class_name WorldStream
extends Node
## Spatial residency for authored descriptors. Generated nodes/resources are released on eviction.
## A single scheduler owns all work and disappears with the world (no detached async callbacks).
const CELL := 120.0
const ACTOR_LOAD := 150.0
const ACTOR_KEEP := 230.0
const FRAME_BUDGET_US := 3000
const HYSTERESIS := 100.0
const MAX_RESOURCE_READS := 2

var regions: Array = []
var cells := {}
var records: Array = []
var pending: Array = []
var retiring: Array = []
var focus := Vector3.ZERO
var supports: Array = []
var _tick := 0.0
var preparing := false
var enabled := false
var generated := 0
var released := 0
var max_job_us := 0
var last_job := ""
var worst_job := ""
var _assets := {}

## Called BEFORE a Zone enters the SceneTree. No expensive _ready builds may run yet.
func register_zone(z: Zone) -> void:
	z.prepare_environment()
	z.streamed = true
	regions.append(z)
	_register(z, z)

func _register(n: Node, z: Zone) -> void:
	for c in n.get_children():
		if c is BrushTerrain:
			c.streamed = true
		elif c is Forest:
			_split_forest(c, z)
		elif c is CityHouses:
			_split_houses(c, z)
		elif c is CityKitLots:
			_split_kitlots(c, z)
		elif c is ModelProp or c is Prop:
			var extent: float = maxf(c.size.x, maxf(c.size.z, c.size.y))
			# Keep landmark silhouettes at larger distances; ordinary dressing stays near.
			var radius := clampf(extent * 16.0, 200.0, 1100.0)
			_add_record(c, z, radius, extent * 0.75 + 16.0)
		elif c is MobSpawner or c is GatherSpot or c is NpcSpot:
			z.actor_sources.append(c)
		else:
			_register(c, z)

func _add_record(n: Node3D, z: Zone, radius: float, extent: float = 0.0, proxy: Node3D = null, center: Vector3 = Vector3.ZERO) -> void:
	n.set_meta("stream_deferred", true)
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != z:
		if cur is Node3D:
			xf = cur.transform * xf
		cur = cur.get_parent()
	var p := z.position + xf * center
	var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	var paths: Array = n.stream_asset_paths() if n is ModelProp or n is Forest else []
	var rec := {"node": n, "pos": p, "radius": radius, "extent": extent, "active": false, "proxy": proxy, "cell": key, "paths": paths}
	records.append(rec)
	if not cells.has(key):
		cells[key] = []
	cells[key].append(rec)

func _split_forest(f: Forest, z: Zone) -> void:
	f.set_meta("stream_deferred", true)
	if f.kind in ["grass", "flower"] and Game.settings.get("grass", true):
		return
	var groups := {}
	for i in f.points.size():
		var p := f.points[i]
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(i)
	for key in groups:
		var part := Forest.new()
		part.name = "Stream_%d_%d" % [key.x, key.y]
		part.kind = f.kind
		part.color = f.color
		part.collide = f.collide
		part.position = Vector3((key.x + 0.5) * CELL, 0, (key.y + 0.5) * CELL)
		for i in groups[key]:
			part.points.append(f.points[i] - part.position)
			part.scales.append(f.scales[i] if i < f.scales.size() else 1.0)
			part.shapes.append(f.shapes[i] if i < f.shapes.size() else Vector3(0.0, 1.0, 1.0))
			part.point_ids.append(i)
		f.add_child(part)
		_add_record(part, z, 650.0 if f.kind not in ["grass", "flower", "bush"] else 220.0, CELL * 0.72)

## 模块化沿街楼：按 CELL 拆成分块节点，每块一条流式记录（近处 rebuild 出 MultiMesh，远处 stream_unload）
func _split_kitlots(k: CityKitLots, z: Zone) -> void:
	k.set_meta("stream_deferred", true)
	k._load_all()
	var groups := {}
	for i in k.count():
		var o := i * CityKitLots.STRIDE
		var key := Vector2i(floori(k.data[o + 1] / CELL), floori(k.data[o + 3] / CELL))
		if not groups.has(key):
			groups[key] = PackedFloat32Array()
		groups[key].append_array(k.data.slice(o, o + CityKitLots.STRIDE))
	# 封顶三角形按第一个顶点所在分块归属
	var cap_groups := {}
	for t in k.caps.size() / 10:
		var o := t * 10
		var ck := Vector2i(floori(k.caps[o] / CELL), floori(k.caps[o + 2] / CELL))
		if not cap_groups.has(ck):
			cap_groups[ck] = PackedFloat32Array()
		cap_groups[ck].append_array(k.caps.slice(o, o + 10))
		if not groups.has(ck):
			groups[ck] = PackedFloat32Array()
	for key in groups:
		var cell := CityKitLots.new()
		cell.name = "Kit_%d_%d" % [key.x, key.y]
		cell.pieces = k.pieces
		cell.palette = k.palette
		cell.data = groups[key]
		cell.caps = cap_groups.get(key, PackedFloat32Array())
		cell.cell_center = Vector3((key.x + 0.5) * CELL, 0, (key.y + 0.5) * CELL)
		cell.set_meta("stream_detail", true)
		cell.set_meta("stream_deferred", true)
		k.add_child(cell)
		_add_record(cell, z, 260.0, CELL, null, cell.cell_center)

