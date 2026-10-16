extends Node
## 游戏状态（自动加载 Game）：角色数据、背包、装备、任务、存档、设置

signal inventory_changed
signal equipment_changed
signal money_changed
signal xp_changed
signal level_up(level: int)
signal quest_log_changed
signal quest_progress(qid: String, text: String)
signal target_changed(unit)
signal chat(text: String, color: Color)
signal error_text(text: String)
signal center_text(text: String, sub: String)
signal spells_changed
signal bars_changed
signal appearance_changed
signal zone_entered(zone_id: String)
signal subzone_changed(name: String)
signal settings_changed
signal npc_markers_dirty
signal item_looted(id: String, n: int)
signal rep_changed
signal mail_changed
signal achieve_changed

const BAG_SIZE := 180
const BAG_PAGE := 90
const BANK_SIZE := 90
const BAR_SLOTS := 24
const EQUIP_SLOTS := ["head", "neck", "back", "chest", "shirt", "tabard", "wrist", "hands", "waist", "legs", "feet", "finger1", "finger2", "trinket1", "trinket2", "main", "off", "ranged"]
const SAVE_DIR := "user://saves"

var pd: Dictionary = {}
var slot_index := -1
var player = null
var world = null
var hud = null
var zone = null
var settings := {
	"mouse_sens": 0.25, "invert_y": false, "sfx": 0.7, "music": 0.4, "day_minutes": 48.0, "show_fps": true, "shadows": true,
	"view_dist": 700.0, "nameplates": true, "auto_loot": false, "ui_scale": 1.0, "weather": true, "volumetric_fog": true, "depth_of_field": true, "fullscreen": false,
}
var keybinds := {}
const DEFAULT_KEYS := {
	"move_forward": KEY_W, "move_back": KEY_S, "turn_left": KEY_A, "turn_right": KEY_D, "strafe_left": KEY_Q, "strafe_right": KEY_E,
	"jump": KEY_SPACE, "autorun": KEY_NUMLOCK, "autorun2": KEY_R, "sit": KEY_X, "target_nearest": KEY_TAB, "interact": KEY_F,
	"char": KEY_C, "bags": KEY_B, "quests": KEY_L, "spellbook": KEY_P, "map": KEY_M, "dungeon": KEY_I, "toggle_ui": KEY_Z,
	"nameplates": KEY_V, "screenshot": KEY_PRINT, "walk": KEY_SLASH, "prof": KEY_K, "talents": KEY_N, "mail": KEY_O, "achiev": KEY_Y,
	"mounts": KEY_J,
}
var bar_keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]
var time_of_day := 9.0  # 0-24
var rng := RandomNumberGenerator.new()
var buyback: Array = []
var _played_accum := 0.0
var item_cooldowns := {}  # 共享冷却组 -> 剩余秒数
var _ah_t := 5.0
var _ach_t := 5.0
var paused_world := false
var _loot_retry_queued := false
var _delivering_loot := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	keybinds = DEFAULT_KEYS.duplicate()
	load_settings()
	inventory_changed.connect(_queue_loot_delivery)
	# 声望变化后重算成就（阵营声望类条目的进度就挂在这里）
	rep_changed.connect(func(): Achieve.evaluate())
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	get_tree().root.theme = UITheme.build()

func _process(delta: float) -> void:
	if pd.is_empty() or world == null:
		return
	if not get_tree().paused:
		var day_len: float = maxf(1.0, settings.get("day_minutes", 48.0)) * 60.0
		time_of_day = fmod(time_of_day + delta * 24.0 / day_len, 24.0)
		pd["played"] = pd.get("played", 0.0) + delta
		for k in item_cooldowns.keys():
			item_cooldowns[k] -= delta
			if item_cooldowns[k] <= 0.0:
				item_cooldowns.erase(k)
		_ah_t -= delta
		if _ah_t <= 0.0:
			_ah_t = 5.0
			Auction.tick()
		# 成就定期结算（每 5 秒一次）：收入类、跨系统类的条目在这里补判，
		# 不放在 add_money 里当场判定——那会在买卖/洗点过程中改动余额。
		_ach_t -= delta
		if _ach_t <= 0.0:
			_ach_t = 5.0
			Achieve.evaluate()

func msg(text: String, color: Color = Color("ffe9a8")) -> void:
	chat.emit(text, color)

func err(text: String) -> void:
	error_text.emit(text)
	Sfx.play("error")

