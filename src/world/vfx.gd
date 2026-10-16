class_name Vfx
extends RefCounted
## 视觉特效工具：漂浮战斗文字、爆发、光环、地面预警等

static func _world_parent() -> Node:
	if Game.zone and is_instance_valid(Game.zone):
		return Game.zone
	if Game.world and is_instance_valid(Game.world):
		return Game.world
	return null

static func float_text(u: Node3D, text: String, col: Color, scl: float = 1.0, crit: bool = false) -> void:
	var parent := _world_parent()
	if parent == null or not is_instance_valid(u):
		return
	if Game.player and is_instance_valid(Game.player) and u.global_position.distance_to(Game.player.global_position) > 70.0:
		return
	var existing:=u.get_tree().get_nodes_in_group("combat_float_labels")
	if existing.size()>=64:
		existing[0].remove_from_group("combat_float_labels")
		existing[0].queue_free()
	var first:=text.left(1)
	var numeric:=first.is_valid_int() or first=="+"
	var lane:int=int(u.get_meta("combat_float_lane",0))%3
	u.set_meta("combat_float_lane",lane+1)
	var l := Label3D.new()
	l.text = text
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.outline_size = 5
	l.font_size = int((28 if numeric else 32) * scl)
	l.pixel_size = 0.0022
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.render_priority = 20
	parent.add_child(l)
	l.add_to_group("combat_float_labels")
	var base: Vector3 = u.head_pos() if u.has_method("head_pos") else u.global_position + Vector3(0, 2, 0)
	var camera:=u.get_viewport().get_camera_3d()
	var right:Vector3=camera.global_basis.x if camera else Vector3.RIGHT
	var side:float=float(lane-1)
	l.global_position = base + right*side*.6 + Vector3.UP*(.18+float(lane)*.22)
	var tw := l.create_tween()
	if crit:
		l.scale = Vector3.ONE * 1.2
		tw.tween_property(l, "scale", Vector3.ONE, 0.10)
	tw.tween_property(l, "global_position", l.global_position + right*side*.4 + Vector3(0, 1.25, 0), .85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tw.tween_callback(l.queue_free)

static func burst(parent: Node, pos: Vector3, col: Color, size: float = 1.0) -> void:
	if parent == null:
		parent = _world_parent()
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = U.sphere_mesh(0.5)
	var m := U.unshaded(Color(col.r, col.g, col.b, 0.8), true).duplicate()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size * 0.3
	var illumination := preload("res://src/render/local_light.gd").attach(mi, Vector3.ZERO, col, clampf(size * 3.0, 3.0, 8.0), 2.2)
	# Keep radius fixed while the visual sphere expands; local light inherits cleanup.
	illumination.set_as_top_level(true)
	illumination.global_position = pos
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size * 1.4, 0.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.parallel().tween_property(illumination, "envelope", 0.0, 0.3)
	tw.tween_callback(mi.queue_free)
	_sparks(parent, pos, col, int(10 * size))

static func _sparks(parent: Node, pos: Vector3, col: Color, n: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = maxi(4, n)
	p.lifetime = 0.6
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.12)
	var mat := U.unshaded(Color(col.r, col.g, col.b, 1.0), true).duplicate()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	qm.material = mat
	p.mesh = qm
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	parent.add_child(p)
	p.global_position = pos
	var cleanup := p.create_tween()
	cleanup.tween_interval(1.2)
	cleanup.tween_callback(p.queue_free)

static func hit_spark(parent: Node, pos: Vector3, col: Color, strength: float = 1.0) -> void:
	var spark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.4) * strength
	var mat := U.unshaded(Color(col, 0.9), true).duplicate()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark.mesh = quad
	spark.material_override = mat
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(spark)
	spark.global_position = pos
	var tw := spark.create_tween()
	tw.tween_property(spark, "scale", Vector3(0.2, 1.4, 1), 0.09)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.09)
	tw.tween_callback(spark.queue_free)

static func ring(parent: Node, pos: Vector3, col: Color, radius: float, dur: float = 0.5, height: float = 0.1) -> void:
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = U.torus_mesh(0.85, 1.0, 32)
	var m := U.unshaded(Color(col.r, col.g, col.b, 0.85), true).duplicate()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, height, 0)
	mi.scale = Vector3(0.2, 0.3, 0.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 0.4, radius), dur).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur)
	tw.tween_callback(mi.queue_free)

static func column(parent: Node, pos: Vector3, col: Color, h: float = 3.0, dur: float = 1.0) -> void:
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = U.cyl_mesh(0.6, 0.8, h, 16)
	var m := U.unshaded(Color(col.r, col.g, col.b, 0.45), true).duplicate()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, h * 0.5, 0)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.3, 1.0, 1.3), dur)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur)
	tw.tween_callback(mi.queue_free)

