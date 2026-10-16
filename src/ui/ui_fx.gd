class_name UIFx
extends Node
## 界面动效：所有按钮的悬停/按下反馈、窗口开合动画、右侧拾取/任务提示（Toast）
## 由 HUD 创建一个实例；按钮动效通过 SceneTree.node_added 自动挂到所有 BaseButton 上

static var inst: UIFx
var toast_box: VBoxContainer

func _init() -> void:
	inst = self

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_hook_existing(get_tree().root)

func _hook_existing(n: Node) -> void:
	for c in n.get_children():
		_on_node_added(c)
		_hook_existing(c)

func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("fx"):
		n.set_meta("fx", true)
		var b: BaseButton = n
		b.mouse_entered.connect(func(): _hover(b, true))
		b.mouse_exited.connect(func(): _hover(b, false))
		b.button_down.connect(func(): _press(b, true))
		b.button_up.connect(func(): _press(b, false))

func _tw(c: Control) -> Tween:
	if c.has_meta("fx_tw"):
		var old: Tween = c.get_meta("fx_tw")
		if old and old.is_valid():
			old.kill()
	var t := c.create_tween()
	c.set_meta("fx_tw", t)
	return t

func _hover(b: BaseButton, on: bool) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree() or b.disabled:
		return
	b.pivot_offset = b.size * 0.5
	var t := _tw(b)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(b, "scale", Vector2.ONE * (1.035 if on else 1.0), 0.12)
	t.parallel().tween_property(b, "modulate", Color(1.12, 1.1, 1.04) if on else Color.WHITE, 0.12)

func _press(b: BaseButton, down: bool) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree() or b.disabled:
		return
	b.pivot_offset = b.size * 0.5
	var t := _tw(b)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", Vector2.ONE * (0.95 if down else 1.035), 0.08 if down else 0.16)

# ---------------------------------------------------------------- 窗口
static func window_open(w: Control) -> void:
	w.pivot_offset = w.size * 0.5
	w.modulate.a = 0.0
	w.scale = Vector2.ONE * 0.94
	var t := w.create_tween()
	w.set_meta("win_tw", t)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(w, "scale", Vector2.ONE, 0.2)
	t.parallel().tween_property(w, "modulate:a", 1.0, 0.14)

static func window_close(w: Control) -> void:
	if w.has_meta("win_tw"):
		var old: Tween = w.get_meta("win_tw")
		if old and old.is_valid():
			old.kill()
	# 逻辑上立即关闭（visible=false），用一个快照替身播放淡出，避免"关闭中仍算打开"
	var parent := w.get_parent()
	if parent == null or not w.is_inside_tree() or w.size.x < 2.0:
		return
	var ghost := TextureRect.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = w.position
	ghost.size = w.size
	ghost.pivot_offset = w.size * 0.5
	var vp := w.get_viewport()
	var img := vp.get_texture().get_image()
	var r := Rect2i(Vector2i(w.global_position * vp.get_final_transform().get_scale()), Vector2i(w.size * vp.get_final_transform().get_scale()))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x < 2 or r.size.y < 2:
		return
	ghost.texture = ImageTexture.create_from_image(img.get_region(r))
	ghost.stretch_mode = TextureRect.STRETCH_SCALE
	parent.add_child(ghost)
	var t := ghost.create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(ghost, "scale", Vector2.ONE * 0.95, 0.12)
	t.parallel().tween_property(ghost, "modulate:a", 0.0, 0.12)
	t.tween_callback(ghost.queue_free)

# ---------------------------------------------------------------- Toast
func build_toasts(parent: Control) -> void:
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	toast_box.offset_left = -330
	toast_box.offset_right = -20
	toast_box.offset_top = -40
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(toast_box)

## 右侧滑入提示：可选物品图标
func toast(text: String, col: Color = UITheme.TEXT, item_id: String = "", count: int = 0) -> void:
	if toast_box == null:
		return
	if toast_box.get_child_count() >= 6:
		toast_box.get_child(0).queue_free()
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UITheme.sb(Color(0.06, 0.08, 0.13, 0.9), 12, 1, Color(col, 0.45), 8)
	sb.shadow_size = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	if item_id != "":
		var iv := IconView.new()
		var it := DB.get_item(item_id)
		iv.setup(it.get("icon", "bag"), it.get("color", Color.WHITE), it.get("q", 1), count, str(it.get("name", "?")).substr(0, 1))
		iv.custom_minimum_size = Vector2(36, 36)
		iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(iv)
	var l := UITheme.label(text, 15, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(240, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	toast_box.add_child(p)
	p.modulate.a = 0.0
	p.position.x = 60
	var t := p.create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(p, "modulate:a", 1.0, 0.18)
	t.tween_interval(3.2)
	t.tween_property(p, "modulate:a", 0.0, 0.5)
	t.tween_callback(p.queue_free)

## 中央标题弹出
static func pop(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * 0.6
	var t := c.create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, 0.35)

## 错误提示轻抖
static func shake(c: Control) -> void:
	var x0 := c.position.x
	var t := c.create_tween()
	for i in 4:
		t.tween_property(c, "position:x", x0 + (6.0 if i % 2 == 0 else -6.0) * (1.0 - i * 0.2), 0.035)
	t.tween_property(c, "position:x", x0, 0.04)
