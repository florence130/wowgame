@tool
class_name Landmark
extends Prop
## 晴岚港地标与大型建筑（白 / 海蓝 / 米色，维多利亚 + 魔导风格）。
## 继承 Prop：kind 取下列 _b_* 名称即可，正面朝向 -Z，size 含义见各函数注释。
## 独立成文件以免与 Prop 本体的改动冲突。

const KINDS_LM := "goddess,beacon,clock_spire,cathedral,civic_hall,opera,mage_tower,rotunda,bathhouse,hospital,warehouse,terminal,rowhouse,guildhouse,galleon,steamship,culvert,market_hall"

const WHITE := Color("f4f2ec")
const BEIGE := Color("e8dcc4")
const SEA := Color("2f6fa8")
const SEA_L := Color("4a90c0")
const GOLD := Color("d8b060")
const STONE := Color("c8c0b0")
const DARK := Color("3a3a48")

## 小地图轮廓（MapGen 调用）：[屋顶色, 占地尺寸]
func map_footprint() -> Array:
	match kind:
		"goddess", "beacon", "clock_spire", "mage_tower", "rotunda":
			return [color_b.darkened(0.15), Vector2(size.x, size.x)]
		"galleon", "steamship", "culvert":
			return []
	return [color_b.darkened(0.15), Vector2(size.x, size.z)]

# ---------------------------------------------------------------- 通用部件
func _spire(pos: Vector3, r: float, h: float, c: Color, sides: int = 8) -> void:
	_mesh(U.cyl_mesh(0.0, r, h, sides), pos + Vector3(0, h * 0.5, 0), c)
	_mesh(U.sphere_mesh(maxf(0.25, r * 0.12)), pos + Vector3(0, h + 0.2, 0), GOLD)
	_mesh(U.cyl_mesh(0.05, 0.05, maxf(1.0, r * 0.6), 6), pos + Vector3(0, h + 0.6, 0), GOLD)

func _dome(pos: Vector3, r: float, c: Color, ribs: int = 8, lantern: bool = true) -> void:
	_mesh(U.cyl_mesh(r * 1.02, r * 1.02, r * 0.35, 24), pos + Vector3(0, r * 0.17, 0), WHITE)
	_mesh(U.sphere_mesh(r, r * 2.0, true, 24), pos + Vector3(0, r * 0.35, 0), c)
	# 金色肋条：竖直圆环，下半部藏在鼓座内
	for i in ribs / 2:
		var a := i * PI / (ribs / 2)
		_mesh(U.torus_mesh(r * 0.99, r * 1.04, 32), pos + Vector3(0, r * 0.35, 0), GOLD, Vector3(90, rad_to_deg(a), 0))
	if lantern:
		_mesh(U.cyl_mesh(r * 0.18, r * 0.2, r * 0.4, 12), pos + Vector3(0, r * 1.35 + r * 0.2, 0), WHITE)
		_mesh(U.sphere_mesh(r * 0.2, r * 0.4, true, 12), pos + Vector3(0, r * 1.55 + r * 0.2, 0), c)
		_mesh(U.sphere_mesh(maxf(0.25, r * 0.06)), pos + Vector3(0, r * 1.95 + r * 0.2, 0), GOLD)

func _colonnade(cx: float, z: float, w: float, h: float, n: int, base_y: float = 0.0, r: float = 0.45) -> void:
	for i in n:
		var x := cx - w * 0.5 + (i + 0.5) * w / n
		_mesh(U.cyl_mesh(r, r * 1.1, h, 12), Vector3(x, base_y + h * 0.5, z), WHITE)
		_box(Vector3(r * 2.6, 0.35, r * 2.6), Vector3(x, base_y + 0.17, z), STONE)
		_box(Vector3(r * 2.6, 0.35, r * 2.6), Vector3(x, base_y + h - 0.17, z), STONE)

func _pediment(w: float, z: float, y: float, depth: float = 2.0, c: Color = WHITE) -> void:
	_mesh(U.prism_mesh(Vector3(w, w * 0.22, depth)), Vector3(0, y + w * 0.11, z), c)
	_box(Vector3(w + 0.4, 0.5, depth + 0.2), Vector3(0, y, z), STONE)

func _arch_win(pos: Vector3, w: float, h: float, rot_y: float = 180.0) -> void:
	_window(pos, w, h, rot_y)
	var n := Node3D.new()
	n.position = pos + Vector3(0, h * 0.5, 0)
	n.rotation_degrees.y = rot_y
	_gen.add_child(n)
	U.add_mesh(n, U.cyl_mesh(w * 0.5, w * 0.5, 0.14, 12), get_window_mat(), Vector3(0, 0, -0.01), Vector3(90, 0, 0), Vector3(1, 1, 1))
	U.add_mesh(n, U.torus_mesh(w * 0.5, w * 0.5 + 0.12, 16), _m(color_c), Vector3(0, 0, 0), Vector3(90, 0, 0), Vector3(1, 0.3, 1))

## 正面一排窗（z 为墙面位置，rot 为窗朝向）
func _win_row(z: float, w: float, y: float, n: int, ww: float = 1.1, wh: float = 1.8, rot: float = 180.0, arched: bool = false) -> void:
	for i in n:
		var x := -w * 0.5 + (i + 0.5) * w / n
		if arched:
			_arch_win(Vector3(x, y, z), ww, wh, rot)
		else:
			_window(Vector3(x, y, z), ww, wh, rot)

func _side_wins(w: float, d: float, y: float, n: int) -> void:
	for j in n:
		var z := -d * 0.5 + (j + 0.5) * d / n
		_window(Vector3(-w * 0.5 - 0.05, y, z), 1.1, 1.8, -90)
		_window(Vector3(w * 0.5 + 0.05, y, z), 1.1, 1.8, 90)

func _glow(pos: Vector3, r: float, c: Color, light_range: float = 0.0) -> void:
	_mesh(U.sphere_mesh(r, r * 2.0, false, 12), pos, c, Vector3.ZERO, Vector3.ONE, U.unshaded(c))
	if light_range > 0.0 and not Engine.is_editor_hint():
		var l := OmniLight3D.new()
		l.position = pos
		l.light_color = c
		l.omni_range = light_range
		l.light_energy = 1.6
		_gen.add_child(l)

