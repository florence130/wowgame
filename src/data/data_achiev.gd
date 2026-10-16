class_name DataAchiev
extends RefCounted
## 成就数据：分类与条目。进度判定、奖励发放、广播在 src/core/achieve.gd。
##
## 条目字段：
##   id     唯一编号        cat   分类 id       name 名称      desc 描述
##   pts    成就点数（计入总点数）          target 目标值
##   kind   判定方式（见下）  key   判定参数（统计键 / 阵营 / 怪物 / 地点 id）
##   hidden 隐藏成就（未完成前不在列表里出现）   reward 额外奖励 {"money": 铜, "items": [[物品id, 数量]]}
##
## kind 取值：
##   stat      pd["achiev"]["stats"][key]（由玩法钩子累加：击杀、任务、制造、采集…）
##   kill      pd["kills"][key]（某只怪物的击杀数）
##   level     角色等级
##   rep       某阵营的累计声望点数      rep_any 所有阵营里最高      rep_all 所有阵营里最低
##   explored  已发现地点数              poi     是否发现某个地点（key = 地点 id）
##   spells    已学技能数                talents 已投入天赋点      profs 已学专业数      recipes 已学配方数
##   money     一生持有过的最高金额（铜）  points  当前成就点数（元成就）
##   fps       已发现的飞行点数量

## 分类：id → 名称与配色（界面左侧列表）
const CATS := {
	"prog": {"name": "成长", "color": Color("a090ff")},
	"quest": {"name": "任务", "color": Color("ffd75e")},
	"combat": {"name": "战斗", "color": Color("e07070")},
	"explore": {"name": "探索", "color": Color("80d0a0")},
	"prof": {"name": "专业与经济", "color": Color("d0a060")},
	"rep": {"name": "声望", "color": Color("60c0e0")},
}

