@tool
class_name POI
extends EditorMarker
## 兴趣点：子区域名称、探索经验、任务探索目标、休息区（旅店）

@export var poi_id: String = ""
@export var title: String = "":
	set(v):
		title = v
		if Engine.is_editor_hint() and is_inside_tree():
			_editor_label("◎ " + title, Color(1, 0.9, 0.3))
@export var radius: float = 40.0
@export var priority: int = 0
@export var explore_xp: bool = true
@export var rest_area: bool = false
@export var music: String = ""

func _ready() -> void:
	add_to_group("poi")
	if Engine.is_editor_hint():
		_editor_label("◎ " + title, Color(1, 0.9, 0.3))
