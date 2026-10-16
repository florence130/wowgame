class_name DataItems
extends RefCounted
## 物品数据：手工物品 + 生成规则（随机后缀装备、任务奖励装备）

const SLOT_NAMES := {
	"head": "头部", "neck": "颈部", "back": "背部", "chest": "胸部", "shirt": "衬衣", "tabard": "战袍",
	"wrist": "手腕", "hands": "手", "waist": "腰部", "legs": "腿部", "feet": "脚", "finger": "手指", "trinket": "饰品",
	"main": "主手", "one": "单手", "two": "双手", "off": "副手", "ranged": "远程",
}
const TYPE_NAMES := {
	"cloth": "布甲", "leather": "皮甲", "mail": "锁甲", "plate": "板甲", "sword": "单手剑", "axe": "单手斧", "mace": "单手锤",
	"dagger": "匕首", "staff": "法杖", "sword2": "双手剑", "axe2": "双手斧", "mace2": "双手锤", "polearm": "长柄武器",
	"gun": "枪械", "bow": "弓", "shield": "盾牌", "offhand": "副手物品", "misc": "其它", "rapier": "细剑",
}
const WEAPON_SPEED := {"dagger": 1.6, "sword": 2.3, "rapier": 2.0, "axe": 2.4, "mace": 2.5, "staff": 3.0, "sword2": 3.2, "axe2": 3.4, "mace2": 3.5, "polearm": 3.3, "gun": 2.6, "bow": 2.7}
const TWO_HAND := ["staff", "sword2", "axe2", "mace2", "polearm"]
const RANGED := ["gun", "bow"]
const ARMOR_K := {"cloth": 1.5, "leather": 3.0, "mail": 6.5, "plate": 11.0}
const SLOT_MULT := {"chest": 1.0, "legs": 0.875, "head": 0.81, "feet": 0.69, "hands": 0.625, "waist": 0.56, "wrist": 0.44, "back": 0.35,
	"finger": 0.56, "neck": 0.56, "trinket": 0.7, "shield": 1.0, "offhand": 0.5, "one": 0.6, "two": 1.0, "ranged": 0.6}
const SUFFIXES := {
	"bear": ["巨熊之", {"str": 0.5, "sta": 0.5}], "eagle": ["苍鹰之", {"sta": 0.5, "int": 0.5}], "monkey": ["灵猴之", {"agi": 0.5, "sta": 0.5}],
	"owl": ["夜枭之", {"int": 0.5, "spi": 0.5}], "tiger": ["猛虎之", {"str": 0.5, "agi": 0.5}], "whale": ["巨鲸之", {"sta": 0.5, "spi": 0.5}],
	"falcon": ["猎隼之", {"agi": 0.5, "int": 0.5}], "str": ["力量之", {"str": 1.0}], "agi": ["敏捷之", {"agi": 1.0}],
	"int": ["智慧之", {"int": 1.0}], "sta": ["坚韧之", {"sta": 1.0}], "spi": ["精神之", {"spi": 1.0}],
}
const MATERIALS := {
	"cloth": ["亚麻", "羊毛", "丝织"], "leather": ["粗皮", "硬皮", "鞣制皮"], "mail": ["铁环", "链甲", "钢锁"], "plate": ["铁", "钢", "精钢"],
}
const SLOT_NOUN := {
	"cloth": {"chest": "长袍", "legs": "长裤", "head": "兜帽", "feet": "便鞋", "hands": "手套", "waist": "腰带", "wrist": "护腕", "back": "披风"},
	"leather": {"chest": "外衣", "legs": "护腿", "head": "皮帽", "feet": "皮靴", "hands": "护手", "waist": "腰带", "wrist": "护腕", "back": "披风"},
	"mail": {"chest": "锁甲", "legs": "护腿", "head": "头盔", "feet": "战靴", "hands": "护手", "waist": "束带", "wrist": "护腕", "back": "披风"},
	"plate": {"chest": "胸甲", "legs": "腿铠", "head": "战盔", "feet": "铁靴", "hands": "铁手套", "waist": "腰带", "wrist": "护腕", "back": "披风"},
}
const WEAPON_NOUN := {
	"rapier": ["练习细剑", "护手细剑", "决斗细剑"],
	"sword": ["短剑", "阔剑", "长剑"], "axe": ["手斧", "战斧", "利斧"], "mace": ["木棍", "钉锤", "战锤"], "dagger": ["小刀", "匕首", "短刃"],
	"staff": ["木杖", "橡木法杖", "符文法杖"], "sword2": ["大剑", "双手剑", "巨剑"], "axe2": ["伐木斧", "巨斧", "斩首斧"], "mace2": ["大木槌", "重锤", "巨锤"],
	"polearm": ["长矛", "长戟", "战戟"], "gun": ["燧发枪", "魔导火枪", "长管步枪"], "bow": ["短弓", "猎弓", "长弓"], "shield": ["圆盾", "鸢盾", "纹章盾"],
	"offhand": ["魔典", "水晶球", "符文书"],
}
const JEWEL_NOUN := {"finger": ["铜戒指", "银戒指", "宝石戒指"], "neck": ["绳结项链", "银项链", "宝石坠饰"], "trinket": ["幸运符", "护身符", "魔导徽章"]}
const GRAY_PREFIX := ["破损的", "生锈的", "破旧的", "弯曲的", "开裂的"]

