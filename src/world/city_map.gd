class_name CityV7Map
extends Node3D
## 晴岚港 v7 的小地图 / 世界地图轮廓：街坊路基、沿街楼、地标占地（数据由生成器写入，城市网格本身不参与地图绘制）。
@export var blocks: Array = []        # [[区颜色, use, PackedVector2Array], ...]
@export var lots: Array = []          # [PackedVector2Array, ...]
@export var landmarks: Array = []     # [PackedVector2Array, ...]

func draw_map(img: Image, cs: float, origin: Vector3) -> void:
	var off := Vector2(global_position.x - origin.x, global_position.z - origin.z)
	for b in blocks:
		var col: Color = Color(b[0])
		if b[1] == "park":
			col = Color("7fa565")
		elif b[1] == "square":
			col = Color("e3dac6")
		else:
			col = Color("d8cfb8").lerp(col, 0.35)
		_fill(img, b[2], col, cs, off)
	for l in lots:
		_fill(img, l, Color("8f7f6b"), cs, off)
	for l in landmarks:
		_fill(img, l, Color("5a3a28"), cs, off)

func _fill(img: Image, poly: PackedVector2Array, col: Color, cs: float, off: Vector2) -> void:
	if poly.size() < 3:
		return
	var mn := Vector2(INF, INF)
	var mx := -mn
	var pts := PackedVector2Array()
	for p in poly:
		var q := (p + off) / cs
		pts.append(q)
		mn = mn.min(q)
		mx = mx.max(q)
	for y in range(maxi(0, int(mn.y)), mini(img.get_height(), int(mx.y) + 1)):
		for x in range(maxi(0, int(mn.x)), mini(img.get_width(), int(mx.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				img.set_pixel(x, y, col)
