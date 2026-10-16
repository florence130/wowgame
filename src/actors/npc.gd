class_name NPC
extends Unit
## 友方 NPC：任务、商人、训练师、旅店、飞行管理员等；卫兵会保护玩家；路人会闲逛与自言自语

var npc_id := ""
var nd: Dictionary = {}
var marker: Label3D
var _wander_t := 0.0
var _wander_to := Vector3.ZERO
var ambient := false
var guard := false
var _bubble_t := 0.0
var _bubble: Label3D
var _guard_think := 0.0
var wander_radius := 0.0
var patrol: Array = []
var _patrol_i := 0
var _talk_face_t := 0.0
var home_yaw := 0.0

const AMBIENT_LINES := ["今天天气真好啊。", "听说灰巾帮又在闹事了……", "晴岚港的魔导列车可快了！", "我家的猫又跑丢了。",
	"冒险者？真了不起。", "飞空艇什么时候才能去远方呢？", "市场的苹果派最好吃了。", "最近晚上总能听到奇怪的钟声。",
	"你也是来找工作的吗？", "这把剑可是我祖父传下来的。", "要下雨了吧？", "嘿，你的衣服真好看！"]

func init_npc(id: String, seed_extra: int = 0) -> void:
	npc_id = id
	nd = DB.npcs.get(id, {})
	unit_name = nd.get("name", id)
	sub_name = nd.get("sub", "")
	faction = "friendly"
	unit_type = "humanoid"
	ambient = nd.get("ambient", false)
	guard = nd.get("guard", false)
	level = 30 if guard else 20
	max_hp = 3000.0 if guard else 800.0
	hp = max_hp
	wdmg = Vector2(30, 45) if guard else Vector2(10, 15)
	wspeed = 2.0
	stats = {"armor": 2000.0 if guard else 500.0, "crit": 5.0, "dodge": 5.0, "spi": 30.0}
	base_speed = 7.0
	var av := Avatar.new()
	av.name = "Model"
	add_child(av)
	var gear := DB.outfit_gear(nd.get("outfit", "villager"), hash(id) + seed_extra)
	av.setup(DB.npc_appearance(id, nd, seed_extra), gear)
	model = av
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	add_to_group("npcs")
	add_to_group("interactable")
	marker = Label3D.new()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 110
	marker.outline_size = 18
	marker.pixel_size = 0.004
	marker.position = Vector3(0, av.height() + 0.75, 0)
	marker.modulate = Color("ffd800")
	marker.outline_modulate = Color("5a3a00")
	add_child(marker)
	refresh_marker()
	Game.npc_markers_dirty.connect(refresh_marker)
	if ambient:
		wander_radius = 14.0
	_bubble_t = randf_range(8.0, 30.0)
	if nd.has("flight") and nd["flight"] != "":
		pass

func refresh_marker() -> void:
	if marker == null:
		return
	var m := Game.npc_marker(npc_id)
	match m:
		"!":
			marker.text = "!"
			marker.modulate = Color("ffd800")
		"?":
			marker.text = "?"
			marker.modulate = Color("ffd800")
		"?gray":
			marker.text = "?"
			marker.modulate = Color("b0b0b0")
		"!gray":
			marker.text = "!"
			marker.modulate = Color("9a9a9a")
			marker.font_size = 80
		_:
			marker.text = ""

func interact(p: Player) -> void:
	if dead:
		return
	face_towards(p.global_position)
	_talk_face_t = 6.0
	if model:
		model.play_emote("talk")
	if nd.has("flight") and nd["flight"] != "":
		Game.discover_fp(nd["flight"])
	if Game.hud:
		Game.hud.open_npc(self)
	Sfx.play("open")

func can_interact() -> bool:
	return not dead

