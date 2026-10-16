class_name DataMail
extends RefCounted
## 邮件文案与附件规则：系统寄出的信件内容都放这里，收发与存档逻辑在 src/core/mail.gd。
##
## 三类信件：
##   1. 升级信 —— 每 10 级由本职业训练师寄出（`level_letter`）
##   2. 声望信 —— 阵营关系升阶时由该阵营军需官寄出（`rep_letter`）
##   3. 战报信 —— 首次击杀副本首领后由对应势力寄出（`boss_letter`）

## 发升级信的训练师（与 data_world.gd 的 t_*_1 同名）
const TRAINERS := {"warrior": "雷恩", "mage": "艾薇拉", "priest": "安娜", "rogue": "影", "gunner": "布洛克"}

## 升级信的等级节点
const LEVEL_STEPS := [10, 20, 30, 40, 50, 60]

## 每档升级信的正文与附件。附件写法：{"items": [["物品id", 数量], ...], "money": 金额}
const LEVEL_LETTERS := {
	1: {
		"subj": "第一道伤疤",
		"body": "你撑过了最初的那几天，这比什么都重要。\n\n很多人死在第一次出村。你没有。\n随信附上一点补给，别嫌少——下次见面，我要看你自己活着回来。",
		"items": [["potion_heal1", 3]], "money": 120,
	},
	2: {
		"subj": "有人开始念你的名字了",
		"body": "酒馆里有人在打听那个最近总出现在钟楼附近的新人。\n\n记住，名声是双刃的。越大，找上门的麻烦也越大。\n这些药水带着，别死在半路上——我还等着看你出师。",
		"items": [["potion_heal2", 2], ["potion_mana1", 2]], "money": 400,
	},
	3: {
		"subj": "现在，我得认真对待你了",
		"body": "我承认，一开始我只是把你当又一个来混日子的。\n\n看来是我看走眼。从今天起，我教你的东西不再留手，你也别指望我再给你收拾残局。\n随信的钱拿去买装备，别省。",
		"items": [["potion_heal2", 3], ["potion_mana1", 3]], "money": 900,
	},
	4: {
		"subj": "以太在上",
		"body": "我教了三十年徒弟，没见过谁走得这么快。\n\n我已经没什么能教你的了。往后的路，你得自己找方向。\n附上的钱是我这些年的积蓄——别推辞，用在刀刃上。",
		"items": [["potion_heal2", 4], ["potion_mana1", 4]], "money": 1600,
	},
	5: {
		"subj": "最后的叮嘱",
		"body": "到此为止，你已经是能把后背交给同伴的人了。\n\n只有一句话：剑是最后的手段，不是唯一的。\n哪天你累了，随时回来，训练场那把木剑还给你留着。",
		"items": [["potion_heal2", 5], ["potion_mana1", 5]], "money": 2600,
	},
}

## 声望升阶信：按阵营给一段不同的语气，署名取该阵营军需官
const REP_LETTERS := {
	"abbey": {
		"subj": "钟声为你而鸣",
		"body": "修钟人今天又多敲了一遍——他说这次是为一个叫%s的人。\n\n修道院不富裕，能拿出来的都写在这张货单后面了。\n愿你走过的路上，钟声不哑。",
	},
	"goldshire": {
		"subj": "金穗镇的名册",
		"body": "镇公所把你的名字记进了常客名册，%s。\n\n粮仓的账我算得很细，但替金穗镇挡过事的人，我从不亏待。\n下次来的时候直接报名字，别排队。",
	},
	"city": {
		"subj": "港务处备案",
		"body": "港务处把你的名字记上了名册，%s。\n\n晴岚港的规矩很简单：你替港口扛了多少事，港口就还你多少。\n附上一点心意，收下就是。",
	},
	"guild": {
		"subj": "荣誉板上的名字",
		"body": "公会大厅的荣誉板上多了你的名字，%s。\n\n别把它当成奖状——那是欠条，写着你从今往后要多担的那份。\n赏金已随信附上。",
	},
	"tower": {
		"subj": "学者会的致意",
		"body": "难得，%s。愿意做实事的人比愿意说话的人少太多了。\n\n学者会的资源不白给，但你目前为止拿得问心无愧。\n随信附上一些消耗品，实验台上的东西烧钱。",
	},
}

