@tool
class_name Prop
extends Node3D
## 参数化白盒道具/建筑。修改 kind 与参数即可在编辑器中实时重建。正面朝向 -Z。

const KINDS := "house,townhouse,cottage,tower,lighthouse,wall,gate,stairs,ramp,block,bridge,fence,lamp,tree,bush,rock,flowerbed,crate,barrel,cart,well,bench,stall,tent,banner,sign,haystack,field,campfire,windmill,fountain,obelisk,statue,ship,pier,crane,column,arch,ruin_wall,pillar,portal_ring,train,rail,airship,dome,church,station,cityhall,guildhall,hall,mine_entrance,anvil,brazier,pipe,clocktower,bell,grave,chest_obj,signal_lamp,tunnel,platform,awning,canopy,gazebo,boat,buoy,lantern_post,hedge,cliff,stalagmite,crystal,web,altar,throne,bookshelf,table,bed,rug,pillar_row,water_plane"

@export_enum("house", "townhouse", "cottage", "tower", "lighthouse", "wall", "gate", "stairs", "ramp", "block", "bridge", "fence", "lamp", "tree", "bush", "rock", "flowerbed", "crate", "barrel", "cart", "well", "bench", "stall", "tent", "banner", "sign", "haystack", "field", "campfire", "windmill", "fountain", "obelisk", "statue", "ship", "pier", "crane", "column", "arch", "ruin_wall", "pillar", "portal_ring", "train", "rail", "airship", "dome", "church", "station", "cityhall", "guildhall", "hall", "mine_entrance", "anvil", "brazier", "pipe", "clocktower", "bell", "grave", "chest_obj", "signal_lamp", "tunnel", "platform", "awning", "canopy", "gazebo", "boat", "buoy", "lantern_post", "hedge", "cliff", "stalagmite", "crystal", "web", "altar", "throne", "bookshelf", "table", "bed", "rug", "pillar_row", "water_plane") var kind: String = "house":
	set(v):
		kind = v
		_queue_rebuild()
@export var size := Vector3(8, 6, 8):
	set(v):
		size = v
		_queue_rebuild()
@export var color_a := Color("e8dcc0"):
	set(v):
		color_a = v
		_queue_rebuild()
@export var color_b := Color("b05a3a"):
	set(v):
		color_b = v
		_queue_rebuild()
@export var color_c := Color("6a4a30"):
	set(v):
		color_c = v
		_queue_rebuild()
@export var variant: int = 0:
	set(v):
		variant = v
		_queue_rebuild()
@export var label: String = "":
	set(v):
		label = v
		_queue_rebuild()
@export var collide: bool = true:
	set(v):
		collide = v
		_queue_rebuild()
@export var flag: String = ""
@export var seed_v: int = 0:
	set(v):
		seed_v = v
		_queue_rebuild()

var _gen: Node3D
var _body: StaticBody3D
var _pending := false
var _rng := RandomNumberGenerator.new()
var _anim_nodes: Array = []
var _t := 0.0
static var window_material: StandardMaterial3D
static var lamp_material: StandardMaterial3D

func _ready() -> void:
	if has_meta("stream_deferred") and not Engine.is_editor_hint():
		set_process(false)
		return
	rebuild()
	if not Engine.is_editor_hint():
		set_process(_anim_nodes.size() > 0)
	else:
		set_process(false)

func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	call_deferred("rebuild")

static func get_window_mat() -> StandardMaterial3D:
	if window_material == null:
		window_material = StandardMaterial3D.new()
		window_material.albedo_color = Color("6a8ab0")
		window_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		window_material.emission_enabled = true
		window_material.emission = Color("ffd890")
		window_material.emission_energy_multiplier = 0.0
	return window_material

static func get_lamp_mat() -> StandardMaterial3D:
	if lamp_material == null:
		lamp_material = StandardMaterial3D.new()
		lamp_material.albedo_color = Color("fff0c0")
		lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lamp_material.emission_enabled = true
		lamp_material.emission = Color("ffd070")
		lamp_material.emission_energy_multiplier = 1.0
	return lamp_material

static func set_night_factor(f: float) -> void:
	get_window_mat().emission_energy_multiplier = f * 1.6
	get_window_mat().albedo_color = Color("6a8ab0").lerp(Color("ffd890"), f)
	get_lamp_mat().albedo_color = Color("e0d8c0").lerp(Color("fff0c0"), f)
	get_lamp_mat().emission_energy_multiplier = 0.2 + f * 2.5

func rebuild() -> void:
	_pending = false
	if _gen and is_instance_valid(_gen):
		remove_child(_gen)
		_gen.free()
	_anim_nodes.clear()
	_gen = Node3D.new()
	_gen.name = "_gen"
	add_child(_gen)
	_body = null
	_rng.seed = seed_v + hash(kind)
	# 旧Prop场景也统一走正式铁艺灯柱；避免潜在场景继续生成圆柱占位灯。
	if kind in ["lamp", "lantern_post", "lamp2", "abbey_lamp"]:
		var formal := ModelProp.new()
		formal.kind = kind
		formal.variant = variant
		formal.size = size
		formal.color_a = color_a
		formal.color_b = color_b
		formal.color_c = color_c
		formal.collide = collide
		formal.seed_v = seed_v
		_gen.add_child(formal)
		return
	if has_method("_b_" + kind):
		call("_b_" + kind)
	else:
		_box(size, Vector3(0, size.y * 0.5, 0), color_a)
	var keep := []
	for a in _anim_nodes:
		keep.append(a[1])
	var keep2 := keep.filter(func(k): return k != _gen)
	U.merge_meshes(_gen, true, keep2)
	for k in keep2:
		if k != _gen and is_instance_valid(k):
			U.merge_meshes(k, true)
	if not Engine.is_editor_hint():
		set_process(_anim_nodes.size() > 0)
		_set_vis_range(_gen, clampf(maxf(size.x, maxf(size.y, size.z)) * 45.0, 140.0, 1800.0))

## 按尺寸做距离剔除（无缝大世界里远处城市的程序化建筑/道具不绘制，大地标保留远景轮廓）
func _set_vis_range(n: Node, r: float) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D and not (c is Label3D):
			c.visibility_range_end = r
			c.visibility_range_end_margin = 20.0
			c.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		_set_vis_range(c, r)

# ---------------------------------------------------------------- 助手
func _m(c: Color) -> Material:
	return U.mat(c)

func _mesh(mesh: Mesh, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, mat_override: Material = null) -> MeshInstance3D:
	return U.add_mesh(_gen, mesh, mat_override if mat_override else _m(c), pos, rot, scl)

func _box(s: Vector3, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, col: bool = false) -> MeshInstance3D:
	var mi := _mesh(U.box_mesh(s), pos, c, rot)
	if col:
		_col_box(s, pos, rot)
	return mi

func _ensure_body() -> StaticBody3D:
	if _body == null:
		_body = StaticBody3D.new()
		_body.collision_layer = 1
		_body.collision_mask = 0
		_gen.add_child(_body)
	return _body

