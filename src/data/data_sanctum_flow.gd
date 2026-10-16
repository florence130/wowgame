class_name SanctumFlow
extends RefCounted
## Approved monastery polygons, shared with the saved Unity workshop scene.
const PATH := "res://assets/models/sanctum_unity_v2/layout.json"
static var _layout: Dictionary = {}

static func layout() -> Dictionary:
	if _layout.is_empty():
		_layout = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		# Narrative overlay leaves the approved source polygons untouched.
		var names := {"boss_lake":"碎帆·拉克","boss_sanctum_lantern":"缠殿者","boss_victor":"覆钟古根"}
		for boss in _layout.bosses:
			if names.has(boss.id):boss.name=names[boss.id]
		var gates := {"sanctum_ember_root":"旧储藏层入口","sanctum_ember_lake":"祈航殿侧门","sanctum_final_open":"旧出航钟台封门"}
		for gate in _layout.gates:gate.name=gates.get(gate.flag,gate.name)
	return _layout

static func rooms() -> Array:
	return layout().get("floors", [])

static func by_id(id: String) -> Dictionary:
	for floor in rooms():
		if floor.id == id:
			return floor
	return {}

static func polygon(floor: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in floor.polygon:
		pts.append(Vector2(p[0], p[1]))
	return pts

static func bounds(floor: Dictionary) -> Rect2:
	var pts := polygon(floor)
	var out := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		out = out.expand(p)
	return out

static func height(floor: Dictionary, p: Vector2) -> float:
	if not floor.has("slope"):
		return float(floor.level)
	var s: Dictionary = floor.slope
	if s.axis == "descent":
		return 18.0-4.0*clampf((p.x-64.0)/8.0,0,1)-6.0*clampf((130.0-p.y)/16.0,0,1)
	var v := p.x if s.axis == "x" else p.y
	var rise := (float(s.high) - float(s.low)) * clampf((v - float(s.a)) / (float(s.b) - float(s.a)), 0.0, 1.0)
	if s.has("flatten_after_x"):
		rise *= clampf((float(s.flatten_after_x) - p.x) / (float(s.flatten_after_x) - float(s.blend_from_x)), 0.0, 1.0)
	return float(s.low) + rise

static func floor_y(p: Vector2, phase: int = -1) -> float:
	var fallback := INF
	var preceding_phase := -1
	for floor in rooms():
		if floor.kind == "blocked" or not Geometry2D.is_point_in_polygon(p, polygon(floor)):
			continue
		var y := height(floor, p)
		if int(floor.phase) == phase:
			return y
		if phase >= 0 and int(floor.phase) <= phase:
			if int(floor.phase) > preceding_phase:
				preceding_phase = int(floor.phase)
				fallback = y
		elif preceding_phase < 0:
			fallback = minf(fallback, y)
	return fallback

static func is_walkable(p: Vector2, margin: float = 0.0) -> bool:
	for floor in rooms():
		if floor.kind == "blocked" or not bounds(floor).grow(margin).has_point(p):
			continue
		var pts := polygon(floor)
		if Geometry2D.is_point_in_polygon(p, pts):
			return true
		if margin > 0:
			for i in pts.size():
				if ZoneBuilder._seg_dist(p, pts[i], pts[(i + 1) % pts.size()]) <= margin:
					return true
	return false
