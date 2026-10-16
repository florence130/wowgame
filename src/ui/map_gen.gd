class_name MapGen
extends RefCounted
## 由地形数据生成手绘风格地图图像（小地图与世界地图共用）

static var _cache := {}

static func build(zone: Node) -> ImageTexture:
	var t: BrushTerrain = zone.terrain if zone else null
	if t == null or t.data == null:
		return null
	var key: String = zone.zone_id
	if _cache.has(key):
		return _cache[key]
	var d: TerrainData = t.data
	var res := d.resolution
	var img := Image.create(res, res, false, Image.FORMAT_RGB8)
	var ca := d.control_a.get_data()
	var cb := d.control_b.get_data()
	var cols: PackedColorArray = d.layer_colors
	var wl := d.water_level
	var r1 := res + 1
	var light := Vector3(-0.6, 0.8, -0.4).normalized()
	var out := PackedByteArray()
	out.resize(res * res * 3)
	for z in res:
		for x in res:
			var i := z * res + x
			var h := d.heights[z * r1 + x]
			var c: Color = cols[0]
			var pi := i * 4
			c = c.lerp(cols[1], ca[pi] / 255.0)
			c = c.lerp(cols[2], ca[pi + 1] / 255.0)
			c = c.lerp(cols[3], ca[pi + 2] / 255.0)
			c = c.lerp(cols[4], ca[pi + 3] / 255.0)
			c = c.lerp(cols[5], cb[pi] / 255.0)
			c = c.lerp(cols[6], cb[pi + 1] / 255.0)
			c = c.lerp(cols[7], cb[pi + 2] / 255.0)
			c = c.lerp(cols[8], cb[pi + 3] / 255.0)
			var hl := d.heights[z * r1 + maxi(0, x - 1)]
			var hr := d.heights[z * r1 + mini(res, x + 1)]
			var hu := d.heights[maxi(0, z - 1) * r1 + x]
			var hd := d.heights[mini(res, z + 1) * r1 + x]
			var n := Vector3(hl - hr, 2.0 * d.cell_size, hu - hd).normalized()
			if n.y < 0.75:
				c = c.lerp(cols[3], clampf((0.75 - n.y) * 3.0, 0.0, 1.0))
			var shade := clampf(n.dot(light) * 1.25, 0.55, 1.15)
			c = c * shade
			if wl > -999.0 and h < wl:
				var depth := clampf((wl - h) / 2.5, 0.0, 1.0)
				c = Color("6fc6d8").lerp(Color("2f7fb0"), depth)
				if depth < 0.12:
					c = c.lerp(Color(0.92, 0.97, 1.0), 0.5)
			out[i * 3] = int(clampf(c.r, 0.0, 1.0) * 255.0)
			out[i * 3 + 1] = int(clampf(c.g, 0.0, 1.0) * 255.0)
			out[i * 3 + 2] = int(clampf(c.b, 0.0, 1.0) * 255.0)
	img = Image.create_from_data(res, res, false, Image.FORMAT_RGB8, out)
	# 建筑轮廓
	var cs := d.cell_size
	var origin: Vector3 = t.global_position
	_draw_props(zone, img, cs, origin)
	img.resize(res * 2, res * 2, Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## 无缝大世界：把多个区域的地图按世界坐标拼成一张（空白处填远景色）。返回 [纹理, 世界原点, 世界尺寸 Vector2]
static func build_world(zone_list: Array) -> Array:
	var key := "world"
	var rects := []
	var bounds := Rect2()
	for z in zone_list:
		if z == null or z.terrain == null or z.terrain.data == null:
			continue
		key += "_" + z.zone_id
		var s: float = z.terrain.data.world_size()
		var r := Rect2(Vector2(z.terrain.global_position.x, z.terrain.global_position.z), Vector2(s, s))
		rects.append([z, r])
		bounds = r if bounds.size == Vector2.ZERO else bounds.merge(r)
	if rects.is_empty():
		return [null, Vector3.ZERO, Vector2.ONE]
	if _cache.has(key):
		return _cache[key]
	var mpp := 1.25   # 每像素米数（与单区域地图一致：cell 2.5m，放大 2 倍）
	var w := int(ceil(bounds.size.x / mpp))
	var h := int(ceil(bounds.size.y / mpp))
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	_fill_far(img, bounds, mpp, rects)
	for e in rects:
		var tex: ImageTexture = build(e[0])
		if tex == null:
			continue
		var src := tex.get_image()
		var r: Rect2 = e[1]
		var pw := int(round(r.size.x / mpp))
		if src.get_width() != pw:
			src.resize(pw, pw, Image.INTERPOLATE_BILINEAR)
		if src.get_format() != Image.FORMAT_RGB8:
			src.convert(Image.FORMAT_RGB8)
		img.blit_rect(src, Rect2i(0, 0, pw, pw), Vector2i(int(round((r.position.x - bounds.position.x) / mpp)), int(round((r.position.y - bounds.position.y) / mpp))))
	var out := [ImageTexture.create_from_image(img), Vector3(bounds.position.x, 0, bounds.position.y), bounds.size]
	_cache[key] = out
	return out

## 拼图里没有可玩地形的区域：用远景地貌的真实高度画出海岸、丘陵与山地（与可玩地形同一套配色与光照）
static func _fill_far(img: Image, bounds: Rect2, mpp: float, rects: Array) -> void:
	var fl = Game.world.far_land if Game.world else null
	var w := img.get_width()
	var h := img.get_height()
	var step := 4   # 每 4 像素采样一次高度，再双线性放大，速度快且足够平滑
	var gw := w / step + 2
	var gh := h / step + 2
	var hs := PackedFloat32Array()
	hs.resize(gw * gh)
	hs.fill(1e9)   # 按需采样（只算被用到的格点）
	var wl: float = fl.water if fl else 8.0
	var light := Vector3(-0.6, 0.8, -0.4).normalized()
	var base_col: Color = rects[0][0].terrain.data.layer_colors[0]
	var rock := Color(0.56, 0.55, 0.52)
	var cell := step * mpp
	for py in h:
		var wz := bounds.position.y + (py + 0.5) * mpp
		# 本行被可玩地形覆盖的像素区间
		var spans := []
		for e in rects:
			var r: Rect2 = e[1]
			if wz >= r.position.y and wz < r.end.y:
				spans.append(Vector2i(int((r.position.x - bounds.position.x) / mpp), int(ceil((r.end.x - bounds.position.x) / mpp))))
		for px in w:
			var covered := false
			for sp in spans:
				if px >= sp.x and px < sp.y:
					covered = true
					break
			if covered:
				continue
			var fx := float(px) / step
			var fz := float(py) / step
			var ix := mini(int(fx), gw - 2)
			var iz := mini(int(fz), gh - 2)
			var tx := fx - ix
			var tz := fz - iz
			for k in [iz * gw + ix, iz * gw + ix + 1, (iz + 1) * gw + ix, (iz + 1) * gw + ix + 1]:
				if hs[k] > 1e8:
					hs[k] = fl.height(bounds.position.x + (k % gw) * cell, bounds.position.y + (k / gw) * cell) if fl else 20.0
			var h00 := hs[iz * gw + ix]
			var h10 := hs[iz * gw + ix + 1]
			var h01 := hs[(iz + 1) * gw + ix]
			var h11 := hs[(iz + 1) * gw + ix + 1]
			var hv := lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)
			var c: Color
			if hv < wl:
				var depth := clampf((wl - hv) / 2.5, 0.0, 1.0)
				c = Color("6fc6d8").lerp(Color("2f7fb0"), depth)
				if depth < 0.12:
					c = c.lerp(Color(0.92, 0.97, 1.0), 0.5)
			else:
				var n := Vector3(h00 - h10 + h01 - h11, 4.0 * cell, h00 - h01 + h10 - h11).normalized()
				c = base_col.darkened(0.08).lerp(rock, clampf((0.82 - n.y) * 3.0, 0.0, 1.0))
				c = c.lerp(Color(0.96, 0.97, 1.0), smoothstep(330.0, 420.0, hv))
				if hv < wl + 1.5:
					c = Color(0.90, 0.84, 0.64)
				c = c * clampf(n.dot(light) * 1.25, 0.55, 1.15)
			img.set_pixel(px, py, c)

