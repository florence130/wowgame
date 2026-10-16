class_name Achieve
extends RefCounted
## 成就系统：进度判定、达成与奖励发放、广播。
##
## 存档：`pd["achiev"] = {"done": {id: 达成时的天数}, "stats": {统计键: 计数}, "pts": 累计点数}`。
## stats 是一生累计的计数器，由玩法钩子累加（击杀、任务、制造、采集、阵亡、拍卖成交、飞行点、最高持币…），
## 判定时按条目里的 `kind` / `key` 取值与 `target` 比较。老存档在 `Game.load()` 里补齐键，不升存档版本。
##
## 钩子一览：`Game.turn_in_quest` / `Game.on_kill` / `Game._on_level_up` / `Game.add_money` /
## `Game.on_explore` / `Game.learn_flight_path` / `Player._on_death` / `Prof.finish_craft` /
## `GatherNode._complete` / `Auction` 成交 / `Mail.deliver`。

## 达成时的广播延迟（同一次结算里连开多个成就时，逐条弹出更清楚）
static var _pending: Array = []

static func data() -> Dictionary:
	if not Game.pd.has("achiev"):
		Game.pd["achiev"] = {}
	var d: Dictionary = Game.pd["achiev"]
	if not d.has("done"):
		d["done"] = {}
	if not d.has("stats"):
		d["stats"] = {}
	if not d.has("pts"):
		d["pts"] = 0
	return d

static func stats() -> Dictionary:
	return data()["stats"]

static func done() -> Dictionary:
	return data()["done"]

static func is_done(id: String) -> bool:
	return done().has(id)

static func total_points() -> int:
	return int(data().get("pts", 0))

static func all_points() -> int:
	var n := 0
	for a in DataAchiev.LIST:
		n += int(a["pts"])
	return n

static func count_done() -> int:
	return done().size()

static func now_day() -> int:
	return int(Game.pd.get("played", 0.0) / 1440.0)

# ================================================================ 统计累加
## 累加一个统计键，并立即判定（只有用到该键的条目会真的推进）
static func bump(key: String, n: int = 1) -> void:
	if Game.pd.is_empty() or key == "":
		return
	var st := stats()
	st[key] = int(st.get(key, 0)) + n
	evaluate()

## 记录持币峰值（"小有积蓄"这类成就用）
## 这里**不**触发判定：add_money 会在买东西、洗点、扣税这类流程中间被调用，
## 若当场解锁成就并发放奖励，就会改动同一次操作里的余额（洗点扣费曾因此被成就奖励冲掉）。
## 峰值只做记录，判定交给击杀 / 任务 / 升级 / 登录与 Game 的定期结算。
static func note_money(v: int) -> void:
	if Game.pd.is_empty():
		return
	var st := stats()
	if v > int(st.get("money_peak", 0)):
		st["money_peak"] = v

## 击杀：游戏侧只传怪物定义，这里拆出总数 / 精英 / 稀有命名 / 首领
static func on_kill(mob_id: String, mob: Dictionary) -> void:
	if Game.pd.is_empty():
		return
	var st := stats()
	st["kills"] = int(st.get("kills", 0)) + 1
	if mob.get("elite", false):
		st["elites"] = int(st.get("elites", 0)) + 1
	if mob.get("boss", false):
		st["bosses"] = int(st.get("bosses", 0)) + 1
	if mob.get("rare", false) or mob.get("named", false):
		st["rares"] = int(st.get("rares", 0)) + 1
	evaluate()

# ================================================================ 判定
## 当前值（用于进度显示与达成判定）
static func value(a: Dictionary) -> int:
	match String(a.get("kind", "stat")):
		"stat":
			return int(stats().get(String(a.get("key", "")), 0))
		"kill":
			return int(Game.pd.get("kills", {}).get(String(a.get("key", "")), 0))
		"level":
			return int(Game.pd.get("level", 1))
		"rep":
			return Rep.points(String(a.get("key", "")))
		"rep_any":
			return _rep_extreme(true)
		"rep_all":
			return _rep_extreme(false)
		"explored":
			return (Game.pd.get("explored", {}) as Dictionary).size()
		"poi":
			return 1 if (Game.pd.get("explored", {}) as Dictionary).has(String(a.get("key", ""))) else 0
		"spells":
			return _spell_count()
		"spec":
			return 1 if str(Game.pd.get("spec", "")) != "" else 0
		"profs":
			return Prof.data().size()
		"mounts":
			return Mounts.learned_count()
		"recipes":
			return (Game.pd.get("recipes", {}) as Dictionary).size()
		"money":
			return int(stats().get("money_peak", 0))
		"points":
			return total_points()
	return 0

