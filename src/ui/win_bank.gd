class_name BankWindow
extends UIWindow
## 银行：90 格。与银行职员交谈打开；拖放或右键在背包/银行之间转移物品

var service_npc: NPC = null
var slots: Array[Slot] = []
var info: RichTextLabel

func _init() -> void:
	_init_window("晴岚港银行", Vector2(540, 600), "bank")
	var tip := UITheme.label("右键背包物品存入，右键银行物品取出；也可以直接拖放。", 14, UITheme.TEXT_DIM)
	body.add_child(tip)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)
	for i in Game.BANK_SIZE:
		var s := Slot.new()
		s.kind = "bank"
		s.index = i
		s.custom_minimum_size = Vector2(48, 48)
		s.corner = 8
		s.right_clicked.connect(func(sl): Game.bank_withdraw(sl.index))
		grid.add_child(s)
		slots.append(s)
	var bottom := HBoxContainer.new()
	body.add_child(bottom)
	bottom.add_child(UITheme.button("整理", _sort))
	bottom.add_child(UITheme.button("全部存入材料", _deposit_mats))
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(info)
	Game.inventory_changed.connect(func(): if visible: refresh())

func _process(_d: float) -> void:
	if visible and service_npc != null:
		if not is_instance_valid(service_npc) or not service_npc.is_inside_tree() or Game.player == null or not Game.player.is_inside_tree() \
				or Game.player.global_position.distance_to(service_npc.global_position) > 9.0:
			close_window()

func refresh() -> void:
	if Game.pd.is_empty():
		return
	var bank: Array = Game.pd["bank"]
	var used := 0
	for i in Game.BANK_SIZE:
		var st = bank[i]
		if st == null:
			slots[i].set_item("")
		else:
			slots[i].set_item(st["id"], st["n"])
			used += 1
	info.text = "[right][color=#a8adb8]%d/%d[/color][/right]" % [used, Game.BANK_SIZE]

func _sort() -> void:
	var items := []
	for st in Game.pd["bank"]:
		if st != null:
			items.append(st)
	items.sort_custom(func(a, b):
		var ia := DB.get_item(a["id"])
		var ib := DB.get_item(b["id"])
		if ia.get("type", "") != ib.get("type", ""):
			return str(ia.get("type", "")) < str(ib.get("type", ""))
		return str(ia.get("name", "")) < str(ib.get("name", "")))
	var nb := []
	nb.resize(Game.BANK_SIZE)
	for i in items.size():
		nb[i] = items[i]
	Game.pd["bank"] = nb
	Game.inventory_changed.emit()

## 一键存入所有商业材料
func _deposit_mats() -> void:
	var n := 0
	for i in Game.BAG_SIZE:
		var st = Game.pd["bag"][i]
		if st != null and DB.get_item(st["id"]).get("type", "") == "trade":
			if Game.bank_deposit(i):
				n += 1
	Game.msg("已存入 %d 组材料。" % n, Color("ffe9a8"))
