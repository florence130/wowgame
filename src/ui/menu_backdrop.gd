class_name MenuBackdrop
extends TextureRect
## An isolated 3D colonnade, so selection blur never blurs the avatar or UI.

var viewport: SubViewport
var scene: Node3D
var camera: Camera3D
var tower: Node3D
var feathers: Array[MeshInstance3D] = []
var feather_origins: Array[Vector3] = []
var drift := Vector2.ZERO
var cursor_target := Vector2.ZERO
var selecting := false
var elapsed := 0.0
var blur_material: ShaderMaterial
var stone: StandardMaterial3D
var shadow_stone: StandardMaterial3D
var ruins: Node3D
var camp: CampScene
var ruins_environment: Environment
var camp_environment: Environment
var sun: DirectionalLight3D
var moonlight: DirectionalLight3D
var feather_particles: GPUParticles3D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(1600, 900)
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	texture = viewport.get_texture()
	blur_material = ShaderMaterial.new()
	blur_material.shader = preload("res://src/ui/menu_backdrop.gdshader")
	material = blur_material
	scene = Node3D.new()
	viewport.add_child(scene)
	ruins = Node3D.new()
	scene.add_child(ruins)
	_build()
	resized.connect(_resize)
	_resize()

func _resize() -> void:
	if viewport:
		# Cap offscreen resolution; visual composition is independent of window size.
		var scale_factor := minf(1.0, 1920.0 / maxf(size.x, 1.0))
		viewport.size = Vector2i(maxi(1, int(size.x * scale_factor)), maxi(1, int(size.y * scale_factor)))

func set_selection(value: bool) -> void:
	selecting = value
	RenderingServer.global_shader_parameter_set("env_night", 1.0 if value else 0.0)
	if tower:
		tower.visible = false
	if ruins:
		ruins.visible = not value
	if camp:
		camp.visible = value
		camp.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
		camp.fireflies.emitting = value
	if camera:
		camera.environment = camp_environment if value else ruins_environment
	if sun:
		sun.visible = not value
	if moonlight:
		moonlight.visible = value
	if feather_particles:
		feather_particles.emitting = not value
	if blur_material:
		blur_material.set_shader_parameter("blur_amount", 1.8 if value else 0.0)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	return m

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(ruins if parent == null else parent).add_child(mi)
	return mi

