class_name CityWard
extends Node3D
## City access applies to sea/rail approaches as well as the three gates.
## Coarse boundary colliders are always resident; they are removed on the existing city_access flag.
@export var points := PackedVector2Array()
@export var flag := "city_access"

func _ready() -> void:
	add_to_group("gates")
	refresh_gate()

func refresh_gate() -> void:
	for child in get_children():child.queue_free()
	if Engine.is_editor_hint() or Game.has_flag(flag):return
	for i in points.size():
		var a:=points[i];var b:=points[(i+1)%points.size()];var mid:=(a+b)*.5
		var body:=StaticBody3D.new();body.name="Barrier_CityAccess_%d"%i
		body.position=Vector3(mid.x,55,mid.y);body.rotation.y=atan2(-(b.y-a.y),b.x-a.x)
		var shape:=BoxShape3D.new();shape.size=Vector3(a.distance_to(b)+.6,130,1.5)
		var cs:=CollisionShape3D.new();cs.shape=shape;body.add_child(cs);add_child(body)
