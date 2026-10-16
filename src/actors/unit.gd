class_name Unit
extends CharacterBody3D
## 战斗单位基类：属性、资源、光环、施法、自动攻击、伤害/治疗、仇恨、死亡

signal died(unit)
signal hp_changed
signal power_changed
signal auras_changed
signal cast_started(spell_name: String, total: float, channel: bool)
signal cast_stopped(success: bool)
signal combat_changed(v: bool)
signal spell_resolved(sid: String, landed: bool)

const MELEE_RANGE := 2.4
const GRAVITY := 22.0

var unit_name := ""
var sub_name := ""
var level := 1
var faction := "hostile"
var unit_type := "humanoid"
var is_elite := false
var is_rare := false
var is_boss := false
var is_critter := false
var is_player := false
var max_hp := 100.0
var hp := 100.0
var power_type := "mana"
var max_power := 0.0
var power := 0.0
var combo := 0
var combo_target: Unit = null

# ===== 新战斗系统资源 =====
## 连招链状态（如"warrior_power_strike_hit"），用于解锁下一段技能
var combo_chain := ""
## 连招窗口剩余时间（秒），超时则链条重置
var combo_window := 0.0
## 通用连击计数（部分职业用，如盗贼影刃标记）
var combo_charges := 0

## 耐力（闪避资源），最大100
var stamina := 100.0
var max_stamina := 100.0
## 连续闪避计数（递增消耗用）
var dodge_streak := 0
var dodge_streak_timer := 0.0

## 职业专精资源（战士势能/法师充能/牧师双值/枪手热量）
var spec_resource := 0.0
var spec_resource_alt := 0.0
var max_spec_resource := 100.0
var spec_resource_type := ""  # "momentum"/"heat"/"holy_shadow"/"fire_charge"等
## 法师双充能（火焰/冰霜各0-3）
var fire_charges := 0
var frost_charges := 0

## 牧师双标记系统
var holy_marks := 0  # 圣光标记 (0-5)
var shadow_marks := 0  # 暗影标记 (0-5)

## 盾反窗口剩余秒数（>0 时下一次被近战攻击必定被格挡并触发反击）；riposte_dmg 为反击伤害区间，riposte_stun 为眩晕秒数
var riposte_window := 0.0
var riposte_dmg := Vector2.ZERO
var riposte_stun := 0.0
var riposte_gauge := ""        # 反击成功时增加的量表（圣骑士：神圣之力）
var riposte_gauge_add := 0.0
var riposte_weapon := "shield"

func _can_riposte_guard() -> bool:
	if riposte_weapon == "rapier":
		return spec == "duelist" and _main_weapon_type() == "rapier"
	return _has_shield()

func on_riposte_success(attacker: Unit) -> void:
	riposte_window = 0.0
	if attacker == null or not is_instance_valid(attacker) or attacker.dead:
		return
	var amt: float = randf_range(riposte_dmg.x, riposte_dmg.y) + float(stats.get("ap", 0.0)) * 0.3
	if riposte_gauge != "":
		gauge_add(riposte_gauge, riposte_gauge_add)
	if spec == "paladin":
		add_aura({"id": "pd_counter", "name": "盾反接续", "icon": "shield_wall", "dur": 6.0, "type": "buff"}, self)
		if model and model.has_method("play_skill_attack"):
			model.play_skill_attack(0.1, 0.25, "shield")
	if is_player:
		Vfx.float_text(self, "刃反！" if riposte_weapon == "rapier" else "盾反！", Color("ffd040"), 1.3, true)
		Sfx.play_at("block", global_position, -2.0)
	attacker.take_damage(amt, "physical", self, false, "盾反", false, 120.0)
	if riposte_stun > 0.0 and not attacker.is_boss:
		attacker.add_aura({"id": "riposte_stun", "name": "盾反", "icon": "shield", "dur": riposte_stun, "type": "debuff", "stun": true}, self)

## 通用量表（转职技能用）：名称 → 当前值。上限见 GAUGE_MAX；印记（整数层数）也存这里，带过期计时。
## 例：冰印记 "ice_mark"（0–5，施放火系技能后清空）、光量表 "light" / 雷量表 "bolt"（0–100）、怒气 "fury"（0–100）
var gauges := {}
var gauge_expire := {}
const GAUGE_MAX := {"ice_mark": 5, "ember": 3, "bloom": 3, "aim": 2, "light": 100, "bolt": 100, "fury": 100, "tide": 5, "holy_power": 5, "resonance": 100, "ammo": 6, "heat": 100}
const FURY_DECAY := 5.0   # 脱战后怒气量表每秒衰减
const FURY_ON_HIT_DEALT := 6.0   # 狂战士：普攻命中积攒的狂怒
const FURY_ON_HIT_TAKEN := 4.0   # 狂战士：每次受伤积攒的狂怒
var _guard_busy := false
const GAUGE_NAMES := {"ice_mark": "印记·冰", "ember": "余烬", "bloom": "水华", "aim": "瞄准", "light": "光量表", "bolt": "雷量表", "fury": "狂怒", "tide": "潮涌", "holy_power": "神圣之力", "resonance": "魔刃共鸣", "ammo": "弹仓", "heat": "热量"}
const GAUGE_TTL := {"ice_mark": 20.0, "tide": 15.0, "holy_power": 30.0}
signal gauges_changed

func gauge(name: String) -> float:
	return float(gauges.get(name, 0.0))

func gauge_add(name: String, amount: float) -> void:
	var mx: float = float(GAUGE_MAX.get(name, 100))
	gauges[name] = clampf(gauge(name) + amount, 0.0, mx)
	if amount > 0.0 and GAUGE_TTL.has(name):
		gauge_expire[name] = float(GAUGE_TTL[name])
	if gauges[name] <= 0.0:
		gauges.erase(name)
		gauge_expire.erase(name)
	gauges_changed.emit()

func gauge_clear(name: String) -> void:
	if gauges.has(name):
		gauges.erase(name)
		gauge_expire.erase(name)
		gauges_changed.emit()

## 量表转移：把 from 量表的 pct 比例转到 to 量表
func gauge_transfer(from: String, to: String, pct: float) -> void:
	var moved := minf(gauge(from) * clampf(pct, 0.0, 1.0), float(GAUGE_MAX.get(to, 100)) - gauge(to))
	if moved <= 0.0:
		return
	gauge_add(from, -moved)
	gauge_add(to, moved)

func _tick_gauges(delta: float) -> void:
	enchant_timer = maxf(0.0, enchant_timer - delta)
	_tick_action(delta)
	if gauge("heat") > 0.0 and not in_combat:
		gauge_add("heat", -delta * 12.0)
	if riposte_window > 0.0:
		riposte_window = maxf(0.0, riposte_window - delta)
	for k in gauge_expire.keys():
		gauge_expire[k] -= delta
		if gauge_expire[k] <= 0.0:
			gauge_clear(k)
	if gauges.has("fury") and not in_combat:
		gauge_add("fury", -FURY_DECAY * delta)

## 转职专精ID（15级选择，如"weapon_master"）
var spec := ""
var resource_profile := ""

func configure_job_resources(cls: String) -> void:
	var profile := cls + ":" + spec
	if resource_profile == profile:
		return
	resource_profile = profile
	spec_resource_type = ""
	spec_resource = 0
	spec_resource_alt = 0
	fire_charges = 0
	frost_charges = 0
	holy_marks = 0
	shadow_marks = 0
	combo = 0
	combo_target = null
	gauges.clear()
	gauge_expire.clear()
	if spec == "":
		power_type = str(DB.classes[cls]["power"])
		spec_resource_type = str({"warrior": "momentum", "priest": "holy_shadow", "rogue": "shadow_marks", "gunner": "heat"}.get(cls, ""))
		gauges_changed.emit()
		return
	power_type = "mana" if spec in ["dark_mage", "elementalist", "radiant"] else ("energy" if spec == "assassin" else "none")
	if power_type == "none":
		power = 0
		max_power = 0
	if spec == "marksman":
		gauge_add("ammo", 6)
	if power_type == "energy":
		power = 100
	gauges_changed.emit()

## 被动技能列表（自动生效的技能ID数组）
var passive_skills: Array = []
## 特性列表（条件触发效果的trait定义）
var traits: Array = []

## 无敌帧剩余时间（闪避期间）
var invincible_frames := 0.0

var enchant_timer := 0.0
var action_lock := 0.0
var pending_action: Dictionary = {}
var motion_tween: Tween
var motion_active := false

func _tick_action(delta: float) -> void:
	action_lock = maxf(0.0, action_lock - delta)
	if pending_action.is_empty():
		return
	if not can_act():
		cancel_action()
		return
	pending_action["remaining"] -= delta
	if pending_action["remaining"] > 0.0:
		return
	var a := pending_action
	pending_action = {}
	var tgt: Unit = a.get("target")
	var sp: Dictionary = a["sp"]
	if sp.get("target", "") == "enemy" and (not is_instance_valid(tgt) or tgt.dead or edge_dist(tgt) > spell_range(sp) or not has_los(tgt)):
		return
	if not _can_pay(sp):
		return
	_commit_skill(sp)
	_deliver(sp, tgt)

func cancel_action() -> void:
	pending_action = {}
	action_lock = 0.0
	if model and model.has_method("cancel_skill"):
		model.cancel_skill()
	if motion_tween and motion_tween.is_valid():
		motion_tween.kill()
	motion_active = false

func reset_job_state() -> void:
	cancel_action()
	stop_cast()
	gauges.clear()
	gauge_expire.clear()
	riposte_window = 0.0
	combo = 0
	combo_target = null
	combo_chain = ""
	combo_window = 0.0
	fire_charges = 0
	frost_charges = 0
	holy_marks = 0
	shadow_marks = 0
	spec_resource = 0.0
	spec_resource_alt = 0.0
	enchant_timer = 0.0
	invincible_frames = 0.0
	next_melee = {}
	auto_attack = false
	auto_shoot = false
	_remove_auras_by(func(a): return a.get("src") == self and a["def"].get("type", "") == "buff")
	gauges_changed.emit()

var stats := {}
var base_stats := {}
## 天赋加成汇总（仅玩家；由 Player.recalc_stats 写入，见 src/core/talents.gd::mods）
var talent_mods: Dictionary = {}
var wdmg := Vector2(1, 2)
var wspeed := 2.0
var off_wdmg := Vector2.ZERO
var off_wspeed := 0.0
var rdmg := Vector2.ZERO
var rspeed := 2.6
var base_speed := 7.0
var radius := 0.45
var auras: Array = []
var target: Unit = null
var in_combat := false
var combat_timer := 0.0
var threat := {}
var cooldowns := {}
var gcd := 0.0
var gcd_total := 1.5
var casting := {}
var swing_timer := 0.0
var off_swing_timer := 0.0
var ranged_timer := 0.0
var auto_attack := false
var auto_shoot := false
var next_melee := {}
var dead := false
var model: Node3D
var since_mana_spend := 100.0
var school_lock := {}
var victory_window := 0.0
var _regen_acc := 0.0
var owner_unit: Unit = null  # 宠物/同伴的主人
var tapped_by_player := false
var spawn_pos := Vector3.ZERO
var kb_velocity := Vector3.ZERO
var mounted := false
## 当前坐骑 id（见 src/data/data_mounts.gd）与它的速度加成；默认 +60%
var mount_id := ""
var mount_bonus := 0.6
var sitting := false
var aiming := false
var last_attacker: Unit = null

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(52)
	add_to_group("units")

# ================================================================ 状态
func is_alive() -> bool:
	return not dead

func has_aura_flag(flag: String) -> bool:
	for a in auras:
		if a["def"].get(flag, false):
			return true
	return false

func is_stunned() -> bool:
	return has_aura_flag("stun")

func is_incap() -> bool:
	return has_aura_flag("incap")

func is_feared() -> bool:
	return has_aura_flag("fear")

func is_rooted() -> bool:
	return has_aura_flag("root") or is_stunned() or is_incap()

func is_stealthed() -> bool:
	return has_aura_flag("stealth")

