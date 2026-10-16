class_name Player
extends Unit
## 玩家：魔兽式操控（WASD/QE、右键转向、左键环视、双键前进、滚轮缩放、Tab 选敌）

const RUN_SPEED := 7.0
const BACK_SPEED := 4.5
const SWIM_SPEED := 4.7
const WALK_SPEED := 2.5
const JUMP_V := 8.0

var cam_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.32
var cam_dist := 9.0
var cam_dist_target := 9.0
var lmb := false
var rmb := false
var lmb_drag := 0.0
var rmb_drag := 0.0
var _press_pos := Vector2.ZERO
var autorun := false
var walking := false
var swimming := false
var hover_unit: Node = null
var pet: Unit = null
var mount_model: Node3D = null
var _fall_start_y := 0.0
var _was_on_floor := true
var _move_input := Vector2.ZERO
var _sel_ring: MeshInstance3D
var _subzone_check := 0.0
var current_subzone := ""
var in_rest_area := false
var _turn_speed := 3.2
var food_aura := false
var shoot_still_t := 0.0
var _last_pos := Vector3.ZERO
var _footstep_distance := 0.0
var _footstep_side := false
var _night_fill: OmniLight3D

func _ready() -> void:
	super._ready()
	is_player = true
	faction = "player"
	add_to_group("player")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	radius = 0.4
	# 镜头
	cam_pivot = Node3D.new()
	cam_pivot.top_level = true
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.collision_mask = 1
	spring.margin = 0.3
	var ss := SphereShape3D.new()
	ss.radius = 0.25
	spring.shape = ss
	cam_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = maxf(Game.settings.get("view_dist", 700.0), 3600.0)   # 远景山脉需要远裁剪面
	camera.near = 0.1
	spring.add_child(camera)
	camera.current = true
	# A very small lavender fill keeps the avatar readable at night.  It is
	# local to the player and has no shadow, so it supports the moon key instead
	# of flattening the whole environment.
	_night_fill = OmniLight3D.new()
	_night_fill.name = "NightCharacterFill"
	_night_fill.light_color = Color("8f98c5")
	_night_fill.light_energy = 0.0
	_night_fill.omni_range = 4.8
	_night_fill.omni_attenuation = 1.55
	_night_fill.light_specular = 0.04
	_night_fill.shadow_enabled = false
	_night_fill.light_volumetric_fog_energy = 0.0
	_night_fill.position = Vector3(0.0, 1.25, 0.0)
	add_child(_night_fill)
	# 选中圈
	_sel_ring = MeshInstance3D.new()
	_sel_ring.mesh = U.torus_mesh(0.9, 1.0, 40)
	_sel_ring.material_override = U.unshaded(Color(1, 0.85, 0.2, 0.9), true).duplicate()
	_sel_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sel_ring.top_level = true
	_sel_ring.visible = false
	add_child(_sel_ring)
	load_from_data()
	Game.equipment_changed.connect(refresh_visuals)

func load_from_data() -> void:
	var pd := Game.pd
	unit_name = pd["name"]
	level = pd["level"]
	var cd: Dictionary = DB.classes[pd["class"]]
	power_type = cd["power"]
	unit_type = "humanoid"

	# 初始化职业专精资源
	match pd["class"]:
		"warrior":
			spec_resource_type = "momentum"  # 势能
			max_spec_resource = 100.0
		"mage":
			# 法师用fire_charges/frost_charges，不用spec_resource
			fire_charges = 0
			frost_charges = 0
		"priest":
			spec_resource_type = "holy_shadow"  # 圣暗双值
			max_spec_resource = 100.0  # 圣言值
		"rogue":
			spec_resource_type = "shadow_marks"  # 影刃标记
			max_spec_resource = 5.0
		"gunner":
			spec_resource_type = "heat"  # 过热
			max_spec_resource = 100.0

	spec_resource = 0.0
	if model:
		model.queue_free()
	model = Avatar.new()
	model.name = "Avatar"
	add_child(model)
	model.setup(pd["app"], Game.gear_visuals())
	recalc_stats()
	hp = pd.get("hp", max_hp)
	if hp <= 0.0:
		hp = max_hp
	power = clampf(float(pd.get("power", max_power if power_type != "rage" else 0.0)), 0.0, max_power)
	cam_yaw = pd.get("yaw", 0.0)
	rotation.y = cam_yaw

func refresh_visuals() -> void:
	if model:
		model.set_gear(Game.gear_visuals())
		model.set_combat_ready(in_combat or auto_attack)

