class_name CampScene
extends Node3D
## Night forest clearing composed from existing CC0 trees and original camp props.
var fire_light: OmniLight3D
var fireflies: GPUParticles3D
var terrain: BrushTerrain
var grass: GrassField
var fallen_log: Node3D
var campfire: Node3D

func material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m

func mesh(m: Mesh, mat: Material, pos: Vector3, scale_factor: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_factor
	add_child(mi)
	return mi

static func prepare_tree(tree: Node3D, pale: bool = false) -> void:
	for instance in tree.find_children("*", "MeshInstance3D", true, false):
		var geometry: MeshInstance3D = instance
		for i in geometry.mesh.get_surface_count():
			var source: Material = geometry.get_active_material(i)
			var leaf := geometry.name.to_lower().contains("leaf")
			var mask: Texture2D = source.albedo_texture if leaf and source is BaseMaterial3D else null
			var color := Color("abc0da") if pale else (Color("3e684b") if leaf else Color("665139"))
			var mat := Forest._veg_mat(color, leaf, mask)
			geometry.set_surface_override_material(i, mat)

func _ready() -> void:
	_build_terrain()
	var rng := RandomNumberGenerator.new()
	rng.seed = 44987
	# Layered hills and smaller trees close the flat horizon and lead into the clearing.
	for i in 18:
		var distant: Node3D = load("res://assets/models/nature_storybook/pine_%d.scn" % (i % 3)).instantiate()
		prepare_tree(distant)
		distant.position = Vector3(-30+i*3.5,0,-58-rng.randf_range(0,12))
		distant.position.y = terrain.get_height_global(distant.position.x,distant.position.z)
		distant.scale = Vector3.ONE * rng.randf_range(0.35,0.58)
		add_child(distant)
	# Dense sides frame a blue moonlit vista through the center.
	for i in 48:
		var z := rng.randf_range(-65, -8)
		var x := rng.randf_range(-36, 36)
		if absf(x) < 11 and z > -52:
			x += 14.0 * signf(x)
		var tree: Node3D = load("res://assets/models/nature_storybook/pine_%d.scn" % (i % 3)).instantiate()
		prepare_tree(tree)
		tree.position = Vector3(x, 0, z)
		tree.position.y = terrain.get_height_global(x,z)
		tree.rotation.y = rng.randf() * TAU
		tree.scale = Vector3.ONE * rng.randf_range(0.65, 1.1)
		add_child(tree)
	for entry in [[Vector3(-6.8, 0, 1.0), 1.0], [Vector3(7.4, 0, -1.6), 1.1], [Vector3(-13, 0, -8), 1.05]]:
		var oak: Node3D = load("res://assets/models/nature_storybook/oak_0.scn").instantiate()
		prepare_tree(oak)
		oak.position = entry[0]
		oak.position.y = terrain.get_height_global(oak.position.x,oak.position.z)
		oak.scale = Vector3.ONE * entry[1]
		add_child(oak)
	var rock_mat := material(Color("707d7d"))
	for entry in [[-5.0,-2.2,2.0],[4.4,-3.0,1.7],[-6.0,-7.0,2.3],[6.7,-8.0,2.5]]:
		mesh(U.sphere_mesh(1.0, 2.0, false, 9), rock_mat, Vector3(entry[0], 0.45, entry[1]), Vector3(entry[2], 0.8, 1.1))
	# Native library assets are reused here and can be placed in the game world.
	var bark := material(Color("51402c"))
	bark.albedo_texture = load("res://assets/textures/building/pt_bark.png")
	fallen_log = preload("res://assets/models/camp_kit/fallen_log.tscn").instantiate()
	fallen_log.position = Vector3(0,0,-2.3)
	add_child(fallen_log)
	_build_fire()
	for side in [-1, 1]:
		var x: float = side * 4.5
		mesh(U.cyl_mesh(0.6,0.7,0.65,12),bark,Vector3(x,0.32,0.8))
		var lantern := material(Color("ffdb7d"))
		lantern.emission_enabled = true
		lantern.emission = Color("ffb94c")
		lantern.emission_energy_multiplier = 2.5
		mesh(U.cyl_mesh(0.11,0.11,0.27,8),lantern,Vector3(x,0.87,0.8))
		mesh(U.cyl_mesh(0.19,0.17,0.08,8),bark,Vector3(x,1.04,0.8))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x,1.0,0.8)
		lamp.light_color = Color("ffc16c")
		lamp.light_energy = 1.5
		lamp.omni_range = 5.0
		add_child(lamp)
	_fireflies()

func _build_fire() -> void:
	campfire = preload("res://assets/models/camp_kit/campfire.tscn").instantiate()
	campfire.position = Vector3(0,0,1.0)
	add_child(campfire)
	fire_light = campfire.get_node("FireLight")

func _build_terrain() -> void:
	var data := TerrainData.new()
	data.setup(128,1.0)
	var noise := FastNoiseLite.new()
	noise.seed = 44987
	noise.frequency = 0.04
	for z in 129:
		for x in 129:
			var wx := x - 64.0
			var wz := z - 96.0
			var distant := smoothstep(12,55,-wz)
			data.set_h(x,z,(3.0+noise.get_noise_2d(wx,wz)*5.5)*distant)
	for z in 128:
		for x in 128:
			var wx := x - 63.5
			var wz := z - 95.5
			data.paint_pixel(x,z,1,0.38)
			data.paint_pixel(x,z,7,0.14+0.12*maxf(noise.get_noise_2d(wx+30,wz),0.0))
			var clearing := Vector2(wx/5.2,(wz-0.5)/4.8).length()
			var edge := 0.09 * noise.get_noise_2d(wx*3,wz*3)
			data.paint_pixel(x,z,2,1.0-smoothstep(0.78,1.16,clearing+edge))
	terrain = BrushTerrain.new()
	terrain.name = "CampTerrain"
	terrain.data = data
	terrain.position = Vector3(-64,0,-96)
	terrain.collision_enabled = false
	add_child(terrain)
	grass = GrassField.new()
	grass.name = "CampGrassField"
	add_child(grass)
	grass.setup(terrain)
	grass.set_process(false)
	# A static camera needs a bounded patch, using the exact game chunk generator.
	for z in range(-3,1):
		for x in range(-2,2):
			grass._build(Vector2i(x,z))

func _fireflies() -> void:
	fireflies = GPUParticles3D.new()
	fireflies.amount = 35
	fireflies.lifetime = 12
	fireflies.preprocess = 12
	fireflies.position = Vector3(0,1.3,-4)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9,1.1,10)
	pm.direction = Vector3.UP
	pm.spread = 180
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.04
	pm.initial_velocity_max = 0.13
	fireflies.process_material = pm
	var orb := SphereMesh.new()
	orb.radius = 0.018
	orb.height = 0.036
	var mat := material(Color("d4ef8d"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color("d4ef8d")
	mat.emission_energy_multiplier = 2.0
	orb.material = mat
	fireflies.draw_pass_1 = orb
	add_child(fireflies)

