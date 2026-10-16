class_name Slot
extends IconView
## 通用格子：背包/装备/动作条/技能书/商人/拾取/奖励。支持拖放与鼠标提示。

signal left_clicked(slot: Slot)
signal right_clicked(slot: Slot)

var kind := "bag"
var index := -1
var slot_name := ""
var item_id := ""
var spell_id := ""
var extra := {}
var empty_hint := ""

func _init() -> void:
	super._init()
	tooltip_text = " "
	custom_minimum_size = Vector2(52, 52)
	mouse_entered.connect(func(): _fx("hover_a", 1.0, 0.12))
	mouse_exited.connect(func(): _fx("hover_a", 0.0, 0.2))

var _fx_tw: Tween

func _fx(prop: String, to: float, dur: float) -> void:
	if not is_inside_tree():
		return
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, prop, to, dur)

## 使用时闪一下 + 轻微缩放回弹
func flash() -> void:
	if not is_inside_tree() or flash_a > 0.5:
		return
	flash_a = 1.0
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 0.9
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "flash_a", 0.0, 0.3)
	t.parallel().tween_property(self, "scale", Vector2.ONE, 0.25)

func set_item(id: String, n: int = 0) -> void:
	item_id = id
	spell_id = ""
	if id == "":
		icon = ""
		count = 0
		quality = -1
		return
	var it := DB.get_item(id)
	icon = it.get("icon", "bag")
	color = it.get("color", Color.WHITE)
	quality = it.get("q", 1)
	count = n
	fallback = str(it.get("name", "?")).substr(0, 1)
	dim = not Game.pd.is_empty() and it.get("equip", "") != "" and not Game.can_equip(it, false)

func set_spell(sid: String) -> void:
	spell_id = sid
	item_id = ""
	if sid == "":
		icon = ""
		return
	var sp: Dictionary = DB.spells.get(sid, {})
	icon = IconArt.spell_key(sid, sp.get("icon", "arcane"))
	color = sp.get("color", Color("8080c0"))
	quality = -1
	count = 0
	fallback = str(sp.get("name", "?")).substr(0, 1)

func _make_custom_tooltip(_for_text: String) -> Object:
	if item_id != "":
		var ex := extra.duplicate()
		ex["n"] = count if count > 0 else 1
		if kind == "equip":
			ex["equipped"] = true
		return Tips.item(item_id, ex)
	if spell_id != "":
		return Tips.spell(spell_id)
	if empty_hint != "":
		return Tips.text(empty_hint)
	return null

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			left_clicked.emit(self)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			right_clicked.emit(self)
			accept_event()

func _get_drag_data(_pos: Vector2) -> Variant:
	if kind in ["vendor", "loot", "reward", "info", "trainer", "buyback"]:
		return null
	if item_id == "" and spell_id == "":
		return null
	var prev := IconView.new()
	prev.setup(icon, color, quality, count, fallback)
	prev.size = Vector2(48, 48)
	prev.position = Vector2(-24, -24)
	var c := Control.new()
	c.add_child(prev)
	set_drag_preview(c)
	return {"from": kind, "index": index, "slot": slot_name, "item": item_id, "spell": spell_id, "src": self}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not data.has("from"):
		return false
	match kind:
		"bag", "bank":
			return data["from"] in ["bag", "equip", "bank"]
		"equip":
			if data["from"] != "bag" or data["item"] == "":
				return false
			var it := DB.get_item(data["item"])
			var e: String = it.get("equip", "")
			return e != "" and (e == slot_name or (e == "finger" and slot_name.begins_with("finger")) or (e == "trinket" and slot_name.begins_with("trinket")) or (e == "main" and slot_name == "off" and Game.pd["class"] == "rogue" and it.get("slot", "") == "one"))
		"bar":
			return data["from"] in ["bar", "spell"] or (data["from"] == "bag" and DB.get_item(data["item"]).has("use"))
	return false

func _drop_data(_pos: Vector2, data: Variant) -> void:
	var from: String = data["from"]
	match kind:
		"bag":
			if from == "bag":
				Game.swap_bag(data["index"], index)
			elif from == "equip":
				if Game.pd["bag"][index] == null:
					var id = Game.pd["equip"].get(data["slot"])
					if id != null:
						Game.pd["equip"].erase(data["slot"])
						Game.pd["bag"][index] = {"id": id, "n": 1}
						Game._after_equip_change()
				else:
					Game.unequip(data["slot"])
			elif from == "bank":
				Game.hud.bank_to_bag(data["index"], index)
		"bank":
			if from == "bag":
				Game.hud.bag_to_bank(data["index"], index)
			elif from == "bank":
				var b: Array = Game.pd["bank"]
				var t = b[index]
				b[index] = b[data["index"]]
				b[data["index"]] = t
				Game.inventory_changed.emit()
		"equip":
			Game.equip_from_bag(data["index"], slot_name == "off")
		"bar":
			var bars: Array = Game.pd["bars"]
			if from == "bar":
				var t2 = bars[index]
				bars[index] = bars[data["index"]]
				bars[data["index"]] = t2
			elif from == "spell":
				bars[index] = {"t": "spell", "id": data["spell"]}
			elif from == "bag":
				bars[index] = {"t": "item", "id": data["item"]}
			Game.bars_changed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and kind == "bar":
		if not get_viewport().gui_is_drag_successful():
			var d = get_viewport().gui_get_drag_data()
			if d is Dictionary and d.get("src") == self:
				pass