# ---------------------------------------------------------------- 迎海女神像
## size.y = 总高。基座三层 + 长袍女神，一手高举以太水晶，一手持航海罗盘
func _b_goddess() -> void:
	var s := size.y / 40.0
	for i in 3:
		var r := (9.0 - i * 2.2) * s
		_mesh(U.cyl_mesh(r * 0.94, r, 3.0 * s, 8), Vector3(0, (1.5 + i * 3.0) * s, 0), STONE.lightened(i * 0.05), Vector3(0, 22.5, 0))
	_col_cyl(8.6 * s, 9.0 * s, Vector3(0, 4.5 * s, 0))
	for i in 8:
		var a := i * TAU / 8.0 + PI / 8.0
		_mesh(U.cyl_mesh(0.25 * s, 0.25 * s, 1.6 * s, 8), Vector3(sin(a) * 8.2 * s, 9.8 * s, cos(a) * 8.2 * s), GOLD)
	var b := 9.0 * s
	var robe := color_c
	_mesh(U.cyl_mesh(2.2 * s, 4.0 * s, 12.0 * s, 16), Vector3(0, b + 6.0 * s, 0), robe)
	_mesh(U.cyl_mesh(1.6 * s, 2.2 * s, 6.0 * s, 16), Vector3(0, b + 15.0 * s, 0), robe)
	_mesh(U.sphere_mesh(1.25 * s, 2.5 * s, false, 16), Vector3(0, b + 19.4 * s, 0), robe)
	_mesh(U.capsule_mesh(0.9 * s, 5.0 * s), Vector3(0, b + 18.6 * s, 0.7 * s), robe.darkened(0.04), Vector3(12, 0, 0))
	_mesh(U.torus_mesh(1.1 * s, 1.35 * s, 16), Vector3(0, b + 20.3 * s, 0), GOLD, Vector3(10, 0, 0))
	# 双翼
	for sx in [-1, 1]:
		for k in 3:
			_mesh(U.prism_mesh(Vector3(5.5 * s, (7.0 - k * 1.6) * s, 0.35 * s)), Vector3(sx * (3.2 + k * 1.4) * s, b + (15.5 - k * 1.2) * s, 1.6 * s), WHITE.lerp(SEA_L, k * 0.15), Vector3(0, sx * 18, sx * -(55 - k * 8)))
	# 高举的右臂与以太水晶
	_mesh(U.capsule_mesh(0.45 * s, 6.5 * s), Vector3(1.9 * s, b + 20.0 * s, -0.3 * s), robe, Vector3(-8, 0, -22))
	_mesh(U.cyl_mesh(0.0, 0.9 * s, 2.2 * s, 6), Vector3(3.1 * s, b + 24.6 * s, -0.5 * s), Color.WHITE, Vector3.ZERO, Vector3.ONE, U.unshaded(Color("9ae8ff")))
	_mesh(U.cyl_mesh(0.9 * s, 0.0, 1.4 * s, 6), Vector3(3.1 * s, b + 22.8 * s, -0.5 * s), Color.WHITE, Vector3.ZERO, Vector3.ONE, U.unshaded(Color("9ae8ff")))
	_glow(Vector3(3.1 * s, b + 23.8 * s, -0.5 * s), 0.6 * s, Color("bff4ff"), 18.0 * s)
	# 左手罗盘
	_mesh(U.capsule_mesh(0.42 * s, 4.5 * s), Vector3(-1.9 * s, b + 15.0 * s, -0.9 * s), robe, Vector3(40, 0, 25))
	_mesh(U.torus_mesh(0.9 * s, 1.2 * s, 20), Vector3(-2.6 * s, b + 13.6 * s, -2.4 * s), GOLD, Vector3(70, 0, 0))
	if not Engine.is_editor_hint():
		var ring := Node3D.new()
		ring.position = Vector3(0, b + 9.0 * s, 0)
		_gen.add_child(ring)
		U.add_mesh(ring, U.torus_mesh(6.0 * s, 6.25 * s, 48), U.unshaded(Color(0.6, 0.9, 1.0, 0.55), true))
		_anim_nodes.append(["spin", ring, 0.25])

# ---------------------------------------------------------------- 灯塔
## size.x = 塔身直径，size.y = 塔高
func _b_beacon() -> void:
	var r := size.x * 0.5
	var h := size.y
	_mesh(U.cyl_mesh(r * 2.0, r * 2.3, 4.0, 10), Vector3(0, 0.0, 0), STONE.darkened(0.1))
	_col_cyl(r * 1.1, h, Vector3(0, h * 0.5, 0))
	var seg := 5
	for i in seg:
		var y0 := 2.0 + i * (h - 2.0) / seg
		var r0 := lerpf(r, r * 0.72, float(i) / seg)
		var r1 := lerpf(r, r * 0.72, float(i + 1) / seg)
		_mesh(U.cyl_mesh(r1, r0, (h - 2.0) / seg, 16), Vector3(0, y0 + (h - 2.0) / seg * 0.5, 0), WHITE if i % 2 == 0 else color_b)
		_window(Vector3(0, y0 + (h - 2.0) / seg * 0.5, -r0 * 0.95), 0.7, 1.2, 180)
	var top := h
	_mesh(U.cyl_mesh(r * 1.15, r * 1.0, 0.6, 16), Vector3(0, top, 0), DARK)
	_mesh(U.torus_mesh(r * 1.05, r * 1.15, 24), Vector3(0, top + 0.9, 0), DARK, Vector3.ZERO, Vector3(1, 2.5, 1))
	_mesh(U.cyl_mesh(r * 0.6, r * 0.6, 3.0, 12), Vector3(0, top + 2.0, 0), Color.WHITE, Vector3.ZERO, Vector3.ONE, U.mat(Color(0.75, 0.92, 1.0, 0.5), 0.0, true))
	_glow(Vector3(0, top + 2.0, 0), r * 0.32, Color("bff0ff"), 30.0)
	_dome(Vector3(0, top + 3.5, 0), r * 0.68, color_b, 6, false)
	_mesh(U.sphere_mesh(0.35), Vector3(0, top + 3.5 + r * 1.4, 0), GOLD)
	_door(Vector3(0, 0, -r - 0.1), 1.4, 2.4, Color("2a4a6a"), 180)
	if not Engine.is_editor_hint():
		var beam := Node3D.new()
		beam.position = Vector3(0, top + 2.0, 0)
		_gen.add_child(beam)
		for sx in [-1, 1]:
			U.add_mesh(beam, U.cyl_mesh(0.4, 4.0, 70.0, 10), U.unshaded(Color(0.8, 0.95, 1.0, 0.13), true), Vector3(sx * 35.0, 0, 0), Vector3(0, 0, 90), Vector3.ONE, false)
		_anim_nodes.append(["spin", beam, 0.5])
		beam.add_to_group("night_only")

# ---------------------------------------------------------------- 钟塔
## size.x = 塔身宽，size.y = 钟面以下高度（总高约 1.55 倍）
func _b_clock_spire() -> void:
	var w := size.x
	var h := size.y
	_foundation(w + 2.0, w + 2.0, STONE)
	_box(Vector3(w + 2.0, 3.0, w + 2.0), Vector3(0, 1.5, 0), STONE, Vector3.ZERO, true)
	_box(Vector3(w, h, w), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(w * 0.96, w * 0.9, w * 0.96), Vector3(0, h + w * 0.45, 0), BEIGE)   # 钟楼层
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(1.0, h + 2.0, 1.0), Vector3(sx * w * 0.5, (h + 2.0) * 0.5, sz * w * 0.5), BEIGE)
			_spire(Vector3(sx * w * 0.5, h + 2.0, sz * w * 0.5), 0.7, 3.0, color_b, 4)
	for f in int(h / 6.0):
		_box(Vector3(w + 0.3, 0.3, w + 0.3), Vector3(0, 4.0 + f * 6.0, 0), BEIGE)
	for f in 4:
		var n := Node3D.new()
		n.rotation_degrees.y = f * 90.0
		n.position = Vector3(0, h - w * 0.3, 0)
		_gen.add_child(n)
		U.add_mesh(n, U.cyl_mesh(w * 0.36, w * 0.36, 0.3, 32), _m(Color("f8f4e8")), Vector3(0, 0, -w * 0.5 - 0.1), Vector3(90, 0, 0))
		U.add_mesh(n, U.torus_mesh(w * 0.34, w * 0.4, 32), _m(GOLD), Vector3(0, 0, -w * 0.5 - 0.15), Vector3(90, 0, 0))
		for k in 12:
			var a := k * TAU / 12.0
			U.add_mesh(n, U.box_mesh(Vector3(0.12, 0.45, 0.06)), _m(DARK), Vector3(sin(a) * w * 0.3, cos(a) * w * 0.3, -w * 0.5 - 0.3), Vector3(0, 0, -rad_to_deg(a)))
		U.add_mesh(n, U.box_mesh(Vector3(0.18, w * 0.26, 0.08)), _m(DARK), Vector3(0, w * 0.11, -w * 0.5 - 0.35))
		U.add_mesh(n, U.box_mesh(Vector3(w * 0.2, 0.16, 0.08)), _m(DARK), Vector3(w * 0.08, 0, -w * 0.5 - 0.38))
		# 钟楼拱窗
		U.add_mesh(n, U.box_mesh(Vector3(w * 0.55, w * 0.62, 0.2)), _m(DARK), Vector3(0, w * 0.75, -w * 0.48 - 0.05))
	_box(Vector3(w + 0.8, 0.6, w + 0.8), Vector3(0, h + 0.9 * w, 0), STONE)
	_spire(Vector3(0, h + 0.9 * w + 0.3, 0), w * 0.62, h * 0.45, color_b, 4)
	_door(Vector3(0, 0, -w * 0.5 - 1.05), 2.0, 3.2, Color("2a4a6a"), 180)
	_signboard(label, Vector3(0, 4.2, -w * 0.5 - 1.1), 0)

