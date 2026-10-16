extends Node
## 数据库（自动加载 DB）：静态数据 + 物品生成 + 掉落

var classes: Dictionary
var spells: Dictionary
var items: Dictionary
var mobs: Dictionary
var npcs: Dictionary
var quests: Dictionary
var zones: Dictionary
var vendors: Dictionary
var flight_paths: Dictionary
var recipes: Dictionary
## 转职：职业 → [转职定义]；扁平索引 id → 定义（含 class）；转职授予的主动技能 id 列表
var specs: Dictionary
var spec_index := {}
var spec_grants: Array = []
var rep_factions: Dictionary
## 声望索引：NPC id → 阵营 id；怪物家族 → 阵营 id
var npc_faction := {}
var fam_faction := {}
var quests_by_giver := {}
var quests_by_turnin := {}
var _item_cache := {}
var _spell_cache := {}

const XP_TABLE := [0, 400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8800, 10100, 11400, 12900, 14400, 15900, 17500, 19100, 20800]
const MAX_LEVEL := 20
const SKIN_TONES := [Color("ffe4d0"), Color("fbd5bd"), Color("f0c4a4"), Color("e0a98a"), Color("c68863"), Color("9a6446"), Color("f8e8e0")]
const HAIR_COLORS := [Color("ffd7b5"), Color("f5e6a8"), Color("e8c070"), Color("c08040"), Color("8a4a28"), Color("4a2a18"), Color("1e1a1a"), Color("e0e0e8"),
	Color("ff9ab8"), Color("8ab8ff"), Color("a0e0b0"), Color("c0a0ff"), Color("d04040"), Color("f0f0ff")]
const EYE_COLORS := [Color("8a5a30"), Color("4a7ac0"), Color("40a060"), Color("a04040"), Color("8050c0"), Color("e0a020"), Color("303040"), Color("40c0c0")]
const HAIR_STYLE_NAMES := ["短发", "清爽短发", "刺猬头", "侧分", "单马尾", "波波头", "双马尾", "长直发", "长卷发", "丸子头"]

func _ready() -> void:
	classes = DataSpells.classes()
	spells = DataSpells.spells()
	items = DataItems.items()
	items.merge(DataItems.extra_items())
	items.merge(DataProf.items())
	recipes = DataProf.recipes()
	for rid in recipes:
		recipes[rid]["id"] = rid
	mobs = DataMobs.mobs()
	npcs = DataWorld.npcs()
	quests = DataWorld.quests()
	zones = DataWorld.zones()
	vendors = DataItems.vendors()
	flight_paths = DataWorld.flight_paths()
	specs = DataSpecs.specs()
	DataCombatExpansion.apply(spells, specs)
	for cls in specs:
		for sd in specs[cls]:
			sd["class"] = cls
			spec_index[sd["id"]] = sd
			for g in sd.get("grants", []):
				if not spec_grants.has(g):
					spec_grants.append(g)
	rep_factions = DataRep.factions()
	for fid in rep_factions:
		for nid in rep_factions[fid].get("npcs", []):
			npc_faction[nid] = fid
		for fam in rep_factions[fid].get("fams", []):
			fam_faction[fam] = fid
	for qid in quests:
		var q: Dictionary = quests[qid]
		q["id"] = qid
		var g: String = q.get("giver", "")
		if g != "":
			if not quests_by_giver.has(g):
				quests_by_giver[g] = []
			quests_by_giver[g].append(qid)
		var t: String = q.get("turnin", "")
		if not quests_by_turnin.has(t):
			quests_by_turnin[t] = []
		quests_by_turnin[t].append(qid)
	for id in items:
		items[id]["id"] = id
	for id in spells:
		spells[id]["id"] = id

# ================================================================ 经验
func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return XP_TABLE[clampi(level, 1, XP_TABLE.size() - 1)]

func quest_xp(q: Dictionary, player_level: int) -> int:
	var lvl: int = q.get("lvl", 1)
	var base: float = DataWorld.QXP[clampi(lvl, 0, DataWorld.QXP.size() - 1)] * float(q.get("w", 1.0))
	var diff := player_level - lvl
	if diff >= 6:
		base *= 0.1
	elif diff == 5:
		base *= 0.2
	elif diff == 4:
		base *= 0.4
	elif diff == 3:
		base *= 0.6
	elif diff == 2:
		base *= 0.8
	return int(round(base / 5.0)) * 5

