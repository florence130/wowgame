extends Node
## Pure data migration checks. No World, terrain, player, or save-game loading.

const LAYOUT = preload("res://src/world/city_layout.gd")
var checks: Array[Dictionary] = []

func check(value: bool, label: String) -> void:
	checks.append({"pass": value, "label": label})
	print("CITY_LAYOUT ", "PASS " if value else "FAIL ", label)

func world_point(x: float, z: float, y: float = 20.0) -> Vector3:
	return WorldLayout.offset("tidewind") + Vector3(x, y, z)

func fixture(unlocked: bool = true) -> Dictionary:
	return {
		"zone": "tidewind", "pos": world_point(-120, 400), "world_ver": 3,
		"yaw": 0.7, "flags": {"city_access": unlocked, "unrelated": true},
		"bind": {"zone": "tidewind", "pos": world_point(154, 870), "name": "旅人之歌酒馆", "spawn": "old_inn"},
		"quests": {"q_d1": {"p": [1, 0, 1, 0, 0, 0, 0]}}, "qdone": {"q_c12": true},
		"fps": {"fp_solenne": true}, "explored": {"poi_market": true},
		"money": 2145, "bank": [{"id": "test_item", "n": 3}],
		"auction": [{"id": "lot", "price": 76}], "tmog": {"head": "test_hat"},
		"professions": {"smith": 42}, "recipes": {"test_recipe": true},
		"guild": {"name": "sample", "rank": 3}, "welfare_day": "2026-10-05",
	}