# ================================================================ 属性
func recalc_stats() -> void:
	if Game.pd.is_empty():
		return
	var pd := Game.pd
	var cls: String = pd["class"]
	var cd: Dictionary = DB.classes[cls]
	var st := Game.calc_stats()
	# 转职被动：先百分比、后固定值（由 Specs.mods 汇总，效果与光环互相独立叠加）
	spec = str(pd.get("spec", ""))
	configure_job_resources(cls)
	var tm := Specs.mods()
	for k in ["str", "agi", "sta", "int", "spi", "armor", "ap", "rap", "sp"]:
		st[k] = st.get(k, 0.0) + aura_stat(k)
	var spct: Dictionary = tm.get("stats_pct", {})
	for k in spct:
		if k in ["ap", "rap"]:
			continue   # 由主属性推导，见下方统一处理
		st[k] = st.get(k, 0.0) * (1.0 + float(spct[k]))
	var sflat: Dictionary = tm.get("stats", {})
	for k in sflat:
		st[k] = st.get(k, 0.0) + float(sflat[k])
	talent_mods = tm
	level = pd["level"]
	var sta: float = st["sta"]
	var hp_from_sta := sta if sta <= 20.0 else 20.0 + (sta - 20.0) * 10.0
	var new_max_hp := (float(cd["hp1"] + cd["hpg"] * (level - 1)) + hp_from_sta + level * level * 0.6) * maxf(0.2, 1.0 + tmod("hp_pct"))
	var ratio := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = round(new_max_hp)
	hp = clampf(round(max_hp * ratio), 1.0 if not dead else 0.0, max_hp)
	match power_type:
		"mana":
			var iv: float = st["int"]
			var mfi := iv if iv <= 20.0 else 20.0 + (iv - 20.0) * 15.0
			var mr := power / max_power if max_power > 0.0 else 1.0
			max_power = round(float(cd["mana1"] + cd["manag"] * (level - 1)) + mfi)
			power = clampf(max_power * mr, 0.0, max_power)
		"rage":
			max_power = 100.0
		"energy":
			max_power = 100.0
	var s: float = st["str"]
	var a: float = st["agi"]
	var ap := 0.0
	match cls:
		"warrior": ap = level * 3 + s * 2 - 20
		"rogue", "gunner": ap = level * 2 + s + a - 20
		_: ap = s - 10
	st["ap"] = maxf(0.0, ap + st.get("ap", 0.0))
	st["rap"] = maxf(0.0, (level * 2 + a * 2 - 10 if cls == "gunner" else level + a - 10) + st.get("rap", 0.0))
	# 攻击强度 / 远程攻击强度由主属性推导，天赋的百分比在这一步之后才生效
	if spct.has("ap"):
		st["ap"] *= 1.0 + float(spct["ap"])
	if spct.has("rap"):
		st["rap"] *= 1.0 + float(spct["rap"])
	st["crit"] = 5.0 + a / 20.0 + st.get("crit", 0.0)
	st["spell_crit"] = 1.0 + st["int"] / 60.0 + st.get("spell_crit", 0.0)
	st["dodge"] = 5.0 + a / (14.5 if cls == "rogue" else 20.0) + st.get("dodge", 0.0)
	st["parry"] = (5.0 if cls in ["warrior", "rogue"] else 0.0) + st.get("parry", 0.0)
	st["armor"] = st["armor"] + a * 2.0
	var eq: Dictionary = pd["equip"]
	st["block"] = (5.0 if (eq.has("off") and DB.get_item(eq["off"]).get("type", "") == "shield") else 0.0) + st.get("block", 0.0)
	stats = st
	# 武器
	if eq.has("main") and Game.can_equip(DB.get_item(eq["main"]), false):
		var w := DB.get_item(eq["main"])
		wdmg = Vector2(w["dmg"][0], w["dmg"][1])
		wspeed = w.get("speed", 2.0)
	else:
		wdmg = Vector2(1, 2) + Vector2.ONE * level * 0.3
		wspeed = 2.0
	off_wspeed = 0.0
	if eq.has("off") and Game.can_equip(DB.get_item(eq["off"]), false):
		var o := DB.get_item(eq["off"])
		if o.has("dmg") and o.get("slot", "") == "one":
			off_wdmg = Vector2(o["dmg"][0], o["dmg"][1])
			off_wspeed = o.get("speed", 2.0)
	rdmg = Vector2.ZERO
	if eq.has("ranged") and Game.can_equip(DB.get_item(eq["ranged"]), false):
		var r := DB.get_item(eq["ranged"])
		if r.has("dmg"):
			rdmg = Vector2(r["dmg"][0], r["dmg"][1])
			rspeed = r.get("speed", 2.6)
	hp_changed.emit()
	power_changed.emit()