const LIST := [
	# ============================================================ 成长
	{"id": "prog_5", "cat": "prog", "name": "初出茅庐", "desc": "达到 5 级。修道院的人开始记得你的脸。",
		"kind": "level", "target": 5, "pts": 5, "reward": {"money": 500}},
	{"id": "prog_10", "cat": "prog", "name": "小有名气", "desc": "达到 10 级。你已经能在谷地里独自走夜路了。",
		"kind": "level", "target": 10, "pts": 10, "reward": {"money": 2000, "items": [["potion_heal2", 2]]}},
	{"id": "prog_15", "cat": "prog", "name": "独当一面", "desc": "达到 15 级。潮风高地的风也吹不倒你了。",
		"kind": "level", "target": 15, "pts": 15, "reward": {"money": 6000}},
	{"id": "prog_20", "cat": "prog", "name": "以太纪元的传说", "desc": "达到等级上限 20 级。这条路的尽头，你自己就是路标。",
		"kind": "level", "target": 20, "pts": 25, "reward": {"money": 20000, "items": [["potion_heal2", 5]]}},
	{"id": "prog_spells", "cat": "prog", "name": "术业有专攻", "desc": "学会 10 个职业技能。",
		"kind": "spells", "target": 10, "pts": 10},
	{"id": "prog_spec", "cat": "prog", "name": "择路而行", "desc": "在 15 级完成转职，选定自己的道路。",
		"kind": "spec", "target": 1, "pts": 15, "reward": {"money": 6000}},
	{"id": "prog_recipes", "cat": "prog", "name": "配方收藏家", "desc": "学会 8 张制造配方。",
		"kind": "recipes", "target": 8, "pts": 15},

	# ============================================================ 任务
	{"id": "quest_1", "cat": "quest", "name": "第一次交差", "desc": "完成 1 个任务。有人愿意把事交给你了。",
		"kind": "stat", "key": "quests", "target": 1, "pts": 5, "reward": {"money": 300}},
	{"id": "quest_10", "cat": "quest", "name": "办事牢靠", "desc": "完成 10 个任务。",
		"kind": "stat", "key": "quests", "target": 10, "pts": 10, "reward": {"money": 1500}},
	{"id": "quest_25", "cat": "quest", "name": "谷地的熟人", "desc": "完成 25 个任务。走哪儿都有人跟你打招呼。",
		"kind": "stat", "key": "quests", "target": 25, "pts": 15, "reward": {"money": 4000}},
	{"id": "quest_50", "cat": "quest", "name": "有求必应", "desc": "完成 50 个任务。",
		"kind": "stat", "key": "quests", "target": 50, "pts": 25, "reward": {"money": 12000, "items": [["potion_heal2", 3]]}},
	{"id": "quest_main_5", "cat": "quest", "name": "主线：追着钟声走", "desc": "完成 5 个主线任务。",
		"kind": "stat", "key": "quests_main", "target": 5, "pts": 10},
	{"id": "quest_main_10", "cat": "quest", "name": "主线：钟声的阴影", "desc": "完成 10 个主线任务。灰巾帮背后那口钟，你迟早要弄明白。",
		"kind": "stat", "key": "quests_main", "target": 10, "pts": 25, "reward": {"money": 15000}},

	# ============================================================ 战斗
	{"id": "combat_50", "cat": "combat", "name": "斩杀者", "desc": "击杀 50 个敌人。",
		"kind": "stat", "key": "kills", "target": 50, "pts": 5, "reward": {"money": 500}},
	{"id": "combat_200", "cat": "combat", "name": "战场老兵", "desc": "击杀 200 个敌人。",
		"kind": "stat", "key": "kills", "target": 200, "pts": 10, "reward": {"money": 2000}},
	{"id": "combat_500", "cat": "combat", "name": "万军辟易", "desc": "击杀 500 个敌人。",
		"kind": "stat", "key": "kills", "target": 500, "pts": 20, "reward": {"money": 8000, "items": [["potion_heal2", 3]]}},
	{"id": "combat_elite_10", "cat": "combat", "name": "精英猎手", "desc": "击杀 10 只精英怪。",
		"kind": "stat", "key": "elites", "target": 10, "pts": 10},
	{"id": "combat_named_5", "cat": "combat", "name": "悬赏猎人", "desc": "击杀 5 只稀有或命名怪。",
		"kind": "stat", "key": "rares", "target": 5, "pts": 15, "reward": {"money": 3000}},
	{"id": "combat_boss_1", "cat": "combat", "name": "第一次倒下的是它", "desc": "击败 1 个首领。",
		"kind": "stat", "key": "bosses", "target": 1, "pts": 15, "reward": {"money": 5000}},
	{"id": "combat_boss_3", "cat": "combat", "name": "三面旗帜", "desc": "击败 3 个首领。风语旧圣堂的三面旗，一面也别留。",
		"kind": "stat", "key": "bosses", "target": 3, "pts": 25, "reward": {"money": 20000, "items": [["potion_heal2", 4]]}},
	{"id": "combat_boss_root", "cat": "combat", "name": "腐根之下", "desc": "击败腐根守卫 厄尔班。",
		"kind": "kill", "key": "boss_rootguard", "target": 1, "pts": 15},
	{"id": "combat_boss_lake", "cat": "combat", "name": "双枪落地", "desc": "击败双枪 莱克。",
		"kind": "kill", "key": "boss_lake", "target": 1, "pts": 15},
	{"id": "combat_boss_victor", "cat": "combat", "name": "钟楼的最后一响", "desc": "击败堕落的守钟人 维克托。",
		"kind": "kill", "key": "boss_victor", "target": 1, "pts": 25, "reward": {"money": 10000}},
	{"id": "combat_death_1", "cat": "combat", "name": "第一次阵亡", "desc": "阵亡 1 次。真正的冒险从摔这一跤开始。",
		"kind": "stat", "key": "deaths", "target": 1, "pts": 5, "hidden": true},
	{"id": "combat_death_10", "cat": "combat", "name": "屡仆屡起", "desc": "阵亡 10 次。墓碑也是里程碑。",
		"kind": "stat", "key": "deaths", "target": 10, "pts": 10, "hidden": true},

	# ============================================================ 探索
	{"id": "explore_5", "cat": "explore", "name": "走出村口", "desc": "发现 5 个地点。",
		"kind": "explored", "target": 5, "pts": 5, "reward": {"money": 300}},
	{"id": "explore_15", "cat": "explore", "name": "见多识广", "desc": "发现 15 个地点。",
		"kind": "explored", "target": 15, "pts": 10, "reward": {"money": 1500}},
	{"id": "explore_30", "cat": "explore", "name": "踏遍谷地", "desc": "发现 30 个地点。",
		"kind": "explored", "target": 30, "pts": 15, "reward": {"money": 5000}},
	{"id": "explore_50", "cat": "explore", "name": "大地的名字", "desc": "发现 50 个地点。地图上每一处空白都填上了名字。",
		"kind": "explored", "target": 50, "pts": 25, "reward": {"money": 15000}},
	{"id": "explore_abbey", "cat": "explore", "name": "晨钟之下", "desc": "抵达晨钟修道院。",
		"kind": "poi", "key": "poi_abbey", "target": 1, "pts": 5},
	{"id": "explore_city", "cat": "explore", "name": "海风与汽笛", "desc": "抵达晴岚港的内港。",
		"kind": "poi", "key": "poi_solenne", "target": 1, "pts": 10},
	{"id": "explore_sanctum", "cat": "explore", "name": "藤蔓深处", "desc": "抵达风语旧圣堂前庭。",
		"kind": "poi", "key": "poi_sanctum_in", "target": 1, "pts": 15},
	{"id": "explore_fp", "cat": "explore", "name": "飞行常客", "desc": "发现 4 个飞行点。",
		"kind": "stat", "key": "fps", "target": 4, "pts": 10},

	# ============================================================ 专业与经济
	{"id": "prof_learn_1", "cat": "prof", "name": "学一门手艺", "desc": "学会 1 个专业技能。",
		"kind": "profs", "target": 1, "pts": 5},
	{"id": "prof_learn_2", "cat": "prof", "name": "多面手", "desc": "学会 2 个专业技能。",
		"kind": "profs", "target": 2, "pts": 10, "reward": {"money": 2000}},
	{"id": "prof_craft_1", "cat": "prof", "name": "第一件作品", "desc": "制造 1 件物品。",
		"kind": "stat", "key": "craft", "target": 1, "pts": 5, "reward": {"money": 300}},
	{"id": "prof_craft_10", "cat": "prof", "name": "手艺人", "desc": "制造 10 件物品。",
		"kind": "stat", "key": "craft", "target": 10, "pts": 10, "reward": {"money": 1500}},
	{"id": "prof_craft_50", "cat": "prof", "name": "匠人", "desc": "制造 50 件物品。",
		"kind": "stat", "key": "craft", "target": 50, "pts": 20, "reward": {"money": 6000}},
	{"id": "prof_gather_25", "cat": "prof", "name": "采药人的背篓", "desc": "采集 25 次矿石或草药。",
		"kind": "stat", "key": "gather", "target": 25, "pts": 10, "reward": {"money": 1200}},
	{"id": "prof_gather_100", "cat": "prof", "name": "走遍山野", "desc": "采集 100 次。",
		"kind": "stat", "key": "gather", "target": 100, "pts": 20, "reward": {"money": 5000}},
	{"id": "prof_auction_1", "cat": "prof", "name": "第一笔生意", "desc": "在交易所卖出 1 件商品。",
		"kind": "stat", "key": "auction_sold", "target": 1, "pts": 10, "reward": {"money": 800}},
	{"id": "prof_mail_10", "cat": "prof", "name": "信箱常客", "desc": "收到 10 封来信（训练师的、军需官的、赏金战报都算）。",
		"kind": "stat", "key": "mails", "target": 10, "pts": 10},
	{"id": "prof_money_10", "cat": "prof", "name": "小有积蓄", "desc": "一次性持有 10 金。",
		"kind": "money", "target": 100000, "pts": 10},
	{"id": "prof_money_100", "cat": "prof", "name": "富甲一方", "desc": "一次性持有 100 金。",
		"kind": "money", "target": 1000000, "pts": 25, "reward": {"items": [["potion_heal2", 5]]}},

	# ============================================================ 声望
	{"id": "rep_first", "cat": "rep", "name": "第一次被记住", "desc": "任一势力达到友善。",
		"kind": "rep_any", "target": 500, "pts": 10, "reward": {"money": 1000}},
	{"id": "rep_1500", "cat": "rep", "name": "声名远扬", "desc": "任一势力达到尊敬（1500 点）。",
		"kind": "rep_any", "target": 1500, "pts": 15, "reward": {"money": 4000}},
	{"id": "rep_3000", "cat": "rep", "name": "一方支柱", "desc": "任一势力达到崇敬（3000 点）。",
		"kind": "rep_any", "target": 3000, "pts": 20, "reward": {"money": 10000}},
	{"id": "rep_5000", "cat": "rep", "name": "活着的传说", "desc": "任一势力达到崇拜（5000 点）。",
		"kind": "rep_any", "target": 5000, "pts": 30, "reward": {"money": 25000, "items": [["potion_heal2", 5]]}},
	{"id": "rep_all_friendly", "cat": "rep", "name": "五方通吃", "desc": "五个势力全部达到友善。",
		"kind": "rep_all", "target": 500, "pts": 30, "reward": {"money": 20000}},
	{"id": "rep_abbey", "cat": "rep", "name": "修道院的朋友", "desc": "晨钟修道院达到尊敬。",
		"kind": "rep", "key": "abbey", "target": 1500, "pts": 10},
	{"id": "rep_city", "cat": "rep", "name": "港口的贵客", "desc": "晴岚港达到尊敬。",
		"kind": "rep", "key": "city", "target": 1500, "pts": 10},
	{"id": "rep_guild", "cat": "rep", "name": "荣誉板上的名字", "desc": "冒险者公会达到尊敬。",
		"kind": "rep", "key": "guild", "target": 1500, "pts": 10},

	# ============================================================ 坐骑
	{"id": "mount_1", "cat": "explore", "name": "第一匹坐骑", "desc": "收集 1 个坐骑。",
		"kind": "mounts", "target": 1, "pts": 5},
	{"id": "mount_3", "cat": "explore", "name": "马厩里没空位了", "desc": "收集 3 个坐骑。",
		"kind": "mounts", "target": 3, "pts": 15, "reward": {"money": 5000}},
	{"id": "mount_5", "cat": "explore", "name": "坐骑收藏家", "desc": "收集全部 5 个坐骑。",
		"kind": "mounts", "target": 5, "pts": 30, "reward": {"money": 20000}},

	# ============================================================ 元成就（点数）
	{"id": "meta_100", "cat": "prog", "name": "成就猎人", "desc": "累计获得 100 点成就点数。",
		"kind": "points", "target": 100, "pts": 20, "reward": {"money": 5000, "items": [["mount_bear_item", 1]]}},
	{"id": "meta_250", "cat": "prog", "name": "成就大师", "desc": "累计获得 250 点成就点数。",
		"kind": "points", "target": 250, "pts": 30, "reward": {"money": 15000, "items": [["potion_heal2", 5]]}},
]

## 按分类取条目（保持 LIST 里的顺序）
static func by_cat(cat: String) -> Array:
	var out := []
	for a in LIST:
		if a["cat"] == cat:
			out.append(a)
	return out

static func get_entry(id: String) -> Dictionary:
	for a in LIST:
		if a["id"] == id:
			return a
	return {}

## 分类总点数（界面标题用）
static func cat_points(cat: String) -> int:
	var n := 0
	for a in by_cat(cat):
		n += int(a["pts"])
	return n
