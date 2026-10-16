@tool
class_name GatherSpot
extends EditorMarker
## 采集物刷新点（任务物品/草药/矿石）

@export var node_type: String = "herb_dew":
	set(v):
		node_type = v
		if Engine.is_editor_hint() and is_inside_tree():
			_editor_label("✿ %s x%d" % [node_type, count], Color(0.6, 1, 0.9))
@export var count: int = 6
@export var radius: float = 20.0
@export var respawn: float = 30.0

var _slots: Array = []
var _zone: Node

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_label("✿ %s x%d" % [node_type, count], Color(0.6, 1, 0.9))

func spawn_all(zone: Node) -> void:
	_init_slots(zone)
	for i in _slots.size():
		_spawn(zone, i)

func _init_slots(zone: Node) -> void:
	_zone = zone
	if not _slots.is_empty():
		return
	for i in count:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius
		var p := global_position + Vector3(cos(a) * r, 0, sin(a) * r)
		_slots.append({"node": null, "pos": p, "yaw": randf() * TAU, "next": 0})
	set_process(not zone.streamed)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_zone) or _zone.streamed:
		return
	for i in _slots.size():
		if not is_instance_valid(_slots[i].node) and _slots[i].next <= Time.get_ticks_msec():
			_spawn(_zone, i)

func stream_step(zone: Node, p: Vector3) -> bool:
	_init_slots(zone)
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		if is_instance_valid(s.node):
			if U.flat_dist(s.pos, p) > WorldStream.ACTOR_KEEP:
				s.node.queue_free()
				s.node = null
				return true
		elif s.next <= Time.get_ticks_msec() and U.flat_dist(s.pos, p) < WorldStream.ACTOR_LOAD:
			_spawn(zone, i)
			return true
	return false

func _spawn(zone: Node, i: int) -> void:
	if is_instance_valid(_slots[i].node):
		return
	var p: Vector3 = _slots[i].pos
	p.y = U.ground_height(get_tree(), p.x, p.z, p.y)
	var g := GatherNode.new()
	g.node_type = node_type
	g.spot = self
	g.set_meta("gather_slot", i)
	zone.units_root.add_child(g)
	g.global_position = p
	g.rotation.y = _slots[i].yaw
	_slots[i].node = g

func on_gathered(g: Node) -> void:
	var i: int = g.get_meta("gather_slot", -1)
	if i < 0 or i >= _slots.size() or _slots[i].node != g:
		return
	_slots[i].node = null
	_slots[i].next = Time.get_ticks_msec() + int(respawn * 1000.0) if respawn > 0.0 else 9223372036854775807