# ---------------------------------------------------------------- 大教堂
## size = (宽, 中殿高, 长)。双塔立面 + 玫瑰窗 + 十字交叉穹顶 + 飞扶壁
func _b_cathedral() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d, STONE)
	_box(Vector3(w * 0.5, h, d), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	_gable_roof(w * 0.5, d, h, w * 0.28, color_b, 0.3)
	for sx in [-1, 1]:
		_box(Vector3(w * 0.25, h * 0.55, d * 0.92), Vector3(sx * w * 0.375, h * 0.275, 0), BEIGE, Vector3.ZERO, true)
		_mesh(U.prism_mesh(Vector3(w * 0.26, h * 0.12, d * 0.92), 1.0 if sx < 0 else 0.0), Vector3(sx * w * 0.375, h * 0.61, 0), color_b)
		for i in int(d / 7.0):
			var z := -d * 0.5 + 4.0 + i * 7.0
			# 飞扶壁
			_box(Vector3(1.0, h * 0.62, 1.4), Vector3(sx * w * 0.5, h * 0.31, z), STONE)
			_box(Vector3(w * 0.26, 0.7, 0.9), Vector3(sx * w * 0.37, h * 0.72, z), STONE, Vector3(0, 0, sx * -28))
			_spire(Vector3(sx * w * 0.5, h * 0.62, z), 0.6, 2.4, color_b, 4)
			_arch_win(Vector3(sx * (w * 0.25 + 0.06), h * 0.78, z + 3.5), 1.4, h * 0.22, sx * 90)
			_arch_win(Vector3(sx * (w * 0.5 + 0.06), h * 0.25, z + 3.5), 1.2, h * 0.22, sx * 90)
	# 耳堂与交叉穹顶
	_box(Vector3(w * 1.25, h * 0.9, w * 0.35), Vector3(0, h * 0.45, d * 0.12), color_a, Vector3.ZERO, true)
	_mesh(U.prism_mesh(Vector3(w * 0.35, w * 0.25, w * 1.3)), Vector3(0, h * 0.9 + w * 0.125, d * 0.12), color_b, Vector3(0, 90, 0))
	_mesh(U.cyl_mesh(w * 0.2, w * 0.2, h * 0.35, 16), Vector3(0, h * 1.12, d * 0.12), WHITE)
	_dome(Vector3(0, h * 1.3, d * 0.12), w * 0.21, color_b, 12)
	# 后殿
	_mesh(U.cyl_mesh(w * 0.25, w * 0.25, h * 0.85, 16), Vector3(0, h * 0.425, d * 0.5), color_a)
	_mesh(U.sphere_mesh(w * 0.25, w * 0.5, true, 16), Vector3(0, h * 0.85, d * 0.5), color_b)
	# 西立面双塔
	var tw := w * 0.26
	var th := h * 1.75
	var fz := -d * 0.5 - tw * 0.4
	for sx in [-1, 1]:
		var tx: float = sx * (w * 0.5 - tw * 0.5)
		_box(Vector3(tw, th, tw), Vector3(tx, th * 0.5, fz), color_a.lightened(0.03), Vector3.ZERO, true)
		for k in 3:
			_arch_win(Vector3(tx, th * (0.35 + k * 0.22), fz - tw * 0.5 - 0.06), tw * 0.32, th * 0.1)
		_box(Vector3(tw + 0.6, 0.6, tw + 0.6), Vector3(tx, th, fz), STONE)
		for qx in [-1, 1]:
			for qz in [-1, 1]:
				_spire(Vector3(tx + qx * tw * 0.42, th + 0.3, fz + qz * tw * 0.42), 0.5, 3.0, color_b, 4)
		_spire(Vector3(tx, th + 0.3, fz), tw * 0.5, th * 0.5, color_b, 8)
	_box(Vector3(w - tw * 2.0, h * 1.05, tw * 0.6), Vector3(0, h * 0.525, fz + tw * 0.2), color_a, Vector3.ZERO, true)
	_mesh(U.prism_mesh(Vector3(w - tw * 2.0, h * 0.3, tw * 0.6)), Vector3(0, h * 1.05 + h * 0.15, fz + tw * 0.2), color_a)
	# 玫瑰窗
	var rz := fz + tw * 0.2 - tw * 0.3 - 0.08
	_mesh(U.cyl_mesh(w * 0.13, w * 0.13, 0.2, 24), Vector3(0, h * 0.72, rz), Color.WHITE, Vector3(90, 0, 0), Vector3.ONE, get_window_mat())
	_mesh(U.torus_mesh(w * 0.13, w * 0.155, 32), Vector3(0, h * 0.72, rz - 0.05), GOLD, Vector3(90, 0, 0))
	for k in 8:
		var a := k * TAU / 8.0
		_box(Vector3(0.14, w * 0.24, 0.1), Vector3(0, h * 0.72, rz - 0.1), GOLD, Vector3(0, 0, rad_to_deg(a)))
	# 三拱门
	for i in 3:
		var x := (i - 1) * (w - tw * 2.0) * 0.32
		var dw := 3.2 if i == 1 else 2.2
		_door(Vector3(x, 0, rz), dw, dw * 1.7, Color("2a3a5a"), 180)
		_mesh(U.torus_mesh(dw * 0.55, dw * 0.75, 16), Vector3(x, dw * 1.7, rz - 0.1), STONE, Vector3(90, 0, 0), Vector3(1, 0.5, 1))
	_box(Vector3(w * 0.9, 0.6, 6.0), Vector3(0, 0.3, fz - tw * 0.5 - 3.0), STONE, Vector3.ZERO, true)
	_signboard(label, Vector3(0, 5.8, rz - 0.2), 0)

# ---------------------------------------------------------------- 市政厅
## size = (总宽, 主体高, 进深)。新古典主义：中央鼓座穹顶 + 两翼曼萨德屋顶 + 门廊
func _b_civic_hall() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d, STONE)
	_box(Vector3(w, 1.6, d), Vector3(0, 0.8, 0), STONE, Vector3.ZERO, true)
	var cw := w * 0.36
	_box(Vector3(cw, h, d), Vector3(0, 1.6 + h * 0.5, 0), color_a, Vector3.ZERO, true)
	for sx in [-1, 1]:
		var wx: float = sx * (cw * 0.5 + (w - cw) * 0.25)
		_box(Vector3((w - cw) * 0.5, h * 0.82, d * 0.86), Vector3(wx, 1.6 + h * 0.41, 0), BEIGE, Vector3.ZERO, true)
		_mesh(U.cyl_mesh(0.78, 1.0, 3.2, 4), Vector3(wx, 1.6 + h * 0.82 + 1.6, 0), color_b, Vector3(0, 45, 0), Vector3((w - cw) * 0.25 / 0.7071, 1, d * 0.43 / 0.7071))
		for f in 2:
			for i in 5:
				var x := wx - (w - cw) * 0.25 + (i + 0.5) * (w - cw) * 0.5 / 5.0
				_arch_win(Vector3(x, 1.6 + 2.2 + f * h * 0.38, -d * 0.43 - 0.06), 1.2, 2.0)
		# 角楼小穹顶
		_mesh(U.cyl_mesh(1.8, 1.8, 3.0, 12), Vector3(sx * w * 0.5, 1.6 + h * 0.82 + 1.5, -d * 0.43), WHITE)
		_dome(Vector3(sx * w * 0.5, 1.6 + h * 0.82 + 3.0, -d * 0.43), 1.9, color_b, 6)
	_box(Vector3(w + 0.6, 0.6, d + 0.6), Vector3(0, 1.6 + h * 0.82, 0), STONE)
	# 中央穹顶
	var top := 1.6 + h
	_box(Vector3(cw + 0.6, 0.7, d + 0.6), Vector3(0, top, 0), STONE)
	_mesh(U.cyl_mesh(cw * 0.34, cw * 0.36, h * 0.4, 24), Vector3(0, top + h * 0.2, 0), WHITE)
	for i in 12:
		var a := i * TAU / 12.0
		_mesh(U.cyl_mesh(0.3, 0.32, h * 0.36, 8), Vector3(sin(a) * cw * 0.37, top + h * 0.2, cos(a) * cw * 0.37), WHITE)
	_dome(Vector3(0, top + h * 0.4, 0), cw * 0.38, color_b, 12)
	# 门廊与山花
	var pz := -d * 0.5 - 4.0
	_box(Vector3(cw + 4.0, 1.6, 8.0), Vector3(0, 0.8, pz), STONE, Vector3.ZERO, true)
	_colonnade(0, pz - 2.5, cw + 2.0, h * 0.8, 8, 1.6, 0.6)
	_box(Vector3(cw + 3.0, 1.2, 7.0), Vector3(0, 1.6 + h * 0.8 + 0.6, pz + 0.5), WHITE)
	_pediment(cw + 3.0, pz + 0.5, 1.6 + h * 0.8 + 1.2, 7.0)
	_mesh(U.cyl_mesh(1.2, 1.2, 0.3, 24), Vector3(0, 1.6 + h * 0.8 + 1.2 + cw * 0.08, pz - 3.1), GOLD, Vector3(90, 0, 0))
	for k in 6:
		_box(Vector3(cw + 6.0 - k * 0.3, 0.27, 0.9), Vector3(0, k * 0.27 + 0.13, pz - 4.0 - (5 - k) * 0.9), STONE, Vector3.ZERO, true)
	_door(Vector3(0, 1.6, -d * 0.5 - 0.06), 3.0, 4.6, Color("2a4a6a"), 180)
	_signboard(label, Vector3(0, 1.6 + h * 0.62, -d * 0.5 - 0.2), 0)

