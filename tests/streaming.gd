extends Node
## Integration regression with a disposable, never-saved character. Real renderer by default.
var checks: Array = []
var samples: Array = []
var frame_ms: Array = []
var measure_frames := false
var out := "res://.local/streaming_20261006"
var shots := "res://.shots/streaming_20261006/regression"
var began := 0
var loading_hp_changes := 0
var observe_damage := false

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
		if arg.begins_with("shots="):
			shots = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	Game.new_character("流式测试", "warrior", DB.random_appearance(7, "f"))
	Game.slot_index = -1
	Game.pd["new"] = false
	Game.pd["flags"]["city_access"] = true
	began = Time.get_ticks_msec()
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	call_deferred("_run")

func _process(delta: float) -> void:
	if measure_frames:
		frame_ms.append(delta * 1000.0)
	if Game.player and not Game.player.dead:
		Game.player.hp = Game.player.max_hp

func check(ok: bool, label: String) -> void:
	checks.append({"pass": ok, "label": label})
	print(("STREAM PASS " if ok else "STREAM FAIL ") + label)

func wait_seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout

func wp(x: float, z: float) -> Vector3:
	return Vector3(x, U.ground_height(get_tree(), x, z, 20), z)

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots + "/" + label + ".png")

func move_to(p: Vector3, label: String) -> void:
	Game.hud.close_all()
	Game.player.set_target(null)
	await Game.world._teleport_to(p)
	await wait_seconds(0.3)
	check(Game.world.ground_ready(Game.player.global_position), label + " landing collision ready")
	check(Game.player.global_position.y >= U.ground_height(get_tree(), p.x, p.z, p.y) - 1.0, label + " no terrain fall-through")
	var s: Dictionary = Game.world.streamer.stats()
	s["label"] = label
	s["player_pos"] = str(Game.player.global_position)
	s["requested_pos"] = str(p)
	var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p - Vector3.UP * 40.0, 1)
	var hit: Dictionary = Game.world.get_world_3d().direct_space_state.intersect_ray(ray)
	s["landing_ray"] = str(hit)
	samples.append(s)
	print("STREAM SAMPLE ", JSON.stringify(s))
	await shot(label)

