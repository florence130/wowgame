extends Node

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	get_tree().change_scene_to_file.call_deferred("res://scenes/boot.tscn")
	await get_tree().create_timer(2.0).timeout
	Game.slot_index = -1
	Game.new_character("星穹旅人", "mage", DB.random_appearance(13, "f"))
	var front := get_tree().current_scene
	front.saves = [{"slot": -1, "data": Game.pd.duplicate(true)}]
	front._show_select()
	front.set_process_unhandled_input(false)
	front.avatar.rotation = Vector3(0, PI, 0)
	print("MOON FIXTURE input disabled; avatar yaw=", front.avatar.rotation.y)
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.local/terrain_unify_20261011/final/selection.png")
	print("MOON CAPTURE memory slot=-1")
	get_tree().quit()
