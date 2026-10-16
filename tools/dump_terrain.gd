extends SceneTree
## 把潮风高地地形（城市周边）导出成网页用的低分辨率高度 + 颜色网格：docs/city_v7/terrain.json
## Godot --headless --path . --script res://tools/dump_terrain.gd
## 坐标为区域坐标；高度减去水位 8 与网页规划标高对齐（0 = 海平面）。

const SRC := "res://data/terrain/tidewind.res"
const OUT := "res://docs/city_v7/terrain.json"
const X0 := -1040.0
const Z0 := -760.0
const X1 := 960.0
const Z1 := 1240.0
const STEP := 10.0
const SEA := 8.0

func _initialize() -> void:
	var d: TerrainData = load(SRC)
	var org := Vector2(X0, Z0)   # 与 gen_tidewind ORIGIN 一致
	var nx := int((X1 - X0) / STEP) + 1
	var nz := int((Z1 - Z0) / STEP) + 1
	var h := PackedFloat32Array()
	var c := PackedByteArray()
	for iz in nz:
		for ix in nx:
			var lx := ix * STEP
			var lz := iz * STEP
			h.append(snappedf(d.sample(lx, lz) - SEA, 0.1))
			var px := clampi(int(lx / d.cell_size), 0, d.resolution - 1)
			var pz := clampi(int(lz / d.cell_size), 0, d.resolution - 1)
			var w := d.get_layer(px, pz)
			var col := d.layer_colors[0]
			var base := 1.0
			var acc := Color(0, 0, 0)
			for i in 8:
				acc += d.layer_colors[i + 1] * w[i]
				base -= w[i]
			col = acc + d.layer_colors[0] * maxf(base, 0.0)
			c.append(int(clampf(col.r, 0, 1) * 255)); c.append(int(clampf(col.g, 0, 1) * 255)); c.append(int(clampf(col.b, 0, 1) * 255))
	var out := {"x0": X0, "z0": Z0, "step": STEP, "nx": nx, "nz": nz, "h": Array(h), "c": Marshalls.raw_to_base64(c)}
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	# 北墙外剖面（检查用）
	for x in [-700.0, -120.0, 230.0]:
		var s := "PROFILE x=%d:" % int(x)
		for z in range(-760, -560, 20):
			s += " %d:%.0f" % [z, d.sample(x - X0, z - Z0) - SEA]
		print(s)
	print("TERRAIN_DUMP ", nx, "x", nz)
	quit()
