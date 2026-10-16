extends "res://tests/environment_pack.gd"
## 当前运行场景的金穗镇几何审计：房屋间距、门前通道、室内地板碰撞、资产碰撞体。

func _rect_gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dz := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)

func _world_rect(n: ModelProp, local_box: AABB) -> Rect2:
	var box := n.global_transform * local_box
	return Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))

func _door_meta(id: String, meta: Dictionary) -> Dictionary:
	return meta.get(id, {}) if meta.has(id) else {}

func _interior_view(prop: ModelProp, label: String, local_eye: Vector3, local_target: Vector3) -> void:
	Game.player.set_physics_process(false)
	Game.hud.hide()
	if not is_instance_valid(camera):
		camera = Camera3D.new()
		camera.fov = 70.0
		Game.world.add_child(camera)
	camera.global_position = prop.to_global(local_eye)
	camera.look_at(prop.to_global(local_target))
	camera.make_current()
	await wait(0.5)
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + "/" + label + ".png")

func run() -> void:
	get_tree().auto_accept_quit = false
	get_tree().root.gui_disable_input = true
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	var town_point := Vector3(435.0, U.ground_height(get_tree(), 435.0, 500.0, 35.0) + 0.5, 500.0)
	await Game.world._teleport_to(town_point)
	await get_tree().physics_frame
	var zone: Node = Game.world.zones.get("vale")
	var buildings: Node = zone.get_node_or_null("Buildings") if zone else null
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/village_kit/buildings.json"))
	var rows: Array = []
	var rects: Array = []
	var door_checks: Array = []
	var floor_checks: Array = []
	var interior_checks: Array = []
	var foliage_checks: Array = []
	if buildings:
		for n in buildings.get_children():
			if not (n is ModelProp):
				continue
			var prop := n as ModelProp
			if prop.asset_scene == "" or not prop.asset_scene.contains("/village_kit/"):
				continue
			if Vector2(prop.global_position.x - 435.0, prop.global_position.z - 470.0).length() > 85.0:
				continue
			var id := prop.asset_scene.get_file().get_basename()
			var inst: Node3D = prop.get_node_or_null("_gen") as Node3D
			var visual: Node3D = inst.get_child(0) as Node3D if inst and inst.get_child_count() > 0 else null
			var local_box: AABB = AABB()
			if visual:
				local_box = prop.call("_local_aabb", visual) as AABB
			var r := _world_rect(prop, local_box)
			var bodies: Array = []
			if prop.get_node_or_null("_gen"):
				bodies = prop.get_node_or_null("_gen").find_children("*", "CollisionShape3D", true, false)
			var row := {"node": str(prop.name), "id": id, "pos": [prop.global_position.x, prop.global_position.y, prop.global_position.z], "rect": [r.position.x, r.position.y, r.size.x, r.size.y], "collision_shapes": bodies.size()}
			rows.append(row)
			rects.append({"id": id, "node": prop, "rect": r})
			var md: Dictionary = _door_meta(id, meta)
			var gen_node: Node = prop.get_node_or_null("_gen")
			if not md.is_empty() and gen_node:
				var d: Array = md.get("door", [])
				if d.size() >= 2:
					var door_pos := prop.global_transform * Vector3(float(d[0]), 1.0, float(d[1]))
					var forward := prop.global_transform.basis * Vector3(0, 0, 1)
					var q := PhysicsRayQueryParameters3D.create(door_pos + forward * 0.7, door_pos + forward * 5.0)
					q.collision_mask = 1
					var ray_exclude: Array[RID] = []
					ray_exclude.append(Game.player.get_rid())
					for body in gen_node.find_children("*", "CollisionObject3D", true, false):
						ray_exclude.append((body as CollisionObject3D).get_rid())
					q.exclude = ray_exclude
					var hit: Dictionary = Game.world.get_world_3d().direct_space_state.intersect_ray(q)
					var hit_name := ""
					var hit_path := ""
					if hit.has("collider") and hit["collider"]:
						hit_name = str(hit["collider"].name)
						hit_path = str(hit["collider"].get_path())
					door_checks.append({"id": id, "node": str(prop.name), "forward_hit": hit_name, "forward_path": hit_path, "shapes": bodies.size()})
					var inner: Array = md.get("inner", [])
					var floors := 0
					if inner.size() >= 4:
						for fx in [0.15, 0.5, 0.85]:
							for fz in [0.15, 0.5, 0.85]:
								var lp := Vector3(lerpf(float(inner[0]), float(inner[1]), fx), 5.0, lerpf(float(inner[2]), float(inner[3]), fz))
								var wp := prop.global_transform * lp
								var down := PhysicsRayQueryParameters3D.create(wp, wp + Vector3.DOWN * 8.0)
								down.collision_mask = 1
								down.exclude = [Game.player]
								var floor_hit: Dictionary = Game.world.get_world_3d().direct_space_state.intersect_ray(down)
								if floor_hit.has("collider") and floor_hit.collider:
									floors += 1
					floor_checks.append({"id": id, "samples": floors, "expected": 9})
					var max_over := -INF
					var terrain_bad := 0
					var foreign_hits := {}
					var sphere := SphereShape3D.new()
					sphere.radius = 0.18
					if inner.size() >= 4:
						for ix in 7:
							for iz in 7:
								var lp := Vector3(lerpf(float(inner[0]), float(inner[1]), 0.08 + ix * 0.14), 0.0, lerpf(float(inner[2]), float(inner[3]), 0.08 + iz * 0.14))
								var wp := prop.global_transform * lp
								var over: float = zone.terrain.get_height_global(wp.x, wp.z) - (prop.global_position.y + 0.2)
								max_over = maxf(max_over, over)
								if over > 0.0:
									terrain_bad += 1
								for height in [0.75, 1.6]:
									var overlap := PhysicsShapeQueryParameters3D.new()
									overlap.shape = sphere
									overlap.transform.origin = wp + Vector3.UP * height
									overlap.collision_mask = 1
									overlap.exclude = ray_exclude
									for result in Game.world.get_world_3d().direct_space_state.intersect_shape(overlap, 8):
										var collider: Node = result.collider
										if not collider is BrushTerrain:
											foreign_hits[str(collider.get_path())] = true
						interior_checks.append({"id": id, "node": str(prop.name), "terrain_bad": terrain_bad, "samples": 49, "max_terrain_over_floor_m": max_over, "foreign_colliders": foreign_hits.keys()})
					for forest in zone.find_children("*", "Forest", true, false):
						var inside := 0
						for point in forest.points:
							var fp: Vector3 = prop.to_local(forest.to_global(point))
							if inner.size() >= 4 and fp.x > float(inner[0]) and fp.x < float(inner[1]) and fp.z > float(inner[2]) and fp.z < float(inner[3]):
								inside += 1
						if inside > 0:
							foliage_checks.append({"id": id, "node": str(prop.name), "forest": str(forest.name), "kind": forest.kind, "centres_inside": inside})
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var gap := _rect_gap(rects[i].rect, rects[j].rect)
			if gap < 2.0:
				print("AUDIT BUILDING GAP ", rects[i].id, " / ", rects[j].id, " = ", snapped(gap, 0.01))
	var report := {"buildings": rows, "door_checks": door_checks, "floor_checks": floor_checks, "interior_checks": interior_checks, "foliage_checks": foliage_checks, "aabb_note": "Conservative visual AABBs only; overlap is not proof of geometry penetration."}
	FileAccess.open(out + "/geometry.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("GOLDEN TOWN GEOMETRY AUDIT ", JSON.stringify({"buildings": rows.size(), "doors": door_checks.size(), "floors": floor_checks.size()}))
	print("GOLDEN TOWN INTERIOR ", JSON.stringify(interior_checks))
	print("GOLDEN TOWN FOLIAGE ", JSON.stringify(foliage_checks))
	check(rows.size() == 16, "all sixteen saved town buildings inspected")
	check(floor_checks.size() == 16 and floor_checks.all(func(row): return row.samples == 9), "all town floors have nine collision samples")
	check(door_checks.size() == 16 and door_checks.all(func(row): return row.forward_hit == ""), "all town door front paths are clear of foreign static bodies")
	check(interior_checks.size() == 16 and interior_checks.all(func(row): return row.terrain_bad == 0), "all 784 interior terrain samples remain below floor")
	check(interior_checks.all(func(row): return row.foreign_colliders.is_empty()), "all 1568 interior sphere samples are clear of foreign static collisions")
	check(foliage_checks.is_empty(), "no authored vegetation centres lie inside town interiors")
	if "views" in OS.get_cmdline_user_args():
		for entry in rects:
			if entry.id == "guard":
				await _interior_view(entry.node, "01_guard_floor", Vector3(-4.0, 2.1, 1.0), Vector3(3.5, 0.4, -3.0))
			elif entry.id == "stable":
				await _interior_view(entry.node, "02_stable_interior", Vector3(-7.0, 2.1, 3.0), Vector3(7.0, 1.2, -4.0))
			elif entry.id == "home_wing":
				await _interior_view(entry.node, "03_home_wing_interior", Vector3(-5.0, 2.1, 4.5), Vector3(5.0, 1.0, 0.5))
			elif entry.id == "trainer":
				await _interior_view(entry.node, "04_trainer_interior", Vector3(-7.0, 2.1, 4.0), Vector3(6.0, 1.1, -3.0))
			elif entry.id == "smithy":
				await _interior_view(entry.node, "05_smithy_interior", Vector3(-5.0, 2.1, 4.0), Vector3(6.0, 1.2, -3.0))
	FileAccess.open(out + "/checks.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)
