class_name DataProf
extends RefCounted
## 专业技能：锻造 / 精工 / 烹饪 —— 等级、配方
## 配方字段：prof, skill(需求技能), out(产物), n(产量), mats([[物品, 数量]]), cost(训练费，0=学会专业时自动获得)
## 制作不需要工作台，随时随地都能进行（参考 FF14）；station 字段保留但始终为空

const PROFS := {
	"smith": {"name": "锻造", "icon": "anvil", "station": "", "station_name": "", "desc": "熔炼矿石，打造武器与锁甲。"},
	"artisan": {"name": "精工", "icon": "gear", "station": "", "station_name": "", "desc": "以齿轮、发条与以太回路制作饰品与魔导器具。"},
	"cook": {"name": "烹饪", "icon": "meat", "station": "", "station_name": "", "desc": "用新鲜食材做出比商店更好的食物与饮料。"},
}
## 等级：[名称, 技能上限, 需要角色等级, 需要当前技能, 学习费用(铜)]
const RANKS := [["学徒", 75, 5, 0, 100], ["熟练", 150, 10, 50, 500]]

static func recipes() -> Dictionary:
	var r := {}
	# ---------------------------------------------------------------- 锻造
	r["sm_bar"] = {"prof": "smith", "skill": 1, "out": "mat_copper_bar", "n": 1, "mats": [["mat_copper", 2]], "cost": 0, "station": "", "name": "熔炼铜锭"}
	r["sm_dagger"] = {"prof": "smith", "skill": 10, "out": "c_copper_dagger", "n": 1, "mats": [["mat_copper_bar", 3], ["mat_leather", 1]], "cost": 50, "station": ""}
	r["sm_bracer"] = {"prof": "smith", "skill": 25, "out": "c_copper_bracer", "n": 1, "mats": [["mat_copper_bar", 3]], "cost": 100, "station": ""}
	r["sm_axe"] = {"prof": "smith", "skill": 40, "out": "c_tiger_axe", "n": 1, "mats": [["mat_copper_bar", 5], ["mat_leather", 2]], "cost": 200, "station": ""}
	r["sm_gloves"] = {"prof": "smith", "skill": 60, "out": "c_chain_gloves", "n": 1, "mats": [["mat_copper_bar", 6], ["mat_wool", 2]], "cost": 400, "station": ""}
	r["sm_hammer"] = {"prof": "smith", "skill": 80, "out": "c_forge_hammer", "n": 1, "mats": [["mat_copper_bar", 9], ["mat_aether", 1]], "cost": 800, "station": ""}
	r["sm_chest"] = {"prof": "smith", "skill": 100, "out": "c_aether_mail", "n": 1, "mats": [["mat_copper_bar", 12], ["mat_aether", 2], ["mat_wool", 3]], "cost": 1200, "station": ""}
	r["sm_sword"] = {"prof": "smith", "skill": 125, "out": "c_rune_sword", "n": 1, "mats": [["mat_copper_bar", 14], ["mat_aether", 4]], "cost": 2000, "station": ""}
	# ---------------------------------------------------------------- 精工
	r["ar_gear"] = {"prof": "artisan", "skill": 1, "out": "mat_gearwork", "n": 1, "mats": [["mat_copper", 1], ["j_gear", 1]], "cost": 0, "station": "", "name": "组装齿轮组件"}
	r["ar_gear2"] = {"prof": "artisan", "skill": 15, "out": "mat_gearwork", "n": 1, "mats": [["mat_copper", 3]], "cost": 60, "station": "", "name": "锻打齿轮组件"}
	r["ar_ring"] = {"prof": "artisan", "skill": 20, "out": "c_gear_ring", "n": 1, "mats": [["mat_copper", 2], ["mat_gearwork", 1]], "cost": 100, "station": ""}
	r["ar_charm"] = {"prof": "artisan", "skill": 45, "out": "c_aether_charm", "n": 1, "mats": [["mat_gearwork", 2], ["mat_aether", 1]], "cost": 300, "station": ""}
	r["ar_goggles"] = {"prof": "artisan", "skill": 60, "out": "c_goggles", "n": 1, "mats": [["mat_gearwork", 2], ["mat_linen", 4]], "cost": 400, "station": ""}
	r["ar_rifle"] = {"prof": "artisan", "skill": 85, "out": "c_magitech_rifle", "n": 1, "mats": [["mat_gearwork", 4], ["mat_copper", 4], ["mat_aether", 1]], "cost": 900, "station": ""}
	r["ar_neck"] = {"prof": "artisan", "skill": 110, "out": "c_aether_pendant", "n": 1, "mats": [["mat_gearwork", 3], ["mat_aether", 4]], "cost": 1600, "station": ""}
	# ---------------------------------------------------------------- 烹饪
	r["ck_steak"] = {"prof": "cook", "skill": 1, "out": "food_meat", "n": 1, "mats": [["mat_raw_meat", 1], ["mat_spice", 1]], "cost": 0, "station": ""}
	r["ck_tea"] = {"prof": "cook", "skill": 15, "out": "drink_herbtea", "n": 2, "mats": [["mat_herb", 1], ["drink_water", 2]], "cost": 50, "station": ""}
	r["ck_stew"] = {"prof": "cook", "skill": 40, "out": "food_stew", "n": 2, "mats": [["mat_raw_meat", 2], ["mat_herb", 1], ["mat_spice", 1]], "cost": 200, "station": ""}
	r["ck_cheese"] = {"prof": "cook", "skill": 70, "out": "food_cheese", "n": 2, "mats": [["mat_raw_meat", 1], ["drink_milk", 1], ["mat_spice", 1]], "cost": 500, "station": "", "name": "烤奶酪"}
	r["ck_feast"] = {"prof": "cook", "skill": 100, "out": "food_feast", "n": 2, "mats": [["mat_raw_meat", 3], ["mat_herb", 2], ["mat_spice", 2]], "cost": 1000, "station": ""}
	return r

