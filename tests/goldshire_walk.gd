extends SceneTree
## Real physics traversal; capsule/angle/snap match src/actors/player.gd and unit.gd.
const KIT = preload("res://src/world/goldshire_kit.gd")
var world: Node3D
var actor: CharacterBody3D
var camera: Camera3D
var failures: Array[String] = []
var results: Array = []
var screenshots := false
var out := "res://.shots/goldshire"
var selected_ids := PackedStringArray()
var route_label: Label

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String, detail: Variant = null) -> void:
	results.append({"check":label,"passed":ok,"detail":detail})
	if not ok:
		failures.append(label)
	print("PASS " if ok else "FAIL ", label, " ", detail)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "shots": screenshots = true
		if arg.begins_with("ids="): selected_ids = arg.substr(4).split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	world = Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c4dfef")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c4dfef")
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(100,0.2,100)
	shape.position.y = -0.1
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(100,0.2,100)
	mesh.position.y = -0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("b3aca2")
	mesh.material_override = mat
	ground.add_child(mesh)
	world.add_child(ground)
	actor = CharacterBody3D.new()
	actor.collision_layer = 2
	actor.collision_mask = 1
	actor.floor_snap_length = 0.6
	actor.floor_max_angle = deg_to_rad(52)
	var cap := CollisionShape3D.new()
	cap.shape = CapsuleShape3D.new()
	cap.shape.radius = 0.4
	cap.shape.height = 1.7
	cap.position.y = 0.85
	actor.add_child(cap)
	world.add_child(actor)
	camera = Camera3D.new()
	camera.fov = 68
	world.add_child(camera)
	camera.current = true
	var canvas := CanvasLayer.new()
	world.add_child(canvas)
	route_label = Label.new()
	route_label.position = Vector2(18,18)
	route_label.add_theme_font_size_override("font_size",22)
	route_label.add_theme_color_override("font_color",Color("f4eee2"))
	route_label.add_theme_color_override("font_shadow_color",Color("3a2616"))
	route_label.add_theme_constant_override("shadow_offset_x",2)
	route_label.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(route_label)
	var ids := ["smithy","general_store","tailor","tavern","guard_tower"]
	if not selected_ids.is_empty():ids = Array(selected_ids)
	for id in ids:
		var building: Node3D = KIT.create(id)
		check(building != null, id + " load")
		if building == null: continue
		world.add_child(building)
		await physics_frame
		await physics_frame
		var depth := 10.0 if id == "tavern" else 8.0
		var start := Vector3(0,0.06,-depth/2-4)
		actor.position = start
		await physics_frame
		if screenshots:
			camera.position = Vector3(15,12,-19)
			camera.look_at(Vector3(0,4,0))
			await shot(id + "_exterior")
		await walk_to(Vector3(0,0,0), id + " enter")
		check(actor.position.y > 0.31 and actor.position.y < 0.5, id + " standing on interior floor", actor.position)
		if screenshots:
			camera.position = Vector3(0,1.95,-depth/2+0.6)
			camera.look_at(Vector3(-0.4,1.7,depth/2-1))
			await shot(id + "_interior")
		# A deliberately closed wall must still block the capsule.
		await walk_to(Vector3(6,0,0), id + " closed wall", false)
		check(actor.position.x < 4.1, id + " wall blocks")
		await walk_to(Vector3(0,0,0), id + " return to aisle")
		if id in ["tailor","tavern","general_store"]:
			var wing_x := -5.0 if id != "tavern" else -6.0
			await walk_to(Vector3(wing_x,0,0), id + " connected side room")
			await walk_to(Vector3(0,0,0), id + " return from side room")
		if id in ["tailor","tavern","guard_tower"]:
			var sx := 2.05 if id == "tailor" else 3.05
			await walk_to(Vector3(sx,0,-3.30), id + " approach stairs")
			await walk_to(Vector3(sx,3.76,3.35), id + " ascend stairs")
			check(actor.position.y > 3.5, id + " upper floor reached", actor.position)
			if id == "guard_tower":
				await walk_to(Vector3(-3.05,3.76,3.35), "guard cross upper landing")
				await walk_to(Vector3(-3.05,7.16,-3.35), "guard reach observation gallery")
				check(actor.position.y > 6.9, "guard gallery height", actor.position)
				if screenshots:
					camera.position = actor.position + Vector3(0,1.5,0)
					camera.look_at(Vector3(2,8,2))
					await shot("guard_tower_gallery")
				await walk_to(Vector3(-3.05,3.76,3.35), "guard descend gallery")
				await walk_to(Vector3(3.05,3.76,3.35), "guard return upper landing")
			if screenshots:
				camera.position = Vector3(sx,5.3,3.35)
				camera.look_at(Vector3(-1,4.7,-2))
				await shot(id + "_upper")
			await walk_to(Vector3(sx,0,-3.30), id + " descend stairs")
			await walk_to(Vector3(0,0,-3.30), id + " leave stair")
		await walk_to(start, id + " exit")
		building.queue_free()
		await process_frame
	for id in KIT.HOMES:
		if not selected_ids.is_empty():break
		var home: Node3D = KIT.create(id)
		check(home != null, id + " load")
		if home:home.free()
	FileAccess.open(out + "/walk_report.json", FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"capsule_radius":0.4,"capsule_height":1.7,"checks":results,"failures":failures}, "  "))
	print("GOLDSHIRE_RESULT ", failures.size(), " failures / ", results.size(), " checks")
	quit(0 if failures.is_empty() else 1)

func walk_to(target: Vector3, label: String, must_reach := true) -> void:
	route_label.text = "GOLDENEAR / " + label + "\nPlayer capsule 0.4m x 1.7m / real collision"
	var reached := false
	var last := actor.position
	var stalled := 0
	for frame in range(360):
		await physics_frame
		var delta := Vector3(target.x-actor.position.x,0,target.z-actor.position.z)
		if delta.length() < 0.13:
			reached = true
			break
		actor.velocity.x = delta.normalized().x * 3.5
		actor.velocity.z = delta.normalized().z * 3.5
		actor.velocity.y = -2.0 if actor.is_on_floor() else actor.velocity.y - 20.0/60.0
		actor.move_and_slide()
		if screenshots:
			camera.position = actor.position + Vector3(0,1.5,0)
			camera.look_at(camera.position + delta.normalized())
		if actor.position.distance_to(last) < 0.001:
			stalled += 1
		else: stalled = 0
		last = actor.position
		if stalled > 25:break
	actor.velocity = Vector3.ZERO
	if must_reach:check(reached,label,{"position":actor.position,"target":target})

func shot(label: String) -> void:
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/" + label + ".png"))