# ================================================================ 角色创建/存档
func new_character(name: String, cls: String, app: Dictionary) -> Dictionary:
	var c := {
		"name": name, "class": cls, "level": 1, "xp": 0, "money": 0, "app": app,
		"bag": [], "bank": [], "equip": {}, "tmog": {}, "appearances": {}, "spells": {}, "bars": [], "spec": "", "rep": {},
		"quests": {}, "qdone": {}, "flags": {}, "zone": "vale", "pos": Vector3.ZERO, "yaw": 0.0, "new": true, "world_ver": 3,
		"bind": {"zone": "vale", "pos": Vector3.ZERO, "name": "晨钟修道院", "spawn": "abbey"},
		"fps": {}, "explored": {}, "played": 0.0, "created": Time.get_unix_time_from_system(), "rested": 0.0,
		"riding": false, "pet": {}, "kills": {}, "time": 9.0, "pending_loot": [],
	}
	c["bag"].resize(BAG_SIZE)
	c["bank"].resize(BANK_SIZE)
	c["bars"].resize(BAR_SLOTS)
	var cd: Dictionary = DB.classes[cls]
	for sid in cd["spells"]:
		if DB.spell_rank_level(sid, 1) <= 1:
			c["spells"][sid] = 1
	var bi := 0
	if cd.get("melee", false):
		c["bars"][0] = {"t": "spell", "id": "attack"}
		bi = 1
	for sid in cd["spells"]:
		if c["spells"].has(sid) and bi < 12:
			c["bars"][bi] = {"t": "spell", "id": sid}
			bi += 1
	pd = c
	for iid in cd["start_items"]:
		var it := DB.get_item(iid)
		var eq: String = it.get("equip", "")
		if eq != "" and it.get("slot", "") != "":
			var s := _resolve_equip_slot(it)
			pd["equip"][s] = iid
			pd["appearances"][iid] = true
		else:
			add_item(iid, 5 if it.get("stack", 1) > 1 else 1, true)
	add_item("hearthstone", 1, true)
	# 消耗品放到动作条
	for i in range(BAG_SIZE):
		var st = pd["bag"][i]
		if st != null and DB.get_item(st["id"]).get("type", "") in ["food", "drink"]:
			pd["bars"][11] = {"t": "item", "id": st["id"]}
			break
	pd["bars"][10] = {"t": "item", "id": "hearthstone"}
	_auto_place_spell("dodge_roll")
	return pd

func list_saves() -> Array:
	var out := []
	for i in 8:
		var path := "%s/char_%d.sav" % [SAVE_DIR, i]
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f:
				var d = str_to_var(f.get_as_text())
				if d is Dictionary:
					out.append({"slot": i, "data": d})
	return out

func free_slot() -> int:
	for i in 8:
		if not FileAccess.file_exists("%s/char_%d.sav" % [SAVE_DIR, i]):
			return i
	return -1

func save_game() -> void:
	if pd.is_empty() or slot_index < 0:
		return
	if player and is_instance_valid(player):
		pd["pos"] = player.global_position
		pd["yaw"] = player.rotation.y
		pd["hp"] = player.hp
		pd["power"] = player.power
	pd["time"] = time_of_day
	pd.erase("new")
	var f := FileAccess.open("%s/char_%d.sav" % [SAVE_DIR, slot_index], FileAccess.WRITE)
	if f:
		f.store_string(var_to_str(pd))

func load_character(slot: int) -> bool:
	var path := "%s/char_%d.sav" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var d = str_to_var(f.get_as_text())
	if not (d is Dictionary):
		return false
	pd = d
	slot_index = slot
	if not pd.has("flags"):
		pd["flags"] = {}
	# 旧版圣堂任务已完成的存档迁移到新的流程旗标，避免重制后把已击杀首领重新锁住。
	if pd.get("qdone", {}).has("q_c17"):
		pd["flags"]["sanctum_ember_root"] = true
	if pd.get("qdone", {}).has("q_c18"):
		pd["flags"]["sanctum_ember_lake"] = true
	for k in ["bag", "bank", "bars"]:
		var want: int = {"bag": BAG_SIZE, "bank": BANK_SIZE, "bars": BAR_SLOTS}[k]
		if pd[k].size() < want:
			pd[k].resize(want)
	time_of_day = pd.get("time", 9.0)
	_grant_starter_rotation()
	_retire_shoulder_slot()
	# 旧版天赋系统已退役：丢弃存档里的天赋点，改用 15 级转职（pd["spec"]）
	pd.erase("talents")
	if not pd.has("spec"):
		pd["spec"] = ""
	# 转职表改版后不存在的旧 id（武器大师 / 不屈卫士）：清空，让玩家重新选择（改选首次免费）
	if str(pd["spec"]) != "" and (not DB.spec_index.has(str(pd["spec"])) or DB.spec_index[str(pd["spec"])].get("class", "") != pd["class"] or int(pd["level"]) < 15):
		pd["spec"] = ""
	if not pd.has("rep"):
		pd["rep"] = {}
	if not pd.has("mail"):
		pd["mail"] = []
	if not pd.has("mail_seq"):
		pd["mail_seq"] = 1
	if not pd.has("mail_boss"):
		pd["mail_boss"] = {}
	if not pd.has("achiev"):
		pd["achiev"] = {}
	Mail.prune()
	Specs.invalidate()
	Specs.sync_spells(true)
	# 老存档补齐成就存档键，并结算一次（登录时把已达成的条目补齐，收入类成就在这里入账）
	Achieve.data()
	Achieve.evaluate()
	_queue_loot_delivery()
	return true

func delete_character(slot: int) -> void:
	DirAccess.remove_absolute("%s/char_%d.sav" % [SAVE_DIR, slot])

func save_settings() -> void:
	var f := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
	if f:
		f.store_string(var_to_str({"settings": settings, "keys": keybinds}))
	settings_changed.emit()

func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.cfg"):
		return
	var f := FileAccess.open("user://settings.cfg", FileAccess.READ)
	var d = str_to_var(f.get_as_text())
	if d is Dictionary:
		settings.merge(d.get("settings", {}), true)
		keybinds.merge(d.get("keys", {}), true)

