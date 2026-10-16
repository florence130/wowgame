extends "res://tests/art_style.gd"

func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	await capture("home_wing_window_after", 456, 513, 180, 11, -0.16, 11.0, "clear")
	get_tree().quit(0)
