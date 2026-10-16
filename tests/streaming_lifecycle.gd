extends "res://tests/streaming.gd"
## Focused interruption test: real outstanding ResourceLoader request, world replacement, retry.

func _run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	var world: World = Game.world
	var old: WorldStream = world.streamer
	old.request(wp(435, 500))
	var requested: Array[String] = []
	for i in old._assets.size() * 2 + 4:
		old._poll_assets()
		for path in old._assets:
			if old._assets[path].pending and old._assets[path].started:
				requested.append(path)
		if not requested.is_empty():
			break
	check(not requested.is_empty(), "background request is started and not consumed")
	var statuses_before := {}
	for path in requested:
		statuses_before[path] = ResourceLoader.load_threaded_get_status(path)
	print("LIFECYCLE requests before transition: ", JSON.stringify(statuses_before))
	await world.travel("sanctum", "start")
	check(not is_instance_valid(old) and world.streamer == null, "old scheduler retired before instance")
	var statuses_after := {}
	for path in requested:
		statuses_after[path] = ResourceLoader.load_threaded_get_status(path)
		check(statuses_after[path] == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "request consumed on shutdown: " + path.get_file())
	await world.travel("vale", "start")
	await world._teleport_to(wp(435, 500))
	check(world.ground_ready(Game.player.global_position), "same assets can be requested by replacement world")
	check(world.streamer._assets.values().all(func(a): return not a.pending), "replacement prewarm completes all requests")
	var failed := checks.filter(func(c): return not c.pass).size()
	FileAccess.open(out + "/lifecycle.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "before": statuses_before, "after": statuses_after}, "\t"))
	print("LIFECYCLE RESULT: ", checks.size(), " checks, ", failed, " failed")
	get_tree().quit(1 if failed else 0)