# ---------------------------------------------------------------- 歌剧院
## size = (宽, 高, 进深)。拱廊立面 + 雕像 + 海蓝穹顶 + 舞台塔
func _b_opera() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d, STONE)
	_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(w + 0.6, 0.8, d + 0.6), Vector3(0, h, 0), STONE)
	# 一层拱廊
	for i in 7:
		var x := -w * 0.42 + i * w * 0.14
		_box(Vector3(1.2, h * 0.38, 2.4), Vector3(x, h * 0.19, -d * 0.5 - 1.2), BEIGE, Vector3.ZERO, true)
		if i < 6:
			_arch_win(Vector3(x + w * 0.07, h * 0.15, -d * 0.5 - 0.06), w * 0.08, h * 0.2)
	_box(Vector3(w * 0.9, 1.0, 2.6), Vector3(0, h * 0.38 + 0.5, -d * 0.5 - 1.2), STONE)
	# 二层双柱
	_colonnade(0, -d * 0.5 - 0.8, w * 0.84, h * 0.42, 12, h * 0.38 + 1.0, 0.42)
	_win_row(-d * 0.5 - 0.06, w * 0.8, h * 0.62, 6, 1.6, h * 0.25, 180.0, true)
	# 屋顶雕像与金色竖琴
	for sx in [-1, 1]:
		_mesh(U.cyl_mesh(0.6, 1.0, 2.6, 10), Vector3(sx * w * 0.42, h + 2.1, -d * 0.45), WHITE)
		_mesh(U.prism_mesh(Vector3(2.4, 2.0, 0.2)), Vector3(sx * w * 0.42 + sx * 0.8, h + 3.3, -d * 0.45), GOLD, Vector3(0, 0, sx * -40))
	_mesh(U.torus_mesh(1.4, 1.8, 24), Vector3(0, h + 2.2, -d * 0.5), GOLD, Vector3(90, 0, 0))
	_dome(Vector3(0, h + 0.8, 0), minf(w, d) * 0.32, color_b, 16)
	_box(Vector3(w * 0.6, h * 0.5, d * 0.25), Vector3(0, h + h * 0.25, d * 0.33), BEIGE, Vector3.ZERO, true)
	_gable_roof(w * 0.6, d * 0.25, h * 1.5, w * 0.15, color_b, 0.3)
	_side_wins(w, d, h * 0.55, int(d / 4.0))
	_door(Vector3(0, 0, -d * 0.5 - 2.45), 3.0, 4.0, Color("6a2a3a"), 180)
	for k in 4:
		_box(Vector3(w * 0.8, 0.3, 1.0), Vector3(0, k * 0.3 + 0.15, -d * 0.5 - 3.0 - (3 - k) * 1.0), STONE, Vector3.ZERO, true)
	_signboard(label, Vector3(0, h * 0.38 + 0.5, -d * 0.5 - 2.6), 0)

# ---------------------------------------------------------------- 法师行会尖塔
## size.x = 塔基宽，size.y = 塔高。悬浮符文环 + 以太水晶顶 + 附属学院
func _b_mage_tower() -> void:
	var w := size.x
	var h := size.y
	_foundation(w * 2.2, w * 2.2, STONE)
	_box(Vector3(w * 2.2, h * 0.16, w * 1.8), Vector3(0, h * 0.08, w * 0.6), BEIGE, Vector3.ZERO, true)
	_mesh(U.cyl_mesh(1.0, 1.0, 3.0, 4), Vector3(0, h * 0.16 + 1.5, w * 0.6), color_b, Vector3(0, 45, 0), Vector3(w * 1.1 / 0.7071, 1, w * 0.9 / 0.7071))
	var seg := 4
	for i in seg:
		var y0 := i * h * 0.8 / seg
		var r0 := lerpf(w * 0.5, w * 0.3, float(i) / seg)
		var r1 := lerpf(w * 0.5, w * 0.3, float(i + 1) / seg)
		_mesh(U.cyl_mesh(r1, r0, h * 0.8 / seg, 8), Vector3(0, y0 + h * 0.4 / seg, 0), color_a, Vector3(0, 22.5, 0))
		_mesh(U.cyl_mesh(r1 * 1.12, r1 * 1.12, 0.5, 8), Vector3(0, y0 + h * 0.8 / seg, 0), color_b, Vector3(0, 22.5, 0))
		for k in 4:
			var a := k * TAU / 4.0
			_arch_win(Vector3(sin(a) * (r0 * 0.95), y0 + h * 0.4 / seg, cos(a) * (r0 * 0.95)), 0.9, 1.8, rad_to_deg(a))
	_col_cyl(w * 0.5, h * 0.8, Vector3(0, h * 0.4, 0))
	var top := h * 0.8
	_mesh(U.cyl_mesh(w * 0.45, w * 0.3, 1.2, 8), Vector3(0, top + 0.6, 0), STONE, Vector3(0, 22.5, 0))
	_spire(Vector3(0, top + 1.2, 0), w * 0.42, h * 0.2, color_b, 8)
	var cy := top + h * 0.2 + 4.0
	_mesh(U.cyl_mesh(0.0, 1.2, 3.0, 6), Vector3(0, cy + 1.5, 0), Color.WHITE, Vector3.ZERO, Vector3.ONE, U.unshaded(color_c))
	_mesh(U.cyl_mesh(1.2, 0.0, 2.0, 6), Vector3(0, cy - 1.0, 0), Color.WHITE, Vector3.ZERO, Vector3.ONE, U.unshaded(color_c))
	_glow(Vector3(0, cy, 0), 0.8, color_c.lightened(0.3), 24.0)
	_door(Vector3(0, 0, -w * 0.5 - 0.05), 1.8, 3.2, Color("3a2a6a"), 180)
	_signboard(label, Vector3(0, 4.0, -w * 0.5 - 0.3), 0)
	if not Engine.is_editor_hint():
		for k in 3:
			var ring := Node3D.new()
			ring.position = Vector3(0, top * (0.45 + k * 0.22), 0)
			ring.rotation_degrees = Vector3(12 * (k - 1), 0, 8 * k)
			_gen.add_child(ring)
			U.add_mesh(ring, U.torus_mesh(w * (0.85 - k * 0.12), w * (0.85 - k * 0.12) + 0.25, 40), U.unshaded(Color(color_c.r, color_c.g, color_c.b, 0.75), true))
			for j in 6:
				var a2 := j * TAU / 6.0
				U.add_mesh(ring, U.box_mesh(Vector3(0.5, 0.5, 0.5)), U.unshaded(color_c.lightened(0.4)), Vector3(cos(a2) * w * (0.85 - k * 0.12), 0, sin(a2) * w * (0.85 - k * 0.12)), Vector3(45, 45, 0))
			_anim_nodes.append(["spin", ring, 0.3 + k * 0.2 * (1 if k % 2 == 0 else -1)])

