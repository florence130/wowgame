extends Node3D

var failed := 0

func check(ok: bool, label: String) -> void:
	print("PATH ", "PASS " if ok else "FAIL ", label)
	if not ok: failed += 1

func floor_mesh(points: PackedVector3Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(points)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func plane(y: float) -> StaticBody3D:
	return floor_mesh(PackedVector3Array([Vector3(-5,y,-5),Vector3(5,y,-5),Vector3(5,y,25),Vector3(-5,y,-5),Vector3(5,y,25),Vector3(-5,y,25)]))

func _ready() -> void:
	Game.slot_index = -1
	var mob := Mob.new()
	add_child(mob)
	mob.set_physics_process(false)
	mob.position = Vector3(0,7.05,0)
	mob.spawn_pos = mob.position
	var actor := Unit.new()
	add_child(actor)
	actor.set_physics_process(false)
	actor.position = Vector3(0,0.05,20)
	var slope := floor_mesh(PackedVector3Array([Vector3(-5,7,0),Vector3(5,7,0),Vector3(5,0,20),Vector3(-5,7,0),Vector3(5,0,20),Vector3(-5,0,20)]))
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(mob._same_encounter_floor(actor), "seven-meter continuous ramp permits a pack to engage")
	mob.is_boss = true
	check(not mob._same_encounter_floor(actor), "boss floor leash remains strict")
	mob.is_boss = false
	slope.free()
	var upper := plane(7)
	var lower := plane(0)
	await get_tree().physics_frame
	check(not mob._same_encounter_floor(actor), "separate stacked floors cannot imitate a ramp")
	upper.free(); lower.free()
	plane(0)
	var capsule := CapsuleShape3D.new()
	capsule.radius=.4;capsule.height=1.7
	var collision := CollisionShape3D.new()
	collision.shape=capsule;collision.position.y=.85
	mob.add_child(collision)
	mob.position=Vector3(0,.1,0)
	mob.velocity=Vector3.ZERO
	for frame in 30:
		await get_tree().physics_frame
		mob.apply_gravity_and_move(1.0/60.0,Vector3.ZERO)
	check(SanctumFollow.walk_supported(mob,Vector3(0,0,15)), "direct pursuit over solid floor is allowed")
	check(not SanctumFollow.walk_supported(mob,Vector3(20,0,0)), "direct pursuit beyond a floor edge is rejected")
	var follow := SanctumFollow.new()
	actor.position = Vector3.ZERO
	mob.position = Vector3.ZERO
	follow.record(actor)
	for z in 9:
		actor.position = Vector3(0,0,z)
		follow.record(actor)
	for x in 9:
		actor.position = Vector3(x,0,8)
		follow.record(actor)
	check(follow.trail.size() >= 16, "owner path is recorded while companion is busy casting")
	var next := follow.target(mob, actor)
	check(absf(next.x) < 0.01 and next.z < 3, "follower keeps the first leg instead of cutting the corner")
	mob.position = Vector3(0,0,8)
	mob.apply_gravity_and_move(1.0/60.0,Vector3.ZERO)
	next = follow.target(mob, actor)
	check(next.z >= 7.9 and next.x < 3, "return from combat resumes at reached corner")
	actor.position = Vector3(0,0,20)
	mob.position = Vector3.ZERO
	follow.last_owner = actor.position
	follow.trail = [Vector3(.245,0,0),Vector3(1,0,0),Vector3(2,0,0)]
	next = follow.target(mob,actor)
	check(next.x > .5, "arrival threshold cannot deadlock inside the movement stopping distance")
	actor.position = Vector3(100,0,100)
	follow.record(actor)
	check(follow.trail.size() == 1, "an actual owner relocation clears stale path")
	print("PATH RESULT failed=",failed)
	get_tree().quit(1 if failed else 0)
