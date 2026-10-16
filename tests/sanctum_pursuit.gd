extends Node3D

var owner_actor: Unit
var ally: Ally
var enemy: Unit
var elapsed := 0.0
var minimum_y := INF
var waypoint := 0
var route := [Vector3(329.44,6,132.15),Vector3(321.43,6,136.22),Vector3(312,6,141),Vector3(279,6,133.2)]
var fixture_zone: Zone

func _ready() -> void:
	Game.slot_index = -1
	Game.new_character("Pursuit fixture", "warrior", DB.random_appearance(7,"f"))
	var saved: Node = load("res://scenes/zones/windwhisper_sanctum.tscn").instantiate()
	var shell: Node3D = saved.get_node("Buildings/SanctumShell")
	shell.get_parent().remove_child(shell)
	add_child(shell)
	saved.free()
	fixture_zone = Zone.new()
	fixture_zone.zone_id = "sanctum"
	Game.zone = fixture_zone
	owner_actor = Unit.new()
	add_child(owner_actor)
	owner_actor.set_physics_process(false)
	owner_actor.faction = "player"
	owner_actor.position = route[0] + Vector3.UP * .1
	owner_actor.in_combat = true
	var shape := CapsuleShape3D.new()
	shape.radius=.4;shape.height=1.7
	var collision := CollisionShape3D.new()
	collision.shape=shape;collision.position.y=.85
	owner_actor.add_child(collision)
	enemy=Unit.new()
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position=Vector3(299,6.05,134)
	enemy.max_hp=100000;enemy.hp=100000
	enemy.in_combat=true
	enemy.add_to_group("mobs")
	enemy.add_threat(owner_actor,1)
	owner_actor.target=enemy
	ally=Ally.new()
	add_child(ally)
	ally.init_ally("garon","tank",owner_actor,15)
	ally.position=Vector3(338,6.1,127)
	set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	elapsed+=delta
	minimum_y=minf(minimum_y,ally.position.y)
	if owner_actor.position.y < 5.5 or ally.position.y < 5.5:
		finish(false,"actor left the physical corridor");return
	var wish:=Vector3.ZERO
	if waypoint < route.size():
		var offset: Vector3=route[waypoint]-owner_actor.position
		offset.y=0
		if offset.length()<.25:waypoint+=1
		else:wish=offset.normalized()*4.5
	owner_actor.apply_gravity_and_move(delta,wish)
	if elapsed > 25:
		finish(waypoint==route.size() and minimum_y >= 5.5 and ally.edge_dist(enemy)<3.0,"completed corner chase")

func finish(ok:bool,reason:String) -> void:
	print("PURSUIT RESULT pass=",ok," min_y=",minimum_y," route=",waypoint,"/",route.size()," ally=",ally.position," reason=",reason)
	Game.zone=null
	fixture_zone.free()
	get_tree().quit(0 if ok else 1)
