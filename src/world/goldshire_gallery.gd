extends Node3D
const KIT = preload("res://src/world/goldshire_kit.gd")
const IDS := ["smithy","general_store","tailor","tavern","guard_tower","home_cottage","home_long","home_loft","home_porch","home_wing","home_broad"]
const NAMES := ["炉石铁匠铺","麦袋杂货店","针线裁缝铺","金穗酒馆与旅店","金穗治安塔","茅草小屋","长屋","阁楼住宅","门廊住宅","侧院工棚住宅","四坡石基住宅"]
var active := 0
var building: Node3D
var player: CharacterBody3D
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var title: Label
var yaw := 0.0
var pitch := -0.18
var overview := true

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c4dfef")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c4dfef")
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-35,0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = Vector3(70,.2,70)
	cs.position.y = -.1
	ground.add_child(cs)
	var plane := MeshInstance3D.new()
	plane.mesh = BoxMesh.new()
	plane.mesh.size = Vector3(70,.2,70)
	plane.position.y = -.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8e877a")
	plane.material_override = mat
	ground.add_child(plane)
	add_child(ground)
	player = CharacterBody3D.new()
	player.collision_layer = 2
	player.collision_mask = 1
	player.floor_snap_length = .6
	player.floor_max_angle = deg_to_rad(52)
	var body_shape := CollisionShape3D.new()
	body_shape.shape = CapsuleShape3D.new()
	body_shape.shape.radius = .4
	body_shape.shape.height = 1.7
	body_shape.position.y = .85
	player.add_child(body_shape)
	var avatar := MeshInstance3D.new()
	avatar.mesh = CapsuleMesh.new()
	avatar.mesh.radius = .32
	avatar.mesh.height = 1.7
	avatar.position.y = .85
	var avatar_mat := StandardMaterial3D.new()
	avatar_mat.albedo_color = Color("3f6a4a")
	avatar.material_override = avatar_mat
	player.add_child(avatar)
	add_child(player)
	pivot = Node3D.new()
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 5
	arm.collision_mask = 1
	arm.margin = .15
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 65
	arm.add_child(camera)
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	title = Label.new()
	title.position = Vector2(24,20)
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_color",Color("f4eee2"))
	title.add_theme_color_override("font_shadow_color",Color("3a2616"))
	title.add_theme_constant_override("shadow_offset_x",2)
	title.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(title)
	show_asset(0)

func show_asset(index: int) -> void:
	active = posmod(index,IDS.size())
	if building:building.queue_free()
	building = KIT.create(IDS[active])
	add_child(building)
	reset_position()
	title.text = "金穗村 · %s  [%d / %d]\nTab 下一栋 · Shift+Tab 上一栋 · R 总览/行走\nWASD 移动 · 右键拖动视角 · 空格跳跃 · F 回到入口" % [NAMES[active],active+1,IDS.size()]

func reset_position() -> void:
	player.position = Vector3(0,.1,-11)
	player.velocity = Vector3.ZERO
	yaw = PI
	pitch = -.18

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:show_asset(active + (-1 if event.shift_pressed else 1))
		if event.keycode == KEY_F:reset_position()
		if event.keycode == KEY_R:overview = not overview
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * .006
		pitch = clampf(pitch-event.relative.y*.004,-1.1,.35)

func _physics_process(delta: float) -> void:
	if overview:
		pivot.position = Vector3(0,4,0)
		pivot.rotation = Vector3(-.48,.65,0)
		arm.spring_length = 23
		arm.collision_mask = 0
	else:
		arm.spring_length = 4.5
		arm.collision_mask = 1
		var input := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var movement := Basis(Vector3.UP,yaw)*input.normalized()*4
		player.velocity.x = movement.x
		player.velocity.z = movement.z
		player.velocity.y = -2 if player.is_on_floor() else player.velocity.y-20*delta
		if Input.is_physical_key_pressed(KEY_SPACE) and player.is_on_floor():player.velocity.y=6
		player.move_and_slide()
		pivot.position = player.position + Vector3(0,1.4,0)
		pivot.rotation = Vector3(pitch,yaw,0)