# ================================================================ 金钱/经验
func add_money(c: int, silent: bool = false) -> void:
	pd["money"] = maxi(0, pd["money"] + c)
	Achieve.note_money(pd["money"])
	money_changed.emit()
	if not silent and c > 0:
		msg("你获得了 %s。" % U.money_text(c), Color("ffff80"))

func give_xp(amount: int, source: String = "") -> void:
	if amount <= 0:
		return
	var lvl: int = pd["level"]
	if lvl >= DB.MAX_LEVEL:
		return
	var rested_bonus := 0
	if source == "kill" and pd.get("rested", 0.0) > 0.0:
		rested_bonus = mini(amount, int(pd["rested"]))
		pd["rested"] -= rested_bonus
	var total := amount + rested_bonus
	pd["xp"] += total
	if source == "kill":
		msg("你获得了%d点经验值%s。" % [total, ("（+%d 精力充沛奖励）" % rested_bonus) if rested_bonus > 0 else ""], Color("a080ff"))
	else:
		msg("获得经验值：%d" % total, Color("a080ff"))
	while pd["level"] < DB.MAX_LEVEL and pd["xp"] >= DB.xp_to_next(pd["level"]):
		pd["xp"] -= DB.xp_to_next(pd["level"])
		pd["level"] += 1
		_on_level_up()
	if pd["level"] >= DB.MAX_LEVEL:
		pd["xp"] = 0
	xp_changed.emit()

func _on_level_up() -> void:
	var l: int = pd["level"]
	msg("恭喜！你升到了%d级！" % l, Color("ffd040"))
	center_text.emit("等级提升！", "你达到了 %d 级" % l)
	Sfx.play("levelup")
	if player:
		player.recalc_stats()
		player.hp = player.max_hp
		player.power = player.max_power if player.power_type != "rage" else 0.0
		player.level = l
		Vfx.level_up(player)
	# 提示可学技能
	var cls: String = pd["class"]
	var learnable := 0
	for sid in DB.classes[cls]["spells"]:
		var cur: int = pd["spells"].get(sid, 0)
		if DB.spell_rank_level(sid, cur + 1) == l:
			learnable += 1
	if learnable > 0:
		msg("你有%d个新技能可以向职业训练师学习。" % learnable, Color("80ff80"))
	# 每 10 级：训练师寄来祝贺信与补给
	Mail.on_level_up(l)
	if l == 10:
		msg("你现在可以向马厩管理员学习初级骑术了。", Color("80ff80"))
	if l == DataSpecs.CHOOSE_LEVEL and str(pd.get("spec", "")) == "":
		msg("你可以转职了！按 N 打开转职面板，选择你的道路。", Color("80ff80"))
	Specs.invalidate()
	if player:
		player.recalc_stats()
	level_up.emit(l)
	Achieve.evaluate()
	npc_markers_dirty.emit()

# ================================================================ 背包
func bag() -> Array:
	return pd["bag"]

func count_item(id: String) -> int:
	var n := 0
	for st in pd["bag"]:
		if st != null and st["id"] == id:
			n += st["n"]
	return n

func free_bag_slots() -> int:
	var n := 0
	for st in pd["bag"]:
		if st == null:
			n += 1
	return n

## 添加物品，返回未能放入的数量
func add_item(id: String, n: int = 1, silent: bool = false, report_full: bool = true) -> int:
	var it := DB.get_item(id)
	if it.is_empty():
		return n
	var max_stack: int = it.get("stack", 1)
	var left := n
	var bagv: Array = pd["bag"]
	if max_stack > 1:
		for i in BAG_SIZE:
			var st = bagv[i]
			if st != null and st["id"] == id and st["n"] < max_stack:
				var add := mini(max_stack - st["n"], left)
				st["n"] += add
				left -= add
				if left <= 0:
					break
	while left > 0:
		var idx := bagv.find(null)
		if idx < 0:
			break
		var add2 := mini(max_stack, left)
		bagv[idx] = {"id": id, "n": add2}
		left -= add2
	var got := n - left
	if got > 0:
		if it.get("slot", "") != "" and it.get("equip", "") != "":
			pd["appearances"][id] = true
		if not silent:
			var qc := U.quality_color(it.get("q", 1))
			msg("你获得了物品：[%s]%s。" % [it["name"], ("x%d" % got) if got > 1 else ""], qc)
			Sfx.play("loot")
			item_looted.emit(id, got)
		inventory_changed.emit()
		_check_collect_quests(id)
	if left > 0 and report_full:
		err("背包已满。")
	return left

## Consume the source before signals fire. Overflow belongs to the character, never a corpse.
func receive_loot(loot: Dictionary) -> void:
	var money: int = loot.get("money", 0)
	var items: Array = loot.get("items", []).duplicate(true)
	loot["money"] = 0
	loot["items"] = []
	if money > 0:
		add_money(money)
		Sfx.play("coin")
	if not pd.has("pending_loot"):
		pd["pending_loot"] = []
	for entry in items:
		pd["pending_loot"].append({"id": entry[0], "n": entry[1]})
	_deliver_pending_loot()
	if not items.is_empty() and not pd["pending_loot"].is_empty():
		msg("背包已满，剩余战利品已暂存；腾出空间后自动入包。", Color("ffd080"))

