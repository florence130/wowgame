extends Node
## Menu is silent until its replacement is confirmed.
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	Game.slot_index = -1
	Game.settings["music"] = 0.4
	Sfx.set_music("city")
	var front: Node = load("res://scenes/boot.tscn").instantiate()
	add_child(front)
	await get_tree().create_timer(2.0).timeout
	var ok := Sfx._music_mode == "menu" and not Sfx._bgm.playing and not Sfx._bgm_on
	front._show_select()
	front._start_create()
	await get_tree().create_timer(0.3).timeout
	ok = ok and not Sfx._bgm.playing
	print("MENU SILENT ", ok)
	get_tree().quit(0 if ok else 1)