func break_stealth() -> void:
	for a in auras.duplicate():
		if a["def"].get("stealth", false):
			remove_aura(str(a["def"].get("id", "")))

func can_act() -> bool:
	return not dead and not is_stunned() and not is_incap() and not is_feared()

func aura_mod(key: String) -> float:
	var v := 0.0
	for a in auras:
		var m: Dictionary = a["def"].get("mods", {})
		if m.has(key):
			v += float(m[key]) * a.get("stacks", 1)
	return v

func aura_stat(key: String) -> float:
	var v := 0.0
	for a in auras:
		var m: Dictionary = a["def"].get("stats", {})
		if m.has(key):
			v += float(m[key])
	return v

## 天赋加成：标量键（dot_pct / heal_pct / dmg_taken / threat / speed / regen / haste / ranged_dmg / hp_pct …）
func tmod(key: String) -> float:
	if talent_mods.is_empty():
		return 0.0
	return float(talent_mods.get(key, 0.0))

## 天赋加成：映射键的单个子键（stats / stats_pct / school_dmg / cost_pct / cd_pct）
func tmod_sub(key: String, sub: String) -> float:
	if talent_mods.is_empty():
		return 0.0
	var m: Dictionary = talent_mods.get(key, {})
	return float(m.get(sub, 0.0))

## 天赋加成：映射键的多个子键之和（用于 技能 id + 学派 + "*" 的叠加）
func tmod_any(key: String, subs: Array) -> float:
	if talent_mods.is_empty():
		return 0.0
	var m: Dictionary = talent_mods.get(key, {})
	var v := 0.0
	for s in subs:
		v += float(m.get(s, 0.0))
	return v

## 转职伤害乘区（按学派，含 "*" 通用）；被动来自 talent_mods，特性按当前目标 / 自身状态动态求值。
## 下限 0.2 防止异常数据造成负伤。victim 为本次伤害的承受者（用于「目标低血 / 减速」类特性）。
func talent_dmg_mul(school: String, victim: Unit = null) -> float:
	if talent_mods.is_empty():
		return 1.0
	var m: Dictionary = talent_mods.get("school_dmg", {})
	var v := float(m.get(school, 0.0)) + float(m.get("*", 0.0))
	if is_player:
		var tm: Dictionary = Specs.trait_mods(self, victim if victim != null else target)
		var ts: Dictionary = tm.get("school_dmg", {})
		v += float(ts.get(school, 0.0)) + float(ts.get("*", 0.0))
	return maxf(0.2, 1.0 + v)

func get_aura(id: String) -> Dictionary:
	for a in auras:
		if a["def"].get("id", "") == id:
			return a
	return {}

func move_speed() -> float:
	if is_rooted():
		return 0.0
	var m := 1.0 + aura_mod("speed") + tmod("speed")
	if mounted:
		m += mount_bonus
	return base_speed * maxf(0.3, m)

func attack_haste() -> float:
	return maxf(0.3, 1.0 + aura_mod("attack_speed") + tmod("haste"))

func forward_dir() -> Vector3:
	return -global_transform.basis.z

## 获取当前移动方向输入（用于方向技能）
func get_move_direction() -> String:
	if not is_player:
		return "forward"  # NPC默认前向

	# 访问Player的_move_input
	if not has_method("_move_input"):
		return "forward"

	var move_input: Variant = get("_move_input")
	if move_input == null or move_input.length() < 0.1:
		return "none"

	var fwd: float = move_input.y
	var strafe: float = move_input.x

	# 优先判断前后
	if abs(fwd) > abs(strafe):
		return "forward" if fwd > 0 else "backward"
	else:
		return "right" if strafe > 0 else "left"

func is_facing(p: Vector3, arc_dot: float = 0.0) -> bool:
	var d := p - global_position
	d.y = 0
	if d.length_squared() < 0.01:
		return true
	var f := forward_dir()
	f.y = 0
	return f.normalized().dot(d.normalized()) >= arc_dot

func is_behind(other: Unit) -> bool:
	var d := global_position - other.global_position
	d.y = 0
	var f := other.forward_dir()
	f.y = 0
	return f.normalized().dot(d.normalized()) < -0.2

func dist_to(u: Node3D) -> float:
	return global_position.distance_to(u.global_position)

func flat_dist_to(u: Node3D) -> float:
	return U.flat_dist(global_position, u.global_position)

func edge_dist(u: Unit) -> float:
	return maxf(0.0, flat_dist_to(u) - radius - u.radius) + absf(global_position.y - u.global_position.y) * 0.3

func chest_pos() -> Vector3:
	var h := 1.2
	if model and model.has_method("height"):
		h = model.height() * 0.6
	return global_position + Vector3(0, h, 0)

func head_pos() -> Vector3:
	var h := 1.8
	if model and model.has_method("height"):
		h = model.height() + 0.25
	return global_position + Vector3(0, h, 0)

## 是否敌对（可以攻击）
func is_enemy(o: Unit) -> bool:
	if o == null or o == self:
		return false
	var a := _side()
	var b := o._side()
	if a == b:
		return false
	if a == "neutral_side" or b == "neutral_side":
		return a == "players" or b == "players"
	return true

func _side() -> String:
	match faction:
		"player", "friendly", "pet", "companion":
			return "players"
		"neutral":
			return "neutral_side"
	return "hostile"

func is_friend(o: Unit) -> bool:
	return o != null and _side() == o._side()

# ================================================================ 资源
func set_hp(v: float) -> void:
	hp = clampf(v, 0.0, max_hp)
	hp_changed.emit()

func add_power(v: float) -> void:
	if max_power <= 0.0:
		return
	power = clampf(power + v, 0.0, max_power)
	power_changed.emit()

func _rage_conv() -> float:
	return 0.0091107836 * level * level + 3.225598133 * level + 4.2652911

# ================================================================ 循环
func _physics_process(delta: float) -> void:
	if dead:
		return
	_tick_timers(delta)
	_tick_auras(delta)
	_tick_cast(delta)
	_tick_auto(delta)
	_tick_regen(delta)

func _tick_timers(delta: float) -> void:
	_tick_gauges(delta)
	if gcd > 0.0:
		gcd = maxf(0.0, gcd - delta)
	for k in cooldowns.keys():
		cooldowns[k] -= delta
		if cooldowns[k] <= 0.0:
			cooldowns.erase(k)
	for k in school_lock.keys():
		school_lock[k] -= delta
		if school_lock[k] <= 0.0:
			school_lock.erase(k)
	since_mana_spend += delta
	if victory_window > 0.0:
		victory_window -= delta
	combat_timer += delta

	# 新战斗系统计时器
	if combo_window > 0.0:
		combo_window -= delta
		if combo_window <= 0.0:
			combo_chain = ""
			combo_charges = 0

	if dodge_streak_timer > 0.0:
		dodge_streak_timer -= delta
		if dodge_streak_timer <= 0.0:
			dodge_streak = 0

	if invincible_frames > 0.0:
		invincible_frames -= delta

func _tick_auras(delta: float) -> void:
	var changed := false
	var i := 0
	while i < auras.size():
		var a: Dictionary = auras[i]
		var d: Dictionary = a["def"]
		if d.has("tick"):
			a["tick_t"] -= delta
			if a["tick_t"] <= 0.0:
				a["tick_t"] += d["tick"]["interval"]
				_aura_tick(a)
				if dead:
					return
		if d.get("dur", 0.0) > 0.0:
			a["rem"] -= delta
			if a["rem"] <= 0.0:
				auras.remove_at(i)
				changed = true
				_on_aura_removed(a)
				continue
		i += 1
	if changed:
		auras_changed.emit()
		recalc_stats()

func _aura_tick(a: Dictionary) -> void:
	var tk: Dictionary = a["def"]["tick"]
	var src: Unit = a.get("src")
	if src != null and not is_instance_valid(src):
		src = null
	var ls: float = tk.get("level_scale", 0.0)
	if tk.has("dmg"):
		var amt: float = float(tk["dmg"]) + ls * (a.get("src_level", 1) - 1)
		if src:
			amt += src.stats.get("sp", 0.0) * tk.get("coef", 0.0) + src.stats.get("rap", 0.0) * tk.get("rap_coef", 0.0)
			amt *= (1.0 + src.aura_mod("dmg_done")) * src.talent_dmg_mul(tk.get("school", "physical"), self) * maxf(0.2, 1.0 + src.tmod("dot_pct"))
		take_damage(maxf(1.0, round(amt)), tk.get("school", "physical"), src, false, a["def"].get("name", ""), true)
		if src and tk.has("caster_energy") and not get_aura(str(tk.get("requires_aura", ""))).is_empty():
			src.add_power(float(tk["caster_energy"]))
	if tk.has("heal"):
		var hamt: float = float(tk["heal"]) + ls * (a.get("src_level", 1) - 1)
		if src:
			hamt += src.stats.get("sp", 0.0) * tk.get("coef", 0.0)
		receive_heal(round(hamt), src, false, a["def"].get("name", ""))
	if tk.has("heal_pct"):
		var before := hp
		receive_heal(max_hp * float(tk["heal_pct"]), src, false, a["def"].get("name", ""))
		if hp > before and src and tk.has("caster_power_pct_on_heal"):
			src.add_power(src.max_power * float(tk["caster_power_pct_on_heal"]))
	if tk.has("rage"):
		add_power(tk["rage"])
	if tk.has("hp_pct"):
		receive_heal(max_hp * tk["hp_pct"], self, false, "")

func _on_aura_removed(a: Dictionary) -> void:
	var d: Dictionary = a["def"]
	if d.get("sheep", false) and model:
		_restore_model()
	if d.get("stealth", false) and is_player:
		_set_stealth_visual(is_stealthed())
		if d.get("id", "") == "stealth":
			cooldowns["stealth"] = DB.spell("stealth").get("cd", 10.0)
	if d.get("food", false) or d.get("drink", false):
		pass

func _tick_cast(delta: float) -> void:
	if casting.is_empty():
		return
	if not can_act():
		stop_cast(false)
		return
	var tgt: Unit = casting.get("target")
	if tgt != null and (not is_instance_valid(tgt) or tgt.dead) and casting["sp"].get("target", "") in ["enemy", "friend"]:
		stop_cast(false)
		return
	casting["elapsed"] += delta
	if casting["channel"]:
		var ticks: int = casting["sp"].get("ticks", 3)
		var tick_len: float = casting["total"] / ticks
		while casting["ticks_done"] < ticks and casting["elapsed"] >= tick_len * (casting["ticks_done"] + 1):
			casting["ticks_done"] += 1
			_channel_tick()
			if casting.is_empty():
				return
		if casting["elapsed"] >= casting["total"]:
			casting = {}
			cast_stopped.emit(true)
	else:
		if casting["elapsed"] >= casting["total"]:
			var c := casting
			casting = {}
			cast_stopped.emit(true)
			_finish_cast(c)

func _channel_tick() -> void:
	var c := casting
	var tgt: Unit = c.get("target")
	if tgt == null or not is_instance_valid(tgt) or tgt.dead:
		stop_cast(false)
		return
	if tgt != self and (edge_dist(tgt) > spell_range(c["sp"]) or not has_los(tgt)):
		stop_cast(false)
		return
	_deliver(c["sp"], tgt)

func _tick_auto(delta: float) -> void:
	if is_player and spec in ["gadgeteer", "marksman"]:
		auto_attack = false
		auto_shoot = false
		return
	var hs := attack_haste()
	if swing_timer > 0.0:
		swing_timer -= delta * hs
	if off_swing_timer > 0.0:
		off_swing_timer -= delta * hs
	if ranged_timer > 0.0:
		ranged_timer -= delta * hs
	if action_lock > 0.0 or motion_active:
		return
	if not can_act() or not casting.is_empty() and not casting.get("channel", false):
		return
	if auto_attack and target != null and is_instance_valid(target) and not target.dead:
		if edge_dist(target) <= MELEE_RANGE - 0.6 + 0.6:
			if is_player and not is_facing(target.global_position, 0.0):
				pass
			else:
				if swing_timer <= 0.0:
					swing_timer = wspeed
					melee_swing(target, false)
				if off_wspeed > 0.0 and off_swing_timer <= 0.0:
					off_swing_timer = off_wspeed
					melee_swing(target, true)
	elif auto_shoot and target != null and is_instance_valid(target) and not target.dead:
		if ranged_timer <= 0.0 and _can_autoshoot():
			ranged_timer = rspeed
			ranged_shot(target)

