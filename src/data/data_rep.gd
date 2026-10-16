class_name DataRep
extends RefCounted
## 声望阵营数据：五个阵营、等级门槛、成员 NPC、对应怪物家族、军需官。
## 任务声望由「交付 NPC 所属阵营」自动推导（可用 quest["rep"] = {fid: 点数} 覆盖）；
## 击杀声望由怪物家族（mob["fam"]）决定；军需品货单在 data_items.gd 的 qm_* 里，条目可带 "rep": [阵营, 等级] 门槛。

## 等级：名称 / 累计点数下限 / 颜色（索引 = 等级）
const TIERS := [
	["中立", 0, Color("a8adb8")],
	["友善", 500, Color("40d040")],
	["尊敬", 1500, Color("40a0ff")],
	["崇敬", 3000, Color("c080ff")],
	["崇拜", 5000, Color("ffd040")],
]
const MAX_POINTS := 5000

static func factions() -> Dictionary:
	return {
		"abbey": {"name": "晨钟修道院", "color": Color("e8d070"), "qm_name": "晨钟修道院军需官",
			"desc": "谷地东侧的修道院，是这片土地的第一道防线。守备官、修士与他们的圣光秩序守护着金穗镇与旅人。",
			"qm": "tom",
			"npcs": ["marcus", "lina", "samuel", "milo", "tom", "gwen", "lucy", "abbey_fp", "guard_abbey", "archbishop",
				"t_warrior_1", "t_mage_1", "t_priest_1", "t_rogue_1", "t_gunner_1"],
			"fams": ["gargoyle", "plant"]},
		"goldshire": {"name": "金穗镇", "color": Color("d8b040"), "qm_name": "金穗镇补给官",
			"desc": "晨露谷的农工镇子。农夫、矿工、伐木工和渔民把谷地里的物产送到这里，再由铁路运往晴岚港。",
			"qm": "duke",
			"npcs": ["duke", "faria", "argo", "dorn", "britta", "kate", "hob", "martha", "gib", "bob", "thad", "ron", "mount_merchant_vale",
				"fizz", "pip_fp", "mill_fp", "grant", "vick", "guard_town", "villager"],
			"fams": ["ratman", "frog", "boar", "scarecrow"]},
		"city": {"name": "晴岚港", "color": Color("5aa0e0"), "qm_name": "晴岚港港务军需处",
			"desc": "海风与以太之都。市政厅、港务处与各行业行会共同支撑着这座依山傍海的城邦。",
			"qm": "harbor_master",
			"npcs": ["mayor", "gate_captain", "isa", "loren", "howard", "lilian", "ed", "station_master", "harbor_master",
				"lighthouse_keeper", "banker", "banker2", "auctioneer", "item_shop", "weapon_shop", "armor_shop", "jeweler",
				"florist", "potion_shop", "rare_shop", "city_inn", "transmog", "airship_captain", "portal_mage", "astronomer",
				"stable_city", "guard_city", "guard_city_f", "citizen", "dock_worker", "elin", "grace",
				"cook_master", "smith_master", "artisan_master"],
			"fams": ["bandit", "bandit_d"]},
		"guild": {"name": "冒险者公会", "color": Color("c08840"), "qm_name": "冒险者公会赏金处",
			"desc": "接委托、发悬赏、给新人引路。等远洋航线开通，公会还要组织第一批去新大陆的探险队。",
			"qm": "guild_master",
			"npcs": ["guild_master", "guild_reg", "oscar"],
			"fams": ["hyena", "harpy"]},
		"tower": {"name": "以太学者会", "color": Color("a080e0"), "qm_name": "学者会物资处",
			"desc": "蔚蓝之塔与魔法师行会、学者行会、公共图书馆的联合。研究以太、发条与一切漂浮的符文。",
			"qm": "selena",
			"npcs": ["selena", "mage_master", "scholar_master", "librarian", "scholar"],
			"fams": ["golem", "spider"]},
	}

## 等级索引 → 累计点数下限
static func floor_points(tier: int) -> int:
	return int(TIERS[clampi(tier, 0, TIERS.size() - 1)][1])

static func tier_name(tier: int) -> String:
	return str(TIERS[clampi(tier, 0, TIERS.size() - 1)][0])

static func tier_color(tier: int) -> Color:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)][2]
