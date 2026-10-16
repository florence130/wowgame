extends Node
## 音频验证：真实 BGM / 环境音的载入与循环、按区域与昼夜切换、战斗与静音的处理、程序化回退。
## 不写存档（slot = -1）。
var checks: Array = []
var out := "res://.local/audio_20261008"

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"pass": ok, "label": label})
	print(("AUDIO PASS " if ok else "AUDIO FAIL ") + label)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func character(cls: String = "warrior", level: int = 20) -> void:
	Game.slot_index = -1
	Game.new_character("音频验证", cls, DB.random_appearance(11, "m"))
	Game.pd["new"] = false
	Game.pd["level"] = level

# ================================================================ 资源
func data_checks() -> void:
	check(Sfx._tracks.has("bgm:field") and Sfx._tracks.has("bgm:night") and Sfx._tracks.has("bgm:dungeon"),
		"三段 BGM 都能载入（白天/夜晚/副本，共 %d 段）" % Sfx._tracks.size())
	check(Sfx._tracks.has("amb:village_day") and Sfx._tracks.has("amb:village_night"), "两段村庄环境音都能载入")
	var f: AudioStream = Sfx._tracks.get("bgm:field", null)
	var night: AudioStream = Sfx._tracks.get("bgm:night", null)
	var day: AudioStream = Sfx._tracks.get("amb:village_day", null)
	check(f is AudioStreamOggVorbis and (f as AudioStreamOggVorbis).loop, "白天 BGM 是循环 ogg")
	var d: AudioStream = Sfx._tracks.get("bgm:dungeon", null)
	check(d is AudioStreamOggVorbis and (d as AudioStreamOggVorbis).loop, "副本 BGM 是循环 ogg")
	check(night is AudioStreamWAV and (night as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "夜晚 BGM 是整曲循环的 wav")
	check(night != null and (night as AudioStreamWAV).get_length() >= 60.0, "夜晚 BGM 长度够长（%.0f 秒，循环不回卷太快）" % (night as AudioStreamWAV).get_length())
	check(day is AudioStreamWAV and (day as AudioStreamWAV).get_length() >= 5.0, "村庄环境音长度合理（%.0f 秒）" % (day as AudioStreamWAV).get_length())

# ================================================================ 切换逻辑
func switch_checks() -> void:
	character()
	Game.settings["music"] = 0.5
	Game.time_of_day = 12.0
	Sfx.set_music("field")
	await wait(2.6)
	check(Sfx._bgm_on and Sfx._bgm.playing, "白天：BGM 开始播放")
	check(Sfx._bgm.volume_db > -12.0, "BGM 音量已淡入到目标值（%.1f dB，音乐音量 50%%）" % Sfx._bgm.volume_db)
	Sfx.set_ambience("village")
	await wait(0.5)
	check(Sfx._amb_mode == "village_day" and Sfx._amb.playing, "白天城区：村庄环境音生效（%s）" % Sfx._amb_mode)
	Game.time_of_day = 22.0
	await wait(4.6)
	check(Sfx._amb_mode == "village_night", "入夜后环境音自动切到夜晚段（%s）" % Sfx._amb_mode)
	Sfx.set_music("night")
	await wait(0.4)
	check(Sfx._bgm_mode == "night" and Sfx._bgm.stream == Sfx._tracks["bgm:night"], "入夜后 BGM 切到夜晚曲")
	Sfx.set_music("dungeon")
	await wait(0.4)
	check(Sfx._bgm_mode == "dungeon" and Sfx._bgm.stream == Sfx._tracks["bgm:dungeon"], "进副本切到副本曲")
	var before: float = Sfx._bgm.volume_db
	Sfx.set_music("combat")
	await wait(1.2)
	check(not Sfx._bgm_on and Sfx._bgm.volume_db < before, "战斗中停掉环境 BGM（%.1f dB → %.1f dB）" % [before, Sfx._bgm.volume_db])
	Sfx.set_music("field")
	await wait(2.6)
	check(Sfx._bgm_on and Sfx._bgm.volume_db > -12.0, "脱离战斗后 BGM 回来（%.1f dB）" % Sfx._bgm.volume_db)
	# 静音：音乐音量为 0 时不应有声音
	Game.settings["music"] = 0.0
	Sfx.set_ambience("")
	await wait(3.0)
	check(Sfx._bgm.volume_db < -40.0, "音乐音量为 0 时 BGM 淡出（%.1f dB）" % Sfx._bgm.volume_db)
	check(Sfx._amb_target <= -79.0 or not Sfx._amb.playing, "关闭环境音后停播")
	Game.settings["music"] = 0.5
	# 程序化回退：没有真实音频的模式仍然会生成旋律
	Sfx.set_music("combat")
	check(Sfx.MUSIC_SCALES.has("combat"), "程序化回退仍保留战斗音型（%d 个模式）" % Sfx.MUSIC_SCALES.size())

# ================================================================ 世界里按区域切换
func enter_world() -> void:
	var old = Game.player
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player) or Game.player == old:
		await get_tree().process_frame
	await wait(1.2)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")

