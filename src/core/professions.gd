class_name Prof
extends RefCounted
## 专业技能逻辑。数据：pd["prof"] = {prof_id: {"skill": int, "rank": int}}，pd["recipes"] = {recipe_id: true}

static func data() -> Dictionary:
	if not Game.pd.has("prof"):
		Game.pd["prof"] = {}
	if not Game.pd.has("recipes"):
		Game.pd["recipes"] = {}
	return Game.pd["prof"]

static func known(p: String) -> bool:
	return data().has(p)

static func skill(p: String) -> int:
	return data().get(p, {}).get("skill", 0)

static func rank(p: String) -> int:
	return data().get(p, {}).get("rank", -1)

static func cap(p: String) -> int:
	var r := rank(p)
	return DataProf.RANKS[r][1] if r >= 0 else 0

static func profession_name(p: String) -> String:
	var r := rank(p)
	return "%s（%s）" % [DataProf.PROFS[p]["name"], DataProf.RANKS[r][0]] if r >= 0 else DataProf.PROFS[p]["name"]

## 下一等级能否学习；返回空字符串表示可以，否则为原因
static func next_rank_block(p: String) -> String:
	var nr := rank(p) + 1
	if nr >= DataProf.RANKS.size():
		return "已达到最高等级"
	var rk: Array = DataProf.RANKS[nr]
	if Game.pd["level"] < rk[2]:
		return "需要角色等级 %d" % rk[2]
	if skill(p) < rk[3]:
		return "需要技能达到 %d" % rk[3]
	if Game.pd["money"] < rk[4]:
		return "金钱不足"
	return ""

static func learn_rank(p: String) -> bool:
	var why := next_rank_block(p)
	if why != "":
		Game.err(why)
		return false
	var nr := rank(p) + 1
	Game.add_money(-DataProf.RANKS[nr][4], true)
	var d := data()
	if not d.has(p):
		d[p] = {"skill": 1, "rank": 0}
		for rid in DB.recipes:
			var r: Dictionary = DB.recipes[rid]
			if r["prof"] == p and r["cost"] == 0:
				Game.pd["recipes"][rid] = true
	else:
		d[p]["rank"] = nr
	Sfx.play("learn")
	Game.msg("你学会了%s！技能上限：%d。" % [profession_name(p), cap(p)], Color("ffff60"))
	Game.spells_changed.emit()
	return true

static func recipes_of(p: String, only_known: bool) -> Array:
	var out := []
	for rid in DB.recipes:
		var r: Dictionary = DB.recipes[rid]
		if r["prof"] != p:
			continue
		if only_known and not Game.pd.get("recipes", {}).has(rid):
			continue
		out.append(rid)
	out.sort_custom(func(a, b): return DB.recipes[a]["skill"] < DB.recipes[b]["skill"])
	return out

static func recipe_name(rid: String) -> String:
	var r: Dictionary = DB.recipes[rid]
	return r.get("name", DB.get_item(r["out"]).get("name", rid))

## 难度颜色：orange / yellow / green / gray
static func difficulty(rid: String) -> String:
	var r: Dictionary = DB.recipes[rid]
	var d := skill(r["prof"]) - int(r["skill"])
	if d < 10:
		return "orange"
	if d < 25:
		return "yellow"
	if d < 40:
		return "green"
	return "gray"

const DIFF_COLORS := {"orange": Color("ff8040"), "yellow": Color("ffd040"), "green": Color("40c040"), "gray": Color("909090"), "red": Color("ff4040")}

static func can_learn_recipe(rid: String) -> String:
	var r: Dictionary = DB.recipes[rid]
	if not known(r["prof"]):
		return "尚未学会%s" % DataProf.PROFS[r["prof"]]["name"]
	if Game.pd["recipes"].has(rid):
		return "已学会"
	if skill(r["prof"]) < r["skill"]:
		return "需要技能 %d" % r["skill"]
	if Game.pd["money"] < r["cost"]:
		return "金钱不足"
	return ""

static func learn_recipe(rid: String) -> bool:
	var why := can_learn_recipe(rid)
	if why != "":
		Game.err(why)
		return false
	Game.add_money(-DB.recipes[rid]["cost"], true)
	Game.pd["recipes"][rid] = true
	Sfx.play("learn")
	Game.msg("你学会了制造：%s。" % recipe_name(rid), Color("ffff60"))
	return true

## 能制造几次（材料）
static func craftable_count(rid: String) -> int:
	var r: Dictionary = DB.recipes[rid]
	var cnt: int = 999
	for m in r["mats"]:
		cnt = mini(cnt, Game.count_item(m[0]) / int(m[1]))
	return cnt

## 附近是否有工作台
static func near_station(station: String) -> bool:
	if station == "" or Game.player == null or Game.zone == null:
		return true
	var kinds: Array = ["anvil"] if station == "anvil" else ["campfire", "brazier"]
	var pp: Vector3 = Game.player.global_position
	for g in ["Props", "Buildings"]:
		var grp: Node = Game.zone.get_node_or_null(g)
		if grp == null:
			continue
		for c in grp.get_children():
			if c is Prop and c.kind in kinds and c.global_position.distance_to(pp) < 7.0:
				return true
	return false

static func craft_block(rid: String) -> String:
	var r: Dictionary = DB.recipes[rid]
	if craftable_count(rid) < 1:
		return "材料不足"
	if not near_station(r["station"]):
		return "附近需要%s" % DataProf.PROFS[r["prof"]]["station_name"]
	if Game.free_bag_slots() < 1:
		return "背包已满"
	return ""

## 完成一次制造：扣材料、给产物、技能提升判定
static func finish_craft(rid: String) -> bool:
	if craft_block(rid) != "":
		return false
	var r: Dictionary = DB.recipes[rid]
	var diff := difficulty(rid)
	for m in r["mats"]:
		Game.remove_item(m[0], m[1])
	Game.add_item(r["out"], r["n"])
	var p: String = r["prof"]
	var chance: float = {"orange": 1.0, "yellow": 0.75, "green": 0.25, "gray": 0.0}[diff]
	if skill(p) < cap(p) and randf() < chance:
		data()[p]["skill"] += 1
		Game.msg("你的%s技能提高到了 %d。" % [DataProf.PROFS[p]["name"], skill(p)], Color("8080ff"))
	Achieve.bump("craft")
	return true