func _can_autoshoot() -> bool:
	return true

func _tick_regen(delta: float) -> void:
	if power_type == "energy":
		add_power(10.0 * delta)
	_regen_acc += delta
	if _regen_acc < 1.0:
		return
	_regen_acc -= 1.0
	var spi: float = stats.get("spi", 10.0)
	var rmul := maxf(0.2, 1.0 + tmod("regen"))
	if not in_combat and hp < max_hp:
		set_hp(hp + maxf(1.0, (level * 0.35 + spi * 0.18) * rmul))

	# 耐力回复
	if stamina < max_stamina:
		var stamina_regen := 10.0 if in_combat else 20.0
		stamina = minf(max_stamina, stamina + stamina_regen)

	# 职业专精资源自然变化
	match spec_resource_type:
		"heat":  # 枪手热量自然冷却
			if spec_resource > 0.0:
				spec_resource = maxf(0.0, spec_resource - 10.0)
		"momentum":  # 战士势能脱战归零
			if not in_combat and spec_resource > 0.0:
				spec_resource = maxf(0.0, spec_resource - 5.0)

	match power_type:
		"mana":
			if power < max_power:
				var r := (12.0 + spi * 0.25) * 0.5
				if is_player:
					r = max_power * (0.005 if in_combat else 0.08)
				elif since_mana_spend < 5.0:
					r = 0.0
				add_power(r * rmul)
		"energy":
			pass
		"rage":
			if not in_combat and power > 0.0:
				add_power(-2.0)

# ================================================================ 战斗状态
func enter_combat() -> void:
	combat_timer = 0.0
	if not in_combat:
		in_combat = true
		combat_changed.emit(true)
		_on_combat_changed(true)
		# 战斗打断进食与潜行之外的状态
		_remove_auras_by(func(a): return a["def"].get("food", false) or a["def"].get("drink", false))

func leave_combat() -> void:
	if in_combat:
		in_combat = false
		combat_changed.emit(false)
		_on_combat_changed(false)

func _on_combat_changed(_v: bool) -> void:
	pass

func add_threat(u: Unit, amount: float) -> void:
	if u == null or not is_instance_valid(u) or u.dead or dead:
		return
	if not is_enemy(u):
		return
	amount *= maxf(0.0, 1.0 + u.tmod("threat"))
	threat[u] = threat.get(u, 0.0) + amount
	enter_combat()
	u.enter_combat()

func top_threat() -> Unit:
	var best: Unit = null
	var bv := -1.0
	for u in threat.keys():
		if not is_instance_valid(u) or u.dead:
			threat.erase(u)
			continue
		if threat[u] > bv:
			bv = threat[u]
			best = u
	return best

# ================================================================ 光环
func add_aura(def: Dictionary, src: Unit) -> void:
	if dead:
		return
	if is_boss and (def.get("stun", false) or def.get("incap", false) or def.get("fear", false) or def.get("root", false)):
		return
	var id: String = def.get("id", def.get("name", ""))
	for a in auras:
		if a["def"].get("id", "") == id:
			if def.get("toggle", false):
				return
			a["rem"] = _scaled_dur(def, src)
			a["def"] = def
			a["src_level"] = src.level if src else 1
			a["src"] = src
			if def.has("absorb") or def.has("absorb_pct"):
				a["absorb"] = _absorb_amount(def, src)
			auras_changed.emit()
			return
	var a2 := {"def": def, "src": src, "rem": _scaled_dur(def, src), "tick_t": def.get("tick", {}).get("interval", 0.0), "stacks": 1,
		"src_level": src.level if src else 1}
	if def.has("absorb") or def.has("absorb_pct"):
		a2["absorb"] = _absorb_amount(def, src)
	auras.append(a2)
	if def.get("sheep", false):
		_polymorph_model()
	if def.get("stealth", false) and is_player:
		_set_stealth_visual(true)
	if def.get("stun", false) or def.get("incap", false) or def.get("fear", false):
		stop_cast(false)
		Vfx.float_text(self, def.get("name", ""), Color("ffd040"), 0.8)
	auras_changed.emit()
	recalc_stats()

## 光环实际持续时间：施法方的天赋延长（dur_pct）。不修改共享的 def，只影响这一次实例。
func _scaled_dur(def: Dictionary, src: Unit) -> float:
	var d: float = def.get("dur", 0.0)
	if d > 0.0 and src != null and is_instance_valid(src):
		d *= maxf(0.2, 1.0 + src.tmod("dur_pct"))
	return d

func _absorb_amount(def: Dictionary, src: Unit) -> float:
	var v: float = def.get("absorb", 0) + max_hp * float(def.get("absorb_pct", 0.0))
	if def.has("absorb_scale") and src:
		v += def["absorb_scale"] * src.level
	return v

func remove_aura(id: String) -> void:
	for i in auras.size():
		if auras[i]["def"].get("id", "") == id:
			var a = auras[i]
			auras.remove_at(i)
			_on_aura_removed(a)
			auras_changed.emit()
			recalc_stats()
			return

func _remove_auras_by(pred: Callable) -> void:
	var changed := false
	var i := 0
	while i < auras.size():
		if pred.call(auras[i]):
			var a = auras[i]
			auras.remove_at(i)
			_on_aura_removed(a)
			changed = true
		else:
			i += 1
	if changed:
		auras_changed.emit()
		recalc_stats()

func clear_auras() -> void:
	for a in auras:
		_on_aura_removed(a)
	auras.clear()
	auras_changed.emit()

func _polymorph_model() -> void:
	if model:
		model.visible = false
	var sheep := CreatureModel.new()
	sheep.name = "SheepModel"
	sheep.setup("sheep", Color.WHITE, Color.WHITE)
	add_child(sheep)

func _restore_model() -> void:
	var s := get_node_or_null("SheepModel")
	if s:
		s.queue_free()
	if model:
		model.visible = true

func _set_stealth_visual(on: bool) -> void:
	if model:
		_set_transparency(model, 0.55 if on else 0.0)

func _set_transparency(n: Node, v: float) -> void:
	if n is GeometryInstance3D:
		n.transparency = v
	for c in n.get_children():
		_set_transparency(c, v)

func recalc_stats() -> void:
	pass

# ================================================================ 施法
func is_casting() -> bool:
	return not casting.is_empty()

func stop_cast(_success: bool = false) -> void:
	if casting.is_empty():
		return
	casting = {}
	cast_stopped.emit(false)

func spell_range(sp: Dictionary) -> float:
	return sp.get("range", MELEE_RANGE if sp.get("target", "") == "enemy" else 40.0)

func is_interrupt_skill(sp: Dictionary) -> bool:
	return sp.get("effects", []).any(func(effect): return effect.get("type", "") == "interrupt")

func cooldown_remaining(sp: Dictionary) -> float:
	var remaining: float = cooldowns.get(str(sp.get("id", "")), 0.0)
	if is_player and is_interrupt_skill(sp):
		remaining = maxf(remaining, float(cooldowns.get("shared_interrupt", 0.0)))
	return remaining

## 校验施法，返回错误文本（空字符串为可以施放）
func check_cast(sp: Dictionary, tgt: Unit) -> String:
	if dead:
		return "你已经死了。"
	if not can_act():
		return "你现在无法这么做。"
	var sid: String = sp["id"]
	if is_player and not Specs.spell_allowed(sid, spec):
		return "转职后请使用当前职业的技能。"
	if action_lock > 0.0 and sp.get("gcd", 1.5) > 0.0:
		return "动作尚未结束。"
	if is_casting() and sid != "dodge_roll":
		return "你正在施放另一个法术。"
	for effect in sp.get("effects", []):
		if effect.get("type", "") in ["dodge", "charge", "blink", "leap_back", "teleport_behind"]:
			if is_rooted() or motion_active:
				return "现在不能使用位移技能。"
			if is_instance_valid(tgt) and tgt != self and absf(tgt.global_position.y - global_position.y) > 2.0:
				return "目标位于不同高度。"
	if cooldown_remaining(sp) > 0.0:
		return "技能还没有准备好。"
	if sp.get("gcd", 1.5) > 0.0 and gcd > 0.0:
		return "技能还没有准备好。"
	if school_lock.has(sp.get("school", "")):
		return "你无法施放该系法术。"
	var cost := spell_cost(sp)
	if cost > power + 0.01 and max_power > 0.0:
		return {"mana": "法力值不足。", "rage": "怒气不足。", "energy": "能量不足。"}.get(power_type, "资源不足。")
	var extra := _extra_cost(sp)
	if extra.get("stamina", 0.0) > stamina + 0.01:
		return "耐力不足。"
	if spec_resource_type != "" and extra.get(spec_resource_type, 0.0) > spec_resource + 0.01:
		return "势能不足。" if spec_resource_type == "momentum" else "专精资源不足。"
	if sp.get("no_combat", false) and in_combat:
		return "你正处于战斗中！"

	# 新战斗系统校验
	var req: Dictionary = sp.get("requires", {})

	# 连招链校验
	if req.has("combo_chain"):
		var chains: Array = req["combo_chain"] if req["combo_chain"] is Array else [req["combo_chain"]]
		if combo_chain not in chains:
			return "需要先使用前置技能。"

	# 专精资源校验
	if req.has("spec_resource_min"):
		if spec_resource < req["spec_resource_min"]:
			return "专精资源不足。"

	# 充能校验（法师）
	if req.has("fire_charges_min") and fire_charges < req["fire_charges_min"]:
		return "火焰充能不足。"
	if req.has("frost_charges_min") and frost_charges < req["frost_charges_min"]:
		return "冰霜充能不足。"
	if req.has("min_charges"):
		var total_charges: int = fire_charges + frost_charges
		if total_charges < req["min_charges"]:
			return "充能不足。"

	# 标记校验（牧师）
	if req.has("holy_marks_min") and holy_marks < req["holy_marks_min"]:
		return "圣光标记不足。"
	if req.has("shadow_marks_min") and shadow_marks < req["shadow_marks_min"]:
		return "暗影标记不足。"

	# 自身光环校验
	if req.has("has_aura_self"):
		var aura_id: String = req["has_aura_self"]
		if get_aura(aura_id).is_empty():
			return "需要特定状态。"
	if req.has("no_aura_self") and not get_aura(str(req["no_aura_self"])).is_empty():
		return "该状态已经生效。"

	# 盗贼位置校验
	if req.has("stealth_or_behind"):
		var has_stealth := is_stealthed()
		var is_behind_target := false
		if is_instance_valid(tgt):
			is_behind_target = is_behind(tgt)
		if not has_stealth and not is_behind_target:
			return "需要潜行或在目标背后。"

	# 双持校验
	if req.has("dual_wield"):
		if off_wspeed <= 0.0:
			return "需要双持武器。"
	if req.get("dual_daggers", false) and (_main_weapon_type() != "dagger" or _off_weapon_type() != "dagger"):
		return "需要装备双匕首。"
	for gname in req.get("gauge_max", {}):
		if gauge(str(gname)) > float(req["gauge_max"][gname]):
			return "弹仓已满。" if gname == "ammo" else "热量过高，需要散热。"

	# 转职专精校验
	if sp.has("requires_spec") and spec != sp["requires_spec"]:
		return "需要特定专精。"
	if req.get("shield", false) and not _has_shield():
		return "需要装备盾牌。"
	# 量表校验：gauge_cost = {"gauge": 名称, "amount": 消耗}（施放时扣除）；requires.gauge_min = {名称: 最低值}
	for key in gauge_costs(sp):
		if gauge(key) < float(gauge_costs(sp)[key]) - 0.001:
			return "%s不足。" % GAUGE_NAMES.get(key, "资源")
	for gname in req.get("gauge_min", {}):
		if gauge(str(gname)) < float(req["gauge_min"][gname]) - 0.001:
			return "%s不足。" % GAUGE_NAMES.get(str(gname), "资源")
	
	# 耐力校验
	if req.has("stamina_min"):
		var stamina_cost: float = req["stamina_min"]
		if dodge_streak > 0:
			stamina_cost += dodge_streak * 20.0
		if stamina < stamina_cost:
			return "耐力不足。"

	# 原有校验
	if req.get("combo", false) and (combo <= 0 or combo_target != tgt):
		return "需要连击点数。"
	if req.get("stealth", false) and not is_stealthed():
		return "你必须处于潜行状态。"
	if req.get("victory", false) and victory_window <= 0.0:
		return "现在还不能使用这个技能。"
	if req.get("ranged_weapon", false) and rdmg == Vector2.ZERO:
		return "需要装备远程武器。"
	if req.has("weapon") and _main_weapon_type() != req["weapon"]:
		return "需要装备%s。" % DataItems.TYPE_NAMES.get(req["weapon"], "特定武器")
	var tt: String = sp.get("target", "self")
	if tt == "enemy" or tt == "ground_enemy":
		if tgt == null or not is_instance_valid(tgt) or tgt.dead:
			return "你没有目标。"
		if not is_enemy(tgt):
			return "无效的目标。"
		var d := edge_dist(tgt)
		var rng: float = spell_range(sp)
		if d > rng:
			return "距离太远。"
		if d < sp.get("min_range", 0.0):
			return "距离太近。"
		if is_player and not is_facing(tgt.global_position, 0.0):
			return "你必须面对目标。"
		if req.get("behind", false) and not is_behind(tgt):
			return "你必须在目标背后。"
		if req.get("target_no_combat", false) and tgt.in_combat:
			return "目标正处于战斗中。"
		if req.get("poly_target", false) and not tgt.unit_type in ["humanoid", "beast", "critter"]:
			return "无效的目标。"
		if tgt.is_boss and (sp.get("id", "") in ["polymorph", "sap", "gouge"]):
			return "目标免疫。"
		if is_player and d > 6.0 and not has_los(tgt):
			return "目标不在视野中。"
	elif tt == "friend":
		var ft := tgt if (tgt != null and is_instance_valid(tgt) and is_friend(tgt) and not tgt.dead) else self
		if sid == "pd_guard" and ft == self:
			return "需要选择一名队友。"
		if edge_dist(ft) > spell_range(sp):
			return "距离太远。"
		if ft != self and not has_los(ft):
			return "目标不在视野中。"
		if req.has("no_aura_target") and not ft.get_aura(req["no_aura_target"]).is_empty():
			return "目标无法接受这个效果。"
	elif tt == "self" and req.has("no_aura_target") and not get_aura(req["no_aura_target"]).is_empty():
		return "无法这么做。"
	return ""