func _has_shield() -> bool:
	if force_shield:
		return true
	var eq: Dictionary = Game.pd.get("equip", {})
	return eq.has("off") and DB.get_item(eq["off"]).get("type", "") == "shield"

func _main_weapon_type() -> String:
	var eq: Dictionary = Game.pd["equip"]
	if eq.has("main"):
		return DB.get_item(eq["main"]).get("type", "")
	return ""

func _off_weapon_type() -> String:
	var eq: Dictionary = Game.pd.get("equip", {})
	return str(DB.get_item(eq["off"]).get("type", "")) if eq.has("off") else ""

const INPUT_BUFFER := 0.22
var buffered_skill := ""
var buffered_target: Unit
var buffer_time := 0.0
var impact_time := 0.0
var impact_strength := 0.0

func clear_skill_buffer() -> void:
	buffered_skill = ""
	buffered_target = null
	buffer_time = 0.0

func combat_impact(amount: float) -> void:
	impact_time = 0.09
	impact_strength = minf(0.055, maxf(impact_strength, amount))

func dodge_direction() -> Vector3:
	if _move_input.length_squared() > 0.01:
		return (global_transform.basis * Vector3(_move_input.x, 0, -_move_input.y)).normalized()
	return forward_dir()

func _tick_skill_buffer(delta: float) -> void:
	if buffered_skill == "":
		return
	buffer_time -= delta
	if buffer_time <= 0.0 or dead or not can_act() or Game.is_typing():
		clear_skill_buffer()
		return
	var sp := DB.spell(buffered_skill, maxi(1, Game.spell_rank(buffered_skill)))
	if not is_casting() and gcd <= 0.0 and action_lock <= 0.0:
		var sid := buffered_skill
		var tgt := buffered_target
		clear_skill_buffer()
		# Preserve the intended target instead of silently attacking the next selection.
		if is_instance_valid(tgt) and not tgt.dead and check_cast(sp, tgt) == "" and begin_cast(sp, tgt):
			_after_skill_started(sp, tgt)

# ================================================================ 输入
func _unhandled_input(event: InputEvent) -> void:
	if Game.world == null or get_tree().paused:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist_target = maxf(1.5, cam_dist_target * 0.88 - 0.2)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_dist_target = minf(32.0, cam_dist_target * 1.13 + 0.2)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				lmb = true
				lmb_drag = 0.0
				_press_pos = mb.position
			else:
				var was_click := lmb and lmb_drag < 6.0
				lmb = false
				_update_mouse_capture()
				if was_click:
					_click_select(mb.position, false)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				rmb = true
				rmb_drag = 0.0
				_press_pos = mb.position
			else:
				var was_click2 := rmb and rmb_drag < 6.0
				rmb = false
				_update_mouse_capture()
				if was_click2:
					_click_select(mb.position, true)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if lmb or rmb:
			var d := mm.relative.length()
			if lmb:
				lmb_drag += d
			if rmb:
				rmb_drag += d
			if (lmb and lmb_drag >= 6.0) or (rmb and rmb_drag >= 6.0):
				_update_mouse_capture(true)
				var sens: float = Game.settings.get("mouse_sens", 0.25) * 0.012
				cam_yaw -= mm.relative.x * sens
				var inv := -1.0 if Game.settings.get("invert_y", false) else 1.0
				cam_pitch = clampf(cam_pitch - mm.relative.y * sens * inv, deg_to_rad(-85), deg_to_rad(35))
				if rmb and can_turn():
					rotation.y = cam_yaw
		else:
			_update_hover(mm.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if Game.is_typing():
			return
		var k: int = event.keycode
		if k == Game.keybinds["jump"]:
			_jump()
		elif k == Game.keybinds["autorun"] or k == Game.keybinds["autorun2"]:
			autorun = not autorun
		elif k == Game.keybinds["sit"]:
			if not in_combat and not mounted:
				set_sitting(not sitting)
		elif k == Game.keybinds["target_nearest"]:
			target_nearest_enemy(event.shift_pressed)
		elif k == Game.keybinds["interact"]:
			interact_nearest()
		elif k == Game.keybinds["walk"]:
			walking = not walking
		else:
			var bi: int = Game.bar_keys.find(k)
			if bi >= 0:
				use_bar_slot(bi + (12 if event.shift_pressed else 0))
				get_viewport().set_input_as_handled()

func _update_mouse_capture(force_capture: bool = false) -> void:
	var want := (lmb and lmb_drag >= 6.0) or (rmb and rmb_drag >= 6.0) or (force_capture and (lmb or rmb))
	if want and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not want and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not lmb and not rmb:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.warp_mouse(_press_pos)

func can_turn() -> bool:
	return not dead and not is_stunned() and not is_incap() and not is_feared()

func _jump() -> void:
	if dead or is_rooted():
		return
	if sitting:
		set_sitting(false)
	if is_on_floor() and not swimming:
		velocity.y = JUMP_V
		Sfx.play("jump", -12.0)
	elif swimming:
		velocity.y = 3.0

func _pick(screen_pos: Vector2, mask: int = 2 | 4) -> Node:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, mask | 1)
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return null
	var c: Node = r["collider"]
	if c is Unit or c.has_method("interact"):
		return c
	return null

