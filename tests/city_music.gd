extends Node
var checks: Array = []
class ProbePlayer extends Player:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
class ProbeWorld extends World:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
func _ready() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"pass": ok, "label": label})
	print(("CITY PASS " if ok else "CITY FAIL ") + label)
func run() -> void:
	Game.slot_index = -1
	Game.settings["music"] = 0.4
	var zone := Zone.new()
	var city := POI.new()
	city.poi_id = "poi_solenne"
	city.radius = 900.0
	city.position = Vector3(-204, 10.2, 246)
	add_child(city)
	zone.pois = [city]
	Game.zone = zone
	var player := ProbePlayer.new()
	add_child(player)
	player.global_position = city.global_position
	var world := ProbeWorld.new()
	add_child(world)
	world.zone = zone
	world.player = player
	Game.time_of_day = 12.0
	world._update_location_audio()
	check(Sfx._music_mode == "city" and Sfx._bgm.playing, "daytime city selects A")
	check(Sfx._bgm.stream.resource_path.ends_with("city_day_suno.ogg"), "city binds migrated asset")
	Sfx._bgm.seek(10.0)
	world._update_location_audio()
	check(Sfx._bgm.get_playback_position() >= 9.9, "same location poll does not restart")
	player.global_position = city.global_position + Vector3(901, 0, 0)
	world._update_location_audio()
	check(Sfx._music_mode == "field", "leaving configured city boundary restores field")
	player.global_position = city.global_position + Vector3(899, 0, 0)
	world._update_location_audio()
	check(Sfx._music_mode == "city", "entering configured city boundary selects A")
	Game.time_of_day = 21.0
	world._update_location_audio()
	check(Sfx._music_mode == "night", "city night does not play A")
	Game.time_of_day = 6.0
	world._update_location_audio()
	check(Sfx._music_mode == "city", "city dawn restores A")
	player.in_combat = true
	player._on_combat_changed(true)
	Game.time_of_day = 22.0
	world._update_location_audio()
	check(Sfx._music_mode == "combat", "night transition preserves combat")
	player.in_combat = false
	player._on_combat_changed(false)
	check(Sfx._music_mode == "night", "combat exit restores current time")
	Game.time_of_day = 12.0
	player.in_combat = true
	player._on_combat_changed(true)
	player.global_position = city.global_position + Vector3(901, 0, 0)
	world._update_location_audio()
	check(Sfx._music_mode == "combat", "city exit preserves combat")
	player.in_combat = false
	player._on_combat_changed(false)
	check(Sfx._music_mode == "field", "combat exit restores current position")
	Game.settings["music"] = 0.0
	await get_tree().create_timer(2.5).timeout
	player.global_position = city.global_position
	world._update_location_audio()
	check(not Sfx._bgm.playing, "muted city entry never starts playback")
	Game.zone = null
	zone.free()
	FileAccess.open("res://.local/music_reference_20261011/city_runtime.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	var fails := checks.filter(func(c): return not c["pass"]).size()
	print("CITY RESULT %d checks / %d failures" % [checks.size(), fails])
	get_tree().quit(1 if fails else 0)
