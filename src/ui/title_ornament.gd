extends Control
## Original feathered crest drawn around the licensed title typeface.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	var silver := Color(0.86, 0.95, 1.0, 0.62)
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array()
		for i in 36:
			var t := i / 35.0
			points.append(center + Vector2(side * (210 + t * 230), 46 - sin(t * PI) * 50 - t * 40))
		draw_polyline(points, silver, 1.5, true)
		for i in 12:
			var t := i / 12.0
			var origin := center + Vector2(side * (245 + t * 170), 42 - sin(t * PI) * 48 - t * 40)
			var tip := origin + Vector2(side * (30 + t * 12), -20 - t * 21)
			draw_polyline(PackedVector2Array([origin, tip, origin + Vector2(side * 8, 3)]), Color(silver, 0.35), 1.0, true)
		draw_line(center + Vector2(side * 40, 132), center + Vector2(side * 230, 132), silver, 1.0, true)
	var diamond := PackedVector2Array([center + Vector2(0, 123), center + Vector2(5, 132), center + Vector2(0, 141), center + Vector2(-5, 132)])
	draw_colored_polygon(diamond, silver)
