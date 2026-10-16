class_name Mounts
extends RefCounted
## 坐骑：收藏状态、召唤与速度。
## 坐骑表在 `src/data/data_mounts.gd`。学会某个坐骑的召唤技能即视为已收集，
## 所以收藏状态直接看 `pd["spells"]`，不需要额外的存档字段（老存档自动兼容）。
## 骑术：`pd["riding"]`（10 级在马厩商人处学初级骑术）。

static func data() -> Dictionary:
	return DataMounts.MOUNTS

## 已收集
static func learned(id: String) -> bool:
	var md := DataMounts.get_mount(id)
	if md.is_empty() or Game.pd.is_empty():
		return false
	return (Game.pd.get("spells", {}) as Dictionary).has(String(md["spell"]))

static func learned_count() -> int:
	var n := 0
	for id in DataMounts.ids():
		if learned(String(id)):
			n += 1
	return n

static func riding_ok() -> bool:
	return bool(Game.pd.get("riding", false))

## 当前骑着的坐骑 id（没骑返回 ""）
static func current() -> String:
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or not pl.mounted:
		return ""
	return String(pl.mount_id)

## 召唤 / 收起。返回 false 时原因已通过 Game.err 提示。
static func summon(id: String) -> bool:
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead:
		return false
	if not learned(id):
		Game.err("你还没有这个坐骑。")
		return false
	if not riding_ok():
		Game.err("你需要学习骑术。")
		return false
	if current() == id:
		pl.dismount()
		return true
	if pl.in_combat or pl.swimming:
		Game.err("你现在无法召唤坐骑。")
		return false
	pl.begin_cast(DB.spell(String(DataMounts.get_mount(id)["spell"])), pl)
	return true

## 界面用：获取来源说明
static func source_text(id: String) -> String:
	return String(DataMounts.get_mount(id).get("src", ""))