func _update_hover(pos: Vector2) -> void:
	var n := _pick(pos)
	if n != hover_unit:
		hover_unit = n
		var shape := Input.CURSOR_ARROW
		if n is Unit:
			var u: Unit = n
			if u.dead and u.has_method("has_loot") and u.has_loot():
				shape = Input.CURSOR_DRAG
			elif is_enemy(u) and not u.dead:
				shape = Input.CURSOR_CROSS
			elif u.has_method("interact"):
				shape = Input.CURSOR_POINTING_HAND
		elif n != null:
			shape = Input.CURSOR_POINTING_HAND
		Input.set_default_cursor_shape(shape)

func _click_select(pos: Vector2, interact: bool) -> void:
	var n := _pick(pos)
	if n == null:
		if not interact and target != null:
			pass
		return
	if n is Unit:
		var u: Unit = n
		set_target(u)
		if interact:
			interact_with(u)
	elif interact and n.has_method("interact"):
		if global_position.distance_to(n.global_position) <= 6.0:
			n.interact(self)
		else:
			Game.err("距离太远。")

func set_target(u: Unit) -> void:
	if u == target:
		return
	target = u
	if u == null:
		auto_attack = false
		auto_shoot = false
	Game.target_changed.emit(u)

func interact_with(u: Unit) -> void:
	if u.dead:
		if u.has_method("open_loot") and u.has_loot():
			if global_position.distance_to(u.global_position) <= 6.0:
				u.open_loot(self)
			else:
				Game.err("距离太远。")
		return
	if is_enemy(u):
		face_towards(u.global_position)
		if rdmg != Vector2.ZERO and Game.pd["class"] == "gunner":
			auto_shoot = true
			auto_attack = edge_dist(u) <= MELEE_RANGE
		else:
			start_auto_attack()
		return
	if u.has_method("interact"):
		if global_position.distance_to(u.global_position) <= 6.5:
			face_towards(u.global_position)
			u.interact(self)
		else:
			Game.err("距离太远。")

func start_auto_attack() -> void:
	if target == null or target.dead or not is_enemy(target):
		return
	if is_stealthed():
		break_stealth()
	auto_attack = true
	if model:
		model.set_combat_ready(true)

func target_nearest_enemy(backward: bool = false) -> void:
	var cands := []
	for u in get_tree().get_nodes_in_group("units"):
		var uu: Unit = u
		if uu.dead or not is_enemy(uu) or uu.is_critter:
			continue
		var d := global_position.distance_to(uu.global_position)
		if d > 40.0:
			continue
		var to := (uu.global_position - global_position)
		to.y = 0
		var f := -camera.global_transform.basis.z
		f.y = 0
		if to.normalized().dot(f.normalized()) < 0.1:
			continue
		cands.append([d, uu])
	if cands.is_empty():
		return
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var idx := 0
	for i in cands.size():
		if cands[i][1] == target:
			idx = (i + (cands.size() - 1 if backward else 1)) % cands.size()
			break
	set_target(cands[idx][1])

func interact_nearest() -> void:
	var best: Node = null
	var bd := 5.5
	for u in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(u):
			continue
		if u is Unit and (u.dead and not (u.has_method("has_loot") and u.has_loot())):
			continue
		if u.has_method("can_interact") and not u.can_interact():
			continue
		var d := global_position.distance_to(u.global_position)
		if d < bd:
			bd = d
			best = u
	if best == null:
		return
	if best is Unit:
		set_target(best)
		interact_with(best)
	else:
		best.interact(self)

# ================================================================ 动作条
func use_bar_slot(i: int) -> void:
	if i < 0 or i >= Game.BAR_SLOTS:
		return
	var b = Game.pd["bars"][i]
	if b == null:
		return
	if Game.hud and i < Game.hud.bar_slots.size():
		Game.hud.bar_slots[i].flash()
	if b["t"] == "spell":
		cast_spell_id(b["id"])
	elif b["t"] == "item":
		use_item_id(b["id"])
	if Game.hud:
		Game.hud.flash_bar(i)

