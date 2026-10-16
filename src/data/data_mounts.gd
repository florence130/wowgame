class_name DataMounts
extends RefCounted
## 坐骑表：模型 / 配色 / 速度加成 / 获取来源。
##
## 坐骑 = 一个召唤技能（`spell`，效果 {"type": "mount", "mount": 坐骑id}）+ 一个学习物品（`item`，use.learn = 技能）。
## 学会技能即视为已收集，所以收藏状态直接看 `pd["spells"]` 里有没有这个技能，不需要额外存档字段。
## 速度是「移动速度提高的比例」：Unit.move_speed() 里 `m += 该坐骑的速度`（角色基础速度为 1.0）。
## `src` 只是界面上的获取说明，真正的发放走商人货单 / 声望军需 / 成就奖励 / 任务奖励。

const MOUNTS := {
	"horse": {"name": "高地骏马", "model": "horse", "color": Color("c7905a"), "color2": Color("2a1a10"),
		"speed": 0.60, "spell": "mount_horse", "item": "mount_horse_item", "q": 3,
		"src": "晴岚港马厩商人（10 级 + 初级骑术）", "desc": "晨露谷牧马人养大的高地种，耐力极好，驮着人也能走上整天的山路。"},
	"deer": {"name": "晨露白鹿", "model": "deer", "color": Color("f2eee2"), "color2": Color("d8c8a0"),
		"speed": 0.60, "spell": "mount_deer", "item": "mount_deer_item", "q": 3,
		"src": "晨钟修道院 · 崇敬（军需官 汤姆）", "desc": "只在晨雾里现身过的白鹿。修士们说，它认得晨钟的每一下。"},
	"wolf": {"name": "灰巾座狼", "model": "wolf", "color": Color("5a5a62"), "color2": Color("9a9a9a"),
		"speed": 0.75, "spell": "mount_wolf", "item": "mount_wolf_item", "q": 3,
		"src": "冒险者公会 · 崇敬（军需官 葛雷森）", "desc": "从灰巾帮手里缴获的战争座狼。认人不认旗，谁骑它就听谁的。"},
	"mech": {"name": "魔导机车", "model": "mech", "color": Color("e0a050"), "color2": Color("3a3a42"),
		"speed": 0.80, "spell": "mount_mech", "item": "mount_mech_item", "q": 4,
		"src": "主线《晴岚港的新市民》奖励 / 交易所稀有货", "desc": "晴岚港工匠的得意之作，以太回路驱动，颠簸但快。"},
	"bear": {"name": "铁鬃战熊", "model": "bear", "color": Color("4a3a2a"), "color2": Color("8a6a4a"),
		"speed": 0.90, "spell": "mount_bear", "item": "mount_bear_item", "q": 4,
		"src": "成就「成就猎人」（100 点）奖励", "desc": "北境山民的重装坐骑。皮糙肉厚，冲起来像一堵会呼吸的墙。"},
}

## 坐骑 id → 条目；未知 id 返回空字典
static func get_mount(id: String) -> Dictionary:
	return MOUNTS.get(id, {})

## 召唤技能 id → 坐骑 id
static func by_spell(sid: String) -> String:
	for mid in MOUNTS:
		if String(MOUNTS[mid]["spell"]) == sid:
			return mid
	return ""

## 效果字典 → 坐骑 id（"mount" 优先，兼容旧的 "model" 写法）
static func from_effect(e: Dictionary) -> String:
	var id := String(e.get("mount", ""))
	if id != "" and MOUNTS.has(id):
		return id
	var legacy := String(e.get("model", "horse"))
	for mid in MOUNTS:
		if String(MOUNTS[mid]["model"]) == legacy:
			return mid
	return "horse"

## 全部坐骑 id（保持表内顺序）
static func ids() -> Array:
	return MOUNTS.keys()

## 速度说明，例如 "+60%"
static func speed_text(id: String) -> String:
	return "+%d%%" % int(round(float(get_mount(id).get("speed", 0.6)) * 100.0))

## 品质颜色（收藏簿里给名字上色）
static func quality_color(id: String) -> Color:
	return U.quality_color(int(get_mount(id).get("q", 3)))
