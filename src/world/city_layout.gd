class_name CityLayout
extends RefCounted
## One-time Solenne position migration (v4/v5 -> v7). v7 doubles the city northward,
## so the new walled rectangle is migrated as well as the frozen v4 envelope. This class never saves files,
## touches Game, grants access, or mutates its input dictionary.
## Call after WorldLayout's legacy world-coordinate migration.

const SAVE_VER := 8   # v7.1：全城 0.8 缩放，旧 v7 城内存档位置一律迁到旅店 / 东门
const CITY_ZONE := "tidewind"
const INN_SPAWN := "city_inn_safe"
const GATE_SPAWN := "gy_gate"
const CITY_SCENE := "res://scenes/zones/tidewind_highlands.tscn"
const INN_FALLBACK := Vector3(-180, 27, 462)
const GATE_FALLBACK := Vector3(324, 80, 480)

# Frozen v4 urban envelope: old landward wall, western shore, harbor and bay.
# It deliberately excludes the east-gate settlement and surrounding wilderness.
# Do not replace this with the new generator's changing city boundary.
const OLD_CITY := [
	Vector2(-940, 215), Vector2(-700, 200), Vector2(-450, 190),
	Vector2(-200, 184), Vector2(0, 190), Vector2(180, 205),
	Vector2(278, 262), Vector2(296, 360), Vector2(292, 470),
	Vector2(286, 560), Vector2(292, 680), Vector2(287, 800),
	Vector2(266, 900), Vector2(212, 980), Vector2(150, 1045),
	Vector2(0, 1060), Vector2(-120, 1050), Vector2(-330, 1225),
	Vector2(-560, 1140), Vector2(-700, 1140), Vector2(-820, 1130),
	Vector2(-880, 1040), Vector2(-900, 820), Vector2(-930, 700),
	Vector2(-950, 560), Vector2(-935, 420), Vector2(-955, 300),
]

static func is_old_city_position(zone_id: String, value: Variant) -> bool:
	if zone_id != CITY_ZONE or not value is Vector3:
		return false
	var position: Vector3 = value
	if position == Vector3.ZERO or not position.is_finite():
		return false
	var local := position - WorldLayout.offset(CITY_ZONE)
	if local.x > -1040.0 and local.x < 300.0 and local.z > -604.0 and local.z < 1090.0:
		return true   # v7 城墙内（含北扩区）
	return Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), PackedVector2Array(OLD_CITY))

static func _target(unlocked: bool, anchors: Dictionary) -> Vector3:
	var spawn_id := INN_SPAWN if unlocked else GATE_SPAWN
	var position: Variant = anchors.get(spawn_id)
	if position is Vector3 and (position as Vector3).is_finite():
		# Authored spawn markers are at the finished floor, saved positions at
		# a safe player height. World still performs its normal ground check.
		return position + Vector3.UP
	return WorldLayout.offset(CITY_ZONE) + (INN_FALLBACK if unlocked else GATE_FALLBACK)

static func migrate(source: Dictionary, anchors: Dictionary = {}) -> Dictionary:
	var result := source.duplicate(true)
	if int(source.get("city_ver", 0)) >= SAVE_VER:
		return result
	var flags: Variant = source.get("flags", {})
	var unlocked: bool = flags is Dictionary and bool(flags.get("city_access", false))
	var destination := _target(unlocked, anchors)
	if is_old_city_position(String(source.get("zone", "")), source.get("pos")):
		result["pos"] = destination
	var bind: Variant = result.get("bind")
	if bind is Dictionary and is_old_city_position(String(bind.get("zone", "")), bind.get("pos")):
		bind["pos"] = destination
		var spawn_id := INN_SPAWN if unlocked else GATE_SPAWN
		if anchors.has(spawn_id):
			bind["spawn"] = spawn_id
		else:
			# A missing marker must not make hearth() ignore the valid position
			# fallback by following a stale / nonexistent spawn ID instead.
			bind.erase("spawn")
	result["city_ver"] = SAVE_VER
	return result

static func anchors_from_scene(scene: PackedScene) -> Dictionary:
	# Read serialized transforms without instantiating buildings or terrain.
	# This also respects a transformed SpawnPoints parent.
	if scene == null:
		return {}
	var state := scene.get_state()
	var transforms := {}
	var targets := {}
	for i in state.get_node_count():
		var path := String(state.get_node_path(i))
		var transform := Transform3D.IDENTITY
		for j in state.get_node_property_count(i):
			if String(state.get_node_property_name(i, j)) == "transform":
				transform = state.get_node_property_value(i, j)
		transforms[path] = transform
		if state.get_node_type(i) == &"Marker3D" and path.get_base_dir().get_file() == "SpawnPoints":
			var name := path.get_file()
			if name in [INN_SPAWN, GATE_SPAWN]:
				targets[name] = path
	var anchors := {}
	for name in targets:
		var path: String = targets[name]
		var transform: Transform3D = transforms.get(path, Transform3D.IDENTITY)
		var parent := path.get_base_dir()
		while parent != "" and parent != ".":
			transform = transforms.get(parent, Transform3D.IDENTITY) * transform
			parent = parent.get_base_dir()
		transform = transforms.get(".", Transform3D.IDENTITY) * transform
		anchors[name] = WorldLayout.offset(CITY_ZONE) + transform.origin
	return anchors

static func scene_anchors() -> Dictionary:
	return anchors_from_scene(load(CITY_SCENE) as PackedScene)
