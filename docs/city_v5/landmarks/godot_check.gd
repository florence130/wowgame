extends SceneTree
## Use an isolated scratch project containing the exported GLBs and manifest.json.
var results: Array = []
var failed := false
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(300,1,300)
	ground_shape.shape = ground_box
	ground_shape.position.y = -1.1
	ground.add_child(ground_shape)
	root.add_child(ground)
	for info in manifest["assets"]:
		var id: String = info["id"]
		var path := "res://" + id + ".glb"
		if not ResourceLoader.exists(path):
			failed = true
			results.append({"id":id,"missing":true})
			continue
		var packed := load(path) as PackedScene
		var scene := packed.instantiate() as Node3D
		root.add_child(scene)
		await physics_frame
		await physics_frame
		var bodies := scene.find_children("*", "StaticBody3D", true, false)
		var shapes := scene.find_children("*", "CollisionShape3D", true, false)
		var meshes := scene.find_children("*", "MeshInstance3D", true, false)
		var bad_materials := []
		var visual_collider_meshes := []
		for mesh in meshes:
			if "colonly" in String(mesh.name).to_lower(): visual_collider_meshes.append(str(mesh.name))
			for i in mesh.mesh.get_surface_count():
				var mat: Material = mesh.mesh.surface_get_material(i)
				if mat == null or not mat.resource_name.begins_with("K|"): bad_materials.append(str(mesh.name))
		var checks := []
		var space := scene.get_world_3d().direct_space_state
		for entry in info["entries"]:
			var p := Vector3(entry[0], entry[1], entry[2])
			var direction := -1.0 if p.z >= float(info["footprint"][1]) * 0.5 - 0.01 else 1.0
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0,1,-2 * direction),p + Vector3(0,1,2 * direction),1)
			var hit := space.intersect_ray(q)
			var fq := PhysicsRayQueryParameters3D.create(p + Vector3(0,2,2 * direction),p + Vector3(0,-2,2 * direction),1)
			var floor_hit := space.intersect_ray(fq)
			var floor_ok: bool = not floor_hit.is_empty() and absf(floor_hit["position"].y) < 0.03
			var ok: bool = hit.is_empty() and floor_ok
			var actor := CharacterBody3D.new()
			actor.collision_layer = 0
			actor.collision_mask = 1
			actor.floor_snap_length = 0.4
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.35
			capsule.height = 1.8
			var actor_shape := CollisionShape3D.new()
			actor_shape.shape = capsule
			actor_shape.position.y = 0.9
			actor.add_child(actor_shape)
			root.add_child(actor)
			actor.position = Vector3(p.x,-0.59,p.z-7.0*direction)
			var reached := false
			for step in 150:
				await physics_frame
				actor.velocity = Vector3(0,actor.velocity.y-9.8/60.0,direction*6.0)
				actor.move_and_slide()
				if (actor.position.z-p.z)*direction >= 3.0:
					reached = absf(actor.position.y) < 0.06
					break
			var walk_end := [actor.position.x,actor.position.y,actor.position.z]
			actor.queue_free()
			await process_frame
			ok = ok and reached
			checks.append({"entry": entry,"clear":hit.is_empty(),"floor_y":floor_hit["position"].y if not floor_hit.is_empty() else null,"walk_from_street":reached,"walk_end":walk_end,"pass":ok})
			if not ok: failed = true
		var service_checks := []
		for anchor in info.get("service_positions",[]):
			var p := Vector3(anchor[0],anchor[1],anchor[2])
			var fq := PhysicsRayQueryParameters3D.create(p+Vector3(0,2,0),p-Vector3(0,2,0),1)
			var floor_hit := space.intersect_ray(fq)
			var clear_query := PhysicsShapeQueryParameters3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.35
			capsule.height = 1.8
			clear_query.shape = capsule
			clear_query.transform = Transform3D(Basis.IDENTITY,p+Vector3(0,0.93,0))
			clear_query.collision_mask = 1
			var overlap := space.intersect_shape(clear_query)
			var ok: bool = not floor_hit.is_empty() and absf(floor_hit["position"].y-p.y)<0.03 and overlap.is_empty()
			service_checks.append({"position":anchor,"pass":ok,"floor_y":floor_hit["position"].y if not floor_hit.is_empty() else null,"capsule_clear":overlap.is_empty()})
			if not ok: failed=true
		var asset_ok: bool = bodies.size() == 1 and shapes.size() == 1 and bad_materials.is_empty() and visual_collider_meshes.is_empty()
		if not asset_ok: failed = true
		var row := {"id":id,"static_bodies":bodies.size(),"collision_shapes":shapes.size(),"visual_meshes":meshes.size(),"bad_materials":bad_materials,"visible_colonly":visual_collider_meshes,"entry_checks":checks,"service_checks":service_checks,"import_contract_pass":asset_ok}
		results.append(row)
		print(JSON.stringify(row))
		scene.queue_free()
		await process_frame
	var report := {"godot":Engine.get_version_info()["string"],"passed":not failed,"test_context":"isolated imported GLBs, flat street plane at -0.6m, fixed 60 physics ticks; not integrated city navigation","walker":{"height":1.8,"radius":0.35,"speed":6.0,"start_distance":7.0,"inside_distance":3.0},"assets":results}
	var out := FileAccess.open("res://godot_import_report.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"  "))
	quit(1 if failed else 0)