func _col_box(s: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	if not collide:
		return
	U.add_box_shape(_ensure_body(), s, pos, rot)

func _col_cyl(r: float, h: float, pos: Vector3) -> void:
	if not collide:
		return
	U.add_cyl_shape(_ensure_body(), r, h, pos)

func _window(pos: Vector3, w: float, h: float, rot_y: float = 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	_gen.add_child(n)
	U.add_mesh(n, U.box_mesh(Vector3(w + 0.16, h + 0.16, 0.12)), _m(color_c), Vector3(0, 0, 0.0))
	U.add_mesh(n, U.box_mesh(Vector3(w, h, 0.14)), get_window_mat(), Vector3(0, 0, -0.01))
	U.add_mesh(n, U.box_mesh(Vector3(0.06, h, 0.16)), _m(color_c), Vector3(0, 0, -0.02))
	U.add_mesh(n, U.box_mesh(Vector3(w, 0.06, 0.16)), _m(color_c), Vector3(0, 0, -0.02))

func _door(pos: Vector3, w: float, h: float, c: Color = Color("5a3a24"), rot_y: float = 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	_gen.add_child(n)
	U.add_mesh(n, U.box_mesh(Vector3(w + 0.3, h + 0.2, 0.14)), _m(color_c.darkened(0.1)), Vector3(0, h * 0.5 + 0.05, 0))
	U.add_mesh(n, U.box_mesh(Vector3(w, h, 0.18)), _m(c), Vector3(0, h * 0.5, -0.02))
	U.add_mesh(n, U.cyl_mesh(w * 0.5, w * 0.5, 0.18, 12), _m(c), Vector3(0, h, -0.02), Vector3(90, 0, 0), Vector3(1, 1, 0.6))
	U.add_mesh(n, U.sphere_mesh(0.06), _m(Color("e8c27a")), Vector3(w * 0.3, h * 0.45, -0.12))

func _gable_roof(w: float, d: float, base_y: float, rh: float, c: Color, overhang: float = 0.5) -> void:
	_mesh(U.prism_mesh(Vector3(w + overhang * 2.0, rh, d + overhang * 2.0)), Vector3(0, base_y + rh * 0.5, 0), c)
	_box(Vector3(0.25, 0.25, d + overhang * 2.0 + 0.1), Vector3(0, base_y + rh, 0), c.darkened(0.25))

func _hip_roof(w: float, d: float, base_y: float, rh: float, c: Color, overhang: float = 0.4) -> void:
	var sx := (w * 0.5 + overhang) / 0.7071
	var sz := (d * 0.5 + overhang) / 0.7071
	_mesh(_pyramid_mesh(), Vector3(0, base_y + rh * 0.5, 0), c, Vector3.ZERO, Vector3(sx, rh, sz))

static var _pyr: ArrayMesh
func _pyramid_mesh() -> ArrayMesh:
	if _pyr != null:
		return _pyr
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, 0.5, 0)
	var c := [Vector3(-0.7071, -0.5, -0.7071), Vector3(0.7071, -0.5, -0.7071), Vector3(0.7071, -0.5, 0.7071), Vector3(-0.7071, -0.5, 0.7071)]
	for i in 4:
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		var n := (b - a).cross(top - a).normalized() * -1.0
		st.set_normal(n)
		st.add_vertex(a)
		st.set_normal(n)
		st.add_vertex(top)
		st.set_normal(n)
		st.add_vertex(b)
	st.set_normal(Vector3.DOWN)
	st.add_vertex(c[0])
	st.add_vertex(c[1])
	st.add_vertex(c[2])
	st.add_vertex(c[0])
	st.add_vertex(c[2])
	st.add_vertex(c[3])
	_pyr = st.commit()
	return _pyr

func _foundation(w: float, d: float, c: Color = Color("8a8478")) -> void:
	_box(Vector3(w + 0.3, 2.6, d + 0.3), Vector3(0, -1.0, 0), c)

func _label3d(text: String, pos: Vector3, sz: int = 64, col: Color = Color("3a2a1a"), rot_y: float = 0.0, billboard: bool = false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = sz
	l.pixel_size = 0.01
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees.y = rot_y
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.double_sided = true
	_gen.add_child(l)
	return l

func _signboard(text: String, pos: Vector3, rot_y: float = 0.0) -> void:
	if text == "":
		return
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	_gen.add_child(n)
	var w := maxf(1.6, text.length() * 0.42 + 0.6)
	U.add_mesh(n, U.box_mesh(Vector3(w, 0.75, 0.1)), _m(Color("f0e2c0")), Vector3.ZERO)
	U.add_mesh(n, U.box_mesh(Vector3(w + 0.14, 0.89, 0.08)), _m(Color("6a4a30")), Vector3(0, 0, 0.02))
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.0085
	l.modulate = Color("3a2412")
	l.outline_size = 0
	l.position = Vector3(0, 0, -0.06)
	l.rotation_degrees.y = 180
	l.double_sided = false
	n.add_child(l)
	var l2 := l.duplicate()
	l2.position = Vector3(0, 0, 0.08)
	l2.rotation_degrees.y = 0
	n.add_child(l2)

# ================================================================ 建筑
func _b_house() -> void:
	# 木筋墙民居（洛奇式）
	var w := size.x
	var h := size.y
	var d := size.z
	var var_ := 1 if kind == "cottage" else variant
	_foundation(w, d)
	_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	var beam := color_c
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(0.3, h, 0.3), Vector3(sx * (w * 0.5 - 0.1), h * 0.5, sz * (d * 0.5 - 0.1)), beam)
	_box(Vector3(w + 0.1, 0.25, d + 0.1), Vector3(0, h * 0.55, 0), beam)
	_box(Vector3(w + 0.1, 0.25, d + 0.1), Vector3(0, h - 0.1, 0), beam)
	# 交叉木筋
	if var_ % 2 == 0:
		for sz in [-1, 1]:
			for k in [-1, 1]:
				_box(Vector3(0.18, h * 0.5, 0.12), Vector3(k * w * 0.25, h * 0.78, sz * (d * 0.5 + 0.02)), beam, Vector3(0, 0, k * 35))
	# 屋顶
	var rh := minf(w, d) * 0.55
	if var_ == 1:
		# 茅草顶：圆润厚重
		_mesh(U.prism_mesh(Vector3(w + 1.6, rh + 0.4, d + 1.4)), Vector3(0, h + rh * 0.5 - 0.1, 0), color_b)
		_mesh(U.capsule_mesh(0.45, d + 1.6), Vector3(0, h + rh + 0.1, 0), color_b.lightened(0.08), Vector3(90, 0, 0))
	else:
		_gable_roof(w, d, h, rh, color_b, 0.6)
	_col_box(Vector3(w + 0.4, rh * 0.6, d + 0.4), Vector3(0, h + rh * 0.3, 0))
	# 烟囱
	_box(Vector3(0.8, rh + 1.2, 0.8), Vector3(w * 0.3, h + rh * 0.5 + 0.4, d * 0.2), Color("9a8a7a"), Vector3.ZERO, false)
	# 门与窗（正面 -Z）
	_door(Vector3(0, 0, -d * 0.5 - 0.05), 1.3, 2.2, Color("6a3a20"), 180)
	for sx in [-1, 1]:
		_window(Vector3(sx * w * 0.3, h * 0.3 + 0.5, -d * 0.5 - 0.05), 0.9, 1.0, 180)
		_window(Vector3(sx * w * 0.3, h * 0.78, -d * 0.5 - 0.05), 0.8, 0.8, 180)
		_window(Vector3(sx * w * 0.3, h * 0.35 + 0.5, d * 0.5 + 0.05), 0.9, 1.0)
		_window(Vector3(sx * (w * 0.5 + 0.05), h * 0.4 + 0.5, 0), 0.9, 1.0, 90)
		# 花箱
		_box(Vector3(1.1, 0.25, 0.35), Vector3(sx * w * 0.3, h * 0.3 - 0.1, -d * 0.5 - 0.25), Color("7a5030"))
		for k in 3:
			_mesh(U.sphere_mesh(0.14), Vector3(sx * w * 0.3 + (k - 1) * 0.3, h * 0.3 + 0.08, -d * 0.5 - 0.25), [Color("ff7090"), Color("ffd040"), Color("f0f0ff")][(k + var_) % 3])
	# 门前台阶
	_box(Vector3(2.0, 0.3, 1.0), Vector3(0, 0.15, -d * 0.5 - 0.6), Color("9a948a"), Vector3.ZERO, true)
	_signboard(label, Vector3(1.6, 2.8, -d * 0.5 - 0.6), 0)

func _b_cottage() -> void:
	_b_house()

func _b_townhouse() -> void:
	# 城市多层建筑（参考近代欧式港口城市）：石材底层 + 灰泥上层 + 曼萨德屋顶
	var w := size.x
	var h := size.y
	var d := size.z
	var fl := maxi(2, int(h / 3.6))
	_foundation(w, d, Color("9a9488"))
	_box(Vector3(w, 3.6, d), Vector3(0, 1.8, 0), color_c.lightened(0.35), Vector3.ZERO, true)
	_box(Vector3(w - 0.1, h - 3.6, d - 0.1), Vector3(0, 3.6 + (h - 3.6) * 0.5, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(w + 0.3, 0.3, d + 0.3), Vector3(0, 3.6, 0), color_c.lightened(0.5))
	_box(Vector3(w + 0.4, 0.4, d + 0.4), Vector3(0, h, 0), color_c.lightened(0.5))
	# 曼萨德屋顶
	var rh := 2.6
	_mesh(U.cyl_mesh(0.8, 1.0, rh, 4), Vector3(0, h + rh * 0.5 + 0.2, 0), color_b, Vector3(0, 45, 0), Vector3(w * 0.5 / 0.7071 * 1.02, 1, d * 0.5 / 0.7071 * 1.02))
	_col_box(Vector3(w, rh, d), Vector3(0, h + rh * 0.5, 0))
	# 老虎窗
	for i in maxi(1, int(w / 3.5)):
		var x := (i - (int(w / 3.5) - 1) * 0.5) * 3.2
		_box(Vector3(1.0, 1.2, 0.8), Vector3(x, h + 1.0, -d * 0.5 + 0.6), color_a)
		_window(Vector3(x, h + 1.0, -d * 0.5 + 0.18), 0.6, 0.8, 180)
		_mesh(U.prism_mesh(Vector3(1.2, 0.5, 0.9)), Vector3(x, h + 1.85, -d * 0.5 + 0.6), color_b, Vector3(0, 90, 0))
	# 窗户
	var cols := maxi(2, int(w / 2.6))
	for f in range(1, fl):
		var y := 3.6 + (f - 1) * 3.4 + 1.7
		if y > h - 0.8:
			break
		for i in cols:
			var x := (i - (cols - 1) * 0.5) * (w / cols)
			_window(Vector3(x, y, -d * 0.5 - 0.05), 1.0, 1.6, 180)
			_window(Vector3(x, y, d * 0.5 + 0.05), 1.0, 1.6)
			if variant % 2 == 0 and f == 1:
				# 阳台
				_box(Vector3(1.6, 0.15, 0.7), Vector3(x, y - 0.95, -d * 0.5 - 0.35), color_c.lightened(0.4))
				_box(Vector3(1.6, 0.5, 0.06), Vector3(x, y - 0.65, -d * 0.5 - 0.68), Color("3a3a42"))
		var rows := maxi(1, int(d / 3.0))
		for j in rows:
			var z := (j - (rows - 1) * 0.5) * (d / rows)
			_window(Vector3(-w * 0.5 - 0.05, y, z), 1.0, 1.6, -90)
			_window(Vector3(w * 0.5 + 0.05, y, z), 1.0, 1.6, 90)
	# 底层：店铺门面或拱门
	_door(Vector3(0, 0, -d * 0.5 - 0.05), 1.6, 2.6, Color("4a3020"), 180)
	for sx in [-1, 1]:
		if w > 6.0:
			_window(Vector3(sx * w * 0.3, 1.6, -d * 0.5 - 0.05), 1.8, 1.8, 180)
	if variant >= 2:
		# 遮阳棚
		var awn := Color("c03a3a") if variant == 2 else Color("3a6ac0")
		for k in 5:
			_box(Vector3(w * 0.9 / 5.0, 0.08, 1.4), Vector3((k - 2) * w * 0.9 / 5.0, 2.95, -d * 0.5 - 0.7), awn if k % 2 == 0 else Color("f0ece0"), Vector3(-18, 0, 0))
	_signboard(label, Vector3(0, 3.1, -d * 0.5 - 0.15), 0)

func _b_tower() -> void:
	var r := size.x * 0.5
	var h := size.y
	_mesh(U.cyl_mesh(r, r * 1.08, h, 16), Vector3(0, h * 0.5, 0), color_a)
	_col_cyl(r * 1.04, h, Vector3(0, h * 0.5, 0))
	_mesh(U.cyl_mesh(r * 1.15, r * 1.15, 0.6, 16), Vector3(0, h, 0), color_c)
	_mesh(U.cyl_mesh(0.0, r * 1.3, r * 2.0, 16), Vector3(0, h + r + 0.3, 0), color_b)
	_mesh(U.cyl_mesh(r * 1.02, r * 1.1, 2.0, 16), Vector3(0, -0.8, 0), Color("8a8478"))
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		_window(Vector3(sin(a) * (r + 0.05), h * 0.6, cos(a) * (r + 0.05)), 0.7, 1.2, rad_to_deg(a))
	_door(Vector3(0, 0, -r - 0.05), 1.3, 2.3, Color("5a3a24"), 180)
	_signboard(label, Vector3(0, 3.0, -r - 0.4), 0)

func _b_lighthouse() -> void:
	var r := size.x * 0.5
	var h := size.y
	_mesh(U.cyl_mesh(r * 1.6, r * 1.8, 3.0, 16), Vector3(0, 0.5, 0), Color("8a8478"))
	var seg := 6
	for i in seg:
		var y0 := i * h / seg
		var rr := lerpf(r, r * 0.7, float(i) / seg)
		_mesh(U.cyl_mesh(lerpf(r, r * 0.7, float(i + 1) / seg), rr, h / seg, 16), Vector3(0, y0 + h / seg * 0.5 + 2.0, 0), Color("f4f0e8") if i % 2 == 0 else Color("c03a3a"))
	_col_cyl(r, h + 2.0, Vector3(0, (h + 2.0) * 0.5, 0))
	var top := h + 2.0
	_mesh(U.cyl_mesh(r * 1.0, r * 1.0, 0.4, 16), Vector3(0, top, 0), Color("3a3a42"))
	_mesh(U.cyl_mesh(r * 0.55, r * 0.55, 2.2, 12), Vector3(0, top + 1.3, 0), Color("fff4c0"), Vector3.ZERO, Vector3.ONE, get_lamp_mat())
	_mesh(U.cyl_mesh(0.0, r * 0.8, 1.6, 12), Vector3(0, top + 3.2, 0), Color("c03a3a"))
	_mesh(U.torus_mesh(r * 0.95, r * 1.05, 24), Vector3(0, top + 0.6, 0), Color("3a3a42"), Vector3.ZERO, Vector3(1, 3, 1))
	if not Engine.is_editor_hint():
		var beam := Node3D.new()
		beam.position = Vector3(0, top + 1.3, 0)
		_gen.add_child(beam)
		for s in [-1, 1]:
			U.add_mesh(beam, U.cyl_mesh(0.3, 3.0, 40.0, 10), U.unshaded(Color(1, 0.95, 0.7, 0.12), true), Vector3(s * 20.0, 0, 0), Vector3(0, 0, 90), Vector3.ONE, false)
		_anim_nodes.append(["spin", beam, 0.6])
		beam.add_to_group("night_only")

func _b_wall() -> void:
	var l := size.x
	var h := size.y
	var t := size.z
	_box(Vector3(l, h + 3.0, t), Vector3(0, (h - 3.0) * 0.5, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(l, 0.4, t + 0.6), Vector3(0, h - 0.2, 0), color_c)
	var n := int(l / 2.0)
	for i in n:
		if i % 2 == 0:
			_box(Vector3(1.0, 1.0, 0.6), Vector3(-l * 0.5 + 1.0 + i * 2.0, h + 0.5, -t * 0.5 + 0.3), color_a)
			_box(Vector3(1.0, 1.0, 0.6), Vector3(-l * 0.5 + 1.0 + i * 2.0, h + 0.5, t * 0.5 - 0.3), color_a)
	_col_box(Vector3(l, 1.0, 0.6), Vector3(0, h + 0.5, -t * 0.5 + 0.3))
	_col_box(Vector3(l, 1.0, 0.6), Vector3(0, h + 0.5, t * 0.5 - 0.3))

func _b_gate() -> void:
	var w := size.x
	var h := size.y
	var t := size.z
	var tw := 5.0
	for sx in [-1, 1]:
		var x: float = sx * (w * 0.5 + tw * 0.5)
		_box(Vector3(tw, h + 6.0, tw), Vector3(x, (h + 6.0) * 0.5 - 2.0, 0), color_a, Vector3.ZERO, true)
		_mesh(U.cyl_mesh(0.0, tw * 0.8, 4.0, 4), Vector3(x, h + 6.0, 0), color_b, Vector3(0, 45, 0))
		for k in 2:
			_window(Vector3(x, h * 0.5 + k * 3.0, -tw * 0.5 - 0.05), 0.6, 1.2, 180)
		_box(Vector3(tw + 0.4, 0.5, tw + 0.4), Vector3(x, h + 3.8, 0), color_c)
	_box(Vector3(w + 0.2, 4.0, t), Vector3(0, h + 2.0, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(w + 0.4, 0.5, t + 0.4), Vector3(0, h + 0.1, 0), color_c)
	_mesh(U.cyl_mesh(w * 0.5, w * 0.5, t + 0.1, 20), Vector3(0, h, 0), color_a, Vector3(90, 0, 0), Vector3(1, 0.5, 1))
	# 旗帜
	for sx in [-1, 1]:
		_box(Vector3(1.4, 3.2, 0.08), Vector3(sx * (w * 0.5 - 1.0), h - 1.0, -t * 0.5 - 0.1), Color("2a5aa8"))
		_mesh(U.sphere_mesh(0.3), Vector3(sx * (w * 0.5 - 1.0), h - 0.6, -t * 0.5 - 0.16), Color("e8c27a"), Vector3.ZERO, Vector3(1, 1, 0.3))
	_signboard(label, Vector3(0, h + 2.0, -t * 0.5 - 0.15), 0)
	if flag != "":
		add_to_group("gates")
		refresh_gate()

func refresh_gate() -> void:
	if _gen == null:
		return
	var old := _gen.get_node_or_null("Barrier")
	if old:
		old.free()
	if flag == "" or Engine.is_editor_hint():
		return
	if Game.has_flag(flag):
		return
	var b := StaticBody3D.new()
	b.name = "Barrier"
	b.collision_layer = 1
	_gen.add_child(b)
	U.add_box_shape(b, Vector3(size.x, size.y + 4.0, 1.0), Vector3(0, size.y * 0.5, 0))
	U.add_mesh(b, U.box_mesh(Vector3(size.x, size.y, 0.2)), U.unshaded(Color(0.4, 0.7, 1.0, 0.28), true), Vector3(0, size.y * 0.5, 0))
	for i in int(size.x / 1.2):
		U.add_mesh(b, U.box_mesh(Vector3(0.12, size.y, 0.12)), U.mat(Color("3a3a42")), Vector3(-size.x * 0.5 + 0.6 + i * 1.2, size.y * 0.5, 0.2))

func _b_stairs() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	var n := maxi(2, int(h / 0.3))
	for i in n:
		var y := (i + 1) * h / n
		var z := d * 0.5 - (i + 0.5) * d / n
		_box(Vector3(w, y, d / n + 0.02), Vector3(0, y * 0.5, z), color_a)
	# 斜坡碰撞（可平滑行走）
	var len := sqrt(d * d + h * h)
	var ang := rad_to_deg(atan2(h, d))
	_col_box(Vector3(w, 0.4, len), Vector3(0, h * 0.5 - 0.2, 0), Vector3(ang, 0, 0))
	if variant == 1:
		for sx in [-1, 1]:
			_box(Vector3(0.3, 0.9, len), Vector3(sx * (w * 0.5 + 0.15), h * 0.5 + 0.45, 0), color_c, Vector3(ang, 0, 0), true)

func _b_ramp() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	var len := sqrt(d * d + h * h)
	var ang := rad_to_deg(atan2(h, d))
	_box(Vector3(w, 0.5, len), Vector3(0, h * 0.5 - 0.25, 0), color_a, Vector3(ang, 0, 0), true)
	_box(Vector3(w, h, d), Vector3(0, h * 0.25 - 0.5, 0), color_c, Vector3.ZERO)

func _b_block() -> void:
	_box(size, Vector3(0, size.y * 0.5, 0), color_a, Vector3.ZERO, true)
	if variant == 1:
		_box(Vector3(size.x + 0.3, 0.3, size.z + 0.3), Vector3(0, size.y, 0), color_c, Vector3.ZERO)

func _b_platform() -> void:
	# 地台/广场：顶面平整 + 挡土墙
	_box(Vector3(size.x, size.y + 4.0, size.z), Vector3(0, (size.y - 4.0) * 0.5, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(size.x + 0.2, 0.25, size.z + 0.2), Vector3(0, size.y, 0), color_c)

func _b_bridge() -> void:
	var l := size.z
	var w := size.x
	_box(Vector3(w, 0.6, l), Vector3(0, size.y, 0), color_a, Vector3.ZERO, true)
	for sx in [-1, 1]:
		_box(Vector3(0.4, 1.0, l), Vector3(sx * (w * 0.5 - 0.2), size.y + 0.8, 0), color_c, Vector3.ZERO, true)
	var arches := maxi(1, int(l / 12.0))
	for i in arches:
		var z := (i - (arches - 1) * 0.5) * l / arches
		_mesh(U.torus_mesh(size.y * 0.7, size.y * 1.0, 24), Vector3(0, 0, z), color_a.darkened(0.1), Vector3(0, 0, 90), Vector3(1, w * 0.45, 1))
	for i in arches + 1:
		var z2 := -l * 0.5 + i * l / arches
		_box(Vector3(w, size.y + 4.0, 1.4), Vector3(0, (size.y - 4.0) * 0.5, z2), color_a.darkened(0.15))

func _b_fence() -> void:
	var l := size.x
	var n := maxi(2, int(l / 2.0) + 1)
	for i in n:
		_box(Vector3(0.15, 1.1, 0.15), Vector3(-l * 0.5 + i * l / (n - 1), 0.55, 0), color_c)
	_box(Vector3(l, 0.1, 0.08), Vector3(0, 0.8, 0), color_c.lightened(0.1))
	_box(Vector3(l, 0.1, 0.08), Vector3(0, 0.45, 0), color_c.lightened(0.1))
	_col_box(Vector3(l, 1.1, 0.2), Vector3(0, 0.55, 0))

func _b_lamp() -> void:
	var h := maxf(3.0, size.y)
	_mesh(U.cyl_mesh(0.07, 0.1, h, 8), Vector3(0, h * 0.5, 0), Color("2a2a32"))
	_mesh(U.cyl_mesh(0.18, 0.22, 0.3, 8), Vector3(0, 0.15, 0), Color("2a2a32"))
	_box(Vector3(0.6, 0.06, 0.06), Vector3(0.25, h - 0.1, 0), Color("2a2a32"))
	_mesh(U.cyl_mesh(0.12, 0.22, 0.45, 6), Vector3(0.5, h - 0.45, 0), Color("fff"), Vector3.ZERO, Vector3.ONE, get_lamp_mat())
	_mesh(U.cyl_mesh(0.0, 0.28, 0.25, 6), Vector3(0.5, h - 0.1, 0), Color("2a2a32"))
	_col_cyl(0.15, h, Vector3(0, h * 0.5, 0))
	if not Engine.is_editor_hint():
		var l := OmniLight3D.new()
		l.position = Vector3(0.5, h - 0.6, 0)
		l.light_color = Color("ffcf80")
		l.omni_range = 9.0
		l.light_energy = 1.4
		l.shadow_enabled = false
		l.visible = false
		l.add_to_group("lamp_lights")
		_gen.add_child(l)

func _b_lantern_post() -> void:
	_b_lamp()

func _b_tree() -> void:
	var h := size.y
	var trunk_c := color_c
	var leaf := color_b
	var r := size.x * 0.5
	match variant:
		0:
			_mesh(U.cyl_mesh(r * 0.12, r * 0.2, h * 0.6, 7), Vector3(0, h * 0.3, 0), trunk_c)
			_mesh(U.sphere_mesh(r), Vector3(0, h * 0.7, 0), leaf, Vector3.ZERO, Vector3(1, 0.85, 1))
			_mesh(U.sphere_mesh(r * 0.7), Vector3(r * 0.55, h * 0.62, r * 0.2), leaf.lightened(0.06))
			_mesh(U.sphere_mesh(r * 0.65), Vector3(-r * 0.5, h * 0.6, -r * 0.25), leaf.darkened(0.06))
			_mesh(U.sphere_mesh(r * 0.6), Vector3(0, h * 0.92, 0), leaf.lightened(0.1))
		1:
			_mesh(U.cyl_mesh(r * 0.1, r * 0.16, h * 0.4, 6), Vector3(0, h * 0.2, 0), trunk_c)
			for i in 4:
				var rr := r * (1.0 - i * 0.2)
				_mesh(U.cyl_mesh(0.0, rr, h * 0.32, 8), Vector3(0, h * (0.32 + i * 0.17), 0), leaf.lightened(i * 0.04))
		2:
			var segs := 6
			var lean := 0.12
			for i in segs:
				_mesh(U.cyl_mesh(r * 0.1, r * 0.13, h / segs + 0.1, 6), Vector3(i * lean * h / segs * 1.5, (i + 0.5) * h / segs, 0), trunk_c, Vector3(0, 0, -8 - i * 2))
			var top := Vector3(segs * lean * h / segs * 1.5, h, 0)
			for i in 7:
				var a := i * TAU / 7.0
				_mesh(U.box_mesh(Vector3(0.5, 0.06, r * 1.4)), top + Vector3(sin(a) * r * 0.6, -0.3, cos(a) * r * 0.6), leaf, Vector3(25, rad_to_deg(a), 0))
			_mesh(U.sphere_mesh(0.3), top, Color("6a5030"))
		3:
			_mesh(U.cyl_mesh(r * 0.08, r * 0.12, h * 0.75, 6), Vector3(0, h * 0.37, 0), Color("e8e4dc"))
			_mesh(U.sphere_mesh(r * 0.8), Vector3(0, h * 0.75, 0), leaf.lightened(0.15), Vector3.ZERO, Vector3(0.9, 1.3, 0.9))
		4:
			_mesh(U.cyl_mesh(r * 0.08, r * 0.16, h * 0.8, 6), Vector3(0, h * 0.4, 0), trunk_c.darkened(0.2))
			for i in 4:
				var a2 := i * TAU / 4.0
				_mesh(U.cyl_mesh(0.02, r * 0.07, r * 1.0, 5), Vector3(sin(a2) * r * 0.3, h * 0.7, cos(a2) * r * 0.3), trunk_c.darkened(0.2), Vector3(cos(a2) * 50, 0, -sin(a2) * 50))
	_col_cyl(maxf(0.25, r * 0.16), h * 0.6, Vector3(0, h * 0.3, 0))

func _b_bush() -> void:
	var r := size.x * 0.5
	_mesh(U.sphere_mesh(r), Vector3(0, r * 0.6, 0), color_b, Vector3.ZERO, Vector3(1, 0.75, 1))
	_mesh(U.sphere_mesh(r * 0.7), Vector3(r * 0.5, r * 0.45, 0.1), color_b.lightened(0.07))
	_mesh(U.sphere_mesh(r * 0.6), Vector3(-r * 0.45, r * 0.4, -0.15), color_b.darkened(0.05))
	if variant == 1:
		for i in 5:
			var a := i * TAU / 5.0
			_mesh(U.sphere_mesh(0.1), Vector3(sin(a) * r * 0.7, r * 0.75, cos(a) * r * 0.7), [Color("ff6080"), Color("ffffff"), Color("ffd040")][i % 3])

func _b_hedge() -> void:
	_box(Vector3(size.x, size.y, size.z), Vector3(0, size.y * 0.5, 0), color_b, Vector3.ZERO, true)
	_box(Vector3(size.x + 0.1, 0.2, size.z + 0.1), Vector3(0, size.y, 0), color_b.lightened(0.08))

func _b_rock() -> void:
	var s := size
	_mesh(U.sphere_mesh(0.5, 1.0, false, 7), Vector3(0, s.y * 0.3, 0), color_a, Vector3(_rng.randf() * 30, _rng.randf() * 360, _rng.randf() * 20), s)
	_mesh(U.sphere_mesh(0.5, 1.0, false, 6), Vector3(s.x * 0.3, s.y * 0.15, s.z * 0.2), color_a.darkened(0.08), Vector3(0, _rng.randf() * 360, 0), s * 0.6)
	_col_box(s * Vector3(0.8, 0.7, 0.8), Vector3(0, s.y * 0.3, 0))

func _b_cliff() -> void:
	var s := size
	for i in 5:
		var off := Vector3(_rng.randf_range(-0.3, 0.3) * s.x, _rng.randf_range(0.0, 0.4) * s.y, _rng.randf_range(-0.3, 0.3) * s.z)
		_mesh(U.box_mesh(Vector3.ONE), off + Vector3(0, s.y * 0.3, 0), color_a.darkened(i * 0.04), Vector3(_rng.randf() * 15, _rng.randf() * 360, _rng.randf() * 15), s * _rng.randf_range(0.5, 0.8))
	_col_box(s * 0.7, Vector3(0, s.y * 0.35, 0))

func _b_flowerbed() -> void:
	_box(Vector3(size.x, 0.4, size.z), Vector3(0, 0.2, 0), Color("8a8478"), Vector3.ZERO, true)
	_box(Vector3(size.x - 0.3, 0.42, size.z - 0.3), Vector3(0, 0.22, 0), Color("5a4030"))
	var n := int(size.x * size.z * 1.5)
	for i in n:
		var p := Vector3(_rng.randf_range(-0.5, 0.5) * (size.x - 0.5), 0.5, _rng.randf_range(-0.5, 0.5) * (size.z - 0.5))
		_mesh(U.sphere_mesh(0.16), p, [Color("ff6080"), Color("ffd040"), Color("f0f0ff"), Color("c080ff"), Color("ff9040")][(i + variant) % 5])
	for i in n / 2:
		_mesh(U.sphere_mesh(0.22), Vector3(_rng.randf_range(-0.5, 0.5) * (size.x - 0.5), 0.45, _rng.randf_range(-0.5, 0.5) * (size.z - 0.5)), Color("4a8a3a"))

func _b_crate() -> void:
	var s := size.x
	_box(Vector3(s, s, s), Vector3(0, s * 0.5, 0), color_c.lightened(0.2), Vector3.ZERO, true)
	for y in [0.08, s - 0.08]:
		_box(Vector3(s + 0.04, 0.1, s + 0.04), Vector3(0, y, 0), color_c)
	_box(Vector3(0.1, s * 1.3, s + 0.04), Vector3(0, s * 0.5, 0), color_c, Vector3(0, 0, 45))

func _b_barrel() -> void:
	var r := size.x * 0.5
	_mesh(U.cyl_mesh(r * 0.9, r * 0.9, size.y, 12), Vector3(0, size.y * 0.5, 0), color_c.lightened(0.15), Vector3.ZERO, Vector3(1.0, 1.0, 1.0))
	_mesh(U.cyl_mesh(r, r, size.y * 0.6, 12), Vector3(0, size.y * 0.5, 0), color_c.lightened(0.2))
	for y in [0.15, 0.5, 0.85]:
		_mesh(U.cyl_mesh(r * 1.02, r * 1.02, 0.06, 12), Vector3(0, size.y * y, 0), Color("4a4a52"))
	_col_cyl(r, size.y, Vector3(0, size.y * 0.5, 0))

func _b_cart() -> void:
	_box(Vector3(1.8, 0.6, 2.8), Vector3(0, 1.0, 0), color_c.lightened(0.15), Vector3.ZERO, true)
	for sx in [-1, 1]:
		_mesh(U.cyl_mesh(0.6, 0.6, 0.12, 12), Vector3(sx * 1.0, 0.6, 0.4), color_c.darkened(0.2), Vector3(0, 0, 90))
	_box(Vector3(0.1, 0.1, 2.0), Vector3(-0.4, 0.8, -2.2), color_c)
	_box(Vector3(0.1, 0.1, 2.0), Vector3(0.4, 0.8, -2.2), color_c)
	if variant == 1:
		_mesh(U.sphere_mesh(0.7), Vector3(0, 1.5, 0.2), Color("e0c070"), Vector3.ZERO, Vector3(1.2, 0.6, 1.6))

func _b_well() -> void:
	_mesh(U.cyl_mesh(1.1, 1.2, 1.0, 14), Vector3(0, 0.5, 0), Color("9a948a"))
	_mesh(U.cyl_mesh(0.85, 0.85, 1.02, 14), Vector3(0, 0.52, 0), Color("3a5a7a"))
	for sx in [-1, 1]:
		_box(Vector3(0.18, 2.4, 0.18), Vector3(sx * 0.95, 1.2, 0), color_c)
	_mesh(U.prism_mesh(Vector3(2.8, 0.9, 1.8)), Vector3(0, 2.7, 0), color_b, Vector3(0, 90, 0))
	_col_cyl(1.2, 1.0, Vector3(0, 0.5, 0))

func _b_bench() -> void:
	_box(Vector3(size.x, 0.12, 0.5), Vector3(0, 0.5, 0), color_c.lightened(0.2), Vector3.ZERO, true)
	_box(Vector3(size.x, 0.5, 0.1), Vector3(0, 0.8, 0.22), color_c.lightened(0.2))
	for sx in [-1, 1]:
		_box(Vector3(0.1, 0.5, 0.5), Vector3(sx * (size.x * 0.5 - 0.15), 0.25, 0), Color("2a2a32"))

func _b_stall() -> void:
	var w := size.x
	var d := size.z
	_box(Vector3(w, 1.0, d * 0.5), Vector3(0, 0.5, -d * 0.2), color_c.lightened(0.2), Vector3.ZERO, true)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(0.12, 2.6, 0.12), Vector3(sx * w * 0.48, 1.3, sz * d * 0.45), color_c)
	var stripes := 6
	for i in stripes:
		_box(Vector3(w / stripes, 0.08, d * 1.1), Vector3(-w * 0.5 + (i + 0.5) * w / stripes, 2.7, 0), color_b if i % 2 == 0 else Color("f4f0e6"), Vector3(-12, 0, 0))
	for i in 4:
		_mesh(U.sphere_mesh(0.18), Vector3(-w * 0.35 + i * w * 0.23, 1.15, -d * 0.25), [Color("ff6040"), Color("ffd040"), Color("80d050"), Color("c080ff")][(i + variant) % 4])
	_signboard(label, Vector3(0, 3.1, -d * 0.5), 0)

func _b_awning() -> void:
	for i in 6:
		_box(Vector3(size.x / 6.0, 0.08, size.z), Vector3(-size.x * 0.5 + (i + 0.5) * size.x / 6.0, size.y, 0), color_b if i % 2 == 0 else Color("f4f0e6"), Vector3(-15, 0, 0))

func _b_tent() -> void:
	var w := size.x
	var d := size.z
	_mesh(U.prism_mesh(Vector3(w, size.y, d)), Vector3(0, size.y * 0.5, 0), color_b)
	_box(Vector3(w * 0.4, size.y * 0.6, 0.05), Vector3(0, size.y * 0.3, -d * 0.5 - 0.02), color_b.darkened(0.3))
	_col_box(Vector3(w * 0.8, size.y * 0.7, d), Vector3(0, size.y * 0.35, 0))

func _b_canopy() -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(0.15, size.y, 0.15), Vector3(sx * size.x * 0.48, size.y * 0.5, sz * size.z * 0.48), color_c)
	_box(Vector3(size.x, 0.12, size.z), Vector3(0, size.y, 0), color_b)

func _b_gazebo() -> void:
	var r := size.x * 0.5
	_mesh(U.cyl_mesh(r, r, 0.4, 8), Vector3(0, 0.2, 0), Color("e8e4dc"))
	for i in 8:
		var a := i * TAU / 8.0
		_mesh(U.cyl_mesh(0.12, 0.12, size.y, 8), Vector3(sin(a) * r * 0.9, size.y * 0.5, cos(a) * r * 0.9), Color("f4f0e8"))
	_mesh(U.cyl_mesh(0.0, r * 1.15, size.y * 0.4, 8), Vector3(0, size.y + size.y * 0.2, 0), color_b)
	_col_cyl(r, 0.4, Vector3(0, 0.2, 0))

func _b_banner() -> void:
	_mesh(U.cyl_mesh(0.06, 0.06, size.y, 6), Vector3(0, size.y * 0.5, 0), Color("4a3a2a"))
	_box(Vector3(1.0, 0.05, 0.05), Vector3(0, size.y - 0.1, 0), Color("4a3a2a"))
	_box(Vector3(0.9, size.y * 0.4, 0.04), Vector3(0, size.y * 0.75, 0), color_b)
	_mesh(U.sphere_mesh(0.18), Vector3(0, size.y * 0.78, -0.04), color_c, Vector3.ZERO, Vector3(1, 1, 0.2))

func _b_sign() -> void:
	_mesh(U.cyl_mesh(0.07, 0.07, 2.2, 6), Vector3(0, 1.1, 0), color_c)
	_signboard(label if label != "" else "→", Vector3(0, 1.9, 0), 0)

func _b_haystack() -> void:
	_mesh(U.sphere_mesh(size.x * 0.5), Vector3(0, size.x * 0.25, 0), Color("e0c070"), Vector3.ZERO, Vector3(1, 0.8, 1))
	_col_cyl(size.x * 0.4, size.x * 0.4, Vector3(0, size.x * 0.2, 0))

func _b_field() -> void:
	var rows := int(size.z / 1.2)
	for i in rows:
		_box(Vector3(size.x, 0.25, 0.5), Vector3(0, 0.1, -size.z * 0.5 + (i + 0.5) * size.z / rows), Color("6a4a30"))
		var n := int(size.x / 0.9)
		for j in n:
			var c := color_b
			match variant:
				0: _mesh(U.cyl_mesh(0.0, 0.2, 0.9, 5), Vector3(-size.x * 0.5 + (j + 0.5) * size.x / n, 0.6, -size.z * 0.5 + (i + 0.5) * size.z / rows), Color("e0c050"))
				1: _mesh(U.sphere_mesh(0.28), Vector3(-size.x * 0.5 + (j + 0.5) * size.x / n, 0.35, -size.z * 0.5 + (i + 0.5) * size.z / rows), c)
				_: _mesh(U.sphere_mesh(0.2), Vector3(-size.x * 0.5 + (j + 0.5) * size.x / n, 0.3, -size.z * 0.5 + (i + 0.5) * size.z / rows), Color("e04030") if j % 3 == 0 else Color("4a9a3a"))

func _b_campfire() -> void:
	for i in 6:
		var a := i * TAU / 6.0
		_mesh(U.sphere_mesh(0.2), Vector3(sin(a) * 0.6, 0.1, cos(a) * 0.6), Color("8a8478"))
	for i in 3:
		_box(Vector3(0.12, 0.12, 0.9), Vector3(0, 0.15, 0), Color("5a3a20"), Vector3(0, i * 60, 0))
	_mesh(U.cyl_mesh(0.0, 0.3, 0.8, 8), Vector3(0, 0.5, 0), Color("ffa030"), Vector3.ZERO, Vector3.ONE, U.unshaded(Color("ffa030")))
	_mesh(U.cyl_mesh(0.0, 0.18, 0.6, 8), Vector3(0, 0.45, 0), Color("fff080"), Vector3.ZERO, Vector3.ONE, U.unshaded(Color("fff080")))
	if not Engine.is_editor_hint():
		preload("res://src/render/local_light.gd").attach(_gen, Vector3(0, 1.0, 0), Color("ff9a40"), 8.0, 2.0, true)
		var p := CPUParticles3D.new()
		p.amount = 16
		p.lifetime = 0.9
		p.position = Vector3(0, 0.5, 0)
		p.direction = Vector3.UP
		p.spread = 15.0
		p.gravity = Vector3(0, 1.5, 0)
		p.initial_velocity_min = 0.6
		p.initial_velocity_max = 1.2
		var qm := QuadMesh.new()
		qm.size = Vector2(0.18, 0.18)
		var mm := U.unshaded(Color(1, 0.6, 0.2, 0.8), true).duplicate()
		mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.material = mm
		p.mesh = qm
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = g
		_gen.add_child(p)

func _b_windmill() -> void:
	var h := size.y
	_mesh(U.cyl_mesh(size.x * 0.35, size.x * 0.5, h, 8), Vector3(0, h * 0.5, 0), color_a)
	_col_cyl(size.x * 0.45, h, Vector3(0, h * 0.5, 0))
	_mesh(U.cyl_mesh(0.0, size.x * 0.55, h * 0.3, 8), Vector3(0, h + h * 0.15, 0), color_b)
	_door(Vector3(0, 0, -size.x * 0.48), 1.2, 2.2, Color("5a3a24"), 180)
	var hub := Node3D.new()
	hub.position = Vector3(0, h * 0.85, -size.x * 0.45 - 0.4)
	_gen.add_child(hub)
	U.add_mesh(hub, U.cyl_mesh(0.3, 0.3, 0.6, 8), _m(color_c), Vector3.ZERO, Vector3(90, 0, 0))
	for i in 4:
		var arm := Node3D.new()
		arm.rotation = Vector3(0, 0, i * PI * 0.5)
		hub.add_child(arm)
		U.add_mesh(arm, U.box_mesh(Vector3(0.18, h * 0.55, 0.1)), _m(color_c), Vector3(0, h * 0.28, 0))
		U.add_mesh(arm, U.box_mesh(Vector3(1.4, h * 0.42, 0.05)), _m(Color("f0ece0")), Vector3(0.75, h * 0.32, 0.05))
	_anim_nodes.append(["spin_z", hub, 0.5])

func _b_fountain() -> void:
	var r := size.x * 0.5
	_mesh(U.cyl_mesh(r, r * 1.04, 0.9, 24), Vector3(0, 0.45, 0), color_a)
	_col_cyl(r, 0.9, Vector3(0, 0.45, 0))
	var wm := ShaderMaterial.new()
	wm.shader = load("res://src/terrain/water.gdshader")
	WaterStyle.configure(wm, 0.20)
	wm.set_shader_parameter("noise_tex", BrushTerrain.get_noise_texture())
	wm.set_shader_parameter("has_height", 0.0)
	wm.set_shader_parameter("shallow", Color(0.49, 0.74, 0.65, 0.65))
	wm.set_shader_parameter("minimum_depth", 0.5)
	_mesh(U.cyl_mesh(r * 0.9, r * 0.9, 0.04, 24), Vector3(0, 0.96, 0), Color.WHITE, Vector3.ZERO, Vector3.ONE, wm)
	_mesh(U.cyl_mesh(0.6, 0.9, 2.0, 12), Vector3(0, 1.5, 0), color_a.lightened(0.05))
	_mesh(U.cyl_mesh(r * 0.4, r * 0.3, 0.4, 16), Vector3(0, 2.6, 0), color_a)
	_mesh(U.cyl_mesh(0.25, 0.35, 1.4, 8), Vector3(0, 3.4, 0), color_a.lightened(0.05))
	_mesh(U.sphere_mesh(0.45), Vector3(0, 4.3, 0), color_c)
	if not Engine.is_editor_hint():
		var p := CPUParticles3D.new()
		p.amount = 60
		p.lifetime = 1.3
		p.position = Vector3(0, 4.2, 0)
		p.direction = Vector3.UP
		p.spread = 30.0
		p.gravity = Vector3(0, -9.8, 0)
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 4.0
		var qm := QuadMesh.new()
		qm.size = Vector2(0.15, 0.15)
		var mm := U.unshaded(Color(0.8, 0.95, 1.0, 0.7), true).duplicate()
		mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.material = mm
		p.mesh = qm
		_gen.add_child(p)

func _b_obelisk() -> void:
	var h := size.y
	_box(Vector3(size.x * 1.6, 0.8, size.x * 1.6), Vector3(0, 0.4, 0), color_a.darkened(0.1), Vector3.ZERO, true)
	_mesh(U.cyl_mesh(size.x * 0.32, size.x * 0.5, h, 4), Vector3(0, h * 0.5 + 0.8, 0), color_a, Vector3(0, 45, 0))
	_mesh(U.cyl_mesh(0.0, size.x * 0.33, size.x * 0.7, 4), Vector3(0, h + 0.8 + size.x * 0.35, 0), color_c, Vector3(0, 45, 0))
	_mesh(U.sphere_mesh(0.25), Vector3(0, h * 0.75, -size.x * 0.42), Color.WHITE, Vector3.ZERO, Vector3(1, 1, 0.4), U.unshaded(color_b))
	_col_box(Vector3(size.x * 0.8, h, size.x * 0.8), Vector3(0, h * 0.5 + 0.8, 0))

func _b_statue() -> void:
	# 女神像：底座 + 长袍身姿 + 高举火炬
	var s := size.y / 10.0
	_mesh(U.cyl_mesh(2.5 * s, 3.0 * s, 2.5 * s, 8), Vector3(0, 1.25 * s, 0), color_a.darkened(0.15))
	_mesh(U.cyl_mesh(1.8 * s, 2.2 * s, 1.0 * s, 8), Vector3(0, 3.0 * s, 0), color_a.darkened(0.05))
	_col_cyl(2.8 * s, 3.5 * s, Vector3(0, 1.75 * s, 0))
	var sc := color_c
	_mesh(U.cyl_mesh(0.7 * s, 1.4 * s, 3.4 * s, 12), Vector3(0, 5.2 * s, 0), sc)
	_mesh(U.cyl_mesh(0.55 * s, 0.7 * s, 1.8 * s, 12), Vector3(0, 7.7 * s, 0), sc)
	_mesh(U.sphere_mesh(0.5 * s), Vector3(0, 9.0 * s, 0), sc)
	_mesh(U.capsule_mesh(0.3 * s, 2.2 * s), Vector3(0, 9.0 * s, 0.25 * s), sc, Vector3(15, 0, 0))
	_mesh(U.capsule_mesh(0.18 * s, 2.0 * s), Vector3(0.6 * s, 9.2 * s, 0), sc, Vector3(0, 0, -15))
	_mesh(U.capsule_mesh(0.18 * s, 1.7 * s), Vector3(-0.6 * s, 7.3 * s, -0.3 * s), sc, Vector3(30, 0, 20))
	_mesh(U.cyl_mesh(0.25 * s, 0.12 * s, 0.6 * s, 8), Vector3(0.85 * s, 10.4 * s, 0), Color("e8c27a"))
	_mesh(U.sphere_mesh(0.35 * s), Vector3(0.85 * s, 10.9 * s, 0), Color.WHITE, Vector3.ZERO, Vector3(1, 1.4, 1), get_lamp_mat())
	for sx in [-1, 1]:
		_mesh(U.prism_mesh(Vector3(2.4 * s, 2.6 * s, 0.15 * s)), Vector3(sx * 1.2 * s, 7.8 * s, 0.6 * s), sc.lightened(0.05), Vector3(0, sx * 15, sx * -40))

func _b_ship() -> void:
	var l := size.z
	var w := size.x
	_mesh(U.capsule_mesh(w * 0.5, l), Vector3(0, 0.6, 0), color_c, Vector3(90, 0, 0), Vector3(1, 1, 0.55))
	_box(Vector3(w * 0.9, 0.2, l * 0.85), Vector3(0, 1.4, 0), color_c.lightened(0.25), Vector3.ZERO, true)
	_col_box(Vector3(w, 2.0, l * 0.9), Vector3(0, 0.6, 0))
	_box(Vector3(w * 0.7, 1.4, l * 0.25), Vector3(0, 2.1, l * 0.3), color_c.lightened(0.15), Vector3.ZERO, true)
	var masts := 2 if l > 18.0 else 1
	for i in masts:
		var z := (i - (masts - 1) * 0.5) * l * 0.35 - l * 0.05
		_mesh(U.cyl_mesh(0.15, 0.2, l * 0.7, 8), Vector3(0, 1.4 + l * 0.35, z), Color("6a4a30"))
		_box(Vector3(w * 1.5, l * 0.32, 0.08), Vector3(0, 1.4 + l * 0.42, z - 0.2), Color("f4f0e6"))
		_box(Vector3(w * 1.6, 0.12, 0.12), Vector3(0, 1.4 + l * 0.6, z - 0.2), Color("6a4a30"))
	_box(Vector3(0.08, 0.6, 1.0), Vector3(0, 1.4 + l * 0.72, 0), color_b)
	_anim_nodes.append(["bob", _gen, 0.0])

func _b_boat() -> void:
	_mesh(U.capsule_mesh(size.x * 0.5, size.z), Vector3(0, 0.3, 0), color_c, Vector3(90, 0, 0), Vector3(1, 1, 0.45))
	_box(Vector3(size.x * 0.8, 0.1, 0.4), Vector3(0, 0.55, 0), color_c.lightened(0.2))
	_anim_nodes.append(["bob", _gen, 0.0])

func _b_buoy() -> void:
	_mesh(U.cyl_mesh(0.3, 0.5, 1.2, 10), Vector3(0, 0.3, 0), Color("c03a3a"))
	_mesh(U.sphere_mesh(0.15), Vector3(0, 1.0, 0), Color.WHITE, Vector3.ZERO, Vector3.ONE, get_lamp_mat())
	_anim_nodes.append(["bob", _gen, 0.0])

func _b_pier() -> void:
	var w := size.x
	var l := size.z
	_box(Vector3(w, 0.35, l), Vector3(0, size.y, 0), color_c.lightened(0.2), Vector3.ZERO, true)
	var n := int(l / 3.0) + 1
	for i in n:
		for sx in [-1, 1]:
			_mesh(U.cyl_mesh(0.18, 0.18, size.y + 4.0, 8), Vector3(sx * (w * 0.5 - 0.2), size.y - 2.0, -l * 0.5 + i * l / maxi(1, n - 1)), color_c.darkened(0.2))
	for i in int(l / 0.8):
		_box(Vector3(w, 0.04, 0.05), Vector3(0, size.y + 0.19, -l * 0.5 + i * 0.8), color_c.darkened(0.15))

func _b_crane() -> void:
	var h := size.y
	_box(Vector3(2.5, 1.0, 2.5), Vector3(0, 0.5, 0), Color("6a6a72"), Vector3.ZERO, true)
	_box(Vector3(0.8, h, 0.8), Vector3(0, h * 0.5, 0), color_c, Vector3.ZERO, true)
	for i in int(h / 1.5):
		_box(Vector3(0.9, 0.08, 0.08), Vector3(0, i * 1.5, 0), color_c.darkened(0.2), Vector3(0, 0, 40))
	_box(Vector3(0.6, 0.6, size.z), Vector3(0, h, -size.z * 0.35), color_c)
	_box(Vector3(1.6, 1.4, 1.6), Vector3(0, h - 0.5, 1.0), Color("6a6a72"))
	_mesh(U.cyl_mesh(0.02, 0.02, h * 0.5, 4), Vector3(0, h * 0.75, -size.z * 0.8), Color("2a2a2a"))
	_box(Vector3(1.4, 1.0, 1.4), Vector3(0, h * 0.5, -size.z * 0.8), Color("a06a40"))

func _b_column() -> void:
	var r := size.x * 0.5
	_box(Vector3(r * 2.4, 0.5, r * 2.4), Vector3(0, 0.25, 0), color_a.darkened(0.1))
	_mesh(U.cyl_mesh(r, r * 1.1, size.y, 12), Vector3(0, size.y * 0.5, 0), color_a)
	_box(Vector3(r * 2.6, 0.5, r * 2.6), Vector3(0, size.y, 0), color_a.darkened(0.1))
	_col_cyl(r, size.y, Vector3(0, size.y * 0.5, 0))

func _b_pillar_row() -> void:
	var n := maxi(2, int(size.x / 4.0))
	for i in n:
		var x := -size.x * 0.5 + i * size.x / (n - 1)
		_mesh(U.cyl_mesh(0.5, 0.55, size.y, 10), Vector3(x, size.y * 0.5, 0), color_a)
		_col_cyl(0.5, size.y, Vector3(x, size.y * 0.5, 0))
	_box(Vector3(size.x + 1.0, 1.0, 1.4), Vector3(0, size.y + 0.5, 0), color_a.darkened(0.08), Vector3.ZERO, true)

func _b_arch() -> void:
	var w := size.x
	var h := size.y
	for sx in [-1, 1]:
		_box(Vector3(1.2, h, size.z), Vector3(sx * (w * 0.5 + 0.6), h * 0.5, 0), color_a, Vector3.ZERO, true)
	_mesh(U.torus_mesh(w * 0.5, w * 0.5 + 1.2, 24), Vector3(0, h, 0), color_a, Vector3(90, 0, 0), Vector3(1, size.z, 1))
	_box(Vector3(w + 2.4, 1.2, size.z), Vector3(0, h + w * 0.5 + 0.4, 0), color_a.darkened(0.08), Vector3.ZERO, true)

func _b_ruin_wall() -> void:
	var l := size.x
	var h := size.y
	var n := maxi(3, int(l / 1.5))
	for i in n:
		var hh := h * _rng.randf_range(0.45, 1.0)
		if i == 0 or i == n - 1:
			hh = h * _rng.randf_range(0.3, 0.6)
		_box(Vector3(l / n + 0.05, hh, size.z), Vector3(-l * 0.5 + (i + 0.5) * l / n, hh * 0.5, 0), color_a.darkened(_rng.randf() * 0.12))
	_col_box(Vector3(l, h * 0.8, size.z), Vector3(0, h * 0.4, 0))
	if variant == 1:
		# 拱窗（参考废墟圣堂）
		_mesh(U.torus_mesh(1.4, 2.2, 20), Vector3(0, h * 0.6, 0), color_a.lightened(0.05), Vector3(90, 0, 0), Vector3(1, size.z * 1.05, 1))
	# 藤蔓
	for i in int(l / 3.0):
		_mesh(U.capsule_mesh(0.12, h * 0.5), Vector3(-l * 0.5 + _rng.randf() * l, h * 0.35, -size.z * 0.5 - 0.05), Color("4a7a3a"))

func _b_pillar() -> void:
	var r := size.x * 0.5
	var h := size.y
	_mesh(U.cyl_mesh(r, r * 1.05, h, 10), Vector3(0, h * 0.5, 0), color_a)
	if variant == 1:
		_mesh(U.cyl_mesh(r * 0.9, r, h * 0.15, 10), Vector3(0.2, h + 0.3, 0.1), color_a.darkened(0.1), Vector3(12, 0, 25))
	else:
		_box(Vector3(r * 2.5, 0.5, r * 2.5), Vector3(0, h, 0), color_a.darkened(0.1))
	_box(Vector3(r * 2.5, 0.5, r * 2.5), Vector3(0, 0.25, 0), color_a.darkened(0.1))
	_col_cyl(r, h, Vector3(0, h * 0.5, 0))
	_mesh(U.capsule_mesh(0.1, h * 0.6), Vector3(r * 0.9, h * 0.4, 0), Color("4a7a3a"))

func _b_portal_ring() -> void:
	var r := size.x * 0.5
	_mesh(U.cyl_mesh(r * 1.3, r * 1.4, 0.6, 24), Vector3(0, 0.3, 0), Color("6a6a7a"))
	_col_cyl(r * 1.3, 0.6, Vector3(0, 0.3, 0))
	var ring := Node3D.new()
	ring.position = Vector3(0, r + 0.8, 0)
	_gen.add_child(ring)
	U.add_mesh(ring, U.torus_mesh(r * 0.85, r, 40), _m(color_c), Vector3.ZERO, Vector3(90, 0, 0))
	U.add_mesh(ring, U.cyl_mesh(r * 0.85, r * 0.85, 0.05, 40), U.unshaded(Color(color_b.r, color_b.g, color_b.b, 0.55), true), Vector3.ZERO, Vector3(90, 0, 0))
	for i in 6:
		var a := i * TAU / 6.0
		U.add_mesh(ring, U.sphere_mesh(0.18), U.unshaded(color_b), Vector3(cos(a) * r, sin(a) * r, 0))
	_anim_nodes.append(["spin_z", ring, 0.4])

func _b_train() -> void:
	# 魔导列车：机车 + 车厢
	var cars := maxi(1, variant + 2)
	for i in cars:
		var z := i * 13.0
		if i == 0:
			_box(Vector3(3.0, 2.6, 6.0), Vector3(0, 2.1, z - 3.0), color_b, Vector3.ZERO, true)
			_mesh(U.cyl_mesh(1.3, 1.3, 7.0, 16), Vector3(0, 2.4, z + 2.5), color_b.darkened(0.15), Vector3(90, 0, 0))
			_mesh(U.cyl_mesh(0.4, 0.5, 1.6, 10), Vector3(0, 4.0, z + 4.5), Color("2a2a32"))
			_mesh(U.cyl_mesh(1.35, 1.35, 0.4, 16), Vector3(0, 2.4, z + 6.0), Color("e8c27a"), Vector3(90, 0, 0))
			_mesh(U.sphere_mesh(0.4), Vector3(0, 2.6, z + 6.2), Color.WHITE, Vector3.ZERO, Vector3.ONE, get_lamp_mat())
			_mesh(U.cyl_mesh(0.5, 0.5, 0.2, 12), Vector3(0, 3.2, z - 1.0), Color.WHITE, Vector3(90, 0, 0), Vector3.ONE, U.unshaded(Color("80e0ff")))
			_box(Vector3(3.2, 0.3, 6.4), Vector3(0, 3.5, z - 3.0), color_c)
		else:
			_box(Vector3(3.0, 2.8, 12.0), Vector3(0, 2.3, z - 1.0), color_a, Vector3.ZERO, true)
			_box(Vector3(3.2, 0.3, 12.2), Vector3(0, 3.8, z - 1.0), color_c)
			for k in 5:
				_window(Vector3(1.55, 2.6, z - 5.0 + k * 2.2), 1.0, 1.0, 90)
				_window(Vector3(-1.55, 2.6, z - 5.0 + k * 2.2), 1.0, 1.0, -90)
		for k in 3:
			for sx in [-1, 1]:
				_mesh(U.cyl_mesh(0.55, 0.55, 0.2, 12), Vector3(sx * 1.4, 0.7, z - 4.0 + k * 3.5), Color("3a3a42"), Vector3(0, 0, 90))

func _b_rail() -> void:
	var l := size.x
	for sz in [-0.75, 0.75]:
		_box(Vector3(l, 0.15, 0.12), Vector3(0, 0.3, sz), Color("6a6a72"))
	for i in int(l / 1.0):
		_box(Vector3(0.35, 0.15, 2.4), Vector3(-l * 0.5 + 0.5 + i, 0.15, 0), Color("5a4030"))
	_box(Vector3(l, 0.3, 3.2), Vector3(0, -0.05, 0), Color("8a8478"))

func _b_airship() -> void:
	var l := size.z
	_mesh(U.capsule_mesh(l * 0.18, l), Vector3(0, l * 0.3, 0), color_a, Vector3(90, 0, 0), Vector3(1, 1, 0.85))
	for i in 5:
		_mesh(U.torus_mesh(l * 0.18, l * 0.185, 24), Vector3(0, l * 0.3, -l * 0.3 + i * l * 0.15), color_c, Vector3(90, 0, 0), Vector3(1, 1, 0.85))
	for sx in [-1, 1]:
		_mesh(U.prism_mesh(Vector3(l * 0.25, l * 0.15, 0.1)), Vector3(sx * l * 0.12, l * 0.36, l * 0.45), color_b, Vector3(0, 90, sx * 90))
	_box(Vector3(l * 0.16, l * 0.08, l * 0.4), Vector3(0, l * 0.06, 0), color_c.lightened(0.2))
	for k in 4:
		_window(Vector3(l * 0.08 + 0.05, l * 0.06, -l * 0.12 + k * l * 0.08), 0.6, 0.5, 90)
		_window(Vector3(-l * 0.08 - 0.05, l * 0.06, -l * 0.12 + k * l * 0.08), 0.6, 0.5, -90)
	for sx in [-1, 1]:
		var prop := Node3D.new()
		prop.position = Vector3(sx * l * 0.12, l * 0.1, l * 0.22)
		_gen.add_child(prop)
		for b in 3:
			U.add_mesh(prop, U.box_mesh(Vector3(0.25, l * 0.1, 0.05)), _m(Color("6a4a30")), Vector3.ZERO, Vector3(0, 0, b * 120))
		_anim_nodes.append(["spin_z", prop, 6.0])
	if variant == 0:
		_anim_nodes.append(["bob", _gen, 0.0])

func _b_dome() -> void:
	# 天文台
	var r := size.x * 0.5
	_mesh(U.cyl_mesh(r, r, size.y, 20), Vector3(0, size.y * 0.5, 0), color_a)
	_col_cyl(r, size.y, Vector3(0, size.y * 0.5, 0))
	_mesh(U.sphere_mesh(r * 1.02, r * 2.04, true, 24), Vector3(0, size.y, 0), color_b)
	_box(Vector3(r * 0.35, r * 1.1, r * 2.1), Vector3(0, size.y + r * 0.5, 0), color_c.darkened(0.4), Vector3(0, 0, 0))
	_mesh(U.cyl_mesh(r * 0.12, r * 0.18, r * 1.4, 10), Vector3(0, size.y + r * 0.9, -r * 0.4), Color("b08a40"), Vector3(-50, 0, 0))
	_mesh(U.torus_mesh(r * 1.0, r * 1.06, 32), Vector3(0, size.y, 0), color_c)
	_door(Vector3(0, 0, -r - 0.05), 1.4, 2.5, Color("4a3020"), 180)
	for i in 6:
		var a := i * TAU / 6.0 + 0.5
		_window(Vector3(sin(a) * (r + 0.05), size.y * 0.6, cos(a) * (r + 0.05)), 0.8, 1.4, rad_to_deg(a))
	_signboard(label, Vector3(0, 3.2, -r - 0.4), 0)

func _b_church() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d)
	_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	_gable_roof(w, d, h, w * 0.6, color_b, 0.5)
	_col_box(Vector3(w, w * 0.4, d), Vector3(0, h + w * 0.2, 0))
	# 钟楼
	var tw := w * 0.42
	var th := h * 2.1
	_box(Vector3(tw, th, tw), Vector3(0, th * 0.5, -d * 0.5 - tw * 0.3), color_a.lightened(0.05), Vector3.ZERO, true)
	_mesh(U.cyl_mesh(0.0, tw * 0.8, tw * 1.6, 4), Vector3(0, th + tw * 0.8, -d * 0.5 - tw * 0.3), color_b, Vector3(0, 45, 0))
	_mesh(U.cyl_mesh(0.08, 0.08, 2.0, 6), Vector3(0, th + tw * 1.6 + 0.8, -d * 0.5 - tw * 0.3), Color("e8c27a"))
	_box(Vector3(1.2, 0.15, 0.15), Vector3(0, th + tw * 1.6 + 1.2, -d * 0.5 - tw * 0.3), Color("e8c27a"))
	_box(Vector3(tw * 0.6, tw * 0.7, 0.2), Vector3(0, th - tw * 0.6, -d * 0.5 - tw * 0.8 - 0.05), Color("2a2a32"))
	# 玫瑰窗
	_mesh(U.cyl_mesh(tw * 0.32, tw * 0.32, 0.2, 16), Vector3(0, th * 0.6, -d * 0.5 - tw * 0.8 - 0.05), Color.WHITE, Vector3(90, 0, 0), Vector3.ONE, get_window_mat())
	_mesh(U.torus_mesh(tw * 0.3, tw * 0.36, 24), Vector3(0, th * 0.6, -d * 0.5 - tw * 0.8 - 0.08), color_c, Vector3(90, 0, 0))
	_door(Vector3(0, 0, -d * 0.5 - tw * 0.8 - 0.05), 2.2, 3.6, Color("5a3a24"), 180)
	for i in int(d / 4.0):
		for sx in [-1, 1]:
			_window(Vector3(sx * (w * 0.5 + 0.05), h * 0.55, -d * 0.5 + 2.0 + i * 4.0), 1.2, h * 0.5, sx * 90)
			_box(Vector3(1.0, h * 0.8, 1.0), Vector3(sx * (w * 0.5 + 0.4), h * 0.4, -d * 0.5 + 4.0 + i * 4.0), color_a.darkened(0.08))
	_signboard(label, Vector3(0, 4.5, -d * 0.5 - tw * 0.8 - 0.3), 0)

func _b_station() -> void:
	# 欧式中央车站：拱形玻璃大厅 + 钟楼 + 红砖立面（参考设定）
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d, Color("a09a8a"))
	var brick := color_a
	var stone := color_c
	_box(Vector3(w, h, d * 0.3), Vector3(0, h * 0.5, -d * 0.35), brick, Vector3.ZERO, true)
	for sx in [-1, 1]:
		_box(Vector3(w * 0.12, h * 1.3, d * 0.32), Vector3(sx * w * 0.45, h * 0.65, -d * 0.35), stone, Vector3.ZERO, true)
		_mesh(U.sphere_mesh(w * 0.07, w * 0.14, true), Vector3(sx * w * 0.45, h * 1.3, -d * 0.35), color_b)
		_mesh(U.cyl_mesh(0.05, 0.05, 1.5, 6), Vector3(sx * w * 0.45, h * 1.3 + w * 0.07 + 0.6, -d * 0.35), Color("e8c27a"))
	# 中央大拱
	_mesh(U.cyl_mesh(w * 0.22, w * 0.22, d * 0.32, 24), Vector3(0, h * 0.85, -d * 0.35), color_b.lightened(0.3), Vector3(90, 0, 0), Vector3(1, 1, 1), get_window_mat())
	_mesh(U.torus_mesh(w * 0.22, w * 0.25, 32), Vector3(0, h * 0.85, -d * 0.5 - 0.05), stone, Vector3(90, 0, 0))
	_box(Vector3(w * 0.44, h * 0.85, 0.3), Vector3(0, h * 0.42, -d * 0.5 - 0.1), Color("3a3a42"))
	_door(Vector3(0, 0, -d * 0.5 - 0.3), 3.6, 4.5, Color("2a3a4a"), 180)
	# 列柱
	for i in 6:
		var x := (i - 2.5) * w * 0.14
		if absf(x) < w * 0.2:
			continue
		_mesh(U.cyl_mesh(0.45, 0.5, h * 0.8, 10), Vector3(x, h * 0.4, -d * 0.5 - 0.6), stone)
	# 钟楼
	var cx := w * 0.3
	_box(Vector3(5.0, h * 2.0, 5.0), Vector3(cx, h, -d * 0.52), stone, Vector3.ZERO, true)
	_mesh(U.cyl_mesh(1.6, 1.6, 0.3, 24), Vector3(cx, h * 1.6, -d * 0.52 - 2.6), Color("f4f0e6"), Vector3(90, 0, 0))
	_box(Vector3(0.12, 1.3, 0.1), Vector3(cx, h * 1.6 + 0.4, -d * 0.52 - 2.8), Color("2a2a2a"))
	_box(Vector3(0.9, 0.12, 0.1), Vector3(cx + 0.4, h * 1.6, -d * 0.52 - 2.8), Color("2a2a2a"))
	_mesh(U.cyl_mesh(0.0, 3.8, 4.0, 4), Vector3(cx, h * 2.0 + 2.0, -d * 0.52), color_b, Vector3(0, 45, 0))
	# 玻璃拱顶站台大厅
	var hall_d := d * 0.65
	for sx in [-1, 1]:
		_box(Vector3(1.0, h * 0.6, hall_d), Vector3(sx * w * 0.45, h * 0.3, d * 0.15), brick, Vector3.ZERO, true)
	var arcs := int(hall_d / 4.0)
	for i in arcs:
		_mesh(U.torus_mesh(w * 0.43, w * 0.45, 32), Vector3(0, h * 0.6, -d * 0.18 + i * 4.0), Color("3a4a5a"), Vector3(90, 0, 0), Vector3(1, 0.4, 1))
	_mesh(U.cyl_mesh(w * 0.44, w * 0.44, hall_d, 24), Vector3(0, h * 0.6, d * 0.15), Color.WHITE, Vector3(90, 0, 0), Vector3(1, 1, 1), U.mat(Color(0.7, 0.85, 0.95, 0.45), 0.0, true))
	_signboard(label, Vector3(0, h * 1.05, -d * 0.5 - 0.35), 0)

func _b_cityhall() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d)
	_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(w + 0.6, 0.6, d + 0.6), Vector3(0, h, 0), color_c)
	_mesh(U.sphere_mesh(w * 0.22, w * 0.44, true, 24), Vector3(0, h + 3.0, 0), color_b)
	_mesh(U.cyl_mesh(w * 0.22, w * 0.22, 3.0, 24), Vector3(0, h + 1.5, 0), color_a.lightened(0.05))
	_mesh(U.cyl_mesh(0.3, 0.6, 2.0, 8), Vector3(0, h + 3.0 + w * 0.22 + 0.8, 0), Color("e8c27a"))
	# 钟
	_mesh(U.cyl_mesh(1.5, 1.5, 0.3, 24), Vector3(0, h + 1.5, -w * 0.22 - 0.1), Color("f4f0e6"), Vector3(90, 0, 0))
	# 门廊
	_box(Vector3(w * 0.6, 0.8, 5.0), Vector3(0, 0.4, -d * 0.5 - 2.5), color_a.darkened(0.1), Vector3.ZERO, true)
	for i in 6:
		var x := (i - 2.5) * w * 0.1
		_mesh(U.cyl_mesh(0.5, 0.55, h * 0.75, 12), Vector3(x, 0.8 + h * 0.37, -d * 0.5 - 4.2), color_a.lightened(0.1))
	_mesh(U.prism_mesh(Vector3(w * 0.64, 3.0, 5.6)), Vector3(0, 0.8 + h * 0.75 + 1.5, -d * 0.5 - 2.5), color_a, Vector3(0, 90, 0))
	_mesh(U.prism_mesh(Vector3(5.6, 3.0, w * 0.64)), Vector3(0, 0.8 + h * 0.75 + 1.5, -d * 0.5 - 2.5), color_a)
	_door(Vector3(0, 0.8, -d * 0.5 - 0.05), 2.4, 3.6, Color("4a3020"), 180)
	for f in 2:
		for i in int(w / 3.5):
			var x2 := -w * 0.5 + 1.75 + i * 3.5
			if absf(x2) < 2.0 and f == 0:
				continue
			_window(Vector3(x2, 2.5 + f * 4.0, -d * 0.5 - 0.05), 1.2, 2.0, 180)
	_signboard(label, Vector3(0, h - 0.8, -d * 0.5 - 0.2), 0)

