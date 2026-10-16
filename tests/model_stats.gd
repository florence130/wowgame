extends Node
func _ready() -> void:
	for name in ["manor_0","manor_1","manor_2","manor_3","manor_4","manor_5","corner_0"]:
		var root := (load("res://assets/models/" + name + ".glb") as PackedScene).instantiate()
		var vertices := 0
		var triangles := 0
		var surfaces := 0
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = mi.mesh
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				vertices += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				triangles += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
				surfaces += 1
		print("MODEL_STATS ", name, " vertices=", vertices, " triangles=", triangles, " surfaces=", surfaces)
		root.free()
	get_tree().quit()