func _split_houses(h: CityHouses, z: Zone) -> void:
	h.set_meta("stream_deferred", true)
	var groups := {}
	for i in h.count():
		var key := Vector2i(floori(h.data[i * 10] / CELL), floori(h.data[i * 10 + 2] / CELL))
		if not groups.has(key):
			groups[key] = PackedFloat32Array()
		groups[key].append_array(h.data.slice(i * 10, i * 10 + 10))
	for key in groups:
		var detail := CityHouses.new()
		detail.name = "Detail_%d_%d" % [key.x, key.y]
		detail.models = h.models
		detail.palette = h.palette
		detail.data = groups[key]
		detail.set_meta("stream_detail", true)
		# data positions remain in the original coordinate frame, including house overhangs.
		var proxy := CityHouses.new()
		proxy.name = "Horizon_%d_%d" % [key.x, key.y]
		proxy.models = h.models
		proxy.palette = h.palette
		proxy.data = groups[key]
		proxy.set_meta("stream_proxy", true)
		h.add_child(proxy)
		h.add_child(detail)
		_add_record(detail, z, 340.0, CELL, proxy, Vector3((key.x + 0.5) * CELL, 0, (key.y + 0.5) * CELL))

static func unit_pinned(u: Unit) -> bool:
	if u.dead or u.in_combat or u.hp < u.max_hp or not u.auras.is_empty() or not u.casting.is_empty():
		return true
	if u is Mob and u.state != Mob.S.IDLE:
		return true
	if Game.player and (Game.player.target == u or Game.player.combo_target == u):
		return true
	if Game.hud and Game.hud.windows_layer:
		for win in Game.hud.windows_layer.get_children():
			if win is NpcWindow and win.visible and win.npc == u:
				return true
			if win is BankWindow or win is TransmogWindow or win is AuctionWindow:
				if win.visible and win.service_npc == u:
					return true
	return false

func _collect_supports() -> void:
	supports.clear()
	for z in regions:
		for u in z.units_root.get_children():
			if u is Unit and not u.is_queued_for_deletion() and unit_pinned(u):
				supports.append(u.global_position)
				# Pin the return corridor as well as both endpoints during evade/leash recovery.
				if u is Mob and not u.dead:
					var steps := maxi(1, ceili(u.global_position.distance_to(u.spawn_pos) / 80.0))
					for i in range(1, steps + 1):
						supports.append(u.global_position.lerp(u.spawn_pos, float(i) / steps))

func request(p: Vector3) -> void:
	focus = p
	_collect_supports()
	for z in regions:
		if z.terrain:
			z.terrain.stream_request(focus, supports)
	pending.clear()
	retiring.clear()
	for rec in records:
		var d: float = U.flat_dist(rec.pos, focus) - rec.extent
		var held := false
		for anchor in supports:
			if U.flat_dist(rec.pos, anchor) - rec.extent < 96.0:
				held = true
				break
		if rec.active and d > rec.radius + HYSTERESIS and not held:
			retiring.append(rec)
		elif not rec.active and (d <= rec.radius or held):
			pending.append(rec)
	pending.sort_custom(func(a, b): return U.flat_dist(a.pos, focus) - a.extent < U.flat_dist(b.pos, focus) - b.extent)
	var needed := {}
	for rec in records:
		if (rec.active and not retiring.has(rec)) or pending.has(rec):
			for path in rec.paths:
				needed[path] = true
	for path in _assets:
		_assets[path].needed = needed.has(path)
	for path in needed:
		if not _assets.has(path) and ResourceLoader.exists(path):
			_assets[path] = {"resource": null, "pending": true, "started": false, "needed": true}

