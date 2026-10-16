extends Node

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	print("AUDIO ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func _ready() -> void:
	Game.slot_index = -1
	Game.new_character("Audio fixture", "warrior", DB.random_appearance(7, "f"))
	var old_volume: float = Game.settings.get("sfx", 0.7)
	Game.settings["sfx"] = 0.7
	for key in Sfx.COMBAT_SOURCES:
		check(Sfx._streams.has(key), "stream " + key)
		if Sfx._streams.has(key):
			var stream: AudioStream = Sfx._streams[key]
			check(stream.get_length() > 0.15 and stream.get_length() <= 0.7, "short transient " + key)
	var listener := Camera3D.new()
	add_child(listener)
	listener.position = Vector3(0, 2, 8)
	listener.current = true
	for key in ["hit", "block", "water", "lightning", "fire", "frost", "shadow", "light"]:
		Sfx.play_at(key, Vector3(2, 0, 0), -10)
		check(Sfx._last_combat_sound.has(key), "spatial event " + key)
	var before: float = Sfx._last_combat_sound.get("hit", -1)
	Sfx.play_at("hit", Vector3.ZERO)
	check(Sfx._last_combat_sound.get("hit") == before, "same-frame impact burst suppressed")
	Game.settings["sfx"] = 0.0
	before = Sfx._last_combat_sound.get("swing", -1)
	Sfx.play_at("swing", Vector3.ZERO)
	check(Sfx._last_combat_sound.get("swing", -1) == before, "muted events suppressed")
	check(Sfx._spatial_players.size() == 16, "fixed spatial voice budget")
	Game.settings["sfx"] = old_volume
	print("AUDIO RESULT failed=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