func _ready() -> void:
	Game.slot_index = -1
	Game.world = null
	var anchors := {
		LAYOUT.INN_SPAWN: world_point(-300, 470, 26),
		LAYOUT.GATE_SPAWN: world_point(324, 480, 23),
	}
	var old := fixture()
	var before := old.duplicate(true)
	var moved := LAYOUT.migrate(old, anchors)
	check(old == before, "pure function preserves input including nested bind and quest data")
	check(moved.pos == world_point(-300, 470, 27), "authorized old-city position uses current inn marker")
	check(moved.bind.pos == moved.pos and moved.bind.spawn == LAYOUT.INN_SPAWN, "city hearth is migrated to stable inn spawn")
	check(moved.city_ver == LAYOUT.SAVE_VER and moved.world_ver == 3, "independent city version preserves world version")
	for key in before:
		if key not in ["pos", "bind"]:
			check(moved[key] == before[key], "preserved non-location field: " + key)
	check(moved.bind.name == old.bind.name and moved.bind.zone == old.bind.zone, "bind identity is preserved")
	check(LAYOUT.migrate(moved, {LAYOUT.INN_SPAWN: Vector3(8, 9, 10)}) == moved, "idempotent even if future anchors move")
	var blocked := LAYOUT.migrate(fixture(false), anchors)
	check(blocked.pos == world_point(324, 480, 24), "locked old-city player goes to current gate outside city")
	check(blocked.bind.spawn == LAYOUT.GATE_SPAWN and not blocked.flags.city_access, "locked bind repairs without granting access")
	var elsewhere := fixture()
	elsewhere.zone = "vale"
	elsewhere.pos = Vector3(70, 28, 250)
	var other_result := LAYOUT.migrate(elsewhere, anchors)
	check(other_result.pos == elsewhere.pos, "player in another zone stays there")
	check(other_result.bind.pos == world_point(-300, 470, 27), "city bind repairs independently of current zone")
	var outside := fixture()
	outside.pos = world_point(400, 470)
	outside.bind.pos = world_point(560, 600)
	var outside_result := LAYOUT.migrate(outside, anchors)
	check(outside_result.pos == outside.pos and outside_result.bind == outside.bind, "outer settlement and wilderness positions are not moved")
	for point in [Vector2(-770, 300), Vector2(-792, 934), Vector2(-578, 1122), Vector2(40, 704), Vector2(-540, 690)]:
		check(LAYOUT.is_old_city_position("tidewind", world_point(point.x, point.y)), "v4 city envelope includes " + str(point))
	for point in [Vector2(318, 480), Vector2(370, 470), Vector2(420, 700), Vector2(-700, -700), Vector2(330, -200)]:
		check(not LAYOUT.is_old_city_position("tidewind", world_point(point.x, point.y)), "city envelope excludes wilderness " + str(point))
	for point in [Vector2(-700, 160), Vector2(-120, -480), Vector2(-740, -300)]:
		check(LAYOUT.is_old_city_position("tidewind", world_point(point.x, point.y)), "v7 north expansion is inside city " + str(point))
	var newborn := fixture()
	newborn["new"] = true
	newborn.pos = Vector3.ZERO
	newborn.bind = {"zone": "vale", "pos": Vector3.ZERO, "spawn": "abbey"}
	var new_result := LAYOUT.migrate(newborn, anchors)
	check(new_result.pos == Vector3.ZERO and new_result.bind == newborn.bind and new_result.new, "new + ZERO retains original start-spawn behavior")
	newborn.pos = world_point(-120, 400)
	check(LAYOUT.migrate(newborn, anchors).pos == world_point(-300, 470, 27), "new flag alone does not suppress a real legacy city position")
	var fallback := LAYOUT.migrate(fixture(), {})
	check(fallback.pos == world_point(-180, 462, 27) and not fallback.bind.has("spawn"), "missing inn marker has safe position fallback without stale spawn")
	var gate_fallback := LAYOUT.migrate(fixture(false), {})
	check(gate_fallback.pos == world_point(324, 480, 80), "missing gate marker uses safe above-ground fallback")
	var future := fixture()
	future.city_ver = LAYOUT.SAVE_VER + 1
	check(LAYOUT.migrate(future, anchors) == future, "future-version saves are untouched")
	for version in [1, 2]:
		var legacy := fixture()
		legacy.world_ver = version
		legacy.pos = Vector3(-120, 20, 400) + WorldLayout.legacy_offset(version, "tidewind")
		legacy.bind.pos = Vector3(154, 20, 870) + WorldLayout.legacy_offset(version, "tidewind")
		# Same existing coordinate conversion used immediately before the new
		# migration hook in World._ready().
		legacy.pos += WorldLayout.offset("tidewind") - WorldLayout.legacy_offset(version, "tidewind")
		legacy.bind.pos += WorldLayout.offset("tidewind") - WorldLayout.legacy_offset(version, "tidewind")
		legacy.world_ver = WorldLayout.SAVE_VER
		check(LAYOUT.migrate(legacy, anchors).pos == world_point(-300, 470, 27), "world v%d offset conversion precedes city migration" % version)
	_check_scene_state()
	var failures := checks.filter(func(c: Dictionary) -> bool: return not c.pass).size()
	var report := {"slot_index": Game.slot_index, "world_instanced": Game.world != null, "checks": checks, "failed": failures}
	FileAccess.open("res://tests/city_layout_migration.results.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CITY_LAYOUT RESULT: ", checks.size(), " checks, ", failures, " failed; slot=", Game.slot_index)
	get_tree().quit(1 if failures else 0)

func _check_scene_state() -> void:
	var root := Node3D.new()
	root.name = "City"
	var points := Node3D.new()
	points.name = "SpawnPoints"
	points.position = Vector3(3, 2, 4)
	root.add_child(points)
	points.owner = root
	var marker := Marker3D.new()
	marker.name = LAYOUT.INN_SPAWN
	marker.position = Vector3(-303, 24, 466)
	points.add_child(marker)
	marker.owner = root
	var packed := PackedScene.new()
	check(packed.pack(root) == OK, "tiny independent scene can serialize migration anchor")
	var resolved := LAYOUT.anchors_from_scene(packed)
	check(resolved.get(LAYOUT.INN_SPAWN) == world_point(-300, 470, 26), "serialized spawn resolves parent transform and overworld offset")
	check(LAYOUT.anchors_from_scene(null).is_empty(), "missing scene anchors remain optional")
	root.free()
