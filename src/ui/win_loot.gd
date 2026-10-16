class_name LootWindow
extends UIWindow
## 拾取窗口

var source: Mob = null
var list: VBoxContainer

func _init() -> void:
	_init_window("拾取", Vector2(300, 120), "loot")
	list = VBoxContainer.new()
	body.add_child(list)

func show_loot(m: Mob) -> void:
	source = m
	open_window()
	_render()

func _process(_d: float) -> void:
	if visible and (source == null or not is_instance_valid(source) or not source.is_inside_tree() or Game.player == null or not Game.player.is_inside_tree() \
			or Game.player.global_position.distance_to(source.global_position) > 8.0):
		close_window()

func _render() -> void:
	for c in list.get_children():
		c.queue_free()
	if source == null or not is_instance_valid(source):
		return
	title_label.text = source.unit_name
	var l: Dictionary = source.loot
	if l.get("money", 0) > 0:
		var b := Button.new()
		b.text = "  💰  " + U.money_text(l["money"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(270, 44)
		b.pressed.connect(func(): source.take_loot_money(); _after())
		list.add_child(b)
	var items: Array = l.get("items", [])
	for i in items.size():
		var e: Array = items[i]
		var it := DB.get_item(e[0])
		var h := HBoxContainer.new()
		var s := Slot.new()
		s.kind = "loot"
		s.set_item(e[0], e[1])
		s.custom_minimum_size = Vector2(44, 44)
		var idx := i
		s.left_clicked.connect(func(_x): source.take_loot_item(idx); _after())
		s.right_clicked.connect(func(_x): source.take_loot_item(idx); _after())
		h.add_child(s)
		var nl := UITheme.label(it.get("name", "?"), 15, U.quality_color(it.get("q", 1)))
		nl.custom_minimum_size.x = 210
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(nl)
		list.add_child(h)
	list.add_child(UITheme.button("全部拾取", func(): source.loot_all(); _after()))
	size = Vector2.ZERO

func _after() -> void:
	if source == null or not is_instance_valid(source) or not source.has_loot():
		close_window()
	else:
		_render()
