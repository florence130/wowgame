class_name Specs
extends RefCounted
## 15 级转职逻辑（取代 src/core/talents.gd）。数据见 src/data/data_specs.gd。
## 存档：pd["spec"] = 转职 id（空串 = 未转职）。旧存档里的 pd["talents"] 不再读取，登录时由 Game 清掉。
##
## 被动：永久生效，汇总进 Unit.talent_mods（键与旧天赋效果键一致，unit.gd 的 tmod* 直接可用）。
## 特性：带触发条件，条件依赖目标 / 自身当前状态，所以不进缓存，在 Unit.trait_mods(target) 里动态求值。

const MAP_KEYS := ["stats", "stats_pct", "school_dmg", "cost_pct", "cd_pct"]
const SCALAR_KEYS := ["dot_pct", "heal_pct", "cast_pct", "dur_pct", "dmg_taken", "threat", "speed", "ranged_dmg", "hp_pct", "regen", "haste"]
const CHANGE_COST := 2000   # 换转职费用（铜）

static var _mods_cache: Dictionary = {}
static var _mods_gen := ""

# ================================================================ 查询
static func options(cls: String = "") -> Array:
	var c: String = cls if cls != "" else str(Game.pd.get("class", "warrior"))
	return DB.specs.get(c, [])

static func current_id() -> String:
	return str(Game.pd.get("spec", "")) if not Game.pd.is_empty() else ""

static func current() -> Dictionary:
	return DB.spec_index.get(current_id(), {})

static func can_choose_level() -> bool:
	return not Game.pd.is_empty() and int(Game.pd.get("level", 1)) >= DataSpecs.CHOOSE_LEVEL

## 能否转到某个转职；返回空串表示可以，否则为原因
static func can_choose(sid: String) -> String:
	var sd: Dictionary = DB.spec_index.get(sid, {})
	if sd.is_empty():
		return "未知转职。"
	if sd.get("class", "") != Game.pd.get("class", ""):
		return "这不是你的职业转职。"
	if not can_choose_level():
		return "需要达到 %d 级。" % DataSpecs.CHOOSE_LEVEL
	if is_instance_valid(Game.player) and (Game.player.in_combat or Game.player.is_casting() or Game.player.action_lock > 0.0 or Game.player.motion_active):
		return "请在脱离战斗且动作结束后转职。"
	if current_id() == sid:
		return "你已经是%s。" % sd["name"]
	if current_id() != "" and int(Game.pd.get("money", 0)) < CHANGE_COST:
		return "改换转职需要 %s。" % U.money_text(CHANGE_COST)
	var retire_count := 0
	for slot in Game.pd.get("equip", {}):
		if not Game.can_equip(DB.get_item(Game.pd["equip"][slot]), false, sid):
			retire_count += 1
	if Game.pd.get("bag", []).count(null) < retire_count:
		return "请先腾出%d个背包位置，存放换职后无法装备的物品。" % retire_count
	return ""

static func choose(sid: String, silent: bool = false) -> bool:
	var why := can_choose(sid)
	if why != "":
		if not silent:
			Game.err(why)
		return false
	if current_id() != "":
		Game.add_money(-CHANGE_COST, true)
	if is_instance_valid(Game.player):
		Game.player.clear_skill_buffer()
		Game.player.reset_job_state()
		if sid == "gadgeteer" and is_instance_valid(Game.player.pet):
			Game.player.pet.queue_free()
			Game.player.pet = null
	Game.pd["spec"] = sid
	for slot in Game.pd.get("equip", {}).keys():
		var item: String = Game.pd["equip"][slot]
		if not Game.can_equip(DB.get_item(item), false):
			var index: int = Game.pd["bag"].find(null)
			Game.pd["bag"][index] = {"id": item, "n": 1}
			Game.pd["equip"].erase(slot)
	invalidate()
	sync_spells(silent)
	if Game.player:
		Game.player.spec = sid
		Game.player.recalc_stats()
		Game.player.refresh_visuals()
	Game.inventory_changed.emit()
	if not silent:
		Game.msg("你转职为：%s。" % DB.spec_index[sid]["name"], Color("ffff60"))
		Sfx.play("learn")
	Game.spells_changed.emit()
	return true

# ================================================================ 汇总
static func invalidate() -> void:
	_mods_gen = ""

static func _empty_mods() -> Dictionary:
	return {"stats": {}, "stats_pct": {}, "school_dmg": {}, "cost_pct": {}, "cd_pct": {}}

static func _add(m: Dictionary, src: Dictionary) -> void:
	for k in MAP_KEYS:
		if src.has(k):
			for sk in src[k]:
				m[k][sk] = float(m[k].get(sk, 0.0)) + float(src[k][sk])
	for k in SCALAR_KEYS:
		if src.has(k):
			m[k] = float(m.get(k, 0.0)) + float(src[k])

