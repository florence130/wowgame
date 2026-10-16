extends Node
## Verify the saved town placements through ModelProp's real integration hook and terrain.
const KIT = preload("res://src/world/goldshire_kit.gd")
var checks: Array = []
var shots := false
func _ready() -> void:
	call_deferred("run")
func check(ok: bool, message: String, detail: Variant = null) -> void:
	checks.append({"passed":ok,"check":message,"detail":detail})
	print("PASS " if ok else "FAIL ",message," ",detail)
func run() -> void:
	shots = "shots" in OS.get_cmdline_user_args()
	var scene: Node3D = load("res://scenes/zones/dawnmist_vale.tscn").instantiate()
	var world := Node3D.new()
	add_child(world)
	var terrain: Node3D
	for child in scene.get_children():
		if child is BrushTerrain:
			terrain = child
			scene.remove_child(child)
			world.add_child(child)
			break
	check(terrain != null,"saved vale terrain loaded")
	var buildings: Array[Node3D] = []
	var distinct: Dictionary = {}
	for node in scene.find_children("*","Node3D",true,false):
		if not node is ModelProp:continue
		var id: String = KIT.choice(node)
		if id == "":continue
		var copy: Node3D = node.duplicate()
		world.add_child(copy)
		buildings.append(copy)
		check(copy.get_meta("goldshire_asset","") == id,"map asset " + id)
		distinct[id] = true
	check(buildings.size() == 12,"five services and seven homes replaced",buildings.size())
	check(distinct.size() == 11,"six unique home presets plus five services",distinct.keys())
	var control := ModelProp.new()
	control.position = Vector3(485,0,56)
	control.kind = "abbey_chapel"
	check(KIT.choice(control)=="","abbey excluded from replacement")
	control.free()
	var actor := CharacterBody3D.new()
	actor.floor_snap_length=.6
	actor.floor_max_angle=deg_to_rad(52)
	actor.collision_layer=2
	actor.collision_mask=1
	var collider := CollisionShape3D.new()
	collider.shape=CapsuleShape3D.new()
	collider.shape.radius=.4
	collider.shape.height=1.7
	collider.position.y=.85
	actor.add_child(collider)
	world.add_child(actor)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for building in buildings:
		if not KIT.LABELS.has(building.label):continue
		var id: String=building.get_meta("goldshire_asset")
		var depth:=10.0 if id=="tavern" else 8.0
		var model: Node3D=building.get_node("_gen").get_child(0)
		var start:=model.to_global(Vector3(0,0,-depth/2-4))
		start.y=terrain.get_height_global(start.x,start.z)+.10
		actor.position=start
		await get_tree().physics_frame
		var target:=model.to_global(Vector3(0,.36,0))
		var reached:=await walk(actor,target)
		check(reached,id+" actual-map enter",{"actual":actor.position,"target":target})
		check(absf(actor.position.y-target.y)<.25,id+" map interior floor height")
		check(await walk(actor,start),id+" actual-map exit",actor.position)
	if shots:
		var env:=WorldEnvironment.new()
		env.environment=Environment.new()
		env.environment.background_mode=Environment.BG_COLOR
		env.environment.background_color=Color("c4dfef")
		env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color=Color("c4dfef")
		env.environment.ambient_light_energy=.7
		world.add_child(env)
		var sun:=DirectionalLight3D.new()
		sun.rotation_degrees=Vector3(-50,-30,0)
		sun.shadow_enabled=true
		world.add_child(sun)
		var cam:=Camera3D.new()
		world.add_child(cam)
		var h:float=terrain.get_height_global(435,470)
		cam.position=Vector3(510,h+60,560)
		cam.look_at(Vector3(435,h+3,470))
		cam.current=true
		for i in range(8):await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/goldshire/map_layout.png"))
	var passed:=true
	for c in checks:passed=passed and c.passed
	FileAccess.open("res://.shots/goldshire/map_report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks},"  "))
	print("GOLDSHIRE_MAP_RESULT ",passed)
	scene.free()
	get_tree().quit(0 if passed else 1)
func walk(actor:CharacterBody3D,target:Vector3)->bool:
	var last:=actor.position
	var stuck:=0
	for i in range(360):
		await get_tree().physics_frame
		var v:=Vector3(target.x-actor.position.x,0,target.z-actor.position.z)
		if v.length()<.14:return true
		actor.velocity.x=v.normalized().x*3.5
		actor.velocity.z=v.normalized().z*3.5
		actor.velocity.y=-2 if actor.is_on_floor() else actor.velocity.y-20.0/60.0
		actor.move_and_slide()
		stuck=stuck+1 if actor.position.distance_to(last)<.001 else 0
		last=actor.position
		if stuck>30:break
	return false