func _queue_loot_delivery() -> void:
	if _delivering_loot or _loot_retry_queued or pd.get("pending_loot", []).is_empty():
		return
	_loot_retry_queued = true
	_deliver_pending_loot.call_deferred()

func _deliver_pending_loot() -> void:
	_loot_retry_queued = false
	if _delivering_loot or pd.is_empty():
		return
	_delivering_loot = true
	var queued: Array = pd.get("pending_loot", [])
	pd["pending_loot"] = []
	for entry in queued:
		var left := add_item(entry["id"], entry["n"], false, false)
		if left > 0:
			pd["pending_loot"].append({"id": entry["id"], "n": left})
	if not queued.is_empty():
		# Publish the final overflow count; guard remains set so this cannot retry itself.
		inventory_changed.emit()
	_delivering_loot = false

func remove_item(id: String, n: int = 1) -> int:
	var left := n
	var bagv: Array = pd["bag"]
	for i in range(BAG_SIZE - 1, -1, -1):
		var st = bagv[i]
		if st != null and st["id"] == id:
			var take := mini(st["n"], left)
			st["n"] -= take
			left -= take
			if st["n"] <= 0:
				bagv[i] = null
			if left <= 0:
				break
	inventory_changed.emit()
	_check_collect_quests(id)
	return n - left

func remove_at(index: int, n: int = -1) -> void:
	var st = pd["bag"][index]
	if st == null:
		return
	if n < 0 or n >= st["n"]:
		pd["bag"][index] = null
	else:
		st["n"] -= n
	inventory_changed.emit()
	_check_collect_quests(st["id"])

func swap_bag(a: int, b: int) -> void:
	var bagv: Array = pd["bag"]
	var sa = bagv[a]
	var sb = bagv[b]
	if sa != null and sb != null and sa["id"] == sb["id"]:
		var ms: int = DB.get_item(sa["id"]).get("stack", 1)
		if ms > 1:
			var mv := mini(ms - sb["n"], sa["n"])
			sb["n"] += mv
			sa["n"] -= mv
			if sa["n"] <= 0:
				bagv[a] = null
			inventory_changed.emit()
			return
	bagv[a] = sb
	bagv[b] = sa
	inventory_changed.emit()

func sort_bag() -> void:
	var items_list := []
	for st in pd["bag"]:
		if st != null:
			items_list.append(st)
	# 合并堆叠
	var merged := {}
	var order := []
	for st in items_list:
		var it := DB.get_item(st["id"])
		if it.get("stack", 1) > 1:
			if not merged.has(st["id"]):
				merged[st["id"]] = 0
				order.append(st["id"])
			merged[st["id"]] += st["n"]
		else:
			order.append(st)
	var flat := []
	for o in order:
		if o is String:
			var total: int = merged[o]
			var ms: int = DB.get_item(o).get("stack", 1)
			while total > 0:
				var take := mini(ms, total)
				flat.append({"id": o, "n": take})
				total -= take
		else:
			flat.append(o)
	var type_rank := {"quest": 0, "misc": 1, "potion": 2, "food": 3, "drink": 3}
	flat.sort_custom(func(a, b):
		var ia := DB.get_item(a["id"])
		var ib := DB.get_item(b["id"])
		var ra: int = 5 if ia.get("slot", "") != "" else type_rank.get(ia.get("type", ""), 8)
		var rb: int = 5 if ib.get("slot", "") != "" else type_rank.get(ib.get("type", ""), 8)
		if ia.get("type", "") == "junk":
			ra = 9
		if ib.get("type", "") == "junk":
			rb = 9
		if ra != rb:
			return ra < rb
		if ia.get("q", 1) != ib.get("q", 1):
			return ia.get("q", 1) > ib.get("q", 1)
		return str(ia.get("name", "")) < str(ib.get("name", "")))
	var nb := []
	nb.resize(BAG_SIZE)
	for i in mini(flat.size(), BAG_SIZE):
		nb[i] = flat[i]
	pd["bag"] = nb
	inventory_changed.emit()

# ================================================================ 银行
## 背包 → 银行。bank_idx < 0 时自动找位置（先叠加再空格）。返回是否成功
func bank_deposit(bag_idx: int, bank_idx: int = -1) -> bool:
	return _move_between(pd["bag"], bag_idx, pd["bank"], bank_idx, "银行已满。")

## 银行 → 背包
func bank_withdraw(bank_idx: int, bag_idx: int = -1) -> bool:
	var ok := _move_between(pd["bank"], bank_idx, pd["bag"], bag_idx, "背包已满。")
	if ok and pd["bank"][bank_idx] == null:
		pass
	return ok

