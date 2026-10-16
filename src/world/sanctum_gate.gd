@tool
extends Node3D
## Unity exports the opening; Godot owns its fire-seed barrier.
@export var flag := ""
@export var title := "火种封印"
@export var width := 8.0
@export var sill_drop := 0.0
@export var tint := Color("8aafcd")
const SEEDS := ["sanctum_ember_root","sanctum_ember_lake","sanctum_ember_nave"]
const SEED_COLORS := [Color("b6d477"),Color("f3b46d"),Color("bda4e5")]
const SEED_NAMES := ["腐根","旧航","潮汐"]

func _ready() -> void:
	add_to_group("gates")
	refresh_gate()

func refresh_gate() -> void:
	_refresh_fire_sockets()
	var old := get_node_or_null("Barrier")
	if old:
		old.free()
	if not Engine.is_editor_hint() and Game.has_flag(flag):
		return
	var barrier := StaticBody3D.new()
	barrier.name = "Barrier"
	barrier.collision_layer = 1
	add_child(barrier)
	U.add_box_shape(barrier, Vector3(width, 5.6+sill_drop, 0.7), Vector3(0, 2.8-sill_drop*.5, 0))
	U.add_mesh(barrier, U.box_mesh(Vector3(width, 4.8+sill_drop, 0.10)), U.unshaded(Color(tint, 0.22), true), Vector3(0, 2.4-sill_drop*.5, 0))
	for i in int(width / 0.8):
		U.add_mesh(barrier, U.box_mesh(Vector3(0.10, 4.8+sill_drop, 0.10)), U.mat(Color("464b55")), Vector3(-width * 0.5 + 0.4 + i * 0.8, 2.4-sill_drop*.5, 0))
	var label := Label3D.new()
	label.text = title
	if flag == "sanctum_final_open":
		var collected := 0
		for seed_flag in SEEDS:
			if not Engine.is_editor_hint() and Game.has_flag(seed_flag):collected+=1
		label.text += "\n火种 %d / 3" % collected
	# The root barrier also seals the irregular excavation beside its actual
	# door. Keep the name above the paved doorway rather than that blind wall.
	label.position = Vector3(4.5 if flag=="sanctum_ember_root" else 0.0, 4.15, 1.5)
	label.font_size = 32
	label.pixel_size = 0.016
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	barrier.add_child(label)

func _refresh_fire_sockets() -> void:
	var previous := get_node_or_null("FireSockets")
	if previous:previous.free()
	var sockets := Node3D.new();sockets.name="FireSockets";add_child(sockets)
	var keys: Array = SEEDS if flag=="sanctum_final_open" else [flag]
	var post_x := width*.5-1.0
	var post_height := 5.1 if keys.size()==3 else 2.35
	var floor_drop := 3.0 if flag=="sanctum_ember_root" else (.5 if flag=="sanctum_ember_lake" else 0.0)
	U.add_mesh(sockets,U.box_mesh(Vector3(.55,post_height+floor_drop,.55)),U.bmat(9,Color("8e917f")),Vector3(post_x,(post_height-floor_drop)*.5,1.5))
	U.add_mesh(sockets,U.box_mesh(Vector3(.9,.25,.9)),U.bmat(9,Color("8e917f")),Vector3(post_x,.125-floor_drop,1.5))
	for i in keys.size():
		var key: String=keys[i]
		var seed_index := SEEDS.find(key)
		if seed_index<0:continue
		var lit: bool=not Engine.is_editor_hint() and Game.has_flag(key)
		var fixture := Node3D.new();fixture.name="Socket_"+str(seed_index)
		fixture.position=Vector3(post_x,1.7+i*1.3,1.85)
		fixture.set_meta("seed_flag",key);fixture.set_meta("lit",lit)
		sockets.add_child(fixture)
		U.add_mesh(fixture,U.box_mesh(Vector3(.9,.78,.2)),U.bmat(9,Color("8e917f")),Vector3(0,.2,-.35))
		U.add_mesh(fixture,U.box_mesh(Vector3(.16,.14,.6)),U.bmat(7,Color("4e5550")),Vector3(0,-.1,-.10))
		U.add_mesh(fixture,U.cyl_mesh(.34,.17,.24,12),U.bmat(7,Color("666b57")),Vector3.ZERO)
		var coal := U.add_mesh(fixture,U.sphere_mesh(.22,.55,false,12),U.mat(SEED_COLORS[seed_index] if lit else Color("393c35"),.8 if lit else 0),Vector3(0,.26,0))
		coal.name="FireSeed"
		var caption := Label3D.new();caption.text=SEED_NAMES[seed_index]
		caption.position=Vector3(-.8,.18,.35);caption.font_size=28;caption.pixel_size=.018
		caption.modulate=SEED_COLORS[seed_index] if lit else Color("989b8d")
		caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		fixture.add_child(caption)