func _run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	var initial_ms := Time.get_ticks_msec() - began
	var world: World = Game.world
	var stream: WorldStream = world.streamer
	Game.time_of_day = 12.0
	world.weather = "clear"
	world.weather_amt = 0.0
	world.weather_t = 99999.0
	for z in world.zones.values():
		for poi in z.pois:
			Game.pd.explored[poi.poi_id] = true
	check(stream != null, "overworld streaming enabled")
	check(stream.stats().terrain_detail < 100, "initial terrain detail is bounded")
	check(get_tree().get_nodes_in_group("units").size() < 120, "initial actors are spatially resident")
	check(stream.stats().static_active < stream.records.size() / 2, "distant generated scenery not instantiated")
	var map_before := MapGen.for_current(world.zone)[0] as Texture2D
	var map_hash := map_before.get_image().get_data().hex_encode().sha256_text()
	await shot("01_spawn")
	# Death and gathering use real handlers; leave/re-enter must not refresh either slot early.
	var mob: Mob
	var gather: GatherNode
	for z in world.zones.values():
		for u in z.units_root.get_children():
			if u is Mob and not u.dead and mob == null:
				mob = u
			if u is GatherNode and gather == null:
				gather = u
	check(mob != null and gather != null, "spawn area supplies state regression actors")
	var mob_pos := mob.global_position
	var spawner: MobSpawner = mob.spawner
	var mob_slot: int = mob.get_meta("spawn_slot")
	var money_pre_kill: int = Game.pd.money
	mob.take_damage(mob.max_hp * 100, "physical", Game.player)
	mob._despawn_t = 180.0 # Keep the observable corpse throughout this bounded test.
	check(not mob.has_loot(), "kill transfers loot immediately without corpse interaction")
	# A deterministic probe guarantees nonempty loot for the persistence checks.
	Game.receive_loot({"money": 17, "items": [["j_wolf_fang", 1]]})
	var money_after_loot: int = Game.pd.money
	var fangs_after_loot := Game.count_item("j_wolf_fang")
	check(money_after_loot >= money_pre_kill + 17 and fangs_after_loot >= 1, "auto-loot probe deposited money and item")
	var xp_before: int = Game.pd["xp"]
	var due: int = spawner._slots[mob_slot].next
	var spot: GatherSpot = gather.spot
	var gather_slot: int = gather.get_meta("gather_slot")
	var gather_pos := gather.global_position
	# Use a long real cooldown so the round trip cannot legitimately refresh it.
	spot.respawn = 180.0
	gather._complete(Game.player)
	await get_tree().process_frame
	var gather_due: int = spot._slots[gather_slot].next
	var city_landing: Vector3 = world.zones.tidewind.get_spawn("fp_solenne").global_position
	# Original -1080,632 lies inside a solid house (confirmed with non-streamed control).
	# Use the authored flight landing, testing the player-facing destination.
	var attacker: Mob = world.zones.vale.spawn_mob("young_wolf", Game.player.global_position + Vector3(1, 0, 0))
	attacker._engage(Game.player)
	Game.player.hp_changed.connect(func():
		if observe_damage and world.loading:
			loading_hp_changes += 1)
	await wait_seconds(0.5)
	observe_damage = true
	await move_to(city_landing, "02_city")
	observe_damage = false
	check(loading_hp_changes == 0 and not Game.player.dead, "loading pauses both sides of active combat")
	attacker.queue_free()
	check(is_instance_valid(mob) and mob.dead and not mob.has_loot() and Game.pd.money == money_after_loot and Game.count_item("j_wolf_fang") == fangs_after_loot, "eviction preserves auto-looted inventory without refilling corpse")
	check(mob.global_position.y >= mob_pos.y - 1.0, "remote corpse retains terrain support")
	check(spawner._zone.zone_id == "vale", "mob respawn ownership stays in original region")
	check(spot._zone.zone_id == "vale", "gather ownership stays in original region")
	check(spot._slots[gather_slot].next == gather_due and not is_instance_valid(spot._slots[gather_slot].node), "harvest cooldown survives leaving")
	await move_to(wp(485, 127), "03_return")
	mob.loot_all()
	check(not mob.has_loot() and Game.pd["xp"] == xp_before and Game.pd.money == money_after_loot and Game.count_item("j_wolf_fang") == fangs_after_loot, "return and corpse interaction cannot duplicate loot or XP")
	check(spawner._slots[mob_slot].next == due, "mob respawn deadline unchanged by reload")
	check(not is_instance_valid(spot._slots[gather_slot].node), "return does not duplicate harvested node")
	# Force the registered deadlines to expire, checking one replacement and correct ownership.
	spawner._slots[mob_slot].next = Time.get_ticks_msec() - 1
	spot._slots[gather_slot].next = Time.get_ticks_msec() - 1
	await wait_seconds(2.0)
	var replacement: Mob = spawner._slots[mob_slot].node
	check(is_instance_valid(replacement) and replacement != mob and replacement.get_parent() == world.zones.vale.units_root, "expired mob slot respawns once in owning zone")
	check(is_instance_valid(spot._slots[gather_slot].node), "expired gather slot respawns")
	# Walk a continuous route through terrain tile edges and the shared region boundary.
	await move_to(wp(100, 490), "04_seam_start")
	stream.max_job_us = 0
	measure_frames = true
	var walk_samples := 0
	var holes := 0
	while Game.player.global_position.x > -110.0:
		var p: Player = Game.player
		var dt := get_process_delta_time()
		p.global_position.x -= 9.0 * minf(dt, 0.1)
		var ground := U.ground_height(get_tree(), p.global_position.x, p.global_position.z, 0)
		if p.global_position.y < ground - 1.0:
			holes += 1
		walk_samples += 1
		await get_tree().process_frame
	measure_frames = false
	check(holes == 0, "continuous seam walk has no terrain fall-through (%d samples)" % walk_samples)
	check(Game.pd.zone == "tidewind", "continuous seam walk changes region")
	await shot("05_seam_end")
	samples.append(stream.stats().merged({"label": "walking"}))
	# Full-resolution tile colliders on both sides of internal and region seams.
	for x in [-80.01, -79.99, -0.01, 0.01, 79.99, 80.01]:
		var p := wp(x, 490)
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p - Vector3.UP * 3.0, 1)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y - p.y) < 0.3, "terrain seam collision x=%.2f" % x)
	for i in 2:
		await move_to(city_landing, "06_city_%d" % i)
		await move_to(wp(435, 500), "07_town_%d" % i)
	check(stream.stats().released > 0, "travel actually releases generated content")
	check(GrassField.blockers.size() < 100, "grass blocker registry remains bounded")
	MapGen._cache.clear() # Rebuild at a different residency; cached identity alone proves nothing.
	var map_after := MapGen.for_current(world.zone)[0] as Texture2D
	check(map_after.get_image().get_data().hex_encode().sha256_text() == map_hash, "full world map independent of chunk residency")
	var gate: ModelProp = world.zones.tidewind.get_node("Buildings/gate_180")
	Game.pd.flags.erase("city_access")
	var gate_landing := gate.global_position + gate.global_transform.basis * Vector3(0, 0, 20)
	gate_landing.y = U.ground_height(get_tree(), gate_landing.x, gate_landing.z)
	await move_to(gate_landing, "08_locked_gate")
	gate.refresh_gate()
	check(gate._gen.get_node_or_null("Barrier") != null, "locked gate has collision barrier")
	await move_to(city_landing, "09_gate_away")
	Game.pd.flags.city_access = true
	world.zone.refresh_gates()
	await move_to(gate_landing, "10_unlocked_gate")
	check(gate._gen.get_node_or_null("Barrier") == null, "quest flag survives gate unloading and rebuilding")
	Game.player.pet = world.spawn_pet(Game.player, "hound")
	await move_to(wp(485, 127), "11_pet_teleport")
	check(is_instance_valid(Game.player.pet) and U.flat_dist(Game.player.pet.global_position, Game.player.global_position) < 8.0, "pet travels with owner after prewarm")
	await world.respawn_player_at_graveyard()
	check(world.ground_ready(Game.player.global_position), "graveyard also prepares landing")
	# Start asset requests for a distant destination, then immediately replace the world.
	stream.request(wp(435, 500))
	var pending_assets := 0
	for i in stream._assets.size() * 2 + 4:
		stream._poll_assets()
		pending_assets = stream._assets.values().filter(func(a): return a.pending and a.started).size()
		if pending_assets > 0:
			break
	check(pending_assets > 0, "transition test has an actual unconsumed background request")
	print("STREAM pending assets before instance transition: ", pending_assets)
	await world.travel("sanctum", "start")
	check(world.streamer == null and world.zone.zone_id == "sanctum", "instance uses independent lifecycle")
	await world.travel("vale", "start")
	check(world.streamer != null and world.zones.size() == 2, "return creates fresh overworld scheduler")
	check(not is_instance_valid(spawner) and not is_instance_valid(spot), "old refresh owners cannot leak into new world")
	frame_ms.sort()
	var result := {"initial_ms": initial_ms, "checks": checks, "samples": samples, "frame_count": frame_ms.size(), "walk_p95_ms": frame_ms[int(frame_ms.size() * 0.95)], "walk_p99_ms": frame_ms[int(frame_ms.size() * 0.99)], "walk_max_ms": frame_ms.back()}
	FileAccess.open(out + "/result.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	var failed := checks.filter(func(c): return not c.pass).size()
	print("STREAMING RESULT: ", checks.size(), " checks, ", failed, " failed; initial_ms=", initial_ms)
	Game.slot_index = -1
	get_tree().quit(1 if failed else 0)