const CLOTH_COLORS := [Color("7a8fb8"), Color("b8865a"), Color("6a9a6a"), Color("9a6aa0"), Color("c0b090"), Color("5a7ab0"), Color("a85a5a")]
const LEATHER_COLORS := [Color("8a5a3a"), Color("6a4a30"), Color("9a7050"), Color("5a4a3a"), Color("7a6040")]
const MAIL_COLORS := [Color("9aa0a8"), Color("7a8088"), Color("a8a090"), Color("8890a0")]

static func items() -> Dictionary:
	var d := {}
	# ---- 初始装备
	d["w_recruit_sword"] = {"name": "新兵短剑", "q": 1, "slot": "one", "type": "sword", "ilvl": 2, "dmg": [2, 5], "speed": 2.3, "price": 7, "color": Color("b0b0b8")}
	d["w_apprentice_staff"] = {"name": "学徒木杖", "q": 1, "slot": "two", "type": "staff", "ilvl": 2, "dmg": [3, 5], "speed": 3.0, "price": 9, "color": Color("8a6a40")}
	d["w_acolyte_mace"] = {"name": "侍僧木锤", "q": 1, "slot": "one", "type": "mace", "ilvl": 2, "dmg": [2, 5], "speed": 2.5, "price": 7, "color": Color("9a7a50")}
	d["w_worn_dagger"] = {"name": "磨损的匕首", "q": 1, "slot": "one", "type": "dagger", "ilvl": 2, "dmg": [1, 3], "speed": 1.6, "price": 7, "color": Color("a0a0a8")}
	d["w_recruit_rifle"] = {"name": "新兵燧发枪", "q": 1, "slot": "ranged", "type": "gun", "ilvl": 2, "dmg": [3, 6], "speed": 2.6, "price": 9, "color": Color("7a5a3a")}
	d["w_hand_axe"] = {"name": "简易手斧", "q": 1, "slot": "one", "type": "axe", "ilvl": 2, "dmg": [2, 4], "speed": 2.4, "price": 6, "color": Color("a0a0a0")}
	d["shirt_recruit"] = {"name": "新兵衬衣", "q": 1, "slot": "shirt", "type": "misc", "ilvl": 1, "price": 1, "color": Color("d8d0b8")}
	d["legs_recruit"] = {"name": "新兵长裤", "q": 1, "slot": "legs", "type": "cloth", "ilvl": 1, "armor": 2, "price": 1, "color": Color("6a6a7a")}
	d["legs_leather_recruit"] = {"name": "新兵皮裤", "q": 1, "slot": "legs", "type": "leather", "ilvl": 1, "armor": 5, "price": 1, "color": Color("6a4a30")}
	d["feet_recruit"] = {"name": "新兵布鞋", "q": 1, "slot": "feet", "type": "cloth", "ilvl": 1, "armor": 1, "price": 1, "color": Color("5a4030")}
	d["chest_apprentice_robe"] = {"name": "学徒长袍", "q": 1, "slot": "chest", "type": "cloth", "ilvl": 1, "armor": 3, "price": 1, "color": Color("6a7ab8"), "robe": true}
	d["chest_acolyte_robe"] = {"name": "侍僧长袍", "q": 1, "slot": "chest", "type": "cloth", "ilvl": 1, "armor": 3, "price": 1, "color": Color("e8e4d8"), "robe": true}
	d["tabard_solenne"] = {"name": "晴岚港战袍", "q": 1, "slot": "tabard", "type": "misc", "ilvl": 15, "price": 0, "color": Color("2a5aa8"), "color2": Color("e8c27a"),
		"desc": "晴岚港市民的荣誉象征。"}

	# ---- 消耗品
	d["food_bread"] = {"name": "烤面包", "q": 1, "slot": "", "type": "food", "ilvl": 1, "stack": 20, "price": 1, "icon": "bread", "color": Color("d0a060"),
		"use": {"food": 61, "dur": 18.0}, "desc": "使用：在18秒内恢复61点生命值。进食时必须保持坐姿。"}
	d["food_meat"] = {"name": "香烤狼排", "q": 1, "slot": "", "type": "food", "ilvl": 5, "req": 5, "stack": 20, "price": 6, "icon": "meat", "color": Color("b06040"),
		"use": {"food": 243, "dur": 21.0}, "desc": "使用：在21秒内恢复243点生命值。进食时必须保持坐姿。"}
	d["food_cheese"] = {"name": "高地奶酪", "q": 1, "slot": "", "type": "food", "ilvl": 15, "req": 15, "stack": 20, "price": 25, "icon": "cheese", "color": Color("f0d060"),
		"use": {"food": 552, "dur": 24.0}, "desc": "使用：在24秒内恢复552点生命值。进食时必须保持坐姿。"}
	d["drink_water"] = {"name": "清泉水", "q": 1, "slot": "", "type": "drink", "ilvl": 1, "stack": 20, "price": 1, "icon": "water", "color": Color("80c0ff"),
		"use": {"drink": 151, "dur": 18.0}, "desc": "使用：在18秒内恢复151点法力值。进食时必须保持坐姿。"}
	d["drink_juice"] = {"name": "蜜桃果汁", "q": 1, "slot": "", "type": "drink", "ilvl": 5, "req": 5, "stack": 20, "price": 6, "icon": "water", "color": Color("ffb080"),
		"use": {"drink": 436, "dur": 21.0}, "desc": "使用：在21秒内恢复436点法力值。进食时必须保持坐姿。"}
	d["drink_milk"] = {"name": "高地牛奶", "q": 1, "slot": "", "type": "drink", "ilvl": 15, "req": 15, "stack": 20, "price": 25, "icon": "water", "color": Color("f0f0f0"),
		"use": {"drink": 835, "dur": 24.0}, "desc": "使用：在24秒内恢复835点法力值。进食时必须保持坐姿。"}
	d["drink_conjured"] = {"name": "魔法清水", "q": 1, "slot": "", "type": "drink", "ilvl": 1, "stack": 20, "price": 0, "icon": "water", "color": Color("a0d0ff"),
		"use": {"drink": 151, "dur": 18.0}, "desc": "使用：在18秒内恢复151点法力值。进食时必须保持坐姿。"}
	d["potion_heal1"] = {"name": "初级治疗药水", "q": 1, "slot": "", "type": "potion", "ilvl": 5, "req": 1, "stack": 5, "price": 5, "icon": "potion_red", "color": Color("e04040"),
		"use": {"heal": [70, 90], "cd": 120.0}, "desc": "使用：恢复70到90点生命值。"}
	d["potion_heal2"] = {"name": "次级治疗药水", "q": 1, "slot": "", "type": "potion", "ilvl": 13, "req": 8, "stack": 5, "price": 25, "icon": "potion_red", "color": Color("ff5050"),
		"use": {"heal": [140, 180], "cd": 120.0}, "desc": "使用：恢复140到180点生命值。"}
	d["potion_mana1"] = {"name": "初级法力药水", "q": 1, "slot": "", "type": "potion", "ilvl": 5, "req": 5, "stack": 5, "price": 10, "icon": "potion_blue", "color": Color("4060ff"),
		"use": {"mana": [140, 180], "cd": 120.0}, "desc": "使用：恢复140到180点法力值。"}
	d["potion_heal3"] = {"name": "港制治疗药水", "q": 1, "slot": "", "type": "potion", "ilvl": 16, "req": 16, "stack": 5, "price": 60, "icon": "potion_red", "color": Color("ed665d"),
		"use": {"heal": [240, 280], "cd": 120.0}, "desc": "使用：恢复240到280点生命值。"}
	d["potion_mana3"] = {"name": "港制法力药水", "q": 1, "slot": "", "type": "potion", "ilvl": 16, "req": 16, "stack": 5, "price": 70, "icon": "potion_blue", "color": Color("6484e3"),
		"use": {"mana": [280, 320], "cd": 120.0}, "desc": "使用：恢复280到320点法力值。"}
	d["hearthstone"] = {"name": "返程石", "q": 1, "slot": "", "type": "misc", "ilvl": 1, "stack": 1, "price": 0, "icon": "hearth", "color": Color("7fb2ff"), "soulbound": true,
		"use": {"spell": "hearthstone_cast"}, "desc": "使用：10秒后返回你绑定的旅店。与旅店老板交谈来改变绑定地点。"}
	d["mount_horse_item"] = {"name": "缰绳：高地骏马", "q": 3, "slot": "", "type": "misc", "ilvl": 10, "req": 10, "stack": 1, "price": 0, "icon": "horse", "color": Color("c7905a"),
		"use": {"learn": "mount_horse"}, "desc": "使用：学会召唤高地骏马。需要初级骑术。"}
	d["mount_mech_item"] = {"name": "钥匙：魔导机车", "q": 4, "slot": "", "type": "misc", "ilvl": 15, "req": 15, "stack": 1, "price": 0, "icon": "gear", "color": Color("e0a050"),
		"use": {"learn": "mount_mech"}, "desc": "使用：学会召唤魔导机车。晴岚港工匠的得意之作。"}
	d["mount_deer_item"] = {"name": "缰绳：晨露白鹿", "q": 3, "slot": "", "type": "misc", "ilvl": 10, "req": 10, "stack": 1, "price": 0, "icon": "deer", "color": Color("f2eee2"),
		"use": {"learn": "mount_deer"}, "desc": "使用：学会召唤晨露白鹿。需要初级骑术。"}
	d["mount_wolf_item"] = {"name": "缰绳：灰巾座狼", "q": 3, "slot": "", "type": "misc", "ilvl": 15, "req": 15, "stack": 1, "price": 0, "icon": "wolf", "color": Color("8a8a94"),
		"use": {"learn": "mount_wolf"}, "desc": "使用：学会召唤灰巾座狼。需要初级骑术。"}
	d["mount_bear_item"] = {"name": "缰绳：铁鬃战熊", "q": 4, "slot": "", "type": "misc", "ilvl": 20, "req": 20, "stack": 1, "price": 0, "icon": "bear", "color": Color("7a5a3a"),
		"use": {"learn": "mount_bear"}, "desc": "使用：学会召唤铁鬃战熊。需要初级骑术。"}

	# ---- 材料与垃圾
	var junk := {
		"j_wolf_fang": ["破损的狼牙", "fang", Color("e0e0d0"), 4], "j_wolf_pelt": ["粗糙的狼皮", "leather", Color("7a6a5a"), 6],
		"j_boar_tusk": ["野猪獠牙", "fang", Color("f0e8d0"), 5], "j_rat_candle": ["融化的蜡烛头", "candle", Color("f0e0a0"), 3],
		"j_dirty_cloth": ["脏兮兮的布条", "cloth", Color("8a8070"), 2], "j_gray_bandana": ["褪色的灰头巾", "cloth", Color("8a8a8a"), 8],
		"j_frog_scale": ["黏滑的鳞片", "fin", Color("60a0a0"), 6], "j_spider_silk": ["粗蛛丝", "web", Color("f0f0f0"), 7],
		"j_bear_paw": ["熊掌", "claw", Color("6a4a30"), 12], "j_gear": ["破碎的齿轮", "gear", Color("b0a080"), 10],
		"j_hyena_charm": ["鬣人骨饰", "bone", Color("e0d8c0"), 11], "j_crab_shell": ["蟹壳碎片", "claw", Color("e07050"), 13],
		"j_straw": ["一捆干稻草", "herb", Color("e0c070"), 12], "j_feather": ["凌乱的羽毛", "feather", Color("c0c0e0"), 15],
		"j_jelly": ["果冻块", "gem", Color("80e0a0"), 3], "j_rotwood": ["腐朽木块", "herb", Color("6a5a3a"), 18], "j_stone_chip": ["雕像碎石", "ore", Color("a0a0a0"), 18],
		"j_rabbit_foot": ["兔脚", "bone", Color("e0d0c0"), 1],
	}
	for k in junk:
		var j: Array = junk[k]
		d[k] = {"name": j[0], "q": 0, "slot": "", "type": "junk", "ilvl": 1, "stack": 20, "price": j[3], "icon": j[1], "color": j[2]}
	d["mat_linen"] = {"name": "亚麻布", "q": 1, "slot": "", "type": "trade", "ilvl": 5, "stack": 20, "price": 4, "icon": "cloth", "color": Color("e0d8c0"), "desc": "商业技能材料"}
	d["mat_wool"] = {"name": "毛料", "q": 1, "slot": "", "type": "trade", "ilvl": 12, "stack": 20, "price": 12, "icon": "cloth", "color": Color("c0b090"), "desc": "商业技能材料"}
	d["mat_leather"] = {"name": "轻皮", "q": 1, "slot": "", "type": "trade", "ilvl": 5, "stack": 20, "price": 6, "icon": "leather", "color": Color("a07040"), "desc": "商业技能材料"}
	d["mat_copper"] = {"name": "铜矿石", "q": 1, "slot": "", "type": "trade", "ilvl": 5, "stack": 20, "price": 5, "icon": "ore", "color": Color("d08050"), "desc": "商业技能材料"}
	d["mat_herb"] = {"name": "宁神花", "q": 1, "slot": "", "type": "trade", "ilvl": 5, "stack": 20, "price": 5, "icon": "flower", "color": Color("f0f0a0"), "desc": "商业技能材料"}
	d["mat_aether"] = {"name": "以太碎晶", "q": 2, "slot": "", "type": "trade", "ilvl": 12, "stack": 20, "price": 60, "icon": "gem", "color": Color("a080ff"), "desc": "蕴含微弱以太能量的晶体。"}

	# ---- 任务物品
	var qi := {
		"q_candle": ["鼠人的蜡烛", "candle", Color("f0e080")], "q_herb_dew": ["晨露草", "herb", Color("90e0a0")],
		"q_grape_crate": ["葡萄酒箱", "crate", Color("a06040")], "q_garrok_bandana": ["加洛克的灰头巾", "cloth", Color("707070")],
		"q_letter_abbey": ["修道院的推荐信", "letter", Color("f0e0c0")], "q_jelly": ["晶莹果冻", "gem", Color("80f0b0")],
		"q_boar_ribs": ["野猪肋排", "meat", Color("c06050")], "q_grain_sack": ["被偷的粮袋", "bag", Color("d0b070")],
		"q_secret_letter": ["灰巾帮密信", "letter", Color("b0b0b0")], "q_ore_sample": ["深石矿样", "ore", Color("c09060")],
		"q_miner_badge": ["矿工徽章", "coin", Color("e0c050")], "q_gold_nugget": ["监工的金块", "ore", Color("ffd040")],
		"q_frog_fin": ["蛙人的鳍", "fin", Color("40a0a0")], "q_fishing_net": ["鲍勃的渔网", "web", Color("c0b090")],
		"q_spider_leg": ["林蛛的腿", "claw", Color("4a3a3a")], "q_lumber": ["优质木材", "crate", Color("a07040")],
		"q_aether_core": ["以太核心", "gem", Color("80c0ff")], "q_hyena_fang": ["狂牙鬣人的獠牙", "fang", Color("f0e0c0")],
		"q_grok_head": ["狂牙之王的獠牙项链", "bone", Color("e0c080")], "q_stark_orders": ["斯塔克的命令书", "scroll", Color("e0d0a0")],
		"q_crab_meat": ["鲜嫩蟹肉", "meat", Color("f0a090")], "q_oil_jar": ["火油罐", "potion_red", Color("c06030")],
		"q_sanctum_map": ["旧圣堂地图", "map", Color("e0d0a0")], "q_steam_core": ["蒸汽核心", "gear", Color("e0a050")],
		"q_harpy_feather": ["风妖的翎羽", "feather", Color("a0e0c0")], "q_rotheart": ["腐根之心", "herb", Color("6a8a3a")],
		"q_lake_pistol": ["旧航印记", "ore", Color("8a8a9a")], "q_bell_shard": ["旧出航钟碎片", "ore", Color("8070a0")],
		"q_permit": ["晴岚港市民证", "scroll", Color("e8c27a")], "q_crop_sample": ["变异的麦穗", "herb", Color("e0d060")],
		"q_wolf_meat": ["新鲜狼肉", "meat", Color("c05050")], "q_signal_part": ["信号灯零件", "gear", Color("c0c0c0")],
		"q_ash_ledger": ["灰烬账本", "scroll", Color("9a8a70")], "q_seal_fragment": ["裂开的港务印章", "coin", Color("c0a060")],
		"q_aether_lens": ["浑浊以太透镜", "gem", Color("90c0ff")], "q_ember_core": ["余烬核心", "gem", Color("ff8060")],
		"q_lighthouse_cell": ["灯塔燃料芯", "gear", Color("f0c060")], "q_ledger_page": ["失踪的账页", "scroll", Color("d0c0a0")],
		"q_e_cargo_seal": ["封存货箱标签", "letter", Color("d0b48c")], "q_e_tide_orders": ["夜航调令", "scroll", Color("c5b89e")],
		"q_e_dispatch": ["篡改的调度单", "letter", Color("b3bbc1")], "q_e_signal_part": ["信号继电器", "gear", Color("c6ac71")],
		"q_e_regulator": ["稳压器", "gear", Color("a3bbc2")], "q_e_route_map": ["秘密运送路线图", "map", Color("c6b188")],
		"q_e_coast_cache": ["密封补给箱", "crate", Color("9d8167")], "q_e_rescue_kit": ["船员急救包", "bag", Color("d6c3a6")],
		"q_e_lens_frame": ["航标镜架", "gear", Color("a6bfc4")], "q_e_cipher": ["航标密文", "scroll", Color("b1abc9")],
		"q_e_launch_key": ["夜航启动钥匙", "gear", Color("d2a367")], "q_e_charge": ["余烬装药", "potion_red", Color("c17b54")],
		"q_e_shutdown": ["停机阀组件", "gear", Color("9db1ae")],
	}
	for k in qi:
		var a: Array = qi[k]
		d[k] = {"name": a[0], "q": 1, "slot": "", "type": "quest", "ilvl": 1, "stack": 20, "price": 0, "icon": a[1], "color": a[2], "quest_item": true}
	d["q_secret_letter"]["starts_quest"] = "q_b9"
	d["q_secret_letter"]["stack"] = 1

	# ---- 首领掉落（精良/史诗）
	d["b_rootguard_staff"] = {"name": "腐根守卫之杖", "q": 3, "slot": "two", "type": "staff", "ilvl": 18, "req": 14, "stats": {"int": 8, "spi": 6, "sta": 4}, "sp": 6, "color": Color("5a7a3a")}
	d["b_rootguard_cloak"] = {"name": "苔藓斗篷", "q": 3, "slot": "back", "type": "cloth", "ilvl": 18, "req": 14, "stats": {"sta": 4, "agi": 4}, "color": Color("4a6a3a")}
	d["b_rootguard_bracer"] = {"name": "盘根护腕", "q": 3, "slot": "wrist", "type": "mail", "ilvl": 18, "req": 14, "stats": {"str": 4, "sta": 3}, "color": Color("6a7a5a")}
	d["b_lake_gun"] = {"name": "双枪莱克的爱枪", "q": 3, "slot": "ranged", "type": "gun", "ilvl": 19, "req": 14, "stats": {"agi": 4}, "color": Color("4a4a5a")}
	d["b_lake_vest"] = {"name": "亡命徒马甲", "q": 3, "slot": "chest", "type": "leather", "ilvl": 19, "req": 14, "stats": {"agi": 8, "sta": 5}, "color": Color("5a4a3a")}
	d["b_lake_blade"] = {"name": "灰巾帮的弯刀", "q": 3, "slot": "one", "type": "sword", "ilvl": 19, "req": 14, "stats": {"str": 3, "agi": 3}, "color": Color("c0c0d0")}
	d["b_victor_hammer"] = {"name": "守钟人的丧钟之锤", "q": 3, "slot": "two", "type": "mace2", "ilvl": 20, "req": 15, "stats": {"str": 11, "sta": 7}, "color": Color("6a6080")}
	d["b_victor_robe"] = {"name": "钟楼守望者长袍", "q": 3, "slot": "chest", "type": "cloth", "ilvl": 20, "req": 15, "stats": {"int": 9, "spi": 7, "sta": 4}, "sp": 8, "color": Color("40405a"), "robe": true}
	d["b_victor_helm"] = {"name": "鸣钟战盔", "q": 3, "slot": "head", "type": "mail", "ilvl": 20, "req": 15, "stats": {"str": 7, "sta": 8}, "color": Color("8a8aa0")}
	d["b_victor_dagger"] = {"name": "回响之刃", "q": 4, "slot": "one", "type": "dagger", "ilvl": 22, "req": 15, "stats": {"agi": 6, "sta": 4}, "crit": 1, "color": Color("a080ff")}
	d["b_grok_axe"] = {"name": "狂牙之王的獠牙斧", "q": 3, "slot": "two", "type": "axe2", "ilvl": 13, "req": 9, "stats": {"str": 7, "sta": 4}, "color": Color("c0b090")}
	d["b_mk0_core"] = {"name": "MK-0 的以太核心", "q": 3, "slot": "trinket", "type": "misc", "ilvl": 13, "req": 9, "stats": {"sta": 5, "int": 4}, "color": Color("80c0ff")}
	d["r_greymane_cloak"] = {"name": "灰鬃毛皮披风", "q": 3, "slot": "back", "type": "cloth", "ilvl": 9, "req": 5, "stats": {"agi": 3, "sta": 3}, "color": Color("8a8a90")}
	d["r_tusk_ring"] = {"name": "石牙指环", "q": 3, "slot": "finger", "type": "misc", "ilvl": 10, "req": 6, "stats": {"str": 3, "sta": 3}, "color": Color("e0d0b0")}
	# ---- 余烬夜航：固定精良装备，由海岸领航者与夜航指挥官掉落
	d["b_ember_blade"] = {"name": "余烬誓约之刃", "q": 3, "slot": "one", "type": "sword", "ilvl": 19, "req": 18, "stats": {"str": 6, "sta": 5}, "color": Color("bd906a"),
		"desc": "缴获自余烬夜航指挥官。刃脊刻着被火烧旧的航线。"}
	d["b_ember_focus"] = {"name": "雾灯航标魔典", "q": 3, "slot": "off", "type": "offhand", "ilvl": 19, "req": 18, "stats": {"int": 7, "spi": 5}, "sp": 4, "color": Color("8195b6"),
		"desc": "余烬镜阵的校准记录，拆除了危险的燃芯回路。"}
	d["b_ember_gun"] = {"name": "赤帆夜航火枪", "q": 3, "slot": "ranged", "type": "gun", "ilvl": 19, "req": 18, "stats": {"agi": 6, "sta": 4}, "color": Color("9d7963"),
		"desc": "护航队使用的可靠火枪，枪托仍带着海盐的痕迹。"}
	return d

