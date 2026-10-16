extends SceneTree

var checks: Array = []
var assets: Array = []
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(name: String, ok: bool, detail: Variant = null) -> void:
	checks.append({"name": name, "passed": ok, "detail": detail})
	if not ok:
		failures.append(name)

func nodes(node: Node, out: Array) -> void:
	out.append(node)
	for child in node.get_children():
		nodes(child, out)

func ray(node: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.hit_back_faces = true
	return node.get_world_3d().direct_space_state.intersect_ray(q)

func run() -> void:
	for family in ["architecture", "civil"]:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/city_v5/" + family + "/manifest.json"))
		for info in manifest.assets:
			var id: String = info.id
			var packed: PackedScene = load(info.path)
			check(id + ": loads as PackedScene", packed != null)
			if packed == null:
				continue
			var scene: Node3D = packed.instantiate()
			root.add_child(scene)
			await physics_frame
			await physics_frame
			var descendants: Array = []
			nodes(scene, descendants)
			var shapes := 0
			var meshes := 0
			var unit_scale := true
			var visible_collision_mesh := false
			for item in descendants:
				if item is CollisionShape3D:
					shapes += 1
				if item is MeshInstance3D:
					meshes += 1
					visible_collision_mesh = visible_collision_mesh or "colonly" in item.name
				if item is Node3D:
					unit_scale = unit_scale and item.scale.is_equal_approx(Vector3.ONE)
			check(id + ": exactly one authored collision shape", shapes == 1, shapes)
			check(id + ": appearance meshes imported", meshes > 0, meshes)
			check(id + ": collision source mesh hidden", not visible_collision_mesh)
			check(id + ": all imported transforms preserve unit scale", unit_scale)
			if family == "architecture":
				for ei in range(info.entry.size()):
					var e: Dictionary = info.entry[ei]
					var p := Vector3(e.position[0], 1.2, e.position[2])
					var out := Vector3(e.outward[0], 0, e.outward[2])
					var blocked := not ray(scene, p + out * 3.0, p - out * 3.0).is_empty()
					check(id + ": entry " + str(ei) + " correct access", blocked != bool(e.open), {"open": e.open, "blocked": blocked})
					if bool(e.open):
						var floor_start := p - out * 2.0 + Vector3.UP * 2.0
						var hit := ray(scene, floor_start, floor_start - Vector3.UP * 6.0)
						check(id + ": entry " + str(ei) + " interior finished floor", not hit.is_empty() and absf(hit.position.y) < .02, str(hit.get("position", "no hit")))
			if id == "city_gate_grand":
				for x in [-8.0, 0.0, 8.0]:
					check(id + ": open street passage x=" + str(x), ray(scene, Vector3(x, 2, -12), Vector3(x, 2, 12)).is_empty())
				check(id + ": arch ring has collision", not ray(scene, Vector3(0, 14.8, -12), Vector3(0, 14.8, 12)).is_empty())
				check(id + ": tower has collision", not ray(scene, Vector3(17, 2, -12), Vector3(17, 2, 12)).is_empty())
			if id == "city_bridge_74":
				for z in [-30.0, 0.0, 30.0]:
					var hit := ray(scene, Vector3(0, 3, z), Vector3(0, -3, z))
					check(id + ": continuous deck z=" + str(z), not hit.is_empty() and absf(hit.position.y) < .02, str(hit.get("position", "no hit")))
				check(id + ": open waterway under central arch", ray(scene, Vector3(-20, -4, 0), Vector3(20, -4, 0)).is_empty())
				check(id + ": pier has collision", not ray(scene, Vector3(-20, -4, 12), Vector3(20, -4, 12)).is_empty())
				var sidewalk := ray(scene, Vector3(9.5, 3, 0), Vector3(9.5, -3, 0))
				check(id + ": raised footway supports feet", not sidewalk.is_empty() and absf(sidewalk.position.y - .2) < .02, str(sidewalk.get("position", "no hit")))
			if id == "city_wall_32":
				var hit := ray(scene, Vector3(0, 20, 0), Vector3(0, 10, 0))
				check(id + ": wall-walk finished floor", not hit.is_empty() and absf(hit.position.y - 16.2) < .02, str(hit.get("position", "no hit")))
			if id in ["harbor_passenger_65", "harbor_sailing_52"]:
				var z := -28.0 if id == "harbor_passenger_65" else -6.0
				var hit := ray(scene, Vector3(0, 7, z), Vector3(0, 0, z))
				check(id + ": finished main deck supports feet", not hit.is_empty() and absf(hit.position.y - float(info.main_deck_y)) < .02, str(hit.get("position", "no hit")))
			assets.append({"id": id, "meshes": meshes, "collision_shapes": shapes, "unit_scale": unit_scale})
			scene.queue_free()
			await physics_frame
			await physics_frame
	var report := {"assets": assets, "checks": checks, "check_count": checks.size(), "failure_count": failures.size(), "failures": failures, "mode": "isolated imported asset physics; no game scene, no save IO"}
	var f := FileAccess.open("res://docs/city_v5/civil/godot_asset_verification.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("CITY_V5_ASSET_CHECKS ", checks.size(), " FAILURES ", failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