func quest_money(q: Dictionary) -> int:
	if q.has("money"):
		return q["money"]
	var lvl: int = q.get("lvl", 1)
	return int((lvl * lvl * 3 + lvl * 15) * float(q.get("w", 1.0)))

# ================================================================ 技能
## 返回某技能某等级的完整定义（合并 rank 覆盖）
func spell(id: String, rank: int = 1) -> Dictionary:
	var key := "%s#%d" % [id, rank]
	if _spell_cache.has(key):
		return _spell_cache[key]
	if not spells.has(id):
		return {}
	var base: Dictionary = spells[id].duplicate(true)
	var ranks: Array = base.get("ranks", [])
	for i in mini(rank, ranks.size()):
		var r: Dictionary = ranks[i]
		var sets: Dictionary = r.get("set", {})
		for path in sets:
			_set_path(base, path, sets[path])
	base["rank"] = rank
	base["max_rank"] = ranks.size()
	_spell_cache[key] = base
	return base

func _set_path(d: Dictionary, path: String, v) -> void:
	var parts := path.split(".")
	var cur = d
	for i in parts.size():
		var p := parts[i]
		var key = p
		if p.begins_with("e") and p.substr(1).is_valid_int() and cur is Dictionary and cur.has("effects"):
			cur = cur["effects"][int(p.substr(1))]
			continue
		if i == parts.size() - 1:
			cur[key] = v
		else:
			cur = cur[key]

func spell_rank_level(id: String, rank: int) -> int:
	var ranks: Array = spells.get(id, {}).get("ranks", [{"lvl": 1}])
	if rank - 1 < ranks.size():
		return ranks[rank - 1].get("lvl", 1)
	return 999

func spell_rank_cost(id: String, rank: int) -> int:
	var ranks: Array = spells.get(id, {}).get("ranks", [])
	if rank - 1 < ranks.size():
		return ranks[rank - 1].get("train", 0)
	return 0

func spell_desc(sp: Dictionary) -> String:
	var t: String = sp.get("desc", "")
	var re := RegEx.new()
	re.compile("\\{([a-z0-9_.]+)\\}")
	var out := t
	for m in re.search_all(t):
		var path := m.get_string(1)
		var val = _get_path(sp, path)
		if val == null:
			match path:
				"rend_total", "sw_total", "corr_total":
					var a: Dictionary = sp["effects"][0]["aura"]
					val = int(a["tick"]["dmg"] * a["dur"] / a["tick"]["interval"])
				"renew_total":
					var a2: Dictionary = sp["effects"][0]["aura"]
					val = int(a2["tick"]["heal"] * a2["dur"] / a2["tick"]["interval"])
				_:
					if path.begins_with("e0.cp"):
						var cpi := int(path.substr(5)) - 1
						var pc: Array = sp["effects"][0]["per_cp"][cpi]
						val = "%d-%d" % [pc[0], pc[1]]
		if val is float:
			val = str(snappedf(val, 0.1)).trim_suffix(".0")
		out = out.replace(m.get_string(0), str(val))
	return out

func _get_path(d: Dictionary, path: String):
	var cur = d
	for p in path.split("."):
		if p.begins_with("e") and p.substr(1).is_valid_int() and cur is Dictionary and cur.has("effects"):
			var idx := int(p.substr(1))
			if idx < cur["effects"].size():
				cur = cur["effects"][idx]
				continue
			return null
		if cur is Dictionary and cur.has(p):
			cur = cur[p]
		else:
			return null
	return cur

# ================================================================ 物品
func get_item(id: String) -> Dictionary:
	if id == "":
		return {}
	if items.has(id):
		var it: Dictionary = items[id]
		if not it.has("_done"):
			_finalize_item(it)
		return it
	if _item_cache.has(id):
		return _item_cache[id]
	var it2 := {}
	if id.begins_with("gen|"):
		it2 = _gen_item(id)
	elif id.begins_with("qr|"):
		it2 = _quest_reward_item(id)
	if not it2.is_empty():
		it2["id"] = id
		_finalize_item(it2)
		_item_cache[id] = it2
	return it2

