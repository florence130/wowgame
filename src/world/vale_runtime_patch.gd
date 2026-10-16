class_name ValeRuntimePatch
extends RefCounted
## 在流式登记、地形网格/碰撞与草地建立之前整地。
## 使用实例私有数据，保留保存场景、新版模型与原始地形资源。

static func apply(zone: Zone) -> void:
	if zone == null or zone.terrain == null or zone.terrain.data == null:
		return
	var terrain := zone.terrain
	var original := terrain.data
	var data := original.duplicate() as TerrainData
	data.heights = original.heights.duplicate()
	data.control_a = original.control_a.duplicate()
	data.control_b = original.control_b.duplicate()
	terrain.data = data
	var nodes: Array[Node3D] = []
	_collect_props(zone, nodes)
	var origin := _relative(terrain, zone).origin
	var pads: Array = []
	# 建筑先于小菜圃；矿坑构件虽沿用kind=house，不能当房屋填平。
	for n in nodes:
		if n.get_parent().name != "Buildings" or not _is_building(n):
			continue
		var xf := _relative(n, zone)
		var half: Vector2 = Vector2(n.size.x, n.size.z) * 0.5
		var centre := data.sample(xf.origin.x - origin.x, xf.origin.z - origin.z) + origin.y
		# 临水地基至少高出水面1.6m。普通地基取现地中心，降低高侧、填平低侧。
		var floor_y := maxf(centre, data.water_level + origin.y + 1.6)
		var margin := data.cell_size * 1.4
		_flatten(data, origin, xf, half + Vector2.ONE * margin, floor_y, 10.0)
		_set_zone_y(n, zone, floor_y + 0.035)
		_paint(data, origin, xf, half + Vector2.ONE * 1.0, 2, 0.78, 3.5)
		pads.append([Vector2(xf.origin.x, xf.origin.z), floor_y])
	for n in nodes:
		if n.kind != "field":
			continue
		var xf := _relative(n, zone)
		var half: Vector2 = Vector2(n.size.x, n.size.z) * 0.5
		var floor_y := maxf(data.sample(xf.origin.x - origin.x, xf.origin.z - origin.z) + origin.y, data.water_level + origin.y + 1.7)
		# 房前的小菜圃沿用最近房基高度，不能把同一块平地重新压出斜坡。
		if maxf(n.size.x, n.size.z) < 8.0:
			var nearest := 20.0
			for pad in pads:
				var d: float = pad[0].distance_to(Vector2(xf.origin.x, xf.origin.z))
				if d < nearest:
					nearest = d
					floor_y = pad[1]
		_flatten(data, origin, xf, half + Vector2.ONE * (data.cell_size * 1.2), floor_y, 8.0)
		_set_zone_y(n, zone, floor_y)
		# 只铺泥地；内缩的条带由ModelProp独立贴地网格表示。
		_paint(data, origin, xf, half + Vector2.ONE * 0.45, 2, 1.0, 3.0)
	_level_tents(nodes, zone, data, origin)
	_protect_village_interiors(zone, nodes, data, origin)
	_resnap_details(zone, nodes, data, original, origin)

## Other zones share only the tent pads, never Vale's building/farm repair.
static func apply_tent_pads(zone: Zone) -> void:
	if zone == null or zone.terrain == null or zone.terrain.data == null:
		return
	var original := zone.terrain.data
	var data := original.duplicate() as TerrainData
	data.heights = original.heights.duplicate()
	data.control_a = original.control_a.duplicate()
	data.control_b = original.control_b.duplicate()
	zone.terrain.data = data
	var nodes: Array[Node3D] = []
	_collect_props(zone, nodes)
	var origin := _relative(zone.terrain, zone).origin
	_level_tents(nodes, zone, data, origin)
	_resnap_details(zone, nodes, data, original, origin)

static func _level_tents(nodes: Array[Node3D], zone: Zone, data: TerrainData, origin: Vector3) -> void:
	# Camp tents get a small, local level pad before their render/physics build.
	# Snapping to the lowest corner alone fixes floating but buries the opposite
	# corner on the steep lakeside and forest slopes.
	for n in nodes:
		if n.get_parent().name != "Props" or n.kind != "tent":
			continue
		var xf := _relative(n, zone)
		var half: Vector2 = Vector2(n.size.x, n.size.z) * 0.5
		var floor_y := data.sample(xf.origin.x - origin.x, xf.origin.z - origin.z) + origin.y
		# Include one full terrain cell beyond the authored footprint. The
		# imported tent mesh has a small overhang beyond its nominal size and
		# otherwise its outer corners can still sink into a steep lake bank.
		_flatten(data, origin, xf, half + Vector2.ONE * (data.cell_size * 1.5), floor_y, 2.0)
		_set_zone_y(n, zone, floor_y + 0.05)

