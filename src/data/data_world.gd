class_name DataWorld
extends RefCounted
## 地区、NPC、任务、飞行路线数据

static func zones() -> Dictionary:
	return {
		"vale": {"name": "晨露谷", "levels": "1-10", "scene": "res://scenes/zones/dawnmist_vale.tscn", "terrain": "res://data/terrain/vale.res",
			"weather": {"clear": 0.55, "cloudy": 0.25, "rain": 0.15, "storm": 0.05}, "outdoor": true, "far_land": {"sea": ["south"]},
			"desc": "温和宜人的谷地。晨钟修道院与金穗镇守护着这片土地，然而灰巾帮的阴影正在悄悄蔓延。"},
		"tidewind": {"name": "潮风高地", "levels": "10-20", "scene": "res://scenes/zones/tidewind_highlands.tscn", "terrain": "res://data/terrain/tidewind.res",
			"weather": {"clear": 0.45, "cloudy": 0.25, "rain": 0.15, "fog": 0.1, "storm": 0.05}, "outdoor": true, "far_land": {"sea": ["west", "south", "east"]},
			"desc": "海风吹拂的高地，西岸坐落着港口城市晴岚港——魔导列车与飞空艇的枢纽。市民篇会把调查线推进到旧铁路、海岸前哨和山麓指挥营地。"},
		"sanctum": {"name": "风语旧圣堂", "levels": "14-16", "scene": "res://scenes/zones/windwhisper_sanctum.tscn", "terrain": "res://data/terrain/sanctum.res",
			"weather": {"clear": 1.0}, "outdoor": true, "instance": true, "dungeon": true,
			"min_level": 14, "spawn_in": "from_tidewind", "entrance": ["tidewind", "from_sanctum"], "entrance_name": "潮风高地东南 · 风语旧圣堂入口",
			"bosses": ["boss_rootguard", "boss_lake", "boss_sanctum_lantern", "boss_victor"],
			"desc": "古王国水手与商人供奉海洋女神的祈航圣堂。魔法科技兴起后，信仰渐淡，圣堂荒废百年，如今已被藤蔓魔物与附近鼠人蛮族占据。"},
	}

static func flight_paths() -> Dictionary:
	return {
		"fp_goldenear": {"name": "金穗镇", "zone": "vale", "cost": 50},
		"fp_lumber": {"name": "林风伐木场", "zone": "vale", "cost": 50},
		"fp_abbey": {"name": "晨钟修道院", "zone": "vale", "cost": 50},
		"fp_camp": {"name": "东门哨站", "zone": "tidewind", "cost": 100},
		"fp_windmill": {"name": "风车农庄", "zone": "tidewind", "cost": 100},
		"fp_solenne": {"name": "晴岚港 · 飞空艇站", "zone": "tidewind", "cost": 100, "needs": "city_access"},
	}

## 邮箱柱摆放：[x, z, 朝向角度]（区域本地坐标）。世界加载时由 world.gd 生成，
## 靠近后按交互键打开邮箱窗口（见 src/world/postbox.gd、src/core/mail.gd）。
static func postboxes() -> Dictionary:
	return {
		"vale": [[452, 512, 200], [497, 134, 250], [214, 486, 90]],
		"tidewind": [[95, 392, 180], [46, 738, 90], [-176, 486, 270]],
		"sanctum": [[0, 40, 180]],
	}

