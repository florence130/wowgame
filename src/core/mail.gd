class_name Mail
extends RefCounted
## 邮箱：收信、领取附件、删除、过期清理。存档在 Game.pd["mail"]（数组，新邮件追加在末尾）。
##
## 信件字段：
##   id     唯一编号（Game.pd["mail_seq"] 自增）
##   from   发件人显示名        fid  可选，阵营 id（信纸配色用）
##   subj   主题                body 正文（可含换行）
##   items  [{"id": 物品id, "n": 数量}]   money 附件金币
##   read   是否已读            done  附件是否已领完
##   day    收到时的游戏内天数（Mail.now_day()），用于过期
##
## 约定：信件本身不写存档版本，`Game.load` 时按需补齐键；测试一律不落盘。

const MAX_MAIL := 40          ## 最多保留的邮件数（超出时先清已读已领，再挤掉最旧的）
const EXPIRE_DAYS := 30       ## 已领取的邮件保留天数，超期自动清理

static func box() -> Array:
	if Game.pd.is_empty():
		return []
	if not Game.pd.has("mail"):
		Game.pd["mail"] = []
	return Game.pd["mail"]

## 游戏内天数：一天 24 分钟（1 小时 = 1 分钟），与昼夜循环同源
static func now_day() -> int:
	return int(Game.pd.get("played", 0.0) / 1440.0)

static func next_id() -> int:
	var n: int = int(Game.pd.get("mail_seq", 1))
	Game.pd["mail_seq"] = n + 1
	return n

## 投递一封系统信件，返回邮件字典（内容为空则不投递）
static func deliver(from: String, subj: String, body: String, items: Array = [], money: int = 0, fid: String = "", quiet: bool = false) -> Dictionary:
	if Game.pd.is_empty() or subj == "":
		return {}
	var m := {
		"id": next_id(), "from": from, "fid": fid, "subj": subj, "body": body,
		"items": _norm_items(items), "money": maxi(0, money),
		"read": false, "done": false, "day": now_day(),
	}
	box().append(m)
	_trim()
	Achieve.bump("mails")
	if not quiet:
		Game.msg("收到新邮件：[%s]（来自 %s）" % [subj, from], Color("a0d0ff"))
		Sfx.play("quest_progress")
	Game.mail_changed.emit()
	return m

## 把模板字典投递出去（DataMail 的三个 letter 函数都返回这个形状）
static func deliver_template(t: Dictionary) -> Dictionary:
	if t.is_empty():
		return {}
	return deliver(t.get("from", ""), t.get("subj", ""), t.get("body", ""), t.get("items", []), int(t.get("money", 0)), t.get("fid", ""))

static func by_id(id: int) -> Dictionary:
	for m in box():
		if int(m.get("id", 0)) == id:
			return m
	return {}

static func unread() -> int:
	var n := 0
	for m in box():
		if not m.get("read", false):
			n += 1
	return n

## 未领取附件的邮件数（HUD 徽章用未读，这里给测试与统计用）
static func pending() -> int:
	var n := 0
	for m in box():
		if has_attach(m) and not m.get("done", false):
			n += 1
	return n

static func has_attach(m: Dictionary) -> bool:
	return not (m.get("items", []) as Array).is_empty() or int(m.get("money", 0)) > 0

static func mark_read(id: int) -> void:
	var m := by_id(id)
	if not m.is_empty() and not m.get("read", false):
		m["read"] = true
		Game.mail_changed.emit()

## 领取附件：背包放不下的部分留在信里，返回是否全部领完
static func claim(id: int) -> bool:
	var m := by_id(id)
	if m.is_empty():
		return false
	m["read"] = true
	var left := []
	for st in m.get("items", []) as Array:
		var rest: int = Game.add_item(st["id"], int(st["n"]), false, false)
		if rest > 0:
			left.append({"id": st["id"], "n": rest})
	m["items"] = left
	var pay: int = int(m.get("money", 0))
	if pay > 0:
		Game.add_money(pay)
		Game.msg("从邮件中取出 %d 银币。" % pay, Color("ffd040"))
		m["money"] = 0
	m["done"] = left.is_empty()
	if not m["done"]:
		Game.err("背包已满，部分附件留在邮件里。")
	Game.mail_changed.emit()
	return m["done"]