# ---------------------------------------------------------------- 传送大厅（圆厅）
## size.x = 直径，size.y = 柱廊高
func _b_rotunda() -> void:
	var r := size.x * 0.5
	var h := size.y
	_mesh(U.cyl_mesh(r + 2.0, r + 2.5, 1.6, 32), Vector3(0, 0.8, 0), STONE)
	_col_cyl(r + 2.0, 1.6, Vector3(0, 0.8, 0))
	_mesh(U.cyl_mesh(r * 0.82, r * 0.82, h, 32), Vector3(0, 1.6 + h * 0.5, 0), color_a)
	var n := 16
	for i in n:
		var a := i * TAU / n
		if absf(wrapf(a - PI, -PI, PI)) < 0.25:
			continue
		_mesh(U.cyl_mesh(0.5, 0.55, h, 10), Vector3(sin(a) * r, 1.6 + h * 0.5, cos(a) * r), WHITE)
		_arch_win(Vector3(sin(a) * r * 0.83, 1.6 + h * 0.5, cos(a) * r * 0.83), 1.4, h * 0.45, rad_to_deg(a))
	# 墙体碰撞（正面留门）
	for i in 12:
		var a2 := i * TAU / 12.0
		if absf(wrapf(a2 - PI, -PI, PI)) < 0.4:
			continue
		_col_box(Vector3(r * 0.45, h, 1.0), Vector3(sin(a2) * r * 0.82, 1.6 + h * 0.5, cos(a2) * r * 0.82), Vector3(0, rad_to_deg(a2), 0))
	_mesh(U.torus_mesh(r * 0.95, r * 1.08, 40), Vector3(0, 1.6 + h, 0), STONE, Vector3.ZERO, Vector3(1, 2.0, 1))
	_mesh(U.sphere_mesh(r * 0.85, r * 1.7, true, 32), Vector3(0, 1.6 + h + 0.4, 0), Color.WHITE, Vector3.ZERO, Vector3.ONE, U.mat(Color(0.55, 0.8, 1.0, 0.45), 0.0, true))
	for i in 4:
		_mesh(U.torus_mesh(r * 0.84, r * 0.88, 40), Vector3(0, 1.6 + h + 0.4, 0), GOLD, Vector3(90, i * 45.0, 0))
	_mesh(U.sphere_mesh(1.0), Vector3(0, 1.6 + h + r * 0.85 + 0.6, 0), GOLD)
	# 内部传送门
	_mesh(U.cyl_mesh(r * 0.4, r * 0.45, 0.6, 24), Vector3(0, 1.9, 0), Color("6a6a8a"))
	if not Engine.is_editor_hint():
		var ring := Node3D.new()
		ring.position = Vector3(0, 1.6 + r * 0.38 + 0.6, 0)
		_gen.add_child(ring)
		U.add_mesh(ring, U.torus_mesh(r * 0.32, r * 0.38, 40), _m(GOLD), Vector3.ZERO, Vector3(90, 0, 0))
		U.add_mesh(ring, U.cyl_mesh(r * 0.32, r * 0.32, 0.05, 40), U.unshaded(Color(color_c.r, color_c.g, color_c.b, 0.6), true), Vector3.ZERO, Vector3(90, 0, 0))
		_anim_nodes.append(["spin_z", ring, 0.5])
	_glow(Vector3(0, 1.6 + r * 0.38 + 0.6, 0), 0.4, color_c, 16.0)
	_signboard(label, Vector3(0, 1.6 + h * 0.85, -r - 0.6), 0)

# ---------------------------------------------------------------- 公共浴池
## size = (宽, 高, 进深)。三穹顶 + 拱窗 + 蒸汽
func _b_bathhouse() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d, STONE)
	_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(w + 0.5, 0.6, d + 0.5), Vector3(0, h, 0), STONE)
	for i in 3:
		var x := (i - 1) * w * 0.32
		var rr := minf(w * 0.15, d * 0.35) * (1.3 if i == 1 else 1.0)
		_dome(Vector3(x, h + 0.3, 0), rr, color_b, 8, i == 1)
	_win_row(-d * 0.5 - 0.06, w * 0.9, h * 0.5, int(w / 3.5), 1.4, h * 0.45, 180.0, true)
	_side_wins(w, d, h * 0.5, int(d / 4.0))
	_colonnade(0, -d * 0.5 - 1.6, w * 0.4, h * 0.85, 6, 0.0, 0.45)
	_box(Vector3(w * 0.44, 0.8, 3.4), Vector3(0, h * 0.85 + 0.4, -d * 0.5 - 1.4), WHITE)
	_door(Vector3(0, 0, -d * 0.5 - 0.06), 2.6, 3.6, Color("2a4a6a"), 180)
	_signboard(label, Vector3(0, h * 0.85 + 1.4, -d * 0.5 - 3.2), 0)
	if not Engine.is_editor_hint():
		for sx in [-1, 1]:
			var p := CPUParticles3D.new()
			p.amount = 24
			p.lifetime = 3.0
			p.position = Vector3(sx * w * 0.32, h + 4.0, 0)
			p.direction = Vector3.UP
			p.spread = 20.0
			p.gravity = Vector3(0.3, 0.6, 0)
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 1.4
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.2
			var qm := QuadMesh.new()
			qm.size = Vector2(1.6, 1.6)
			var mm := U.unshaded(Color(1, 1, 1, 0.25), true).duplicate()
			mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			qm.material = mm
			p.mesh = qm
			_gen.add_child(p)

