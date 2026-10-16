extends Node3D

var checks: Array = []

func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	Game.slot_index = -1
	Game.new_character("建筑入口临时物理验证", "warrior", DB.random_appearance(7, "f"))
	Game.slot_index = -1
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 2, 120)
	shape.shape = box
	shape.position.y = -1.6
	ground.add_child(shape)
	add_child(ground)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/city_v5/architecture/manifest.json"))
	for info in manifest.assets:
		if not info.enterable:
			continue
		for yaw in [0.0, 90.0]:
			var asset: Node3D = load(info.path).instantiate()
			asset.rotation.y = deg_to_rad(yaw)
			add_child(asset)
			await ticks(3)
			for ei in range(info.entry.size()):
				var entry: Dictionary = info.entry[ei]
				var basis_yaw := Basis(Vector3.UP, deg_to_rad(yaw))
				var e := basis_yaw * Vector3(entry.position[0], 0, entry.position[2])
				var outward := basis_yaw * Vector3(entry.outward[0], 0, entry.outward[2])
				var player := Player.new()
				add_child(player)
				player.set_physics_process(false)
				player.set_process(false)
				player.position = e + outward * 4.0 + Vector3.DOWN * .59
				var target := e - outward * 3.0
				var max_height := -.6
				for i in range(240):
					var wish := target - player.position
					wish.y = 0
					if wish.length() < .10:
						break
					player.apply_gravity_and_move(1.0 / 60.0, wish.normalized() * Player.WALK_SPEED)
					max_height = maxf(max_height, player.position.y)
					await ticks(1)
				var pos := player.position
				var remaining := Vector2(pos.x-target.x, pos.z-target.z).length()
				var collisions: Array = []
				for i in player.get_slide_collision_count():
					var hit := player.get_slide_collision(i)
					collisions.append({"normal":str(hit.get_normal()),"position":str(hit.get_position())})
				checks.append({"asset":info.id,"entry":ei,"yaw":yaw,"pass":remaining < .15 and absf(pos.y) < .08,"position":str(pos),"remaining_m":remaining,"max_height":max_height,"collisions":collisions})
				player.queue_free()
				await ticks(3)
			asset.queue_free()
			await ticks(3)
	var failures := checks.filter(func(c): return not c.pass).size()
	var report := {"scope":"Actual Player class, authored capsule, floor_max_angle=52 degrees, unchanged apply_gravity_and_move; isolated imported assets over a flat street at -0.6; no World scene or terrain integration claimed.","slot_index":Game.slot_index,"checks":checks,"check_count":checks.size(),"failure_count":failures}
	FileAccess.open("res://docs/city_v5/architecture/player_walk_verification.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("CITY_V5_ARCHITECTURE_WALK checks=", checks.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
