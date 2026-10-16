class_name Ally
extends Unit
## 宠物与同伴（信赖系统式 NPC 队友）：坦克 / 治疗 / 输出 / 宠物

var role := "pet"  # pet / tank / healer / dps
var ally_id := ""
var _think := 0.0
var _ability_cds := {}
var follow_offset := Vector3(1.8, 0, 2.2)
var _revive_t := 0.0
var spell_list: Array = []
var _sanctum_follow := preload("res://src/actors/sanctum_follow.gd").new()

func init_ally(id: String, r: String, owner: Unit, lvl: int) -> void:
	ally_id = id
	role = r
	owner_unit = owner
	level = lvl
	faction = "pet" if r == "pet" else "companion"
	unit_type = "beast" if r == "pet" else "humanoid"
	add_to_group("allies")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6 if r != "pet" else 0.9
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5, 0)
	add_child(cs)
	radius = 0.4
	if r == "pet":
		unit_name = "机械猎犬"
		sub_name = "%s的宠物" % owner.unit_name
		var cm := CreatureModel.new()
		cm.setup("hound", Color("b08a50"), Color("80c0ff"), true)
		add_child(cm)
		model = cm
		spell_list = ["pet_bite", "pet_growl"]
		follow_offset = Vector3(-1.6, 0, 1.6)
	else:
		var nd: Dictionary = DB.npcs.get(id, {})
		unit_name = nd.get("name", id)
		sub_name = nd.get("sub", "")
		var av := Avatar.new()
		add_child(av)
		var gear := DB.outfit_gear(nd.get("outfit", "knight"), hash(id))
		av.setup(DB.npc_appearance(id, nd), gear)
		model = av
		match r:
			"tank":
				spell_list = ["npc_taunt", "npc_shield_slam", "npc_thunder"]
				follow_offset = Vector3(0, 0, -2.5)
			"healer":
				spell_list = ["npc_heal", "npc_renew", "npc_smite"]
				follow_offset = Vector3(2.0, 0, 3.0)
			"dps":
				spell_list = ["npc_arrow", "npc_multishot"]
				follow_offset = Vector3(-2.0, 0, 3.0)
	_set_stats()

func _set_stats() -> void:
	var base := DataMobs.base_hp(level)
	var mult = {"pet": 1.1, "tank": 2.6, "healer": 1.3, "dps": 1.4}[role]
	max_hp = round(base * mult + level * 8)
	hp = max_hp
	var dr := DataMobs.base_dmg(level)
	match role:
		"pet":
			wdmg = dr * 0.9
			wspeed = 2.0
		"tank":
			wdmg = dr * 0.9
			wspeed = 2.4
		"dps":
			wdmg = dr * 0.8
			rdmg = dr * 1.1
			rspeed = 2.6
		"healer":
			wdmg = dr * 0.5
	stats = {"armor": DataMobs.base_armor(level) * (2.2 if role == "tank" else 1.0), "ap": 0.0, "sp": level * 2.0, "crit": 5.0, "spell_crit": 5.0,
		"dodge": 8.0 if role == "tank" else 5.0, "parry": 8.0 if role == "tank" else 0.0, "block": 10.0 if role == "tank" else 0.0, "spi": 20.0}
	base_speed = 7.0

