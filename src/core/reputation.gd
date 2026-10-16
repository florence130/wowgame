class_name Rep
extends RefCounted
## 声望逻辑。数据：pd["rep"] = {faction_id: 累计点数}
## 来源：任务交付（按交付 NPC 的阵营，可用 quest["rep"] 覆盖）、击杀（按怪物家族）。
## 用途：军需官货单门槛、阵营商人折扣、角色面板声望条。

## 阵营商人折扣：按该 NPC 所属阵营的声望等级
const DISCOUNTS := [0.0, 0.05, 0.10, 0.15, 0.20]

static func data() -> Dictionary:
	if Game.pd.is_empty():
		return {}
	if not Game.pd.has("rep"):
		Game.pd["rep"] = {}
	return Game.pd["rep"]

static func points(fid: String) -> int:
	return int(data().get(fid, 0))

static func tier(fid: String) -> int:
	var p := points(fid)
	var t := 0
	for i in DataRep.TIERS.size():
		if p >= int(DataRep.TIERS[i][1]):
			t = i
	return t

static func tier_name(fid: String) -> String:
	return DataRep.tier_name(tier(fid))

static func tier_color(fid: String) -> Color:
	return DataRep.tier_color(tier(fid))

static func at_least(fid: String, t: int) -> bool:
	return tier(fid) >= t

## 当前等级内的进度：x = 本级已得，y = 本级区间长度（用于进度条与 x/y 文案）
static func progress(fid: String) -> Vector2:
	var p := points(fid)
	var t := tier(fid)
	var lo := DataRep.floor_points(t)
	var hi: int = DataRep.floor_points(t + 1) if t + 1 < DataRep.TIERS.size() else DataRep.MAX_POINTS
	return Vector2(maxi(0, p - lo), maxi(1, hi - lo))

static func ratio(fid: String) -> float:
	var pr := progress(fid)
	return clampf(pr.x / pr.y, 0.0, 1.0)

static func faction_name(fid: String) -> String:
	return str(DB.rep_factions.get(fid, {}).get("name", fid))

static func faction_color(fid: String) -> Color:
	return DB.rep_factions.get(fid, {}).get("color", Color("a8adb8"))

## 增加声望。announce = true 时逐次播报（任务），否则只在本级提升时播报（击杀）。
static func gain(fid: String, amount: int, announce: bool = true) -> void:
	if fid == "" or amount <= 0 or Game.pd.is_empty():
		return
	var before := tier(fid)
	var p := mini(DataRep.MAX_POINTS, points(fid) + amount)
	data()[fid] = p
	var after := tier(fid)
	Game.rep_changed.emit()
	if after > before:
		Game.msg("%s的声望提升为：[%s]" % [faction_name(fid), DataRep.tier_name(after)], DataRep.tier_color(after))
		Game.center_text.emit("声望提升", "%s · %s" % [faction_name(fid), DataRep.tier_name(after)])
		Sfx.play("levelup")
		# 军需官寄来贺信（含附件），每档只寄一次
		for t in range(before + 1, after + 1):
			Mail.on_rep_tier(fid, t)
	elif announce:
		var pr := progress(fid)
		Game.msg("你在%s的声望提高了 %d 点（%s %d/%d）。" % [faction_name(fid), amount, DataRep.tier_name(after), int(pr.x), int(pr.y)], Color("80d0ff"))

# ================================================================ 来源
## 任务交付声望：基础 40 + 8×任务等级，再乘任务权重（主线/副本任务权重更高）
static func quest_gain(q: Dictionary) -> int:
	var lvl: int = int(q.get("lvl", 1))
	var w: float = float(q.get("w", 1.0))
	return maxi(10, int(round((40.0 + 8.0 * lvl) * w)))

## 击杀声望：按怪物等级，稀有/精英/首领加成；小动物不给
static func kill_gain(mob: Dictionary, level: int) -> int:
	if mob.get("critter", false):
		return 0
	var base := maxf(1.0, level * 0.6)
	if mob.get("elite", false):
		base *= 1.5
	if mob.get("rare", false) or mob.get("named", false):
		base *= 3.0
	if mob.get("boss", false):
		base *= 5.0
	return maxi(1, int(round(base)))

## 任务归属阵营：quest["rep"] 可指定（{阵营: 点数}），否则用交付 NPC 的阵营
static func quest_factions(q: Dictionary) -> Dictionary:
	if q.has("rep"):
		return q["rep"]
	var fid := faction_of_npc(str(q.get("turnin", "")))
	return {fid: quest_gain(q)} if fid != "" else {}

static func faction_of_npc(npc_id: String) -> String:
	return str(DB.npc_faction.get(npc_id, ""))

static func faction_of_fam(fam: String) -> String:
	return str(DB.fam_faction.get(fam, ""))

## 阵营商人折扣（0.0 - 0.20）
static func discount_for_npc(npc_id: String) -> float:
	var fid := faction_of_npc(npc_id)
	if fid == "":
		return 0.0
	return DISCOUNTS[tier(fid)]

# ================================================================ 军需品门槛
## 货单条目统一成字典：{"id": 物品 id, "rep": [阵营, 等级], "price": 覆盖价}
static func entry(e) -> Dictionary:
	if e is Dictionary:
		return e
	return {"id": str(e)}

## 门槛文案；无门槛返回空串
static func entry_line(e) -> String:
	var ed := entry(e)
	if not ed.has("rep"):
		return ""
	var r: Array = ed["rep"]
	return "需要：%s · %s" % [faction_name(str(r[0])), DataRep.tier_name(int(r[1]))]

static func entry_ok(e) -> bool:
	var ed := entry(e)
	if not ed.has("rep"):
		return true
	var r: Array = ed["rep"]
	return at_least(str(r[0]), int(r[1]))

static func entry_id(e) -> String:
	return str(entry(e).get("id", ""))
