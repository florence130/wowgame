class_name Mob
extends Unit
## 怪物 AI：游荡、仇恨范围、追击、技能、逃跑、社交仇恨、脱战重置、掉落与重生

enum S { IDLE, COMBAT, EVADE, FLEE, DEAD }

var mob_id := ""
var def: Dictionary = {}
var state := S.IDLE
var spawner: Node = null
var wander_radius := 8.0
var _wander_target := Vector3.ZERO
var _wander_wait := 0.0
var _think := 0.0
var _ability_t := 2.0
var _ability_cds := {}
var _flee_t := 0.0
var _fled := false
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _evade_t := 0.0
var loot := {}
var looted_all := false
var _despawn_t := 0.0
var _sparkle: Node3D
var aggro_base := 13.0           # 2026-10-10：17 → 13（新手区一进怪堆就被围殴；配合采场把怪物分组拉开）
var ranged_spell := ""
var caster_spell := ""
var leash := 70.0
var encounter_room := ""
var encounter_bounds := Rect2()
var _active := true
var _combat_start := Vector3.ZERO
var last_evade_reason := ""
var _bell_warning: Node3D
var _adds_summoned := 0
var dmg_mul := 1.0
var patrol: Array = []
var _patrol_i := 0
var no_xp := false

func init_mob(id: String, lvl_override: int = 0) -> void:
	mob_id = id
	def = DB.mobs.get(id, {})
	var lv: Array = def.get("lvl", [1, 1])
	level = lvl_override if lvl_override > 0 else randi_range(lv[0], lv[1])
	unit_name = def.get("name", id)
	sub_name = def.get("sub", "")
	unit_type = def.get("type", "beast")
	is_elite = def.get("elite", false)
	is_rare = def.get("rare", false)
	is_boss = def.get("boss", false)
	is_critter = def.get("critter", false)
	no_xp = def.get("no_xp", false)
	faction = "neutral" if def.get("neutral", false) else "hostile"
	base_speed = def.get("speed", 7.0)
	if is_critter:
		base_speed = def.get("speed", 4.0)
	var scl: float = def.get("scale", 1.0)
	radius = 0.45 * scl
	if def.get("model", "") in ["bear", "golem", "treant"]:
		radius = 0.6 * scl
	ranged_spell = def.get("ranged", "")
	caster_spell = def.get("caster", "")
	if is_boss:
		leash = float(def.get("leash", 200.0))
	_build_stats()
	_build_model()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	var hh: float = maxf(radius * 2.0 + 0.1, model.height() * 0.85 if model else 1.5)
	cap.height = hh
	cs.shape = cap
	cs.position = Vector3(0, hh * 0.5, 0)
	add_child(cs)
	add_to_group("mobs")
	add_to_group("interactable")

func _build_stats() -> void:
	var hpm: float = def.get("hp_mul", 1.0)
	dmg_mul = def.get("dmg_mul", 1.0)
	if is_elite:
		hpm *= 2.6
		dmg_mul *= 1.5
	max_hp = round(DataMobs.base_hp(level) * hpm)
	if is_critter:
		max_hp = 8.0
	hp = max_hp
	var dr := DataMobs.base_dmg(level) * dmg_mul
	wspeed = def.get("atk_speed", 2.0)
	wdmg = dr * (wspeed / 2.0)
	if is_critter:
		wdmg = Vector2(1, 1)
	rdmg = wdmg * 0.85
	rspeed = 2.5
	stats = {"armor": DataMobs.base_armor(level) * def.get("armor_mul", 1.0), "ap": 0.0, "sp": level * 1.5 * dmg_mul, "crit": 5.0, "spell_crit": 3.0,
		"dodge": 5.0, "parry": 5.0 if unit_type == "humanoid" else 0.0, "block": 0.0, "spi": 10.0}
	power_type = "mana"
	max_power = 0.0
	power = 0.0