## NPC 外观：g 性别、outfit 服装预设、可覆盖 hair/hair_color/skin
static func npcs() -> Dictionary:
	var n := {}
	# ===== 晨钟修道院
	n["marcus"] = {"name": "马库斯", "sub": "修道院守备官", "g": "m", "outfit": "knight", "hair": 2, "hair_color": Color("6a4a30"), "beard": true,
		"greet": "愿圣光指引你，冒险者。晨钟修道院虽小，却是这片谷地的第一道防线。"}
	n["lina"] = {"name": "莉娜", "sub": "副队长", "g": "f", "outfit": "guard_abbey", "hair": 4, "hair_color": Color("c08040"),
		"greet": "别站在那儿发呆了，修道院外面的麻烦可不会自己消失。"}
	n["samuel"] = {"name": "塞缪尔", "sub": "修士", "g": "m", "outfit": "monk", "hair": 0, "hair_color": Color("8a8a8a"),
		"greet": "晨露草只在清晨的阳光下才会绽放……多么美丽的造物啊。"}
	n["milo"] = {"name": "米洛", "sub": "酿酒师", "g": "m", "outfit": "farmer", "hair": 1, "hair_color": Color("a05030"),
		"greet": "我的葡萄园！我那些可怜的葡萄！"}
	n["tom"] = {"name": "汤姆", "sub": "军需官", "g": "m", "outfit": "merchant", "hair": 3, "hair_color": Color("3a2a20"), "vendor": "general", "qm": "abbey",
		"greet": "需要补给吗？面包、清水，出门在外可别饿着肚子。"}
	n["gwen"] = {"name": "格温", "sub": "武器匠", "g": "f", "outfit": "smith", "hair": 5, "hair_color": Color("8a3020"), "vendor": "smith_abbey",
		"greet": "一把趁手的武器，能救你的命。"}
	n["lucy"] = {"name": "露西", "sub": "护甲商", "g": "f", "outfit": "merchant", "hair": 6, "hair_color": Color("e0c080"), "vendor": "armor_abbey",
		"greet": "穿得结实点，外面的狼可不讲道理。"}
	n["t_warrior_1"] = {"name": "雷恩", "sub": "战士训练师", "g": "m", "outfit": "knight", "hair": 1, "hair_color": Color("3a3a3a"), "trainer": "warrior", "greet": "握紧你的剑，让敌人感受你的怒火！"}
	n["t_mage_1"] = {"name": "艾薇拉", "sub": "法师训练师", "g": "f", "outfit": "mage", "hair": 7, "hair_color": Color("a0c0ff"), "trainer": "mage", "greet": "奥术是一门精确的学问，可不是随便挥挥手就行的。"}
	n["t_priest_1"] = {"name": "安娜", "sub": "牧师训练师", "g": "f", "outfit": "priest", "hair": 4, "hair_color": Color("f0e0b0"), "trainer": "priest", "greet": "圣光与你同在，孩子。"}
	n["t_rogue_1"] = {"name": "影", "sub": "盗贼训练师", "g": "m", "outfit": "rogue", "hair": 3, "hair_color": Color("202020"), "trainer": "rogue", "greet": "……你是怎么找到我的？算了，有什么事快说。"}
	n["t_gunner_1"] = {"name": "布洛克", "sub": "魔导枪手训练师", "g": "m", "outfit": "hunter", "hair": 2, "hair_color": Color("6a5030"), "beard": true, "trainer": "gunner", "greet": "火药、以太和一双好眼睛——这就是枪手的全部。"}
	n["guard_abbey"] = {"name": "修道院卫兵", "sub": "", "g": "m", "outfit": "guard_abbey", "guard": true, "greet": "保持警惕，冒险者。"}
	# ===== 金穗镇
	n["duke"] = {"name": "杜克", "sub": "金穗镇治安官", "g": "m", "outfit": "knight", "hair": 2, "hair_color": Color("9a9a9a"), "beard": true, "qm": "goldshire",
		"greet": "金穗镇是个好地方，我不会让任何人破坏它的安宁。"}
	n["faria"] = {"name": "法莉亚", "sub": "旅店老板娘", "g": "f", "outfit": "barmaid", "hair": 6, "hair_color": Color("c06030"), "innkeeper": true, "vendor": "food", "prof": "cook",
		"greet": "欢迎来到金穗旅店！累了就进来歇歇脚吧，热汤管够。"}
	n["argo"] = {"name": "阿尔戈", "sub": "铁匠", "g": "m", "outfit": "smith", "hair": 0, "hair_color": Color("2a2a2a"), "beard": true, "vendor": "smith_town", "prof": "smith", "greet": "叮——叮——叮——嗯？要买武器？"}
	n["dorn"] = {"name": "多恩", "sub": "护甲商", "g": "m", "outfit": "smith", "hair": 1, "hair_color": Color("6a4a30"), "vendor": "armor_town", "greet": "上好的锁甲和皮甲，童叟无欺。"}
	n["britta"] = {"name": "布丽塔", "sub": "杂货商", "g": "f", "outfit": "merchant", "hair": 5, "hair_color": Color("e0c080"), "vendor": "general", "greet": "需要点什么？药水、食物，应有尽有！"}
	n["kate"] = {"name": "凯特", "sub": "裁缝", "g": "f", "outfit": "noble", "hair": 7, "hair_color": Color("402030"), "vendor": "tailor_town", "greet": "这些布料都是我亲手织的哦。"}
	n["fizz"] = {"name": "菲兹", "sub": "飞艇驿站管理员", "g": "m", "outfit": "engineer", "hair": 3, "hair_color": Color("e08040"), "flight": "fp_goldenear", "train": "solenne", "prof": "artisan", "greet": "要坐小飞艇吗？安全第一，速度第二……大概。铁路修好以后，我这儿也代售去晴岚港的车票。"}
	n["ron"] = {"name": "罗恩", "sub": "马厩管理员", "g": "m", "outfit": "farmer", "hair": 2, "hair_color": Color("8a6a40"), "vendor": "stable", "riding": true,
		"greet": "这些高地骏马是整个谷地最好的马。到了10级再来找我学骑术吧。"}
	# 独立的坐骑商人：与马厩管理员共用 stable 货单/骑术服务链路，站在马厩门外，避免与室内 NPC 重叠。
	n["mount_merchant_vale"] = {"name": "芙蕾雅", "sub": "坐骑商人", "g": "f", "outfit": "ranger", "hair": 6, "hair_color": Color("c080a0"),
		"vendor": "stable", "riding": true, "greet": "想找一匹可靠的伙伴吗？高地骏马已经备好，先学会骑术再上路。"}
	n["t_warrior_2"] = {"name": "葛兰", "sub": "战士训练师", "g": "m", "outfit": "knight", "hair": 0, "hair_color": Color("3a2a20"), "beard": true, "trainer": "warrior", "greet": "又一个想学打架的？很好。"}
	n["t_mage_2"] = {"name": "莫甘娜", "sub": "法师训练师", "g": "f", "outfit": "mage", "hair": 6, "hair_color": Color("6040a0"), "trainer": "mage", "greet": "专注，冒险者。专注。"}
	n["t_priest_2"] = {"name": "约书亚", "sub": "牧师训练师", "g": "m", "outfit": "priest", "hair": 1, "hair_color": Color("e0d0b0"), "trainer": "priest", "greet": "治愈他人，便是治愈自己。"}
	n["t_rogue_2"] = {"name": "夜莺", "sub": "盗贼训练师", "g": "f", "outfit": "rogue", "hair": 4, "hair_color": Color("202030"), "trainer": "rogue", "greet": "嘘——小声点。"}
	n["t_gunner_2"] = {"name": "霍克", "sub": "魔导枪手训练师", "g": "m", "outfit": "hunter", "hair": 1, "hair_color": Color("aa7a40"), "trainer": "gunner", "greet": "瞄准，呼吸，扣扳机。"}
	n["guard_town"] = {"name": "金穗镇卫兵", "sub": "", "g": "m", "outfit": "guard_town", "guard": true, "greet": "需要问路吗？"}
	n["villager"] = {"name": "金穗镇居民", "sub": "", "g": "r", "outfit": "villager", "ambient": true, "greet": "今天天气真好啊。"}
	n["hob"] = {"name": "霍布", "sub": "农夫", "g": "m", "outfit": "farmer", "hair": 2, "hair_color": Color("8a6a40"), "beard": true, "greet": "这些年的收成……唉。"}
	n["martha"] = {"name": "玛莎", "sub": "农妇", "g": "f", "outfit": "farmer", "hair": 5, "hair_color": Color("6a4030"), "greet": "要尝尝我做的野猪肉炖菜吗？前提是你得先帮我弄到肋排。"}
	n["gib"] = {"name": "吉布", "sub": "矿工", "g": "m", "outfit": "miner", "hair": 0, "hair_color": Color("4a3a30"), "beard": true, "greet": "那些该死的鼠人把我们赶出了矿坑！"}
	n["bob"] = {"name": "鲍勃", "sub": "渔夫", "g": "m", "outfit": "sailor", "hair": 3, "hair_color": Color("aaaaaa"), "beard": true, "greet": "镜湖的鱼啊，以前可多了……在那些蛙人来之前。"}
	n["thad"] = {"name": "萨德", "sub": "伐木场工头", "g": "m", "outfit": "lumberjack", "hair": 1, "hair_color": Color("a04020"), "beard": true, "greet": "嘿！小心脚下，这片林子最近不太平。"}
	n["pip_fp"] = {"name": "皮普", "sub": "飞艇驿站管理员", "g": "m", "outfit": "engineer", "hair": 4, "hair_color": Color("40a0e0"), "flight": "fp_lumber", "greet": "林风伐木场驿站，随时为你服务！"}
	n["abbey_fp"] = {"name": "缇娜", "sub": "飞艇驿站管理员", "g": "f", "outfit": "engineer", "hair": 6, "hair_color": Color("e06080"), "flight": "fp_abbey", "greet": "从修道院出发，去哪儿都很方便哦。"}
	n["selena"] = {"name": "赛琳娜", "sub": "蔚蓝之塔法师", "g": "f", "outfit": "mage", "hair": 7, "hair_color": Color("e0e0ff"), "qm": "tower", "greet": "工坊那边的傀儡又失控了……真是麻烦。"}
	n["vick"] = {"name": "维克", "sub": "老猎人", "g": "m", "outfit": "hunter", "hair": 2, "hair_color": Color("aaaaaa"), "beard": true, "greet": "狂牙岭的鬣人越来越多了。年轻人，你会用武器吧？"}
	n["elin"] = {"name": "艾琳", "sub": "斥候", "g": "f", "outfit": "ranger", "hair": 4, "hair_color": Color("40302a"), "greet": "这条路通往潮风高地和晴岚港。路上小心。"}
	# ===== 潮风高地 · 东门哨站
	n["loren"] = {"name": "洛伦", "sub": "哨站指挥官", "g": "m", "outfit": "guard_city", "hair": 1, "hair_color": Color("3a3a3a"), "greet": "晴岚港正处于封城警戒中。在查清灰巾帮的阴谋之前，任何人都不能随意进城。"}
	n["isa"] = {"name": "伊莎", "sub": "移民登记官", "g": "f", "outfit": "noble", "hair": 6, "hair_color": Color("e0b060"), "greet": "想获得晴岚港的市民身份？那你得先证明自己的价值。"}
	n["pip"] = {"name": "皮普", "sub": "流动商人", "g": "m", "outfit": "merchant", "hair": 3, "hair_color": Color("e0c040"), "vendor": "camp", "greet": "旅途必需品！价格公道！"}
	n["grace"] = {"name": "葛蕾丝", "sub": "帐篷旅馆老板", "g": "f", "outfit": "barmaid", "hair": 5, "hair_color": Color("a04030"), "innkeeper": true, "vendor": "food", "greet": "帐篷虽小，但被窝很暖和哦。"}
	n["oscar"] = {"name": "奥斯卡", "sub": "冒险者导师", "g": "m", "outfit": "knight", "hair": 2, "hair_color": Color("e0e0e0"), "beard": true, "trainer": "all", "greet": "无论你修习哪一门技艺，我都能教你几招。"}
	n["bran"] = {"name": "布兰", "sub": "飞艇驿站管理员", "g": "m", "outfit": "engineer", "hair": 1, "hair_color": Color("6a4a30"), "flight": "fp_camp", "greet": "东门哨站驿站。目前只开放城外航线。"}
	n["grant"] = {"name": "老格兰特", "sub": "农场主", "g": "m", "outfit": "farmer", "hair": 0, "hair_color": Color("cccccc"), "beard": true, "greet": "我种了一辈子的地，从没见过稻草人自己走路！"}
	n["mill_fp"] = {"name": "汉娜", "sub": "飞艇驿站管理员", "g": "f", "outfit": "engineer", "hair": 5, "hair_color": Color("c08040"), "flight": "fp_windmill", "greet": "风车农庄驿站，风大，抓稳了！"}
	n["howard"] = {"name": "霍华德", "sub": "铁路调度员", "g": "m", "outfit": "engineer", "hair": 2, "hair_color": Color("5a5a5a"), "beard": true, "greet": "旧站场废弃好几年了，可那些傀儡还在不停地游荡。"}
	n["lilian"] = {"name": "莉莉安", "sub": "鸟类学家", "g": "f", "outfit": "ranger", "hair": 7, "hair_color": Color("80a040"), "greet": "风鸣鸟妖的羽毛结构太迷人了！可惜它们脾气不太好。"}
	n["ed"] = {"name": "艾德", "sub": "圣堂守望者", "g": "m", "outfit": "priest", "hair": 1, "hair_color": Color("8a7a60"), "greet": "风语旧圣堂……曾经是信徒朝圣的地方。如今只剩下腐朽和阴谋。"}
	n["guard_city"] = {"name": "晴岚港卫兵", "sub": "", "g": "m", "outfit": "guard_city", "guard": true, "greet": "晴岚港欢迎你。需要指路吗？"}
	n["guard_city_f"] = {"name": "晴岚港卫兵", "sub": "", "g": "f", "outfit": "guard_city", "guard": true, "greet": "保持城市整洁，冒险者。"}
	n["refugee"] = {"name": "等待入城的旅人", "sub": "", "g": "r", "outfit": "villager", "greet": "已经在这里等了三天了……什么时候才能进城啊。"}
	# ===== 风语旧圣堂（同伴）
	n["garon"] = {"name": "加隆", "sub": "盾卫 · 同伴", "g": "m", "outfit": "knight", "hair": 1, "hair_color": Color("6a4a30"), "beard": true, "companion": "tank"}
	n["aria"] = {"name": "艾莉亚", "sub": "修女 · 同伴", "g": "f", "outfit": "priest", "hair": 6, "hair_color": Color("f0e0b0"), "companion": "healer"}
	n["frey"] = {"name": "芙蕾", "sub": "游侠 · 同伴", "g": "f", "outfit": "ranger", "hair": 4, "hair_color": Color("40a060"), "companion": "dps"}
	# ===== 晴岚港
	n["gate_captain"] = {"name": "罗兰", "sub": "城门守卫队长", "g": "m", "outfit": "guard_city", "hair": 2, "hair_color": Color("aa7a40"), "greet": "欢迎来到晴岚港——海风与以太之都。"}
	n["mayor"] = {"name": "阿德里安", "sub": "晴岚港市长", "g": "m", "outfit": "noble", "hair": 1, "hair_color": Color("bbbbbb"), "beard": true, "greet": "每一位新市民，都是这座城市的未来。"}
	n["guild_master"] = {"name": "葛雷森", "sub": "冒险者公会会长", "g": "m", "outfit": "knight", "hair": 2, "hair_color": Color("6a4a30"), "beard": true, "qm": "guild", "greet": "冒险者公会永远欢迎有本事的人。"}
	n["transmog"] = {"name": "薇薇安", "sub": "幻化师", "g": "f", "outfit": "noble", "hair": 7, "hair_color": Color("ff80c0"), "transmog": true, "greet": "外表是灵魂的第一张名片～要来改变一下造型吗？"}
	n["banker"] = {"name": "汉斯", "sub": "银行职员", "g": "m", "outfit": "noble", "hair": 3, "hair_color": Color("3a3a3a"), "bank": true, "greet": "晴岚港银行，您的财产安全由我们守护。"}
	n["banker2"] = {"name": "葛洛莉", "sub": "银行职员", "g": "f", "outfit": "noble", "hair": 5, "hair_color": Color("6a4030"), "bank": true, "greet": "需要存取物品吗？"}
	n["auctioneer"] = {"name": "米娅", "sub": "交易所拍卖师", "g": "f", "outfit": "noble", "hair": 6, "hair_color": Color("40a0c0"), "auction": true, "greet": "交易大厅今日行情火热！"}
	n["item_shop"] = {"name": "康拉德", "sub": "道具商人", "g": "m", "outfit": "merchant", "hair": 2, "hair_color": Color("8a5a30"), "vendor": "general2", "greet": "冒险必备道具，一站购齐！"}
	n["weapon_shop"] = {"name": "布鲁诺", "sub": "武器商", "g": "m", "outfit": "smith", "hair": 0, "hair_color": Color("1a1a1a"), "beard": true, "vendor": "city_weapon", "greet": "看看这些刀刃的光泽！"}
	n["armor_shop"] = {"name": "艾格尼丝", "sub": "防具商", "g": "f", "outfit": "smith", "hair": 5, "hair_color": Color("a04020"), "vendor": "city_armor", "greet": "从布衣到锁甲，应有尽有。"}
	n["jeweler"] = {"name": "奥萝拉", "sub": "珠宝匠", "g": "f", "outfit": "noble", "hair": 7, "hair_color": Color("f0d080"), "vendor": "jewelry", "greet": "每一颗宝石都有自己的故事。"}
	n["florist"] = {"name": "莉莉", "sub": "卖花姑娘", "g": "f", "outfit": "barmaid", "hair": 4, "hair_color": Color("f0a060"), "vendor": "flowers", "greet": "要买一束花吗？送给重要的人吧～"}
	n["potion_shop"] = {"name": "赫尔曼", "sub": "药剂师", "g": "m", "outfit": "mage", "hair": 3, "hair_color": Color("6a8a4a"), "vendor": "potion", "greet": "小心，别碰那个冒泡的瓶子。"}
	n["rare_shop"] = {"name": "卡西米尔", "sub": "珍品商人", "g": "m", "outfit": "noble", "hair": 1, "hair_color": Color("2a2a3a"), "vendor": "rare", "greet": "只有真正的鉴赏家，才配得上我的收藏。"}
	n["guild_reg"] = {"name": "诺拉", "sub": "公会登记员", "g": "f", "outfit": "noble", "hair": 6, "hair_color": Color("3a2a2a"), "greet": "想创建自己的公会吗？在我这里登记就可以。"}
	n["city_inn"] = {"name": "杰克", "sub": "海风旅店老板", "g": "m", "outfit": "barmaid", "hair": 2, "hair_color": Color("6a3a20"), "beard": true, "innkeeper": true, "vendor": "food", "greet": "海风旅店，最好的海景房！"}
	n["station_master"] = {"name": "格伦", "sub": "魔导列车站长", "g": "m", "outfit": "conductor", "hair": 2, "hair_color": Color("aaaaaa"), "beard": true, "train": "goldenear",
		"greet": "晴岚港中央车站，魔导列车准点发车！目前开通：晴岚港 ⇄ 金穗镇。"}
	n["airship_captain"] = {"name": "艾薇", "sub": "飞空艇船长", "g": "f", "outfit": "captain", "hair": 4, "hair_color": Color("c03030"), "flight": "fp_solenne",
		"greet": "天空之港！远洋航线还在筹备中，不过近郊航线随时可以出发。"}
	n["portal_mage"] = {"name": "奥莉薇亚", "sub": "传送门法师", "g": "f", "outfit": "mage", "hair": 7, "hair_color": Color("c0a0ff"), "portal": true, "greet": "传送门已校准。想去哪里？"}
	n["astronomer"] = {"name": "托勒", "sub": "天文学家", "g": "m", "outfit": "mage", "hair": 0, "hair_color": Color("dddddd"), "beard": true, "greet": "星辰的轨迹……最近有些异样。"}
	n["archbishop"] = {"name": "塞拉菲娜", "sub": "大主教", "g": "f", "outfit": "priest", "hair": 6, "hair_color": Color("f0f0f0"), "trainer": "priest", "greet": "愿海风与圣光庇佑你。"}
	n["harbor_master"] = {"name": "布雷克", "sub": "港务长", "g": "m", "outfit": "captain", "hair": 1, "hair_color": Color("4a3a2a"), "beard": true, "qm": "city", "greet": "今天进港的货船有十二艘，忙死我了。"}
	n["lighthouse_keeper"] = {"name": "老约翰", "sub": "灯塔看守", "g": "m", "outfit": "sailor", "hair": 0, "hair_color": Color("eeeeee"), "beard": true, "greet": "四十年了，这座灯塔的光从没熄灭过。"}
	n["dock_worker"] = {"name": "码头工人", "sub": "", "g": "m", "outfit": "sailor", "ambient": true, "greet": "嘿咻——嘿咻——"}
	n["citizen"] = {"name": "晴岚港市民", "sub": "", "g": "r", "outfit": "citizen", "ambient": true, "greet": "你好呀，新来的？"}
	n["scholar"] = {"name": "图书馆学者", "sub": "", "g": "r", "outfit": "mage", "greet": "嘘，这里是图书馆。"}
	n["t_warrior_3"] = {"name": "奥古斯特", "sub": "战士训练师", "g": "m", "outfit": "knight", "hair": 1, "hair_color": Color("2a2a2a"), "trainer": "warrior", "greet": "公会的战士从不退缩。"}
	n["t_mage_3"] = {"name": "伊瑟拉", "sub": "法师训练师", "g": "f", "outfit": "mage", "hair": 7, "hair_color": Color("80e0ff"), "trainer": "mage", "greet": "以太在这座城市里流淌，你感受到了吗？"}
	n["t_rogue_3"] = {"name": "灰鸦", "sub": "盗贼训练师", "g": "m", "outfit": "rogue", "hair": 3, "hair_color": Color("1a1a1a"), "trainer": "rogue", "greet": "城市的阴影比森林更深。"}
	n["t_gunner_3"] = {"name": "罗莎", "sub": "魔导枪手训练师", "g": "f", "outfit": "hunter", "hair": 5, "hair_color": Color("c06020"), "trainer": "gunner", "greet": "最新型号的魔导火枪，想不想试试？"}
	n["stable_city"] = {"name": "马修", "sub": "马厩管理员", "g": "m", "outfit": "farmer", "hair": 2, "hair_color": Color("8a6a40"), "vendor": "stable", "riding": true, "greet": "城里的马厩，照料得比城外好多了。"}
	# ===== 晴岚港（扩建：行会 / 公共设施 / 港区）
	n["cook_master"] = {"name": "玛格丽特", "sub": "烹饪师行会会长", "g": "f", "outfit": "barmaid", "hair": 5, "hair_color": Color("c06030"), "vendor": "cook_guild", "prof": "cook", "greet": "海港城市最不缺的就是新鲜食材——还有挑剔的舌头。"}
	n["smith_master"] = {"name": "格里姆", "sub": "锻铁匠行会会长", "g": "m", "outfit": "smith", "hair": 0, "hair_color": Color("3a2a20"), "beard": true, "vendor": "smith_guild", "prof": "smith", "greet": "炉火从不熄灭，锤声从不停歇。这就是锻铁匠行会。"}
	n["artisan_master"] = {"name": "伊格纳兹", "sub": "精工行会会长", "g": "m", "outfit": "engineer", "hair": 3, "hair_color": Color("aaaaaa"), "vendor": "artisan_guild", "prof": "artisan", "greet": "齿轮、发条、以太回路——精工就是让魔法与机械握手。"}
	n["mage_master"] = {"name": "瑟琳娜", "sub": "魔法师行会会长", "g": "f", "outfit": "mage", "hair": 7, "hair_color": Color("e0e0ff"), "trainer": "mage", "greet": "这座塔里的每一块砖都浸透了以太。小心别碰那些漂浮的符文。"}
	n["scholar_master"] = {"name": "奥古斯丁", "sub": "学者行会会长", "g": "m", "outfit": "mage", "hair": 1, "hair_color": Color("dddddd"), "beard": true, "greet": "知识是最自由的货物，它不需要缴纳关税。"}
	n["librarian"] = {"name": "伊芙", "sub": "公共图书馆馆长", "g": "f", "outfit": "noble", "hair": 6, "hair_color": Color("6a4030"), "greet": "图书馆向所有人开放——只要你保持安静。"}
	n["welfare_officer"] = {"name": "汉娜", "sub": "社会保障局专员", "g": "f", "outfit": "noble", "hair": 4, "hair_color": Color("3a2a2a"), "greet": "无论是退役水手还是新来的移民，晴岚港都会照顾每一位市民。"}
	n["black_marketeer"] = {"name": "\"渡鸦\"", "sub": "？？？", "g": "m", "outfit": "rogue", "hair": 3, "hair_color": Color("1a1a1a"), "vendor": "rare", "greet": "……你没见过我，我也没见过你。看货吧。"}
	n["tavern_keeper"] = {"name": "老科尔", "sub": "海鸥酒馆老板", "g": "m", "outfit": "barmaid", "hair": 0, "hair_color": Color("8a6a40"), "beard": true, "innkeeper": true, "vendor": "food", "greet": "朗姆酒、烤鱼、水手的歌——海鸥酒馆什么都有！"}
	n["inn_keeper2"] = {"name": "罗莎琳", "sub": "旅人之歌酒馆老板娘", "g": "f", "outfit": "barmaid", "hair": 6, "hair_color": Color("e0b060"), "innkeeper": true, "vendor": "food", "greet": "远道而来的旅人啊，先喝一杯再说吧！"}
	n["doctor"] = {"name": "贝尔纳", "sub": "公共医院院长", "g": "m", "outfit": "priest", "hair": 2, "hair_color": Color("8a8a8a"), "vendor": "potion", "greet": "受伤了？别逞强，先坐下来让我看看。"}
	n["nurse"] = {"name": "医院护士", "sub": "", "g": "f", "outfit": "priest", "ambient": true, "greet": "请保持安静，这里有病人在休息。"}
	n["opera_manager"] = {"name": "瓦伦蒂诺", "sub": "歌剧院经理", "g": "m", "outfit": "noble", "hair": 1, "hair_color": Color("2a2a2a"), "greet": "今晚的剧目是《迎海女神》！票早就卖光了。"}
	n["bath_attendant"] = {"name": "浴池管理员", "sub": "", "g": "f", "outfit": "villager", "greet": "热水是用以太锅炉烧的，舒服着呢。"}
	n["shipwright"] = {"name": "道格拉斯", "sub": "船厂工头", "g": "m", "outfit": "engineer", "hair": 2, "hair_color": Color("6a4a30"), "beard": true, "greet": "这艘新船下个月就能下水，用的是最新的以太龙骨！"}
	n["merchant_captain"] = {"name": "卡洛琳", "sub": "商船船长", "g": "f", "outfit": "captain", "hair": 4, "hair_color": Color("3a2a20"), "greet": "从南方群岛运来的香料，港口税可一分都没少交。"}
	n["ferry_clerk"] = {"name": "客运站售票员", "sub": "", "g": "m", "outfit": "conductor", "greet": "远洋客轮还在维修中，近海航线照常运营。"}
	n["sailor"] = {"name": "水手", "sub": "", "g": "m", "outfit": "sailor", "ambient": true, "greet": "嘿，陆地上的朋友！"}
	n["warehouse_keeper"] = {"name": "仓库管理员", "sub": "", "g": "m", "outfit": "merchant", "greet": "货单！谁拿走了我的货单？"}
	n["clergy"] = {"name": "神职人员", "sub": "", "g": "r", "outfit": "priest", "ambient": true, "greet": "愿海风与圣光庇佑你。"}
	n["clock_keeper"] = {"name": "提奥", "sub": "钟塔守护人", "g": "m", "outfit": "engineer", "hair": 1, "hair_color": Color("bbbbbb"), "beard": true, "greet": "钟塔里的以太摆锤，三百年来误差不超过一秒。"}
	n["park_keeper"] = {"name": "园丁", "sub": "", "g": "m", "outfit": "farmer", "greet": "请别踩草坪，谢谢。"}
	n["canal_keeper"] = {"name": "运河管理员", "sub": "", "g": "m", "outfit": "sailor", "greet": "运河的水一路流进内港，城里的雨水也都从这儿排走。"}
	_add_dialog(n)
	n["outer_farmer"] = {"name": "外城农夫", "sub": "", "g": "r", "outfit": "farmer", "ambient": true, "greet": "城里人吃的菜，可都是我们种的。"}
	# 晴岚港 v4 新增设施的人员（tools/gen_solenne.gd）
	var v4 := {
		"tax_officer": ["瑞文", "税务局主簿", "m", "noble", "港口税、市场税、以太矿税……每一枚铜币都有它该去的地方。",
			[["晴岚港收哪些税？", "进港的货按重量收港口税，市场摊位按月收租，以太矿石另收一成。冒险者的委托报酬不收税——这是公会争取来的。"]]],
		"judge": ["伊莎贝拉", "裁定厅首席裁定官", "f", "noble", "裁定厅只看证据，不看身份。",
			[["裁定厅审理什么案子？", "商船纠纷、码头斗殴、契约违约……还有灰巾帮那批走私火枪的案子，卷宗已经堆到天花板了。"]]],
		"archivist": ["奥斯本", "城市档案员", "m", "mage", "三百年的地契、船籍和航海日志，都在这些架子上。",
			[["档案馆里最古老的东西是什么？", "建城那年的第一份港口登记簿——上面只有七条渔船的名字。"]]],
		"canal_officer": ["玛丽娜", "漕运局督办", "f", "captain", "河道上的每一条驳船都要在漕运局登记。",
			[["漕运局管什么？", "晴岚河上的驳船、内港的泊位、水门的开闭。上游高原的矿石顺河而下，在这里换上海船。"]]],
		"customs_officer": ["海关稽查官", "", "m", "guard_city", "请出示货单。违禁品一律没收。", []],
		"researcher": ["莉莉安娜", "魔导研究所研究员", "f", "mage", "别碰那台仪器！它还在校准。",
			[["研究所在研究什么？", "以太晶体的共振。如果能让它稳定发光一千年，灯塔、列车、传送门都会变得更便宜。"]]],
		"lecturer": ["学院讲师", "", "m", "mage", "今天的课题是：以太流在海风中的偏折。", []],
		"governor": ["维多利亚", "晴岚港总督", "f", "noble", "欢迎来到总督官邸。市议会把这座城托付给我，我也把它托付给每一位市民。",
			[["总督和市长有什么不同？", "市长阿德里安管城里的柴米油盐，我负责港口、海防和与别国的往来。总督由市议会推举，任期五年。"]]],
		"butler": ["官邸管家", "", "m", "noble", "总督阁下在书房，请稍候。", []],
		"ambassador": ["外交使节", "", "m", "noble", "远方的王国很关心晴岚港的新航线。", []],
		"merchant_head": ["贝尔纳", "商会会长", "m", "merchant", "博览集市馆是商会出资建的——全大陆最大的玻璃屋顶！",
			[["博览集市馆里能买到什么？", "从武器到珠宝，从幻化服饰到海外珍品。每年秋天还有博览会，各国商人都会来。"]]],
		"admiral": ["海军提督", "", "m", "knight", "海防舰队随时待命。", []],
		"finance_minister": ["财政大臣", "", "f", "noble", "账目必须清清楚楚。", []],
		"expo_guide": ["博览馆讲解员", "", "f", "citizen", "欢迎参观晴岚港博览集市馆！店铺都在中央长廊两侧。", []],
	}
	for id in v4:
		var e: Array = v4[id]
		n[id] = {"name": e[0], "sub": e[1], "g": e[2], "outfit": e[3], "greet": e[4]}
		if not (e[5] as Array).is_empty():
			n[id]["topics"] = e[5]
	# 15–20 级海岸线的运行时外勤 NPC；由 ember_chapter.gd 放置到对应前哨。
	n["e_port_agent"] = {"name": "诺拉", "sub": "港务外勤", "g": "f", "outfit": "captain", "hair": 4, "hair_color": Color("8a4a28"),
		"greet": "别碰那几只封存货箱。你有市政授权吗？那就跟我来，今天我们把这条走私线查到底。"}
	n["e_coast_agent"] = {"name": "塞林", "sub": "海岸巡视员", "g": "m", "outfit": "sailor", "hair": 2, "hair_color": Color("3a2a20"), "beard": true,
		"greet": "海风把脚印吹散得很快。你来得正好，夜航船队就在前面，准备好就出发。"}
	return n