func _move_between(src: Array, si: int, dst: Array, di: int, full_msg: String) -> bool:
	var st = src[si]
	if st == null:
		return false
	var ms: int = DB.get_item(st["id"]).get("stack", 1)
	if di < 0:
		# 先叠加到同类堆
		if ms > 1:
			for i in dst.size():
				var d = dst[i]
				if d != null and d["id"] == st["id"] and d["n"] < ms:
					var mv := mini(ms - d["n"], st["n"])
					d["n"] += mv
					st["n"] -= mv
					if st["n"] <= 0:
						src[si] = null
						break
		if src[si] != null:
			di = dst.find(null)
			if di < 0:
				err(full_msg)
				inventory_changed.emit()
				return false
			dst[di] = st
			src[si] = null
	else:
		var d2 = dst[di]
		if d2 != null and d2["id"] == st["id"] and ms > 1:
			var mv2 := mini(ms - d2["n"], st["n"])
			d2["n"] += mv2
			st["n"] -= mv2
			if st["n"] <= 0:
				src[si] = null
		else:
			dst[di] = st
			src[si] = d2
	inventory_changed.emit()
	_check_collect_quests(st["id"])
	return true

# ================================================================ 装备
func can_equip(it: Dictionary, show_err: bool = true, job: String = "__current__") -> bool:
	if it.get("equip", "") == "":
		return false
	var cls: String = pd["class"]
	var cd: Dictionary = DB.classes[cls]
	var sd: Dictionary = Specs.current() if job == "__current__" else DB.spec_index.get(job, {})
	if int(pd.get("level", 1)) < DataSpecs.CHOOSE_LEVEL:
		sd = {}
	if it.get("req", 1) > pd["level"]:
		if show_err:
			err("你的等级太低，无法装备这件物品。")
		return false
	var t: String = it.get("type", "misc")
	if t in ["cloth", "leather", "mail", "plate"] and it.get("slot", "") != "back":
		if not t in cd["armor"] and not t in sd.get("armor", []):
			if show_err:
				err("你无法装备这种护甲。")
			return false
	if DataItems.WEAPON_SPEED.has(t) or t in ["shield", "offhand"]:
		if not t in cd["weapons"] and not t in sd.get("weapons", []):
			if show_err:
				err("你无法使用这种武器。")
			return false
	return true

func _resolve_equip_slot(it: Dictionary, prefer_off: bool = false) -> String:
	var s: String = it.get("equip", "")
	match s:
		"finger":
			return "finger2" if pd["equip"].has("finger1") and not pd["equip"].has("finger2") else "finger1"
		"trinket":
			return "trinket2" if pd["equip"].has("trinket1") and not pd["equip"].has("trinket2") else "trinket1"
		"main":
			if pd.get("spec", "") == "duelist" and it.get("type", "") == "rapier" and not prefer_off:
				return "main"
			if it.get("slot", "") == "one" and pd["class"] == "rogue":
				if prefer_off or (pd["equip"].has("main") and not pd["equip"].has("off")):
					return "off"
			return "main"
	return s

func equip_from_bag(index: int, prefer_off: bool = false) -> void:
	var st = pd["bag"][index]
	if st == null:
		return
	var it := DB.get_item(st["id"])
	if not can_equip(it):
		return
	if player and player.is_casting():
		err("你正在施法。")
		return
	if player and player.in_combat and it.get("slot", "") not in ["one", "two", "ranged", "off"]:
		err("你正处于战斗中！")
		return
	var slot := _resolve_equip_slot(it, prefer_off)
	pd["bag"][index] = null
	var old = pd["equip"].get(slot)
	pd["equip"][slot] = st["id"]
	pd["appearances"][st["id"]] = true
	if old != null:
		pd["bag"][index] = {"id": old, "n": 1}
	# 双手武器卸下副手
	if it.get("slot", "") == "two" and pd["equip"].has("off"):
		var off_id = pd["equip"]["off"]
		pd["equip"].erase("off")
		if add_item(off_id, 1, true) > 0:
			pd["equip"]["off"] = off_id
	if slot == "off" and pd["equip"].has("main") and DB.get_item(pd["equip"]["main"]).get("slot", "") == "two":
		var m_id = pd["equip"]["main"]
		pd["equip"].erase("main")
		add_item(m_id, 1, true)
	Sfx.play("equip")
	_after_equip_change()

func unequip(slot: String) -> void:
	if not pd["equip"].has(slot):
		return
	var id: String = pd["equip"][slot]
	var idx: int = pd["bag"].find(null)
	if idx < 0:
		err("背包已满。")
		return
	pd["equip"].erase(slot)
	pd["bag"][idx] = {"id": id, "n": 1}
	Sfx.play("equip")
	_after_equip_change()

func _after_equip_change() -> void:
	TransmogWindow.validate()
	if player:
		player.recalc_stats()
		player.refresh_visuals()
	inventory_changed.emit()
	equipment_changed.emit()

## 角色外观（幻化后）
func gear_visuals() -> Dictionary:
	var g := {}
	var map := {"head": "head", "back": "back", "chest": "chest", "shirt": "shirt", "tabard": "tabard", "wrist": "wrist",
		"hands": "hands", "waist": "waist", "legs": "legs", "feet": "feet", "main": "main", "off": "off", "ranged": "ranged"}
	for s in map:
		var id = pd["equip"].get(s)
		var tm = pd.get("tmog", {}).get(s)
		if tm == "hidden":
			continue
		if tm != null and id != null:
			id = tm
		if id != null:
			var v := DB.item_visual(id)
			if s == "main" or s == "off" or s == "ranged":
				v["wtype"] = DB.get_item(id).get("type", "sword")
			g[map[s]] = v
	if pd.get("hide_helm", false):
		g.erase("head")
	return g