## 当前应显示的地图：大世界时拼图，否则单区域。返回 [纹理, 原点, 尺寸 Vector2]
static func for_current(z: Node) -> Array:
	var w = Game.world
	if w and w.zones.size() > 1:
		return build_world(w.zones.values())
	var tex := build(z)
	if z and z.terrain:
		var s: float = z.terrain.data.world_size()
		return [tex, z.terrain.global_position, Vector2(s, s)]
	return [tex, Vector3.ZERO, Vector2(1000, 1000)]

static func _draw_props(n: Node, img: Image, cs: float, origin: Vector3) -> void:
	for c in n.get_children():
		if c is CityHouses or c is CityV7Map:
			c.draw_map(img, cs, origin)
			continue
		if c is Prop or c is ModelProp:
			# Native civil ribbons have large bounding boxes over water; the terrain already maps their roads.
			if c is ModelProp and c.asset_scene.begins_with("res://assets/models/city_v5/civil_generated/"):
				continue
			var k: String = c.kind
			var roof := Color()
			var fp := Vector2.ZERO
			match k:
				"house", "cottage", "townhouse", "church", "cityhall", "guildhall", "hall", "station", "tower", "windmill", "dome", "clocktower", "tent", "stall", "lighthouse":
					roof = c.color_b.darkened(0.15)
					fp = Vector2(c.size.x, c.size.z) if k not in ["tower", "windmill", "dome", "lighthouse"] else Vector2(c.size.x, c.size.x)
				"wall", "gate":
					roof = Color("8a8478")
					fp = Vector2(c.size.x, maxf(2.0, c.size.z))
				"bridge", "pier", "platform", "block":
					roof = c.color_a.darkened(0.1)
					fp = Vector2(c.size.x, c.size.z)
				"fountain", "well":
					roof = Color("b0d8f0")
					fp = Vector2(c.size.x, c.size.x)
				_:
					if c.has_method("map_footprint"):
						var mf: Array = c.map_footprint()
						if mf.size() == 2:
							roof = mf[0]
							fp = mf[1]
			if fp != Vector2.ZERO:
				var p: Vector3 = c.global_position - origin
				var basis: Basis = c.global_transform.basis
				var ex := basis.x * fp.x * 0.5
				var ez := basis.z * fp.y * 0.5
				var steps := int(maxf(fp.x, fp.y) / cs * 2.0) + 2
				for i in steps + 1:
					for j in steps + 1:
						var q := p + ex * (i * 2.0 / steps - 1.0) + ez * (j * 2.0 / steps - 1.0)
						var px := int(q.x / cs)
						var pz := int(q.z / cs)
						if px >= 0 and pz >= 0 and px < img.get_width() and pz < img.get_height():
							var edge := i == 0 or j == 0 or i == steps or j == steps
							img.set_pixel(px, pz, roof.darkened(0.35) if edge else roof)
		if c.get_child_count() > 0 and not (c is Prop or c is ModelProp):
			_draw_props(c, img, cs, origin)