func _build_model() -> void:
	var mk: String = def.get("model", "wolf")
	var scl: float = def.get("scale", 1.0)
	if mk == "humanoid":
		var av := Avatar.new()
		av.name = "Model"
		add_child(av)
		var app := DB.random_appearance(hash(mob_id) + randi() % 1000, "r")
		var gear := DB.outfit_gear(def.get("outfit", "bandit"), randi())
		if def.has("color") and gear.has("chest"):
			gear["chest"]["color"] = def["color"]
		if def.has("color2") and gear.has("head"):
			gear["head"]["color"] = def["color2"]
		var w: String = def.get("weapon", "")
		if w != "":
			if w in ["gun", "bow"]:
				gear["ranged"] = {"type": w, "wtype": w, "color": Color("6a4a30")}
				gear["main"] = {"type": "dagger", "wtype": "dagger", "color": Color("b0b0b8")}
			else:
				gear["main"] = {"type": w, "wtype": w, "color": Color("b0b0b8")}
		av.setup(app, gear)
		av.scale = Vector3.ONE * scl
		model = av
	else:
		var cm := CreatureModel.new()
		cm.name = "Model"
		add_child(cm)
		cm.setup(mk, def.get("color", Color.GRAY), def.get("color2", Color.WHITE), def.get("metal", false), def.get("weapon", ""))
		cm.scale = Vector3.ONE * scl
		model = cm

# ================================================================ AI
func _physics_process(delta: float) -> void:
	if Game.world and Game.world.simulation_suspended():
		return
	if state == S.DEAD:
		_dead_process(delta)
		return
	var pl: Node3D = Game.player
	# 远离玩家时休眠
	if pl and is_instance_valid(pl) and state == S.IDLE and hp >= max_hp and auras.is_empty():
		var far := global_position.distance_squared_to(pl.global_position) > 140.0 * 140.0
		if far:
			if model:
				model.visible = global_position.distance_squared_to(pl.global_position) < 260.0 * 260.0
			return
		elif model and not model.visible and get_aura("polymorph").is_empty():
			model.visible = true
	super._physics_process(delta)
	if dead:
		return
	_think -= delta
	match state:
		S.IDLE: _idle(delta)
		S.COMBAT: _combat(delta)
		S.EVADE: _evade(delta)
		S.FLEE: _flee(delta)
	if model:
		var st := {"speed": velocity.length() if state != S.FLEE else velocity.length(), "casting": is_casting() and not casting.get("channel", false),
			"channel": casting.get("channel", false), "aiming": auto_shoot and target != null and edge_dist(target) > MELEE_RANGE}
		model.animate(delta, st)

func _idle(delta: float) -> void:
	# 游荡
	var wish := Vector3.ZERO
	if not can_act():
		apply_gravity_and_move(delta, Vector3.ZERO)
		return
	if patrol.size() > 1:
		var pt: Vector3 = patrol[_patrol_i]
		var d := pt - global_position
		d.y = 0
		if d.length() < 1.5:
			_patrol_i = (_patrol_i + 1) % patrol.size()
		else:
			wish = d.normalized() * 2.6
			rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 6.0, 0.0, 1.0))
	elif wander_radius > 0.5:
		_wander_wait -= delta
		if _wander_wait <= 0.0:
			var a := randf() * TAU
			var r := randf() * wander_radius
			_wander_target = spawn_pos + Vector3(cos(a) * r, 0, sin(a) * r)
			_wander_wait = randf_range(4.0, 12.0)
		var d2 := _wander_target - global_position
		d2.y = 0
		if d2.length() > 0.8 and _wander_wait > 2.0:
			wish = d2.normalized() * (2.2 if not is_critter else 3.0)
			rotation.y = lerp_angle(rotation.y, atan2(-d2.x, -d2.z), clampf(delta * 5.0, 0.0, 1.0))
	apply_gravity_and_move(delta, wish)
	if _think <= 0.0:
		_think = 0.25
		if faction == "hostile" and not is_critter:
			_check_aggro()
		if not threat.is_empty():
			_engage(top_threat())

func _aggro_radius(u: Unit) -> float:
	var r := aggro_base + (level - u.level) * 1.0
	if is_elite:
		r += 3.0
	r = clampf(r, 5.0, 35.0)
	if u.is_stealthed():
		r *= 0.35
	return r