func _finalize_item(it: Dictionary) -> void:
	it["_done"] = true
	var slot: String = it.get("slot", "")
	var t: String = it.get("type", "misc")
	var ilvl: int = it.get("ilvl", 1)
	var q: int = it.get("q", 1)
	if not it.has("req"):
		it["req"] = maxi(1, ilvl - 3) if slot != "" else 1
	if not it.has("stack"):
		it["stack"] = 1
	if not it.has("stats"):
		it["stats"] = {}
	if slot in ["chest", "legs", "head", "feet", "hands", "waist", "wrist", "back"] and not it.has("armor") and ARMOR_TYPES.has(t):
		var k: float = DataItems.ARMOR_K.get(t, 1.5)
		if slot == "back":
			k = 1.5
		var qm = [0.8, 1.0, 1.1, 1.2, 1.3, 1.4][q]
		it["armor"] = maxi(1, int(round(k * (ilvl + 5) * DataItems.SLOT_MULT.get(slot, 0.5) * qm)))
	if t == "shield" and not it.has("armor"):
		it["armor"] = int(round(6.5 * (ilvl + 5) * 1.2 * [0.8, 1.0, 1.1, 1.2, 1.3, 1.4][q]))
	if DataItems.WEAPON_SPEED.has(t) and not it.has("dmg"):
		var speed: float = DataItems.WEAPON_SPEED[t]
		var qm2 = [0.8, 1.0, 1.15, 1.3, 1.45, 1.6][q]
		var dps: float = (1.5 + ilvl * 0.55) * qm2
		if t in DataItems.TWO_HAND:
			dps *= 1.35
		var avg := dps * speed
		it["dmg"] = [maxi(1, int(round(avg * 0.75))), maxi(2, int(round(avg * 1.25)))]
		it["speed"] = speed
	if DataItems.WEAPON_SPEED.has(t) and not it.has("speed"):
		it["speed"] = DataItems.WEAPON_SPEED[t]
	if not it.has("price"):
		var sm: float = DataItems.SLOT_MULT.get(slot, 0.5) if slot != "" else 0.5
		if slot in ["one", "two", "ranged"]:
			sm = 1.0 if slot == "two" else 0.7
		it["price"] = maxi(1, int(pow(ilvl, 1.6) * 3.0 * (1.0 + q * 0.6) * sm))
	if not it.has("icon"):
		it["icon"] = _icon_for(slot, t)
	if not it.has("color"):
		it["color"] = Color.WHITE
	# 武器装备位
	if slot == "one" or slot == "two":
		it["equip"] = "main"
	elif slot == "off":
		it["equip"] = "off"
	elif slot != "":
		it["equip"] = slot

const ARMOR_TYPES := ["cloth", "leather", "mail", "plate"]

func _icon_for(slot: String, t: String) -> String:
	if DataItems.WEAPON_SPEED.has(t):
		return {"sword": "sword", "sword2": "sword", "axe": "axe", "axe2": "axe", "mace": "mace", "mace2": "mace", "dagger": "dagger",
			"staff": "staff", "polearm": "spear", "gun": "gun", "bow": "bow"}.get(t, "sword")
	if t == "shield":
		return "shield"
	if t == "offhand":
		return "book"
	match slot:
		"chest": return "chest"
		"legs": return "legs"
		"head": return "head"
		"feet": return "feet"
		"hands": return "hands"
		"waist": return "waist"
		"wrist": return "wrist"
		"back": return "back"
		"finger": return "ring"
		"neck": return "neck"
		"trinket": return "trinket"
		"shirt": return "shirt"
		"tabard": return "tabard"
	return "bag"

const QUALITY_KEYS := {"gray": 0, "white": 1, "green": 2, "blue": 3, "purple": 4}