# ---------------------------------------------------------------- 公共医院
## size = (宽, 高, 进深)。H 形两翼 + 中央入口 + 海蓝十字
func _b_hospital() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d, STONE)
	_box(Vector3(w * 0.4, h, d * 0.5), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	_hip_roof(w * 0.4, d * 0.5, h, h * 0.3, color_b)
	for sx in [-1, 1]:
		_box(Vector3(w * 0.3, h * 0.85, d), Vector3(sx * w * 0.35, h * 0.425, 0), BEIGE, Vector3.ZERO, true)
		_gable_roof(w * 0.3, d, h * 0.85, w * 0.12, color_b, 0.4)
		for f in 2:
			for i in 3:
				_window(Vector3(sx * w * 0.35 + (i - 1) * w * 0.08, 2.0 + f * h * 0.4, -d * 0.5 - 0.06), 1.0, 1.6, 180)
	for f in 2:
		_win_row(-d * 0.25 - 0.06, w * 0.36, 2.0 + f * h * 0.4, 4)
	# 十字徽记
	var cz := -d * 0.25 - 0.12
	_mesh(U.cyl_mesh(1.8, 1.8, 0.2, 24), Vector3(0, h * 0.8, cz), WHITE, Vector3(90, 0, 0))
	_box(Vector3(0.7, 2.4, 0.12), Vector3(0, h * 0.8, cz - 0.08), color_b)
	_box(Vector3(2.4, 0.7, 0.12), Vector3(0, h * 0.8, cz - 0.08), color_b)
	_box(Vector3(w * 0.3, 0.3, 4.0), Vector3(0, 3.6, -d * 0.25 - 2.0), color_b.lightened(0.2))
	for sx2 in [-1, 1]:
		_mesh(U.cyl_mesh(0.18, 0.18, 3.6, 8), Vector3(sx2 * w * 0.13, 1.8, -d * 0.25 - 3.8), WHITE)
	_door(Vector3(0, 0, -d * 0.25 - 0.06), 2.6, 3.0, Color("2a4a6a"), 180)
	_signboard(label, Vector3(0, 4.3, -d * 0.25 - 4.1), 0)

# ---------------------------------------------------------------- 仓库
## size = (宽, 高, 长)。米色砖墙 + 大货门 + 装卸台
func _b_warehouse() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d, STONE)
	_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	_gable_roof(w, d, h, w * 0.35, color_b, 0.5)
	_col_box(Vector3(w, w * 0.2, d), Vector3(0, h + w * 0.1, 0))
	for i in int(d / 5.0):
		var z := -d * 0.5 + 2.5 + i * 5.0
		for sx in [-1, 1]:
			_box(Vector3(0.6, h, 0.8), Vector3(sx * (w * 0.5 + 0.2), h * 0.5, z), color_c)
			_window(Vector3(sx * (w * 0.5 + 0.06), h * 0.75, z + 2.5), 1.4, 1.0, sx * 90)
	_box(Vector3(w * 0.55, h * 0.7, 0.2), Vector3(0, h * 0.35, -d * 0.5 - 0.1), Color("6a4a30"))
	for k in 5:
		_box(Vector3(w * 0.55, 0.1, 0.24), Vector3(0, h * 0.14 * k + 0.4, -d * 0.5 - 0.12), Color("4a3020"))
	_box(Vector3(w * 0.8, 1.0, 3.0), Vector3(0, 0.5, -d * 0.5 - 1.5), STONE, Vector3.ZERO, true)
	_mesh(U.prism_mesh(Vector3(w * 0.3, w * 0.12, 1.0)), Vector3(0, h + 0.2, -d * 0.5 - 0.2), color_a)
	_signboard(label, Vector3(0, h * 0.82, -d * 0.5 - 0.25), 0)

# ---------------------------------------------------------------- 海运客运站
## size = (宽, 高, 进深)。铸铁玻璃拱顶大厅 + 钟 + 临水候船雨棚
func _b_terminal() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d, STONE)
	_box(Vector3(w, h, d * 0.35), Vector3(0, h * 0.5, -d * 0.325), color_a, Vector3.ZERO, true)
	_box(Vector3(w + 0.5, 0.6, d * 0.35 + 0.5), Vector3(0, h, -d * 0.325), STONE)
	_win_row(-d * 0.5 - 0.06, w * 0.9, h * 0.5, int(w / 3.2), 1.4, h * 0.5, 180.0, true)
	_mesh(U.cyl_mesh(2.0, 2.0, 0.3, 24), Vector3(0, h + 2.2, -d * 0.5 + 0.2), Color("f8f4e8"), Vector3(90, 0, 0))
	_mesh(U.torus_mesh(1.9, 2.2, 24), Vector3(0, h + 2.2, -d * 0.5 + 0.1), GOLD, Vector3(90, 0, 0))
	_mesh(U.prism_mesh(Vector3(w * 0.4, 4.4, 1.0)), Vector3(0, h + 2.2, -d * 0.5 + 0.6), color_a)
	for sx in [-1, 1]:
		_box(Vector3(1.0, h * 0.7, d * 0.65), Vector3(sx * w * 0.48, h * 0.35, d * 0.175), DARK, Vector3.ZERO, true)
	var arcs := int(d * 0.65 / 4.0)
	for i in arcs:
		_mesh(U.torus_mesh(w * 0.46, w * 0.48, 32), Vector3(0, h * 0.7, -d * 0.15 + i * 4.0), DARK, Vector3(90, 0, 0), Vector3(1, 0.3, 1))
	_mesh(U.cyl_mesh(w * 0.47, w * 0.47, d * 0.65, 24), Vector3(0, h * 0.7, d * 0.175), Color.WHITE, Vector3(90, 0, 0), Vector3.ONE, U.mat(Color(0.6, 0.85, 1.0, 0.4), 0.0, true))
	_box(Vector3(w * 0.8, 0.25, 8.0), Vector3(0, 4.0, d * 0.5 + 4.0), color_b)
	for i in 4:
		_mesh(U.cyl_mesh(0.15, 0.15, 4.0, 8), Vector3(-w * 0.35 + i * w * 0.233, 2.0, d * 0.5 + 7.5), DARK)
	_door(Vector3(0, 0, -d * 0.5 - 0.06), 3.0, 4.0, Color("2a4a6a"), 180)
	_signboard(label, Vector3(0, h * 0.86, -d * 0.5 - 0.25), 0)

