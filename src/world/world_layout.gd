class_name WorldLayout
extends RefCounted
## 无缝大世界布局：晨露谷与潮风高地（含晴岚港）拼成同一张地图，同一场景、同一坐标系。
## 各区域场景仍单独生成 / 编辑（区域内坐标不变），运行时按 OFFSETS 平移后一起加载。
##
## 地理：一块北靠群山、西南临海的大陆。潮风高地在西（西岸是晴岚港与大海），晨露谷在东；
## 两图北缘对齐（世界 z=0），晨露谷整条西边（x=0, z 0–960）与高地东边相接，中间没有山墙，
## 地面向同一个"世界基础高度" world_base() 过渡（两侧各 BLEND 米），所以是连续的丘陵草原。
## 高地东门大路（区域 930,330 → 世界 -30,490）在 x=0 接上晨露谷的农庄大路，一路通往金穗镇。
## 两图北侧群山在接缝处连成一片（north_ridge），南侧是海岸（晨露谷河流向南入海）。

## 区域 → 世界偏移（区域坐标 + 偏移 = 世界坐标）
const OFFSETS := {"vale": Vector3(0, 0, 0), "tidewind": Vector3(-960, 0, 160)}
## 存档坐标版本：2 = 第一版拼接（高地偏移 -960,0,595），3 = 当前
const SAVE_VER := 3
const LEGACY_OFFSETS := {2: {"tidewind": Vector3(-960, 0, 595)}}
## 接缝线（世界坐标）：x = SEAM_X，z ∈ [SEAM_Z0, SEAM_Z1]（两图都存在的那一段）
const SEAM_X := 0.0
const SEAM_Z0 := 0.0
const SEAM_Z1 := 960.0
const BLEND := 110.0       # 两侧过渡宽度
## 跨界大路在接缝处的位置（世界 z）
const ROAD_Z := 490.0

static var _noise: FastNoiseLite

static func in_overworld(zone_id: String) -> bool:
	return OFFSETS.has(zone_id)

static func offset(zone_id: String) -> Vector3:
	return OFFSETS.get(zone_id, Vector3.ZERO)

static func zones() -> Array:
	return OFFSETS.keys()

## 旧版本存档里的区域偏移（用来把旧坐标换算到当前布局）
static func legacy_offset(ver: int, zone_id: String) -> Vector3:
	if ver < 2:
		return Vector3.ZERO
	return LEGACY_OFFSETS.get(ver, {}).get(zone_id, offset(zone_id))

## 世界基础高度：两图交界一带的连续起伏丘陵（世界坐标）
static func world_base(wx: float, wz: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 4242
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 0.0045
		_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		_noise.fractal_octaves = 4
	var h := 18.0 + _noise.get_noise_2d(wx, wz) * 7.0
	# 北侧群山（两图北缘都是山，在接缝处连成一片）
	h += pow(clampf((220.0 - wz) / 220.0, 0.0, 1.0), 1.6) * 44.0
	# 大路经过处平缓一些
	h = lerpf(h, 19.0, (1.0 - smoothstep(10.0, 45.0, absf(wz - ROAD_Z))) * 0.7)
	# 南侧海岸（晨露谷南缘 → 高地东南角）
	h = lerpf(h, 2.0, smoothstep(905.0, 975.0, wz))
	return h

## 生成器在基础地形之后调用：接缝两侧 width 米内向 world_base 过渡（接缝处两图严格等高）
static func apply_seam(b: ZoneBuilder, zone_id: String, width: float = BLEND) -> void:
	if not in_overworld(zone_id):
		return
	var off := offset(zone_id)
	var r1 := b.res + 1
	for z in r1:
		for x in r1:
			var wx := x * b.cs + b.org.x + off.x
			var wz := z * b.cs + b.org.y + off.z
			if wz < SEAM_Z0 - BLEND or wz > SEAM_Z1 + BLEND:
				continue
			var d := absf(wx - SEAM_X)
			if d > width:
				continue
			# 沿 z 方向在接缝段两端淡出（段外只有一侧有地形）
			var zf := smoothstep(SEAM_Z0 - BLEND, SEAM_Z0, wz) * (1.0 - smoothstep(SEAM_Z1, SEAM_Z1 + BLEND, wz))
			var t := (1.0 - smoothstep(0.0, width, d)) * zf
			if t <= 0.0:
				continue
			var i := z * r1 + x
			b.data.heights[i] = lerpf(b.data.heights[i], world_base(SEAM_X, clampf(wz, SEAM_Z0, SEAM_Z1)) * 0.5 + world_base(wx, wz) * 0.5 if d > 0.01 else world_base(SEAM_X, wz), t)

## 生成结束前再缝合一次（道路、河流等后续改动可能动到接缝附近），只影响接缝两侧 14m
static func stitch(b: ZoneBuilder, zone_id: String) -> void:
	apply_seam(b, zone_id, 14.0)
	stitch_road_surface(b.data, b.org, zone_id)

## Shared road core and soft shoulders, fading into each map's existing paint.
## Heights/buildings/city paving outside the crossing are preserved.
static func stitch_road_surface(data: TerrainData, origin: Vector2, zone_id: String) -> void:
	var off := offset(zone_id)
	for z in data.resolution:
		var wz := (z + 0.5) * data.cell_size + origin.y + off.z
		if absf(wz - ROAD_Z) > 22.0:
			continue
		for x in data.resolution:
			var wx := (x + 0.5) * data.cell_size + origin.x + off.x
			var blend := 1.0 - smoothstep(6.0, 32.0, absf(wx - SEAM_X))
			blend *= 1.0 - smoothstep(12.0, 22.0, absf(wz - ROAD_Z))
			if blend <= 0.0:
				continue
			var dirt := 1.0 - smoothstep(3.0, 7.0, absf(wz - ROAD_Z))
			var a := data.control_a.get_pixel(x, z)
			var b := data.control_b.get_pixel(x, z)
			data.control_a.set_pixel(x, z, a.lerp(Color(0, dirt, 0, 0), blend))
			data.control_b.set_pixel(x, z, b.lerp(Color(0, 0, 0, 0), blend))