## Commit/release at most one resource per job; a burst of completed loads is not one frame's work.
func _poll_assets() -> bool:
	var in_flight := 0
	for path in _assets.keys():
		var asset: Dictionary = _assets[path]
		if not asset.needed and (not asset.pending or not asset.started):
			last_job = "asset_release/" + path.get_file()
			_assets.erase(path)
			return true
		if asset.pending and asset.started:
			in_flight += 1
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				last_job = "asset_commit/" + path.get_file()
				asset.resource = ResourceLoader.load_threaded_get(path)
				asset.pending = false
				return true
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				asset.pending = false
				push_warning("Stream asset failed: " + path)
				return true
	if in_flight < MAX_RESOURCE_READS:
		for path in _assets:
			var asset: Dictionary = _assets[path]
			if asset.pending and not asset.started and asset.needed:
				last_job = "asset_request/" + path.get_file()
				ResourceLoader.load_threaded_request(path)
				asset.started = true
				return true
	return false

func _assets_ready(rec: Dictionary) -> bool:
	for path in rec.paths:
		if _assets.has(path) and _assets[path].pending:
			return false
	return true

## ResourceLoader is engine-global: consume outstanding requests before replacing this world.
func shutdown() -> void:
	enabled = false
	pending.clear()
	retiring.clear()
	for path in _assets:
		_assets[path].needed = false
	while not _assets.is_empty():
		_poll_assets()
		if not _assets.is_empty():
			await get_tree().process_frame

func _process(delta: float) -> void:
	if not enabled or preparing or Game.world.simulation_suspended() or not is_instance_valid(Game.player):
		return
	_tick -= delta
	if _tick <= 0.0 or U.flat_dist(focus, Game.player.global_position) > 20.0:
		_tick = 0.25
		request(Game.player.global_position)
	_run_budget(FRAME_BUDGET_US)

func _run_budget(budget: int) -> void:
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < budget:
		var before := Time.get_ticks_usec()
		if not _step():
			break
		var elapsed := Time.get_ticks_usec() - before
		if elapsed > max_job_us:
			max_job_us = elapsed
			worst_job = last_job

func _step() -> bool:
	for z in regions:
		if z.terrain and z.terrain.stream_step():
			last_job = "terrain/" + z.zone_id
			return true
	if _poll_assets():
		return true
	for i in pending.size():
		var rec: Dictionary = pending[i]
		if not _assets_ready(rec):
			continue
		pending.remove_at(i)
		last_job = String(rec.node.name)
		rec.node.rebuild()
		rec.active = true
		if is_instance_valid(rec.proxy):
			rec.proxy.visible = false
		generated += 1
		return true
	if not retiring.is_empty():
		var rec: Dictionary = retiring.pop_front()
		last_job = "release/" + String(rec.node.name)
		rec.node.stream_unload()
		rec.active = false
		if is_instance_valid(rec.proxy):
			rec.proxy.visible = true
		released += 1
		return true
	if preparing or not pending.is_empty():
		return false
	for z in regions:
		if z.stream_actor_step(focus):
			last_job = "actor/" + z.zone_id
			return true
	return false

func prepare(p: Vector3) -> void:
	preparing = true
	request(p)
	var start := Time.get_ticks_msec()
	while _has_pending():
		_run_budget(8000)
		await get_tree().process_frame
	await get_tree().physics_frame
	# The first physics frame registers newly-created collision before actors snap to it.
	while true:
		var did_work := false
		for z in regions:
			if z.stream_actor_step(p):
				did_work = true
				break
		if not did_work:
			break
		await get_tree().process_frame
	await get_tree().physics_frame
	preparing = false
	enabled = true
	print("[stream] prepared %s in %d ms; %s" % [p, Time.get_ticks_msec() - start, JSON.stringify(stats())])

func _has_pending() -> bool:
	if not pending.is_empty() or not retiring.is_empty():
		return true
	for z in regions:
		if z.terrain and not z.terrain._terrain_queue.is_empty():
			return true
	return false

func ground_ready(p: Vector3) -> bool:
	for z in regions:
		if z.terrain and not z.terrain.collision_ready(p):
			return false
	return true

func stats() -> Dictionary:
	var active := 0
	var terrain_tiles := 0
	for rec in records:
		active += int(rec.active)
	for z in regions:
		if z.terrain:
			terrain_tiles += z.terrain._chunks.size()
	return {"static_active": active, "static_total": records.size(), "terrain_detail": terrain_tiles, "units": get_tree().get_nodes_in_group("units").size(), "generated": generated, "released": released, "max_job_ms": max_job_us / 1000.0, "worst_job": worst_job}