# ---------------------------------------------------------------- 维多利亚式联排住宅
## size = (宽, 高, 进深)，variant：0 平顶山墙 / 1 角楼 / 2 凸窗 / 3 双子
func _b_rowhouse() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	var fl := maxi(2, int(h / 3.4))
	_foundation(w, d, STONE)
	_box(Vector3(w, 3.4, d), Vector3(0, 1.7, 0), BEIGE.darkened(0.04), Vector3.ZERO, true)
	_box(Vector3(w - 0.1, h - 3.4, d - 0.1), Vector3(0, 3.4 + (h - 3.4) * 0.5, 0), color_a, Vector3.ZERO, true)
	for f in range(1, fl):
		_box(Vector3(w + 0.2, 0.22, d + 0.2), Vector3(0, f * 3.4, 0), WHITE)
	_box(Vector3(w + 0.4, 0.4, d + 0.4), Vector3(0, h, 0), WHITE)
	# 曼萨德屋顶 + 老虎窗 + 烟囱
	var rh := 3.0
	_mesh(U.cyl_mesh(0.75, 1.0, rh, 4), Vector3(0, h + rh * 0.5 + 0.2, 0), color_b, Vector3(0, 45, 0), Vector3(w * 0.5 / 0.7071, 1, d * 0.5 / 0.7071))
	_col_box(Vector3(w, rh, d), Vector3(0, h + rh * 0.5, 0))
	for i in maxi(1, int(w / 3.6)):
		var x := (i - (maxi(1, int(w / 3.6)) - 1) * 0.5) * 3.4
		_box(Vector3(1.1, 1.3, 0.9), Vector3(x, h + 1.1, -d * 0.5 + 0.7), WHITE)
		_window(Vector3(x, h + 1.1, -d * 0.5 + 0.22), 0.7, 0.9, 180)
		_mesh(U.prism_mesh(Vector3(1.3, 0.6, 1.0)), Vector3(x, h + 2.05, -d * 0.5 + 0.7), color_b, Vector3(0, 90, 0))
	for sx in [-1, 1]:
		_box(Vector3(0.9, 2.6, 0.9), Vector3(sx * (w * 0.5 - 0.6), h + 2.2, d * 0.15), Color("b8a890"))
	var cols := maxi(2, int(w / 2.6))
	for f in range(1, fl):
		var y := f * 3.4 + 1.7
		if y > h - 0.6:
			break
		for i in cols:
			var x2 := (i - (cols - 1) * 0.5) * (w / cols)
			if variant % 2 == 0:
				_arch_win(Vector3(x2, y - 0.2, -d * 0.5 - 0.06), 0.95, 1.5)
			else:
				_window(Vector3(x2, y, -d * 0.5 - 0.06), 1.0, 1.7, 180)
			_window(Vector3(x2, y, d * 0.5 + 0.06), 1.0, 1.6)
	match variant:
		1:
			# 角楼
			var tr := minf(w, d) * 0.22
			_mesh(U.cyl_mesh(tr, tr, h + 1.0, 12), Vector3(w * 0.5 - tr * 0.6, (h + 1.0) * 0.5, -d * 0.5 + tr * 0.6), color_a.lightened(0.03))
			_spire(Vector3(w * 0.5 - tr * 0.6, h + 1.0, -d * 0.5 + tr * 0.6), tr * 1.15, tr * 2.6, color_b, 12)
		2:
			# 凸窗
			for sx2 in [-1, 1]:
				_box(Vector3(2.4, h - 4.0, 1.0), Vector3(sx2 * w * 0.25, 3.4 + (h - 4.0) * 0.5, -d * 0.5 - 0.5), WHITE)
				for f2 in range(1, fl):
					if f2 * 3.4 + 1.7 < h - 0.6:
						_window(Vector3(sx2 * w * 0.25, f2 * 3.4 + 1.7, -d * 0.5 - 1.06), 1.6, 1.6, 180)
		3:
			_mesh(U.prism_mesh(Vector3(w * 0.5, 2.2, 1.0)), Vector3(-w * 0.25, h + 1.1, -d * 0.5 + 0.2), color_a)
			_mesh(U.prism_mesh(Vector3(w * 0.5, 2.2, 1.0)), Vector3(w * 0.25, h + 1.1, -d * 0.5 + 0.2), color_a)
	_door(Vector3(0, 0, -d * 0.5 - 0.06), 1.4, 2.6, color_c.darkened(0.3), 180)
	_box(Vector3(2.4, 0.3, 1.2), Vector3(0, 0.15, -d * 0.5 - 0.7), STONE, Vector3.ZERO, true)
	for sx3 in [-1, 1]:
		_window(Vector3(sx3 * w * 0.3, 1.7, -d * 0.5 - 0.06), 1.6, 1.6, 180)
	if label != "":
		var awn := color_c
		for k in 5:
			_box(Vector3(w * 0.9 / 5.0, 0.08, 1.4), Vector3((k - 2) * w * 0.9 / 5.0, 3.0, -d * 0.5 - 0.7), awn if k % 2 == 0 else WHITE, Vector3(-18, 0, 0))
	_signboard(label, Vector3(0, 3.4, -d * 0.5 - 0.2), 0)

# ---------------------------------------------------------------- 行会会馆
## size = (宽, 高, 进深)；color_c 为行会徽记色；variant 1 = 锻造烟囱，2 = 齿轮（精工），3 = 书卷（学者）
func _b_guildhouse() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d, STONE)
	_box(Vector3(w, h * 0.35, d), Vector3(0, h * 0.175, 0), STONE.lightened(0.05), Vector3.ZERO, true)
	_box(Vector3(w - 0.2, h * 0.65, d - 0.2), Vector3(0, h * 0.35 + h * 0.325, 0), color_a, Vector3.ZERO, true)
	_gable_roof(w, d, h, w * 0.3, color_b, 0.5)
	_col_box(Vector3(w, w * 0.15, d), Vector3(0, h + w * 0.08, 0))
	# 中央山墙立面
	_box(Vector3(w * 0.4, h * 1.15, 1.2), Vector3(0, h * 0.575, -d * 0.5 - 0.6), WHITE, Vector3.ZERO, true)
	_mesh(U.prism_mesh(Vector3(w * 0.44, w * 0.2, 1.4)), Vector3(0, h * 1.15 + w * 0.1, -d * 0.5 - 0.6), color_b)
	_mesh(U.cyl_mesh(w * 0.09, w * 0.09, 0.3, 24), Vector3(0, h * 0.9, -d * 0.5 - 1.25), color_c, Vector3(90, 0, 0))
	_mesh(U.torus_mesh(w * 0.09, w * 0.11, 24), Vector3(0, h * 0.9, -d * 0.5 - 1.3), GOLD, Vector3(90, 0, 0))
	_win_row(-d * 0.5 - 0.06, w, h * 0.55, int(w / 3.0), 1.1, 1.9, 180.0, true)
	_win_row(-d * 0.5 - 0.06, w, h * 0.18, int(w / 3.0), 1.2, 1.4)
	_side_wins(w, d, h * 0.55, int(d / 3.5))
	# 侧塔
	_mesh(U.cyl_mesh(w * 0.1, w * 0.1, h * 1.3, 10), Vector3(-w * 0.5, h * 0.65, -d * 0.5), color_a)
	_spire(Vector3(-w * 0.5, h * 1.3, -d * 0.5), w * 0.13, w * 0.3, color_b, 10)
	for k in 2:
		_box(Vector3(1.4, h * 0.5, 0.06), Vector3((k * 2 - 1) * w * 0.28, h * 0.6, -d * 0.5 - 0.1), color_c)
	match variant:
		1:
			for i in 2:
				_box(Vector3(1.6, h * 0.7, 1.6), Vector3(w * 0.3, h + h * 0.2, d * (0.1 + i * 0.2)), Color("8a7a6a"))
			if not Engine.is_editor_hint():
				var p := CPUParticles3D.new()
				p.amount = 18
				p.lifetime = 4.0
				p.position = Vector3(w * 0.3, h * 1.6, d * 0.2)
				p.direction = Vector3.UP
				p.spread = 12.0
				p.gravity = Vector3(0.4, 0.5, 0)
				p.initial_velocity_min = 1.0
				p.initial_velocity_max = 1.6
				var qm := QuadMesh.new()
				qm.size = Vector2(1.4, 1.4)
				var mm := U.unshaded(Color(0.35, 0.35, 0.38, 0.35), true).duplicate()
				mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				qm.material = mm
				p.mesh = qm
				_gen.add_child(p)
		2:
			if not Engine.is_editor_hint():
				var gear := Node3D.new()
				gear.position = Vector3(0, h * 0.9, -d * 0.5 - 1.5)
				_gen.add_child(gear)
				U.add_mesh(gear, U.torus_mesh(w * 0.06, w * 0.1, 12), _m(GOLD), Vector3.ZERO, Vector3(90, 0, 0))
				for t in 8:
					U.add_mesh(gear, U.box_mesh(Vector3(0.4, w * 0.24, 0.2)), _m(GOLD), Vector3.ZERO, Vector3(0, 0, t * 22.5))
				_anim_nodes.append(["spin_z", gear, 0.6])
		3:
			_mesh(U.cyl_mesh(0.6, 0.6, w * 0.3, 12), Vector3(0, h * 1.18, -d * 0.5 - 0.8), Color("f4ecd8"), Vector3(0, 0, 90))
	_door(Vector3(0, 0, -d * 0.5 - 1.26), 2.4, 3.6, Color("4a3020"), 180)
	_signboard(label, Vector3(0, h * 0.36, -d * 0.5 - 1.35), 0)