func _physics_process(delta: float) -> void:
	if Game.world and Game.world.simulation_suspended():
		return
	var pl: Node3D = Game.player
	if pl and is_instance_valid(pl) and global_position.distance_squared_to(pl.global_position) > 150.0 * 150.0 and not in_combat and hp >= max_hp and auras.is_empty():
		# 远处 NPC 不绘制（无缝大世界里另一端的城市居民）
		if model:
			model.visible = global_position.distance_squared_to(pl.global_position) < 240.0 * 240.0
		return
	if model and not model.visible:
		model.visible = true
	super._physics_process(delta)
	if dead:
		return
	var wish := Vector3.ZERO
	if _talk_face_t > 0.0:
		_talk_face_t -= delta
		if _talk_face_t <= 0.0 and wander_radius <= 0.0 and patrol.is_empty():
			var tw := create_tween()
			tw.tween_property(self, "rotation:y", home_yaw, 0.6)
	elif guard and _guard_logic(delta):
		wish = _guard_wish
	elif patrol.size() > 1:
		var pt: Vector3 = patrol[_patrol_i]
		var d := pt - global_position
		d.y = 0
		if d.length() < 1.2:
			_patrol_i = (_patrol_i + 1) % patrol.size()
		else:
			wish = d.normalized() * 2.4
			rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 5.0, 0.0, 1.0))
	elif wander_radius > 0.0:
		_wander_t -= delta
		if _wander_t <= 0.0:
			var a := randf() * TAU
			_wander_to = spawn_pos + Vector3(cos(a), 0, sin(a)) * randf() * wander_radius
			_wander_t = randf_range(6.0, 16.0)
		var d2 := _wander_to - global_position
		d2.y = 0
		if d2.length() > 0.8 and _wander_t > 3.0:
			wish = d2.normalized() * 2.2
			rotation.y = lerp_angle(rotation.y, atan2(-d2.x, -d2.z), clampf(delta * 5.0, 0.0, 1.0))
	apply_gravity_and_move(delta, wish)
	if model:
		model.set_combat_ready(in_combat)
		model.animate(delta, {"speed": Vector2(velocity.x, velocity.z).length()})
	# 自言自语
	if ambient:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble_t = randf_range(20.0, 50.0)
			if pl and global_position.distance_to(pl.global_position) < 25.0:
				say(AMBIENT_LINES[randi() % AMBIENT_LINES.size()])

var _guard_wish := Vector3.ZERO
func _guard_logic(delta: float) -> bool:
	_guard_think -= delta
	if _guard_think <= 0.0:
		_guard_think = 0.5
		if target == null or not is_instance_valid(target) or target.dead:
			target = null
			auto_attack = false
			for m in get_tree().get_nodes_in_group("mobs"):
				if m.dead or m.faction != "hostile" or not m.in_combat:
					continue
				if m.global_position.distance_to(global_position) < 22.0 and m.global_position.distance_to(spawn_pos) < 35.0:
					target = m
					m.add_threat(self, 1.0)
					say("休想在这里撒野！")
					break
	if target != null and is_instance_valid(target) and not target.dead:
		var d := edge_dist(target)
		if global_position.distance_to(spawn_pos) > 40.0:
			target = null
			auto_attack = false
			return false
		auto_attack = true
		if d > MELEE_RANGE - 0.8:
			var dir := target.global_position - global_position
			dir.y = 0
			_guard_wish = dir.normalized() * 7.0
			rotation.y = atan2(-dir.x, -dir.z)
		else:
			_guard_wish = Vector3.ZERO
			face_towards(target.global_position)
		return true
	# 回到岗位
	var back := spawn_pos - global_position
	back.y = 0
	if back.length() > 1.0 and patrol.is_empty():
		_guard_wish = back.normalized() * 4.0
		rotation.y = atan2(-back.x, -back.z)
		return true
	elif back.length() <= 1.0 and patrol.is_empty():
		rotation.y = lerp_angle(rotation.y, home_yaw, 0.1)
	return false

func say(text: String) -> void:
	if _bubble and is_instance_valid(_bubble):
		_bubble.queue_free()
	var b := Label3D.new()
	b.text = text
	b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.font_size = 34
	b.outline_size = 10
	b.pixel_size = 0.004
	b.modulate = Color("fffbe8")
	b.outline_modulate = Color(0.1, 0.12, 0.2, 0.9)
	b.position = Vector3(0, (model.height() if model else 1.7) + 0.5, 0)
	add_child(b)
	_bubble = b
	var tw := b.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(b, "modulate:a", 0.0, 0.5)
	tw.tween_callback(b.queue_free)
	Game.msg("%s说：%s" % [unit_name, text], Color("fff6d0"))

func take_damage(amt: float, school: String, src: Unit, crit: bool = false, sname: String = "", periodic: bool = false, bonus_threat: float = 0.0, mechanic: bool = false) -> void:
	super.take_damage(amt * (0.2 if guard else 1.0), school, src, crit, sname, periodic, bonus_threat, mechanic)

func _on_death(_k: Unit) -> void:
	var tm := get_tree().create_timer(30.0)
	tm.timeout.connect(func():
		if is_instance_valid(self):
			dead = false
			hp = max_hp
			global_position = spawn_pos
			if model:
				model.set_dead(false))
