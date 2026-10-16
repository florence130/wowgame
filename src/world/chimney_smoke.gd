class_name ChimneySmoke
extends Node3D
## 烟囱炊烟：一小束缓慢上升、渐渐变淡的灰白烟团（CPUParticles3D，视距外自动停发）。放在烟囱口上方，节点位置即出烟口。
@export var strength := 1.0
var _p: CPUParticles3D

func _ready() -> void:
	_p = CPUParticles3D.new()
	_p.amount = int(10 * strength)
	_p.lifetime = 7.0
	_p.preprocess = 7.0
	_p.local_coords = false
	_p.direction = Vector3(0.25, 1.0, 0.1)
	_p.spread = 9.0
	_p.initial_velocity_min = 0.55
	_p.initial_velocity_max = 0.9
	_p.gravity = Vector3(0.18, 0.12, 0.0)          # 一点风
	_p.damping_min = 0.05
	_p.damping_max = 0.1
	_p.scale_amount_min = 0.7
	_p.scale_amount_max = 1.1
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(1.0, 2.6))
	_p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(0.93, 0.92, 0.9, 0.0))
	g.set_color(1, Color(0.85, 0.86, 0.9, 0.0))
	g.add_point(0.12, Color(0.94, 0.93, 0.9, 0.55))
	g.add_point(0.6, Color(0.88, 0.88, 0.9, 0.3))
	_p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	_p.mesh = q
	_p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_p.visibility_range_end = 150.0
	_p.visibility_range_end_margin = 20.0
	add_child(_p)

static var _tex: Texture2D
static func _puff() -> Texture2D:
	if _tex == null:
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = gr
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_tex = t
	return _tex
