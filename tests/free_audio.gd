extends Node
class AudioPOI extends Node3D:
	var poi_id := "poi_solenne"
	var radius := 100.0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _ready() -> void:
	var settings: Dictionary = Game.settings.duplicate(true)
	var hour: float = Game.time_of_day
	Sfx.set_process(false)
	check(Sfx._streams.size() == 31, "31 recorded effects")
	check(Sfx._tracks.size() == 14, "14 looping music and ambience tracks")
	for key in ["menu", "vale_day", "city_day", "tidewind_day", "sanctum_day"]:
		check(Sfx._tracks["bgm:" + key].resource_path.begins_with("res://assets/audio/orchestral/"), "current full arrangement " + key)
	for stream in Sfx._streams.values(): check(stream.get_length() > 0.0, "effect length")
	for stream in Sfx._tracks.values():
		check(stream.get_length() > 1.0 and stream.loop, "loop enabled")
	var zone := Zone.new()
	for theme in ["vale", "tidewind", "sanctum"]:
		zone.zone_id = theme
		zone.default_music = "dungeon" if theme == "sanctum" else "field"
		Game.time_of_day = 12.0
		check(zone.music_mode() == theme + "_day", "map day " + theme)
		Game.time_of_day = 23.0
		check(zone.music_mode() == theme + "_night", "map night " + theme)
	zone.zone_id = "vale"
	zone.default_music = "field"
	add_child(zone)
	var poi := AudioPOI.new()
	zone.add_child(poi)
	zone.pois = [poi]
	for time in [5.5, 20.0, 12.0]:
		Game.time_of_day = time
		check(zone.music_mode(Vector3.ZERO) == "city_day", "city day boundary")
		check(zone.music_mode(Vector3(101, 0, 0)) == "vale_day", "city exterior")
	Game.time_of_day = 23.0
	check(zone.music_mode(Vector3.ZERO) == "city_night", "city night")
	zone.free()
	Game.settings["music"] = 0.5
	Game.settings["sfx"] = 0.7
	Sfx.set_music("menu")
	check(Sfx._bgm.playing, "menu playback")
	var player = Sfx._bgm
	Sfx.set_music("menu")
	check(Sfx._bgm == player, "same theme keeps player")
	for mode in ["vale_day", "combat", "vale_night", "city_night"]:
		Sfx.set_music(mode)
		check(Sfx._bgm.playing, "switch " + mode)
	Sfx._fade_audio(4.0, 0.5)
	check(not Sfx._bgm_out.playing, "old music stops")
	Sfx.set_ambience("forest")
	Sfx._fade_audio(4.0, 0.5)
	check(Sfx._amb.playing and Sfx._amb_mode == "forest_night", "night ambience")
	Game.settings["music"] = 0.0
	Sfx._fade_audio(4.0, 0.0)
	check(not Sfx._bgm.playing and Sfx._amb.playing, "music mute independent")
	Game.settings["sfx"] = 0.0
	Sfx._fade_audio(5.0, 0.5)
	check(Sfx._bgm.playing and not Sfx._amb.playing, "effects mute independent")
	Game.settings["sfx"] = 0.7
	Sfx._fade_audio(0.1, 0.5)
	check(Sfx._amb.playing, "ambience immediate restore")
	Sfx.set_ambience("")
	Sfx._fade_audio(5.0, 0.5)
	check(not Sfx._amb.playing, "clear ambience")
	Sfx.set_process(true)
	Game.settings["music"] = 0.5
	Sfx.set_music("vale_day")
	await get_tree().create_timer(4.0).timeout
	check(Sfx._bgm.playing and not Sfx._bgm_out.playing, "real frame fade completes")
	Sfx.set_music("combat")
	await get_tree().create_timer(0.1).timeout
	Sfx.set_music("city_night")
	await get_tree().create_timer(4.0).timeout
	check(Sfx._bgm.playing and not Sfx._bgm_out.playing, "rapid frame switch completes")
	Game.settings = settings
	Game.time_of_day = hour
	Sfx.set_process(false)
	for p in [Sfx._bgm, Sfx._bgm_out, Sfx._amb, Sfx._amb_out]:
		p.stop()
		p.stream = null
	await get_tree().process_frame
	print("FREE_AUDIO failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