func _physics_process(delta: float) -> void:
	if Game.world and Game.world.simulation_suspended():
		return
	if dead:
		_revive_t -= delta
		if model:
			model.animate(delta, {})
		if owner_unit and is_instance_valid(owner_unit) and not owner_unit.in_combat and _revive_t <= 0.0 and role != "pet":
			_revive()
		return
	super._physics_process(delta)
	if dead:
		return
	if owner_unit == null or not is_instance_valid(owner_unit):
		queue_free()
		return
	var in_sanctum: bool = Game.zone != null and Game.zone.zone_id == "sanctum"
	var floor_path := global_position
	if in_sanctum:
		floor_path = _sanctum_follow.target(self, owner_unit)
	for k in _ability_cds.keys():
		_ability_cds[k] -= delta
		if _ability_cds[k] <= 0.0:
			_ability_cds.erase(k)
	_think -= delta
	var wish := Vector3.ZERO
	var enemy := _pick_enemy()
	if owner_unit.dead:
		enemy = null
	if not can_act():
		apply_gravity_and_move(delta, Vector3.ZERO)
		_anim(delta)
		return
	if is_casting():
		apply_gravity_and_move(delta, Vector3.ZERO)
		_anim(delta)
		return
	# Ranged companions close the gap before beginning another stationary cast.
	# Otherwise a succession of valid long-range heals leaves them one corner
	# farther behind after every pull, even though their spells are in range.
	if in_sanctum and role in ["healer", "dps"] and global_position.distance_to(owner_unit.global_position) > 22.0:
		var follow := floor_path - global_position
		follow.y = 0.0
		auto_attack = false
		auto_shoot = false
		apply_gravity_and_move(delta, follow.normalized() * minf(move_speed() * 1.3, follow.length() / maxf(delta, .001)))
		_anim(delta)
		return
	# 治疗优先
	if role == "healer" and _think <= 0.0:
		_think = 0.4
		if _heal_logic():
			apply_gravity_and_move(delta, Vector3.ZERO)
			_anim(delta)
			return
	if enemy != null:
		target = enemy
		enter_combat()
		var d := edge_dist(enemy)
		var want := MELEE_RANGE - 0.8
		if role in ["healer", "dps"]:
			want = 22.0
		if role != "healer" or _think <= 0.0:
			_use_abilities(enemy, d)
		if d > want or (role in ["healer", "dps"] and not has_los(enemy)):
			var dir := enemy.global_position - global_position
			if in_sanctum and (not has_los(enemy) or absf(enemy.global_position.y - global_position.y) > 3.0 or not SanctumFollow.walk_supported(self, enemy.global_position)):
				dir = floor_path - global_position
			dir.y = 0
			wish = dir.normalized() * move_speed()
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 10.0, 0.0, 1.0))
		else:
			face_towards(enemy.global_position)
		auto_attack = role in ["pet", "tank"] or (role == "dps" and d <= MELEE_RANGE)
		auto_shoot = role == "dps" and d > MELEE_RANGE
	else:
		target = null
		auto_attack = false
		auto_shoot = false
		if in_combat and combat_timer > 3.0:
			leave_combat()
		# 跟随主人
		var fp := owner_unit.global_position + owner_unit.global_transform.basis * follow_offset
		var monastery: bool = Game.zone != null and Game.zone.zone_id == "sanctum"
		if monastery:
			fp = _sanctum_follow.target(self,owner_unit)
		else:
			_sanctum_follow.reset()
		var d2 := fp - global_position
		d2.y = 0
		var dist := d2.length()
		if dist > 60.0 and not monastery:
			global_position = fp + Vector3(0, 1, 0)
		elif dist > (.25 if monastery else 1.2):
			var behind := global_position.distance_to(owner_unit.global_position) if monastery else dist
			var sp := move_speed() * (1.3 if behind > 6.0 else 1.0)
			if owner_unit.mounted:
				sp *= 1.6
			# Small floor-path samples need full movement speed, capped by this
			# frame's remaining distance rather than braking at every sample.
			wish = d2.normalized() * minf(sp, dist/maxf(delta,.001) if monastery else dist*4.0)
			rotation.y = lerp_angle(rotation.y, atan2(-d2.x, -d2.z), clampf(delta * 8.0, 0.0, 1.0))
		else:
			rotation.y = lerp_angle(rotation.y, owner_unit.rotation.y, clampf(delta * 3.0, 0.0, 1.0))
	apply_gravity_and_move(delta, wish)
	_anim(delta)

func _anim(delta: float) -> void:
	if model:
		model.set_combat_ready(in_combat)
		model.animate(delta, {"speed": Vector2(velocity.x, velocity.z).length(), "casting": is_casting() and not casting.get("channel", false),
			"aiming": auto_shoot})
		if model is Avatar:
			model.set_ranged_mode(auto_shoot)