func _b_guildhall() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d)
	_box(Vector3(w, h * 0.45, d), Vector3(0, h * 0.225, 0), Color("9a948a"), Vector3.ZERO, true)
	_box(Vector3(w - 0.2, h * 0.55, d - 0.2), Vector3(0, h * 0.45 + h * 0.275, 0), color_a, Vector3.ZERO, true)
	_hip_roof(w, d, h, h * 0.45, color_b, 0.8)
	_col_box(Vector3(w, h * 0.3, d), Vector3(0, h + h * 0.15, 0))
	for sx in [-1, 1]:
		_mesh(U.cyl_mesh(2.0, 2.2, h * 1.3, 12), Vector3(sx * w * 0.5, h * 0.65, -d * 0.5), color_a.lightened(0.05))
		_mesh(U.cyl_mesh(0.0, 2.5, 4.0, 12), Vector3(sx * w * 0.5, h * 1.3 + 2.0, -d * 0.5), color_b)
		_col_cyl(2.1, h * 1.3, Vector3(sx * w * 0.5, h * 0.65, -d * 0.5))
		_box(Vector3(1.5, h * 0.6, 0.06), Vector3(sx * w * 0.25, h * 0.5, -d * 0.5 - 0.1), Color("2a5aa8"))
	_door(Vector3(0, 0, -d * 0.5 - 0.05), 2.6, 3.6, Color("4a3020"), 180)
	for i in int(w / 3.2):
		var x := -w * 0.5 + 1.6 + i * 3.2
		if absf(x) > 2.5:
			_window(Vector3(x, h * 0.25, -d * 0.5 - 0.05), 1.0, 1.6, 180)
		_window(Vector3(x, h * 0.7, -d * 0.5 - 0.05), 1.0, 1.8, 180)
	_signboard(label, Vector3(0, h * 0.5, -d * 0.5 - 0.2), 0)

