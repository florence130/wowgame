extends Node
## 金穗镇村屋可进入检查：每栋房屋从门前 2m 走进去，终点必须在房屋占地内、站在室内地面上（不被门槛 / 横梁 / 地形挡住）；
## 并检查地面是否穿进室内（室内 9 个采样点的地形高度不得高于室内地板）。
## Godot --path . res://tests/village_walk.tscn
const IDS := ["home_wing"]
var fails := 0

func check(ok: bool, what: String) -> void:
	print("VPROBE ", "PASS " if ok else "FAIL ", what)
	if not ok:
		fails += 1

func _ready() -> void:
	if not has_meta("runner"):
		var n := Node.new()
		n.set_script(get_script())
		n.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(n)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.new_character("村测", "warrior", DB.random_appearance(7, "f"))
	Game.slot_index = -1
	Game.pd["zone"] = "vale"
	Game.pd["level"] = 15
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	_run.call_deferred()

func _find_house(id: String) -> ModelProp:
	for n in Game.world.find_children("*", "ModelProp", true, false):
		if String((n as ModelProp).asset_scene).ends_with("/%s.glb" % id):
			return n
	return null

func _run() -> void:
	for i in 400:
		await get_tree().process_frame
		if Game.player and is_instance_valid(Game.player) and Game.world and not Game.world.loading:
			break
	await get_tree().create_timer(2.0).timeout
	var p: Player = Game.player
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/village_kit/buildings.json"))
	for id in IDS:
		var h := _find_house(id)
		if h == null:
			check(false, "%s：场景里找到房屋节点" % id)
			continue
		var m: Dictionary = meta[id]
		var yaw := h.rotation_degrees.y
		var basis := Basis(Vector3.UP, deg_to_rad(yaw))
		var start := h.global_position + basis * Vector3(float(m.door[0]), 0, float(m.door[1]) + 2.0)
		Game.world.streamer.prepare(start)
		p.hp = p.max_hp
		p.global_position = Vector3(start.x, h.global_position.y + 1.0, start.z)
		p.velocity = Vector3.ZERO
		p.rotation.y = deg_to_rad(yaw)
		p.cam_yaw = p.rotation.y
		for k in 200:
			await get_tree().process_frame
			if Game.world.ground_ready(p.global_position):
				break
		await get_tree().create_timer(0.8).timeout
		p.global_position.y = U.ground_height(get_tree(), start.x, start.z, h.global_position.y + 3.0) + 0.3
		await get_tree().create_timer(0.5).timeout
		p.hp = p.max_hp
		var sp := h.global_position + basis * Vector3(float(m.door[0]), 0, float(m.door[1]) + 2.0)
		var space := p.get_world_3d().direct_space_state
		for zz in [0.2, 0.6, 1.0, 1.5, 2.2]:
			var from := Vector3(sp.x, h.global_position.y + zz, sp.z)
			var to := from + basis * Vector3(0, 0, -6.0)
			var q := PhysicsRayQueryParameters3D.create(from, to)
			var r := space.intersect_ray(q)
			print("PROBE ", id, " h=", zz, " ", ("none" if r.is_empty() else "%s dist %.2f" % [str(r.collider.get_path()).right(50), from.distance_to(r.position)]))
		print("PROBE start ", sp, " player ", p.global_position)
		p.autorun = true
		for st in 8:
			await get_tree().create_timer(0.35).timeout
			var cs := ""
			for ci in p.get_slide_collision_count():
				var kc := p.get_slide_collision(ci)
				cs += " [%s @ %.2f,%.2f,%.2f n=%.1f,%.1f,%.1f]" % [str((kc.get_collider() as Node).get_path()).right(60), (basis.inverse() * (kc.get_position() - h.global_position)).x, (basis.inverse() * (kc.get_position() - h.global_position)).y, (basis.inverse() * (kc.get_position() - h.global_position)).z, kc.get_normal().x, kc.get_normal().y, kc.get_normal().z]
			print("PROBE step ", id, " p=", basis.inverse() * (p.global_position - h.global_position), cs)
		p.autorun = false
		var qd := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 3, 0), p.global_position + Vector3(0, -3, 0))
		qd.exclude = [p.get_rid()]
		var rd := p.get_world_3d().direct_space_state.intersect_ray(qd)
		print("PROBE down ", id, " ", ("none" if rd.is_empty() else "%s y=%.2f (rel house %.2f)" % [str(rd.collider.get_path()).right(60), rd.position.y, rd.position.y - h.global_position.y]))
		var qa := PhysicsRayQueryParameters3D.create(p.global_position, p.global_position + Vector3(0, 4, 0))
		qa.exclude = [p.get_rid()]
		var ra := p.get_world_3d().direct_space_state.intersect_ray(qa)
		print("PROBE up ", id, " ", ("none" if ra.is_empty() else "%s y=%.2f (rel %.2f)" % [str(ra.collider.get_path()).right(60), ra.position.y, ra.position.y - h.global_position.y]))
		await get_tree().create_timer(0.5).timeout
		var local := basis.inverse() * (p.global_position - h.global_position)
		var bb: Array = m.bbox          # Blender 坐标 x0, y0, x1, y1（glTF z = -y）
		var inside: bool = local.x > float(bb[0]) and local.x < float(bb[2]) and local.z > -float(bb[3]) and local.z < -float(bb[1])
		var dy := p.global_position.y - h.global_position.y
		check(inside and dy > -0.3 and not p.dead, "%s：走进室内（局部 %.1f, %.1f；离地 %.2f）" % [id, local.x, local.z, dy])
		# 地面穿模：室内 9 个采样点的地形高度不得高于室内地板（房屋原点 + 0.2）
		var inner: Array = m.inner
		var bad := 0
		var worst := -99.0
		for fx in [0.1, 0.5, 0.9]:
			for fz in [0.1, 0.5, 0.9]:
				var lp := Vector3(lerpf(float(inner[0]), float(inner[1]), fx), 0.0, lerpf(float(inner[2]), float(inner[3]), fz))
				var wp := h.global_position + basis * lp
				var terr = U.terrain_at(get_tree(), wp.x, wp.z)
				if terr == null:
					continue
				var over: float = terr.get_height_global(wp.x, wp.z) - (h.global_position.y + 0.2)
				worst = maxf(worst, over)
				if over > 0.0:
					bad += 1
		check(bad == 0, "%s：室内无地形穿出（%d / 9 采样点高于地板，最高 %+.2fm）" % [id, bad, worst])
	print("VPROBE RESULT: ", "ALL PASS" if fails == 0 else "%d FAIL" % fails)
	get_tree().quit(1 if fails else 0)

