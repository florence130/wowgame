extends Node3D
## Sea-temple window lighting. A separate finite budget keeps high window keys
## from being displaced by ground lamps. No effect in other zones.
var tick := 0.0

static func ambient_factor(p: Vector3) -> float:
	if p.y < 23.0 and p.x > 58.0 and p.x < 126.0 and p.z > 80.0 and p.z < 164.0:
		return .68
	if p.y > 23.0 and p.y < 55.0 and p.x > 72.0 and p.x < 146.0 and p.z > 29.0 and p.z < 140.0:
		return .70
	return 1.0

func _ready() -> void:
	add_to_group("sanctum_window_rig")
	for light in get_children():light.visible=false

func _process(delta: float) -> void:
	tick+=delta
	if tick<.2:return
	tick=0.0
	var camera := get_viewport().get_camera_3d()
	if camera:select_lights(camera.global_position)

func select_lights(p: Vector3) -> void:
	var lights := get_children()
	lights.sort_custom(func(a,b):return a.global_position.distance_squared_to(p)<b.global_position.distance_squared_to(p))
	var shadows := bool(Game.settings.get("shadows",true))
	for i in lights.size():
		var light := lights[i] as SpotLight3D
		var distance := light.global_position.distance_to(p)
		light.visible=i<6 and distance<62.0 and p.y>23.0
		light.shadow_enabled=light.visible and i<3 and distance<45.0 and shadows
