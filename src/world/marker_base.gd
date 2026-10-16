@tool
class_name EditorMarker
extends Marker3D
## 带编辑器标签的标记点基类（运行时不显示）

var _elabel: Label3D

func _editor_label(text: String, col: Color) -> void:
	if not Engine.is_editor_hint():
		return
	if _elabel == null or not is_instance_valid(_elabel):
		_elabel = Label3D.new()
		_elabel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_elabel.pixel_size = 0.02
		_elabel.font_size = 48
		_elabel.outline_size = 12
		_elabel.position = Vector3(0, 3, 0)
		_elabel.no_depth_test = true
		add_child(_elabel)
	_elabel.text = text
	_elabel.modulate = col