## 进度：Vector2(当前, 目标)
static func progress(a: Dictionary) -> Vector2:
	return Vector2(mini(value(a), int(a.get("target", 1))), int(a.get("target", 1)))

## 扫描全部条目，把已达成的解锁；返回本次新解锁数量（元成就会连带解锁，故循环到稳定）
## _busy 防重入：发奖励会经过 Game.add_money → note_money，可能再次触发判定。
static var _busy := false
static func evaluate() -> int:
	if Game.pd.is_empty() or _busy:
		return 0
	_busy = true
	var n := 0
	var changed := true
	while changed:
		changed = false
		for a in DataAchiev.LIST:
			if is_done(String(a["id"])):
				continue
			if value(a) >= int(a.get("target", 1)):
				_unlock(a)
				n += 1
				changed = true
	_busy = false
	if n > 0:
		_flush()
	return n

## 外部（界面打开时）强制刷新一次
static func check() -> int:
	return evaluate()

static func _rep_extreme(high: bool) -> int:
	var v := 0 if high else 999999
	var any := false
	for fid in DataRep.factions():
		any = true
		var p := Rep.points(fid)
		v = maxi(v, p) if high else mini(v, p)
	return v if any else 0

static func _spell_count() -> int:
	var n := 0
	for sid in Game.pd.get("spells", {}):
		if int(Game.pd["spells"][sid]) > 0:
			n += 1
	return n

# ================================================================ 达成
static func _unlock(a: Dictionary) -> void:
	var id := String(a["id"])
	done()[id] = now_day()
	data()["pts"] = total_points() + int(a["pts"])
	# 奖励：金钱与物品直接到手（与邮件不同，成就不留悬念）
	var rw: Dictionary = a.get("reward", {})
	var money := int(rw.get("money", 0))
	if money > 0:
		Game.add_money(money, true)
	for st in rw.get("items", []):
		Game.add_item(String(st[0]), int(st[1]), true, false)
	_pending.append({"name": String(a["name"]), "pts": int(a["pts"]), "money": money, "id": id})
	Game.achieve_changed.emit()

## 逐条播报（同一次结算里可能连开好几个）
static func _flush() -> void:
	var list := _pending
	_pending = []
	for i in list.size():
		var e: Dictionary = list[i]
		var money: int = int(e.get("money", 0))
		var tail := "（+%d 点）" % int(e["pts"])
		if money > 0:
			tail = "（+%d 点，奖励 %s）" % [int(e["pts"]), U.money_text(money)]
		Game.msg("成就达成：[%s] %s" % [String(e["name"]), tail], Color("ffe9a8"))
		if i == 0:
			Game.center_text.emit("成就达成！", "%s  %s" % [String(e["name"]), tail])
	Game.achieve_changed.emit()

# ================================================================ 界面辅助
static func visible_entries() -> Array:
	var out := []
	for a in DataAchiev.LIST:
		if a.get("hidden", false) and not is_done(String(a["id"])):
			continue
		out.append(a)
	return out

## 一条成就的富文本进度说明（界面用）
static func progress_text(a: Dictionary) -> String:
	if is_done(String(a["id"])):
		return "[color=#80ff80]已完成[/color]"
	var t := int(a.get("target", 1))
	var v := value(a)
	if t <= 1:
		return "[color=#a8adb8]未完成[/color]"
	return "%s %d/%d" % [_bar(v, t), v, t]

static func _bar(v: int, t: int) -> String:
	var n := int(round(clampf(float(v) / maxf(float(t), 1.0), 0.0, 1.0) * 10.0))
	return "[" + "■".repeat(n) + "·".repeat(10 - n) + "]"