## 一键领取所有有附件的邮件，返回领取的邮件数
static func claim_all() -> int:
	var n := 0
	for m in box().duplicate():
		if has_attach(m) and not m.get("done", false):
			claim(int(m.get("id", 0)))
			n += 1
	if n > 0:
		Game.msg("已领取 %d 封邮件的附件。" % n, Color("ffe9a8"))
	return n

## 删除一封（有未领取附件时不允许，避免误删）
static func erase(id: int) -> bool:
	var arr := box()
	for i in arr.size():
		var m: Dictionary = arr[i]
		if int(m.get("id", 0)) != id:
			continue
		if has_attach(m) and not m.get("done", false):
			Game.err("这封邮件还有未领取的附件。")
			return false
		arr.remove_at(i)
		Game.mail_changed.emit()
		return true
	return false

## 删除所有已读邮件，返回删除数量
static func erase_read() -> int:
	var arr := box()
	var kept := []
	var n := 0
	for m in arr:
		if m.get("read", false) and not (has_attach(m) and not m.get("done", false)):
			n += 1
		else:
			kept.append(m)
	if n > 0:
		Game.pd["mail"] = kept
		Game.msg("已删除 %d 封已读邮件。" % n, Color("a8adb8"))
		Game.mail_changed.emit()
	return n

## 清理：过期（已领取且超过 EXPIRE_DAYS 天）+ 超出上限时的挤压
static func prune() -> int:
	var arr := box()
	var kept := []
	var n := 0
	var today := now_day()
	for m in arr:
		var stale: bool = not has_attach(m) and today - int(m.get("day", today)) >= EXPIRE_DAYS
		if stale:
			n += 1
		else:
			kept.append(m)
	if n > 0:
		Game.pd["mail"] = kept
	return n

static func _trim() -> void:
	var arr := box()
	if arr.size() <= MAX_MAIL:
		return
	# 先清「已读且附件已领完」的旧信；仍超限则从最旧的开始挤掉
	var drop := arr.size() - MAX_MAIL
	var kept := []
	for m in arr:
		var disposable: bool = m.get("read", false) and not (has_attach(m) and not m.get("done", false))
		if drop > 0 and disposable:
			drop -= 1
			continue
		kept.append(m)
	while kept.size() > MAX_MAIL:
		kept.remove_at(0)
	Game.pd["mail"] = kept

static func _norm_items(items: Array) -> Array:
	var out := []
	for it in items:
		if it is Array and (it as Array).size() >= 2:
			out.append({"id": String(it[0]), "n": int(it[1])})
		elif it is Dictionary:
			out.append({"id": String(it.get("id", "")), "n": int(it.get("n", 1))})
	return out

# ---------------------------------------------------------------- 系统钩子
## 升级信：每 10 级一封，同一等级只发一次
static func on_level_up(level: int) -> void:
	if level % 10 != 0 or level > DataMail.LEVEL_STEPS[-1]:
		return
	var t: Dictionary = DataMail.level_letter(level, Game.pd.get("class", ""))
	deliver_template(t)

## 声望升阶信：由 Rep.gain 在关系等级变化时调用
static func on_rep_tier(fid: String, tier: int) -> void:
	var who: String = Game.pd.get("name", "冒险者")
	deliver_template(DataMail.rep_letter(fid, tier, who))

## 首领首杀战报：同一首领只寄一次（靠 pd["mail_boss"] 记录）
static func on_boss_kill(mob_id: String) -> void:
	if Game.pd.is_empty() or mob_id == "":
		return
	if not Game.pd.has("mail_boss"):
		Game.pd["mail_boss"] = {}
	if Game.pd["mail_boss"].has(mob_id):
		return
	var t: Dictionary = DataMail.boss_letter(mob_id)
	if t.is_empty():
		return
	Game.pd["mail_boss"][mob_id] = true
	deliver_template(t)