func _check_aggro() -> void:
	for u in get_tree().get_nodes_in_group("units"):
		var uu: Unit = u
		if uu.dead or uu.faction not in ["player", "pet", "companion"]:
			continue
		if encounter_room != "" and not encounter_bounds.grow(6.0).has_point(Vector2(uu.global_position.x, uu.global_position.z)):
			continue
		if encounter_room != "" and not _same_encounter_floor(uu):
			continue
		var d := global_position.distance_to(uu.global_position)
		if d <= _aggro_radius(uu) and absf(uu.global_position.y - global_position.y) < 12.0:
			if d > 6.0 and not has_los(uu):
				continue
			add_threat(uu, 1.0)
			_engage(uu)
			if uu.is_player:
				Sfx.play_at("aggro", global_position, -10.0)
			return

func _engage(u: Unit) -> void:
	if u == null:
		return
	if state != S.COMBAT:
		state = S.COMBAT
		_combat_start = global_position
		_ability_t = randf_range(1.5, 4.0)
		_stuck_t = 0.0
		if model:
			model.set_combat_ready(true)
		_social_aggro(u)
	target = u

func _social_aggro(u: Unit) -> void:
	var fam: String = def.get("fam", "")
	if fam == "" or fam == "critter":
		return
	for m in get_tree().get_nodes_in_group("mobs"):
		var mm: Mob = m
		if mm == self or mm.dead or mm.state != S.IDLE:
			continue
		if encounter_room != "" and mm.encounter_room != encounter_room:
			continue
		if mm.def.get("fam", "") != fam:
			continue
		if mm.global_position.distance_to(global_position) <= 7.0:      # 连锁仇恨半径 10 → 7m
			mm.add_threat(u, 0.5)
			mm._engage(u)

func on_hostile_action(src: Unit) -> void:
	if state == S.EVADE or dead:
		return
	if is_critter:
		state = S.FLEE
		_flee_t = 5.0
		target = src
		return
	if state == S.IDLE:
		_engage(src)

func add_threat(u: Unit, amount: float) -> void:
	if state == S.EVADE:
		return
	super.add_threat(u, amount)

func take_damage(amt: float, school: String, src: Unit, crit: bool = false, sname: String = "", periodic: bool = false, bonus_threat: float = 0.0, mechanic: bool = false) -> void:
	if state == S.EVADE:
		if src and (src.is_player or src.owner_unit != null):
			Vfx.float_text(self, "闪避", Color.WHITE)
		return
	super.take_damage(amt, school, src, crit, sname, periodic, bonus_threat, mechanic)

func _same_encounter_floor(tgt: Unit) -> bool:
	if absf(tgt.global_position.y - spawn_pos.y) <= 4.0:
		return true
	# Packs on ramps must be able to engage the party below their spawn.
	# Require physical support along the entire connecting slope. A target
	# on a separate stacked floor cannot satisfy these intermediate samples.
	if is_boss or not is_inside_tree() or global_position.distance_to(tgt.global_position) > 26.0 or not has_los(tgt):
		return false
	var space := get_world_3d().direct_space_state
	for step in 5:
		var sample := global_position.lerp(tgt.global_position, float(step) / 4.0)
		var query := PhysicsRayQueryParameters3D.create(sample + Vector3.UP * 0.7, sample - Vector3.UP * 1.0, 1)
		if space.intersect_ray(query).is_empty():
			return false
	return true

func _encounter_focus(tgt: Unit) -> Unit:
	# Keep threat intact while an owned companion crosses the entry behind its
	# leader. Chase the leader until that companion is on the encounter floor.
	if encounter_room == "" or tgt.owner_unit == null or not is_instance_valid(tgt.owner_unit):
		return tgt
	if not _same_encounter_floor(tgt) or not encounter_bounds.grow(6.0).has_point(Vector2(tgt.global_position.x, tgt.global_position.z)):
		if not tgt.owner_unit.dead:
			return tgt.owner_unit
	return tgt