func has_los(tgt: Unit) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(chest_pos(), tgt.chest_pos(), 1)
	q.exclude = [get_rid(), tgt.get_rid()]
	var r := space.intersect_ray(q)
	return r.is_empty()

func _main_weapon_type() -> String:
	return ""

func _off_weapon_type() -> String:
	return ""

## 是否持盾；玩家看副手装备，其他单位默认没有（测试可用 force_shield 覆盖）
var force_shield := false
func _has_shield() -> bool:
	return force_shield

func spell_cost(sp: Dictionary) -> float:
	var raw: Variant = sp.get("cost", 0)
	# 字典形式 {"momentum": 15, "rage": 30}：这里只返回主资源（power_type）部分
	var c := float(raw.get(power_type, 0)) if raw is Dictionary else float(raw)
	c += max_power * float(sp.get("cost_pct_max", 0.0))
	var cg: Dictionary = sp.get("cost_by_gauge", {})
	if not cg.is_empty() and gauge(cg["gauge"]) >= float(cg["threshold"]):
		c *= float(cg.get("mul", 1.0))
	if c > 0.0 and not talent_mods.is_empty():
		c *= maxf(0.2, 1.0 + tmod_any("cost_pct", [sp.get("id", ""), sp.get("school", ""), "*"]))
	return c

func gauge_costs(sp: Dictionary) -> Dictionary:
	var result: Dictionary = sp.get("gauge_costs", {}).duplicate()
	var gc: Dictionary = sp.get("gauge_cost", {})
	if not gc.is_empty():
		result[str(gc["gauge"])] = float(gc["amount"])
	if sp.has("gauge_cost_by_aura") and not get_aura(str(sp["gauge_cost_by_aura"])).is_empty():
		result.clear()
	return result

func _can_pay(sp: Dictionary) -> bool:
	if spell_cost(sp) > power + 0.01:
		return false
	for key in gauge_costs(sp):
		if gauge(key) + 0.001 < float(gauge_costs(sp)[key]):
			return false
	return true

## 咏唱时间。cast_by_gauge = {"gauge": 量表名, "per": 每点缩短比例, "max": 最大缩短比例}：按量表数值缩短。
func cast_time(sp: Dictionary) -> float:
	var t := float(sp.get("cast", 0.0)) * maxf(0.3, 1.0 - aura_mod("cast_speed") - tmod("cast_pct"))
	var cg: Dictionary = sp.get("cast_by_gauge", {})
	if not cg.is_empty():
		var cut := minf(float(cg.get("max", 0.5)), gauge(str(cg.get("gauge", ""))) * float(cg.get("per", 0.1)))
		if cg.has("threshold"):
			cut = float(cg.get("max", 0.5)) if gauge(str(cg["gauge"])) >= float(cg["threshold"]) else 0.0
		t *= 1.0 - cut
	var ca: Dictionary = sp.get("cast_by_aura", {})
	if not ca.is_empty() and not get_aura(str(ca["id"])).is_empty():
		t *= float(ca.get("mul", 1.0))
	return t

## 开始施放（已通过校验）
func begin_cast(sp: Dictionary, tgt: Unit) -> bool:
	var e := check_cast(sp, tgt)
	if e != "":
		_cast_error(e)
		return false
	sp = sp.duplicate(true)
	sp["_stealth_open"] = is_stealthed()
	if sp.get("id", "") == "dodge_roll":
		stop_cast()
		cancel_action()
	if sp.get("remove_aura_on_cast", "") != "":
		remove_aura(str(sp["remove_aura_on_cast"]))
	var tt: String = sp.get("target", "self")
	if tt == "friend":
		if tgt == null or not is_instance_valid(tgt) or not is_friend(tgt) or tgt.dead:
			tgt = self
	elif tt == "self" or tt == "none":
		tgt = self
	if sp.get("next_melee", false):
		next_melee = sp
		if target == null or target != tgt:
			target = tgt
		auto_attack = true
		return true
	var g: float = sp.get("gcd", 1.5) * maxf(0.6, 1.0 - aura_mod("skill_haste"))
	if g > 0.0:
		gcd = g
		gcd_total = g
	# 潜行状态下施放会解除（除特定技能）
	if is_stealthed() and sp.get("id", "") != "stealth" and not sp.get("keep_stealth", false):
		break_stealth()
	if sitting:
		set_sitting(false)
	var ct := cast_time(sp)
	var ch: float = sp.get("channel", 0.0)
	if ch > 0.0:
		_pay(sp)
		casting = {"sp": sp, "target": tgt, "elapsed": 0.0, "total": ch, "channel": true, "ticks_done": 0}
		cast_started.emit(sp["name"], ch, true)
		_start_cd(sp)
		_cast_sound(sp)
		CombatPresentation.anticipate(self, sp, tgt)
		return true
	if ct > 0.0:
		casting = {"sp": sp, "target": tgt, "elapsed": 0.0, "total": ct, "channel": false}
		cast_started.emit(sp["name"], ct, false)
		_cast_telegraph(sp, ct)
		CombatPresentation.anticipate(self, sp, tgt)
		if sp.get("school", "") in ["fire", "frost", "arcane", "holy", "shadow", "nature", "water", "lightning", "light"]:
			Sfx.play_at("cast", global_position, -18.0)
		return true
	_finish_cast({"sp": sp, "target": tgt})
	return true

func _cast_error(e: String) -> void:
	pass

func _cast_telegraph(sp: Dictionary, ct: float) -> void:
	if sp.has("telegraph"):
		Vfx.telegraph(get_parent(), global_position, sp["telegraph"], ct, self)

## 字典形式 cost 里除主资源（power_type）以外的部分：势能 / 耐力等
func _extra_cost(sp: Dictionary) -> Dictionary:
	var raw: Variant = sp.get("cost", 0)
	var out := {}
	if raw is Dictionary:
		for k in raw:
			if k != power_type:
				out[k] = float(raw[k])
	return out

func _pay(sp: Dictionary) -> void:
	for key in gauge_costs(sp):
		gauge_add(key, -float(gauge_costs(sp)[key]))
	var extra := _extra_cost(sp)
	if extra.has("stamina"):
		stamina = maxf(0.0, stamina - extra["stamina"])
	if spec_resource_type != "" and extra.has(spec_resource_type):
		spec_resource = maxf(0.0, spec_resource - extra[spec_resource_type])
		power_changed.emit()
	var cost := spell_cost(sp)
	if cost > 0.0:
		add_power(-cost)
		if power_type == "mana":
			since_mana_spend = 0.0

func _start_cd(sp: Dictionary) -> void:
	var cd: float = sp.get("cd", 0.0)
	if cd > 0.0 and not sp.get("cd_on_end", false):
		if not talent_mods.is_empty():
			cd *= maxf(0.2, 1.0 + tmod_any("cd_pct", [sp.get("id", ""), "*"]))
		cooldowns[sp["id"]] = cd
		if is_player and is_interrupt_skill(sp):
			cooldowns["shared_interrupt"] = cd

func _cast_sound(sp: Dictionary) -> void:
	var sch: String = sp.get("school", "")
	if sp.get("target", "") in ["enemy", "ground_enemy"] and sch != "physical":
		Sfx.play_at("cast", global_position, -19.0)
		return
	var key = {"fire": "fire", "frost": "frost", "holy": "holy", "shadow": "shadow", "arcane": "arcane", "nature": "frost",
		"water": "water", "lightning": "lightning", "light": "light", "wind": "wind"}.get(sch, "")
	if key != "":
		Sfx.play_at(key, global_position, -12.0)

func _finish_cast(c: Dictionary) -> void:
	var sp: Dictionary = c["sp"]
	var tgt: Unit = c.get("target")
	if sp.get("target", "") == "friend" and (not is_instance_valid(tgt) or tgt.dead or edge_dist(tgt) > spell_range(sp) or (tgt != self and not has_los(tgt))):
		return
	if sp.get("target", "") in ["enemy", "ground_enemy"]:
		if tgt == null or not is_instance_valid(tgt) or tgt.dead:
			return
		if is_player and edge_dist(tgt) > spell_range(sp) + 3.0:
			_cast_error("距离太远。")
			return
		if is_player and not has_los(tgt):
			_cast_error("目标不在视野中。")
			return
	if not _can_pay(sp):
		return
	if sp.get("target", "") == "enemy" and tgt and is_instance_valid(tgt):
		face_towards(tgt.global_position)
		if not in_combat or target == null:
			target = tgt
	if is_instance_valid(tgt) and is_enemy(tgt):
		enter_combat()
	var windup: float = sp.get("windup", 0.0) if is_player else 0.0
	if windup > 0.0:
		action_lock = windup + float(sp.get("recovery", 0.18))
		pending_action = {"sp": sp, "target": tgt, "remaining": windup}
		if model and model.has_method("play_skill_attack"):
			model.play_skill_attack(windup, float(sp.get("recovery", 0.18)), str(sp.get("animation", "slash")))
		elif model:
			model.play_attack(-1)
		if sp.get("animation", "") not in ["rifle", "shotgun", "cannon", "rocket", "rail"]:
			Sfx.play_at("swing", global_position, -12.0)
	else:
		_commit_skill(sp)
		_deliver(sp, tgt)