# ================================================================ 属性
func calc_stats() -> Dictionary:
	var cls: String = pd["class"]
	var cd: Dictionary = DB.classes[cls]
	var lvl: int = pd["level"]
	var st := {"str": 0.0, "agi": 0.0, "sta": 0.0, "int": 0.0, "spi": 0.0, "armor": 0.0, "sp": 0.0, "ap": 0.0, "rap": 0.0, "crit": 0.0}
	for k in ["str", "agi", "sta", "int", "spi"]:
		st[k] = float(cd["base"][k]) + float(cd["growth"][k]) * (lvl - 1)
	for s in pd["equip"]:
		var it := DB.get_item(pd["equip"][s])
		if not can_equip(it, false):
			continue
		for k in it.get("stats", {}):
			st[k] = st.get(k, 0.0) + it["stats"][k]
		st["armor"] += it.get("armor", 0)
		st["sp"] += it.get("sp", 0)
		st["crit"] += it.get("crit", 0)
	for k in ["str", "agi", "sta", "int", "spi"]:
		st[k] = floorf(st[k])
	return st

# ================================================================ 技能
## New rank-1 loop skills are granted to existing characters without replacing their bars/ranks.
## 肩部装备槽已移除：旧存档里已穿戴、背包与银行中的肩部装备，按商人价折算成金币
func _retire_shoulder_slot() -> void:
	var refund := 0
	var count := 0
	if pd.get("equip", {}).has("shoulder"):
		refund += int(DB.get_item(pd["equip"]["shoulder"]).get("price", 0))
		count += 1
		pd["equip"].erase("shoulder")
	pd.get("tmog", {}).erase("shoulder")
	pd.get("appearances", {}).erase("shoulder")
	for key in ["bag", "bank"]:
		var arr: Array = pd.get(key, [])
		for i in arr.size():
			var st = arr[i]
			if st != null and DB.get_item(st["id"]).get("slot", "") == "shoulder":
				refund += int(DB.get_item(st["id"]).get("price", 0)) * int(st.get("n", 1))
				count += int(st.get("n", 1))
				arr[i] = null
	if count > 0:
		pd["money"] = int(pd.get("money", 0)) + refund
		pd["shoulder_refund"] = {"n": count, "money": refund}

func _grant_starter_rotation() -> void:
	for sid in DB.classes[pd["class"]]["spells"]:
		if DB.spell_rank_level(sid, 1) <= 1 and not pd["spells"].has(sid):
			pd["spells"][sid] = 1
			_auto_place_spell(sid)
	spells_changed.emit()

func learn_spell(sid: String, rank: int) -> void:
	var had: bool = pd["spells"].has(sid)
	pd["spells"][sid] = rank
	var sp := DB.spell(sid, rank)
	if had:
		msg("你学会了：%s（等级 %d）。" % [sp["name"], rank], Color("ffff60"))
	else:
		msg("你学会了新技能：%s。" % sp["name"], Color("ffff60"))
		_auto_place_spell(sid)
	Sfx.play("learn")
	# 技能数 / 坐骑收集这类成就在学会技能后立即重判
	Achieve.evaluate()
	spells_changed.emit()

func _auto_place_spell(sid: String) -> void:
	for b in pd["bars"]:
		if b != null and b.get("t") == "spell" and b.get("id") == sid:
			return
	for i in BAR_SLOTS:
		if pd["bars"][i] == null:
			pd["bars"][i] = {"t": "spell", "id": sid}
			bars_changed.emit()
			return

func spell_rank(sid: String) -> int:
	if DataSpells.common_spells().has(sid):
		return 1
	return pd["spells"].get(sid, 0)

# ================================================================ 任务
func quest_state(qid: String) -> String:
	if pd["qdone"].has(qid):
		return "done"
	if pd["quests"].has(qid):
		return "complete" if is_quest_complete(qid) else "active"
	return "available" if can_accept(qid) else "unavailable"

func can_accept(qid: String, ignore_level: bool = false) -> bool:
	var q: Dictionary = DB.quests.get(qid, {})
	if q.is_empty() or pd["qdone"].has(qid) or pd["quests"].has(qid):
		return false
	if q.has("class") and q["class"] != pd["class"]:
		return false
	for p in q.get("prev", []):
		if not pd["qdone"].has(p):
			return false
	if not ignore_level:
		var minl: int = q.get("min", maxi(1, q.get("lvl", 1) - 4))
		if pd["level"] < minl:
			return false
	return true

func quest_low_level_hint(qid: String) -> bool:
	return can_accept(qid, true) and not can_accept(qid)