func _b_hall() -> void:
	# 通用大型公共建筑（传送门大厅/交易所/银行/图书馆等）
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d)
	_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(w + 0.5, 0.6, d + 0.5), Vector3(0, h, 0), color_c)
	match variant:
		0:
			_gable_roof(w, d, h, w * 0.3, color_b, 0.4)
		1:
			_mesh(U.sphere_mesh(minf(w, d) * 0.4, minf(w, d) * 0.8, true, 24), Vector3(0, h + 0.3, 0), color_b)
			_mesh(U.cyl_mesh(0.3, 0.5, 2.0, 8), Vector3(0, h + minf(w, d) * 0.4 + 1.0, 0), Color("e8c27a"))
		_:
			_hip_roof(w, d, h + 0.3, h * 0.4, color_b, 0.6)
	_col_box(Vector3(w, 3.0, d), Vector3(0, h + 1.5, 0))
	for i in 4:
		var x := (i - 1.5) * w * 0.2
		_mesh(U.cyl_mesh(0.4, 0.45, h * 0.85, 10), Vector3(x, h * 0.42, -d * 0.5 - 0.6), color_a.lightened(0.1))
	_door(Vector3(0, 0, -d * 0.5 - 0.05), 2.4, 3.4, Color("3a2a1a"), 180)
	for i in int(w / 3.0):
		var x2 := -w * 0.5 + 1.5 + i * 3.0
		if absf(x2) > 2.5:
			_window(Vector3(x2, h * 0.5, -d * 0.5 - 0.05), 1.1, 2.2, 180)
	for j in int(d / 3.5):
		_window(Vector3(-w * 0.5 - 0.05, h * 0.5, -d * 0.5 + 1.75 + j * 3.5), 1.1, 2.2, -90)
		_window(Vector3(w * 0.5 + 0.05, h * 0.5, -d * 0.5 + 1.75 + j * 3.5), 1.1, 2.2, 90)
	_signboard(label, Vector3(0, h * 0.82, -d * 0.5 - 0.2), 0)

