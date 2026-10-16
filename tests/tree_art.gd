extends Node3D
## Actual Forest renderer, mature-tree scale, matching near/far silhouettes and trunk colliders.
var out := "res://.local/trees_20261007/gallery"
var checks: Array = []
var camera: Camera3D

func check(ok: bool, label: String) -> void:
	checks.append({"pass": ok, "label": label})
	print(("TREE PASS " if ok else "TREE FAIL ") + label)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color("b1cbdc")
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = World.AMB_DAY
	we.environment.ambient_light_energy = 0.6
	we.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = World.SUN_DAY
	sun.light_energy = 1.32
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250
	add_child(sun)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 500
	floor_node.mesh = plane
	floor_node.material_override = U.mat(Color("6e8858"))
	add_child(floor_node)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22
	camera.far = 600
	add_child(camera)
	_run()

func _run() -> void:
	for kind in ["oak", "pine", "birch"]:
		var stage := Node3D.new()
		add_child(stage)
		var count: int = Forest.VEG[kind][1]
		for v in count:
			var f := Forest.new()
			f.kind = kind
			f.color = Color("73a05a") if kind == "birch" else Color("49773f")
			f.position.x = (v - (count-1)*0.5) * 13
			var point_id := 0
			while hash(point_id*31+7) % count != v: point_id += 1
			f.points = PackedVector3Array([Vector3.ZERO])
			f.point_ids = PackedInt32Array([point_id])
			f.scales = PackedFloat32Array([1.0])
			stage.add_child(f)
			await get_tree().physics_frame
			await get_tree().physics_frame
			var name_v := "%s_%d" % [kind, v]
			var near_box := AABB()
			var far_box := AABB()
			for part in Forest._veg_parts(name_v, true): near_box = near_box.merge(part[2] * part[0].get_aabb())
			for part in Forest._veg_parts(name_v): far_box = far_box.merge(part[2] * part[0].get_aabb())
			check(near_box.end.y >= 12.0 and near_box.end.y < 19.0, name_v + " mature height " + str(near_box.end.y))
			check(absf(near_box.end.y-far_box.end.y) < near_box.end.y*0.13, name_v + " near/far height agrees")
			check(far_box.size.x/near_box.size.x > 0.75 and far_box.size.x/near_box.size.x < 1.3, name_v + " near/far crown width agrees")
			var shapes := f.find_children("*", "CollisionShape3D", true, false)
			check(shapes.size() == 1 and shapes[0].shape is CylinderShape3D, name_v + " one trunk collision")
			check(is_equal_approx(shapes[0].shape.radius, f._trunk_radius(0)), name_v + " collider follows asset stem radius")
			var ray := PhysicsRayQueryParameters3D.create(f.global_position + Vector3(5,1,0), f.global_position + Vector3(0,1,0), 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider.get_parent() == f._gen and hit.position.x > f.global_position.x+0.15, name_v + " physical trunk blocks a torso-height approach")
			var drawn_top := 0.0
			for part in Forest._veg_parts(name_v):
				if part[1]: continue
				var arrays: Array = part[0].surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				if indices.is_empty():
					for vertex in vertices: drawn_top = maxf(drawn_top, vertex.y)
				else:
					for index in indices: drawn_top = maxf(drawn_top, vertices[index].y)
			check(drawn_top > near_box.end.y*0.6, name_v + " far trunk retains rendered upper stem")
			var bounds_ok := true
			for mi in f.find_children("*", "MultiMeshInstance3D", true, false):
				var actual: AABB = mi.multimesh.get_instance_transform(0) * mi.multimesh.mesh.get_aabb()
				if not mi.custom_aabb.grow(0.01).encloses(actual): bounds_ok = false
			check(bounds_ok, name_v + " render bounds contain mature meshes")
			for path in f.stream_asset_paths(): check(ResourceLoader.exists(path), name_v + " queued resource exists " + path.get_file())
			var label := Label3D.new()
			label.text = "%s  %.1fm" % [name_v, near_box.end.y]
			label.font_size = 48
			label.pixel_size = 0.012
			label.position = f.position + Vector3(0,0.45,3.2)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			stage.add_child(label)
			var person := MeshInstance3D.new()
			var body := CapsuleMesh.new()
			body.height = 1.8
			body.radius = 0.25
			person.mesh = body
			person.material_override = U.mat(Color("e5d6a1"))
			person.position = f.position + Vector3(2.2,0.9,2.0)
			stage.add_child(person)
		for distance in [50.0, 180.0]:
			var target := Vector3(0, 8.5, 0)
			camera.position = target + Vector3(0,0.12,1).normalized()*distance
			camera.look_at(target)
			await get_tree().create_timer(1.2).timeout
			RenderingServer.force_draw(false)
			get_viewport().get_texture().get_image().save_png(out + "/%s_%s.png" % [kind, "near" if distance < 120 else "far"])
		stage.queue_free()
		await get_tree().process_frame
	FileAccess.open(out + "/checks.json", FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	var failures := checks.filter(func(c): return not c["pass"]).size()
	print("TREE RESULT: ", checks.size(), " checks, ", failures, " failed")
	get_tree().quit(1 if failures else 0)
