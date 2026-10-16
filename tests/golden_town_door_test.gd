extends "res://tests/art_style.gd"

func _find_wing() -> ModelProp:
	for n in Game.world.find_children("*", "ModelProp", true, false):
		var p := n as ModelProp
		if p.asset_scene.ends_with("/home_wing.glb") and p.get_node_or_null("_gen/AutoDoorPivot"):
			return p
	return null

func run() -> void:
	get_tree().auto_accept_quit = false
	get_tree().root.gui_disable_input = true
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	await Game.world._teleport_to(Vector3(435.0, U.ground_height(get_tree(), 435.0, 500.0, 35.0) + 0.5, 500.0))
	for node in Game.world.find_children("*", "ModelProp", true, false):
		var prop := node as ModelProp
		if prop.get_node_or_null("_gen/AutoDoorPivot"):
			_verify_door_fit(prop)
	var wing := _find_wing()
	if wing == null:
		print("AUTO DOOR FAIL: home_wing not streamed")
		get_tree().quit(1)
		return
	var pivot := wing.get_node("_gen/AutoDoorPivot") as Node3D
	var leaf := pivot.get_node_or_null("DoorLeaf_BlenderHinged") as Node3D
	var leaf_dims: Vector3 = leaf.get_meta("door_dimensions_m", Vector3.ZERO) if leaf else Vector3.ZERO
	var leaf_meshes: int = leaf.find_children("*", "MeshInstance3D", true, false).size() if leaf else 0
	var asset_ok: bool = leaf != null and leaf_meshes > 0 and leaf_dims.x > 1.6 and leaf_dims.y > 2.8 and leaf_dims.z > 0.1
	if not asset_ok:
		print("AUTO DOOR FAIL: Blender hinged leaf missing or malformed ", JSON.stringify({"leaf": leaf != null, "meshes": leaf_meshes, "dims": leaf_dims}))
		get_tree().quit(1)
		return
	var front := wing.global_transform.basis * Vector3(0, 0, 1)
	var far := pivot.global_position + front * 7.0
	far.y = U.ground_height(get_tree(), far.x, far.z, 35.0) + 0.5
	await Game.world._teleport_to(far)
	await get_tree().create_timer(0.8).timeout
	var closed_angle := pivot.rotation.y
	var collision := pivot.get_node("DoorLeafCollision").get_child(0) as CollisionShape3D
	check(not collision.disabled, "closed door blocks the doorway")
	await _door_view("home_wing_door_closed", wing, leaf)
	var near := pivot.global_position + front * 1.8
	near.y = U.ground_height(get_tree(), near.x, near.z, 35.0) + 0.5
	await Game.world._teleport_to(near)
	await get_tree().create_timer(1.0).timeout
	var open_angle := pivot.rotation.y
	check(collision.disabled, "open door frees the doorway")
	await _door_view("home_wing_door_auto_open", wing, leaf)
	var inward := open_angle > 0.5
	var latch := pivot.to_global(Vector3(leaf_dims.x, 1.0, 0.0)) - pivot.global_position
	check(latch.dot(front) < -0.5, "door latch actually moves into the room")
	print("AUTO DOOR RESULT ", JSON.stringify({"closed": closed_angle, "open": open_angle, "opened": absf(open_angle - closed_angle) > 0.5, "inward_positive_y": inward, "asset": "door_leaf_hinged.glb", "dimensions": leaf_dims}))
	get_tree().quit(0 if absf(open_angle - closed_angle) > 0.5 and absf(closed_angle) < 0.15 and inward and not checks.any(func(c): return not c["pass"]) else 1)

func _verify_door_fit(prop: ModelProp) -> void:
	var pivot := prop.get_node("_gen/AutoDoorPivot") as Node3D
	var leaf := pivot.get_node("DoorLeaf_BlenderHinged") as Node3D
	var opening: Vector3 = leaf.get_meta("door_frame_opening_m", Vector3.ZERO)
	var centre: Vector3 = leaf.get_meta("door_frame_center_m", Vector3.ZERO)
	var radius := opening.x * 0.5
	var previous_angle := pivot.rotation.y
	pivot.rotation.y = 0.0
	var invalid_vertices := 0
	var inspected := 0
	for node in leaf.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if not str(mesh_node.name).begins_with("DoorBoard_"):
			continue
		var transform_to_house := prop.global_transform.affine_inverse() * mesh_node.global_transform
		for surface in mesh_node.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var relative: Vector3 = transform_to_house * vertex - centre
				var arch_top := opening.y - radius + sqrt(maxf(0.0, radius * radius - relative.x * relative.x))
				if absf(relative.x) > radius + 0.005 or relative.y < -0.005 or relative.y > arch_top + 0.005:
					invalid_vertices += 1
				inspected += 1
	pivot.rotation.y = previous_angle
	check(inspected > 0 and invalid_vertices == 0, "%s door boards fit the actual arched opening (%d vertices)" % [prop.name, inspected])

func _door_view(label: String, prop: ModelProp, leaf: Node3D) -> void:
	var opening: Vector3 = leaf.get_meta("door_frame_opening_m", Vector3.ZERO)
	var centre: Vector3 = leaf.get_meta("door_frame_center_m", Vector3.ZERO)
	check(opening.x > 1.6 and opening.y > 2.8, label + " has measured doorway dimensions")
	var target := prop.to_global(centre + Vector3.UP * opening.y * 0.5)
	var front := prop.global_transform.basis * Vector3.FORWARD * -1.0
	var right := prop.global_transform.basis * Vector3.RIGHT
	if not is_instance_valid(camera):
		camera = Camera3D.new()
		camera.fov = 75.0
		Game.world.add_child(camera)
	camera.global_position = target + front * 2.65 + right * -0.25 + Vector3.UP * 0.15
	camera.look_at(target)
	camera.make_current()
	Game.hud.hide()
	await wait(0.5)
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + "/" + label + ".png")
