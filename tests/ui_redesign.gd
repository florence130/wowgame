extends Node
## Runtime interaction/layout evidence. Never creates, edits or deletes character saves.
var front: Node3D
var checks: Array = []
var out := "res://.shots/canticum_ui_20261011/v11"
var original_settings: Dictionary
var original_settings_bytes: PackedByteArray
var settings_existed := false
var motion_samples: Array = []

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	original_settings = Game.settings.duplicate(true)
	settings_existed = FileAccess.file_exists("user://settings.cfg")
	if settings_existed:
		original_settings_bytes = FileAccess.get_file_as_bytes("user://settings.cfg")
	get_tree().change_scene_to_file.call_deferred("res://scenes/boot.tscn")
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks.append({"pass": value, "label": label})
	print(("UI PASS " if value else "UI FAIL ") + label)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func capture(label: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + "/" + label + ".png")
	print("UI CAPTURE ", label)

func pointer(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)

func click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	pointer(at)
	await wait(0.1)
	print("UI CLICK ", control.name, " ", at, " hover=", get_viewport().gui_get_hovered_control())
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = at
		ev.global_position = at
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		get_viewport().push_input(ev, true)
	await get_tree().process_frame
	await wait(0.1)

func key_press(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.pressed = pressed
		get_viewport().push_input(ev, true)
		await get_tree().process_frame

func run() -> void:
	await wait(2.5)
	front = get_tree().current_scene
	print("UI USER DATA ", OS.get_user_data_dir())
	check(front.mode == "title", "boot opens title before character selection")
	check(front.ui.get_node("TitleMenu").get_child_count() == 3, "vertical start/settings/quit buttons")
	var screen: Vector2 = front.ui.size
	pointer(screen * 0.5)
	# Reassert injected motion each frame so unrelated desktop motion cannot replace it.
	for i in 90:
		pointer(screen * 0.5)
		await get_tree().process_frame
	await wait(1.5)
	await capture("01_title")
	var initial: Vector2 = front.backdrop.drift
	var elapsed_before: float = front.backdrop.elapsed
	var movement_start: float = front.backdrop.elapsed
	while front.backdrop.elapsed - movement_start < 0.12:
		pointer(Vector2(screen.x - 1, 2))
		await get_tree().process_frame
	var halfway: Vector2 = front.backdrop.drift
	while front.backdrop.elapsed - movement_start < 1.32:
		pointer(Vector2(screen.x - 1, 2))
		await get_tree().process_frame
	check(front.backdrop.drift.distance_to(initial) > 0.4, "mouse moves real background camera")
	check(halfway.distance_to(front.backdrop.drift) > 0.2, "camera eases instead of snapping")
	check(absf(front.backdrop.camera.position.x + 4.8) <= 0.51, "background camera bounded")
	check(front.backdrop.feather_particles.emitting and front.backdrop.elapsed > elapsed_before, "feather particle simulation active over time")
	await capture("02_title_mouse_edge")
	for frame in (0 if "fast" in OS.get_cmdline_user_args() else 48):
		var progress := frame / 47.0
		var x := (1.0 - progress * 2.0) if progress < 0.5 else (progress * 2.0 - 1.0)
		if frame < 36:
			pointer(Vector2(screen.x * x, screen.y * (0.35 + progress * 0.3)))
		await wait(0.08)
		await capture("motion_%02d" % frame)
		motion_samples.append({"frame": frame, "time_ms": Time.get_ticks_msec(), "camera": str(front.backdrop.camera.position), "drift": str(front.backdrop.drift)})
	Game.settings["menu_reduce_motion"] = true
	await wait(1.5)
	check(front.backdrop.drift.length() < 0.05, "reduced motion recenters camera")
	Game.settings["menu_reduce_motion"] = false
	print("UI PRE SETTINGS mode=", front.mode)
	await click(front.ui.get_node("TitleMenu").get_child(1))
	await wait(0.4)
	check(front.settings_window.visible and front.settings_window.page == "settings", "title settings opens working controls")
	await capture("03_settings")
	var title_menu: Control = front.ui.get_node("TitleMenu")
	check(title_menu.get_child(0).disabled and title_menu.get_child(2).disabled, "modal disables underlying start and quit keyboard actions")
	await click(title_menu.get_child(0))
	check(front.mode == "title", "modal intercepts clicks on underlying start")
	var checkbox: CheckBox
	for c in front.settings_window.body.get_children():
		if c is CheckBox and not c.disabled:
			checkbox = c
			break
	var selected: bool = checkbox.button_pressed
	await click(checkbox)
	check(checkbox.button_pressed != selected, "real pointer toggles settings checkbox")
	await capture("03b_settings_toggle")
	await click(checkbox)
	await key_press(KEY_ESCAPE)
	check(not front.settings_overlay.visible and not title_menu.get_child(0).disabled, "escape closes modal and restores title input")
	await click(title_menu.get_child(1))
	check(front.settings_window.page == "settings" and front.settings_window.visible, "settings reopens correct page")
	await click(front.settings_window.body.get_child(-1))
	var saved_list: Array = front.saves.duplicate()
	front.saves = []
	await click(front.ui.get_node("TitleMenu").get_child(0))
	await wait(0.5)
	check(front.mode == "create", "start with no saves opens creation")
	check(front.backdrop.camp.visible and not front.backdrop.ruins.visible, "night camp replaces ruins in character backdrop")
	check(front.backdrop.camp.terrain._mat.shader == BrushTerrain.TERRAIN_SHADER, "camp uses actual game terrain shader and painted layers")
	check(front.backdrop.camp.grass.mat.shader == GrassField.SHADER and front.backdrop.camp.grass.get_child_count() > 0, "camp uses actual game procedural grass chunks")
	check(front.backdrop.camp.grass.mesh == GrassField._source_mesh("grass_near"), "camp uses the same grass meshes as game world")
	check(front.backdrop.camp.fallen_log.scene_file_path.ends_with("camp_kit/fallen_log.tscn"), "camp instantiates library fallen log")
	check(front.backdrop.camp.campfire.scene_file_path.ends_with("camp_kit/campfire.tscn"), "camp instantiates library campfire")
	check(front.backdrop.camp.campfire.get_node("HearthCollision/CollisionShape3D").shape is CylinderShape3D, "library campfire keeps reusable collision")
	await capture("04_create")
	for control in front.ui.get_children():
		if control is Button and control.text == "返回":
			await click(control)
			break
	check(front.mode == "title", "real return button exits empty-save creation")
	# A disposable in-memory character supplies preview and HUD data.
	Game.slot_index = -1
	Game.new_character("星穹旅人", "mage", DB.random_appearance(13, "f"))
	Game.pd["new"] = false
	front.saves = [{"slot": -1, "data": Game.pd.duplicate(true)}]
	for i in 2:
		var sample: Dictionary = Game.pd.duplicate(true)
		sample["name"] = "营地旅人%d" % i
		sample["app"] = DB.random_appearance(26 + i, "f")
		front.saves.append({"slot": -1, "data": sample})
	await click(front.ui.get_node("TitleMenu").get_child(0))
	await wait(1.0)
	check(front.avatar_view.visible, "avatar remains sharp in separate transparent viewport")
	check(absf(front.avatar.rotation.y - PI) < 0.01 and front.stage.rotation == Vector3.ZERO, "selection resets avatar to face camera")
	check(front.backdrop.blur_material.get_shader_parameter("blur_amount") > 0.0, "selection background softened")
	await capture("05_selection")
	for button in front.ui.find_children("*", "Button", true, false):
		if button.text == "返回开始界面":
			await click(button)
			break
	await wait(0.4)
	check(not front.avatar_view.visible and not front.backdrop.camp.visible, "back returns to title and removes selection layers")
	# Repeated page changes must not accumulate background viewports.
	check(front.ui.get_child_count() < 10, "page switching releases old controls")
	front.saves = saved_list
	if "menu-only" in OS.get_cmdline_user_args():
		finish()
		return
	Game.slot_index = -1
	Game.new_character("星穹旅人", "mage", DB.random_appearance(13, "f"))
	Game.pd["new"] = false
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	await wait(1)
	while not is_instance_valid(Game.player) or Game.world.loading:
		await get_tree().process_frame
	await wait(3)
	Game.player.set_physics_process(false)
	var hud: HUD = Game.hud
	check(hud.player_frame.horizontal_resources, "player resource frame has no class portrait")
	check(hud.player_frame.global_position.y > hud.get_node("ActionBars").global_position.y + 85, "health and power below two action rows")
	check(hud.bar_slots.size() == 24, "all 24 bindings retain cooldown and drag/drop slots")
	check(hud.xp_bar.get_global_rect().position.y > hud.player_frame.get_global_rect().end.y, "experience on separate bottom row")
	check(absf(hud.xp_bar.size.x - hud.player_frame.size.x) < 1.0, "experience spans full width of both resource bars")
	check(absf(hud.minimap.size.x - hud.minimap.size.y) < 1, "minimap square viewport")
	var micro: Control = hud.get_node("MicroMenu").get_child(0)
	for b in micro.get_children():
		check(b is Button and b.text.is_empty(), "icon-only toolbar: " + b.accessibility_name)
	await capture("06_game_hud")
	Game.player.hp = Game.player.max_hp * 0.45
	Game.player.power = Game.player.max_power * 0.35
	await wait(1.2)
	check(absf(hud.player_frame._hp_disp - 0.45) < 0.03, "health updates from gameplay values")
	check(absf(hud.player_frame._pw_disp - 0.35) < 0.03, "mana updates from gameplay values")
	await capture("07_game_resources")
	for id in ["char", "bag", "spells", "talents", "achiev", "mounts", "mail", "prof", "quests", "dungeon", "map", "menu"]:
		var index := ["char", "bag", "spells", "talents", "achiev", "mounts", "mail", "prof", "quests", "dungeon", "map", "menu"].find(id)
		await click(micro.get_child(index))
		await wait(0.15)
		check(hud.win[hud._win_id(id)].visible, "real toolbar click opens " + id)
		hud.close_all()
	hud.toggle_window("char")
	await wait(0.7)
	await capture("08_character_inventory")
	hud.close_all()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait(1)
	check(hud.player_frame.get_global_rect().end.x < hud.get_node("MicroMenu").global_position.x, "resource row clear of toolbar at 1280x720")
	hud._refresh_mail_badge()
	check(hud.mail_btn.text.is_empty(), "mail refresh retains icon-only button")
	await capture("09_hud_1280")
	finish()

func finish() -> void:
	Game.settings = original_settings
	if settings_existed:
		FileAccess.open("user://settings.cfg", FileAccess.WRITE).store_buffer(original_settings_bytes)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	var failures := checks.filter(func(c): return not c["pass"])
	FileAccess.open(out + "/results.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures.size(), "user_data_dir": OS.get_user_data_dir(), "motion_samples": motion_samples}, "\t"))
	print("UI CHECKS ", checks.size(), " FAILURES ", failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
