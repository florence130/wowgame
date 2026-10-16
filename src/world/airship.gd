class_name Airship
extends Node3D
## 城市上空的飞艇（tools/blender/city_kit/airship_build.py → assets/models/city_lm/airship.glb，沿 +X、船头 -X）。
## moored：停在泊台上，缓慢上下浮动 / 微摇；否则绕 center 为圆心、radius 为半径的水平圆航线巡航，船头朝前进方向。
## 纯装饰：没有碰撞，不参与寻路；位置全由 _process 推算，不依赖物理。
const MODEL := "res://assets/models/city_lm/airship.glb"

@export var center := Vector3.ZERO
@export var radius := 0.0
@export var speed := 5.0
@export var phase := 0.0
@export var moored := false
@export var length := 60.0
var _t := 0.0
var _base_y := 0.0

func _ready() -> void:
	var m := CityKit.load_glb(MODEL)
	if m != null:
		m.scale = Vector3.ONE * (length / 60.0)
		add_child(m)
	_base_y = center.y
	_t = phase * 7.0
	_place(0.0)

func _process(delta: float) -> void:
	_t += delta
	_place(delta)

func _place(_delta: float) -> void:
	if moored or radius <= 1.0:
		position = Vector3(center.x, _base_y + sin(_t * 0.55) * 0.7, center.z)
		rotation = Vector3(sin(_t * 0.4) * 0.02, rotation.y, sin(_t * 0.33) * 0.025)
		return
	var a := phase + _t * speed / radius
	position = center + Vector3(cos(a) * radius, sin(_t * 0.25 + phase * 3.0) * 2.5, sin(a) * radius)
	rotation = Vector3(0.0, PI * 0.5 - a, sin(_t * 0.3) * 0.03)