## gen|<weapontype>|<q>|<ilvl>[|suffix]  或  gen|<slot>|<armortype>|<q>|<ilvl>[|suffix]
func _gen_item(id: String) -> Dictionary:
	var p := id.split("|")
	var it := {}
	var is_weapon := DataItems.WEAPON_SPEED.has(p[1]) or p[1] == "shield" or p[1] == "offhand"
	var t: String
	var slot: String
	var qs: String
	var ilvl: int
	var suffix := ""
	if is_weapon:
		t = p[1]
		qs = p[2]
		ilvl = int(p[3])
		if p.size() > 4:
			suffix = p[4]
		slot = "two" if t in DataItems.TWO_HAND else ("ranged" if t in DataItems.RANGED else ("off" if t in ["shield", "offhand"] else "one"))
	else:
		slot = p[1]
		t = p[2]
		qs = p[3]
		ilvl = int(p[4])
		if p.size() > 5:
			suffix = p[5]
	var q: int = QUALITY_KEYS.get(qs, 1)
	var tier := clampi((ilvl - 1) / 6, 0, 2)
	var name := ""
	var h := hash(id)
	if is_weapon:
		name = DataItems.WEAPON_NOUN[t][tier]
	elif slot in ["finger", "neck", "trinket"]:
		name = DataItems.JEWEL_NOUN[slot][tier]
		t = "misc"
	else:
		var mat_names: Array = DataItems.MATERIALS.get(t, ["布"])
		name = mat_names[tier] + DataItems.SLOT_NOUN.get(t, DataItems.SLOT_NOUN["cloth"]).get(slot, "护具")
	if q == 0:
		name = DataItems.GRAY_PREFIX[absi(h) % DataItems.GRAY_PREFIX.size()] + name
	if suffix != "" and DataItems.SUFFIXES.has(suffix):
		name = DataItems.SUFFIXES[suffix][0] + name
	it["name"] = name
	it["q"] = q
	it["slot"] = slot
	it["type"] = t
	it["ilvl"] = ilvl
	it["color"] = _gear_color(t, h)
	if q >= 2:
		it["color2"] = Color.from_hsv(float(absi(h / 7) % 360) / 360.0, 0.45, 0.85)
	if t == "cloth" and slot == "chest":
		it["robe"] = (absi(h) % 2) == 0
	if suffix != "" and DataItems.SUFFIXES.has(suffix):
		it["stats"] = _make_stats(suffix, ilvl, q, slot)
	return it

func _gear_color(t: String, h: int) -> Color:
	var arr: Array
	match t:
		"cloth": arr = DataItems.CLOTH_COLORS
		"leather": arr = DataItems.LEATHER_COLORS
		"mail", "plate", "shield": arr = DataItems.MAIL_COLORS
		"staff", "bow", "gun": arr = DataItems.LEATHER_COLORS
		_: arr = [Color("b8b8c0"), Color("a0a0a8"), Color("c8c0b0")]
	return arr[absi(h) % arr.size()]

func _make_stats(suffix: String, ilvl: int, q: int, slot: String) -> Dictionary:
	var split: Dictionary = DataItems.SUFFIXES[suffix][1]
	var sm: float = DataItems.SLOT_MULT.get(slot, 0.6)
	if slot == "two":
		sm = 1.0
	var budget := maxf(1.0, ilvl * 0.45 * sm * [0.0, 0.6, 1.0, 1.3, 1.6, 2.0][q] + 0.5)
	var st := {}
	for k in split:
		var v := int(round(budget * float(split[k])))
		if v > 0:
			st[k] = v
	if st.is_empty():
		st[split.keys()[0]] = 1
	return st

