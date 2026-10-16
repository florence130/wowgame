extends Node
## Interactive visual fixture; all characters stay in memory with slot_index = -1.
var front: Node3D

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner",true)
		get_tree().root.add_child.call_deferred(runner)
		return
	get_tree().change_scene_to_file.call_deferred("res://scenes/boot.tscn")
	await get_tree().create_timer(1.0).timeout
	front = get_tree().current_scene
	DisplayServer.window_set_title("Canticum Turris - UI Preview (memory only)")
	Game.slot_index = -1
	Game.new_character("星穹旅人","mage",DB.random_appearance(13,"f"))
	front.saves = [{"slot":-1,"data":Game.pd.duplicate(true)}]
	for i in 2:
		var data: Dictionary = Game.pd.duplicate(true)
		data["name"] = "营地旅人%d" % (i+1)
		data["app"] = DB.random_appearance(26+i,"f")
		front.saves.append({"slot":-1,"data":data})
	print("UI PREVIEW READY; memory characters only")

func _input(event: InputEvent) -> void:
	if not is_instance_valid(front):
		return
	if event is InputEventMouseButton or event is InputEventKey:
		print("UI FIXTURE INPUT ", event.as_text(), " mode=", front.mode,
			" focus=", get_viewport().gui_get_focus_owner())