## 对话补充：topics = [[问题, 回答]]（闲谈/世界观），service = 对话里的功能
static func _add_dialog(n: Dictionary) -> void:
	var t := {
		"mayor": [["晴岚港是怎么建起来的？", "三百年前，这里只是一个渔村。第一批以太矿船在海湾避风，商人们跟着来了，然后是工匠、学者和冒险者。晴岚港没有国王，只有市议会——这座城市属于每一个在这里讨生活的人。"],
			["灰巾帮的事情结束了吗？", "守钟人倒下了，但灰巾帮从城里得到的那批魔导火枪还没全部追回。港务处和公会都在查。"]],
		"gate_captain": [["城里有什么规矩？", "别在城里拔刀，别在运河里洗衣服，别在钟塔底下吵到提奥。其余的——晴岚港是自由港，随你。"]],
		"guild_master": [["冒险者公会都做些什么？", "接委托、发悬赏、给新人引路。等晴岚港的远洋航线开通，公会还要组织第一批去新大陆的探险队。"]],
		"guild_reg": [["单机版的公会有什么用？", "嗯……可以给自己起个响亮的名号？等更多冒险者来到晴岚港，公会系统才会真正热闹起来。"]],
		"portal_mage": [["传送门是怎么运作的？", "传送大厅地下埋着一块巨大的以太晶核。我们只是把它的力量引导成一条稳定的通道——前提是两端都有人校准。"]],
		"banker": [["银行安全吗？", "金库在钟塔地下二十米，门是精工行会造的，钥匙在市长手里。你说安不安全？"]],
		"auctioneer": [["交易所的东西都是谁在卖？", "全大陆的商人和冒险者！货架每隔一段时间就会换一批。想卖东西？价格别定得太离谱就行。"]],
		"transmog": [["幻化是什么原理？", "一点点幻术，一点点以太编织。装备本身不会改变，只是看起来像另一件——就像化妆一样～"]],
		"station_master": [["魔导列车靠什么驱动？", "车头里有一颗以太核心，加上蒸汽涡轮。以前每天四班，灰巾帮捣乱以后停了好几个月。"]],
		"airship_captain": [["远洋航线什么时候开通？", "船已经造好了，就差一张可靠的海图和足够的以太燃料。耐心点，冒险者。"]],
		"harbor_master": [["港口每天有多少船？", "商船十几艘，渔船数不过来。北港停客船和商船，南港是货船和水手的天下——要找水手，去海鸥酒馆。"],
			["迎海女神像有什么来历？", "传说第一位港务长在风暴里迷了航，是一道蓝光把船引回了海湾。后来人们在防波堤上立了女神像，水晶里的光到今天都没灭过。"]],
		"lighthouse_keeper": [["灯塔的光为什么是蓝色的？", "因为烧的不是油，是以太水晶。蓝光在雾里能照得更远。四十年了，我一晚都没让它灭过。"]],
		"shipwright": [["以太龙骨是什么？", "在龙骨里嵌一条以太导管，船就能在逆风里自己往前走。精工行会的伊格纳兹设计的，我负责把它装进木头里。"]],
		"merchant_captain": [["你从哪里来？", "南方群岛。香料、珊瑚、晒干的海星——在晴岚港都能卖个好价钱。"]],
		"canal_keeper": [["运河通向哪里？", "从城东的公园水门一路流进内港。下大雨的时候，全城的雨水都从这儿排进海里，排水口在南边海堤上。"]],
		"park_keeper": [["公园里的雕像是谁？", "第一任市议长。听说他最大的愿望就是城里有一片不用做生意的地方——所以就有了这座公园。"]],
		"astronomer": [["星辰有什么异样？", "北天的「舵手座」最近亮得反常。古籍里说，上一次它这么亮，海上出现了一座会移动的岛……也许只是巧合。"]],
		"archbishop": [["大教堂供奉的是谁？", "圣光，以及守护航海者的海风。水手出海前都会来这里点一盏灯。"]],
		"clergy": [["教堂里可以做些什么？", "祈祷、静坐，或者帮忙照看医院里的病人。"]],
		"librarian": [["有什么值得一读的书？", "《晴岚港编年史》《以太矿物学》《迎海女神》剧本手稿……还有一本《灰巾帮的起源》，最近被借阅了很多次。"],
			["灰巾帮是怎么来的？", "最早是一群被矿场解雇的工人。后来有人给他们提供了武器和以太，事情就变了味——书里没写那个人是谁。"]],
		"scholar": [["你在研究什么？", "以太在海水里的溶解速度。很无聊？不，这关系到整座港口的未来。"]],
		"mage_master": [["怎样才能加入魔法师行会？", "天赋、耐心，和一颗不会被漂浮符文吓到的心脏。法师训练师伊瑟拉就在塔下，想学法术就去找她。"]],
		"artisan_master": [["魔导机车是你们造的吗？", "当然！市长送给英雄的那把钥匙，就是我们行会的杰作。"]],
		"smith_master": [["锻铁匠行会有多少年历史？", "比晴岚港还老。第一批移民上岸时，最先搭起来的就是一座铁匠炉。"]],
		"cook_master": [["晴岚港的招牌菜是什么？", "炖海鲜！用生肉？……好吧，内陆的冒险者拿不到新鲜海货，用肉也行，关键是调味料。"]],
		"tavern_keeper": [["最近有什么传闻？", "有个水手说他在南边海上看见了一座冒烟的岛。他喝了三瓶朗姆酒才说的，你自己判断。"]],
		"inn_keeper2": [["城外的难民怎么样了？", "城门开了以后，大部分人都在外城区安了家，种地、养鸡。日子总会好起来的。"]],
		"black_marketeer": [["你卖的东西是从哪来的？", "……问太多的人，通常买不到好东西。"]],
		"doctor": [["医院收费吗？", "社会保障局会付账。冒险者受伤了随时来，不收钱。"]],
		"welfare_officer": [["社会保障局是做什么的？", "照顾退役的水手、受伤的工人、刚来的移民——还有手头紧的冒险者。每天都可以来领一份补助。"]],
		"opera_manager": [["《迎海女神》讲的是什么？", "一位港务长在风暴中迷航，大海中升起一道蓝光为他指路——这是晴岚港的建城传说。"]],
		"ferry_clerk": [["现在有哪些航线？", "近海：晴岚港 ⇄ 南方群岛（维修中）。远洋：新大陆航线（筹备中）。陆路请去中央车站坐魔导列车。"]],
		"clock_keeper": [["钟塔多少年了？", "三百年。钟摆里有一颗以太摆锤，每到整点会微微发光——晚上来看最清楚。"]],
		"bath_attendant": [["浴池的水是从哪来的？", "地下温泉，加上以太锅炉。泡一泡，旅途的疲惫全没了。"]],
	}
	for id in t:
		if n.has(id):
			n[id]["topics"] = t[id]
	var svc := {"bath_attendant": "bath", "doctor": "heal", "welfare_officer": "welfare", "guild_reg": "guild", "opera_manager": "opera",
		"scholar_master": "research", "clock_keeper": "time", "ferry_clerk": "routes"}
	for id in svc:
		if n.has(id):
			n[id]["service"] = svc[id]