## qr|<qid>|<slot>|<type>|<stats>
func _quest_reward_item(id: String) -> Dictionary:
	var p := id.split("|")
	var qd: Dictionary = quests.get(p[1], {})
	var lvl: int = qd.get("lvl", 1)
	var slot := p[2]
	var t := p[3]
	var statkey := p[4] if p.size() > 4 else "sta"
	var q: int = qd.get("q_reward", 2 if lvl >= 4 else 1)
	var ilvl := lvl + 2
	var it := {"q": q, "ilvl": ilvl, "req": maxi(1, lvl - 1)}
	var h := hash(id)
	var prefix := _quest_item_prefix(qd)
	if slot in ["one", "two", "ranged", "off"]:
		it["slot"] = slot
		it["type"] = t
		var tier := clampi((ilvl - 1) / 6, 0, 2)
		it["name"] = prefix + DataItems.WEAPON_NOUN.get(t, ["武器"])[tier]
	elif slot in ["finger", "neck", "trinket"]:
		it["slot"] = slot
		it["type"] = "misc"
		it["name"] = prefix + {"finger": "指环", "neck": "项链", "trinket": "护符"}[slot]
	else:
		it["slot"] = slot
		it["type"] = t
		it["name"] = prefix + DataItems.SLOT_NOUN.get(t, DataItems.SLOT_NOUN["cloth"]).get(slot, "护具")
	it["color"] = _gear_color(t, h)
	it["color2"] = Color.from_hsv(float(absi(h / 7) % 360) / 360.0, 0.4, 0.9)
	if t == "cloth" and slot == "chest":
		it["robe"] = true
	# 属性分配
	var parts := statkey.split("_")
	var sm: float = DataItems.SLOT_MULT.get(slot, 0.6)
	if slot == "two":
		sm = 1.0
	if slot == "ranged":
		sm = 0.6
	var budget := maxf(1.0, ilvl * 0.45 * sm * [0.0, 0.7, 1.0, 1.3, 1.6][q] + 0.6)
	var st := {}
	for i in parts.size():
		var share := 1.0 / parts.size()
		if parts.size() == 2:
			share = 0.6 if i == 0 else 0.4
		var v := int(round(budget * share))
		if v > 0:
			st[parts[i]] = v
	if st.is_empty():
		st[parts[0]] = 1
	it["stats"] = st
	if t == "offhand" and parts[0] == "int":
		it["sp"] = int(ilvl / 3)
	return it

func _quest_item_prefix(qd: Dictionary) -> String:
	var giver: String = qd.get("giver", "")
	var map := {"lina": "修道院", "marcus": "晨钟", "samuel": "修士的", "milo": "酿酒师的", "tom": "军需", "hob": "麦浪", "martha": "农家",
		"duke": "金穗镇", "gib": "矿工的", "bob": "渔夫的", "thad": "伐木工", "selena": "蔚蓝", "vick": "猎人的", "faria": "旅人的",
		"loren": "哨站", "isa": "晴岚", "grant": "风车", "howard": "铁道", "lilian": "风羽", "ed": "守望者", "grace": "旅人的", "elin": "斥候"}
	return map.get(giver, "冒险者")

func quest_choice_ids(qid: String) -> Array:
	var q: Dictionary = quests.get(qid, {})
	var out := []
	for c in q.get("choice", []):
		var p: PackedStringArray = c.split(":")
		var stats := p[2] if p.size() > 2 else "sta"
		out.append("qr|%s|%s|%s|%s" % [qid, p[0], p[1], stats])
	return out