## 新增的专业材料与产物（合并进物品表）
static func items() -> Dictionary:
	var d := {}
	d["mat_copper_bar"] = {"name": "铜锭", "q": 1, "slot": "", "type": "trade", "ilvl": 8, "stack": 20, "price": 12, "icon": "ore", "color": Color("e09060"), "desc": "锻造材料。由铜矿石熔炼而成。"}
	d["mat_gearwork"] = {"name": "齿轮组件", "q": 1, "slot": "", "type": "trade", "ilvl": 8, "stack": 20, "price": 15, "icon": "gear", "color": Color("d0b070"), "desc": "精工材料。"}
	d["mat_raw_meat"] = {"name": "生肉", "q": 1, "slot": "", "type": "trade", "ilvl": 5, "stack": 20, "price": 3, "icon": "meat", "color": Color("d06060"), "desc": "烹饪材料。从野兽身上获得。"}
	d["mat_spice"] = {"name": "调味料", "q": 1, "slot": "", "type": "trade", "ilvl": 1, "stack": 20, "price": 2, "icon": "herb", "color": Color("e0a040"), "desc": "烹饪材料。可在烹饪师处购买。"}
	d["drink_herbtea"] = {"name": "宁神花茶", "q": 1, "slot": "", "type": "drink", "ilvl": 10, "req": 8, "stack": 20, "price": 8, "icon": "water", "color": Color("e0e0a0"),
		"use": {"drink": 520, "dur": 21.0}, "desc": "使用：在21秒内恢复520点法力值。进食时必须保持坐姿。"}
	d["food_stew"] = {"name": "猎人炖肉", "q": 1, "slot": "", "type": "food", "ilvl": 12, "req": 10, "stack": 20, "price": 12, "icon": "meat", "color": Color("a06040"),
		"use": {"food": 480, "dur": 21.0}, "desc": "使用：在21秒内恢复480点生命值。进食时必须保持坐姿。"}
	d["food_feast"] = {"name": "晴岚港炖海鲜", "q": 2, "slot": "", "type": "food", "ilvl": 17, "req": 14, "stack": 20, "price": 30, "icon": "meat", "color": Color("e08060"),
		"use": {"food": 900, "dur": 24.0}, "desc": "使用：在24秒内恢复900点生命值。进食时必须保持坐姿。"}
	# ---- 制造装备（专业产物，名称与属性固定）
	var c := {
		"c_copper_dagger": ["铜制匕首", 1, "one", "dagger", 7, 5, {}, Color("d09060")],
		"c_copper_bracer": ["铜链护腕", 1, "wrist", "mail", 9, 6, {}, Color("c08860")],
		"c_tiger_axe": ["匠铸猛虎战斧", 2, "one", "axe", 11, 8, {"str": 3, "agi": 2}, Color("c8a070")],
		"c_chain_gloves": ["铆钉链甲护手", 2, "hands", "mail", 13, 10, {"str": 3, "sta": 3}, Color("a0a0a8")],
		"c_forge_hammer": ["熔炉巨锤", 2, "two", "mace2", 15, 12, {"str": 7, "sta": 4}, Color("b07050")],
		"c_aether_mail": ["以太钢锁甲", 2, "chest", "mail", 17, 14, {"str": 6, "sta": 6, "int": 2}, Color("9ab0d0")],
		"c_rune_sword": ["晴岚符文剑", 3, "one", "sword", 19, 15, {"str": 5, "sta": 4}, Color("c0d8ff")],
		"c_gear_ring": ["齿轮指环", 2, "finger", "misc", 10, 8, {"sta": 3}, Color("d0b070")],
		"c_aether_charm": ["以太回路护符", 2, "trinket", "misc", 13, 10, {"int": 3, "spi": 2}, Color("a080ff")],
		"c_goggles": ["精工护目镜", 2, "head", "cloth", 14, 11, {"int": 4, "spi": 3}, Color("c0a060")],
		"c_magitech_rifle": ["魔导工匠步枪", 2, "ranged", "gun", 16, 13, {"agi": 5}, Color("8a7a6a")],
		"c_aether_pendant": ["以太星辉项链", 3, "neck", "misc", 18, 15, {"sta": 5, "int": 5}, Color("b0a0ff")],
	}
	for id in c:
		var e: Array = c[id]
		d[id] = {"name": e[0], "q": e[1], "slot": e[2], "type": e[3], "ilvl": e[4], "req": e[5], "stats": e[6], "color": e[7], "crafted": true}
	d["c_rune_sword"]["crit"] = 1
	return d