func _combat(delta: float) -> void:
	var tgt := top_threat()
	if tgt == null:
		_start_evade("no living threat")
		return
	# The party leader defines whether the encounter is being pulled out of
	# its room. A tank's ranged taunt/healer aggro at the entrance must not
	# reset a pack while the player is already inside its encounter boundary.
	var boundary_target: Unit = tgt
	if tgt.owner_unit != null and is_instance_valid(tgt.owner_unit):
		boundary_target = tgt.owner_unit
	if encounter_room != "" and (not encounter_bounds.grow(6.0).has_point(Vector2(boundary_target.global_position.x, boundary_target.global_position.z)) or not encounter_bounds.grow(6.0).has_point(Vector2(global_position.x, global_position.z))):
		_start_evade("encounter boundary")
		return
	tgt = _encounter_focus(tgt)
	if encounter_room != "" and not _same_encounter_floor(tgt):
		_start_evade("different floor")
		return
	target = tgt
	# 脱战距离
	if global_position.distance_to(spawn_pos) > leash or global_position.distance_to(_combat_start) > leash:
		_start_evade("home leash")
		return
	# 逃跑
	if def.get("flee", false) and not _fled and hp / max_hp < 0.18 and not is_casting():
		_fled = true
		state = S.FLEE
		_flee_t = 6.0
		auto_attack = false
		Game.msg("%s试图逃跑！" % unit_name, Color("ffa040"))
		Vfx.float_text(self, "逃跑！", Color("ffa040"))
		return
	if not can_act():
		apply_gravity_and_move(delta, Vector3.ZERO)
		return
	if is_casting():
		face_towards(tgt.global_position)
		apply_gravity_and_move(delta, Vector3.ZERO)
		return
	var d := edge_dist(tgt)
	var desired := 0.0
	var use_ranged := (ranged_spell != "" or caster_spell != "") and d > MELEE_RANGE + 0.5
	if use_ranged:
		desired = 24.0
	# 技能
	_ability_t -= delta
	if _ability_t <= 0.0:
		_ability_t = randf_range(2.0, 4.0)
		if _try_abilities(tgt, d):
			return
	if caster_spell != "" and d <= 30.0 and d > MELEE_RANGE + 0.5:
		var csp := DB.spell(caster_spell)
		if not _ability_cds.has(caster_spell) and has_los(tgt):
			_ability_cds[caster_spell] = csp.get("cd", 3.0) + randf_range(0.0, 1.5)
			face_towards(tgt.global_position)
			begin_cast(csp, tgt)
			apply_gravity_and_move(delta, Vector3.ZERO)
			return
	if ranged_spell != "" and d <= 28.0 and d > MELEE_RANGE + 0.5 and has_los(tgt):
		auto_attack = false
		auto_shoot = true
		face_towards(tgt.global_position)
		apply_gravity_and_move(delta, Vector3.ZERO)
		return
	auto_shoot = false
	# 追击
	var wish := Vector3.ZERO
	var reach := MELEE_RANGE - 0.8
	if use_ranged and has_los(tgt):
		reach = desired
	if d > reach:
		var dir := tgt.global_position - global_position
		dir.y = 0
		wish = dir.normalized() * move_speed() * 1.0
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 10.0, 0.0, 1.0))
		auto_attack = d <= MELEE_RANGE
	else:
		face_towards(tgt.global_position)
		auto_attack = true
	apply_gravity_and_move(delta, wish)
	# 卡住检测
	for k in _ability_cds.keys():
		_ability_cds[k] -= delta
		if _ability_cds[k] <= 0.0:
			_ability_cds.erase(k)
	if wish.length() > 0.5:
		if global_position.distance_to(_last_pos) < 0.02:
			_stuck_t += delta
			if _stuck_t > 1.0 and is_on_floor():
				velocity.y = 7.0
			if _stuck_t > 7.0 and not is_boss:
				_start_evade("movement stuck")
				return
		else:
			_stuck_t = maxf(0.0, _stuck_t - delta)
	_last_pos = global_position