func accept_quest(qid: String) -> void:
	if not can_accept(qid):
		return
	if pd["quests"].size() >= 25:
		err("你的任务日志已满。")
		return
	var q: Dictionary = DB.quests[qid]
	var prog := []
	for o in q.get("obj", []):
		prog.append(0)
	pd["quests"][qid] = {"p": prog}
	msg("接受任务：%s" % q["name"], Color("ffd040"))
	Sfx.play("quest_accept")
	if q.has("grant_on_accept"):
		pd["flags"][q["grant_on_accept"]] = true
		msg("晴岚港的城门已经为你敞开！", Color("80ff80"))
		if zone and zone.has_method("refresh_gates"):
			zone.refresh_gates()
	if q.has("starter_item"):
		remove_item(q["starter_item"], 1)
	# 已持有的收集物
	for i in q.get("obj", []).size():
		var o: Dictionary = q["obj"][i]
		if o["type"] == "collect":
			_check_collect_quests(o["item"])
		elif o["type"] == "explore" and pd["explored"].has(o.get("poi", "")):
			# 城市 POI 经常在接任务前就被逛过；接受任务时补记已探索目标。
			pd["quests"][qid]["p"][i] = 1
	quest_log_changed.emit()
	npc_markers_dirty.emit()

func abandon_quest(qid: String) -> void:
	if not pd["quests"].has(qid):
		return
	var q: Dictionary = DB.quests[qid]
	pd["quests"].erase(qid)
	for o in q.get("obj", []):
		if o["type"] == "collect":
			var c := count_item(o["item"])
			if c > 0:
				remove_item(o["item"], c)
	msg("放弃任务：%s" % q["name"], Color("ffd040"))
	quest_log_changed.emit()
	npc_markers_dirty.emit()

func objective_progress(qid: String, i: int) -> int:
	var q: Dictionary = DB.quests[qid]
	var o: Dictionary = q["obj"][i]
	if o["type"] == "collect":
		return mini(count_item(o["item"]), o["n"])
	var p: Array = pd["quests"][qid]["p"]
	return p[i] if i < p.size() else 0

func objective_text(qid: String, i: int) -> String:
	var q: Dictionary = DB.quests[qid]
	var o: Dictionary = q["obj"][i]
	var have := objective_progress(qid, i)
	var need: int = o.get("n", 1)
	match o["type"]:
		"kill":
			var mname: String = DB.mobs.get(o["mob"][0], {}).get("name", "?")
			return "%s已杀死：%d/%d" % [mname, have, need]
		"collect":
			return "%s：%d/%d" % [DB.get_item(o["item"]).get("name", "?"), have, need]
		"explore":
			return "%s%s" % [o.get("text", "探索"), "（已完成）" if have >= 1 else ""]
		"talkto":
			return o.get("text", "交谈")
	return ""

func is_quest_complete(qid: String) -> bool:
	if not pd["quests"].has(qid):
		return false
	var q: Dictionary = DB.quests[qid]
	var objs: Array = q.get("obj", [])
	for i in objs.size():
		if objective_progress(qid, i) < objs[i].get("n", 1):
			return false
	return true

func on_kill(mob_id: String, mob_level: int = 0) -> void:
	pd["kills"][mob_id] = pd["kills"].get(mob_id, 0) + 1
	# 副本首领首杀：由对应势力寄来战报信（含赏金）
	Mail.on_boss_kill(mob_id)
	# 声望：显式 rep 优先（副本首领），否则按怪物家族归属；只在本级提升时播报
	var mob: Dictionary = DB.mobs.get(mob_id, {})
	# 风语旧圣堂流程：前三个首领各自点亮一枚火种。旗标独立于任务，重进副本仍保留。
	var ember_flag := String(mob.get("ember_flag", ""))
	if ember_flag != "" and not has_flag(ember_flag):
		if not pd.has("flags"):
			pd["flags"] = {}
		pd["flags"][ember_flag] = true
		msg("获得圣堂火种：%s" % mob.get("ember_name", ember_flag), Color("ffd86a"))
		if zone and zone.has_method("refresh_gates"):
			zone.refresh_gates()
		save_game()
	# 成就：总数 / 精英 / 稀有命名 / 首领 各自的计数器
	Achieve.on_kill(mob_id, mob)
	var reps := {}
	if mob.has("rep"):
		reps = mob["rep"]
	else:
		var fid := Rep.faction_of_fam(str(mob.get("fam", "")))
		if fid != "":
			var lv := mob_level
			if lv <= 0:
				var rg = mob.get("lvl", [1, 1])
				lv = int(rg[0]) if rg is Array and not rg.is_empty() else 1
			reps[fid] = Rep.kill_gain(mob, lv)
	for rf in reps:
		Rep.gain(str(rf), int(reps[rf]), false)
	for qid in pd["quests"]:
		var q: Dictionary = DB.quests[qid]
		var objs: Array = q.get("obj", [])
		for i in objs.size():
			var o: Dictionary = objs[i]
			if o["type"] == "kill" and mob_id in o["mob"]:
				var p: Array = pd["quests"][qid]["p"]
				if p[i] < o["n"]:
					p[i] += 1
					var t := objective_text(qid, i)
					quest_progress.emit(qid, t)
					if is_quest_complete(qid):
						_quest_now_complete(qid)
					quest_log_changed.emit()

func on_explore(poi: String) -> void:
	for qid in pd["quests"]:
		var q: Dictionary = DB.quests[qid]
		var objs: Array = q.get("obj", [])
		for i in objs.size():
			var o: Dictionary = objs[i]
			if o["type"] == "explore" and o["poi"] == poi:
				var p: Array = pd["quests"][qid]["p"]
				if p[i] < 1:
					p[i] = 1
					quest_progress.emit(qid, objective_text(qid, i))
					if is_quest_complete(qid):
						_quest_now_complete(qid)
					quest_log_changed.emit()

