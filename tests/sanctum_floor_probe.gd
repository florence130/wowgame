extends Node3D

func _ready() -> void:
	Game.slot_index = -1
	var zone: Node = load("res://scenes/zones/windwhisper_sanctum.tscn").instantiate()
	var shell: Node3D = zone.get_node("Buildings/SanctumShell")
	shell.get_parent().remove_child(shell)
	add_child(shell)
	zone.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	for p in [Vector3(321.429,6,136.215),Vector3(320.737,6,135.778),Vector3(316.783,6,135.905),Vector3(43.98,16.38,113.30)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.7, p - Vector3.UP * 2.0, 1))
		print("FLOOR PROBE ",p," ",hit)
	get_tree().quit()