func _try_abilities(tgt: Unit, d: float) -> bool:
	var spells: Array = def.get("spells", [])
	for sid in spells:
		if _ability_cds.has(sid):
			continue
		var sp := DB.spell(sid)
		if sp.is_empty():
			continue
		if sp.has("hp_below") and hp / max_hp > sp["hp_below"]:
			continue
		if sid == "mob_summon" and _adds_summoned >= 3:
			continue
		var tt: String = sp.get("target", "enemy")
		var ok := false
		match tt:
			"enemy", "ground_enemy":
				ok = d <= sp.get("range", MELEE_RANGE) and d >= sp.get("min_range", 0.0)
			"none":
				ok = d <= sp.get("range", 7.0)
			"self":
				ok = true
			"self_or_ally":
				ok = hp / max_hp < 0.6
		if not ok:
			continue
		if randf() < 0.35 and not is_boss:
			continue
		_ability_cds[sid] = sp.get("cd", 8.0) * randf_range(1.0, 1.3)
		var t2 := tgt if tt in ["enemy", "ground_enemy"] else self
		if tt == "self_or_ally":
			t2 = self
		face_towards(tgt.global_position)
		if begin_cast(sp, t2):
			if sp.get("cast", 0.0) > 0.0 or sp.has("telegraph"):
				pass
			return true
	return false

func cast_time(sp: Dictionary) -> float:
	return float(sp.get("cast", 0.0))

func _cast_telegraph(sp: Dictionary, ct: float) -> void:
	super._cast_telegraph(sp,ct)
	if mob_id != "boss_victor" or sp.get("id","") != "mob_bell":return
	_bell_warning=Vfx.telegraph(get_parent(),global_position,40.0,ct,self)
	var caption := Label3D.new()
	caption.text="丧钟回响\n打断施法！全场冲击"
	caption.position=Vector3(0,4.5,0);caption.font_size=38;caption.pixel_size=.018
	caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	_bell_warning.add_child(caption)
	cast_stopped.connect(_clear_bell_warning,CONNECT_ONE_SHOT)
	Game.msg(def.get("name","覆钟古根")+"正在震动旧钟——打断施法！",Color("ffad70"))

func _clear_bell_warning(_success: bool) -> void:
	if is_instance_valid(_bell_warning):_bell_warning.queue_free()
	_bell_warning=null

func _summon_adds() -> void:
	var add_id: String = def.get("adds", "")
	if add_id == "" or Game.zone == null:
		return
	for i in 2:
		_adds_summoned += 1
		var a := randf() * TAU
		var pos := global_position + Vector3(cos(a) * 4.0, 0.5, sin(a) * 4.0)
		var m: Mob = Game.zone.spawn_mob(add_id, pos, 0)
		if m:
			m.encounter_room = encounter_room
			m.encounter_bounds = encounter_bounds
		if m and target:
			m.add_threat(target, 5.0)
			m._engage(target)
	Game.msg("%s召唤了援军！" % unit_name, Color("ff8040"))

func _flee(delta: float) -> void:
	_flee_t -= delta
	var src := target if target and is_instance_valid(target) else null
	var dir := Vector3.FORWARD
	if src:
		dir = global_position - src.global_position
		dir.y = 0
		dir = dir.normalized()
	if not can_act():
		apply_gravity_and_move(delta, Vector3.ZERO)
	else:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 8.0, 0.0, 1.0))
		apply_gravity_and_move(delta, dir * move_speed() * 0.75)
	auto_attack = false
	if _flee_t <= 0.0:
		if is_critter:
			state = S.IDLE
			threat.clear()
			leave_combat()
		else:
			state = S.COMBAT
			# 召唤附近同类
			for m in get_tree().get_nodes_in_group("mobs"):
				if m != self and not m.dead and m.state == S.IDLE and m.def.get("fam", "") == def.get("fam", "") and m.global_position.distance_to(global_position) < 18.0 and src:
					m.add_threat(src, 1.0)
					m._engage(src)

func _start_evade(reason: String = "") -> void:
	last_evade_reason = reason
	state = S.EVADE
	threat.clear()
	target = null
	auto_attack = false
	auto_shoot = false
	stop_cast(false)
	_evade_t = 0.0
	_remove_auras_by(func(a): return a["def"].get("type", "") == "debuff")
	leave_combat()