func _b_mine_entrance() -> void:
	for sx in [-1, 1]:
		_box(Vector3(0.6, 4.0, 0.6), Vector3(sx * 2.2, 2.0, 0), Color("6a4a30"), Vector3.ZERO, true)
	_box(Vector3(5.6, 0.6, 0.7), Vector3(0, 4.1, 0), Color("6a4a30"), Vector3.ZERO, true)
	_box(Vector3(4.0, 4.0, 0.2), Vector3(0, 2.0, 0.6), Color("1a1410"))
	_signboard(label, Vector3(0, 4.9, -0.4), 0)
	_mesh(U.cyl_mesh(0.12, 0.12, 0.3, 8), Vector3(2.2, 3.0, -0.4), Color.WHITE, Vector3.ZERO, Vector3.ONE, get_lamp_mat())

func _b_tunnel() -> void:
	var w := size.x
	var h := size.y
	var l := size.z
	for sx in [-1, 1]:
		_box(Vector3(1.5, h, l), Vector3(sx * (w * 0.5 + 0.75), h * 0.5, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(w + 3.0, 1.5, l), Vector3(0, h + 0.75, 0), color_a, Vector3.ZERO, true)
	var n := int(l / 4.0)
	for i in n:
		var z := -l * 0.5 + 2.0 + i * 4.0
		for sx in [-1, 1]:
			_box(Vector3(0.4, h, 0.4), Vector3(sx * (w * 0.5 - 0.2), h * 0.5, z), color_c)
		_box(Vector3(w, 0.4, 0.4), Vector3(0, h - 0.2, z), color_c)

func _b_anvil() -> void:
	_box(Vector3(0.5, 0.6, 0.5), Vector3(0, 0.3, 0), Color("5a4030"), Vector3.ZERO, true)
	_box(Vector3(0.9, 0.3, 0.4), Vector3(0, 0.75, 0), Color("3a3a42"))
	_mesh(U.cyl_mesh(0.0, 0.2, 0.4, 6), Vector3(0.6, 0.75, 0), Color("3a3a42"), Vector3(0, 0, 90))

func _b_brazier() -> void:
	_mesh(U.cyl_mesh(0.1, 0.15, 1.2, 6), Vector3(0, 0.6, 0), Color("3a3a42"))
	_mesh(U.cyl_mesh(0.5, 0.25, 0.4, 10), Vector3(0, 1.3, 0), Color("3a3a42"))
	_mesh(U.cyl_mesh(0.0, 0.35, 0.7, 8), Vector3(0, 1.75, 0), Color.WHITE, Vector3.ZERO, Vector3.ONE, U.unshaded(color_b if color_b != Color("b05a3a") else Color("ff9030")))
	_col_cyl(0.3, 1.5, Vector3(0, 0.75, 0))
	if not Engine.is_editor_hint():
		preload("res://src/render/local_light.gd").attach(_gen, Vector3(0, 2.0, 0), color_b if color_b != Color("b05a3a") else Color("ff9a40"), 9.0, 1.8, true)

func _b_pipe() -> void:
	_mesh(U.cyl_mesh(size.x * 0.5, size.x * 0.5, size.z, 10), Vector3(0, size.y, 0), color_c, Vector3(90, 0, 0))
	for i in int(size.z / 3.0) + 1:
		_mesh(U.cyl_mesh(size.x * 0.6, size.x * 0.6, 0.2, 10), Vector3(0, size.y, -size.z * 0.5 + i * 3.0), Color("e8c27a"), Vector3(90, 0, 0))
		_box(Vector3(0.2, size.y, 0.2), Vector3(0, size.y * 0.5, -size.z * 0.5 + i * 3.0), Color("4a4a52"))

func _b_clocktower() -> void:
	var w := size.x
	var h := size.y
	_foundation(w, w)
	_box(Vector3(w, h, w), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	for f in 4:
		var a := f * 90.0
		var n := Node3D.new()
		n.rotation_degrees.y = a
		n.position = Vector3(0, h * 0.82, 0)
		_gen.add_child(n)
		U.add_mesh(n, U.cyl_mesh(w * 0.35, w * 0.35, 0.3, 24), _m(Color("f4f0e6")), Vector3(0, 0, -w * 0.5 - 0.1), Vector3(90, 0, 0))
		U.add_mesh(n, U.torus_mesh(w * 0.33, w * 0.38, 24), _m(Color("e8c27a")), Vector3(0, 0, -w * 0.5 - 0.15), Vector3(90, 0, 0))
		U.add_mesh(n, U.box_mesh(Vector3(0.15, w * 0.28, 0.1)), _m(Color("2a2a2a")), Vector3(0, w * 0.12, -w * 0.5 - 0.3))
		U.add_mesh(n, U.box_mesh(Vector3(w * 0.22, 0.15, 0.1)), _m(Color("2a2a2a")), Vector3(w * 0.1, 0, -w * 0.5 - 0.3))
	_box(Vector3(w + 0.6, 0.6, w + 0.6), Vector3(0, h, 0), color_c)
	_mesh(U.cyl_mesh(0.0, w * 0.75, w * 1.2, 4), Vector3(0, h + w * 0.6, 0), color_b, Vector3(0, 45, 0))
	_door(Vector3(0, 0, -w * 0.5 - 0.05), 1.6, 2.6, Color("4a3020"), 180)

func _b_bell() -> void:
	_mesh(U.cyl_mesh(size.x * 0.25, size.x * 0.5, size.y, 16), Vector3(0, size.y * 0.5, 0), color_c)
	_mesh(U.torus_mesh(size.x * 0.45, size.x * 0.55, 20), Vector3(0, 0.1, 0), color_c.darkened(0.2))
	_mesh(U.sphere_mesh(size.x * 0.27, size.x * 0.54, true), Vector3(0, size.y, 0), color_c)

func _b_grave() -> void:
	_box(Vector3(0.9, 1.2, 0.25), Vector3(0, 0.6, 0), Color("9a9a9a"), Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)), true)
	_mesh(U.cyl_mesh(0.45, 0.45, 0.25, 12), Vector3(0, 1.2, 0), Color("9a9a9a"), Vector3(90, 0, 0))
	_box(Vector3(1.0, 0.2, 1.8), Vector3(0, 0.1, 1.0), Color("6a5a4a"))

