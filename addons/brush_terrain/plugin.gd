@tool
extends EditorPlugin
## 地形笔刷编辑器插件

const MODES := ["抬升", "降低", "平滑", "压平", "涂刷"]

var terrain: BrushTerrain
var dock: VBoxContainer
var mode := 0
var radius := 12.0
var strength := 0.6
var layer := 1
var painting := false
var flatten_h := 0.0
var _undo_heights: PackedFloat32Array
var _undo_a: Image
var _undo_b: Image
var _mode_buttons: Array[Button] = []
var _layer_opt: OptionButton
var _info: Label

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "地形笔刷"
	var title := Label.new()
	title.text = "地形笔刷（选中 BrushTerrain 节点）"
	dock.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	dock.add_child(grid)
	var group := ButtonGroup.new()
	for i in MODES.size():
		var b := Button.new()
		b.text = MODES[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == 0
		b.pressed.connect(func(): mode = i)
		grid.add_child(b)
		_mode_buttons.append(b)
	dock.add_child(_make_slider("半径", 1.0, 80.0, radius, func(v): radius = v))
	dock.add_child(_make_slider("强度", 0.02, 3.0, strength, func(v): strength = v))
	var lh := HBoxContainer.new()
	var ll := Label.new()
	ll.text = "涂刷层"
	lh.add_child(ll)
	_layer_opt = OptionButton.new()
	for i in TerrainData.LAYER_NAMES.size():
		_layer_opt.add_item(TerrainData.LAYER_NAMES[i], i)
	_layer_opt.select(1)
	_layer_opt.item_selected.connect(func(i): layer = i)
	lh.add_child(_layer_opt)
	dock.add_child(lh)
	var save := Button.new()
	save.text = "保存地形数据"
	save.pressed.connect(_save_terrain)
	dock.add_child(save)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.text = "左键拖动绘制；Shift+左键=降低；Ctrl+左键=压平(取起点高度)；Ctrl+Z 撤销一笔。"
	dock.add_child(_info)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree() -> void:
	if terrain and is_instance_valid(terrain):
		terrain.set_brush_preview(Vector3(0, -99999, 0), 0.0)
	remove_control_from_docks(dock)
	dock.queue_free()

func _make_slider(label: String, mn: float, mx: float, val: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 40
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.01
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Label.new()
	v.text = "%.2f" % val
	s.value_changed.connect(func(x): cb.call(x); v.text = "%.2f" % x)
	h.add_child(s)
	h.add_child(v)
	return h

func _handles(object: Object) -> bool:
	return object is BrushTerrain

func _edit(object: Object) -> void:
	if terrain and is_instance_valid(terrain) and terrain != object:
		terrain.set_brush_preview(Vector3(0, -99999, 0), 0.0)
	terrain = object as BrushTerrain

func _make_visible(visible: bool) -> void:
	if dock:
		dock.visible = true
	if not visible and terrain and is_instance_valid(terrain):
		terrain.set_brush_preview(Vector3(0, -99999, 0), 0.0)

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if terrain == null or not is_instance_valid(terrain) or terrain.data == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventKey and event.pressed and event.keycode == KEY_Z and event.ctrl_pressed:
		if _undo_heights.size() > 0:
			_restore_undo()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouse:
		var hit = terrain.ray_hit(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
		if hit != null:
			terrain.set_brush_preview(hit, radius)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and hit != null:
				painting = true
				_store_undo()
				flatten_h = hit.y
				_stroke(hit, event)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif not event.pressed and painting:
				painting = false
				terrain.commit_collision()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
		if event is InputEventMouseMotion and painting and hit != null:
			_stroke(hit, event)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _stroke(hit: Vector3, ev: InputEventMouse) -> void:
	var m := mode
	if m == 0 and ev.shift_pressed:
		m = 1
	if ev.ctrl_pressed and m != 4:
		m = 3
	terrain.apply_brush(m, hit, radius, strength, flatten_h, layer)

func _store_undo() -> void:
	_undo_heights = terrain.data.heights.duplicate()
	_undo_a = terrain.data.control_a.duplicate()
	_undo_b = terrain.data.control_b.duplicate()

func _restore_undo() -> void:
	terrain.data.heights = _undo_heights
	terrain.data.control_a = _undo_a
	terrain.data.control_b = _undo_b
	_undo_heights = PackedFloat32Array()
	terrain.rebuild()

func _save_terrain() -> void:
	if terrain and terrain.data and terrain.data.resource_path != "":
		var err := ResourceSaver.save(terrain.data, terrain.data.resource_path)
		_info.text = "已保存：%s (%s)" % [terrain.data.resource_path, error_string(err)]

func _save_external_data() -> void:
	if terrain and is_instance_valid(terrain) and terrain.data and terrain.data.resource_path != "":
		ResourceSaver.save(terrain.data, terrain.data.resource_path)
