@tool
class_name TerrainData
extends Resource
## 地形数据：高度 + 两张混合控制图（8 个可涂刷层 + 基础层）

const LAYER_NAMES := ["草地(基础)", "深草/林地", "泥土路", "岩石", "沙地", "石板路", "农田", "花草地", "苔藓/暗土"]
const DEFAULT_COLORS := ArtStyle.TERRAIN_COLORS

@export var resolution: int = 256
@export var cell_size: float = 2.0
@export var heights: PackedFloat32Array = PackedFloat32Array()
@export var control_a: Image
@export var control_b: Image
@export var water_level: float = -1000.0
@export var layer_colors: PackedColorArray = PackedColorArray(DEFAULT_COLORS)
@export var texture_overrides: Dictionary = {}

func setup(res: int, cs: float, base_h: float = 0.0) -> void:
	resolution = res
	cell_size = cs
	heights = PackedFloat32Array()
	heights.resize((res + 1) * (res + 1))
	heights.fill(base_h)
	control_a = Image.create(res, res, false, Image.FORMAT_RGBA8)
	control_a.fill(Color(0, 0, 0, 0))
	control_b = Image.create(res, res, false, Image.FORMAT_RGBA8)
	control_b.fill(Color(0, 0, 0, 0))

func world_size() -> float:
	return resolution * cell_size

func idx(x: int, z: int) -> int:
	return z * (resolution + 1) + x

func get_h(x: int, z: int) -> float:
	x = clampi(x, 0, resolution)
	z = clampi(z, 0, resolution)
	return heights[z * (resolution + 1) + x]

func set_h(x: int, z: int, v: float) -> void:
	if x < 0 or z < 0 or x > resolution or z > resolution:
		return
	heights[z * (resolution + 1) + x] = v

## 局部坐标（米）双线性插值高度
func sample(lx: float, lz: float) -> float:
	var gx := clampf(lx / cell_size, 0.0, float(resolution) - 0.0001)
	var gz := clampf(lz / cell_size, 0.0, float(resolution) - 0.0001)
	var x0 := int(gx)
	var z0 := int(gz)
	var fx := gx - x0
	var fz := gz - z0
	var r1 := resolution + 1
	var h00 := heights[z0 * r1 + x0]
	var h10 := heights[z0 * r1 + x0 + 1]
	var h01 := heights[(z0 + 1) * r1 + x0]
	var h11 := heights[(z0 + 1) * r1 + x0 + 1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)

func normal_at(lx: float, lz: float) -> Vector3:
	var e := cell_size
	var hl := sample(lx - e, lz)
	var hr := sample(lx + e, lz)
	var hu := sample(lx, lz - e)
	var hd := sample(lx, lz + e)
	return Vector3(hl - hr, 2.0 * e, hu - hd).normalized()

## 读取某层权重（0=基础层）
func get_layer(px: int, pz: int) -> PackedFloat32Array:
	var a := control_a.get_pixel(px, pz)
	var b := control_b.get_pixel(px, pz)
	return PackedFloat32Array([a.r, a.g, a.b, a.a, b.r, b.g, b.b, b.a])

## 向某层涂刷（排他混合）
func paint_pixel(px: int, pz: int, layer: int, amount: float) -> void:
	if px < 0 or pz < 0 or px >= resolution or pz >= resolution:
		return
	var a := control_a.get_pixel(px, pz)
	var b := control_b.get_pixel(px, pz)
	var w := [a.r, a.g, a.b, a.a, b.r, b.g, b.b, b.a]
	for i in 8:
		var target := 1.0 if (i + 1) == layer else 0.0
		w[i] = lerpf(w[i], target, clampf(amount, 0.0, 1.0))
	control_a.set_pixel(px, pz, Color(w[0], w[1], w[2], w[3]))
	control_b.set_pixel(px, pz, Color(w[4], w[5], w[6], w[7]))