static func spell_vfx(kind: String, caster: Node3D, tgt: Node3D) -> void:
	var parent := _world_parent()
	if parent == null:
		return
	match kind:
		"nova":
			ring(parent, caster.global_position, Color("a0b8ff"), 8.0, 0.45)
			_sparks(parent, caster.global_position + Vector3(0, 0.3, 0), Color("c0d0ff"), 20)
		"frostnova":
			ring(parent, caster.global_position, Color("c0f0ff"), 10.0, 0.5)
			ring(parent, caster.global_position, Color("ffffff"), 9.0, 0.7, 0.3)
			_sparks(parent, caster.global_position + Vector3(0, 0.3, 0), Color("e0ffff"), 30)
		"arcanenova":
			ring(parent, caster.global_position, Color("e0a0ff"), 10.0, 0.5, 0.8)
			burst(parent, caster.global_position + Vector3(0, 1, 0), Color("e0a0ff"), 2.5)
		"shadownova":
			ring(parent, caster.global_position, Color("8040c0"), 9.0, 0.6, 0.5)
			burst(parent, caster.global_position + Vector3(0, 1, 0), Color("6020a0"), 2.0)
		"shout":
			ring(parent, caster.global_position, Color("ffd080"), 10.0, 0.5, 1.5)
		"heal":
			if tgt and is_instance_valid(tgt):
				column(parent, tgt.global_position, Color("fff0a0"), 2.6, 0.8)
				_sparks(parent, tgt.global_position + Vector3(0, 1.0, 0), Color("ffffa0"), 16)
		"holyhit":
			if tgt and is_instance_valid(tgt):
				column(parent, tgt.global_position, Color("ffe080"), 4.0, 0.5)
				burst(parent, tgt.chest_pos(), Color("fff0a0"), 1.2)
		"shadowhit":
			if tgt and is_instance_valid(tgt):
				burst(parent, tgt.chest_pos(), Color("9040ff"), 1.4)
		"burst":
			if tgt and is_instance_valid(tgt):
				burst(parent, tgt.chest_pos(), Color("ff6020"), 1.4)
		"slash":
			if caster and is_instance_valid(caster):
				burst(parent, caster.global_position + Vector3(0, 1, 0) + (caster as Node3D).global_transform.basis.z * -2.0, Color("ffffff"), 1.6)

static func level_up(u: Node3D) -> void:
	var parent := _world_parent()
	if parent == null:
		return
	column(parent, u.global_position, Color("ffe060"), 5.0, 1.6)
	ring(parent, u.global_position, Color("ffe060"), 4.0, 1.0)
	_sparks(parent, u.global_position + Vector3(0, 1.5, 0), Color("fff0a0"), 40)

static func trail(u: Node3D, dur: float) -> void:
	if not is_instance_valid(u):
		return
	var trail_node := CPUParticles3D.new()
	trail_node.amount = 8
	trail_node.lifetime = 0.2
	trail_node.local_coords = false
	trail_node.position = Vector3(0, 0.5, 0)
	trail_node.initial_velocity_min = 0.0
	trail_node.initial_velocity_max = 0.2
	trail_node.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var mat := U.unshaded(Color(0.7, 0.8, 0.9, 0.4), true)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	trail_node.mesh = quad
	u.add_child(trail_node)
	var tw := trail_node.create_tween()
	tw.tween_interval(dur)
	tw.tween_property(trail_node, "emitting", false, 0.0)
	tw.tween_interval(0.25)
	tw.tween_callback(trail_node.queue_free)

## 地面预警圈：逐渐填满，结束时消失
static func telegraph(parent: Node, pos: Vector3, radius: float, dur: float, follow: Node3D = null) -> Node3D:
	if parent == null:
		return null
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos + Vector3(0, 0.15, 0)
	var outer := MeshInstance3D.new()
	outer.mesh = U.cyl_mesh(1.0, 1.0, 0.04, 40)
	var om := U.unshaded(Color(1.0, 0.2, 0.15, 0.25), true).duplicate()
	outer.material_override = om
	outer.scale = Vector3(radius, 1, radius)
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(outer)
	var edge := MeshInstance3D.new()
	edge.mesh = U.torus_mesh(0.95, 1.0, 48)
	edge.material_override = U.unshaded(Color(1.0, 0.3, 0.2, 0.9), true)
	edge.scale = Vector3(radius, 0.3, radius)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(edge)
	var inner := MeshInstance3D.new()
	inner.mesh = U.cyl_mesh(1.0, 1.0, 0.05, 40)
	inner.material_override = U.unshaded(Color(1.0, 0.35, 0.2, 0.35), true)
	inner.scale = Vector3(0.01, 1, 0.01)
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inner)
	var tw := root.create_tween()
	tw.tween_property(inner, "scale", Vector3(radius, 1, radius), dur)
	tw.tween_callback(root.queue_free)
	if follow != null:
		var upd := func():
			if is_instance_valid(follow) and is_instance_valid(root):
				root.global_position = follow.global_position + Vector3(0, 0.15, 0)
		tw.parallel().tween_method(func(_k): upd.call(), 0.0, 1.0, dur)
	return root

static func ground_aoe(parent: Node, pos: Vector3, radius: float, delay: float, src: Node, dmg: float, school: String, sname: String, mechanic: bool = false) -> void:
	telegraph(parent, pos, radius, delay)
	var tm := parent.get_tree().create_timer(delay)
	tm.timeout.connect(func():
		if not is_instance_valid(parent):
			return
		burst(parent, pos + Vector3(0, 0.5, 0), Color("ff7030"), radius * 0.8)
		Sfx.play_at("fire", pos)
		if src == null or not is_instance_valid(src):
			return
		for u in parent.get_tree().get_nodes_in_group("units"):
			if u.dead or not src.is_enemy(u):
				continue
			if U.flat_dist(u.global_position, pos) <= radius + u.radius and absf(u.global_position.y - pos.y) <= 3.0:
				u.take_damage(dmg, school, src, false, sname, false, 0.0, mechanic))