## 地区商人售卖表（物品 id 列表）
static func vendors() -> Dictionary:
	return {
		"general": ["food_bread", "food_meat", "drink_water", "drink_juice", "potion_heal1", "potion_mana1"],
		"general2": ["food_bread", "food_meat", "food_cheese", "drink_water", "drink_juice", "drink_milk", "potion_heal1", "potion_heal2", "potion_mana1"],
		"food": ["food_bread", "food_meat", "food_cheese", "drink_water", "drink_juice", "drink_milk"],
		"potion": ["potion_heal1", "potion_heal2", "potion_mana1", "potion_heal3", "potion_mana3"],
		"smith_abbey": ["gen|sword|white|3", "gen|axe|white|3", "gen|mace|white|3", "gen|dagger|white|3", "gen|staff|white|3", "gen|sword2|white|3", "gen|gun|white|3", "gen|shield|white|3"],
		"armor_abbey": ["gen|chest|cloth|white|3", "gen|legs|cloth|white|3", "gen|chest|leather|white|3", "gen|legs|leather|white|3", "gen|chest|mail|white|3", "gen|legs|mail|white|3", "gen|feet|leather|white|3", "gen|hands|mail|white|3"],
		"smith_town": ["gen|sword|white|8", "gen|axe|white|8", "gen|mace|white|8", "gen|dagger|white|8", "gen|staff|white|8", "gen|sword2|white|8", "gen|axe2|white|8", "gen|mace2|white|8", "gen|polearm|white|8", "gen|gun|white|8", "gen|bow|white|8", "gen|shield|white|8"],
		"armor_town": ["gen|chest|mail|white|8", "gen|legs|mail|white|8", "gen|head|mail|white|8", "gen|feet|mail|white|8", "gen|hands|mail|white|8", "gen|waist|mail|white|8", "gen|wrist|mail|white|8",
			"gen|chest|leather|white|8", "gen|legs|leather|white|8", "gen|feet|leather|white|8", "gen|hands|leather|white|8"],
		"tailor_town": ["gen|chest|cloth|white|8", "gen|legs|cloth|white|8", "gen|head|cloth|white|8", "gen|feet|cloth|white|8", "gen|hands|cloth|white|8", "gen|waist|cloth|white|8", "gen|wrist|cloth|white|8", "gen|back|cloth|white|8"],
		"camp": ["food_meat", "food_cheese", "drink_juice", "drink_milk", "potion_heal1", "potion_heal2", "potion_mana1", "gen|chest|mail|white|13", "gen|chest|leather|white|13", "gen|chest|cloth|white|13", "gen|gun|white|13", "gen|sword|white|13", "gen|staff|white|13"],
		"city_weapon": ["gen|rapier|white|15", "gen|sword|white|15", "gen|axe|white|15", "gen|mace|white|15", "gen|dagger|white|15", "gen|staff|white|15", "gen|sword2|white|15", "gen|axe2|white|15", "gen|mace2|white|15", "gen|polearm|white|15", "gen|gun|white|15", "gen|bow|white|15", "gen|shield|white|15", "gen|offhand|white|15"],
		"city_armor": ["gen|chest|mail|white|15", "gen|legs|mail|white|15", "gen|head|mail|white|15", "gen|chest|leather|white|15", "gen|legs|leather|white|15", "gen|head|leather|white|15",
			"gen|chest|cloth|white|15", "gen|legs|cloth|white|15", "gen|head|cloth|white|15", "gen|back|cloth|white|15"],
		"jewelry": ["gen|finger|misc|green|14|bear", "gen|finger|misc|green|14|owl", "gen|finger|misc|green|14|monkey", "gen|neck|misc|green|14|eagle", "gen|neck|misc|green|14|tiger", "gen|neck|misc|green|14|whale"],
		"flowers": ["flower_rose", "flower_lily", "flower_sun"],
		"rare": ["mount_mech_item", "gen|trinket|misc|blue|18|falcon", "gen|back|cloth|blue|18|monkey", "gen|back|cloth|blue|18|owl", "gen|back|cloth|blue|18|bear"],
		# 坐骑：马厩只卖基础的高地骏马；白鹿 / 座狼走声望军需，战熊走成就奖励（见 src/data/data_mounts.gd 的 src）
		"stable": ["mount_horse_item"],
		"cook_guild": ["mat_spice", "drink_water", "drink_milk", "food_bread", "food_cheese"],
		"smith_guild": ["mat_copper", "gen|sword|white|15", "gen|axe|white|15", "gen|mace|white|15", "gen|shield|white|15", "gen|chest|mail|white|15", "gen|legs|mail|white|15"],
		"artisan_guild": ["mat_copper", "mat_linen"],
		# ===== 声望军需官：条目可写成 {"id": 物品, "rep": [阵营, 等级]}，等级 1=友善 2=尊敬 3=崇敬 4=崇拜
		"qm_abbey": [
			{"id": "gen|legs|mail|blue|14|bear", "rep": ["abbey", 1]},
			{"id": "gen|mace|blue|16|eagle", "rep": ["abbey", 2]},
			{"id": "gen|neck|misc|blue|18|owl", "rep": ["abbey", 3]},
			{"id": "mount_deer_item", "rep": ["abbey", 3]},
			"gen|chest|mail|white|12", "potion_heal2"],
		"qm_goldshire": [
			{"id": "gen|legs|leather|blue|14|monkey", "rep": ["goldshire", 1]},
			{"id": "gen|sword|blue|16|tiger", "rep": ["goldshire", 2]},
			{"id": "gen|feet|mail|blue|18|bear", "rep": ["goldshire", 3]},
			"food_cheese", "drink_milk"],
		"qm_city": [
			{"id": "gen|back|cloth|blue|15|owl", "rep": ["city", 1]},
			{"id": "gen|chest|mail|blue|17|bear", "rep": ["city", 2]},
			{"id": "gen|finger|misc|blue|18|falcon", "rep": ["city", 3]},
			{"id": "gen|sword2|purple|20|tiger", "rep": ["city", 4]},
			"potion_mana1"],
		"qm_guild": [
			{"id": "gen|waist|leather|blue|15|monkey", "rep": ["guild", 1]},
			{"id": "gen|gun|blue|17|falcon", "rep": ["guild", 2]},
			{"id": "mount_wolf_item", "rep": ["guild", 3]},
			{"id": "gen|trinket|misc|purple|20|bear", "rep": ["guild", 4]},
			"gen|dagger|white|13"],
		"qm_tower": [
			{"id": "gen|head|cloth|blue|15|owl", "rep": ["tower", 1]},
			{"id": "gen|staff|blue|17|eagle", "rep": ["tower", 2]},
			{"id": "gen|offhand|blue|18|int", "rep": ["tower", 3]},
			"mat_aether"],
	}

static func extra_items() -> Dictionary:
	return {
		"flower_rose": {"name": "晴岚玫瑰", "q": 1, "slot": "", "type": "misc", "ilvl": 1, "stack": 20, "price": 10, "icon": "flower", "color": Color("ff5070"), "desc": "芬芳的红玫瑰。可以送给心仪的人。"},
		"flower_lily": {"name": "海风百合", "q": 1, "slot": "", "type": "misc", "ilvl": 1, "stack": 20, "price": 10, "icon": "flower", "color": Color("f0f0ff"), "desc": "生长在海崖边的白色百合。"},
		"flower_sun": {"name": "向阳花", "q": 1, "slot": "", "type": "misc", "ilvl": 1, "stack": 20, "price": 10, "icon": "flower", "color": Color("ffd040"), "desc": "总是朝着太阳的明黄色花朵。"},
	}