func _pick_enemy() -> Unit:
	var best: Unit = null
	var best_score := -1.0
	var ot: Unit = owner_unit.target
	for m in get_tree().get_nodes_in_group("mobs"):
		var mm: Unit = m
		if mm.dead or not is_enemy(mm):
			continue
		var engaged := false
		for u in mm.threat.keys():
			if is_instance_valid(u) and (u == owner_unit or u.owner_unit == owner_unit or u.faction == "companion"):
				engaged = true
				break
		if not engaged:
			continue
		var d := global_position.distance_to(mm.global_position)
		if d > 50.0:
			continue
		var score := 100.0 - d
		if mm == ot:
			score += 60.0
		if role == "tank" and mm.top_threat() != self:
			score += 80.0
		if score > best_score:
			best_score = score
			best = mm
	if best == null and ot != null and is_instance_valid(ot) and not ot.dead and is_enemy(ot) and owner_unit.in_combat and ot.in_combat:
		best = ot
	return best

func _use_abilities(enemy: Unit, d: float) -> void:
	for sid in spell_list:
		if _ability_cds.has(sid):
			continue
		var sp := DB.spell(sid)
		var tt: String = sp.get("target", "enemy")
		if tt == "friend":
			continue
		if sid in ["npc_taunt", "pet_growl"]:
			if enemy.top_threat() == self:
				continue
		if sid == "npc_thunder":
			var n := 0
			for m in get_tree().get_nodes_in_group("mobs"):
				if not m.dead and m.in_combat and m.global_position.distance_to(global_position) < 8.0:
					n += 1
			if n < 2:
				continue
		if tt == "enemy" and d > sp.get("range", MELEE_RANGE):
			continue
		if tt == "none" and d > 7.0:
			continue
		_ability_cds[sid] = sp.get("cd", 6.0) + randf_range(0.0, 1.0)
		face_towards(enemy.global_position)
		if begin_cast(sp, enemy if tt == "enemy" else self):
			return

func _heal_logic() -> bool:
	var party: Array = [owner_unit]
	for a in get_tree().get_nodes_in_group("allies"):
		if not a.dead:
			party.append(a)
	var low: Unit = null
	var lowp := 0.72
	for u in party:
		if not is_instance_valid(u) or u.dead:
			continue
		var p: float = u.hp / u.max_hp
		if p < lowp and global_position.distance_to(u.global_position) < 40.0:
			lowp = p
			low = u
	if low != null:
		if not _ability_cds.has("npc_renew") and low.get_aura("renew_npc").is_empty():
			_ability_cds["npc_renew"] = 3.0
			face_towards(low.global_position)
			begin_cast(DB.spell("npc_renew"), low)
			return true
		face_towards(low.global_position)
		return begin_cast(DB.spell("npc_heal"), low)
	return false

func take_damage(amt: float, school: String, src: Unit, crit: bool = false, sname: String = "", periodic: bool = false, bonus_threat: float = 0.0, mechanic: bool = false) -> void:
	super.take_damage(amt, school, src, crit, sname, periodic, bonus_threat, mechanic)

func add_threat(u: Unit, amount: float) -> void:
	super.add_threat(u, amount)

func deal_melee_damage(tgt: Unit, amt: float, sname: String = "", bonus_threat: float = 0.0, aoe: bool = false, white: bool = false, mechanic: bool = false) -> bool:
	if role == "tank":
		bonus_threat += amt * 1.8
	elif role == "pet":
		bonus_threat += amt * 1.2
	return super.deal_melee_damage(tgt, amt, sname, bonus_threat, aoe, white, mechanic)

func _on_death(_killer: Unit) -> void:
	_revive_t = 4.0
	Game.msg("%s倒下了！" % unit_name, Color("ff8080"))
	if role == "pet" and owner_unit and owner_unit.is_player:
		Game.msg("你的机械猎犬被击毁了。使用「召唤机械猎犬」来修复它。", Color("ffa040"))

func _revive() -> void:
	dead = false
	hp = max_hp
	if model and model.has_method("set_dead"):
		model.set_dead(false)
	hp_changed.emit()
	Vfx.column(get_parent(), global_position, Color("ffffff"), 3.0, 1.0)
	Game.msg("%s重新站了起来。" % unit_name, Color("80ff80"))
	add_to_group("units")