func cast_spell_id(sid: String) -> void:
	if dead:
		return
	var rank := Game.spell_rank(sid)
	if rank <= 0:
		Game.err("你还没有学会这个技能。")
		return
	var sp := DB.spell(sid, rank)
	if sp.get("toggle_attack", false):
		if auto_attack:
			auto_attack = false
		else:
			if target == null or not is_enemy(target):
				Game.err("你没有目标。")
				return
			start_auto_attack()
		return
	if sp.get("toggle_shoot", false):
		if auto_shoot:
			auto_shoot = false
			return
		var e0 := check_cast(sp, target)
		if e0 != "":
			Game.err(e0)
			return
		auto_shoot = true
		ranged_timer = maxf(ranged_timer, 0.5)
		face_towards(target.global_position)
		return
	if mounted:
		var effs: Array = sp.get("effects", [])
		if effs.size() > 0 and effs[0].get("type", "") == "mount":
			dismount()
			return
		dismount()
	var tgt := target
	if sp.get("target", "") == "friend" and (tgt == null or not is_friend(tgt)):
		tgt = self
	if sp.get("target", "") in ["self", "none"]:
		tgt = self
	var cast_remaining: float = maxf(0.0, float(casting.get("total", 0.0)) - float(casting.get("elapsed", 0.0)))
	var busy := maxf(maxf(gcd, action_lock), cast_remaining)
	if sid != "dodge_roll" and sp.get("gcd", 1.0) > 0.0 and busy > 0.0 and busy <= INPUT_BUFFER:
		buffered_skill = sid
		buffered_target = tgt
		buffer_time = INPUT_BUFFER
		return
	if sid == "dodge_roll":
		clear_skill_buffer()
	if begin_cast(sp, tgt):
		_after_skill_started(sp, tgt)

func _after_skill_started(sp: Dictionary, tgt: Unit) -> void:
	if sp.get("target", "") == "enemy" and is_instance_valid(tgt) and is_enemy(tgt):
		if DB.classes[Game.pd["class"]].get("melee", false) or spec == "shadow_priest":
			start_auto_attack()
		elif Game.pd["class"] == "gunner" and spec == "" and edge_dist(tgt) > 5.0 and rdmg != Vector2.ZERO and sp.get("id") != "weak_mark":
			auto_shoot = true

func _cast_error(e: String) -> void:
	Game.err(e)

func use_item_id(id: String) -> void:
	var idx := -1
	for i in Game.BAG_SIZE:
		var st = Game.pd["bag"][i]
		if st != null and st["id"] == id:
			idx = i
			break
	if idx < 0:
		Game.err("你没有这件物品。")
		return
	use_bag_item(idx)

func use_bag_item(idx: int) -> void:
	var st = Game.pd["bag"][idx]
	if st == null or dead:
		return
	var it := DB.get_item(st["id"])
	if it.get("equip", "") != "":
		Game.equip_from_bag(idx)
		return
	if it.has("starts_quest"):
		if Game.hud:
			Game.hud.open_quest_offer(it["starts_quest"], null)
		return
	var use: Dictionary = it.get("use", {})
	if use.is_empty():
		return
	if it.get("req", 1) > level:
		Game.err("你的等级太低。")
		return
	if use.has("spell"):
		var sp := DB.spell(use["spell"])
		if cooldowns.has(sp["id"]):
			Game.err("物品还没有准备好。")
			return
		begin_cast(sp, self)
		return
	if use.has("learn"):
		var sid: String = use["learn"]
		if Game.pd["spells"].has(sid):
			Game.err("你已经学会了。")
			return
		if sid.begins_with("mount") and not Game.pd.get("riding", false):
			Game.err("你需要学习骑术。")
			return
		Game.remove_at(idx, 1)
		Game.learn_spell(sid, 1)
		return
	if use.has("food") or use.has("drink"):
		if in_combat:
			Game.err("你正处于战斗中！")
			return
		if mounted:
			dismount()
		var is_food := use.has("food")
		var total: float = use.get("food", use.get("drink", 0))
		var dur: float = use.get("dur", 18.0)
		var aid := "food" if is_food else "drink"
		remove_aura(aid)
		var def := {"id": aid, "name": "进食" if is_food else "喝水", "icon": "bread" if is_food else "water", "color": it.get("color", Color.WHITE),
			"dur": dur, "type": "buff", "food": is_food, "drink": not is_food, "tick": {"interval": 1.0}}
		if is_food:
			def["tick"]["heal"] = total / dur
		else:
			def["tick"]["mana"] = total / dur
		Game.remove_at(idx, 1)
		set_sitting(true)
		add_aura(def, self)
		return
	if use.has("heal") or use.has("mana"):
		var grp := "potion"
		if Game.item_cooldowns.has(grp):
			Game.err("物品还没有准备好。")
			return
		Game.item_cooldowns[grp] = use.get("cd", 120.0)
		Game.remove_at(idx, 1)
		if use.has("heal"):
			receive_heal(randf_range(use["heal"][0], use["heal"][1]), self, false, it["name"])
			Vfx.spell_vfx("heal", self, self)
		if use.has("mana"):
			add_power(randf_range(use["mana"][0], use["mana"][1]))
			Vfx.burst(get_parent(), chest_pos(), Color("4060ff"), 1.0)
		Sfx.play("heal")

