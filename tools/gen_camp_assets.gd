extends SceneTree
## Bake metre-scale, self-contained camp props into the native asset library.
const DEST := "res://assets/models/camp_kit/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	_save(_log(), "fallen_log")
	_save(_fire(), "campfire")
	print("CAMP ASSETS saved fallen_log.tscn and campfire.tscn")
	quit()

func _material(c: Color, texture: String = "") -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.95
	if not texture.is_empty():
		mat.albedo_texture = load(texture)
	return mat

func _mesh(parent: Node3D, name: String, geometry: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = geometry
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

func _log() -> Node3D:
	var root := Node3D.new()
	root.name = "FallenLog"
	var bark := _material(Color("87633e"), "res://assets/textures/building/pt_bark.png")
	var cut := _material(Color("b99a63"))
	_mesh(root, "Bark", U.cyl_mesh(0.35,0.4,5.0,20), bark, Vector3(0,0.4,0)).rotation.z = PI * 0.5
	for side in [-1,1]:
		var center := Vector3(side * 2.505,0.4,0)
		_mesh(root, "CutEnd", U.cyl_mesh(0.345,0.345,0.02,24), cut, center).rotation.z = PI * 0.5
		for i in 4:
			var radius := 0.075 + i * 0.066
			_mesh(root, "GrowthRing", U.torus_mesh(radius-0.003,radius+0.003,32), _material(Color("917249")), center + Vector3(side*0.015,0,0)).rotation.z = PI * 0.5
	var branch := _mesh(root,"BrokenBranch",U.cyl_mesh(0.10,0.15,0.6,9),bark,Vector3(-0.7,0.55,0.25))
	branch.rotation = Vector3(0.6,0,-0.6)
	var body := StaticBody3D.new()
	body.name = "LogCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = 0.39
	shape.height = 5.0
	collision.shape = shape
	collision.position.y = 0.4
	collision.rotation.z = PI * 0.5
	body.add_child(collision)
	return root

func _fire() -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire"
	root.set_script(load("res://src/world/campfire_effect.gd"))
	var rock := _material(ArtStyle.TERRAIN_ROCK)
	for i in 12:
		var a := TAU * i / 12.0
		var stone := _mesh(root,"HearthStone",U.sphere_mesh(0.22,0.44,false,9),rock,Vector3(cos(a)*0.75,0.15,sin(a)*0.65))
		stone.scale = Vector3(1.15,0.7,0.85)
	var wood := _material(Color("634327"),"res://assets/textures/building/pt_bark.png")
	for i in 5:
		_mesh(root,"FuelLog",U.cyl_mesh(0.1,0.13,1.1,12),wood,Vector3(0,0.18,0)).rotation = Vector3(PI*0.5,i*TAU/5,0)
	var flames := Node3D.new()
	flames.name = "Flames"
	root.add_child(flames)
	var fm := ShaderMaterial.new()
	fm.shader = load(DEST + "fire.gdshader")
	fm.set_shader_parameter("noise_tex", BrushTerrain.get_noise_texture())
	for i in 3:
		var quad := QuadMesh.new()
		quad.size = Vector2(1.2,1.65)
		var flame := _mesh(flames,"Flame",quad,fm,Vector3(0,0.9,0))
		flame.rotation.y = i * PI / 3.0
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.position = Vector3(0,1.1,0)
	light.light_color = Color("ffb45a")
	light.light_energy = 3.4
	light.omni_range = 8.5
	light.shadow_enabled = true
	root.add_child(light)
	var body := StaticBody3D.new()
	body.name = "HearthCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 0.28
	collision.position.y = 0.14
	collision.shape = shape
	body.add_child(collision)
	return root

func _owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_owners(child,root)

func _save(node: Node3D, id: String) -> void:
	_owners(node,node)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed,DEST+id+".tscn") == OK)
	node.free()
