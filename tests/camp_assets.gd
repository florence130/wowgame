extends Node3D
## Verify the saved props can be used without the front end or a game world.
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("CAMP PASS " if ok else "CAMP FAIL ") + label)
	if not ok:
		failures += 1

func _ready() -> void:
	var log_scene := preload("res://assets/models/camp_kit/fallen_log.tscn")
	var fire_scene := preload("res://assets/models/camp_kit/campfire.tscn")
	var log_prop := log_scene.instantiate()
	log_prop.position = Vector3(-5,0,0)
	add_child(log_prop)
	var fire := fire_scene.instantiate()
	fire.position = Vector3(5,0,0)
	add_child(fire)
	var unlit := fire_scene.instantiate()
	unlit.set("lit",false)
	unlit.position = Vector3(10,0,0)
	add_child(unlit)
	check(Game.world == null and Game.hud == null, "props instantiate with no game world or UI")
	check(fire.get_node("Flames").visible and fire.get_node("FireLight").visible, "lit fire contains its flame and light")
	check(not unlit.get_node("Flames").visible and not unlit.get_node("FireLight").visible, "saved lit=false works on initial placement")
	fire.set("lit",false)
	check(not fire.get_node("Flames").visible and not fire.get_node("FireLight").visible, "runtime extinguish hides flame and light")
	fire.set("lit",true)
	check(fire.get_node("Flames").visible and not unlit.get_node("Flames").visible, "lighting one instance leaves another extinguished")
	var model := ModelProp.new()
	model.asset_scene = "res://assets/models/camp_kit/campfire.tscn"
	model.position = Vector3(0,0,-5)
	add_child(model)
	check(model.get_meta("modular_asset_scene","") == model.asset_scene, "existing ModelProp loads the native library scene")
	check(model.get_node("_gen/Campfire/Flames").visible, "ModelProp keeps the reusable effect")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for at in [Vector3(-5,0,0),Vector3(5,0,0),Vector3(0,0,-5)]:
		var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*3,at-Vector3.UP)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty(), "prop collision works at " + str(at))
	print("CAMP ASSET CHECKS 10 FAILURES ",failures)
	get_tree().quit(1 if failures > 0 else 0)