func _box(pos: Vector3, dims: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dims
	return _mesh(mesh, mat, pos, parent)

func _cyl(pos: Vector3, radius: float, height: float, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.04
	mesh.height = height
	mesh.radial_segments = 32
	return _mesh(mesh, mat, pos, parent)

func _column(x: float, z: float, height: float, broken: bool = false) -> void:
	var r := 0.56
	_box(Vector3(x, 0.12, z), Vector3(1.9, 0.24, 1.9), stone)
	_box(Vector3(x, 0.32, z), Vector3(1.55, 0.16, 1.55), stone)
	_cyl(Vector3(x, 0.49, z), 0.78, 0.18, stone)
	_cyl(Vector3(x, 0.62, z), 0.64, 0.12, stone)
	_cyl(Vector3(x, 0.72 + height * 0.5, z), r, height, stone)
	# Fluting catches the cool side light and leaves a crisp stylized silhouette.
	for n in 16:
		var angle := TAU * n / 16.0
		_cyl(Vector3(x + cos(angle) * r, 0.72 + height * 0.5, z + sin(angle) * r), 0.045, height - 0.12, stone)
	for n in range(1, int(height / 1.5)):
		_cyl(Vector3(x, 0.72 + n * 1.5, z), r * 1.025, 0.025, shadow_stone)
	if not broken:
		_cyl(Vector3(x, height + 0.78, z), 0.67, 0.16, stone)
		_cyl(Vector3(x, height + 0.93, z), 0.77, 0.16, stone)
		_box(Vector3(x, height + 1.12, z), Vector3(1.65, 0.24, 1.65), stone)
	else:
		for n in 5:
			var shard := _box(Vector3(x - 0.4 + n * 0.2, height + 0.73, z), Vector3(0.24, 0.12 + n % 3 * 0.14, 0.8), stone)
			shard.rotation.z = sin(n * 3.0) * 0.22

func _build() -> void:
	stone = _mat(Color("dce7ef"))
	shadow_stone = _mat(Color("afc1d8"))
	var env := Environment.new()
	ruins_environment = env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://src/ui/menu_sky.gdshader")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("99b2de")
	env.ambient_light_energy = 0.78
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("91a9ca")
	env.fog_light_energy = 0.65
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		env.ssr_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var light := DirectionalLight3D.new()
	sun = light
	light.rotation_degrees = Vector3(-28, -38, 0)
	light.light_color = Color("f3f8ff")
	light.light_energy = 1.7
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 90
	scene.add_child(light)
	camera = Camera3D.new()
	camera.fov = 58
	camera.far = 350
	camera.position = Vector3(-4.8, 0.85, 10.8)
	scene.add_child(camera)
	camera.look_at(Vector3(-0.6, 8.5, -11))
	# A flooded avenue with pale marble islands and colonnades framing open sky.
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(300, 300)
	water_mesh.subdivide_width = 30
	water_mesh.subdivide_depth = 30
	var wm := ShaderMaterial.new()
	wm.shader = preload("res://src/ui/menu_water.gdshader")
	var water := _mesh(water_mesh, wm, Vector3(0, 0.045, -60))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1.0, 1.0]:
		for i in 7:
			var z := 5.0 - i * 7.0
			var x: float = side * (6.0 + (0.8 if i == 0 else 0.0))
			_column(x, z, 9.5 if i < 3 else 8.4, (side > 0 and i in [1, 4]))
			_box(Vector3(x, -0.02, z), Vector3(4.4, 0.22, 6.95), stone)
			if i in [0, 2, 5]:
				_box(Vector3(x, 10.95 if i < 3 else 9.85, z - 2.5), Vector3(1.75, 0.55, 6.7), stone)
	# Far temple and stepped terrace. Off-center broken pillars interrupt symmetry.
	for i in 8:
		_box(Vector3(0, 0.08 + i * 0.15, -39.0 - i * 0.44), Vector3(11.0, 0.18, 1.0), stone)
	for x in [-4.2, -1.4, 1.4, 4.2]:
		_column(x, -47, 6.8)
	_box(Vector3(0, 8.1, -47), Vector3(11.6, 0.7, 2.1), stone)
	_column(-10.0, -9.0, 3.0, true)
	_column(10.0, -14.0, 4.8, true)
	var tree: Node3D = load("res://assets/models/nature_storybook/oak_0.scn").instantiate()
	tree.position = Vector3(-13, 0, -14)
	tree.scale = Vector3.ONE * 1.2
	ruins.add_child(tree)
	CampScene.prepare_tree(tree, true)
	var reflection := ReflectionProbe.new()
	reflection.position = Vector3(0, 0.5, -8)
	reflection.size = Vector3(44, 28, 80)
	reflection.box_projection = true
	reflection.intensity = 0.85
	ruins.add_child(reflection)
	_build_feathers()
	camp = CampScene.new()
	scene.add_child(camp)
	camp_environment = Environment.new()
	camp_environment.background_mode = Environment.BG_SKY
	var night_sky := Sky.new()
	night_sky.process_mode = Sky.PROCESS_MODE_REALTIME
	night_sky.radiance_size = Sky.RADIANCE_SIZE_256
	var night_material := ShaderMaterial.new()
	night_material.shader = preload("res://src/ui/camp_sky.gdshader")
	night_material.set_shader_parameter("cloud_tex", preload("res://assets/textures/environment_packs/sky_clouds.png"))
	night_material.set_shader_parameter("cloud_detail_tex", preload("res://assets/textures/environment_packs/sky_cloud_detail.png"))
	night_sky.sky_material = night_material
	camp_environment.sky = night_sky
	camp_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camp_environment.ambient_light_color = Color("739fc4")
	camp_environment.ambient_light_energy = 0.6
	camp_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	camp_environment.glow_enabled = true
	camp_environment.glow_intensity = 0.45
	camp_environment.fog_enabled = true
	camp_environment.fog_light_color = Color("163b53")
	camp_environment.fog_light_energy = 0.5
	camp_environment.fog_density = 0.009
	camp_environment.fog_sky_affect = 0.0
	moonlight = DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-32, -25, 0)
	moonlight.light_color = Color("91bce8")
	moonlight.light_energy = 0.7
	moonlight.shadow_enabled = true
	scene.add_child(moonlight)
	set_selection(false)