func world_checks() -> void:
	character()
	Game.settings["music"] = 0.5
	Game.time_of_day = 12.0
	await enter_world()
	var p: Player = Game.player
	check(Game.zone != null and Game.zone.ambience(p.global_position) == "", "晨露谷（没有城区兴趣点）不播放村庄环境音")
	check(Game.zone.music_mode() == "field", "白天野外音乐模式为 field（%s）" % Game.zone.music_mode())
	check(Sfx._bgm_mode == "field" and Sfx._bgm.playing, "进入野外后播放白天 BGM")
	# 传送到晴岚港城区中心
	Game.pd["flags"]["city_access"] = true
	var solenne: POI = null
	for z in Game.world.zones.values():
		for n in get_tree().get_nodes_in_group("poi"):
			if n is POI and String(n.poi_id) == "poi_solenne":
				solenne = n
	check(solenne != null, "找到晴岚港城区兴趣点")
	if solenne != null:
		Game.world.travel(Game.pd["zone"], "", solenne.global_position)
		# 传送要先预热目标区块（城区生成要几秒），轮询等玩家真的到位
		var t := 0.0
		while U.flat_dist(Game.player.global_position, solenne.global_position) > 25.0 and t < 30.0:
			await wait(0.5)
			t += 0.5
		check(U.flat_dist(Game.player.global_position, solenne.global_position) <= 25.0, "传送到晴岚港城区（用了 %.1f 秒）" % t)
		check(Game.zone.ambience(Game.player.global_position) == "village", "站到城区里时区域判定为村庄环境音")
		await wait(1.5)
		check(Sfx._amb_mode == "village_day" and Sfx._amb.playing, "城区里实际播起了环境音（%s）" % Sfx._amb_mode)
		await shot("city_ambience")
	# 离开城区 300m 之外应该关掉环境音
	if solenne != null:
		var out_pos: Vector3 = solenne.global_position + Vector3(430, 0, 0)
		out_pos.y = U.ground_height(get_tree(), out_pos.x, out_pos.z, out_pos.y) + 2.0
		Game.world.travel(Game.pd["zone"], "", out_pos)
		var t2 := 0.0
		while U.flat_dist(Game.player.global_position, out_pos) > 25.0 and t2 < 20.0:
			await wait(0.5)
			t2 += 0.5
		check(Game.zone.ambience(Game.player.global_position) == "",
			"离开城区 300m 之外不再有环境音（%.0fm）" % U.flat_dist(Game.player.global_position, solenne.global_position))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	data_checks()
	await switch_checks()
	if not "core" in OS.get_cmdline_user_args():
		await world_checks()
	var failures := checks.filter(func(c): return not c["pass"]).size()
	FileAccess.open(out + "/results.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	print("AUDIO RESULT %d PASS / %d FAIL" % [checks.size() - failures, failures])
	Game.slot_index = -1
	get_tree().quit(1 if failures else 0)
