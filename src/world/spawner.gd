@tool
class_name MobSpawner
extends EditorMarker
## 怪物刷新点：在 radius 范围内维持 count 只怪物

@export var mob_id: String = "young_wolf":
	set(v):
		mob_id = v
		_upd()
@export var count: int = 4:
	set(v):
		count = v
		_upd()
@export var radius: float = 15.0
@export var level_override: int = 0
@export var respawn: float = 60.0
@export var wander: float = 6.0
@export var patrol: PackedVector3Array = PackedVector3Array()
## 可选章节门槛：场景仍然保留刷怪点，但在前置任务完成前不生成高等级敌人。
@export var required_quest: String = ""
## 副本房间门槛：全部旗标满足后才允许刷怪。与任务门槛并行，避免把副本流程伪装成任务完成。
@export var required_flags: PackedStringArray = PackedStringArray()
## 首领已击败后不再在重进副本时重新生成；旗标由 Game.on_kill 写入。
@export var defeated_flag: String = ""
## Empty values preserve the open-world encounters.
@export var encounter_room: String = ""
@export var encounter_bounds := Rect2()

var _alive: Array = []
var _slots: Array = []
var _zone: Node

func _ready() -> void:
	_upd()
	if Engine.is_editor_hint():
		return

func _upd() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		_editor_label("%s x%d" % [mob_id, count], Color(1, 0.4, 0.3))

func spawn_all(zone: Node) -> void:
	_init_slots(zone)
	if not _unlocked():
		# 非流式场景也要能在玩家完成前置任务后即时启用刷新点。
		set_process(true)
		return
	for i in _slots.size():
		_spawn_one(zone, i)
	set_process(not zone.streamed)

func _init_slots(zone: Node) -> void:
	_zone = zone
	if not _slots.is_empty():
		return
	for i in count:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius if count > 1 else 0.0
		var p := global_position + Vector3(cos(a) * r, 0, sin(a) * r)
		_slots.append({"node": null, "pos": p, "level": level_override, "next": 0, "yaw": randf() * TAU, "patrol_i": 0})
	set_process(not zone.streamed)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_zone) or _zone.streamed or not _unlocked():
		return
	for i in _slots.size():
		if not is_instance_valid(_slots[i].node) and _slots[i].next <= Time.get_ticks_msec():
			_spawn_one(_zone, i)

func stream_step(zone: Node, p: Vector3) -> bool:
	_init_slots(zone)
	if not _unlocked():
		return false
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var m: Mob = slot.node
		if is_instance_valid(m):
			if U.flat_dist(m.global_position, p) > WorldStream.ACTOR_KEEP and not WorldStream.unit_pinned(m):
				slot.pos = m.global_position
				slot.yaw = m.rotation.y
				slot.patrol_i = m._patrol_i
				slot.node = null
				_alive.erase(m)
				m.queue_free()
				return true
		elif slot.next <= Time.get_ticks_msec() and U.flat_dist(slot.pos, p) < WorldStream.ACTOR_LOAD:
			_spawn_one(zone, i)
			return true
	return false

func _spawn_one(zone: Node, i: int = -1) -> void:
	if not _unlocked() or i < 0 or i >= _slots.size() or is_instance_valid(_slots[i].node):
		return
	var def: Dictionary = DB.mobs.get(mob_id, {})
	if def.is_empty():
		push_warning("未知怪物：" + mob_id)
		return
	var slot: Dictionary = _slots[i]
	var m: Mob = zone.spawn_mob(mob_id, slot.pos, slot.level)
	if m == null:
		return
	m.spawner = self
	m.encounter_room = encounter_room
	m.encounter_bounds = encounter_bounds
	m.set_meta("spawn_slot", i)
	if not slot.has("home"):
		slot.home = m.spawn_pos
	m.spawn_pos = slot.home
	slot.node = m
	slot.level = m.level
	m.wander_radius = wander if not def.get("boss", false) else 0.0
	m.rotation.y = slot.yaw
	m._patrol_i = slot.patrol_i
	if patrol.size() > 1 and i == 0:
		for pt in patrol:
			m.patrol.append(global_position + pt)
	_alive.append(m)

func _unlocked() -> bool:
	if defeated_flag != "" and is_instance_valid(Game) and Game.has_flag(defeated_flag):
		return false
	if required_quest != "" and (not is_instance_valid(Game) or not Game.pd.get("qdone", {}).has(required_quest)):
		return false
	if is_instance_valid(Game):
		for f in required_flags:
			if not Game.has_flag(String(f)):
				return false
	return true

func on_mob_died(m: Node) -> void:
	_alive.erase(m)
	var i: int = m.get_meta("spawn_slot", -1)
	if i < 0 or i >= _slots.size() or _slots[i].node != m:
		return
	var slot: Dictionary = _slots[i]
	# Corpses retain their own loot and expire normally; the spawn slot has a separate clock.
	slot.node = null
	slot.pos = slot.home
	slot.level = level_override
	slot.patrol_i = 0
	var def: Dictionary = DB.mobs.get(mob_id, {})
	var rt: float = def.get("respawn", respawn)
	slot.next = Time.get_ticks_msec() + int((rt + randf() * rt * 0.3) * 1000.0) if rt > 0.0 else 9223372036854775807