func _build_tower() -> void:
	tower = Node3D.new()
	tower.name = "BabelTower"
	tower.position = Vector3(-11, 0, -104)
	ruins.add_child(tower)
	var distant := _mat(Color("b6c8e3"))
	# Successively smaller arcaded tiers and a visible spiral rising into the mist.
	for tier in 8:
		var r := 11.8 - tier * 1.13
		var y := 1.6 + tier * 4.2
		_cyl(Vector3(0, y, 0), r, 3.5, distant, tower)
		_cyl(Vector3(0, y + 1.88, 0), r + 0.45, 0.32, stone, tower)
		for n in 28:
			var a := n * TAU / 28.0
			var arch := _box(Vector3(cos(a) * (r + 0.035), y + 0.25, sin(a) * (r + 0.035)), Vector3(0.55, 1.9, 0.06), shadow_stone, tower)
			arch.rotation.y = -a + PI * 0.5
	for i in 200:
		var f := i / 199.0
		var a := f * TAU * 5.0
		var r := 12.3 - f * 8.4
		var step_mesh := _box(Vector3(cos(a) * r, 0.2 + f * 32.0, sin(a) * r), Vector3(1.8, 0.13, 0.6), stone, tower)
		step_mesh.rotation.y = -a
	_cyl(Vector3(0, 35.1, 0), 2.2, 4.0, stone, tower)
	tower.visible = false

func _build_feathers() -> void:
	feather_particles = GPUParticles3D.new()
	feather_particles.name = "DriftingFeathers"
	feather_particles.amount = 82
	feather_particles.lifetime = 48.0
	feather_particles.preprocess = 48.0
	feather_particles.position = Vector3(-1.0, 7.0, -9.0)
	feather_particles.visibility_aabb = AABB(Vector3(-24,-12,-35),Vector3(48,30,70))
	feather_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(13,8,15)
	pm.direction = Vector3(0.9,-0.12,0.05)
	pm.spread = 38.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.32
	pm.gravity = Vector3(0,-0.008,0)
	pm.angle_min = -85
	pm.angle_max = 85
	pm.angular_velocity_min = -14
	pm.angular_velocity_max = 14
	pm.scale_min = 0.3
	pm.scale_max = 0.8
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 2.2
	pm.turbulence_influence_min = 0.06
	pm.turbulence_influence_max = 0.13
	feather_particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18,0.48)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/ui/feather.svg")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	feather_particles.draw_pass_1 = quad
	ruins.add_child(feather_particles)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and size.x > 0 and size.y > 0:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		cursor_target = ((local / size - Vector2(0.5, 0.5)) * 2.0).clamp(Vector2(-1,-1),Vector2.ONE)

func _process(delta: float) -> void:
	elapsed += delta
	var cursor := Vector2.ZERO
	if not selecting and size.x > 0 and size.y > 0 and not Game.settings.get("menu_reduce_motion", false):
		cursor = cursor_target
	drift = drift.lerp(cursor, 1.0 - exp(-delta * 2.8))
	if camera:
		if selecting:
			camera.fov = 38
			camera.position = Vector3(0,2.7,9.6)
			camera.look_at(Vector3(0,1.4,-5))
		else:
			camera.fov = 58
			camera.position = Vector3(-4.8 + drift.x * 0.5, 0.85 - drift.y * 0.12, 10.8)
			camera.look_at(Vector3(-0.6 + drift.x * 0.22, 8.5 - drift.y * 0.18, -11))