# ================================================================ 掉落
func roll_loot(mob: Dictionary, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var loot: Dictionary = mob.get("loot", {})
	var res := {"money": 0, "items": []}
	if mob.get("critter", false):
		if rng.randf() < 0.3 and loot.has("junk"):
			res["items"].append([loot["junk"][0], 1])
		return res
	var mult := 1.0
	if mob.get("elite", false):
		mult = 2.5
	if mob.get("boss", false):
		mult = 5.0
	if mob.get("rare", false) or mob.get("named", false):
		mult = maxf(mult, 3.0)
	if loot.get("humanoid", false) or mob.get("type", "") == "humanoid":
		res["money"] = int(rng.randi_range(level * 2, level * 6) * mult)
	elif rng.randf() < 0.15:
		res["money"] = int(rng.randi_range(level, level * 3) * mult)
	if loot.has("junk") and rng.randf() < 0.55:
		var j: Array = loot["junk"]
		res["items"].append([j[rng.randi() % j.size()], 1])
	if mob.get("type", "") == "beast" and rng.randf() < 0.35:
		res["items"].append(["mat_raw_meat", rng.randi_range(1, 2)])
	if loot.has("mat") and rng.randf() < 0.25:
		res["items"].append([loot["mat"], 1])
	if loot.has("mat2") and rng.randf() < 0.18:
		res["items"].append([loot["mat2"], 1])
	if loot.get("humanoid", false) and rng.randf() < 0.22:
		res["items"].append(["mat_wool" if loot.get("mat_cloth2", false) or level >= 11 else "mat_linen", rng.randi_range(1, 2)])
	if loot.get("humanoid", false) and rng.randf() < 0.04:
		res["items"].append(["food_meat" if level >= 5 else "food_bread", 1])
	if rng.randf() < 0.025:
		res["items"].append(["potion_heal1" if level < 9 else "potion_heal2", 1])
	var ilvl := level + rng.randi_range(-1, 1)
	if rng.randf() < 0.07:
		res["items"].append([random_gear(maxi(1, ilvl), 0, rng), 1])
	if rng.randf() < 0.035:
		res["items"].append([random_gear(maxi(1, ilvl), 1, rng), 1])
	var green_ch: float = loot.get("green", 0.022)
	if mob.get("elite", false):
		green_ch = maxf(green_ch, 0.12)
	if rng.randf() < green_ch:
		var q := 2
		if (mob.get("rare", false) or mob.get("boss", false)) and rng.randf() < 0.3:
			q = 3
		res["items"].append([random_gear(maxi(1, ilvl), q, rng), 1])
	if loot.has("items"):
		var lst: Array = loot["items"].duplicate()
		var pick: int = loot.get("pick", lst.size())
		lst.shuffle()
		for i in mini(pick, lst.size()):
			res["items"].append([lst[i], 1])
	return res

func random_gear(ilvl: int, q: int, rng: RandomNumberGenerator) -> String:
	var qn: String = ["gray", "white", "green", "blue", "purple"][q]
	var r := rng.randf()
	var suffix := ""
	if q >= 2:
		var keys := DataItems.SUFFIXES.keys()
		suffix = "|" + keys[rng.randi() % keys.size()]
	if r < 0.32:
		var wt: Array = ["sword", "axe", "mace", "dagger", "staff", "sword2", "axe2", "mace2", "polearm", "gun", "bow", "shield", "offhand"]
		var t: String = wt[rng.randi() % wt.size()]
		if t == "offhand" and q < 2:
			t = "staff"
		return "gen|%s|%s|%d%s" % [t, qn, ilvl, suffix]
	elif r < 0.4 and q >= 2:
		var js: Array = ["finger", "neck", "finger"]
		return "gen|%s|misc|%s|%d%s" % [js[rng.randi() % js.size()], qn, ilvl, suffix]
	else:
		var slots: Array = ["chest", "legs", "head", "feet", "hands", "waist", "wrist", "back"]
		var s: String = slots[rng.randi() % slots.size()]
		if s == "back":
			return "gen|back|cloth|%s|%d%s" % [qn, ilvl, suffix]
		var ts: Array = ["cloth", "leather", "mail"]
		return "gen|%s|%s|%s|%d%s" % [s, ts[rng.randi() % 3], qn, ilvl, suffix]

# ================================================================ 外观
const OUTFITS := {
	"knight": {"chest": ["mail", "8a92a0", "2a4a8a"], "legs": ["mail", "6a7080"], "feet": ["mail", "4a4a52"], "hands": ["mail", "6a7080"], "tabard": ["", "2a4a8a", "e8c27a"], "weapon": "sword", "shield": true},
	"guard_abbey": {"chest": ["mail", "9aa0a8"], "legs": ["mail", "6a6a7a"], "feet": ["leather", "4a3a2a"], "head": ["mail", "a0a8b0"], "tabard": ["", "e8e0d0", "c0a040"], "weapon": "polearm"},
	"guard_town": {"chest": ["mail", "8a90a0"], "legs": ["leather", "5a4a3a"], "feet": ["leather", "3a2a20"], "head": ["mail", "9aa0a8"], "tabard": ["", "c0a040", "6a4020"], "weapon": "sword", "shield": true},
	"guard_city": {"chest": ["mail", "c0c8d8"], "legs": ["mail", "3a4a6a"], "feet": ["mail", "2a2a3a"], "hands": ["mail", "c0c8d8"], "head": ["mail", "d0d8e8"], "tabard": ["", "2a5aa8", "e8c27a"], "weapon": "polearm"},
	"monk": {"chest": ["cloth", "a08a6a"], "legs": ["cloth", "8a7050"], "feet": ["cloth", "5a4030"], "robe": true, "waist": ["cloth", "5a4030"]},
	"priest": {"chest": ["cloth", "f0ece0", "e8c27a"], "legs": ["cloth", "e0dcd0"], "feet": ["cloth", "c0b090"], "robe": true, "waist": ["cloth", "e8c27a"], "weapon": "mace"},
	"mage": {"chest": ["cloth", "5a4a9a", "e8c27a"], "legs": ["cloth", "3a3a6a"], "feet": ["cloth", "3a2a4a"], "robe": true, "head": ["hat", "5a4a9a"], "weapon": "staff"},
	"farmer": {"chest": ["cloth", "c0a070"], "legs": ["cloth", "6a5a8a"], "feet": ["leather", "5a4030"], "head": ["strawhat", "e0c070"]},
	"merchant": {"chest": ["cloth", "8a5a3a", "e0c080"], "legs": ["cloth", "4a3a2a"], "feet": ["leather", "3a2a20"], "waist": ["leather", "3a2a20"]},
	"smith": {"chest": ["leather", "5a3a2a"], "legs": ["cloth", "4a4a52"], "feet": ["leather", "2a2020"], "hands": ["leather", "4a3020"], "weapon": "mace"},
	"rogue": {"chest": ["leather", "2a2a32"], "legs": ["leather", "1a1a22"], "feet": ["leather", "1a1a1a"], "hands": ["leather", "2a2a2a"], "back": ["cloth", "1a1a2a"], "weapon": "dagger"},
	"hunter": {"chest": ["leather", "6a5a3a"], "legs": ["leather", "4a4a2a"], "feet": ["leather", "3a2a20"], "back": ["cloth", "4a5a3a"], "weapon": "gun"},
	"ranger": {"chest": ["leather", "3a6a4a"], "legs": ["leather", "3a3a2a"], "feet": ["leather", "3a2a20"], "back": ["cloth", "2a5a3a"], "weapon": "bow"},
	"barmaid": {"chest": ["cloth", "f0e8d8", "a04030"], "legs": ["cloth", "a04030"], "feet": ["leather", "4a3020"], "robe": true, "waist": ["cloth", "ffffff"]},
	"noble": {"chest": ["cloth", "6a2a4a", "e8c27a"], "legs": ["cloth", "2a2a3a"], "feet": ["leather", "1a1a1a"], "robe": true, "back": ["cloth", "4a1a3a"]},
	"engineer": {"chest": ["leather", "8a6a4a", "e0a040"], "legs": ["cloth", "5a5a6a"], "feet": ["leather", "3a2a20"], "hands": ["leather", "6a4a2a"], "head": ["goggles", "6a4a2a"]},
	"miner": {"chest": ["cloth", "8a7a6a"], "legs": ["cloth", "5a5040"], "feet": ["leather", "3a2a20"], "head": ["minerhat", "e0c040"], "weapon": "pick"},
	"sailor": {"chest": ["cloth", "f0f0f0", "2a4a8a"], "legs": ["cloth", "2a3a6a"], "feet": ["leather", "2a2020"], "head": ["bandana", "c03030"]},
	"lumberjack": {"chest": ["cloth", "b03030", "2a2a2a"], "legs": ["cloth", "3a4a6a"], "feet": ["leather", "4a3020"], "weapon": "axe"},
	"villager": {"chest": ["cloth", "random"], "legs": ["cloth", "random"], "feet": ["leather", "4a3020"]},
	"citizen": {"chest": ["cloth", "random"], "legs": ["cloth", "random"], "feet": ["leather", "3a2a20"], "robe_chance": 0.5},
	"conductor": {"chest": ["cloth", "2a3a6a", "e8c27a"], "legs": ["cloth", "2a3a6a"], "feet": ["leather", "1a1a1a"], "head": ["cap", "2a3a6a"]},
	"captain": {"chest": ["leather", "6a2a2a", "e8c27a"], "legs": ["cloth", "f0f0f0"], "feet": ["leather", "2a1a1a"], "head": ["tricorn", "2a1a1a"], "back": ["cloth", "6a2a2a"], "weapon": "sword"},
	"bandit": {"chest": ["leather", "5a5a62"], "legs": ["leather", "3a3a42"], "feet": ["leather", "2a2a2a"], "head": ["bandana", "8a8a8a"], "mask": true},
	"bandit_mage": {"chest": ["cloth", "4a3a5a"], "legs": ["cloth", "3a3a42"], "feet": ["cloth", "2a2a2a"], "robe": true, "head": ["bandana", "8a8a8a"], "mask": true},
	"bandit_armored": {"chest": ["mail", "6a6a72"], "legs": ["leather", "3a3a42"], "feet": ["mail", "4a4a52"], "head": ["bandana", "8a8a8a"], "mask": true},
	"bandit_boss": {"chest": ["mail", "3a3a42", "a02020"], "legs": ["leather", "2a2a32"], "feet": ["mail", "2a2a2a"], "head": ["bandana", "a02020"], "back": ["cloth", "6a1a1a"], "mask": true},
	"knight_dark": {"chest": ["mail", "3a3a4a", "a080ff"], "legs": ["mail", "2a2a3a"], "feet": ["mail", "2a2a2a"], "hands": ["mail", "3a3a4a"], "head": ["mail", "3a3a4a"], "back": ["cloth", "2a1a3a"]},
}

## 由种子生成随机外观
func random_appearance(seed_v: int, gender: String = "r") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var g := gender
	if g == "r":
		g = "f" if rng.randf() < 0.5 else "m"
	return {
		"gender": g,
		"skin": SKIN_TONES[rng.randi() % 6],
		"hair": rng.randi() % HAIR_STYLE_NAMES.size() if g == "f" else [0, 1, 2, 3, 5][rng.randi() % 5],
		"hair_color": HAIR_COLORS[rng.randi_range(2, 7)],
		"eye": rng.randi() % 4,
		"eye_color": EYE_COLORS[rng.randi() % EYE_COLORS.size()],
		"brow": rng.randi() % 3,
		"mouth": rng.randi() % 3,
		"face": rng.randi() % 3,
		"height": rng.randf_range(0.95, 1.05),
		"build": rng.randf_range(0.92, 1.1),
		"beard": g == "m" and rng.randf() < 0.25,
		"blush": g == "f",
	}

func npc_appearance(npc_id: String, nd: Dictionary, seed_extra: int = 0) -> Dictionary:
	var a := random_appearance(hash(npc_id) + seed_extra, nd.get("g", "r"))
	if nd.has("hair"):
		a["hair"] = nd["hair"]
	if nd.has("hair_color"):
		a["hair_color"] = nd["hair_color"]
	if nd.has("beard"):
		a["beard"] = nd["beard"]
	return a

## 服装预设 -> 装备外观字典
func outfit_gear(outfit: String, seed_v: int = 0) -> Dictionary:
	var o: Dictionary = OUTFITS.get(outfit, OUTFITS["villager"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var g := {}
	for slot in ["chest", "legs", "feet", "hands", "head", "back", "tabard", "waist"]:
		if o.has(slot):
			var arr: Array = o[slot]
			var c1: Color
			if arr[1] == "random":
				c1 = Color.from_hsv(rng.randf(), rng.randf_range(0.25, 0.55), rng.randf_range(0.45, 0.85))
			else:
				c1 = Color(arr[1])
			var e := {"type": arr[0], "color": c1}
			if arr.size() > 2:
				e["color2"] = Color(arr[2])
			g[slot] = e
	if o.get("robe", false) or rng.randf() < float(o.get("robe_chance", 0.0)):
		if g.has("chest"):
			g["chest"]["robe"] = true
	if o.has("weapon"):
		g["main"] = {"type": o["weapon"], "color": Color("b0b0b8")}
	if o.get("shield", false):
		g["off"] = {"type": "shield", "color": Color("8a6a40"), "color2": Color("e8c27a")}
	if o.get("mask", false):
		g["mask"] = true
	return g

## 由物品生成装备外观
func item_visual(item_id: String) -> Dictionary:
	var it := get_item(item_id)
	if it.is_empty():
		return {}
	var v := {"type": it.get("type", "cloth"), "color": it.get("color", Color.WHITE)}
	if it.has("color2"):
		v["color2"] = it["color2"]
	if it.get("robe", false):
		v["robe"] = true
	v["q"] = it.get("q", 1)
	return v

# ================================================================ 杂项
func npc_has_quest_role(npc_id: String) -> bool:
	return quests_by_giver.has(npc_id) or quests_by_turnin.has(npc_id)

func class_color(cls: String) -> Color:
	return classes.get(cls, {}).get("color", Color.WHITE)
