@tool
class_name ZonePortal
extends EditorMarker
## 区域传送点（走入即触发）

@export var target_zone: String = ""
@export var target_spawn: String = ""
@export var radius: float = 6.0
@export var title: String = "":
	set(v):
		title = v
		if Engine.is_editor_hint() and is_inside_tree():
			_editor_label("⇨ " + title, Color(0.5, 0.8, 1))
@export var requires_flag: String = ""
@export var requires_level: int = 0
var _cool := 2.0

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_label("⇨ " + title, Color(0.5, 0.8, 1))
		return
	add_to_group("portals")

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cool -= delta
	if _cool > 0.0:
		return
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.dead:
		return
	if U.flat_dist(p.global_position, global_position) < radius and absf(p.global_position.y - global_position.y) < 8.0:
		_cool = 3.0
		if requires_flag != "" and not Game.has_flag(requires_flag):
			Game.err("你还不能前往那里。")
			return
		if requires_level > 0 and Game.pd["level"] < requires_level:
			Game.err("你需要达到%d级才能前往%s。" % [requires_level, title])
			return
		if not DB.zones.has(target_zone) or not ResourceLoader.exists(DB.zones[target_zone]["scene"]):
			Game.err("%s尚未开放（开发中）。" % title)
			return
		Game.world.travel(target_zone, target_spawn)