func _aura_tick(a: Dictionary) -> void:
	var tk: Dictionary = a["def"].get("tick", {})
	if tk.has("mana"):
		add_power(tk["mana"])
		return
	super._aura_tick(a)

# ================================================================ 移动
func _physics_process(delta: float) -> void:
	if Game.world and (Game.world.simulation_suspended() or not Game.world.ground_ready(global_position)):
		velocity = Vector3.ZERO
		return
	super._physics_process(delta)
	_tick_skill_buffer(delta)
	if motion_active:
		return
	if Game.world == null:
		return
	var typing := Game.is_typing()
	var fwd := 0.0
	var strafe := 0.0
	var turn := 0.0
	var kb := Game.keybinds
	if not typing and not dead:
		if Input.is_key_pressed(kb["move_forward"]):
			fwd += 1.0
		if Input.is_key_pressed(kb["move_back"]):
			fwd -= 1.0
		if Input.is_key_pressed(kb["strafe_left"]):
			strafe -= 1.0
		if Input.is_key_pressed(kb["strafe_right"]):
			strafe += 1.0
		if Input.is_key_pressed(kb["turn_left"]):
			if rmb:
				strafe -= 1.0
			else:
				turn += 1.0
		if Input.is_key_pressed(kb["turn_right"]):
			if rmb:
				strafe += 1.0
			else:
				turn -= 1.0
	if lmb and rmb:
		fwd = 1.0
	if autorun:
		if fwd < 0.0:
			autorun = false
		fwd = maxf(fwd, 1.0) if autorun else fwd
	if dead or not can_act():
		fwd = 0.0
		strafe = 0.0
		turn = 0.0
		autorun = false
	if is_feared():
		_fear_move(delta)
		return
	if turn != 0.0 and can_turn():
		rotation.y += turn * _turn_speed * delta
		if not lmb:
			cam_yaw = rotation.y
	strafe = clampf(strafe, -1.0, 1.0)
	var moving := fwd != 0.0 or strafe != 0.0
	if moving:
		if sitting:
			set_sitting(false)
		if is_casting() and not casting["sp"].get("move_cast", false):
			stop_cast(false)
	# 速度
	var spd := move_speed()
	if is_casting():
		spd *= float(casting["sp"].get("cast_move_multiplier", casting["sp"].get("move_cast_speed", 1.0)))
	var dir := Vector3(strafe, 0, -fwd)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var mult := 1.0
	if fwd < 0.0 and strafe == 0.0:
		mult = BACK_SPEED / RUN_SPEED
	if walking:
		mult = WALK_SPEED / RUN_SPEED
	# 游泳检测
	var wl: float = Game.zone.water_level() if Game.zone else -10000.0
	swimming = global_position.y < wl - 1.1
	if swimming:
		mult *= SWIM_SPEED / RUN_SPEED
		if mounted:
			dismount()
	var wish := global_transform.basis * dir * spd * mult
	if swimming:
		var vy := velocity.y
		var target_y := wl - 1.25
		vy = lerpf(vy, (target_y - global_position.y) * 3.0, 0.15)
		if Input.is_key_pressed(kb["jump"]) and not typing:
			vy = 3.0
		velocity = Vector3(wish.x, vy, wish.z)
		move_and_slide()
	else:
		apply_gravity_and_move(delta, wish)
	# 坠落伤害
	var on_floor := is_on_floor()
	if _was_on_floor and not on_floor:
		_fall_start_y = global_position.y
	if not _was_on_floor and on_floor and not swimming:
		var fall := _fall_start_y - global_position.y
		if fall > 14.0:
			var dmg := max_hp * clampf((fall - 14.0) / 30.0, 0.0, 0.95)
			take_damage(dmg, "fall", null, false, "坠落")
			Game.msg("你因坠落受到了%d点伤害。" % int(dmg), Color("ff8080"))
	if not on_floor:
		_fall_start_y = maxf(_fall_start_y, global_position.y)
	_was_on_floor = on_floor or swimming
	# 防止掉出世界
	if global_position.y < -200.0:
		Game.world.respawn_player_at_graveyard()
	_move_input = Vector2(strafe, fwd)
	_update_footsteps()
	_last_pos = global_position