# ---------------------------------------------------------------- 三桅商船
## size = (宽, -, 长)
func _b_galleon() -> void:
	var l := size.z
	var w := size.x
	_mesh(U.capsule_mesh(w * 0.5, l), Vector3(0, 1.6 - w * 0.3, 0), color_c, Vector3(90, 0, 0), Vector3(1, 1, 0.6))
	_box(Vector3(w * 0.92, 0.25, l * 0.86), Vector3(0, 1.7, 0), color_c.lightened(0.3), Vector3.ZERO, true)
	_col_box(Vector3(w, 2.4, l * 0.9), Vector3(0, 0.6, 0))
	_box(Vector3(w * 0.96, 0.5, l * 0.86), Vector3(0, 1.2, 0), color_b)
	_box(Vector3(w * 0.85, 3.0, l * 0.2), Vector3(0, 3.2, l * 0.36), color_c.lightened(0.15), Vector3.ZERO, true)
	_window(Vector3(0, 3.4, l * 0.46 + 0.06), w * 0.6, 1.0, 0)
	_box(Vector3(w * 0.7, 1.6, l * 0.12), Vector3(0, 2.6, -l * 0.38), color_c.lightened(0.15))
	_mesh(U.cyl_mesh(0.1, 0.2, l * 0.35, 6), Vector3(0, 2.4, -l * 0.55), color_c, Vector3(-70, 0, 0))
	for i in 3:
		var z := -l * 0.25 + i * l * 0.25
		var mh := l * (0.75 if i == 1 else 0.6)
		_mesh(U.cyl_mesh(0.18, 0.28, mh, 8), Vector3(0, 1.8 + mh * 0.5, z), Color("6a4a30"))
		for k in 3:
			var sy := 1.8 + mh * (0.35 + k * 0.22)
			var sw := w * (1.7 - k * 0.35)
			_box(Vector3(sw, mh * 0.18, 0.1), Vector3(0, sy, z - 0.3), WHITE)
			_box(Vector3(sw + 0.4, 0.14, 0.14), Vector3(0, sy + mh * 0.09, z - 0.3), Color("6a4a30"))
		_box(Vector3(0.06, 0.9, 1.6), Vector3(0, 1.8 + mh + 0.3, z), color_b)
	_anim_nodes.append(["bob", _gen, 0.0])

# ---------------------------------------------------------------- 魔导蒸汽客轮
## size = (宽, -, 长)
func _b_steamship() -> void:
	var l := size.z
	var w := size.x
	_mesh(U.capsule_mesh(w * 0.5, l), Vector3(0, 1.4 - w * 0.275, 0), DARK, Vector3(90, 0, 0), Vector3(1, 1, 0.55))
	_box(Vector3(w * 0.95, 0.6, l * 0.88), Vector3(0, 1.6, 0), color_a, Vector3.ZERO, true)
	_col_box(Vector3(w, 3.0, l * 0.9), Vector3(0, 0.8, 0))
	_box(Vector3(w * 0.8, 2.6, l * 0.55), Vector3(0, 3.2, 0.05 * l), color_a, Vector3.ZERO, true)
	_box(Vector3(w * 0.65, 2.2, l * 0.32), Vector3(0, 5.6, 0.0), color_a)
	_box(Vector3(w * 0.85, 0.2, l * 0.58), Vector3(0, 4.55, 0.05 * l), color_b)
	_box(Vector3(w * 0.7, 0.2, l * 0.35), Vector3(0, 6.75, 0.0), color_b)
	for i in int(l * 0.5 / 1.6):
		for sx in [-1, 1]:
			_window(Vector3(sx * (w * 0.4 + 0.06), 3.2, -l * 0.22 + i * 1.6), 0.8, 0.8, sx * 90)
	for i in 2:
		var z := -l * 0.08 + i * l * 0.16
		_mesh(U.cyl_mesh(w * 0.13, w * 0.15, 4.0, 12), Vector3(0, 8.8, z), color_b)
		_mesh(U.cyl_mesh(w * 0.155, w * 0.155, 0.5, 12), Vector3(0, 10.6, z), GOLD)
		_glow(Vector3(0, 7.4, z - w * 0.15), 0.3, Color("9ae8ff"))
	for sx in [-1, 1]:
		_mesh(U.cyl_mesh(2.2, 2.2, 1.2, 16), Vector3(sx * (w * 0.5 + 0.6), 1.6, 0), color_b, Vector3(0, 0, 90))
		_mesh(U.sphere_mesh(2.3, 4.6, true, 16), Vector3(sx * (w * 0.5 + 0.6), 1.6, 0), color_a, Vector3(0, 0, sx * -90), Vector3(1, 0.5, 1))
	_mesh(U.cyl_mesh(0.08, 0.08, 6.0, 6), Vector3(0, 9.0, -l * 0.3), DARK)
	_box(Vector3(0.06, 1.0, 1.8), Vector3(0, 11.0, -l * 0.3), SEA_L)
	_anim_nodes.append(["bob", _gen, 0.0])

# ---------------------------------------------------------------- 城市排水出口
## size = (拱宽, 墙高, 墙长)。石墙 + 拱形涵洞 + 铁栅 + 流水
func _b_culvert() -> void:
	var w := size.x
	var h := size.y
	var l := size.z
	_box(Vector3(l, h, 3.0), Vector3(0, h * 0.5, 0), color_a, Vector3.ZERO, true)
	_box(Vector3(l + 0.4, 0.6, 3.4), Vector3(0, h, 0), STONE)
	_mesh(U.cyl_mesh(w * 0.5, w * 0.5, 3.2, 20), Vector3(0, w * 0.5, 0), Color("1a2228"), Vector3(90, 0, 0))
	_mesh(U.torus_mesh(w * 0.5, w * 0.5 + 0.8, 24), Vector3(0, w * 0.5, -1.6), STONE, Vector3(90, 0, 0), Vector3(1, 1.2, 1))
	for i in 6:
		_box(Vector3(0.12, w, 0.12), Vector3(-w * 0.4 + i * w * 0.16, w * 0.5, -1.65), DARK)
	_box(Vector3(w, 0.12, 0.12), Vector3(0, w * 0.6, -1.65), DARK)
	var wm := ShaderMaterial.new()
	wm.shader = load("res://src/terrain/water.gdshader")
	WaterStyle.configure(wm, 0.20)
	wm.set_shader_parameter("noise_tex", BrushTerrain.get_noise_texture())
	wm.set_shader_parameter("has_height", 0.0)
	_mesh(U.box_mesh(Vector3(w * 0.7, 0.2, 6.0)), Vector3(0, 0.3, -4.5), Color.WHITE, Vector3(-18, 0, 0), Vector3.ONE, wm)
	_signboard(label, Vector3(0, h - 1.0, -1.7), 0)

# ---------------------------------------------------------------- 铸铁玻璃市场大厅
## size = (宽, 高, 长)
func _b_market_hall() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_foundation(w, d, STONE)
	for sx in [-1, 1]:
		_box(Vector3(1.0, h, d), Vector3(sx * w * 0.5, h * 0.5, 0), color_a, Vector3.ZERO, true)
		for i in int(d / 4.0):
			_arch_win(Vector3(sx * (w * 0.5 + 0.06), h * 0.45, -d * 0.5 + 2.0 + i * 4.0), 2.0, h * 0.5, sx * 90)
	for i in int(d / 4.0) + 1:
		_mesh(U.torus_mesh(w * 0.48, w * 0.5, 32), Vector3(0, h, -d * 0.5 + i * 4.0), DARK, Vector3(90, 0, 0), Vector3(1, 0.3, 1))
	_mesh(U.cyl_mesh(w * 0.49, w * 0.49, d, 24), Vector3(0, h, 0), Color.WHITE, Vector3(90, 0, 0), Vector3.ONE, U.mat(Color(0.65, 0.88, 1.0, 0.4), 0.0, true))
	_box(Vector3(w * 0.9, h * 1.2, 1.0), Vector3(0, h * 0.6, -d * 0.5), color_a, Vector3.ZERO, false)
	_mesh(U.cyl_mesh(w * 0.3, w * 0.3, 0.3, 24), Vector3(0, h * 1.05, -d * 0.5 - 0.5), Color.WHITE, Vector3(90, 0, 0), Vector3.ONE, get_window_mat())
	_box(Vector3(w * 0.3, h * 0.6, 0.3), Vector3(0, h * 0.3, -d * 0.5 - 0.5), Color("2a3a4a"))
	_signboard(label, Vector3(0, h * 0.7, -d * 0.5 - 0.7), 0)