func _b_chest_obj() -> void:
	_box(Vector3(1.0, 0.6, 0.7), Vector3(0, 0.3, 0), Color("8a5a30"), Vector3.ZERO, true)
	_mesh(U.cyl_mesh(0.35, 0.35, 1.0, 12), Vector3(0, 0.6, 0), Color("8a5a30"), Vector3(0, 0, 90), Vector3(1, 1, 1))
	_box(Vector3(1.04, 0.1, 0.74), Vector3(0, 0.55, 0), Color("e8c27a"))

func _b_signal_lamp() -> void:
	_mesh(U.cyl_mesh(0.1, 0.12, 4.0, 6), Vector3(0, 2.0, 0), Color("3a3a42"))
	_box(Vector3(0.6, 1.4, 0.4), Vector3(0, 4.2, 0), Color("2a2a32"))
	_mesh(U.sphere_mesh(0.18), Vector3(0, 4.5, -0.22), Color.WHITE, Vector3.ZERO, Vector3.ONE, U.unshaded(Color("ff4040") if variant == 0 else Color("40ff60")))
	_col_cyl(0.15, 4.0, Vector3(0, 2.0, 0))

func _b_stalagmite() -> void:
	_mesh(U.cyl_mesh(0.0, size.x * 0.5, size.y, 7), Vector3(0, size.y * 0.5, 0), color_a)
	_col_cyl(size.x * 0.3, size.y, Vector3(0, size.y * 0.5, 0))

