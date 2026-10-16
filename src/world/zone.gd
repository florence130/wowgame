class_name Zone
extends Node3D
## 区域场景根节点：运行时生成怪物/NPC/采集物，提供子区域、水位、出生点查询

@export var zone_id: String = "vale"
@export var default_music: String = "field"

var units_root: Node3D
var pois: Array = []
var spawn_points := {}
var streamed := false
var actor_sources: Array = []
var npc_instances := {}
var npc_saved := {}
var terrain: BrushTerrain
var _environment_prepared := false

## Stream登记前调用；非stream加载在父节点_enter_tree中先于地形_ready调用。
func prepare_environment() -> void:
	if _environment_prepared or Engine.is_editor_hint():
		return
	_environment_prepared = true
	for c in get_children():
		if c is BrushTerrain:
			terrain = c
			break
	if zone_id == "vale":
		preload("res://src/world/vale_runtime_patch.gd").apply(self)
		preload("res://src/world/village_composition.gd").apply(self)
	else:
		preload("res://src/world/vale_runtime_patch.gd").apply_tent_pads(self)

func _enter_tree() -> void:
	prepare_environment()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	units_root = Node3D.new()
	units_root.name = "Units"
	add_child(units_root)
	# 只找本区域自己的地形（无缝大世界里同时加载多个区域）
	for c in get_children():
		if c is BrushTerrain:
			terrain = c
			break
	if terrain == null:
		terrain = get_tree().get_first_node_in_group("terrain") as BrushTerrain
	_collect(self)

func _collect(n: Node) -> void:
	for c in n.get_children():
		if c is POI:
			pois.append(c)
		elif c is Marker3D and c.get_parent().name == "SpawnPoints":
			spawn_points[String(c.name)] = c
		_collect(c)

## 由 World 在玩家进入后调用
func populate() -> void:
	if not streamed:
		_populate(self)
	pois.sort_custom(func(a, b): return a.priority > b.priority or (a.priority == b.priority and a.radius < b.radius))

func _populate(n: Node) -> void:
	for c in n.get_children():
		if c is MobSpawner:
			c.spawn_all(self)
		elif c is NpcSpot:
			_spawn_npc(c)
		elif c is GatherSpot:
			c.spawn_all(self)
		elif c != units_root:
			_populate(c)

func _snap(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	# 从出生点上方 3m 开始向下找地面：从高处打会先命中屋顶/雨棚/穹顶，把室内或檐下的 NPC 放到房顶上
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -80, 0), 1)
	var r := space.intersect_ray(q)
	if not r.is_empty():
		return r["position"] + Vector3(0, 0.1, 0)
	if terrain:
		p.y = terrain.get_height_global(p.x, p.z) + 0.1
	return p

func spawn_mob(id: String, pos: Vector3, lvl: int = 0) -> Mob:
	var m := Mob.new()
	m.name = "%s_%d" % [id, randi() % 100000]
	units_root.add_child(m)
	m.init_mob(id, lvl)
	m.global_position = _snap(pos)
	m.spawn_pos = m.global_position
	return m

func _spawn_npc(s: NpcSpot) -> NPC:
	var n := NPC.new()
	n.name = "npc_" + s.npc_id
	units_root.add_child(n)
	n.init_npc(s.npc_id, s.seed_v)
	n.global_position = _snap(s.global_position)
	n.rotation.y = s.global_rotation.y
	n.home_yaw = n.rotation.y
	n.spawn_pos = n.global_position
	if s.wander >= 0.0:
		n.wander_radius = s.wander
	for p in s.patrol:
		n.patrol.append(s.global_position + p)
	return n

func water_level() -> float:
	if terrain:
		return terrain.water_level_global()
	return -10000.0

func subzone_at(p: Vector3) -> String:
	if Game.player:
		Game.player.in_rest_area = false
	for poi in pois:
		if U.flat_dist(poi.global_position, p) <= poi.radius:
			_on_poi(poi)
			return poi.title
	return ""

var _explored_this := {}
func _on_poi(poi: POI) -> void:
	if poi.poi_id == "" or _explored_this.has(poi.poi_id):
		_update_rest(poi)
		return
	_explored_this[poi.poi_id] = true
	Game.on_explore(poi.poi_id)
	if not Game.pd["explored"].has(poi.poi_id):
		Game.pd["explored"][poi.poi_id] = true
		if poi.explore_xp:
			var xp := int(DB.xp_to_next(Game.pd["level"]) * 0.04)
			Game.msg("发现新区域：%s" % poi.title, Color("ffd040"))
			Game.give_xp(xp, "explore")
		# 成就：探索类（地点数 / 具体地点）在这里判定，pd["explored"] 刚写好
		Achieve.evaluate()
	_update_rest(poi)

func _update_rest(poi: POI) -> void:
	if Game.player:
		Game.player.in_rest_area = poi.rest_area and U.flat_dist(poi.global_position, Game.player.global_position) <= poi.radius

func music_mode(pos: Vector3 = Vector3.INF) -> String:
	var period := "night" if Game.time_of_day < 5.5 or Game.time_of_day > 20.0 else "day"
	var theme := "sanctum" if default_music == "dungeon" else ("tidewind" if zone_id == "tidewind" else "vale")
	if pos.is_finite():
		for p in pois:
			if String(p.poi_id) == "poi_solenne" and U.flat_dist(pos, p.global_position) <= p.radius:
				theme = "city"
				break
	return "%s_%s" % [theme, period]

func ambience(pos: Vector3) -> String:
	if default_music == "dungeon":
		return ""
	for p in pois:
		if String(p.poi_id) == "poi_solenne" and U.flat_dist(pos, p.global_position) <= 300.0:
			return "village"
	return "forest"

func get_spawn(name: String) -> Node3D:
	return spawn_points.get(name)

func nearest_graveyard(p: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for k in spawn_points:
		if String(k).begins_with("gy_"):
			var d: float = spawn_points[k].global_position.distance_to(p)
			if d < bd:
				bd = d
				best = spawn_points[k]
	if best == null and spawn_points.size() > 0:
		best = spawn_points.values()[0]
	return best

func refresh_gates() -> void:
	for g in get_tree().get_nodes_in_group("gates"):
		g.refresh_gate()

## One expensive actor operation at a time; markers and slot clocks stay resident.
func stream_actor_step(p: Vector3) -> bool:
	for s in actor_sources:
		if s is MobSpawner or s is GatherSpot:
			if s.stream_step(self, p):
				return true
		elif s is NpcSpot:
			var n: NPC = npc_instances.get(s)
			if is_instance_valid(n):
				if U.flat_dist(n.global_position, p) > WorldStream.ACTOR_KEEP and not WorldStream.unit_pinned(n):
					npc_saved[s] = [n.global_position, n.rotation.y, n._patrol_i]
					npc_instances.erase(s)
					n.queue_free()
					return true
			elif U.flat_dist(npc_saved[s][0] if npc_saved.has(s) else s.global_position, p) < WorldStream.ACTOR_LOAD:
				n = _spawn_npc(s)
				if npc_saved.has(s):
					var state: Array = npc_saved[s]
					n.global_position = state[0]
					n.rotation.y = state[1]
					n._patrol_i = state[2]
				npc_instances[s] = n
				return true
	return false
