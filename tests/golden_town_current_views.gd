extends "res://tests/art_style.gd"

func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	await capture("golden_town_ground_current", 435, 500, 0, 26, -0.35)
	await capture("golden_town_top_current", 435, 500, 0, 92, -1.05)
	await capture("golden_town_south_current", 435, 525, 180, 18, -0.22)
	await capture("golden_town_east_current", 466, 516, 90, 18, -0.22)
	FileAccess.open(out + "/golden_town_current_views.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "views": results}, "\t"))
	get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)