func _b_crystal() -> void:
	for i in 4:
		_mesh(U.cyl_mesh(0.0, size.x * 0.25, size.y * (1.0 - i * 0.18), 6), Vector3((i - 1.5) * size.x * 0.2, size.y * 0.4, _rng.randf_range(-0.3, 0.3)), Color.WHITE, Vector3(_rng.randf_range(-20, 20), 0, _rng.randf_range(-20, 20)), Vector3.ONE, U.unshaded(color_b.lightened(i * 0.1)))

func _b_web() -> void:
	for i in 6:
		_box(Vector3(size.x, 0.03, 0.03), Vector3(0, size.y * 0.5, 0), Color("f0f0f0"), Vector3(0, 0, i * 30))
	for k in 3:
		_mesh(U.torus_mesh(size.x * 0.1 * (k + 1), size.x * 0.1 * (k + 1) + 0.03, 6), Vector3(0, size.y * 0.5, 0), Color("f0f0f0"), Vector3(90, 0, 0))

func _b_altar() -> void:
	_box(Vector3(size.x, 1.0, size.z), Vector3(0, 0.5, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(size.x + 0.3, 0.2, size.z + 0.3), Vector3(0, 1.05, 0), color_c)
	for sx in [-1, 1]:
		_mesh(U.cyl_mesh(0.1, 0.1, 0.4, 8), Vector3(sx * size.x * 0.35, 1.35, 0), Color("f0e8d0"))
		_mesh(U.sphere_mesh(0.08), Vector3(sx * size.x * 0.35, 1.6, 0), Color.WHITE, Vector3.ZERO, Vector3(1, 1.5, 1), U.unshaded(Color("ffc040")))

func _b_throne() -> void:
	_box(Vector3(1.6, 0.8, 1.4), Vector3(0, 0.4, 0), color_c, Vector3.ZERO, true)
	_box(Vector3(1.6, 3.0, 0.3), Vector3(0, 1.5, 0.6), color_c)
	_mesh(U.sphere_mesh(0.3), Vector3(0, 3.1, 0.6), Color("e8c27a"))

func _b_bookshelf() -> void:
	_box(Vector3(size.x, size.y, 0.6), Vector3(0, size.y * 0.5, 0), Color("6a4a30"), Vector3.ZERO, true)
	for r in int(size.y / 0.6):
		for i in int(size.x / 0.15):
			_box(Vector3(0.12, 0.45, 0.4), Vector3(-size.x * 0.5 + 0.1 + i * 0.15, 0.3 + r * 0.6, -0.12), Color.from_hsv(fmod(i * 0.13 + r * 0.3, 1.0), 0.45, 0.6))

func _b_table() -> void:
	_box(Vector3(size.x, 0.1, size.z), Vector3(0, 0.85, 0), color_c.lightened(0.2), Vector3.ZERO, true)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(0.1, 0.8, 0.1), Vector3(sx * (size.x * 0.5 - 0.1), 0.4, sz * (size.z * 0.5 - 0.1)), color_c)