## 声望信附件：按关系等级（1 友善 / 2 尊敬 / 3 崇敬 / 4 崇拜）
const REP_REWARDS := {
	1: {"items": [["potion_heal2", 2]], "money": 300},
	2: {"items": [["potion_heal2", 3], ["potion_mana1", 2]], "money": 800},
	3: {"items": [["potion_heal2", 4], ["potion_mana1", 3]], "money": 1500},
	4: {"items": [["potion_heal2", 5], ["potion_mana1", 4]], "money": 3000},
}

## 首领首杀战报信
const BOSS_LETTERS := {
	"boss_rootguard": {
		"from": "晨钟修道院院长",
		"subj": "腐烂的根已经断了",
		"body": "教堂地下室的味道终于散了。\n\n药剂师说那东西的根须已经缠了整整一代人的地基。你不只是清了一只怪物，你让这座修道院能再站一百年。\n供奉箱里的钱归你，这是规矩。",
		"money": 500, "items": [["potion_heal2", 3]],
	},
	"boss_lake": {
		"from": "港务长 布雷克",
		"subj": "湖底的账清了",
		"body": "双枪莱克的名字在赏金榜上挂了七年，没人敢接。\n\n今天早上，他的枪已经挂在我的办公室里了。港口的商船可以重新走东航道，运费能降两成——这两成是几百个水手的饭碗。\n赏金一分不少，收下。",
		"money": 800, "items": [["potion_heal2", 4], ["potion_mana1", 2]],
	},
	"boss_victor": {
		"from": "冒险者公会会长 葛雷森",
		"subj": "维克托的悬赏结清",
		"body": "我做了二十年公会会长，第一次见到有人单枪匹马把他的旗子摘下来。\n\n荣誉板上你的名字我亲自刻的，刻得比谁都深。\n赏金加三成，算我请你喝一趟酒。",
		"money": 1200, "items": [["potion_heal2", 5], ["potion_mana1", 4]],
	},
}

## 返回该等级对应的升级信（超过最后一档就一直沿用最后一档）
static func level_letter(level: int, cls: String) -> Dictionary:
	var step := 0
	for s in LEVEL_STEPS:
		if level >= s:
			step = LEVEL_STEPS.find(s) + 1
	if step <= 0:
		return {}
	step = mini(step, LEVEL_LETTERS.size())
	var d: Dictionary = LEVEL_LETTERS[step]
	return {
		"from": TRAINERS.get(cls, "训练师"),
		"subj": d["subj"],
		"body": d["body"],
		"items": d["items"],
		"money": d["money"],
	}

## 返回某阵营升到 tier（1..4）时的祝贺信
static func rep_letter(fid: String, tier: int, who: String) -> Dictionary:
	if not REP_LETTERS.has(fid) or tier < 1:
		return {}
	var d: Dictionary = REP_LETTERS[fid]
	var f: Dictionary = DataRep.factions().get(fid, {})
	var rw: Dictionary = REP_REWARDS.get(mini(tier, 4), {})
	var signer: String = String(f.get("qm_name", f.get("name", "")))
	# 正文里只有一部分信会点名收信人；没有占位符时不能直接 % who（会抛格式化错误）
	var body: String = String(d["body"])
	if body.contains("%"):
		body = body % who
	return {
		"from": signer,
		"fid": fid,
		"subj": "%s · %s" % [d["subj"], DataRep.tier_name(tier)],
		"body": body,
		"items": rw.get("items", []),
		"money": rw.get("money", 0),
	}

## 返回首次击杀某首领的战报信
static func boss_letter(mob_id: String) -> Dictionary:
	if not BOSS_LETTERS.has(mob_id):
		return {}
	var d: Dictionary = BOSS_LETTERS[mob_id]
	return {"from": d["from"], "subj": d["subj"], "body": d["body"], "items": d["items"], "money": d["money"]}