func _update_footsteps() -> void:
	var travel := U.flat_dist(global_position, _last_pos)
	if dead or swimming or mounted or not is_on_floor() or travel > 1.0:
		_footstep_distance = 0.0
		return
	if travel < 0.002:
		return
	_footstep_distance += travel
	var stride := 1.35 if walking else 2.15
	if _footstep_distance < stride:
		return
	_footstep_distance = fmod(_footstep_distance, stride)
	_footstep_side = not _footstep_side
	var stone: bool = Game.zone != null and Game.zone.zone_id == "sanctum"
	if not stone and Game.zone != null and Game.zone.terrain != null:
		var terrain: BrushTerrain = Game.zone.terrain
		var local := terrain.to_local(global_position)
		var data := terrain.data
		var cell := Vector2i(floori(local.x / data.cell_size), floori(local.z / data.cell_size))
		if cell.x >= 0 and cell.y >= 0 and cell.x < data.resolution and cell.y < data.resolution:
			var layers := data.get_layer(cell.x, cell.y)
			stone = layers[2] > 0.4 or layers[4] > 0.3
	Sfx.play_at(("step_stone_a" if _footstep_side else "step_stone_b") if stone else "step_dirt", global_position, -18.0 if walking else -15.0)

func _fear_move(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	rotation.y += sin(t * 1.3) * delta * 2.0
	apply_gravity_and_move(delta, forward_dir() * move_speed() * 0.8)

func _process(delta: float) -> void:
	if Game.world == null:
		return
	if is_instance_valid(_night_fill):
		var nf: float = Game.world.night_factor()
		_night_fill.visible = nf > 0.01 and cam_dist > 1.2
		# 角色补光只抬起暗部，不把浅色材质和眼睛照成自发光。
		_night_fill.light_energy = lerpf(0.0, 0.085, nf)
	# 镜头
	impact_time = maxf(0.0, impact_time - delta)
	camera.h_offset = sin(impact_time * 110.0) * impact_strength * (impact_time / 0.09)
	if impact_time <= 0.0:
		impact_strength = 0.0
	cam_dist = lerpf(cam_dist, cam_dist_target, clampf(delta * 8.0, 0.0, 1.0))
	var moving := _move_input.length() > 0.0
	if moving and not lmb and not rmb:
		cam_yaw = lerp_angle(cam_yaw, rotation.y, clampf(delta * 3.0, 0.0, 1.0))
	var head_h = 1.55 * (model.height() / 1.62 if model and model.has_method("height") else 1.0)
	if mounted:
		head_h += 0.8
	cam_pivot.global_position = cam_pivot.global_position.lerp(global_position + Vector3(0, head_h, 0), clampf(delta * 14.0, 0.0, 1.0))
	cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)
	spring.spring_length = cam_dist
	# 第一人称时隐藏模型
	if model:
		model.visible = cam_dist > 1.2 or not get_aura("polymorph").is_empty()
	# 动画
	var st := {"speed": velocity.dot(forward_dir()) if not dead else 0.0, "strafe": velocity.dot(global_transform.basis.x),
		"air": not is_on_floor() and not swimming, "casting": is_casting() and not casting.get("channel", false), "channel": casting.get("channel", false),
		"swim": swimming, "sit": sitting, "mounted": mounted, "aiming": (auto_shoot or spec == "marksman") and is_instance_valid(target), "cast_animation": casting.get("sp", {}).get("animation", ""), "rolling": motion_active and invincible_frames > 0}
	if model:
		model.set_combat_ready(in_combat or auto_attack)
		if model is Avatar:
			model.set_ranged_mode(spec == "marksman" or (auto_shoot and target != null and not auto_attack))
			model.set_mech_armor(spec == "gadgeteer" and not get_aura("mech_armor").is_empty())
		model.animate(delta, st)
	if mount_model and mount_model.has_method("animate"):
		mount_model.animate(delta, {"speed": st["speed"], "strafe": st["strafe"]})
	# 选中圈
	if target != null and is_instance_valid(target) and target != self:
		_sel_ring.visible = true
		var r: float = target.radius * 1.6 + 0.3
		_sel_ring.global_position = target.global_position + Vector3(0, 0.08, 0)
		_sel_ring.scale = Vector3(r, 0.5, r)
		var col := Color(0.3, 1.0, 0.3, 0.9)
		if is_enemy(target):
			col = Color(1.0, 0.25, 0.2, 0.9) if target.faction == "hostile" else Color(1.0, 0.9, 0.2, 0.9)
		if target.dead:
			col = Color(0.6, 0.6, 0.6, 0.6)
		(_sel_ring.material_override as StandardMaterial3D).albedo_color = col
	else:
		_sel_ring.visible = false
		if target != null and not is_instance_valid(target):
			set_target(null)
	# 自动攻击目标死亡
	if target != null and is_instance_valid(target) and target.dead:
		auto_attack = false
		auto_shoot = false
	# 战斗状态
	_update_combat_state()
	# 精力充沛
	if in_rest_area and not in_combat:
		var cap := DB.xp_to_next(level) * 1.5
		Game.pd["rested"] = minf(cap, Game.pd.get("rested", 0.0) + delta * DB.xp_to_next(level) * 0.002)
	_subzone_check -= delta
	if _subzone_check <= 0.0:
		_subzone_check = 0.5
		if Game.zone:
			var sz: String = Game.zone.subzone_at(global_position)
			if sz != current_subzone:
				current_subzone = sz
				Game.subzone_changed.emit(sz)
				if sz != "":
					Game.center_text.emit(sz, "")
	if pet != null and not is_instance_valid(pet):
		pet = null