func _b_bed() -> void:
	_box(Vector3(1.2, 0.5, 2.2), Vector3(0, 0.25, 0), color_c, Vector3.ZERO, true)
	_box(Vector3(1.1, 0.2, 1.6), Vector3(0, 0.55, 0.25), color_b)
	_box(Vector3(0.8, 0.18, 0.4), Vector3(0, 0.6, -0.8), Color("f4f0e6"))

func _b_rug() -> void:
	_box(Vector3(size.x, 0.04, size.z), Vector3(0, 0.02, 0), color_b)
	_box(Vector3(size.x * 0.8, 0.045, size.z * 0.8), Vector3(0, 0.025, 0), color_c)

func _b_water_plane() -> void:
	var wm := ShaderMaterial.new()
	wm.shader = load("res://src/terrain/water.gdshader")
	WaterStyle.configure(wm, 0.20)
	wm.set_shader_parameter("noise_tex", BrushTerrain.get_noise_texture())
	wm.set_shader_parameter("has_height", 0.0)
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	pm.subdivide_width = 16
	pm.subdivide_depth = 16
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = wm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gen.add_child(mi)

func _b_canopy_tree() -> void:
	_b_tree()

# ---------------------------------------------------------------- 动画
func _process(delta: float) -> void:
	_t += delta
	for a in _anim_nodes:
		var n: Node3D = a[1]
		if not is_instance_valid(n):
			continue
		match a[0]:
			"spin":
				n.rotation.y += delta * a[2]
			"spin_z":
				n.rotation.z += delta * a[2]
			"bob":
				n.position.y = sin(_t * 0.8 + seed_v) * 0.15
				n.rotation.z = sin(_t * 0.6 + seed_v) * 0.02

## Release generated render/physics content; retain the authored descriptor.
func stream_unload() -> void:
	set_process(false)
	_body = null
	_anim_nodes.clear()
	if is_instance_valid(_gen):
		_gen.free()
	_gen = null
