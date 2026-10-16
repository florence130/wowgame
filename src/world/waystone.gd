class_name Waystone
extends StaticBody3D
## 城内传送石：靠近按交互键（默认 F）打开目的地列表，选中后淡出淡入传送到同区域的另一块传送石旁。
## 摆放数据来自 docs/city_v7/game.json 的 waystones（tools/city_plan_v6 导出），由 GenCityV7 生成。
## land_rel / land_yaw：落点相对石心的偏移与朝向（导出时已用步行碰撞验证过可站立）。

const STONE := Color("d9cfb8")
const STONE_D := Color("b3a68c")
const CRYSTAL := Color("8fdcff")
const GOLD := Color("e0b45a")

@export var ws_id := ""
@export var title := ""
@export var zone_id := "tidewind"
@export var land_rel := Vector3(0, 0, 3.4)
@export var land_yaw := 180.0
## 跨区域直达：这块石头额外能传到哪些 ws_id（对方的列表里也会出现这一块，来回都能传）
@export var links: Array = []
var _ring: Node3D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("waystones")
	collision_layer = 1
	collision_mask = 0
	_build()

func _build() -> void:
	# 三级八角台基
	U.add_mesh(self, U.cyl_mesh(2.6, 2.6, 0.6, 8), U.mat(STONE_D), Vector3(0, -0.1, 0))
	U.add_mesh(self, U.cyl_mesh(2.0, 2.0, 0.25, 8), U.mat(STONE), Vector3(0, 0.325, 0))
	U.add_mesh(self, U.cyl_mesh(1.25, 1.25, 0.3, 8), U.mat(STONE), Vector3(0, 0.6, 0))
	# 四根石框立柱 + 顶盖
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			U.add_mesh(self, U.box_mesh(Vector3(0.32, 3.1, 0.32)), U.mat(STONE), Vector3(sx * 0.72, 2.3, sz * 0.72))
	U.add_mesh(self, U.box_mesh(Vector3(1.9, 0.22, 1.9)), U.mat(STONE_D), Vector3(0, 3.96, 0))
	# 发光水晶柱（六棱柱 + 尖顶）
	var glow := U.mat(CRYSTAL, 2.2)
	U.add_mesh(self, U.cyl_mesh(0.36, 0.5, 3.0, 6), glow, Vector3(0, 2.25, 0), Vector3.ZERO, Vector3.ONE, false)
	U.add_mesh(self, U.cyl_mesh(0.02, 0.36, 0.9, 6), glow, Vector3(0, 4.2, 0), Vector3.ZERO, Vector3.ONE, false)
	# 悬浮符文环（缓慢旋转）
	_ring = Node3D.new()
	_ring.position = Vector3(0, 2.4, 0)
	add_child(_ring)
	var torus := TorusMesh.new()
	torus.inner_radius = 1.45
	torus.outer_radius = 1.6
	torus.rings = 32
	torus.ring_segments = 6
	U.add_mesh(_ring, torus, U.mat(GOLD, 0.6), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.6, 0)
	light.light_color = CRYSTAL
	light.light_energy = 1.2
	light.omni_range = 7.0
	light.shadow_enabled = false
	add_child(light)
	var lb := Label3D.new()
	lb.text = "◆ 传送石 · %s" % title
	lb.position = Vector3(0, 5.0, 0)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.font_size = 40
	lb.pixel_size = 0.01
	lb.modulate = Color("bff0ff")
	lb.outline_size = 10
	lb.visibility_range_end = 60.0
	add_child(lb)
	U.add_cyl_shape(self, 1.3, 4.2, Vector3(0, 2.0, 0))

func _process(delta: float) -> void:
	if _ring:
		_ring.rotate_y(delta * 0.6)

func can_interact() -> bool:
	return true

func interact(_p: Player) -> void:
	if Game.hud == null:
		return
	Game.hud.open_waystone(self)
	Sfx.play("open")

## 同区域的其他传送石（按名称排序）
func destinations() -> Array:
	var out: Array = []
	for w in get_tree().get_nodes_in_group("waystones"):
		if w == self or not is_instance_valid(w):
			continue
		if w.zone_id == zone_id or links.has(w.ws_id) or w.links.has(ws_id):
			out.append(w)
	out.sort_custom(func(a, b): return a.title < b.title)
	return out

func land_point() -> Vector3:
	return global_position + land_rel

## 传送到本石旁（由出发石的目的地菜单调用）
func arrive() -> void:
	if Game.world == null:
		return
	Vfx.column(Game.world.zone, Game.player.global_position, CRYSTAL, 2.0, 0.6)
	await Game.world.travel(zone_id, "", land_point(), deg_to_rad(land_yaw))
	Vfx.column(Game.world.zone, Game.player.global_position, CRYSTAL, 2.0, 0.6)
	Sfx.play("open")
