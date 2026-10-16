@tool
class_name NpcSpot
extends EditorMarker
## NPC 放置点

@export var npc_id: String = "villager":
	set(v):
		npc_id = v
		if Engine.is_editor_hint() and is_inside_tree():
			_editor_label(npc_id, Color(0.4, 1, 0.5))
@export var wander: float = -1.0
@export var patrol: PackedVector3Array = PackedVector3Array()
@export var seed_v: int = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_label(npc_id, Color(0.4, 1, 0.5))