## 当前转职的被动汇总（无条件、可缓存）
static func mods() -> Dictionary:
	var gen := "%s|%d" % [current_id(), int(Game.pd.get("level", 1)) if not Game.pd.is_empty() else 0]
	if gen == _mods_gen and not _mods_cache.is_empty():
		return _mods_cache
	var m := _empty_mods()
	var sd := current()
	if not sd.is_empty() and can_choose_level():
		for p in sd.get("passives", []):
			_add(m, p)
	_mods_cache = m
	_mods_gen = gen
	return m

## 条件特性是否在当前状态下生效。me = 持有者，tgt = 当前目标（可为 null）
static func trait_active(t: Dictionary, me: Unit, tgt: Unit) -> bool:
	match str(t.get("trigger", "")):
		"": return true
		"self_hp_below": return me.max_hp > 0.0 and me.hp / me.max_hp < float(t.get("value", 0.3))
		"target_hp_below": return tgt != null and is_instance_valid(tgt) and not tgt.dead and tgt.max_hp > 0.0 and tgt.hp / tgt.max_hp < float(t.get("value", 0.3))
		"target_slowed": return tgt != null and is_instance_valid(tgt) and not tgt.dead and tgt.aura_mod("speed") < 0.0
	return false

## 按量表层数变化的减伤：特性里写 "taken_per_gauge": {"gauge": 名称, "per": 每层, "max": 上限}（per 为负数 = 减伤）
static func dynamic_taken(me: Unit) -> float:
	var sd := current()
	if sd.is_empty() or not can_choose_level():
		return 0.0
	var v := 0.0
	for t in sd.get("traits", []):
		var tg: Dictionary = t.get("taken_per_gauge", {})
		if tg.is_empty() or not trait_active(t, me, null):
			continue
		var n := me.gauge(str(tg.get("gauge", "")))
		v += maxf(float(tg.get("max", -0.5)), n * float(tg.get("per", 0.0))) if float(tg.get("per", 0.0)) < 0.0 else minf(float(tg.get("max", 0.5)), n * float(tg.get("per", 0.0)))
	return v

## 生效特性的汇总（动态求值）
static func trait_mods(me: Unit, tgt: Unit) -> Dictionary:
	var m := _empty_mods()
	var sd := current()
	if sd.is_empty() or not can_choose_level():
		return m
	for t in sd.get("traits", []):
		if trait_active(t, me, tgt):
			_add(m, t.get("mods", {}))
	return m

# ================================================================ 转职授予的主动技能
static func sync_spells(silent: bool = false) -> void:
	if Game.pd.is_empty():
		return
	if not Game.pd["bars"].has({"t": "spell", "id": "dodge_roll"}):
		Game._auto_place_spell("dodge_roll")
	var granted := {}
	var sd := current()
	for g in sd.get("grants", []) if can_choose_level() else []:
		granted[g] = true
	for sid in DB.spec_grants:
		if granted.has(sid):
			if not Game.pd["spells"].has(sid):
				Game.pd["spells"][sid] = 1
				if not silent:
					Game.msg("你学会了新技能：%s。" % DB.spell(sid).get("name", sid), Color("ffff60"))
		elif Game.pd["spells"].has(sid):
			Game.pd["spells"].erase(sid)
			_clear_from_bars(sid)
	for sid in DB.spells:
		if not spell_allowed(str(sid), current_id()):
			_clear_from_bars(str(sid))
	# Newly chosen kits go in freed combat slots in authored order.
	for sid in sd.get("grants", []):
		if granted.has(sid) and not Game.pd["bars"].has({"t": "spell", "id": sid}):
			Game._auto_place_spell(sid)
	Game.bars_changed.emit()

const BASE_SKILLS := {
	"paladin": ["charge", "taunt", "battle_shout"],
	"berserker": ["charge", "battle_shout"],
	"dark_mage": ["blink", "arcane_intellect"],
	"elementalist": ["blink", "arcane_intellect"],
	"radiant": ["power_word_fortitude"],
	"shadow_priest": ["power_word_fortitude"],
	"assassin": ["stealth", "vanish", "sprint", "kick", "evasion"],
	"duelist": ["sprint", "kick"],
	"marksman": ["summon_hound"],
	"gadgeteer": []}

static func spell_allowed(sid: String, job: String = "") -> bool:
	var sp: Dictionary = DB.spells.get(sid, {})
	if sp.has("requires_spec"):
		return job == sp["requires_spec"] and can_choose_level()
	if job == "" or not sp.has("class"):
		return true
	return sid in BASE_SKILLS.get(job, [])

static func _clear_from_bars(sid: String) -> void:
	var changed := false
	var bars: Array = Game.pd.get("bars", [])
	for i in bars.size():
		var b = bars[i]
		if b != null and b.get("t") == "spell" and b.get("id") == sid:
			bars[i] = null
			changed = true
	if changed:
		Game.bars_changed.emit()

# ================================================================ 文案
const STAT_NAMES := {"str": "力量", "agi": "敏捷", "sta": "耐力", "int": "智力", "spi": "精神", "armor": "护甲",
	"ap": "攻击强度", "rap": "远程攻击强度", "sp": "法术强度", "crit": "致命一击", "spell_crit": "法术暴击",
	"dodge": "躲闪", "parry": "招架", "block": "格挡"}
