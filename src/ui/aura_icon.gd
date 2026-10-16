class_name AuraIcon
extends IconView
## 光环图标：显示剩余时间，右键取消增益

var aura: Dictionary = {}
var debuff := false
var unit: Unit

func _init() -> void:
	super._init()
	tooltip_text = " "
	corner = 6

func _make_custom_tooltip(_t: String) -> Object:
	return Tips.aura(aura)

func _draw() -> void:
	quality = -1
	super._draw()
	if debuff:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.2, 0.2, 0.9), false, 2.0)
	var d: Dictionary = aura.get("def", {})
	if d.get("dur", 0.0) > 0.0:
		var t := U.time_text(aura.get("rem", 0.0))
		var f := UITheme.get_font(true)
		var fs := 12
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, Vector2((size.x - w) * 0.5, size.y + 12), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 1))
		draw_string(f, Vector2((size.x - w) * 0.5, size.y + 12), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe080"))

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		if unit and unit.is_player and not debuff:
			unit.remove_aura(aura["def"].get("id", ""))
