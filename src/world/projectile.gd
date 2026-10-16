class_name Projectile
extends Node3D
## 追踪型投射物（火球、寒冰箭、子弹、箭矢等）

var target: Node3D
var speed := 25.0
var on_hit: Callable
var life := 6.0
var color := Color.WHITE
var kind := "orb"
var show_impact := true

static func spawn(parent: Node, from: Vector3, tgt: Node3D, spd: float, col: Color, size: float, k: String, cb: Callable, impact_effect: bool = true) -> Projectile:
	if parent == null or not is_instance_valid(tgt):
		cb.call()
		return null
	var p := Projectile.new()
	p.target = tgt
	p.speed = spd
	p.on_hit = cb
	p.color = col
	p.kind = k
	p.show_impact = impact_effect
	parent.add_child(p)
	p.global_position = from
	match k:
		"bullet":
			U.add_mesh(p, U.capsule_mesh(size * 0.5, size * 4.0), U.unshaded(col), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
		"arrow", "spear":
			U.add_mesh(p, U.cyl_mesh(0.02, 0.02, 0.9 if k == "spear" else 0.6), U.char_mat(Color("8a6a40"), false), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
			U.add_mesh(p, U.cyl_mesh(0.0, 0.04, 0.12), U.char_mat(Color("c0c0c0"), false), Vector3(0, 0, -0.4 if k == "spear" else -0.3), Vector3(-90, 0, 0), Vector3.ONE, false)
		_:
			U.add_mesh(p, U.sphere_mesh(size), U.unshaded(col.lightened(0.4)), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			U.add_mesh(p, U.sphere_mesh(size * 1.7), U.unshaded(Color(col.r, col.g, col.b, 0.35), true), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			var trail := CPUParticles3D.new()
			trail.amount = 24
			trail.lifetime = 0.35
			trail.local_coords = false
			trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			trail.emission_sphere_radius = size * 0.6
			trail.gravity = Vector3.ZERO
			trail.initial_velocity_min = 0.2
			trail.initial_velocity_max = 0.6
			trail.scale_amount_min = 0.5
			trail.scale_amount_max = 1.0
			var qm := QuadMesh.new()
			qm.size = Vector2(size, size)
			var mat := U.unshaded(Color(col.r, col.g, col.b, 0.7), true).duplicate()
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			qm.material = mat
			trail.mesh = qm
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 1))
			g.set_color(1, Color(1, 1, 1, 0))
			trail.color_ramp = g
			p.add_child(trail)
	# The moving spell illuminates the world instead of only drawing an unlit orb.
	if k not in ["arrow", "spear", "bullet"]:
		preload("res://src/render/local_light.gd").attach(p, Vector3.ZERO, col, 6.5, 2.4)
	return p

func _physics_process(delta: float) -> void:
	life -= delta
	if not is_instance_valid(target) or life <= 0.0:
		queue_free()
		return
	var tp: Vector3 = target.chest_pos() if target.has_method("chest_pos") else target.global_position
	var d := tp - global_position
	var step := speed * delta
	if d.length() <= step + 0.3:
		global_position = tp
		if on_hit.is_valid():
			on_hit.call()
		if show_impact:
			Vfx.burst(get_parent(), tp, color, 0.7 if kind == "orb" else 0.35)
		queue_free()
		return
	if absf(d.normalized().dot(Vector3.UP)) < 0.98:
		look_at(tp, Vector3.UP)
	global_position += d.normalized() * step