static func _resnap_details(zone: Zone, nodes: Array[Node3D], data: TerrainData, original: TerrainData, origin: Vector3) -> void:
	# 修改后的坡肩小件、栅栏、营帐重新贴地；水中船/码头保留。
	for n in nodes:
		if n.get_parent().name != "Props" or n.kind in ["field", "tent", "boat", "pier", "bridge", "rail", "water_plane"]:
			continue
		if n.has_meta("interior_relocated"):
			continue
		var xf := _relative(n, zone)
		var before := original.sample(xf.origin.x - origin.x, xf.origin.z - origin.z)
		var after := data.sample(xf.origin.x - origin.x, xf.origin.z - origin.z)
		if absf(after - before) > 0.015:
			_set_zone_y(n, zone, xf.origin.y + after - before)
	# 已保存的森林实例随局部整地升降，避免树根和灌木悬空。
	for f in zone.find_children("*", "Node3D", true, false):
		if not (f is Forest):
			continue
		var xf := _relative(f, zone)
		var inv := xf.affine_inverse()
		for i in f.points.size():
			var p: Vector3 = xf * f.points[i]
			var lx := p.x - origin.x
			var lz := p.z - origin.z
			p.y += data.sample(lx, lz) - original.sample(lx, lz)
			f.points[i] = inv * p

## Later overlapping pads and vegetable beds can lift an earlier house edge.
## Protect every village interior after all pads; trim misplaced authored tree,
## bush and flower instances here, before the streamer builds their collisions.
static func _protect_village_interiors(zone: Zone, nodes: Array[Node3D], data: TerrainData, origin: Vector3) -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/village_kit/buildings.json"))
	var houses: Array = []
	for n in nodes:
		if not n is ModelProp or not n.asset_scene.contains("/village_kit/"):
			continue
		var id: String = n.asset_scene.get_file().get_basename()
		if not metadata.has(id):
			continue
		var m: Dictionary = metadata[id]
		var xf := _relative(n, zone)
		var half := Vector2(float(m.w), float(m.d)) * 0.5
		# Lowering only prevents the final pass from raising a neighbouring floor.
		var bounds := _bounds(data, origin, xf, half + Vector2.ONE * data.cell_size, 0.0)
		var inv := xf.affine_inverse()
		for iz in range(bounds.position.y, bounds.end.y):
			for ix in range(bounds.position.x, bounds.end.x):
				var p := origin + Vector3(ix * data.cell_size, 0, iz * data.cell_size)
				if _weight(p, inv, half + Vector2.ONE * data.cell_size, 0.001) > 0.0:
					data.set_h(ix, iz, minf(data.get_h(ix, iz), xf.origin.y - origin.y - 0.035))
		houses.append({"xf": xf, "inv": inv, "half": half, "door": Vector2(float(m.door[0]), float(m.door[1]))})
	# These objects were authored as outdoor decoration. Find the closest safe
	# exterior position rather than retaining their accidental indoor placement.
	for n in nodes:
		var weapon_stall: bool = n is ModelProp and n.asset_scene.ends_with("/mabi/weapon_stall.glb")
		if not weapon_stall and (n.get_parent().name != "Props" or not n.kind in ["flowerbed", "haystack", "basket", "sack"]):
			continue
		var xf := _relative(n, zone)
		var radius := maxf(n.size.x * xf.basis.x.length(), n.size.z * xf.basis.z.length()) * 0.5
		if _outside_houses(xf.origin, houses, radius, false):
			continue
		var found := false
		for distance in range(3, 26, 2):
			for step in 24:
				var angle := TAU * step / 24.0
				var candidate := xf.origin + Vector3(cos(angle), 0, sin(angle)) * distance
				if _outside_houses(candidate, houses, radius + 0.7, true):
					candidate.y = data.sample(candidate.x - origin.x, candidate.z - origin.z) + origin.y
					n.position = _relative(n.get_parent() as Node3D, zone).affine_inverse() * candidate
					n.set_meta("interior_relocated", true)
					found = true
					break
			if found:
				break
	for f in zone.find_children("*", "Node3D", true, false):
		if not f is Forest or f.kind == "grass":
			continue
		var xf := _relative(f, zone)
		var points := PackedVector3Array()
		var scales := PackedFloat32Array()
		var shapes := PackedVector3Array()
		var point_ids := PackedInt32Array()
		for i in f.points.size():
			var p: Vector3 = xf * f.points[i]
			var margin := 1.2 if f.kind in ["oak", "pine", "birch"] else 0.5
			if not _outside_houses(p, houses, margin, false):
				continue
			points.append(f.points[i])
			if i < f.scales.size(): scales.append(f.scales[i])
			if i < f.shapes.size(): shapes.append(f.shapes[i])
			point_ids.append(f.point_ids[i] if i < f.point_ids.size() else i)
		f.points = points
		f.scales = scales
		f.shapes = shapes
		f.point_ids = point_ids

