extends "res://tests/ui_preview.gd"
## Fixed 24 fps native MovieMaker evidence, no screenshot stalls in the animation.
var frame := 0
var begun := false

func _process(_delta: float) -> void:
	if not is_instance_valid(front):
		return
	frame += 1
	var width: float = front.ui.size.x
	var height: float = front.ui.size.y
	if frame <= 80:
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(width*(0.5+0.48*sin(frame/22.0)),height*(0.5+0.4*cos(frame/26.0)))
		motion.global_position = motion.position
		get_viewport().push_input(motion,true)
	if frame == 85:
		_click(front.ui.get_node("TitleMenu").get_child(1))
	if frame == 120:
		_key(KEY_ESCAPE)
	if frame == 140:
		_click(front.ui.get_node("TitleMenu").get_child(0))
	if frame == 220:
		for button in front.ui.find_children("*","Button",true,false):
			if button.text == "返回开始界面":
				_click(button)
				break
	if frame == 250:
		_click(front.ui.get_node("TitleMenu").get_child(0))
	if frame >= 290:
		print("UI MOTION DONE frames=",frame," native fixed-fps=24")
		get_tree().quit()

func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event,true)

func _key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_viewport().push_input(event,true)