## 任务经验表（按任务等级）
const QXP := [0, 100, 160, 230, 320, 420, 520, 630, 740, 860, 980, 1100, 1220, 1350, 1480, 1620, 1760, 1900, 2200, 2500, 2800]

static func quests() -> Dictionary:
	var q := {}
	# ======================================================== 晨钟修道院 1-5
	q["q_a1"] = {"name": "觉醒之晨", "lvl": 1, "giver": "marcus", "turnin": "lina", "main": true, "w": 0.4,
		"text": "欢迎来到晨钟修道院，冒险者。你从远方而来，带着一封推荐信和满身的风尘。\n\n如今的晨露谷并不太平：山岭里来了鼠人，葡萄园被强盗占据，连修道院外的狼群都越来越大胆。\n\n去找修道院门口的副队长莉娜吧，她会告诉你该做些什么。",
		"obj_text": "与修道院门口的副队长莉娜交谈。", "complete": "你就是新来的冒险者？马库斯大人已经交代过了。很好，我们正缺人手。"}
	for c in ["warrior", "mage", "priest", "rogue", "gunner"]:
		var tn: String = {"warrior": "t_warrior_1", "mage": "t_mage_1", "priest": "t_priest_1", "rogue": "t_rogue_1", "gunner": "t_gunner_1"}[c]
		q["q_cls_" + c] = {"name": "导师的召唤", "lvl": 1, "giver": "marcus", "turnin": tn, "class": c, "w": 0.4,
			"text": "每一位冒险者都需要一位导师。你的职业训练师就在修道院里，去见见他们吧。\n\n随着你的成长，训练师会教给你新的技能——记得经常回来看看。",
			"obj_text": "与你的职业训练师交谈。", "complete": "你来了。让我看看你的架势……嗯，还有很多要学的。等你有所成长，就来找我学习新技能吧。"}
	q["q_a2"] = {"name": "狼群出没", "lvl": 1, "giver": "lina", "turnin": "lina", "prev": ["q_a1"],
		"text": "修道院西边的林间空地上，幼狼的数量越来越多。它们已经开始袭击运送补给的马车了。\n\n去消灭8只幼狼，让它们知道修道院不是好惹的。",
		"obj_text": "杀死8只幼狼。", "obj": [{"type": "kill", "mob": ["young_wolf"], "n": 8}],
		"progress": "狼群还在外面游荡吗？", "complete": "干得漂亮！这下运货的伙计们能松口气了。", "choice": ["hands:cloth:sta", "hands:leather:agi", "hands:mail:str"], "q_reward": 1}
	q["q_a11"] = {"name": "狼肉储备", "lvl": 2, "giver": "tom", "turnin": "tom",
		"text": "修道院的储藏室快见底了。修士们虽然吃素，可卫兵们需要肉！\n\n林子里的狼肉虽然有点硬，但炖久了还挺香的。给我带6块新鲜狼肉回来。",
		"obj_text": "收集6块新鲜狼肉。", "obj": [{"type": "collect", "item": "q_wolf_meat", "n": 6, "mobs": ["young_wolf", "timber_wolf"], "chance": 0.6}],
		"progress": "狼肉呢？", "complete": "太好了！今晚有肉汤喝了。拿着，这些面包算是我的谢礼。", "items": [["food_bread", 5]]}
	q["q_a3"] = {"name": "鼠人的骚扰", "lvl": 2, "giver": "lina", "turnin": "lina", "prev": ["q_a2"],
		"text": "修道院东边的山坡上，一群掘地鼠人挖开了一个新洞穴。它们偷走工具，挖坏田地，还把一切能拿的东西都拖进地洞。\n\n去东边的鼠人营地，干掉10个掘地鼠人苦工。",
		"obj_text": "杀死10个掘地鼠人苦工。", "obj": [{"type": "kill", "mob": ["ratman_worker"], "n": 10}],
		"progress": "鼠人还在东坡上乱挖吗？", "complete": "做得好。虽然鼠人像野草一样割不完，但至少能让它们老实一阵子。", "choice": ["feet:cloth:spi", "feet:leather:sta", "feet:mail:sta"], "q_reward": 1}
	q["q_a4"] = {"name": "鼠人的蜡烛", "lvl": 3, "giver": "lina", "turnin": "lina", "prev": ["q_a2"],
		"text": "有件事很奇怪——鼠人头上都顶着蜡烛。它们好像很害怕黑暗，没了蜡烛就不敢下洞。\n\n如果能收走它们的蜡烛，也许能让它们停止挖掘。给我带8根鼠人的蜡烛回来。",
		"obj_text": "收集8根鼠人的蜡烛。", "obj": [{"type": "collect", "item": "q_candle", "n": 8, "mobs": ["ratman_worker"], "chance": 0.6}],
		"progress": "蜡烛收集得怎么样了？", "complete": "嗯……这些蜡烛的蜡是从修道院的仓库里偷的！可恶的小偷。", "money": 150}
	q["q_a5"] = {"name": "修道院草药", "lvl": 2, "giver": "samuel", "turnin": "samuel",
		"text": "晨露草是一种神奇的植物，只在清晨的阳光下才会绽放淡绿色的光芒。修道院用它来制作治疗药膏。\n\n修道院周围的草地上能找到它们。请帮我采集6株晨露草。",
		"obj_text": "采集6株晨露草。", "obj": [{"type": "collect", "item": "q_herb_dew", "n": 6, "node": "herb_dew"}],
		"progress": "找到晨露草了吗？它们会发出淡淡的绿光。", "complete": "多么新鲜的晨露草！愿圣光祝福你。拿着这些药水，你会用得上的。", "items": [["potion_heal1", 2]]}
	q["q_a6"] = {"name": "晶莹果冻", "lvl": 3, "giver": "samuel", "turnin": "samuel", "prev": ["q_a5"],
		"text": "说来你可能不信，修道院北边草地上那些胖乎乎的果冻史莱姆，它们体内的果冻是制作药膏最好的黏合剂。\n\n它们性情温和，只要你不招惹它们……当然，你得招惹它们。请带5块晶莹果冻回来。",
		"obj_text": "收集5块晶莹果冻。", "obj": [{"type": "collect", "item": "q_jelly", "n": 5, "mobs": ["jelly_slime"], "chance": 0.7}],
		"progress": "果冻史莱姆们很可爱，对吧？", "complete": "完美的果冻！药膏的问题解决了。", "choice": ["wrist:cloth:int", "wrist:leather:agi", "wrist:mail:str"], "q_reward": 1}
	q["q_a7"] = {"name": "失窃的葡萄", "lvl": 4, "giver": "milo", "turnin": "milo",
		"text": "那些戴灰头巾的强盗占了我的葡萄园！他们不光偷吃葡萄，还把我酿酒用的葡萄箱子全搬走了！\n\n葡萄箱就堆在葡萄园里。求求你，帮我拿回8个葡萄酒箱！",
		"obj_text": "从葡萄园取回8个葡萄酒箱。", "obj": [{"type": "collect", "item": "q_grape_crate", "n": 8, "node": "grape_crate"}],
		"progress": "我的葡萄……", "complete": "我的宝贝们！你真是个好人。等我酿出新酒，第一杯就请你喝！", "choice": ["legs:cloth:int", "legs:leather:agi", "legs:mail:str"]}
	q["q_a8"] = {"name": "灰巾帮的威胁", "lvl": 4, "giver": "marcus", "turnin": "marcus", "prev": ["q_a3"], "main": true,
		"text": "那些戴灰头巾的家伙自称「灰巾帮」，他们霸占了修道院南边的葡萄园。\n\n我原以为他们只是一群小毛贼，但他们的数量越来越多，而且组织严密。去葡萄园，消灭10个灰巾帮小喽啰。",
		"obj_text": "杀死10个灰巾帮小喽啰。", "obj": [{"type": "kill", "mob": ["bandit_thug_s"], "n": 10}],
		"progress": "灰巾帮还在葡萄园里吗？", "complete": "好！这能让他们收敛一点。不过……我总觉得事情没这么简单。", "choice": ["chest:cloth:int", "chest:leather:agi", "chest:mail:str"]}
	q["q_a9"] = {"name": "头目加洛克", "lvl": 5, "giver": "marcus", "turnin": "marcus", "prev": ["q_a8"], "main": true, "w": 1.3,
		"text": "据俘虏交代，葡萄园的灰巾帮由一个叫加洛克的家伙领导。他就藏在葡萄园深处的木屋旁边。\n\n干掉加洛克，把他的头巾带回来作为证据。",
		"obj_text": "取得加洛克的灰头巾。", "obj": [{"type": "collect", "item": "q_garrok_bandana", "n": 1, "mobs": ["garrok"], "chance": 1.0}],
		"progress": "加洛克还活着吗？", "complete": "加洛克的头巾……干得好。这头巾的内侧绣着一个奇怪的标记——一口钟。这是什么意思？", "choice": ["one:sword:str", "one:dagger:agi", "two:staff:int", "ranged:gun:agi"]}
	q["q_a10"] = {"name": "致金穗镇的信", "lvl": 5, "giver": "marcus", "turnin": "duke", "prev": ["q_a9"], "main": true, "w": 0.6,
		"text": "灰巾帮的事情远比我想象的严重。我写了一封信，详细说明了葡萄园的情况和那个钟形标记。\n\n沿着大路往南走，把信交给金穗镇的治安官杜克。他是我的老朋友，会知道该怎么办的。\n\n修道院外的世界很大，冒险者——祝你好运。",
		"obj_text": "将信件交给金穗镇的治安官杜克。", "complete": "马库斯的信？……钟形标记。我在别处也见过这个标记。看来灰巾帮的触角已经伸到了整个谷地。\n\n欢迎来到金穗镇，冒险者。我们需要你。"}
	# ======================================================== 金穗镇 5-10
	q["q_b1"] = {"name": "农庄求援", "lvl": 5, "giver": "duke", "turnin": "hob", "prev": ["q_a10"], "main": true, "w": 0.5,
		"text": "西边麦浪农庄的霍布昨天来报告，说他的粮仓被人撬了。我怀疑又是灰巾帮干的。\n\n顺着西边的大路走，去农庄找霍布了解情况。",
		"obj_text": "与麦浪农庄的农夫霍布交谈。", "complete": "治安官派你来的？太好了！我都快急死了。"}
	q["q_b2"] = {"name": "野猪横行", "lvl": 5, "giver": "hob", "turnin": "hob",
		"text": "除了强盗，还有野猪！那些石牙野猪把我的麦田拱得一团糟。\n\n帮我杀掉8头石牙野猪吧，它们就在农庄周围的田野上。",
		"obj_text": "杀死8头石牙野猪。", "obj": [{"type": "kill", "mob": ["boar"], "n": 8}],
		"progress": "野猪还在祸害庄稼吗？", "complete": "谢天谢地！我的麦子总算能长了。", "choice": ["waist:cloth:spi", "waist:leather:agi", "waist:mail:sta"]}
	q["q_b3"] = {"name": "野猪肋排", "lvl": 6, "giver": "martha", "turnin": "martha",
		"text": "既然你在打野猪，能不能顺便帮我带6块野猪肋排回来？我的野猪肉炖菜在整个金穗镇都很有名哦。",
		"obj_text": "收集6块野猪肋排。", "obj": [{"type": "collect", "item": "q_boar_ribs", "n": 6, "mobs": ["boar"], "chance": 0.6}],
		"progress": "炖锅已经烧热了！", "complete": "多么新鲜的肋排！来，尝尝我的手艺，再带上一些路上吃。", "items": [["food_meat", 5]]}
	q["q_b4"] = {"name": "被偷的粮食", "lvl": 7, "giver": "hob", "turnin": "hob", "prev": ["q_b1"], "main": true,
		"text": "灰巾帮的暴徒们把我的粮食搬到了农庄西边的废弃农舍。那可是全村过冬的口粮！\n\n去把8袋被偷的粮食抢回来。小心，那些暴徒下手可狠了。",
		"obj_text": "取回8袋被偷的粮食。", "obj": [{"type": "collect", "item": "q_grain_sack", "n": 8, "mobs": ["bandit_thug", "bandit_rogue"], "chance": 0.55}],
		"progress": "粮食找回来了吗？", "complete": "我的粮食！你救了全村人的命。对了，你在那些强盗身上有没有发现什么奇怪的东西？如果有，一定要拿给治安官看。",
		"choice": ["head:cloth:int", "head:leather:agi", "head:mail:str"]}
	q["q_b9"] = {"name": "神秘的密信", "lvl": 8, "giver": "", "turnin": "duke", "main": true, "w": 0.8, "starter_item": "q_secret_letter",
		"starter_drop": {"mobs": ["bandit_thug", "bandit_rogue", "bandit_apprentice"], "chance": 0.12, "min_level": 7},
		"text": "这封信被一个灰巾帮成员贴身藏着，信封上盖着一个钟形的蜡封。\n\n信中写道：「……粮食已收集完毕，按计划运往高地。旧圣堂的钟声响起之时，便是晴岚港陷落之日。——S」\n\n你应该把这封信交给金穗镇的治安官杜克。",
		"obj_text": "将密信交给金穗镇的治安官杜克。", "complete": "旧圣堂……晴岚港陷落？！这可不是小事。签名是「S」……灰巾帮在金穗镇一带的队长叫斯塔克。\n\n冒险者，我们得行动了。"}
	q["q_b11"] = {"name": "灰巾帮的阴谋", "lvl": 9, "giver": "duke", "turnin": "duke", "prev": ["q_b9"], "main": true,
		"text": "在对付斯塔克之前，我们得先削弱他的力量。农庄西边的废弃农舍周围聚集着大量灰巾帮成员，其中还有会使用魔导术的学徒。\n\n去消灭8个灰巾帮暴徒和5个灰巾帮魔导学徒。",
		"obj_text": "杀死8个灰巾帮暴徒和5个灰巾帮魔导学徒。", "obj": [{"type": "kill", "mob": ["bandit_thug"], "n": 8}, {"type": "kill", "mob": ["bandit_apprentice"], "n": 5}],
		"progress": "灰巾帮的势力还很强吗？", "complete": "很好，斯塔克的手下已经折损大半。现在是时候直捣黄龙了。", "choice": ["chest:cloth:int", "chest:leather:agi", "chest:mail:str"]}
	q["q_b12"] = {"name": "灰巾帮队长", "lvl": 10, "giver": "duke", "turnin": "duke", "prev": ["q_b11"], "main": true, "w": 1.4,
		"text": "斯塔克就躲在废弃农舍的地窖口附近。他是个危险的家伙，曾经是晴岚港的雇佣兵。\n\n干掉他，找到他的命令书。我们必须知道灰巾帮到底在策划什么。",
		"obj_text": "取得斯塔克的命令书。", "obj": [{"type": "collect", "item": "q_stark_orders", "n": 1, "mobs": ["stark"], "chance": 1.0}],
		"progress": "斯塔克……", "complete": "（杜克仔细阅读着命令书，脸色越来越难看）\n\n「全体向风语旧圣堂集结。副首领莱克负责后勤，守钟人已在钟楼等候。」\n\n守钟人……旧圣堂……这件事已经超出了金穗镇的能力范围。",
		"choice": ["one:sword:str_sta", "two:axe2:str", "one:dagger:agi", "two:staff:int_spi", "ranged:gun:agi_sta", "one:mace:int"]}
	q["q_b13"] = {"name": "通往潮风高地", "lvl": 10, "giver": "duke", "turnin": "elin", "prev": ["q_b12"], "main": true, "w": 0.5,
		"text": "风语旧圣堂位于潮风高地，就在晴岚港的东南方。必须尽快通知晴岚港！\n\n沿着农庄大路一直往西，在西境关口，斥候艾琳在那里驻守。她熟悉去高地的路。去找她吧。",
		"obj_text": "与西境关口的斥候艾琳交谈。", "complete": "杜克治安官派你来的？我明白了。去高地的路我很熟。"}
	q["q_b14"] = {"name": "前往东门哨站", "lvl": 10, "giver": "elin", "turnin": "loren", "prev": ["q_b13"], "main": true, "w": 0.6,
		"text": "顺着这条大路一直往西走，过了关口就是潮风高地。晴岚港最近封城了，所有外来者都被安排在城外的东门哨站。\n\n把杜克的报告交给哨站指挥官洛伦。他是个可靠的人。",
		"obj_text": "前往潮风高地的东门哨站，与指挥官洛伦交谈。", "complete": "金穗镇的报告？灰巾帮、旧圣堂、守钟人……\n\n这和我们最近掌握的情报完全吻合。冒险者，你来得正是时候。"}
	q["q_b5"] = {"name": "深石矿坑", "lvl": 6, "giver": "duke", "turnin": "gib", "prev": ["q_a10"], "w": 0.5,
		"text": "镇子西南边的深石矿坑被鼠人占了，矿工们都逃了出来。矿工吉布就在矿坑入口那里，去看看能帮上什么忙。",
		"obj_text": "与深石矿坑入口的矿工吉布交谈。", "complete": "治安官派人来了？太好了！"}
	q["q_b6"] = {"name": "矿坑里的鼠人", "lvl": 6, "giver": "gib", "turnin": "gib", "prev": ["q_b5"],
		"text": "那些鼠人挖掘工霸占了整个矿坑！它们不光挖矿，还到处乱挖，整个矿坑都快塌了。\n\n进去杀掉10个掘地鼠人挖掘工。",
		"obj_text": "杀死10个掘地鼠人挖掘工。", "obj": [{"type": "kill", "mob": ["ratman_digger"], "n": 10}],
		"progress": "矿坑里的情况怎么样？", "complete": "好样的！", "choice": ["hands:cloth:int", "hands:leather:agi_sta", "hands:mail:str_sta"]}
	q["q_b7"] = {"name": "失踪的矿工", "lvl": 7, "giver": "gib", "turnin": "gib", "prev": ["q_b5"],
		"text": "我的搭档老汤米在鼠人袭击那天没能逃出来……他最后一次出现是在矿坑最深处。\n\n如果你能深入矿坑，请帮我找找他。哪怕只是找回他的矿工徽章也好。",
		"obj_text": "探索矿坑深处，找到老汤米的矿工徽章。", "obj": [{"type": "explore", "poi": "poi_mine_deep", "text": "探索矿坑深处"}, {"type": "collect", "item": "q_miner_badge", "n": 1, "node": "miner_body"}],
		"progress": "有老汤米的消息吗？", "complete": "（吉布接过徽章，沉默了很久）\n\n……谢谢你，冒险者。至少他能魂归故里了。", "money": 400}
	q["q_b8"] = {"name": "监工的金块", "lvl": 8, "giver": "gib", "turnin": "gib", "prev": ["q_b6"],
		"text": "鼠人监工们把矿坑里挖出来的金块都私藏了起来，而那些地卜师会用火焰魔法保护它们。\n\n杀掉6个掘地鼠人地卜师，再从监工身上夺回4块金块。",
		"obj_text": "杀死6个掘地鼠人地卜师，并收集4块监工的金块。", "obj": [{"type": "kill", "mob": ["ratman_geomancer"], "n": 6}, {"type": "collect", "item": "q_gold_nugget", "n": 4, "mobs": ["ratman_foreman"], "chance": 0.6}],
		"progress": "金块拿回来了吗？", "complete": "这些金块够我们重开矿坑了！", "choice": ["legs:cloth:int_spi", "legs:leather:agi_sta", "legs:mail:str_sta"]}
	q["q_b10"] = {"name": "大头目格里奇", "lvl": 9, "giver": "gib", "turnin": "gib", "prev": ["q_b8"], "w": 1.3,
		"text": "鼠人们的大头目叫格里奇，是个又肥又凶的家伙，就盘踞在矿坑最深处的大厅里。\n\n只要干掉它，剩下的鼠人就会作鸟兽散。",
		"obj_text": "杀死格里奇。", "obj": [{"type": "kill", "mob": ["grizzik"], "n": 1}],
		"progress": "格里奇还活着？", "complete": "格里奇死了？！太好了！深石矿坑终于又是我们的了！", "choice": ["finger:misc:str_sta", "finger:misc:agi_sta", "finger:misc:int_spi"]}
	q["q_b15"] = {"name": "蛙人的鳍", "lvl": 6, "giver": "bob", "turnin": "bob",
		"text": "镜湖岸边来了一群潮蛙人。它们把我的鱼都赶跑了，还在湖边搭起了窝棚！\n\n听说蛙人的鳍是很好的胶料原料。给我带8片蛙人的鳍，我付你钱。",
		"obj_text": "收集8片蛙人的鳍。", "obj": [{"type": "collect", "item": "q_frog_fin", "n": 8, "mobs": ["frogman_scout", "frogman_fisher"], "chance": 0.6}],
		"progress": "咕噜咕噜……我说的是蛙人的叫声，不是我。", "complete": "哈哈，这些鳍够我做好几罐胶了！", "choice": ["back:cloth:sta", "feet:leather:agi", "feet:mail:str"]}
	q["q_b16"] = {"name": "鲍勃的渔网", "lvl": 7, "giver": "bob", "turnin": "bob", "prev": ["q_b15"],
		"text": "那些蛙人偷走了我的渔网，就晾在它们的窝棚附近。没了渔网，我可怎么打鱼啊！\n\n帮我取回5张渔网吧。",
		"obj_text": "取回5张鲍勃的渔网。", "obj": [{"type": "collect", "item": "q_fishing_net", "n": 5, "node": "fishing_net"}],
		"progress": "我的渔网……", "complete": "我的渔网！虽然被弄得湿漉漉黏糊糊的，但洗洗还能用。", "money": 450}
	q["q_b17"] = {"name": "潮汐祭司", "lvl": 8, "giver": "bob", "turnin": "bob", "prev": ["q_b15"],
		"text": "蛙人中有一些会用闪电魔法的祭司，它们在湖边举行奇怪的仪式，召唤更多的蛙人到这里来。\n\n去杀掉6个潮蛙人潮汐祭司，阻止仪式继续。",
		"obj_text": "杀死6个潮蛙人潮汐祭司。", "obj": [{"type": "kill", "mob": ["frogman_priest"], "n": 6}],
		"progress": "仪式还在进行吗？", "complete": "湖面终于平静下来了。", "choice": ["chest:cloth:int_spi", "chest:leather:agi_sta", "chest:mail:str_sta"]}
	q["q_b18"] = {"name": "老蛙王咕噜鲁", "lvl": 9, "giver": "bob", "turnin": "bob", "prev": ["q_b17"], "w": 1.3,
		"text": "最后一件事——蛙人的老大，一个叫咕噜鲁的大家伙。它就住在湖心小岛对面的大窝棚里。\n\n只要除掉它，剩下的蛙人自然会离开镜湖。",
		"obj_text": "杀死咕噜鲁。", "obj": [{"type": "kill", "mob": ["gurglu"], "n": 1}],
		"progress": "咕噜鲁……", "complete": "咕噜鲁完蛋了？镜湖又是我的了！哈哈哈！", "choice": ["neck:misc:int_spi", "neck:misc:agi_sta", "neck:misc:str_sta"]}
	q["q_b19"] = {"name": "林蛛之患", "lvl": 7, "giver": "thad", "turnin": "thad",
		"text": "伐木场周围的林子里到处都是林蛛，好几个伙计都被咬了。\n\n帮我清理一下，杀掉10只林蛛。",
		"obj_text": "杀死10只林蛛。", "obj": [{"type": "kill", "mob": ["forest_spider"], "n": 10}],
		"progress": "小心它们的毒液！", "complete": "干得好！伙计们终于敢进林子干活了。", "choice": ["wrist:cloth:int_spi", "wrist:leather:agi_sta", "wrist:mail:str_sta"]}
	q["q_b20"] = {"name": "优质木材", "lvl": 7, "giver": "thad", "turnin": "thad",
		"text": "伐木场外有几堆砍好的优质木材，因为林蛛的缘故一直没人敢去搬。\n\n帮我搬6捆优质木材回来，金穗镇的房子还等着修呢。",
		"obj_text": "收集6捆优质木材。", "obj": [{"type": "collect", "item": "q_lumber", "n": 6, "node": "lumber_pile"}],
		"progress": "木材呢？", "complete": "好木头！这下可以开工了。", "money": 400}
	q["q_b21"] = {"name": "织网者薇丝", "lvl": 9, "giver": "thad", "turnin": "thad", "prev": ["q_b19"], "w": 1.3,
		"text": "那些林蛛都是从东边山脚下的蛛巢里爬出来的。巢穴里住着一只巨大的林蛛母后，我们叫它织网者薇丝。\n\n不除掉它，林蛛会一直源源不断地冒出来。",
		"obj_text": "杀死织网者薇丝。", "obj": [{"type": "kill", "mob": ["weaver"], "n": 1}],
		"progress": "……", "complete": "你干掉了薇丝？！真了不起！", "choice": ["back:cloth:int", "back:cloth:agi", "back:cloth:str"]}
	q["q_b22"] = {"name": "灰熊出没", "lvl": 9, "giver": "thad", "turnin": "thad",
		"text": "最近林子深处的灰熊变得很暴躁，大概是被林蛛吓的。它们已经冲进伐木场好几次了。\n\n杀掉8只灰熊。它们可不好对付，小心点。",
		"obj_text": "杀死8只灰熊。", "obj": [{"type": "kill", "mob": ["grizzly"], "n": 8}],
		"progress": "灰熊……", "complete": "伐木场又安全了。谢谢你。", "choice": ["chest:cloth:int_spi", "chest:leather:agi_sta", "chest:mail:str_sta"]}
	q["q_b23"] = {"name": "林地潜猎者", "lvl": 8, "giver": "duke", "turnin": "duke", "prev": ["q_a10"],
		"text": "东边林地里出现了一种凶猛的黑狼，人们叫它林地潜猎狼。已经有好几个旅人被袭击了。\n\n去东边的林地杀掉8只林地潜猎狼。",
		"obj_text": "杀死8只林地潜猎狼。", "obj": [{"type": "kill", "mob": ["prowler"], "n": 8}],
		"progress": "东边的路安全了吗？", "complete": "做得好，旅人们会感谢你的。", "choice": ["feet:cloth:int", "feet:leather:agi_sta", "feet:mail:str_sta"]}
	q["q_b27"] = {"name": "蔚蓝之塔的邀请", "lvl": 8, "giver": "duke", "turnin": "selena", "prev": ["q_a10"], "w": 0.5,
		"text": "南边蔚蓝之塔的法师赛琳娜派人送信来，说需要一位冒险者帮忙。她那里好像出了什么状况……跟机械有关。\n\n去南边的蔚蓝之塔见她吧。",
		"obj_text": "与蔚蓝之塔的法师赛琳娜交谈。", "complete": "终于有人来了！"}
	q["q_b24"] = {"name": "失控的傀儡", "lvl": 9, "giver": "selena", "turnin": "selena",
		"text": "塔东边那座废弃的魔导工坊，原本是我和几个工匠研究以太驱动傀儡的地方。一场事故之后，那些傀儡全部失控了。\n\n它们在工坊周围游荡，见人就攻击。去摧毁10个失控的魔导傀儡。",
		"obj_text": "摧毁10个失控的魔导傀儡。", "obj": [{"type": "kill", "mob": ["rogue_golem"], "n": 10}],
		"progress": "傀儡们的核心是蓝色的，打那里！", "complete": "辛苦了……这些可怜的造物。", "choice": ["head:cloth:int_spi", "head:leather:agi_sta", "head:mail:str_sta"]}
	q["q_b25"] = {"name": "以太核心", "lvl": 9, "giver": "selena", "turnin": "selena",
		"text": "我需要回收傀儡体内的以太核心来研究事故原因。从失控的傀儡和齿轮蜘蛛身上收集6个以太核心给我。",
		"obj_text": "收集6个以太核心。", "obj": [{"type": "collect", "item": "q_aether_core", "n": 6, "mobs": ["rogue_golem", "gear_spider"], "chance": 0.5}],
		"progress": "核心可能还很烫，小心。", "complete": "这些核心……被人动过手脚！有人故意让傀儡失控。核心上刻着一个钟形的符号。", "choice": ["trinket:misc:int", "trinket:misc:agi", "trinket:misc:str"]}
	q["q_b26"] = {"name": "原型机MK-0", "lvl": 10, "giver": "selena", "turnin": "selena", "prev": ["q_b25"], "w": 1.6, "elite": true,
		"text": "工坊里有一台最早期的原型傀儡——MK-0。它的装甲比其他傀儡厚得多，力量也大得多。\n\n如果它也被动了手脚，后果不堪设想。去工坊深处摧毁它。\n\n（精英任务：建议做好充分准备）",
		"obj_text": "摧毁原型机 MK-0。", "obj": [{"type": "kill", "mob": ["mk0"], "n": 1}],
		"progress": "MK-0……", "complete": "MK-0被摧毁了？你真是个了不起的冒险者。", "choice": ["two:staff:int_spi", "two:sword2:str_sta", "one:dagger:agi_sta", "ranged:gun:agi"]}
	q["q_b31"] = {"name": "老猎人的委托", "lvl": 8, "giver": "faria", "turnin": "vick", "prev": ["q_a10"], "w": 0.5,
		"text": "老猎人维克每次进城都在我这儿喝酒。他上次说，西南边的狂牙岭来了一大群鬣人，他一个人对付不了。\n\n你要是有空，去狂牙岭附近找他吧。",
		"obj_text": "与狂牙岭附近的老猎人维克交谈。", "complete": "法莉亚那丫头让你来的？好，好。"}
	q["q_b28"] = {"name": "狂牙鬣人", "lvl": 9, "giver": "vick", "turnin": "vick",
		"text": "狂牙鬣人占领了整个狂牙岭。它们凶残、狡猾，还会成群结队地袭击路人。\n\n去杀掉10个狂牙鬣人和5个狂牙鬣人投矛手。",
		"obj_text": "杀死10个狂牙鬣人和5个狂牙鬣人投矛手。", "obj": [{"type": "kill", "mob": ["hyena_warrior"], "n": 10}, {"type": "kill", "mob": ["hyena_thrower"], "n": 5}],
		"progress": "它们的投矛准得很，别站着不动。", "complete": "好身手！", "choice": ["chest:cloth:int", "chest:leather:agi", "chest:mail:str"]}
	q["q_b29"] = {"name": "鬣人的獠牙", "lvl": 9, "giver": "vick", "turnin": "vick",
		"text": "镇上悬赏狂牙鬣人的獠牙。带8颗回来，赏金归你。",
		"obj_text": "收集8颗狂牙鬣人的獠牙。", "obj": [{"type": "collect", "item": "q_hyena_fang", "n": 8, "mobs": ["hyena_warrior", "hyena_thrower"], "chance": 0.6}],
		"progress": "獠牙？", "complete": "这是你的赏金。", "money": 800}
	q["q_b30"] = {"name": "狂牙之王", "lvl": 11, "giver": "vick", "turnin": "vick", "prev": ["q_b28"], "w": 2.0, "elite": true,
		"text": "狂牙鬣人的首领叫格罗克，自称「狂牙之王」。这家伙个头比普通鬣人大一倍，力大无穷。\n\n只要它还活着，鬣人就会不断骚扰金穗镇。带回它的獠牙项链作为证据。\n\n（精英任务：格罗克非常强大，请做好准备，或者等级更高时再来）",
		"obj_text": "取得狂牙之王的獠牙项链。", "obj": [{"type": "collect", "item": "q_grok_head", "n": 1, "mobs": ["grok"], "chance": 1.0}],
		"progress": "格罗克……", "complete": "你……你真的干掉了格罗克？！小子，你会成为一名伟大的冒险者的！", "choice": ["two:axe2:str_sta", "one:sword:agi_sta", "two:staff:int_sta", "ranged:bow:agi"]}
	q["q_b32"] = {"name": "旅店的补给", "lvl": 7, "giver": "faria", "turnin": "faria",
		"text": "旅店的炖菜需要上好的狼肉。东边林地的潜猎狼肉质紧实，是最好的选择。帮我带6块新鲜狼肉吧。",
		"obj_text": "收集6块新鲜狼肉。", "obj": [{"type": "collect", "item": "q_wolf_meat", "n": 6, "mobs": ["prowler"], "chance": 0.6}],
		"progress": "炖锅还空着呢。", "complete": "太好了！这些给你，路上吃。", "items": [["food_meat", 5], ["drink_juice", 5]]}
	# ======================================================== 潮风高地 10-15
	q["q_c2"] = {"name": "进城许可", "lvl": 10, "giver": "loren", "turnin": "isa", "prev": ["q_b14"], "main": true, "w": 0.5,
		"text": "晴岚港正处于封城警戒中，没有市民证的人一律不得入城。不过，如果你愿意协助我们调查灰巾帮，我可以为你作保。\n\n去找移民登记官伊莎，她会为你办理临时登记。",
		"obj_text": "与移民登记官伊莎交谈。", "complete": "洛伦为你作保？那好吧。不过要拿到正式的市民证，你得先证明自己对这座城市的价值。"}
	q["q_c3"] = {"name": "海滩的骚动", "lvl": 10, "giver": "isa", "turnin": "isa", "prev": ["q_c2"], "main": true,
		"text": "南边的海滩上，礁石蟹最近异常活跃。它们爬上了渔民的晒网场，还伤了好几个人。\n\n去杀掉10只礁石蟹。这也算是你为晴岚港做的第一件事。",
		"obj_text": "杀死10只礁石蟹。", "obj": [{"type": "kill", "mob": ["reef_crab"], "n": 10}],
		"progress": "螃蟹的壳很硬，找准关节下手。", "complete": "不错。你的登记表上终于有第一笔记录了。", "choice": ["legs:cloth:int_spi", "legs:leather:agi_sta", "legs:mail:str_sta"]}
	q["q_c4"] = {"name": "鲜嫩蟹肉", "lvl": 11, "giver": "grace", "turnin": "grace",
		"text": "哨站里挤满了等待入城的旅人，大家都饿坏了。海滩上的螃蟹肉质鲜美，帮我带8块鲜嫩蟹肉回来吧，我给大家煮一锅蟹肉汤。",
		"obj_text": "收集8块鲜嫩蟹肉。", "obj": [{"type": "collect", "item": "q_crab_meat", "n": 8, "mobs": ["reef_crab", "giant_crab"], "chance": 0.6}],
		"progress": "锅已经烧开啦！", "complete": "真香！谢谢你，大家今晚能吃顿好的了。", "items": [["food_cheese", 5], ["drink_milk", 5]], "money": 600}
	q["q_c5"] = {"name": "风车农庄的求援", "lvl": 11, "giver": "isa", "turnin": "grant", "prev": ["q_c3"], "main": true, "w": 0.5,
		"text": "东南边的风车农庄是晴岚港的粮仓。农场主老格兰特送来了紧急求援信，说农庄里发生了怪事。\n\n去农庄看看吧。",
		"obj_text": "与风车农庄的老格兰特交谈。", "complete": "你是城里派来的？快，快来看看我的田！"}
	q["q_c6"] = {"name": "疯长的稻草人", "lvl": 11, "giver": "grant", "turnin": "grant", "prev": ["q_c5"],
		"text": "我的稻草人……它们自己动起来了！还用麦秆根须缠住路过的人！\n\n一定是有人在田里埋了什么邪门的东西。帮我消灭10个疯长的稻草人，再从田里采集5株变异的麦穗给我。",
		"obj_text": "消灭10个疯长的稻草人，收集5株变异的麦穗。", "obj": [{"type": "kill", "mob": ["scarecrow"], "n": 10}, {"type": "collect", "item": "q_crop_sample", "n": 5, "node": "crop_sample"}],
		"progress": "我的田……", "complete": "这些麦穗……散发着以太的味道。有人用以太污染了土地！", "choice": ["waist:cloth:int_spi", "waist:leather:agi_sta", "waist:mail:str_sta"]}
	q["q_c7"] = {"name": "纵火犯", "lvl": 12, "giver": "grant", "turnin": "grant", "prev": ["q_c5"], "main": true,
		"text": "还有更糟的——灰巾帮的纵火犯在农庄外围放火，烧掉了两座粮仓！他们手里拿着装满火油的罐子。\n\n消灭8个灰巾帮纵火犯，夺回5个火油罐。",
		"obj_text": "杀死8个灰巾帮纵火犯，收集5个火油罐。", "obj": [{"type": "kill", "mob": ["arsonist"], "n": 8}, {"type": "collect", "item": "q_oil_jar", "n": 5, "mobs": ["arsonist"], "chance": 0.6}],
		"progress": "火！到处是火！", "complete": "这些火油罐上……又是那个钟形标记。灰巾帮想要让晴岚港断粮！快把这件事告诉洛伦指挥官。", "choice": ["chest:cloth:int_sta", "chest:leather:agi_sta", "chest:mail:str_sta"]}
	q["q_c8"] = {"name": "灰巾帮哨营", "lvl": 12, "giver": "loren", "turnin": "loren", "prev": ["q_c7"], "main": true,
		"text": "斥候发现了灰巾帮在高地北部建立的哨营。那里驻扎着大量哨兵和火枪手——晴岚港的叛徒给他们提供了魔导火枪！\n\n去哨营消灭10个灰巾帮哨兵和6个灰巾帮火枪手。",
		"obj_text": "杀死10个灰巾帮哨兵和6个灰巾帮火枪手。", "obj": [{"type": "kill", "mob": ["bandit_sentry"], "n": 10}, {"type": "kill", "mob": ["bandit_gunner"], "n": 6}],
		"progress": "火枪手会在远处射击，尽量贴近他们。", "complete": "干得漂亮！灰巾帮的哨营已经乱成一团了。", "choice": ["hands:cloth:int_spi", "hands:leather:agi_sta", "hands:mail:str_sta"]}
	q["q_c9"] = {"name": "铁腕瓦尔加", "lvl": 13, "giver": "loren", "turnin": "loren", "prev": ["q_c8"], "main": true, "w": 1.4,
		"text": "哨营的指挥官叫瓦尔加，外号「铁腕」。据说他手里有一份旧圣堂的地图——灰巾帮的主力就藏在那里。\n\n干掉瓦尔加，拿到那份地图。",
		"obj_text": "取得旧圣堂地图。", "obj": [{"type": "collect", "item": "q_sanctum_map", "n": 1, "mobs": ["varga"], "chance": 1.0}],
		"progress": "瓦尔加……", "complete": "（洛伦展开地图）\n\n风语旧圣堂……他们在钟楼里藏了什么？「丧钟」……如果那口钟被敲响……\n\n冒险者，接下来的事情会非常危险。", "choice": ["one:sword:str_sta", "two:mace2:str_sta", "one:dagger:agi_sta", "two:staff:int_spi", "ranged:gun:agi_sta", "off:offhand:int"]}
	q["q_c10"] = {"name": "锈蚀的傀儡", "lvl": 12, "giver": "howard", "turnin": "howard",
		"text": "北边的旧铁路站场废弃好几年了，可那里的维护傀儡还在游荡。最近它们开始攻击铁轨上的巡线员。\n\n去摧毁10个锈蚀的魔导傀儡。",
		"obj_text": "摧毁10个锈蚀的魔导傀儡。", "obj": [{"type": "kill", "mob": ["rust_golem"], "n": 10}],
		"progress": "傀儡们……", "complete": "谢谢你。站场终于安静了一些。", "choice": ["feet:cloth:int_spi", "feet:leather:agi_sta", "feet:mail:str_sta"]}
	q["q_c11"] = {"name": "蒸汽核心", "lvl": 13, "giver": "howard", "turnin": "howard", "prev": ["q_c10"],
		"text": "傀儡和蒸汽蜘蛛体内的蒸汽核心还能用。收集6个蒸汽核心给我，我想用它们修复站场的信号系统。",
		"obj_text": "收集6个蒸汽核心。", "obj": [{"type": "collect", "item": "q_steam_core", "n": 6, "mobs": ["rust_golem", "steam_spider"], "chance": 0.5}],
		"progress": "核心找到了吗？", "complete": "好极了！", "choice": ["wrist:cloth:int_spi", "wrist:leather:agi_sta", "wrist:mail:str_sta"]}
	q["q_c12"] = {"name": "信号灯修复", "lvl": 13, "giver": "howard", "turnin": "howard", "prev": ["q_c11"],
		"text": "最后，站场里还散落着一些信号灯零件。帮我捡4个回来，我就能让信号灯重新亮起来。到时候魔导列车就能恢复通往金穗镇的线路了！",
		"obj_text": "收集4个信号灯零件。", "obj": [{"type": "collect", "item": "q_signal_part", "n": 4, "node": "signal_part"}],
		"progress": "零件就在铁轨旁边。", "complete": "信号灯亮了！看到那道绿光了吗？列车线路恢复了！", "money": 1500}
	q["q_c13"] = {"name": "风妖的翎羽", "lvl": 13, "giver": "lilian", "turnin": "lilian",
		"text": "东边的鸣风崖上栖息着风鸣鸟妖。它们的翎羽能捕捉风中的以太——这对我的研究非常重要！\n\n能帮我收集10根风妖的翎羽吗？",
		"obj_text": "收集10根风妖的翎羽。", "obj": [{"type": "collect", "item": "q_harpy_feather", "n": 10, "mobs": ["harpy", "harpy_witch"], "chance": 0.6}],
		"progress": "翎羽在阳光下会闪着绿光哦。", "complete": "太美了……谢谢你！", "choice": ["head:cloth:int_spi", "head:leather:agi_sta", "head:mail:str_sta"]}
	q["q_c14"] = {"name": "风鸣巫母", "lvl": 14, "giver": "lilian", "turnin": "lilian", "prev": ["q_c13"],
		"text": "风鸣巫母能操纵狂风，它们最近频繁地袭击路过鸣风崖的商队。\n\n去消灭8个风鸣巫母。",
		"obj_text": "杀死8个风鸣巫母。", "obj": [{"type": "kill", "mob": ["harpy_witch"], "n": 8}],
		"progress": "小心它们的狂风！", "complete": "商队终于能安全通过了。", "choice": ["chest:cloth:int_spi", "chest:leather:agi_sta", "chest:mail:str_sta"]}
	q["q_c15"] = {"name": "鸟妖女王", "lvl": 15, "giver": "lilian", "turnin": "lilian", "prev": ["q_c14"], "w": 1.4,
		"text": "所有的风鸣鸟妖都听命于它们的女王希尔维亚。她栖息在鸣风崖最高处的巢里。\n\n这对鸟类学来说是一个巨大的损失……但为了商队的安全，请你去击败她。",
		"obj_text": "杀死希尔维亚。", "obj": [{"type": "kill", "mob": ["harpy_matron"], "n": 1}],
		"progress": "……", "complete": "鸣风崖终于恢复了平静。", "choice": ["neck:misc:int_spi", "neck:misc:agi_sta", "neck:misc:str_sta"]}
	q["q_c16"] = {"name": "旧圣堂的阴影", "lvl": 14, "giver": "loren", "turnin": "loren", "prev": ["q_c9"], "main": true, "w": 2.2, "dungeon": true,
		"text": "根据地图，灰巾帮的首脑——一个被称为「守钟人」的家伙——就在风语旧圣堂的钟楼里。他想要敲响那口「丧钟」，用诅咒之力摧毁晴岚港。\n\n我已经召集了三位可靠的同伴：盾卫加隆、修女艾莉亚和游侠芙蕾。他们会在圣堂入口等你。\n\n深入旧圣堂，击败守钟人，带回丧钟的碎片。\n\n（地下城任务：按 I 打开地下城查找器，或前往高地东南的圣堂入口）",
		"obj_text": "取得丧钟碎片。", "obj": [{"type": "collect", "item": "q_bell_shard", "n": 1, "mobs": ["boss_victor"], "chance": 1.0}],
		"progress": "丧钟还没有被敲响……我们还有时间。", "complete": "丧钟碎片……它还在微微震动。\n\n你做到了，冒险者。晴岚港欠你一个大人情。去找伊莎吧，你值得拥有市民的身份。",
		"choice": ["chest:cloth:int_spi", "chest:leather:agi_sta", "chest:mail:str_sta", "finger:misc:str_sta", "finger:misc:int_spi"], "q_reward": 3}
	q["q_c17"] = {"name": "腐根之心", "lvl": 14, "giver": "ed", "turnin": "ed", "dungeon": true, "w": 1.2,
		"text": "旧圣堂的花园曾经是整个高地最美丽的地方。可如今，一个叫厄尔班的树妖占据了那里，用腐根吞噬了一切。\n\n击败厄尔班，带回它的腐根之心。我会用圣水将它净化。",
		"obj_text": "取得腐根之心。", "obj": [{"type": "collect", "item": "q_rotheart", "n": 1, "mobs": ["boss_rootguard"], "chance": 1.0}],
		"progress": "花园……", "complete": "愿这颗心得到安息。", "choice": ["waist:cloth:int_spi", "waist:leather:agi_sta", "waist:mail:str_sta"], "q_reward": 2}
	q["q_c18"] = {"name": "双枪莱克", "lvl": 15, "giver": "ed", "turnin": "ed", "dungeon": true, "w": 1.2,
		"text": "灰巾帮的副首领莱克是个臭名昭著的亡命徒，双手各持一把魔导左轮。他负责为灰巾帮提供武器和补给。\n\n击败他，把他的左轮带回来。",
		"obj_text": "取得莱克的左轮。", "obj": [{"type": "collect", "item": "q_lake_pistol", "n": 1, "mobs": ["boss_lake"], "chance": 1.0}],
		"progress": "莱克……", "complete": "这把枪……是晴岚港军械库失窃的那一批。看来城里有内鬼。", "choice": ["feet:cloth:int_spi", "feet:leather:agi_sta", "feet:mail:str_sta"], "q_reward": 2}
	q["q_c19"] = {"name": "晴岚港的新市民", "lvl": 15, "min": 15, "giver": "isa", "turnin": "mayor", "prev": ["q_c16"], "main": true, "w": 1.5, "grant_on_accept": "city_access",
		"text": "我已经听说了你在旧圣堂的壮举。整个哨站都在谈论你！\n\n这是你的晴岚港市民证。城门已经为你打开——去市政大厅见阿德里安市长吧，他要亲自为你授予市民身份。\n\n欢迎回家，冒险者。",
		"obj_text": "进入晴岚港，前往市政大厅拜见阿德里安市长。", "complete": "所以，你就是那位粉碎了灰巾帮阴谋的英雄！\n\n以晴岚港市长的名义，我在此授予你晴岚港的市民身份。这件战袍是这座城市对你的敬意——还有这把钥匙，城里的工匠们特意为你打造的。\n\n欢迎来到晴岚港，海风与以太之都！",
		"items": [["tabard_solenne", 1], ["mount_mech_item", 1]], "money": 5000}
	q["q_d1"] = {"name": "城市导览", "lvl": 15, "giver": "mayor", "turnin": "gate_captain", "prev": ["q_c19"], "w": 0.8,
		"text": "晴岚港是一座依山傍海的城市。作为新市民，你应该好好熟悉一下它的每一个角落。\n\n去看看内港入口的迎海女神像、市政广场的喷泉、东北区市场、冒险者公会、中南部的中央车站、西北高地上的飞空艇站，还有南边的大教堂。最后去东门找守卫队长罗兰报到。",
		"obj_text": "游览晴岚港的各个区域。", "obj": [
			{"type": "explore", "poi": "poi_harbor", "text": "迎海女神像"}, {"type": "explore", "poi": "poi_plaza", "text": "市政广场"},
			{"type": "explore", "poi": "poi_market", "text": "东北区市场"}, {"type": "explore", "poi": "poi_guild", "text": "冒险者公会"},
			{"type": "explore", "poi": "poi_station", "text": "中央车站"}, {"type": "explore", "poi": "poi_airport", "text": "飞空艇站"},
			{"type": "explore", "poi": "poi_cathedral", "text": "大教堂"}],
		"progress": "城市大吗？", "complete": "怎么样，晴岚港不错吧？", "money": 2000}
	q["q_d2"] = {"name": "冒险者登记", "lvl": 15, "giver": "mayor", "turnin": "guild_master", "prev": ["q_c19"], "w": 0.4,
		"text": "冒险者公会会长葛雷森想见你。公会在城市东部，挂着蓝色旗帜的大楼就是。",
		"obj_text": "前往冒险者公会，与会长葛雷森交谈。", "complete": "你就是那个在旧圣堂大显身手的家伙？好！公会就需要你这样的人。"}
	q["q_d3"] = {"name": "幻化的艺术", "lvl": 15, "giver": "guild_master", "turnin": "transmog", "prev": ["q_d2"], "w": 0.4,
		"text": "一个好的冒险者，不光要实力强，还要有派头！市场区有一位幻化师薇薇安，她能让你的装备换上任何你收集过的外观。\n\n去找她看看吧。",
		"obj_text": "与市场区的幻化师薇薇安交谈。", "complete": "哎呀，又是一位新顾客～你身上的装备外观我都帮你记录在衣柜里了，随时可以来幻化哦。"}
	q["q_d4"] = {"name": "魔导列车", "lvl": 15, "giver": "guild_master", "turnin": "station_master", "prev": ["q_d2"], "w": 0.4,
		"text": "晴岚港的中央车站是整个大陆最繁忙的车站之一。现在列车线路刚刚恢复，站长格伦应该很需要人手。去看看吧。",
		"obj_text": "与中央车站的站长格伦交谈。", "complete": "哦！你就是修好信号灯的那位？不对，那是霍华德说的……总之，欢迎乘坐魔导列车！"}
	q["q_d5"] = {"name": "飞空艇之梦", "lvl": 15, "giver": "station_master", "turnin": "airship_captain", "prev": ["q_d4"], "w": 0.4,
		"text": "列车只能在大地上奔跑，可天空才是真正的边界。北边高地上的飞空艇站，船长艾薇正在筹备一条通往远方大陆的航线。\n\n去见见她吧，也许未来的冒险就从那里开始。",
		"obj_text": "与飞空艇站的船长艾薇交谈。", "complete": "欢迎来到天空之港！远洋航线还在筹备中……等它开通的那一天，我第一个邀请你登船！"}
	# ======================================================== 15-20 级：灰巾帮余烬
	# 这条线承接 q_c19，使用现有城市 POI 和旧圣堂副本，避免凭空创建不可到达的任务地点。
	q["q_e1"] = {"name": "余烬的账本", "lvl": 16, "min": 16, "giver": "mayor", "turnin": "archivist", "prev": ["q_c19"], "main": true, "w": 1.1,
		"text": "灰巾帮的首脑已经倒下，但市政档案馆发现了一本被火烧过的账本。账页上还留着旧圣堂的印记，说明这场阴谋远没有结束。\n\n前往档案馆确认账本来源，再回到旧圣堂寻找被藏起来的补页。",
		"obj_text": "探索城市档案馆，并从旧圣堂的灰巾帮余党身上取得灰烬账本。", "obj": [{"type": "explore", "poi": "poi_archive", "text": "探索城市档案馆"}, {"type": "collect", "item": "q_ash_ledger", "n": 1, "mobs": ["d_bandit", "d_bandit_mage"], "chance": 0.35}], "dungeon": true,
		"progress": "账本上的印记和丧钟完全一致。", "complete": "这些数字不是军费，而是以太燃料的流向。有人在圣堂被毁之后继续供养灰巾帮。", "choice": ["chest:cloth:int_spi", "chest:leather:agi_sta", "chest:mail:str_sta"]}
	q["q_e2"] = {"name": "运河封锁", "lvl": 17, "min": 17, "giver": "archivist", "turnin": "canal_keeper", "prev": ["q_e1"], "main": true, "w": 1.2,
		"text": "账本里出现了一个奇怪的暗号：‘水门三号，潮汐后交货’。运河管理员说最近有不明船只靠近排水口，灰巾帮可能正在把武器运进城。\n\n回到旧圣堂，截断他们最后一批军械，并取回被打碎的港务印章。",
		"obj_text": "消灭8名灰巾帮神枪手，取得裂开的港务印章。", "obj": [{"type": "kill", "mob": ["d_bandit_gunner"], "n": 8}, {"type": "collect", "item": "q_seal_fragment", "n": 1, "mobs": ["d_bandit_gunner"], "chance": 0.35}], "dungeon": true,
		"progress": "水门的铁链已经重新锁上了吗？", "complete": "印章是真的。有人利用港务印章伪造了夜间通行令，运河下面一定还有一条暗线。", "choice": ["one:sword:str_sta", "one:dagger:agi_sta", "two:staff:int_spi", "ranged:gun:agi_sta"]}
	q["q_e3"] = {"name": "灯塔断讯", "lvl": 18, "min": 18, "giver": "canal_keeper", "turnin": "lighthouse_keeper", "prev": ["q_e2"], "main": true, "w": 1.25,
		"text": "运河暗线通向南港，而南港的灯塔昨夜突然熄灭。没有灯塔指引，海上的商船会撞上暗礁，城里的以太通讯也会中断。\n\n沿着运河检查水门，再到灯塔确认航标是否被人动过。",
		"obj_text": "检查运河、南港和灯塔。", "obj": [{"type": "explore", "poi": "poi_canal", "text": "检查城市运河"}, {"type": "explore", "poi": "poi_south_port", "text": "检查南港"}, {"type": "explore", "poi": "poi_lighthouse", "text": "检查灯塔"}],
		"progress": "灯塔的蓝光又亮起来了吗？", "complete": "灯塔没有损坏，是有人把航标的晶核调成了灰巾帮的频率。线索指向旧圣堂最后一间没有搜过的钟楼密室。", "money": 3200}
	q["q_e4"] = {"name": "浑浊的以太", "lvl": 19, "min": 19, "giver": "lighthouse_keeper", "turnin": "astronomer", "prev": ["q_e3"], "main": true, "w": 1.35,
		"text": "灯塔晶核里混进了来自旧圣堂的黑色杂质。天文学家托勒认为那是丧钟残响凝成的以太，必须用圣堂石像鬼身上的透镜碎片才能分析。\n\n再次进入风语旧圣堂，摧毁石像鬼并带回浑浊以太透镜。",
		"obj_text": "消灭8只圣堂石像鬼，收集3块浑浊以太透镜。", "obj": [{"type": "kill", "mob": ["d_gargoyle"], "n": 8}, {"type": "collect", "item": "q_aether_lens", "n": 3, "mobs": ["d_gargoyle"], "chance": 0.35}], "dungeon": true,
		"progress": "透镜带回来了吗？它们应该会在月光下发出紫色的边缘光。", "complete": "这些透镜记录了守钟人死前的最后一道指令：把余烬核心送往钟楼。核心还没有熄灭。", "choice": ["trinket:misc:int", "trinket:misc:agi", "trinket:misc:str"]}
	q["q_e5"] = {"name": "余烬终局", "lvl": 20, "min": 20, "giver": "astronomer", "turnin": "mayor", "prev": ["q_e4"], "main": true, "w": 1.6,
		"text": "余烬核心仍在钟楼深处跳动。只要它还在，灰巾帮就能重新点燃丧钟，下一次目标将是晴岚港本身。\n\n进入旧圣堂最后一次，击败堕落的守钟人，带回余烬核心。",
		"obj_text": "取得余烬核心，并确认观测塔的星图。", "obj": [{"type": "collect", "item": "q_ember_core", "n": 1, "mobs": ["boss_victor"], "chance": 1.0}, {"type": "explore", "poi": "poi_observatory", "text": "确认观测塔的星图"}], "dungeon": true,
		"progress": "核心还在震动……快把它交给市长。", "complete": "你把最后一块余烬从钟楼里带了出来。晴岚港不会忘记你的名字。\n\n总督已经批准开放北方航线，这座城市的下一段故事，等你亲自启程。", "items": [["mount_bear_item", 1]], "money": 12000, "q_reward": 4}
	# 支线：为15-20级玩家提供城市外勤和灯塔补给，不阻塞主线。
	q["q_e6"] = {"name": "城墙外的余波", "lvl": 16, "min": 16, "giver": "gate_captain", "turnin": "gate_captain", "prev": ["q_c19"], "w": 0.9,
		"text": "灰巾帮的残党还在城墙外骚扰巡逻队。趁他们尚未重新集结，先清理掉东门附近的哨兵和火枪手。",
		"obj_text": "消灭12名灰巾帮哨兵和8名灰巾帮火枪手。", "obj": [{"type": "kill", "mob": ["bandit_sentry"], "n": 12}, {"type": "kill", "mob": ["bandit_gunner"], "n": 8}],
		"progress": "东门的巡逻队安全了吗？", "complete": "很好，至少今晚城墙外不会再有火枪声了。", "money": 2600}
	q["q_e7"] = {"name": "灯塔的燃料", "lvl": 18, "min": 18, "giver": "lighthouse_keeper", "turnin": "lighthouse_keeper", "prev": ["q_e3"], "w": 0.8,
		"text": "灯塔虽然重新亮起，但备用燃料已经见底。旧铁路站场的傀儡还在使用同类以太燃料，去收集一些灯塔燃料芯。",
		"obj_text": "从锈蚀的魔导傀儡和蒸汽蜘蛛身上收集6个灯塔燃料芯。", "obj": [{"type": "collect", "item": "q_lighthouse_cell", "n": 6, "mobs": ["rust_golem", "steam_spider"], "chance": 0.55}],
		"progress": "燃料芯应该足够支撑一个月。", "complete": "谢谢你。海上的船只又能看见回家的方向了。", "money": 4200}
	q["q_e8"] = {"name": "档案馆的空白页", "lvl": 17, "min": 17, "giver": "archivist", "turnin": "archivist", "prev": ["q_e1"], "w": 0.75,
		"text": "账本中间缺了几页，档案员怀疑灰巾帮把它们藏在旧城的废弃仓库里。找到这些纸页，也许能确认城内的接应者。",
		"obj_text": "探索旧城，并从灰巾帮精锐身上找回失踪的账页。", "obj": [{"type": "explore", "poi": "poi_oldtown", "text": "探索旧城"}, {"type": "collect", "item": "q_ledger_page", "n": 2, "mobs": ["d_bandit", "d_bandit_mage"], "chance": 0.35}], "dungeon": true,
		"progress": "纸页上有没有新的名字？", "complete": "这里写着一个城内仓库的编号。我们会把证据交给裁定厅。", "money": 3600}
	# 15–20 级章节由独立数据表维护，覆盖上方早期草稿并追加完整的港口、铁路、海岸四段内容。
	q.merge(preload("res://src/data/data_ember_quests.gd").quests(), true)
	# Keep progress/reward IDs while replacing the abandoned-temple story.
	q["q_c16"].merge({"name":"清缴旧祈航圣堂","text":"这座圣堂曾与晨钟修道院一样供奉海洋女神，水手与王国商人在这里祈求航程平安。魔法科技兴起之后，旧信仰逐渐淡去，它已经荒废了一百多年。如今藤蔓魔物与附近鼠人占据了旧庭院、供物库和钟台。\n\n加隆、艾莉亚与芙蕾会在入口与你会合。深入清缴占据者，击败覆钟古根，取回旧出航钟的碎片。","obj_text":"清缴覆钟古根，取得旧出航钟碎片。","progress":"旧钟台上的植物魔物清除了吗？","complete":"你让那些被遗忘的石墙重见了天光。带回的旧钟碎片，是古王国航海记忆的一部分。去找伊莎吧，晴岚港感谢你的帮助。"},true)
	q["q_c17"]["text"]="藤蔓魔物厄尔班侵入了旧祈航庭院。昔日的奉献台已被根系缠住。击败它，带回腐根之心，阻止根系继续向圣堂内部生长。"
	q["q_c17"]["progress"]="庭院的侵藤清除了吗？"
	q["q_c18"].merge({"name":"鼠人拾荒头目","text":"碎帆·拉克把旧祭品转运院占作鼠人的拾荒营地。它的窝群正在拆毁旧供物与航海纪念品。击败拉克，取回它从奉献登记间抢走的旧航印记。","obj_text":"取得旧航印记。","progress":"拉克还守着转运院吗？","complete":"这枚印记属于昔日的航海商会。我们会把它与其他残留供物一同登记保存。"},true)
	q["q_c19"]["complete"]="感谢你清缴旧圣堂的占据者，并带回古王国的航海遗物。晴岚港愿意接纳这样的冒险者。以市长的名义，我授予你市民身份。"
	return q