func _check_collect_quests(item_id: String) -> void:
	if pd.is_empty():
		return
	for qid in pd["quests"]:
		var q: Dictionary = DB.quests[qid]
		var objs: Array = q.get("obj", [])
		for i in objs.size():
			var o: Dictionary = objs[i]
			if o["type"] == "collect" and o["item"] == item_id:
				var was: bool = pd["quests"][qid].get("done", false)
				quest_progress.emit(qid, objective_text(qid, i))
				var now := is_quest_complete(qid)
				if now and not was:
					_quest_now_complete(qid)
				pd["quests"][qid]["done"] = now
				quest_log_changed.emit()
				npc_markers_dirty.emit()

func _quest_now_complete(qid: String) -> void:
	pd["quests"][qid]["done"] = true
	msg("%s（完成）" % DB.quests[qid]["name"], Color("ffd040"))
	Sfx.play("quest_progress")
	npc_markers_dirty.emit()

## 某物品当前是否对任务有用（用于掉落/采集判定）
func quest_needs_item(item_id: String) -> bool:
	for qid in pd["quests"]:
		var q: Dictionary = DB.quests[qid]
		for o in q.get("obj", []):
			if o["type"] == "collect" and o["item"] == item_id and count_item(item_id) < o["n"]:
				return true
	return false

func turn_in_quest(qid: String, choice_id: String = "") -> bool:
	if not is_quest_complete(qid):
		return false
	var q: Dictionary = DB.quests[qid]
	var need_slots = q.get("items", []).size() + (1 if choice_id != "" else 0)
	if free_bag_slots() < need_slots:
		err("背包空间不足。")
		return false
	for o in q.get("obj", []):
		if o["type"] == "collect":
			remove_item(o["item"], o["n"])
	pd["quests"].erase(qid)
	pd["qdone"][qid] = true
	msg("任务完成：%s" % q["name"], Color("ffd040"))
	var xp := DB.quest_xp(q, pd["level"])
	if pd["level"] >= DB.MAX_LEVEL:
		add_money(xp * 6)
	else:
		give_xp(xp, "quest")
	add_money(DB.quest_money(q))
	for it in q.get("items", []):
		add_item(it[0], it[1])
	if choice_id != "":
		add_item(choice_id, 1)
	# 成就：任务总数与主线任务数
	Achieve.bump("quests")
	if q.get("main", false):
		Achieve.bump("quests_main")
	# 声望：默认按交付 NPC 的阵营，quest["rep"] 可覆盖
	var reps := Rep.quest_factions(q)
	for fid in reps:
		Rep.gain(str(fid), int(reps[fid]))
	Sfx.play("quest_done")
	quest_log_changed.emit()
	npc_markers_dirty.emit()
	return true

## NPC 头顶标记：返回 "!" "?" "?gray" "!gray" 或 ""
func npc_marker(npc_id: String) -> String:
	if pd.is_empty():
		return ""
	for qid in DB.quests_by_turnin.get(npc_id, []):
		if pd["quests"].has(qid) and is_quest_complete(qid):
			return "?"
	for qid in DB.quests_by_giver.get(npc_id, []):
		if can_accept(qid):
			return "!"
	for qid in DB.quests_by_turnin.get(npc_id, []):
		if pd["quests"].has(qid):
			return "?gray"
	for qid in DB.quests_by_giver.get(npc_id, []):
		if quest_low_level_hint(qid):
			return "!gray"
	return ""

## 尝试掉落任务起始物品
func roll_quest_starter(mob_id: String) -> String:
	for qid in DB.quests:
		var q: Dictionary = DB.quests[qid]
		if not q.has("starter_drop"):
			continue
		var sd: Dictionary = q["starter_drop"]
		if not mob_id in sd["mobs"]:
			continue
		if pd["qdone"].has(qid) or pd["quests"].has(qid) or count_item(q["starter_item"]) > 0:
			continue
		if pd["level"] < sd.get("min_level", 1):
			continue
		if rng.randf() < sd["chance"]:
			return q["starter_item"]
	return ""

# ================================================================ 杂项
func has_flag(f: String) -> bool:
	if f == "sanctum_final_open":
		return pd.get("flags", {}).get("sanctum_ember_root", false) and pd.get("flags", {}).get("sanctum_ember_lake", false) and pd.get("flags", {}).get("sanctum_ember_nave", false)
	return pd.get("flags", {}).get(f, false)

func bind_location(zone_id: String, pos: Vector3, name: String) -> void:
	pd["bind"] = {"zone": zone_id, "pos": pos, "name": name}
	msg("你的返程石已绑定到：%s。" % name, Color("80c0ff"))

func discover_fp(fp: String) -> void:
	if not pd["fps"].has(fp):
		pd["fps"][fp] = true
		msg("发现新的飞行点：%s" % DB.flight_paths[fp]["name"], Color("80ff80"))
		Achieve.bump("fps")

func is_typing() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var f := vp.gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

func key_name(action: String) -> String:
	var k: int = keybinds.get(action, 0)
	return OS.get_keycode_string(k) if k != 0 else ""