func _evade(delta: float) -> void:
	_evade_t += delta
	var d := spawn_pos - global_position
	d.y = 0
	set_hp(minf(max_hp, hp + max_hp * delta * 0.5))
	if d.length() < 1.5 or _evade_t > 12.0:
		if _evade_t > 12.0:
			global_position = spawn_pos + Vector3(0, 0.5, 0)
		set_hp(max_hp)
		state = S.IDLE
		_fled = false
		_adds_summoned = 0
		if model:
			model.set_combat_ready(false)
		return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 8.0, 0.0, 1.0))
	apply_gravity_and_move(delta, d.normalized() * base_speed * 1.2)
	if model:
		model.animate(delta, {"speed": base_speed})

# ================================================================ 死亡/掉落
func _on_death(killer: Unit) -> void:
	state = S.DEAD
	collision_layer = 4
	remove_from_group("units")
	var pl: Player = Game.player
	var player_credit := tapped_by_player or (killer != null and (killer.is_player or killer.owner_unit != null or killer.faction == "companion"))
	_despawn_t = 75.0 if not is_boss else 3600.0
	if player_credit and pl and not is_critter:
		var xp := 0 if no_xp else DataMobs.xp_for_kill(level, pl.level, is_elite)
		if is_boss:
			xp = int(xp * 1.5)
		if xp > 0:
			Game.give_xp(xp, "kill")
			pl.victory_window = 20.0
		Game.on_kill(mob_id, level)
		_roll_loot()
	elif player_credit and is_critter:
		Game.on_kill(mob_id, level)
		_roll_loot()
	if player_credit and has_loot():
		Game.receive_loot(loot)
	if not has_loot():
		_despawn_t = 15.0
	else:
		_add_sparkle()
	if spawner and is_instance_valid(spawner):
		spawner.on_mob_died(self)
	Sfx.play_at("death", global_position, -12.0)

func _roll_loot() -> void:
	loot = DB.roll_loot(def, level, Game.rng)
	# 任务物品
	for qid in Game.pd["quests"]:
		var q: Dictionary = DB.quests[qid]
		for o in q.get("obj", []):
			if o["type"] == "collect" and o.has("mobs") and mob_id in o["mobs"]:
				if Game.quest_needs_item(o["item"]) and randf() < o.get("chance", 0.5):
					loot["items"].append([o["item"], 1])
	var lq: String = def.get("loot", {}).get("quest", "")
	if lq != "" and Game.quest_needs_item(lq):
		var dup := false
		for e in loot["items"]:
			if e[0] == lq:
				dup = true
		if not dup:
			loot["items"].append([lq, 1])
	var starter := Game.roll_quest_starter(mob_id)
	if starter != "":
		loot["items"].append([starter, 1])

func has_loot() -> bool:
	return loot.get("money", 0) > 0 or loot.get("items", []).size() > 0

func open_loot(_p: Player) -> void:
	if not has_loot():
		return
	loot_all()

func take_loot_item(i: int) -> bool:
	var items: Array = loot.get("items", [])
	if i < 0 or i >= items.size():
		return false
	var e: Array = items[i]
	var left := Game.add_item(e[0], e[1])
	if left > 0:
		e[1] = left
		return false
	items.remove_at(i)
	_check_empty()
	return true

func take_loot_money() -> void:
	var m: int = loot.get("money", 0)
	if m > 0:
		Game.add_money(m)
		Sfx.play("coin")
		loot["money"] = 0
	_check_empty()

func loot_all() -> void:
	Game.receive_loot(loot)
	_check_empty()

func _check_empty() -> void:
	if not has_loot():
		if _sparkle:
			_sparkle.queue_free()
			_sparkle = null
		_despawn_t = minf(_despawn_t, 8.0)

func _add_sparkle() -> void:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var mat := U.unshaded(Color(1, 0.95, 0.5, 1), true).duplicate()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mat
	p.mesh = qm
	p.position = Vector3(0, 0.5, 0)
	add_child(p)
	_sparkle = p

func _dead_process(delta: float) -> void:
	_despawn_t -= delta
	if model:
		model.animate(delta, {})
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		move_and_slide()
	if _despawn_t <= 0.0:
		if Game.hud and Game.hud.has_method("loot_source_gone"):
			Game.hud.loot_source_gone(self)
		queue_free()

func interact(p: Player) -> void:
	if dead and has_loot():
		open_loot(p)

func can_interact() -> bool:
	return dead and has_loot()