static func _outside_houses(p: Vector3, houses: Array, margin: float, protect_doors: bool) -> bool:
	for house in houses:
		var q: Vector3 = house.inv * p
		var half: Vector2 = house.half
		if absf(q.x) < half.x + margin and absf(q.z) < half.y + margin:
			return false
		var door: Vector2 = house.door
		if protect_doors and absf(q.x - door.x) < 2.0 + margin and q.z > door.y - 1.0 and q.z < door.y + 7.0:
			return false
	return true

static func _collect_props(root: Node, out: Array[Node3D]) -> void:
	for c in root.get_children():
		if c is ModelProp or c is Prop:
			out.append(c)
		else:
			_collect_props(c, out)

static func _is_building(n: Node3D) -> bool:
	if n is ModelProp and (n.asset_scene.contains("/mabi/") or n.asset_scene.contains("weapon_stall")):
		return false
	return n.kind in ["house", "cottage", "abbey_house", "abbey_cottage", "abbey_chapel", "abbey_campanile", "windmill", "hall", "tower", "barn", "farmhouse"]

static func _relative(n: Node3D, zone: Zone) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != zone:
		if cur is Node3D:
			xf = cur.transform * xf
		cur = cur.get_parent()
	return xf

static func _set_zone_y(n: Node3D, zone: Zone, y: float) -> void:
	var p := _relative(n, zone).origin
	p.y = y
	var parent_xf := _relative(n.get_parent() as Node3D, zone)
	n.position = parent_xf.affine_inverse() * p

static func _bounds(data: TerrainData, origin: Vector3, xf: Transform3D, half: Vector2, falloff: float) -> Rect2i:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := xf * Vector3((half.x + falloff) * sx, 0, (half.y + falloff) * sz) - origin
			lo = lo.min(Vector2(p.x, p.z))
			hi = hi.max(Vector2(p.x, p.z))
	var a := Vector2i(maxi(0, floori(lo.x / data.cell_size)), maxi(0, floori(lo.y / data.cell_size)))
	var b := Vector2i(mini(data.resolution, ceili(hi.x / data.cell_size)), mini(data.resolution, ceili(hi.y / data.cell_size)))
	return Rect2i(a, b - a + Vector2i.ONE)

static func _weight(p: Vector3, inv: Transform3D, half: Vector2, falloff: float) -> float:
	var q := inv * p
	var outside := Vector2(maxf(absf(q.x) - half.x, 0.0), maxf(absf(q.z) - half.y, 0.0)).length()
	return 1.0 - smoothstep(0.0, falloff, outside)

static func _flatten(data: TerrainData, origin: Vector3, xf: Transform3D, half: Vector2, y: float, falloff: float) -> void:
	var bounds := _bounds(data, origin, xf, half, falloff)
	var inv := xf.affine_inverse()
	for z in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var p := origin + Vector3(x * data.cell_size, 0, z * data.cell_size)
			var w := _weight(p, inv, half, falloff)
			if w > 0:
				data.set_h(x, z, lerpf(data.get_h(x, z), y - origin.y, w))

static func _paint(data: TerrainData, origin: Vector3, xf: Transform3D, half: Vector2, layer: int, opacity: float, falloff: float) -> void:
	var bounds := _bounds(data, origin, xf, half, falloff)
	var inv := xf.affine_inverse()
	for z in range(bounds.position.y, mini(bounds.end.y, data.resolution)):
		for x in range(bounds.position.x, mini(bounds.end.x, data.resolution)):
			var p := origin + Vector3((x + 0.5) * data.cell_size, 0, (z + 0.5) * data.cell_size)
			var w := _weight(p, inv, half, falloff) * opacity
			if w > 0:
				data.paint_pixel(x, z, layer, w)