func _update_combat_state() -> void:
	var engaged := false
	for u in get_tree().get_nodes_in_group("units"):
		var m: Unit = u
		if not m.dead and m.faction == "hostile" and (m.threat.has(self) or (pet != null and m.threat.has(pet))):
			engaged = true
			break
	if engaged:
		combat_timer = 0.0
		if not in_combat:
			enter_combat()
	elif in_combat and combat_timer > 5.0:
		leave_combat()

func _on_combat_changed(v: bool) -> void:
	if v:
		if mounted:
			dismount()
		Sfx.set_music("combat")
	else:
		auto_attack = false if target == null or target.dead else auto_attack
		if Game.zone:
			Sfx.set_music(Game.zone.music_mode(global_position))

func _can_autoshoot() -> bool:
	return spec != "gadgeteer" and _move_input.length() < 0.01 and not is_casting()

func on_hostile_action(src: Unit) -> void:
	if target == null and src != null and not dead:
		set_target(src)

# ================================================================ 特殊
func _hearth() -> void:
	if Game.world:
		Game.world.hearth()

func _summon_pet(pet_id: String) -> void:
	if spec == "gadgeteer":
		return
	if pet != null and is_instance_valid(pet) and not pet.dead:
		pet.set_hp(pet.max_hp)
		Game.msg("你的机械猎犬已修复完毕。", Color("80ff80"))
		return
	if Game.world:
		pet = Game.world.spawn_pet(self, pet_id)

func _mount(kind: String) -> void:
	if mounted:
		dismount()
		return
	if in_combat or swimming:
		Game.err("你现在无法召唤坐骑。")
		return
	# 坐骑 id → 模型 / 配色 / 速度（表在 src/data/data_mounts.gd）
	var md := DataMounts.get_mount(kind)
	var mid: String = kind if not md.is_empty() else DataMounts.from_effect({"model": kind})
	md = DataMounts.get_mount(mid)
	mounted = true
	mount_id = mid
	mount_bonus = float(md.get("speed", 0.6))
	var mkind: String = String(md.get("model", kind))
	var m := CreatureModel.new()
	m.name = "Mount"
	m.setup(mkind, Color(md.get("color", Color("8a5a3a"))), Color(md.get("color2", Color("2a1a10"))))
	add_child(m)
	mount_model = m
	if model:
		# 体型越高大的坐骑，骑手坐得越高
		model.position.y = 0.95 if mkind == "horse" else (0.75 if mkind == "mech" else 0.85)
		model.position.z = 0.1
	Sfx.play("equip")

func dismount() -> void:
	if not mounted:
		return
	mounted = false
	mount_id = ""
	mount_bonus = 0.6
	if mount_model:
		mount_model.queue_free()
		mount_model = null
	if model:
		model.position = Vector3.ZERO

func set_sitting(v: bool) -> void:
	super.set_sitting(v)

func _on_death(_killer: Unit) -> void:
	dismount()
	autorun = false
	Game.msg("你死亡了。", Color("ff4040"))
	Sfx.play("death")
	Achieve.bump("deaths")
	if Game.hud:
		Game.hud.show_death()

func revive(full: bool = true) -> void:
	dead = false
	hp = max_hp if full else max_hp * 0.5
	power = max_power if power_type == "mana" else (0.0 if power_type == "rage" else max_power)
	if model and model.has_method("set_dead"):
		model.set_dead(false)
	hp_changed.emit()
	power_changed.emit()
	Vfx.column(get_parent(), global_position, Color("ffffff"), 3.0, 1.0)
