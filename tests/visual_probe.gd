extends Node
## 视觉验收截图：指定时刻与视点（区域坐标），每张等 4 秒后截屏到 .shots/visual/
## Godot --path . res://tests/visual_probe.tscn
const SHOTS := [
	# [名称, 区域, x, z, 朝向°, 镜头距离, 俯仰, 时刻]
	# v7.1（0.8 缩放）坐标
	["night_moon", "tidewind", -36, 490, 180, 10, 0.55, 23.0],
	["night_plaza", "tidewind", -36, 502, 0, 26, -0.12, 22.0],
	["axis_arch", "tidewind", -36, 258, 0, 14, 0.1, 10.0],
	["royal_stair", "tidewind", -36, -154, 0, 12, 0.12, 10.0],
	["palace_front", "tidewind", -36, -228, 0, 30, -0.05, 15.0],
	["mage_tower", "tidewind", -532, -42, 0, 20, 0.1, 17.0],
	["canal_water", "tidewind", 4, 252, 0, 10, -0.5, 11.0],
	["vale_meadow", "vale", 430, 230, 200, 7, -0.12, 10.0],
	["north_ridge", "tidewind", 76, -154, 0, 70, -0.18, 9.0],
	["harbor_sea", "tidewind", -276, 598, 180, 16, -0.25, 12.0],
	["hall_guild", "tidewind", -90, 391, 54, 4, 0.05, 14.0],
	["hall_night", "tidewind", -36, 329, 0, 4, 0.05, 22.0],
	["waystone_dusk", "tidewind", 3, 436, 90, 7, -0.1, 19.0],
]
var out := "res://.shots/visual"

func _ready() -> void:
	if not has_meta("runner"):
		var n := Node.new()
		n.set_script(get_script())
		n.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(n)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Game.new_character("视觉", "mage", DB.random_appearance(7, "f"))
	Game.slot_index = -1
	Game.pd["zone"] = "tidewind"
	Game.pd["level"] = 15
	Game.pd["flags"]["city_access"] = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	_run.call_deferred()

func _run() -> void:
	for i in 400:
		await get_tree().process_frame
		if Game.player and Game.world and not Game.world.loading:
			break
	await get_tree().create_timer(3.0).timeout
	var p: Player = Game.player
	var i := 0
	for s in SHOTS:
		Game.world.weather = "clear"
		Game.world.weather_amt = 0.0
		Game.world.weather_t = 9999.0
		Game.time_of_day = s[7]
		var w := Vector3(s[2], 80, s[3]) + WorldLayout.offset(s[1])
		Game.world.streamer.prepare(w)
		var gy := U.ground_height(get_tree(), w.x, w.z, 160.0)
		if String(s[0]).begins_with("hall_"):
			var hf := GenCityV7.hall_floor_at(s[2], s[3])
			if hf != INF: gy = hf + WorldLayout.offset(s[1]).y
		p.global_position = Vector3(w.x, gy + 0.5, w.z)
		p.rotation.y = deg_to_rad(s[4])
		p.cam_yaw = p.rotation.y
		p.cam_dist_target = s[5]
		p.cam_pitch = s[6]
		await get_tree().create_timer(4.0 if s[1] == "tidewind" else 10.0).timeout
		Game.time_of_day = s[7]
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(out) + "/%02d_%s.png" % [i, s[0]])
		print("VISUAL ", s[0])
		if String(s[0]).begins_with("hall_"):
			var best: OmniLight3D = null
			for l in get_tree().root.find_children("hall_*", "OmniLight3D", true, false):
				if best == null or (l as Node3D).global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
					best = l
			if best:
				print("  HALL_LIGHT %s in_tree=%s vis=%s pos=%s player=%s cam=%s" % [best.name, best.is_inside_tree(), best.is_visible_in_tree(), best.global_position, p.global_position, get_viewport().get_camera_3d().global_position])
			else:
				print("  HALL_LIGHT none found")
		i += 1
	print("VISUAL DONE")
	get_tree().quit()