func _commit_skill(sp: Dictionary) -> void:
	if sp.has("windup") and model and model.has_method("reach_skill_contact"):
		model.reach_skill_contact()
	_pay(sp)
	_start_cd(sp)
	_cast_sound(sp)
	if sp.get("animation", "") in ["rifle", "shotgun", "cannon", "rocket", "rail"]:
		Sfx.play_at("shot", global_position, -6.0)
		Vfx.hit_spark(get_parent(), _skill_origin(sp), Color("ffd8a0"), 0.6)
	if sp.has("cast_by_gauge") and sp.get("consume_gauge_on_cast", true):
		var key: String = sp["cast_by_gauge"]["gauge"]
		if sp.has("consume_gauge_amount"):
			gauge_add(key, -float(sp["consume_gauge_amount"]))
		else:
			gauge_clear(key)

func face_towards(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0
	if d.length_squared() > 0.001:
		rotation.y = atan2(-d.x, -d.z)

## 投射物或立即生效
func _skill_origin(sp: Dictionary) -> Vector3:
	var style: String = sp.get("animation", "")
	if style in ["rifle", "shotgun", "cannon", "rocket", "rail"] and model and model.has_method("skill_release_origin"):
		return model.skill_release_origin(style)
	return chest_pos() + forward_dir() * 0.4

func _deliver(sp: Dictionary, tgt: Unit) -> void:
	CombatPresentation.release(self, sp, tgt)
	# Both instant and casted magic release a gesture; weapon skills keep their contact pose.
	if not sp.has("windup") and sp.get("animation", "") != "reload" and sp.get("school", "physical") != "physical" and model and model.has_method("play_cast_release"):
		model.play_cast_release()
	if sp.has("projectile") and tgt != null and tgt != self:
		var pj: Dictionary = sp["projectile"]
		Projectile.spawn(get_parent(), _skill_origin(sp), tgt, pj.get("speed", 25.0), pj.get("color", Color.WHITE), pj.get("size", 0.25), pj.get("kind", "orb"),
			func(): if is_instance_valid(self) and is_instance_valid(tgt) and not tgt.dead: apply_effects(sp, tgt), not (is_player and CombatPresentation.available()))
	else:
		apply_effects(sp, tgt)

# ================================================================ 效果
func _effect_condition(condition: Dictionary, context: Dictionary) -> bool:
	if condition.has("self_aura") and not context["self_auras"].has(condition["self_aura"]):
		return false
	if condition.has("target_aura") and not context["target_auras"].has(condition["target_aura"]):
		return false
	if condition.has("no_target_aura") and context["target_auras"].has(condition["no_target_aura"]):
		return false
	if condition.get("effective_heal", false) and not context["effective_heal"]:
		return false
	if condition.get("behind_or_stealth", false) and not context["behind_or_stealth"]:
		return false
	for key in condition.get("gauge_min", {}):
		if float(context["gauges"].get(key, 0)) < float(condition["gauge_min"][key]):
			return false
	return true

func _effect_multiplier(effect: Dictionary, context: Dictionary) -> float:
	return float(effect.get("bonus_mul", 1.0)) if _effect_condition(effect.get("bonus_when", {}), context) else 1.0

func apply_effects(sp: Dictionary, tgt: Unit) -> void:
	var school: String = sp.get("school", "physical")
	var sname: String = sp.get("name", "")
	var context := {"gauges": gauges.duplicate(), "self_auras": {}, "target_auras": {}, "effective_heal": false, "behind_or_stealth": sp.get("_stealth_open", false) or (is_instance_valid(tgt) and is_behind(tgt))}
	for a in auras:
		context["self_auras"][str(a["def"].get("id", ""))] = true
	if is_instance_valid(tgt):
		for a in tgt.auras:
			context["target_auras"][str(a["def"].get("id", ""))] = true
	var landed := true
	if sp.has("vfx") and not (is_player and CombatPresentation.available()):
		Vfx.spell_vfx(sp["vfx"], self, tgt)
	
	# 方向技能分支
	if sp.get("directional", false):
		var dir := get_move_direction()
		var effect_key := ""
		match dir:
			"forward":
				effect_key = "forward"
			"backward":
				effect_key = "backward"
			"left":
				effect_key = "left"
			"right":
				effect_key = "right"
			"none":
				effect_key = "forward"  # 无输入默认前向
		
		# 使用方向分支效果覆盖主效果
		if sp.has(effect_key):
			var dir_effects: Array = sp[effect_key]
			sp = sp.duplicate()
			sp["effects"] = dir_effects

	# 技能命中后设置连招链
	if sp.has("combo_chain_set"):
		combo_chain = sp["combo_chain_set"]
		combo_window = sp.get("combo_window", 4.0)

	# 处理专精资源变化
	if sp.has("spec_resource_gain"):
		spec_resource = minf(max_spec_resource, spec_resource + sp["spec_resource_gain"])
	if sp.has("spec_resource_cost"):
		spec_resource = maxf(0.0, spec_resource - sp["spec_resource_cost"])

	# 处理充能变化（法师）
	if sp.has("fire_charges_gain"):
		fire_charges = mini(3, fire_charges + sp["fire_charges_gain"])
	if sp.has("fire_charges_cost"):
		fire_charges = maxi(0, fire_charges - sp["fire_charges_cost"])
	if sp.has("frost_charges_gain"):
		frost_charges = mini(3, frost_charges + sp["frost_charges_gain"])
	if sp.has("frost_charges_cost"):
		frost_charges = maxi(0, frost_charges - sp["frost_charges_cost"])

	for e in sp.get("effects", []):
		var t: String = e["type"]
		if not landed or not _effect_condition(e.get("when", {}), context):
			continue
		var ls: float = e.get("level_scale", 0.0) * (level - 1)
		match t:
			"damage":
				if tgt == null or tgt.dead:
					continue
				var amt := randf_range(e.get("min", 0) + ls, e.get("max", 0) + ls)
				amt += stats.get("sp", 0.0) * e.get("coef", 0.0)
				amt += stats.get("ap", 0.0) * e.get("ap_coef", 0.0)
				amt += stats.get("rap", 0.0) * e.get("rap_coef", 0.0)
				amt *= _effect_multiplier(e, context)
				# 终结斩：目标血量<20%时伤害翻倍
				if e.get("execute_bonus", false) and tgt.hp < tgt.max_hp * 0.2:
					amt *= 2.0
				# 新斩杀机制：支持自定义阈值和倍率
				if e.has("execute_bonus_threshold"):
					var threshold: float = e["execute_bonus_threshold"]
					var multiplier: float = e.get("execute_multiplier", 2.0)
					if tgt.hp < tgt.max_hp * threshold:
						amt *= multiplier
				# 法师充能加成（奥术弹幕）
				if e.has("per_charge"):
					var total_charges: int = fire_charges + frost_charges
					amt += e["per_charge"] * total_charges
				# 牧师标记加成
				if e.has("per_holy_mark"):
					amt += e["per_holy_mark"] * holy_marks
				if e.has("per_shadow_mark"):
					amt += e["per_shadow_mark"] * shadow_marks
				# 减速目标加成（冰枪术）
				if e.has("bonus_if_slowed"):
					var has_slow := false
					for aura in tgt.auras:
						if aura.get("mods", {}).has("speed") and aura["mods"]["speed"] < 0:
							has_slow = true
							break
					if has_slow:
						amt *= e["bonus_if_slowed"]
				# 量表加成：per_gauge = {"gauge": 名称, "per": 每点增伤比例}
				if e.has("per_gauge"):
					var pg: Dictionary = e["per_gauge"]
					amt *= 1.0 + gauge(str(pg.get("gauge", ""))) * float(pg.get("per", 0.0))
				var hp_before := tgt.hp
				landed = deal_melee_damage(tgt, amt, sname, sp.get("threat_bonus", 0.0)) if school == "physical" else deal_spell_damage(tgt, amt, school, sname, sp.get("threat_bonus", 0.0))
				# 吸血：lifesteal = 实际造成伤害的比例
				if e.has("lifesteal") and not dead:
					var dealt := maxf(0.0, hp_before - tgt.hp)
					if dealt > 0.0:
						receive_heal(dealt * float(e["lifesteal"]), self, false, sname)
			"dispel_debuff":
				# 驱散目标身上 count 个减益（跳过控制类以外的无意义减益时不做区分，按先进先出）
				var dt: Unit = tgt if (tgt != null and is_friend(tgt)) else self
				var removed := 0
				var want: int = int(e.get("count", 1))
				for a in dt.auras.duplicate():
					if removed >= want:
						break
					if a["def"].get("type", "") == "debuff" and a["def"].get("dispel", false):
						dt.remove_aura(str(a["def"].get("id", "")))
						removed += 1
				if removed > 0 and is_player:
					Vfx.float_text(dt, "驱散", Color("fff4c0"), 0.9)
			"chain":
				# 连锁：主目标之后，依次弹跳到附近未被击中的敌人。{"min","max","coef","jumps","falloff","radius"}
				if tgt == null or tgt.dead:
					continue
				var hit := [tgt]
				var cur: Unit = tgt
				var mul := 1.0
				for j in int(e.get("jumps", 2)):
					var nxt: Unit = null
					var best := float(e.get("radius", 10.0))
					for u in get_tree().get_nodes_in_group("units"):
						var uu3: Unit = u
						if uu3.dead or hit.has(uu3) or not is_enemy(uu3) or absf(uu3.global_position.y - cur.global_position.y) > 3.0 or not cur.has_los(uu3):
							continue
						var dd := U.flat_dist(uu3.global_position, cur.global_position)
						if dd < best:
							best = dd
							nxt = uu3
					if nxt == null:
						break
					mul *= 1.0 - float(e.get("falloff", 0.2))
					hit.append(nxt)
					cur = nxt
					var camt: float = (randf_range(e.get("min", 0) + ls, e.get("max", 0) + ls) + stats.get("sp", 0.0) * e.get("coef", 0.0)) * mul
					Vfx.burst(get_parent(), nxt.chest_pos(), Color("e0e870"), 0.6)
					deal_spell_damage(nxt, camt, school, sname, sp.get("threat_bonus", 0.0))
			"gauge":
				# 量表 / 印记：{"gauge": 名称, "add": 增量} 或 {"gauge": 名称, "clear": true}
				# 或 {"transfer": [来源, 目标], "pct": 比例}
				if e.has("transfer"):
					gauge_transfer(str(e["transfer"][0]), str(e["transfer"][1]), float(e.get("pct", 0.5)))
				elif e.get("clear", false):
					gauge_clear(str(e.get("gauge", "")))
				else:
					var key: String = e.get("gauge", "")
					var gain: float = e.get("add", 0.0)
					if gain > 0.0:
						for a in auras:
							gain += float(a["def"].get("gauge_bonus", {}).get(key, 0.0))
					gauge_add(key, gain)
			"gauge_balance":
				var akey: String = e["a"]
				var bkey: String = e["b"]
				var difference := gauge(akey) - gauge(bkey)
				var moved := absf(difference) * clampf(float(e.get("pct", 0.5)), 0.0, 0.5)
				gauge_add(akey, -moved if difference > 0 else moved)
				gauge_add(bkey, moved if difference > 0 else -moved)
			"heal_pct":
				var ht: Unit = tgt if is_instance_valid(tgt) else self
				var before_heal := ht.hp
				ht.receive_heal(ht.max_hp * float(e.get("pct", 0.1)) * _effect_multiplier(e, context), self, false, sname)
				context["effective_heal"] = ht.hp > before_heal
			"party_aura":
				for u in get_tree().get_nodes_in_group("units"):
					if u is Unit and not u.dead and is_friend(u) and dist_to(u) <= float(e.get("radius", 10.0)) and (u == self or has_los(u)):
						u.add_aura(e["aura"], self)
			"weapon":
				if tgt == null or tgt.dead:
					continue
				var base = randf_range(wdmg.x, wdmg.y) + stats.get("ap", 0.0) / 14.0 * wspeed
				var amt2: float = base * e.get("pct", 1.0) + e.get("bonus", 0) + ls
				amt2 *= _effect_multiplier(e, context)
				if e.has("execute_bonus_threshold") and tgt.hp < tgt.max_hp * float(e["execute_bonus_threshold"]):
					amt2 *= float(e.get("execute_multiplier", 2.0))
				if e.has("per_gauge"):
					var wpg: Dictionary = e["per_gauge"]
					amt2 *= 1.0 + gauge(str(wpg.get("gauge", ""))) * float(wpg.get("per", 0.0))
				if model and not sp.has("windup"):
					model.play_attack(-1)
				var w_hp_before := tgt.hp
				landed = deal_melee_damage(tgt, amt2, sname, sp.get("threat_bonus", 0.0))
				if e.has("lifesteal") and not dead:
					var w_dealt := maxf(0.0, w_hp_before - tgt.hp)
					if w_dealt > 0.0:
						receive_heal(w_dealt * float(e["lifesteal"]), self, false, sname)
			"riposte":
				# 盾反：开启窗口，窗口内下一次近战攻击必定被格挡并触发反击。{"window","min","max","stun","gauge","gauge_add"}
				riposte_weapon = str(e.get("weapon", "shield"))
				if not _can_riposte_guard():
					if is_player:
						Game.err("需要装备盾牌。")
					continue
				riposte_window = float(e.get("window", 1.0))
				riposte_dmg = Vector2(float(e.get("min", 0)) + ls, float(e.get("max", 0)) + ls)
				riposte_stun = float(e.get("stun", 0.0))
				riposte_gauge = str(e.get("gauge", ""))
				riposte_gauge_add = float(e.get("gauge_add", 0.0))
				if is_player:
					Vfx.float_text(self, "盾反准备", Color("ffd040"), 1.0)
			"guard":
				# 守护：给友方目标挂上分担伤害光环（来源为自己）。{"pct","range","dur"}
				var gt: Unit = tgt if (tgt != null and is_friend(tgt) and tgt != self) else null
				if gt == null:
					if is_player:
						Game.err("需要选择一名队友。")
					continue
				gt.add_aura({"id": "guard_" + str(get_instance_id()), "name": "守护", "icon": "shield", "color": Color("ffe080"),
					"dur": float(e.get("dur", 10.0)), "type": "buff", "guard": {"pct": float(e.get("pct", 0.3)), "range": float(e.get("range", 30.0))}}, self)
			"ranged":
				if tgt == null or tgt.dead:
					continue
				var amt3: float = randf_range(rdmg.x, rdmg.y) * e.get("pct", 1.0) + e.get("bonus", 0) + stats.get("rap", 0.0) * e.get("rap_coef", 0.0)
				landed = deal_spell_damage(tgt, amt3 * _effect_multiplier(e, context), school, sname, 0.0, true)
			"ranged_multi":
				var targets := [tgt]
				for u in get_tree().get_nodes_in_group("units"):
					if targets.size() >= e.get("targets", 3):
						break
					if u != tgt and is_enemy(u) and not u.dead and u.global_position.distance_to(tgt.global_position) <= e.get("radius", 10.0) and (u.in_combat or u.faction == "hostile"):
						targets.append(u)
				for u in targets:
					var uu: Unit = u
					var amt4: float = randf_range(rdmg.x, rdmg.y) + e.get("bonus", 0) + stats.get("rap", 0.0) / 14.0 * rspeed
					Projectile.spawn(get_parent(), chest_pos(), uu, 50.0, Color("ffe080"), 0.1, "bullet",
						func(): if is_instance_valid(self) and is_instance_valid(uu) and not uu.dead: deal_spell_damage(uu, amt4, "physical", sname, 0.0, true))
			"heal":
				var ht := tgt if tgt != null else self
				var ha = randf_range(e.get("min", 0) + ls, e.get("max", 0) + ls) + stats.get("sp", 0.0) * e.get("coef", 0.0)
				# 牧师圣光标记加成
				if e.has("per_holy_mark"):
					ha += e["per_holy_mark"] * holy_marks
				var crit = randf() < (stats.get("spell_crit", 2.0) / 100.0)
				if crit:
					ha *= 1.5
				ht.receive_heal(ha, self, crit, sname)
			"heal_self_pct":
				receive_heal(max_hp * e.get("pct", 0.1), self, false, sname)
			"aura":
				var at := tgt if tgt != null else self
				if at.dead:
					continue
				var adef: Dictionary = e["aura"]
				if adef.get("type", "") == "debuff" and at.is_boss and (adef.get("incap", false) or adef.get("stun", false) or adef.get("fear", false)):
					Vfx.float_text(at, "免疫", Color.WHITE)
					continue
				at.add_aura(adef, self)
				if adef.get("type", "") == "debuff" and is_enemy(at):
					at.add_threat(self, 5.0 + level)
					at.on_hostile_action(self)
			"self_aura":
				var sdef: Dictionary = e["aura"]
				if sdef.get("toggle", false) and not get_aura(sdef["id"]).is_empty():
					remove_aura(sdef["id"])
				else:
					add_aura(sdef, self)
			"consume_aura":
				remove_aura(str(e["id"]))
			"aoe":
				var center := global_position
				if e.get("center", "self") == "target" and tgt:
					center = tgt.global_position
				var n := 0
				var hits := 0
				for u in get_tree().get_nodes_in_group("units"):
					var uu2: Unit = u
					if uu2.dead or not is_enemy(uu2):
						continue
					if uu2.faction == "neutral" and not uu2.in_combat and is_player:
						continue
					if U.flat_dist(uu2.global_position, center) > e.get("radius", 8.0) + uu2.radius:
						continue
					if absf(uu2.global_position.y - center.y) > 3.0 or not has_los(uu2):
						continue
					if e.get("frontal", false) and not is_facing(uu2.global_position, 0.2):
						continue
					n += 1
					if n > e.get("max_targets", 99):
						break
					var target_hit := true
					if e.get("max", 0) > 0:
						var amt5: float = randf_range(e.get("min", 0) + ls, e.get("max", 0) + ls) + stats.get("sp", 0.0) * e.get("coef", 0.0) + stats.get("rap", 0.0) * e.get("rap_coef", 0.0)
						var pg: Dictionary = e.get("per_gauge", {})
						amt5 *= 1.0 + gauge(str(pg.get("gauge", ""))) * float(pg.get("per", 0.0))
						if school == "physical":
							target_hit = deal_melee_damage(uu2, amt5, sname, sp.get("threat_bonus", 0.0), true, false, sp.get("mechanic", false))
							if target_hit:
								hits += 1
						else:
							target_hit = deal_spell_damage(uu2, amt5, school, sname, sp.get("threat_bonus", 0.0), false, sp.get("mechanic", false))
							if target_hit:
								hits += 1
					else:
						hits += 1
						uu2.add_threat(self, 10.0 + sp.get("threat_bonus", 0.0))
						uu2.on_hostile_action(self)
					if target_hit and e.has("aura") and not uu2.dead:
						if not (uu2.is_boss and (e["aura"].get("fear", false) or e["aura"].get("stun", false))):
							uu2.add_aura(e["aura"], self)
				landed = hits > 0
			"ground_aoe":
				if tgt:
					Vfx.ground_aoe(get_parent(), tgt.global_position, e.get("radius", 5.0), e.get("delay", 2.0), self,
						randf_range(e.get("min", 0) + ls, e.get("max", 0) + ls), school, sname, sp.get("mechanic", false))
			"charge":
				if tgt:
					_do_charge(tgt, e)
			"blink":
				_do_blink(e.get("dist", 20.0))
			"leap_back":
				_do_leap_back(e.get("dist", 14.0))
			"energize":
				add_power(e.get("amount", 0) + max_power * e.get("pct", 0.0))
			"combo":
				if combo_target != tgt:
					combo = 0
					combo_target = tgt
				var combo_gain: int = e.get("n", 1)
				# 盗贼：背后使用时额外连击点
				if e.has("n_from_behind") and tgt != null and is_behind(tgt):
					combo_gain = e["n_from_behind"]
				combo = mini(5, combo + combo_gain)
				power_changed.emit()
			"finisher_damage":
				if tgt == null or tgt.dead or combo <= 0:
					continue
				var pc: Array = e["per_cp"][combo - 1]
				var amt6 = randf_range(pc[0], pc[1]) + stats.get("ap", 0.0) * e.get("ap_per_cp", 0.0) * combo
				if model and not sp.has("windup"):
					model.play_attack(2)
				amt6 *= _effect_multiplier(e, context)
				landed = deal_spell_damage(tgt, amt6, school, sname) if e.get("spell", false) else deal_melee_damage(tgt, amt6, sname, 0.0)
				if not landed:
					continue
				add_power(e.get("energy_per_cp", 0) * combo)
				combo = 0
				power_changed.emit()
			"finisher_aura":
				var ad: Dictionary = e["aura"].duplicate()
				ad["dur"] = e.get("base_dur", 6.0) + e.get("per_cp", 3.0) * combo
				add_aura(ad, self)
				combo = 0
				power_changed.emit()
			"finisher_aura_scaled":
				# 盗贼割裂出血：根据连击点缩放持续时间和伤害
				if tgt == null or combo <= 0:
					continue
				landed = _hit_roll_melee(tgt, true) not in ["miss", "dodge", "parry"]
				if not landed:
					Vfx.float_text(tgt, "未命中", Color.WHITE)
					continue
				var cp_idx: int = combo - 1
				var ad: Dictionary = e["aura_base"].duplicate(true)
				ad["dur"] = e["durations"][cp_idx]
				ad["tick"]["dmg"] = e["damages"][cp_idx]
				tgt.add_aura(ad, self)
				combo = 0
				power_changed.emit()
			"finisher_stun":
				# 盗贼肾击：根据连击点缩放昏迷时间
				if tgt == null or combo <= 0:
					continue
				var stun_dur: float = e["durations"][combo - 1]
				var stun_aura := {
					"id": "kidney_shot", "name": "肾击", "icon": "kick", "color": Color("c0a060"),
					"dur": stun_dur, "type": "debuff", "stun": true
				}
				tgt.add_aura(stun_aura, self)
				combo = 0
				power_changed.emit()
			"teleport_behind":
				if is_instance_valid(tgt) and not tgt.dead:
					var behind_pos := tgt.global_position - tgt.forward_dir() * (radius + tgt.radius + 0.5)
					_move_skill(behind_pos, 0.2, float(e.get("max_distance", 8.0)))
			"clear_threat":
				# 清空仇恨（消失技能）
				# TODO: 当仇恨系统完成后实现
				pass
			"interrupt":
				if tgt and tgt.is_casting():
					var tsp: Dictionary = tgt.casting["sp"]
					if not tsp.get("interruptible", true):
						Vfx.float_text(tgt, "无法打断", Color.WHITE)
						continue
					tgt.stop_cast(false)
					tgt.school_lock[tsp.get("school", "physical")] = e.get("lock", 4.0)
					Vfx.float_text(tgt, "打断", Color("ffffff"))
			"taunt":
				if tgt:
					var tt := tgt.top_threat()
					var top = tgt.threat.get(tt, 0.0) if tt else 0.0
					tgt.threat[self] = top + 50.0
					tgt.target = self
					tgt.add_threat(self, 1.0)
			"knockback":
				if tgt and not tgt.is_boss:
					var dir := (tgt.global_position - global_position)
					dir.y = 0
					tgt.kb_velocity = dir.normalized() * e.get("force", 6.0) * 2.0 + Vector3(0, 6, 0)
			"summon_pet":
				_summon_pet(e.get("pet", ""))
			"summon_adds":
				_summon_adds()
			"create_item":
				if is_player:
					Game.add_item(e["item"], e.get("count", 1))
			"hearth":
				if is_player:
					_hearth()
			"mount":
				_mount(DataMounts.from_effect(e))
			"dodge":
				_do_dodge(e)
			"stamina_cost":
				var cost: float = e.get("amount", 30.0)
				# 连续闪避递增消耗
				if dodge_streak > 0:
					cost += dodge_streak * 20.0
				if stamina >= cost:
					stamina -= cost
					dodge_streak += 1
					dodge_streak_timer = 3.0
			"momentum":
				if spec != "":
					continue
				# 战士势能增加
				var amt_m: float = e.get("amount", 0.0)
				if e.get("per_tick", false):
					# 引导技能每tick产生
					amt_m = amt_m
				spec_resource = minf(max_spec_resource, spec_resource + amt_m)
				power_changed.emit()
			"combo_chain_set":
				combo_chain = e.get("chain", "")
				combo_window = e.get("window", 4.0)
			"combo_chain_clear":
				combo_chain = ""
				combo_window = 0.0
			"stun":
				if tgt and not tgt.dead:
					if tgt.is_boss:
						Vfx.float_text(tgt, "免疫", Color.WHITE)
						continue
					var stun_aura := {
						"id": "stun_" + str(Time.get_ticks_msec()),
						"name": "眩晕",
						"icon": "scream",
						"color": Color("ffcc00"),
						"dur": e.get("duration", 1.0),
						"type": "debuff",
						"stun": true
					}
					tgt.add_aura(stun_aura, self)
			"damage_bonus_low_hp":
				# 终结斩低血加成（已在damage中计算，这里只是标记）
				pass
			"slow_self":
				# 蓄势待发减速（引导期间）
				pass
			"dash":
				# 向后跃退
				var dash_dist: float = e.get("distance", -8.0)
				var dash_dir := -transform.basis.z if dash_dist < 0 else transform.basis.z
				velocity = dash_dir * abs(dash_dist) * 3.0
			"threat":
				# 嘲讽威胁值增加
				if tgt:
					tgt.add_threat(self, e.get("amount", 100.0))
			"add_charge":
				# 法师充能系统
				var charge_type: String = e.get("charge_type", "")
				var amount: int = e.get("amount", 1)
				if charge_type == "fire":
					fire_charges = mini(3, fire_charges + amount)
				elif charge_type == "frost":
					frost_charges = mini(3, frost_charges + amount)
				# 检查是否触发奥术爆发
				if fire_charges >= 3 and frost_charges >= 3:
					var surge_aura := {
						"id": "arcane_surge",
						"name": "奥术爆发",
						"icon": "arcane",
						"color": Color("d080ff"),
						"dur": 10.0,
						"type": "buff",
						"mods": {"cast_speed": -0.3, "speed": 0.2},
						"stats": {"spell_dmg_pct": 20}
					}
					add_aura(surge_aura, self)
					fire_charges = 0
					frost_charges = 0
					Vfx.float_text(self, "奥术爆发!", Color("d080ff"))
				power_changed.emit()
			"add_mark":
				# 牧师标记系统
				var mark_type: String = e.get("mark_type", "")
				var mark_amount: int = e.get("amount", 1)
				if mark_type == "holy":
					holy_marks = mini(5, holy_marks + mark_amount)
					if holy_marks == 5:
						Vfx.float_text(self, "圣光满溢!", Color("ffd700"))
				elif mark_type == "shadow":
					shadow_marks = mini(5, shadow_marks + mark_amount)
					if shadow_marks == 5:
						Vfx.float_text(self, "暗影充盈!", Color("8040c0"))
				power_changed.emit()
			"consume_marks":
				# 消耗标记
				var consume_type: String = e.get("mark_type", "")
				if consume_type == "holy":
					holy_marks = 0
				elif consume_type == "shadow":
					shadow_marks = 0
				power_changed.emit()
			"consume_all_charges":
				# 消耗所有充能
				fire_charges = 0
				frost_charges = 0
				power_changed.emit()

	spell_resolved.emit(str(sp.get("id", "")), landed)

func on_hostile_action(_src: Unit) -> void:
	pass

func dodge_direction() -> Vector3:
	return forward_dir()

## Swept CharacterBody movement; no ground-height teleport or crossing floor levels.
func _move_skill(destination: Vector3, duration: float, max_distance: float = 8.0) -> void:
	if dead or is_rooted() or not can_act() or motion_active:
		return
	var displacement := destination - global_position
	if absf(displacement.y) > 2.0:
		return
	displacement.y = 0.0
	displacement = displacement.limit_length(max_distance)
	if displacement.length_squared() < 0.01:
		return
	motion_active = true
	var last := [0.0]
	motion_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	motion_tween.tween_method(func(k: float):
		if dead or not can_act() or is_rooted():
			cancel_action()
			return
		var step := displacement * (k - float(last[0]))
		last[0] = k
		var collision := move_and_collide(step)
		if collision != null:
			cancel_action(), 0.0, 1.0, duration)
	motion_tween.tween_callback(func(): motion_active = false)

func _do_dodge(e: Dictionary) -> void:
	invincible_frames = minf(0.18, float(e.get("invincible_frames", 0.18)))
	_move_skill(global_position + dodge_direction().normalized() * float(e.get("distance", 3.8)), 0.28, 3.8)
	if model and model.has_method("play_roll"):
		model.play_roll()
	Vfx.trail(self, 0.24)
	Sfx.play_at("swing", global_position, -14.0)

func _do_charge(tgt: Unit, e: Dictionary) -> void:
	var dir := tgt.global_position - global_position
	dir.y = 0
	var dist := dir.length()
	var dest := tgt.global_position - dir.normalized() * (radius + tgt.radius + 0.8)
	var dur := clampf(dist / 30.0, 0.1, 0.8)
	Vfx.trail(self, dur)
	_move_skill(dest, dur, float(e.get("max_distance", 25.0)))
	face_towards(tgt.global_position)
	if e.has("rage") and spec == "":
		add_power(e["rage"])
	if e.has("stun") and motion_tween and motion_tween.is_valid():
		motion_tween.tween_callback(func():
			if is_instance_valid(tgt) and not tgt.dead and not tgt.is_boss and edge_dist(tgt) <= MELEE_RANGE:
				tgt.add_aura({"id": "charge_stun", "name": "冲锋昏迷", "icon": "charge", "dur": e["stun"], "type": "debuff", "stun": true}, self)
				tgt.add_threat(self, 10.0))
	auto_attack = true
	target = tgt

func _do_blink(dist: float) -> void:
	_move_skill(global_position + forward_dir() * minf(dist, 6.0), 0.16, 6.0)
	Vfx.trail(self, 0.16)

func _do_leap_back(dist: float) -> void:
	_move_skill(global_position - forward_dir() * minf(dist, 4.0), 0.25, 4.0)

func _summon_pet(_id: String) -> void:
	pass

func _summon_adds() -> void:
	pass

func _hearth() -> void:
	pass

func _mount(_m: String) -> void:
	pass

func set_sitting(v: bool) -> void:
	sitting = v
	if not v:
		_remove_auras_by(func(a): return a["def"].get("food", false) or a["def"].get("drink", false))

# ================================================================ 伤害
func _hit_roll_melee(tgt: Unit, special: bool, allow_riposte: bool = true) -> String:
	var diff := tgt.level - level
	var miss := 0.05 + maxf(0, diff) * 0.01
	if off_wspeed > 0.0 and not special:
		miss += 0.12
	var dodge: float = tgt.stats.get("dodge", 5.0) / 100.0 + tgt.aura_mod("dodge")
	var parry := 0.0
	var riposting: bool = allow_riposte and tgt._can_riposte_guard() and tgt.riposte_window > 0.0 and tgt.is_facing(global_position, 0.0)
	if riposting:
		miss = 0.0   # 盾反窗口内必定格挡，连未命中也不会发生
	if tgt.stats.get("parry", 0.0) > 0.0 and tgt.is_facing(global_position, 0.0):
		parry = tgt.stats.get("parry", 0.0) / 100.0
	var block := 0.0
	if tgt.stats.get("block", 0.0) > 0.0 and tgt.is_facing(global_position, 0.0):
		block = tgt.stats.get("block", 0.0) / 100.0
	# 盾反窗口：窗口内面对攻击者时，下一次近战攻击必定被格挡并触发反击
	if riposting:
		block = 1.0
		dodge = 0.0
		parry = 0.0
	if not tgt.is_facing(global_position, 0.0):
		dodge *= 0.5 if tgt.is_player else 1.0
	if tgt.is_incap() or tgt.is_stunned():
		dodge = 0.0
		parry = 0.0
		block = 0.0
	var crit: float = stats.get("crit", 5.0) / 100.0 - maxf(0, diff) * 0.01
	var r := randf()
	if r < miss:
		return "miss"
	r -= miss
	if r < dodge:
		return "dodge"
	r -= dodge
	if r < parry:
		return "parry"
	r -= parry
	if r < block:
		return "block"
	r -= block
	if r < crit:
		return "crit"
	return "hit"

func melee_swing(tgt: Unit, offhand: bool) -> void:
	if not is_player:
		face_towards(tgt.global_position)
	var dmg_range := off_wdmg if offhand else wdmg
	var spd := off_wspeed if offhand else wspeed
	var amt = randf_range(dmg_range.x, dmg_range.y) + stats.get("ap", 0.0) / 14.0 * spd
	if offhand:
		amt *= 0.5
	if is_player and spec != "":
		amt *= 0.4
	var name := ""
	var bonus_threat := 0.0
	if not offhand and not next_melee.is_empty():
		var hs := next_melee
		next_melee = {}
		if power >= spell_cost(hs):
			_pay(hs)
			for e in hs.get("effects", []):
				if e["type"] == "weapon":
					amt += e.get("bonus", 0)
			name = hs["name"]
			bonus_threat = hs.get("threat_bonus", 0.0)
	if model:
		model.play_attack(-1)
	deal_melee_damage(tgt, amt, name, bonus_threat, false, name == "")
	Sfx.play_at("swing", global_position, -10.0)

func deal_melee_damage(tgt: Unit, amt: float, sname: String = "", bonus_threat: float = 0.0, aoe: bool = false, white: bool = false, mechanic: bool = false) -> bool:
	if tgt.dead:
		return false
	var res := "hit" if mechanic else _hit_roll_melee(tgt, sname != "", not aoe)
	amt *= (1.0 + aura_mod("dmg_done")) * talent_dmg_mul("physical", tgt)
	match res:
		"miss", "dodge", "parry":
			var txt: String = {"miss": "未命中", "dodge": "躲闪", "parry": "招架"}[res]
			if is_player or tgt.is_player or owner_unit != null:
				Vfx.float_text(tgt, txt, Color("ffffff"), 0.9)
			tgt.add_threat(self, 1.0)
			tgt.on_hostile_action(self)
			if is_player or tgt.is_player:
				var how0 := sname if sname != "" else "攻击"
				if res == "miss":
					Game.msg("%s的%s没有命中%s。" % [_who(self), how0, _who(tgt)], Color("c0c0c0"))
				else:
					Game.msg("%s的%s被%s%s了。" % [_who(self), how0, _who(tgt), txt], Color("c0c0c0"))
			if power_type == "rage" and res != "miss":
				add_power(1.0)
			return false
		"block":
			if tgt.riposte_window > 0.0 and not aoe and not mechanic and tgt._can_riposte_guard():
				# 盾反：这一击完全挡下（不再走 take_damage，否则最低 1 点伤害会穿透），并触发反击
				if is_player or tgt.is_player:
					Game.msg("%s的%s被%s盾反了。" % [_who(self), sname if sname != "" else "攻击", _who(tgt)], Color("c0c0c0"))
				tgt.on_riposte_success(self)
				return false
			Sfx.play_at("block", tgt.global_position, -8.0)
			amt = maxf(0.0, amt - tgt.stats.get("block_value", 10.0 + tgt.level))
		"crit":
			amt *= 2.0
	var crit := res == "crit"
	if power_type == "rage" and white:
		add_power(amt / _rage_conv() * 7.5 * (1.0 if not crit else 1.5))
	if spec == "berserker" and white:
		gauge_add("fury", FURY_ON_HIT_DEALT)
	var before := tgt.hp
	tgt.take_damage(amt, "physical", self, crit, sname, false, bonus_threat, mechanic)
	if tgt.hp < before:
		_hit_feedback(tgt, crit, sname)
		if not aoe:
			_trigger_enchant(tgt)
	if tgt.hp < before:
		Sfx.play_at("hit_crit" if crit else "hit", tgt.global_position, -5.0 if crit else -8.0)
	return true

func deal_spell_damage(tgt: Unit, amt: float, school: String, sname: String, bonus_threat: float = 0.0, ranged_phys: bool = false, mechanic: bool = false) -> bool:
	if tgt.dead:
		return false
	var diff := tgt.level - level
	var miss := 0.04 + maxf(0, diff) * 0.01
	if ranged_phys:
		miss = 0.05 + maxf(0, diff) * 0.01
	if not mechanic and randf() < miss:
		if is_player or tgt.is_player or owner_unit != null:
			Vfx.float_text(tgt, "抵抗" if not ranged_phys else "未命中", Color("ffffff"), 0.9)
		tgt.add_threat(self, 1.0)
		tgt.on_hostile_action(self)
		return false
	var crit_ch: float = (stats.get("crit", 5.0) if ranged_phys else stats.get("spell_crit", 2.0)) / 100.0
	var crit := randf() < crit_ch
	if crit:
		amt *= 2.0 if ranged_phys else 1.5
	amt *= (1.0 + aura_mod("dmg_done")) * talent_dmg_mul(school, tgt)
	if ranged_phys and not talent_mods.is_empty():
		amt *= maxf(0.2, 1.0 + tmod("ranged_dmg"))
	var before := tgt.hp
	tgt.take_damage(amt, school, self, crit, sname, false, bonus_threat, mechanic)
	if tgt.hp < before:
		_hit_feedback(tgt, crit, sname, school)
		var contact_key: String = {"water":"water","lightning":"lightning","fire":"fire","frost":"frost","shadow":"shadow","arcane":"arcane","holy":"light","light":"light","wind":"wind","physical":"hit"}.get(school, "")
		if contact_key != "":
			Sfx.play_at(contact_key, tgt.global_position, -9.0 if is_player else -15.0)
	return true

func _trigger_enchant(tgt: Unit) -> void:
	if enchant_timer > 0.0 or tgt.dead:
		return
	for a in auras:
		var e: Dictionary = a["def"].get("enchant", {})
		if e.is_empty():
			continue
		enchant_timer = maxf(0.5, float(e.get("interval", 1.0)))
		var amount: float = randf_range(e.get("min", 0), e.get("max", 0)) + stats.get("ap", 0.0) * float(e.get("ap_coef", 0.0))
		deal_spell_damage(tgt, amount, str(e.get("school", "neutral")), a["def"].get("name", "附魔"))
		return

func _hit_feedback(tgt: Unit, crit: bool, sname: String, school: String = "physical") -> void:
	if not is_player:
		return
	if model and model.has_method("impact_pause"):
		model.impact_pause(0.045 if crit else 0.025)
	if not CombatPresentation.contact(self, tgt, school, crit):
		Vfx.hit_spark(get_parent(), tgt.chest_pos(), Color("ffe3b0") if crit else Color("dfd5bf"), 1.3 if crit else 1.0)
	if has_method("combat_impact") and sname != "":
		call("combat_impact", 0.045 if crit else 0.022)

func take_damage(amt: float, school: String, src: Unit, crit: bool = false, sname: String = "", periodic: bool = false, bonus_threat: float = 0.0, mechanic: bool = false) -> void:
	if dead:
		return

	# 无敌帧期间免疫伤害
	if invincible_frames > 0.0 and not periodic and not mechanic and school != "fall":
		if is_player or (src != null and src.is_player):
			Vfx.float_text(self, "闪避", Color("80ff80"), 1.2)
		return

	if src != null and is_instance_valid(src):
		last_attacker = src
	# 物理伤害护甲减免
	if school == "physical" and not periodic:
		var armor: float = stats.get("armor", 0.0)
		var lv := src.level if src else level
		var dr := armor / (armor + 400.0 + 85.0 * lv)
		amt *= 1.0 - clampf(dr, 0.0, 0.75)
	var extra_taken := 0.0
	if is_player:
		# 转职特性中按量表层数减伤（元素法师：每层潮涌 -2%）
		extra_taken = Specs.dynamic_taken(self)
	amt *= maxf(0.35, 1.0 + aura_mod("dmg_taken") + tmod("dmg_taken") + extra_taken)
	amt = maxf(1.0, round(amt))
	amt -= _redirect_to_guardian(amt, school, src, sname)
	# 狂战士：被攻击也会积攒狂怒
	if spec == "berserker" and amt > 0.0:
		gauge_add("fury", FURY_ON_HIT_TAKEN)
	# 吸收
	var absorbed := 0.0
	for a in auras:
		if a.has("absorb") and a["absorb"] > 0.0:
			var take := minf(a["absorb"], amt)
			a["absorb"] -= take
			amt -= take
			absorbed += take
			if a["absorb"] <= 0.0:
				a["rem"] = 0.001
				a["def"] = a["def"].duplicate()
				a["def"]["dur"] = 0.001
			if amt <= 0.0:
				break
	# 受伤打断：变形/凿击等
	_remove_auras_by(func(a): return a["def"].get("break_on_damage", false) or (a["def"].get("break_on_damage_chance", 0.0) > 0.0 and randf() < a["def"]["break_on_damage_chance"]))
	if is_stealthed() and amt > 0.0:
		break_stealth()
	if sitting:
		set_sitting(false)
	set_hp(hp - amt)
	# Ordinary hits do not push player casts back. Explicit interrupts and control still work.
	if not is_player and not casting.is_empty() and not casting["channel"] and amt > 0.0:
		casting["elapsed"] = maxf(0.0, casting["elapsed"] - 0.5)
	if power_type == "rage" and amt > 0.0:
		add_power(amt / _rage_conv() * 2.5)
	if model and amt > 0.0:
		model.play_hit()
	# 漂浮文字
	var show := is_player or (src != null and (src.is_player or (src.owner_unit != null and src.owner_unit.is_player)))
	if show:
		var col := Color("ffffff")
		if is_player:
			col = Color("ff4040")
		elif school != "physical":
			col = {"fire": Color("ff9040"), "frost": Color("80d0ff"), "arcane": Color("ff90ff"), "holy": Color("ffe880"), "shadow": Color("b080ff"), "nature": Color("90ff70"),
				"water": Color("60c8ff"), "lightning": Color("e0e870"), "light": Color("fff4c0")}.get(school, Color("ffff60"))
		elif src != null and not src.is_player:
			col = Color("d0d0d0")
		var txt := str(int(amt))
		if absorbed > 0.0:
			txt += "（吸收%d）" % int(absorbed) if amt > 0.0 else ""
			if amt <= 0.0:
				txt = "吸收"
		Vfx.float_text(self, txt, col, 1.5 if crit else 1.0, crit)
	if src != null and is_instance_valid(src):
		if is_player or src.is_player:
			var who := _who(src)
			var tgt_name := _who(self)
			var how := sname if sname != "" else "攻击"
			Game.msg("%s的%s对%s造成了%d点%s伤害%s%s。" % [who, how, tgt_name, int(amt), _school_name(school), "（致命一击）" if crit else "", ("（吸收%d）" % int(absorbed)) if absorbed > 0 else ""], Color("ff9090") if is_player else Color("ffffff"))
		src.enter_combat()
		add_threat(src, (amt + absorbed) * (1.5 if src.power_type == "rage" and src.is_player else 1.0) + bonus_threat)
		on_hostile_action(src)
		if src.is_player or (src.owner_unit != null):
			tapped_by_player = true
	if hp <= 0.0:
		die(src)

## 守护：身上有 def.guard = {"pct": 分担比例, "range": 有效距离} 的光环时，守护者（光环来源）替自己承担一部分伤害。
## 返回被分担出去的伤害。分担出去的伤害以 periodic=true 交给守护者，跳过第二次护甲减免；_guard_busy 防止互相守护时无限递归。
func _redirect_to_guardian(amt: float, school: String, src: Unit, sname: String) -> float:
	for a in auras:
		var gd: Dictionary = a["def"].get("guard", {})
		if gd.is_empty():
			continue
		var gsrc: Unit = a.get("src")
		if gsrc == null or not is_instance_valid(gsrc) or gsrc.dead or gsrc == self or gsrc._guard_busy:
			continue
		if U.flat_dist(gsrc.global_position, global_position) > float(gd.get("range", 30.0)):
			continue
		var shared: float = roundf(amt * float(gd.get("pct", 0.3)))
		if shared < 1.0:
			return 0.0
		gsrc._guard_busy = true
		gsrc.take_damage(shared, school, src, false, sname, true, 0.0)
		gsrc._guard_busy = false
		return shared
	return 0.0

func _who(u: Unit) -> String:
	if u == null:
		return "某物"
	if u.is_player:
		return "你"
	return u.unit_name

func _school_name(s: String) -> String:
	return {"physical": "物理", "fire": "火焰", "frost": "冰霜", "arcane": "奥术", "holy": "神圣", "shadow": "暗影", "nature": "自然",
		"water": "水", "lightning": "雷", "light": "光", "wind": "风", "neutral": "无属性"}.get(s, "")

func receive_heal(amt: float, src: Unit, crit: bool = false, sname: String = "") -> void:
	if dead:
		return
	if src != null and is_instance_valid(src):
		amt *= maxf(0.2, 1.0 + src.tmod("heal_pct"))
	amt = round(amt)
	var eff := minf(amt, max_hp - hp)
	set_hp(hp + amt)
	if (is_player or (src != null and src.is_player)) and amt >= 1.0 and sname != "":
		Vfx.float_text(self, "+%d" % int(amt), Color("60ff60"), 1.3 if crit else 1.0, crit)
	# 治疗仇恨：对所有与目标交战的敌人
	if src != null and is_instance_valid(src) and eff > 0.0 and in_combat:
		for u in get_tree().get_nodes_in_group("units"):
			var m: Unit = u
			if not m.dead and m.threat.has(self):
				m.add_threat(src, eff * 0.5)

func die(killer: Unit) -> void:
	if dead:
		return
	dead = true
	cancel_action()
	gauges.clear()
	gauge_expire.clear()
	riposte_window = 0.0
	invincible_frames = 0.0
	hp = 0.0
	casting = {}
	auto_attack = false
	auto_shoot = false
	clear_auras()
	threat.clear()
	velocity = Vector3.ZERO
	if model and model.has_method("set_dead"):
		model.set_dead(true)
	hp_changed.emit()
	died.emit(self)
	_on_death(killer)
	leave_combat()

func _on_death(_killer: Unit) -> void:
	pass

func ranged_shot(tgt: Unit) -> void:
	if not is_player:
		face_towards(tgt.global_position)
	var amt = randf_range(rdmg.x, rdmg.y) + stats.get("rap", 0.0) / 14.0 * rspeed
	if model and model.has_method("play_cast_release"):
		model.play_cast_release()
	Sfx.play_at("shot", global_position, -6.0)
	var me := self
	Projectile.spawn(get_parent(), chest_pos() + forward_dir() * 0.5, tgt, 60.0, Color("ffe080"), 0.1, "bullet",
		func(): if is_instance_valid(me) and is_instance_valid(tgt) and not tgt.dead: me.deal_spell_damage(tgt, amt, "physical", "自动射击" if me.is_player else "", 0.0, true))

# ================================================================ 移动辅助
func apply_gravity_and_move(delta: float, wish: Vector3) -> void:
	var v := velocity
	v.x = wish.x
	v.z = wish.z
	if kb_velocity.length_squared() > 0.01:
		v.x += kb_velocity.x
		v.z += kb_velocity.z
		if kb_velocity.y > 0.0:
			v.y = kb_velocity.y
			kb_velocity.y = 0.0
		kb_velocity.x = move_toward(kb_velocity.x, 0.0, 30.0 * delta)
		kb_velocity.z = move_toward(kb_velocity.z, 0.0, 30.0 * delta)
	if not is_on_floor():
		v.y -= GRAVITY * delta
	elif v.y < 0.0:
		v.y = -1.0
	velocity = v
	move_and_slide()
