class_name CreatureModel
extends Node3D
## 程序化生物模型（四足/双足/蜘蛛/史莱姆/螃蟹等），朝向 -Z。

var kind := "wolf"
var c1 := Color.GRAY
var c2 := Color.WHITE
var metal := false
var rig := "quad"
var body: Node3D
var torso: Node3D
var head: Node3D
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var arms: Array[Node3D] = []
var elbows: Array[Node3D] = []
var tail: Node3D
var wings: Array[Node3D] = []
var t := 0.0
var phase := 0.0
var attack_t := -1.0
var hit_t := -1.0
var dead_t := -1.0
var cast_release_t := -1.0
var _h := 1.0
var _dt := 0.016
var weapon_type := ""
var combat_ready := false

func setup(k: String, col1: Color, col2: Color, is_metal: bool = false, weapon: String = "") -> void:
	kind = k
	c1 = col1
	c2 = col2
	metal = is_metal
	weapon_type = weapon
	_build()

func _m(c: Color) -> Material:
	return U.char_mat(c)

func _build() -> void:
	for c in get_children():
		c.queue_free()
	legs.clear()
	knees.clear()
	arms.clear()
	elbows.clear()
	wings.clear()
	body = Node3D.new()
	add_child(body)
	match kind:
		"wolf", "hound": _build_quad(Vector3(0.36, 0.34, 0.95), 0.55, "wolf")
		"boar": _build_quad(Vector3(0.5, 0.45, 0.9), 0.4, "boar")
		"bear": _build_quad(Vector3(0.75, 0.7, 1.35), 0.6, "bear")
		"deer": _build_quad(Vector3(0.32, 0.36, 0.85), 0.75, "deer")
		"horse": _build_quad(Vector3(0.45, 0.5, 1.3), 0.85, "horse")
		"sheep": _build_quad(Vector3(0.45, 0.42, 0.6), 0.3, "sheep")
		"rabbit": _build_rabbit()
		"spider": _build_spider()
		"crab": _build_crab()
		"slime": _build_slime()
		"mech": _build_mech()
		"ratman": _build_biped(0.85, "rat")
		"frogman": _build_biped(0.95, "frog")
		"hyena": _build_biped(1.15, "hyena")
		"golem": _build_biped(1.25, "golem")
		"scarecrow": _build_biped(1.05, "scarecrow")
		"harpy": _build_biped(1.0, "harpy")
		"treant": _build_biped(1.3, "treant")
		"gargoyle": _build_biped(1.1, "gargoyle")
		_: _build_quad(Vector3(0.4, 0.4, 0.9), 0.5, "wolf")
	U.merge_levels(body)

# ---------------------------------------------------------------- 四足
func _build_quad(size: Vector3, leg_h: float, style: String) -> void:
	rig = "quad"
	_h = leg_h + size.y
	torso = Node3D.new()
	torso.position = Vector3(0, leg_h + size.y * 0.45, 0)
	body.add_child(torso)
	var m1 := _m(c1)
	var m2 := _m(c2)
	match style:
		"sheep":
			U.add_mesh(torso, U.sphere_mesh(size.x * 0.75), _m(Color("f8f8f0")), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.95, 1.35))
		"boar":
			U.add_mesh(torso, U.sphere_mesh(size.x * 0.6), m1, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.0, 1.7))
			U.add_mesh(torso, U.box_mesh(Vector3(0.06, 0.18, size.z * 0.7)), _m(c1.darkened(0.4)), Vector3(0, size.y * 0.5, 0))
		_:
			U.add_mesh(torso, U.capsule_mesh(size.x * 0.5, size.z), m1, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, size.y / size.x, 1))
			if style in ["wolf", "bear"]:
				U.add_mesh(torso, U.sphere_mesh(size.x * 0.55), m1, Vector3(0, size.y * 0.1, -size.z * 0.3), Vector3.ZERO, Vector3(1.05, 1.1, 1.0))
	if style == "wolf" or style == "deer" or style == "horse":
		U.add_mesh(torso, U.capsule_mesh(size.x * 0.32, size.z * 0.55), m2, Vector3(0, -size.y * 0.22, -size.z * 0.05), Vector3(90, 0, 0))
	head = Node3D.new()
	var hd := Vector3(0, size.y * 0.35, -size.z * 0.5)
	if style == "horse" or style == "deer":
		hd = Vector3(0, size.y * 0.9, -size.z * 0.55)
	head.position = hd
	torso.add_child(head)
	match style:
		"wolf":
			U.add_mesh(head, U.sphere_mesh(0.17), m1, Vector3(0, 0.02, -0.08), Vector3.ZERO, Vector3(1, 0.9, 1.1))
			U.add_mesh(head, U.box_mesh(Vector3(0.12, 0.1, 0.2)), m2, Vector3(0, -0.03, -0.25))
			U.add_mesh(head, U.sphere_mesh(0.03), _m(Color("1a1a1a")), Vector3(0, 0.0, -0.36))
			for s in [-1, 1]:
				U.add_mesh(head, U.cyl_mesh(0.0, 0.06, 0.13, 6), m1, Vector3(s * 0.08, 0.17, -0.02), Vector3(-10, 0, s * -15))
				U.add_mesh(head, U.sphere_mesh(0.022), U.unshaded(Color("ffd040")), Vector3(s * 0.07, 0.05, -0.2))
		"boar":
			U.add_mesh(head, U.sphere_mesh(0.22), m1, Vector3(0, -0.02, -0.1), Vector3.ZERO, Vector3(1, 0.9, 1.2))
			U.add_mesh(head, U.cyl_mesh(0.09, 0.1, 0.12), _m(c1.lightened(0.3)), Vector3(0, -0.06, -0.33), Vector3(90, 0, 0))
			for s in [-1, 1]:
				U.add_mesh(head, U.cyl_mesh(0.0, 0.03, 0.18, 6), m2, Vector3(s * 0.1, -0.04, -0.3), Vector3(-60, 0, s * 25))
				U.add_mesh(head, U.sphere_mesh(0.02), U.unshaded(Color("1a1a1a")), Vector3(s * 0.09, 0.06, -0.24))
				U.add_mesh(head, U.cyl_mesh(0.0, 0.06, 0.1, 6), m1, Vector3(s * 0.13, 0.17, -0.05), Vector3(0, 0, s * -30))
		"bear":
			U.add_mesh(head, U.sphere_mesh(0.26), m1, Vector3(0, 0.05, -0.12))
			U.add_mesh(head, U.sphere_mesh(0.13), _m(c1.lightened(0.25)), Vector3(0, -0.04, -0.33), Vector3.ZERO, Vector3(1, 0.8, 1))
			U.add_mesh(head, U.sphere_mesh(0.04), _m(Color("1a1a1a")), Vector3(0, 0.0, -0.45))
			for s in [-1, 1]:
				U.add_mesh(head, U.sphere_mesh(0.08), m1, Vector3(s * 0.18, 0.25, -0.05))
				U.add_mesh(head, U.sphere_mesh(0.025), U.unshaded(Color("1a1a1a")), Vector3(s * 0.11, 0.1, -0.33))
		"deer", "horse":
			var big := style == "horse"
			U.add_mesh(head, U.capsule_mesh(0.1 if not big else 0.13, 0.5 if not big else 0.7), m1, Vector3(0, -0.15, 0.1), Vector3(-35, 0, 0))
			U.add_mesh(head, U.capsule_mesh(0.09 if not big else 0.12, 0.32 if not big else 0.45), m1, Vector3(0, 0.12, -0.12), Vector3(70, 0, 0))
			for s in [-1, 1]:
				U.add_mesh(head, U.sphere_mesh(0.025), U.unshaded(Color("1a1a1a")), Vector3(s * 0.08, 0.16, -0.12))
				U.add_mesh(head, U.cyl_mesh(0.0, 0.04, 0.12, 6), m1, Vector3(s * 0.07, 0.3, 0.0), Vector3(0, 0, s * -20))
				if not big:
					U.add_mesh(head, U.cyl_mesh(0.01, 0.015, 0.28), _m(Color("e0d0b0")), Vector3(s * 0.08, 0.36, 0.02), Vector3(-20, 0, s * -25))
			if big:
				U.add_mesh(head, U.box_mesh(Vector3(0.05, 0.45, 0.2)), _m(c2), Vector3(0, 0.0, 0.2), Vector3(-35, 0, 0))
		"sheep":
			U.add_mesh(head, U.sphere_mesh(0.13), _m(Color("3a3a3a")), Vector3(0, 0.05, -0.08), Vector3.ZERO, Vector3(0.9, 1, 1.2))
			for s in [-1, 1]:
				U.add_mesh(head, U.sphere_mesh(0.022), U.unshaded(Color.WHITE), Vector3(s * 0.06, 0.08, -0.2))
				U.add_mesh(head, U.capsule_mesh(0.03, 0.12), _m(Color("3a3a3a")), Vector3(s * 0.12, 0.05, -0.05), Vector3(0, 0, s * 70))
	# 腿
	var lx := size.x * 0.38
	var lz := size.z * 0.36
	var lr := 0.05 + size.x * 0.08
	var leg_c := c1.darkened(0.15)
	if style == "sheep":
		leg_c = Color("3a3a3a")
	for i in 4:
		var front := i < 2
		var sx := -1 if i % 2 == 0 else 1
		var hip := Node3D.new()
		hip.position = Vector3(sx * lx, leg_h + 0.05, -lz if front else lz)
		body.add_child(hip)
		U.add_mesh(hip, U.capsule_mesh(lr, leg_h * 0.6), _m(leg_c), Vector3(0, -leg_h * 0.25, 0))
		var knee := Node3D.new()
		knee.position = Vector3(0, -leg_h * 0.5, 0)
		hip.add_child(knee)
		U.add_mesh(knee, U.capsule_mesh(lr * 0.8, leg_h * 0.6), _m(leg_c), Vector3(0, -leg_h * 0.22, 0))
		U.add_mesh(knee, U.sphere_mesh(lr * 1.1), _m(leg_c.darkened(0.3)), Vector3(0, -leg_h * 0.48, -0.02), Vector3.ZERO, Vector3(1, 0.6, 1.2))
		legs.append(hip)
		knees.append(knee)
	# 尾巴
	tail = Node3D.new()
	tail.position = Vector3(0, size.y * 0.2, size.z * 0.5)
	torso.add_child(tail)
	match style:
		"wolf":
			U.add_mesh(tail, U.capsule_mesh(0.07, 0.45), m1, Vector3(0, -0.05, 0.2), Vector3(60, 0, 0))
			U.add_mesh(tail, U.sphere_mesh(0.07), m2, Vector3(0, -0.15, 0.4))
		"boar":
			U.add_mesh(tail, U.torus_mesh(0.02, 0.05), m1, Vector3(0, 0, 0.05), Vector3(0, 90, 0))
		"bear", "sheep", "deer":
			U.add_mesh(tail, U.sphere_mesh(0.07), m2 if style != "sheep" else _m(Color("f8f8f0")), Vector3(0, 0, 0.03))
		"horse":
			U.add_mesh(tail, U.capsule_mesh(0.07, 0.6), _m(c2), Vector3(0, -0.2, 0.15), Vector3(25, 0, 0))

func _build_rabbit() -> void:
	rig = "hop"
	_h = 0.35
	torso = Node3D.new()
	torso.position = Vector3(0, 0.15, 0)
	body.add_child(torso)
	U.add_mesh(torso, U.sphere_mesh(0.14), _m(c1), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1.25))
	head = Node3D.new()
	head.position = Vector3(0, 0.1, -0.14)
	torso.add_child(head)
	U.add_mesh(head, U.sphere_mesh(0.09), _m(c1))
	for s in [-1, 1]:
		U.add_mesh(head, U.capsule_mesh(0.025, 0.18), _m(c1), Vector3(s * 0.04, 0.13, 0.02), Vector3(-15, 0, s * -10))
		U.add_mesh(head, U.sphere_mesh(0.015), U.unshaded(Color("1a1a1a")), Vector3(s * 0.05, 0.02, -0.07))
	U.add_mesh(torso, U.sphere_mesh(0.05), _m(Color.WHITE), Vector3(0, 0.02, 0.17))
	U.add_mesh(torso, U.sphere_mesh(0.05), _m(c1.darkened(0.1)), Vector3(-0.07, -0.1, 0.06), Vector3.ZERO, Vector3(1, 0.6, 1.6))
	U.add_mesh(torso, U.sphere_mesh(0.05), _m(c1.darkened(0.1)), Vector3(0.07, -0.1, 0.06), Vector3.ZERO, Vector3(1, 0.6, 1.6))

# ---------------------------------------------------------------- 蜘蛛
func _build_spider() -> void:
	rig = "spider"
	_h = 0.7
	torso = Node3D.new()
	torso.position = Vector3(0, 0.45, 0)
	body.add_child(torso)
	var m1 := _m(c1)
	U.add_mesh(torso, U.sphere_mesh(0.32), m1, Vector3(0, 0.08, 0.3), Vector3.ZERO, Vector3(1, 0.85, 1.15))
	U.add_mesh(torso, U.sphere_mesh(0.12), _m(c2), Vector3(0, 0.3, 0.38), Vector3.ZERO, Vector3(1, 0.5, 1.4))
	U.add_mesh(torso, U.sphere_mesh(0.2), m1, Vector3(0, 0, -0.15))
	head = Node3D.new()
	head.position = Vector3(0, 0, -0.32)
	torso.add_child(head)
	for i in 4:
		var ex := (i - 1.5) * 0.05
		U.add_mesh(head, U.sphere_mesh(0.025), U.unshaded(c2 if not metal else Color("ff3030")), Vector3(ex, 0.06, -0.02))
	for s in [-1, 1]:
		U.add_mesh(head, U.cyl_mesh(0.0, 0.03, 0.12, 6), _m(c1.darkened(0.3)), Vector3(s * 0.05, -0.06, -0.06), Vector3(-160, 0, 0))
	if metal:
		U.add_mesh(torso, U.cyl_mesh(0.06, 0.06, 0.3), _m(Color("b0a080")), Vector3(0, 0.3, 0.2), Vector3(0, 0, 0))
		U.add_mesh(torso, U.sphere_mesh(0.07), U.unshaded(c2), Vector3(0, 0.12, 0.5))
	for i in 8:
		var side := -1 if i < 4 else 1
		var k := i % 4
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.15, 0.0, -0.12 + k * 0.1)
		hip.rotation = Vector3(0, side * (-0.9 + k * 0.55) + (PI if side > 0 else 0.0), 0)
		torso.add_child(hip)
		var seg := Node3D.new()
		seg.rotation = Vector3(0, 0, 0.7)
		hip.add_child(seg)
		U.add_mesh(seg, U.capsule_mesh(0.03, 0.42), _m(c1.darkened(0.2)), Vector3(-0.19, 0, 0), Vector3(0, 0, 90))
		var knee := Node3D.new()
		knee.position = Vector3(-0.38, 0, 0)
		knee.rotation = Vector3(0, 0, -1.9)
		seg.add_child(knee)
		U.add_mesh(knee, U.capsule_mesh(0.025, 0.55), _m(c1.darkened(0.3)), Vector3(-0.26, 0, 0), Vector3(0, 0, 90))
		legs.append(hip)
		knees.append(knee)

# ---------------------------------------------------------------- 螃蟹
func _build_crab() -> void:
	rig = "crab"
	_h = 0.6
	torso = Node3D.new()
	torso.position = Vector3(0, 0.35, 0)
	body.add_child(torso)
	U.add_mesh(torso, U.sphere_mesh(0.38), _m(c1), Vector3.ZERO, Vector3.ZERO, Vector3(1.3, 0.55, 1.0))
	head = Node3D.new()
	head.position = Vector3(0, 0.12, -0.32)
	torso.add_child(head)
	for s in [-1, 1]:
		U.add_mesh(head, U.cyl_mesh(0.015, 0.015, 0.14), _m(c1), Vector3(s * 0.08, 0.05, 0))
		U.add_mesh(head, U.sphere_mesh(0.035), U.unshaded(Color("1a1a1a")), Vector3(s * 0.08, 0.13, 0))
	for s in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(s * 0.35, 0.0, -0.25)
		torso.add_child(arm)
		U.add_mesh(arm, U.capsule_mesh(0.05, 0.3), _m(c1), Vector3(s * 0.08, 0, -0.1), Vector3(70, s * 30, 0))
		var claw := Node3D.new()
		claw.position = Vector3(s * 0.15, 0.05, -0.3)
		arm.add_child(claw)
		U.add_mesh(claw, U.sphere_mesh(0.13), _m(c1.lightened(0.1)), Vector3.ZERO, Vector3.ZERO, Vector3(0.8, 0.7, 1.4))
		U.add_mesh(claw, U.cyl_mesh(0.0, 0.05, 0.18, 6), _m(c2), Vector3(0, 0.04, -0.2), Vector3(-90, 0, 0))
		arms.append(arm)
		elbows.append(claw)
	for i in 6:
		var side := -1 if i < 3 else 1
		var k := i % 3
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.4, -0.05, -0.05 + k * 0.15)
		torso.add_child(hip)
		U.add_mesh(hip, U.capsule_mesh(0.03, 0.4), _m(c1.darkened(0.15)), Vector3(side * 0.15, -0.12, 0), Vector3(0, 0, side * 55))
		legs.append(hip)

# ---------------------------------------------------------------- 史莱姆
func _build_slime() -> void:
	rig = "blob"
	_h = 0.8
	torso = Node3D.new()
	body.add_child(torso)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(c1.r, c1.g, c1.b, 0.85)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mm.rim_enabled = true
	mm.rim = 0.6
	U.add_mesh(torso, U.sphere_mesh(0.45), mm, Vector3(0, 0.38, 0), Vector3.ZERO, Vector3(1, 0.85, 1))
	U.add_mesh(torso, U.sphere_mesh(0.12), U.unshaded(Color(1, 1, 1, 0.5)), Vector3(-0.15, 0.6, -0.2))
	head = Node3D.new()
	head.position = Vector3(0, 0.45, -0.38)
	torso.add_child(head)
	for s in [-1, 1]:
		U.add_mesh(head, U.sphere_mesh(1.0), U.unshaded(Color("1a1a2a")), Vector3(s * 0.11, 0.02, 0), Vector3.ZERO, Vector3(0.035, 0.055, 0.02))
	U.add_mesh(head, U.torus_mesh(0.02, 0.035), U.unshaded(Color("1a1a2a")), Vector3(0, -0.07, 0.01), Vector3(90, 0, 0), Vector3(1, 1, 0.4))

func _build_mech() -> void:
	rig = "static"
	_h = 0.9
	torso = Node3D.new()
	torso.position = Vector3(0, 0.45, 0)
	body.add_child(torso)
	U.add_mesh(torso, U.box_mesh(Vector3(0.4, 0.3, 1.2)), _m(Color("c08040")), Vector3(0, 0.05, 0))
	U.add_mesh(torso, U.cyl_mesh(0.18, 0.18, 0.5), _m(Color("e8c27a")), Vector3(0, 0.15, 0.25), Vector3(90, 0, 0))
	for z in [-0.55, 0.55]:
		U.add_mesh(torso, U.cyl_mesh(0.3, 0.3, 0.14, 16), _m(Color("2a2a2a")), Vector3(0, -0.15, z), Vector3(0, 0, 90))
		U.add_mesh(torso, U.cyl_mesh(0.15, 0.15, 0.16, 12), _m(Color("b0b0b0")), Vector3(0, -0.15, z), Vector3(0, 0, 90))
	U.add_mesh(torso, U.cyl_mesh(0.02, 0.02, 0.6), _m(Color("3a3a3a")), Vector3(0, 0.45, -0.45), Vector3(0, 0, 90))
	U.add_mesh(torso, U.sphere_mesh(0.08), U.unshaded(Color("80e0ff")), Vector3(0, 0.15, -0.62))
	head = Node3D.new()
	torso.add_child(head)

# ---------------------------------------------------------------- 双足（兽人类）
func _build_biped(scale_h: float, style: String) -> void:
	rig = "biped"
	_h = 1.6 * scale_h
	body.scale = Vector3.ONE * scale_h
	var skin := c1
	var cloth := c2
	var leg_len := 0.7
	var hips := Node3D.new()
	hips.position = Vector3(0, leg_len, 0)
	body.add_child(hips)
	torso = Node3D.new()
	hips.add_child(torso)
	var tm := _m(cloth if style in ["rat", "hyena", "scarecrow"] else skin)
	match style:
		"golem":
			U.add_mesh(torso, U.box_mesh(Vector3(0.6, 0.55, 0.42)), _m(skin), Vector3(0, 0.3, 0))
			U.add_mesh(torso, U.cyl_mesh(0.12, 0.12, 0.05, 16), U.unshaded(cloth), Vector3(0, 0.33, -0.22), Vector3(90, 0, 0))
			U.add_mesh(torso, U.box_mesh(Vector3(0.4, 0.18, 0.3)), _m(skin.darkened(0.3)), Vector3(0, 0.0, 0))
			for x in [-0.2, 0.2]:
				U.add_mesh(torso, U.cyl_mesh(0.04, 0.04, 0.3), _m(Color("6a6a6a")), Vector3(x, 0.65, 0.12))
		"treant":
			U.add_mesh(torso, U.cyl_mesh(0.22, 0.28, 0.75, 8), _m(skin), Vector3(0, 0.35, 0))
			U.add_mesh(torso, U.sphere_mesh(0.45), _m(cloth), Vector3(0, 0.95, 0.05), Vector3.ZERO, Vector3(1.2, 0.9, 1.1))
			U.add_mesh(torso, U.sphere_mesh(0.28), _m(cloth.darkened(0.15)), Vector3(0.3, 1.05, 0.1))
			U.add_mesh(torso, U.sphere_mesh(0.28), _m(cloth.lightened(0.1)), Vector3(-0.3, 1.0, 0.0))
		"scarecrow":
			U.add_mesh(torso, U.cyl_mesh(0.16, 0.2, 0.5, 8), tm, Vector3(0, 0.25, 0))
			U.add_mesh(torso, U.cyl_mesh(0.03, 0.03, 0.9), _m(Color("6a4a2a")), Vector3(0, 0.42, 0), Vector3(0, 0, 90))
			for i in 5:
				U.add_mesh(torso, U.cyl_mesh(0.0, 0.03, 0.15, 5), _m(skin), Vector3((i - 2) * 0.07, -0.02, -0.1), Vector3(180, 0, 0))
		"harpy":
			U.add_mesh(torso, U.cyl_mesh(0.14, 0.12, 0.42, 10), _m(skin), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
			U.add_mesh(torso, U.sphere_mesh(0.16), _m(cloth), Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1, 0.9, 0.9))
		"gargoyle":
			U.add_mesh(torso, U.cyl_mesh(0.24, 0.18, 0.5, 10), _m(skin), Vector3(0, 0.25, 0), Vector3(10, 0, 0))
		_:
			U.add_mesh(torso, U.cyl_mesh(0.17, 0.15, 0.45, 10), tm, Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
			U.add_mesh(torso, U.sphere_mesh(0.17), tm, Vector3(0, 0.44, 0), Vector3.ZERO, Vector3(1, 0.6, 0.85))
			if style in ["frog"]:
				U.add_mesh(torso, U.sphere_mesh(0.18), _m(c2), Vector3(0, 0.2, -0.04), Vector3.ZERO, Vector3(0.9, 1.1, 0.7))
	head = Node3D.new()
	head.position = Vector3(0, 0.55 if style != "golem" else 0.62, 0)
	torso.add_child(head)
	_build_beast_head(style, skin, cloth)
	# 手臂
	var sw := 0.2 if style != "golem" else 0.38
	var arm_r := 0.05 if style != "golem" else 0.1
	for s in [-1, 1]:
		var sh := Node3D.new()
		sh.position = Vector3(s * sw, 0.45 if style != "golem" else 0.5, 0)
		torso.add_child(sh)
		if style == "harpy":
			var wing := Node3D.new()
			sh.add_child(wing)
			for i in 4:
				U.add_mesh(wing, U.box_mesh(Vector3(0.12, 0.55 - i * 0.08, 0.02)), _m(cloth.lerp(skin, i * 0.2)), Vector3(s * (0.06 + i * 0.1), -0.2 - i * 0.03, 0.05 + i * 0.01), Vector3(0, 0, s * (10 + i * 12)))
			wings.append(wing)
		var acol := skin if style != "scarecrow" else cloth
		if style == "golem":
			U.add_mesh(sh, U.box_mesh(Vector3(0.2, 0.4, 0.2)), _m(skin), Vector3(0, -0.2, 0))
		elif style == "treant":
			U.add_mesh(sh, U.cyl_mesh(0.07, 0.09, 0.45, 6), _m(skin), Vector3(0, -0.2, 0))
		else:
			U.add_mesh(sh, U.capsule_mesh(arm_r, 0.32), _m(acol), Vector3(0, -0.14, 0))
		var el := Node3D.new()
		el.position = Vector3(0, -0.3 if style != "golem" else -0.4, 0)
		sh.add_child(el)
		if style == "golem":
			U.add_mesh(el, U.box_mesh(Vector3(0.24, 0.45, 0.24)), _m(skin.darkened(0.15)), Vector3(0, -0.2, 0))
			U.add_mesh(el, U.sphere_mesh(0.16), _m(Color("6a6a6a")), Vector3(0, -0.45, 0))
		elif style == "treant":
			U.add_mesh(el, U.cyl_mesh(0.05, 0.07, 0.45, 6), _m(skin), Vector3(0, -0.2, 0))
			for k in 3:
				U.add_mesh(el, U.cyl_mesh(0.0, 0.03, 0.18, 5), _m(skin), Vector3((k - 1) * 0.04, -0.48, 0), Vector3(180, 0, (k - 1) * 20))
		else:
			U.add_mesh(el, U.capsule_mesh(arm_r * 0.9, 0.3), _m(skin if style != "scarecrow" else Color("e0c070")), Vector3(0, -0.13, 0))
			U.add_mesh(el, U.sphere_mesh(arm_r * 1.1), _m(skin), Vector3(0, -0.28, 0))
		var hand := Node3D.new()
		hand.name = "Hand"
		hand.position = Vector3(0, -0.28, 0)
		el.add_child(hand)
		arms.append(sh)
		elbows.append(el)
	if weapon_type != "" and elbows.size() > 1:
		var w := WeaponModel.make(weapon_type, Color("a0a0a8"), 1)
		var hr: Node3D = elbows[1].get_node("Hand")
		hr.add_child(w)
		if weapon_type in ["staff", "torch"]:
			w.rotation_degrees = Vector3(0, 0, 0)
		elif weapon_type == "gun":
			w.rotation_degrees = Vector3(180, 0, 0)
		else:
			w.rotation_degrees = Vector3(-90, 0, 0)
	# 腿
	for s in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(s * (0.09 if style != "golem" else 0.17), 0, 0)
		hips.add_child(hip)
		var lc := skin if style in ["frog", "rat", "hyena", "harpy", "gargoyle"] else (cloth.darkened(0.2) if style != "golem" and style != "treant" else skin.darkened(0.1))
		if style == "scarecrow":
			U.add_mesh(hip, U.cyl_mesh(0.025, 0.025, 0.75), _m(Color("6a4a2a")), Vector3(0, -0.35, 0))
		elif style == "golem":
			U.add_mesh(hip, U.box_mesh(Vector3(0.22, 0.4, 0.24)), _m(skin.darkened(0.2)), Vector3(0, -0.18, 0))
		else:
			U.add_mesh(hip, U.capsule_mesh(0.07, 0.4), _m(lc), Vector3(0, -0.17, 0))
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.36, 0)
		hip.add_child(knee)
		if style != "scarecrow":
			if style == "golem":
				U.add_mesh(knee, U.box_mesh(Vector3(0.24, 0.36, 0.26)), _m(skin.darkened(0.3)), Vector3(0, -0.17, 0))
			else:
				U.add_mesh(knee, U.capsule_mesh(0.06, 0.38), _m(lc), Vector3(0, -0.15, 0))
			var foot_c := lc.darkened(0.3)
			if style == "frog":
				foot_c = c2
			U.add_mesh(knee, U.box_mesh(Vector3(0.1, 0.06, 0.2 if style != "frog" else 0.28)), _m(foot_c), Vector3(0, -0.33, -0.05))
		legs.append(hip)
		knees.append(knee)
	if style in ["rat", "hyena", "gargoyle"]:
		tail = Node3D.new()
		tail.position = Vector3(0, 0, 0.12)
		hips.add_child(tail)
		U.add_mesh(tail, U.capsule_mesh(0.025 if style == "rat" else 0.05, 0.6), _m(skin.lightened(0.15) if style == "rat" else skin), Vector3(0, -0.2, 0.2), Vector3(50, 0, 0))
	if style == "gargoyle":
		for s in [-1, 1]:
			var wing2 := Node3D.new()
			wing2.position = Vector3(s * 0.12, 0.4, 0.15)
			torso.add_child(wing2)
			U.add_mesh(wing2, U.prism_mesh(Vector3(0.6, 0.55, 0.03)), _m(skin.darkened(0.2)), Vector3(s * 0.3, 0.15, 0.05), Vector3(0, s * 20, s * -40))
			wings.append(wing2)

func _build_beast_head(style: String, skin: Color, cloth: Color) -> void:
	var sm := _m(skin)
	match style:
		"rat":
			U.add_mesh(head, U.sphere_mesh(0.17), sm, Vector3(0, 0.12, 0))
			U.add_mesh(head, U.cyl_mesh(0.03, 0.11, 0.2, 10), sm, Vector3(0, 0.08, -0.17), Vector3(-90, 0, 0))
			U.add_mesh(head, U.sphere_mesh(0.03), _m(Color("ff9aa8")), Vector3(0, 0.08, -0.28))
			for s in [-1, 1]:
				U.add_mesh(head, U.sphere_mesh(0.09), _m(skin.lightened(0.2)), Vector3(s * 0.14, 0.27, 0.02), Vector3.ZERO, Vector3(1, 1, 0.3))
				U.add_mesh(head, U.sphere_mesh(0.025), U.unshaded(Color("1a1a1a")), Vector3(s * 0.07, 0.17, -0.13))
			# 头顶蜡烛
			U.add_mesh(head, U.cyl_mesh(0.03, 0.03, 0.12), _m(Color("f0e8c0")), Vector3(0.05, 0.33, 0.02))
			U.add_mesh(head, U.sphere_mesh(0.03), U.unshaded(Color("ffc040")), Vector3(0.05, 0.42, 0.02), Vector3.ZERO, Vector3(1, 1.6, 1))
			U.add_mesh(head, U.sphere_mesh(0.18, 0.36, true), _m(cloth.darkened(0.2)), Vector3(0, 0.17, 0.02))
		"frog":
			U.add_mesh(head, U.sphere_mesh(0.22), sm, Vector3(0, 0.12, -0.02), Vector3.ZERO, Vector3(1.15, 0.85, 1.05))
			U.add_mesh(head, U.box_mesh(Vector3(0.28, 0.02, 0.02)), U.unshaded(Color("3a1a1a")), Vector3(0, 0.05, -0.22))
			for s in [-1, 1]:
				U.add_mesh(head, U.sphere_mesh(0.07), _m(Color("f0f0e0")), Vector3(s * 0.11, 0.27, -0.1))
				U.add_mesh(head, U.sphere_mesh(0.035), U.unshaded(Color("1a1a1a")), Vector3(s * 0.11, 0.28, -0.16))
			U.add_mesh(head, U.prism_mesh(Vector3(0.03, 0.2, 0.25)), _m(c2), Vector3(0, 0.3, 0.08), Vector3(0, 90, 0))
		"hyena":
			U.add_mesh(head, U.sphere_mesh(0.18), sm, Vector3(0, 0.12, 0))
			U.add_mesh(head, U.box_mesh(Vector3(0.12, 0.1, 0.22)), _m(skin.darkened(0.3)), Vector3(0, 0.07, -0.2))
			for s in [-1, 1]:
				U.add_mesh(head, U.cyl_mesh(0.0, 0.06, 0.14, 6), sm, Vector3(s * 0.1, 0.3, 0.0), Vector3(0, 0, s * -20))
				U.add_mesh(head, U.sphere_mesh(0.025), U.unshaded(Color("ff5030")), Vector3(s * 0.07, 0.17, -0.14))
			U.add_mesh(head, U.box_mesh(Vector3(0.04, 0.22, 0.3)), _m(cloth), Vector3(0, 0.22, 0.12))
		"golem":
			U.add_mesh(head, U.box_mesh(Vector3(0.28, 0.22, 0.26)), _m(skin.lightened(0.1)), Vector3(0, 0.1, 0))
			U.add_mesh(head, U.box_mesh(Vector3(0.2, 0.05, 0.02)), U.unshaded(cloth), Vector3(0, 0.12, -0.135))
		"treant":
			for s in [-1, 1]:
				U.add_mesh(head, U.sphere_mesh(0.04), U.unshaded(Color("e0ff80")), Vector3(s * 0.08, 0.1, -0.25))
			U.add_mesh(head, U.box_mesh(Vector3(0.12, 0.03, 0.02)), U.unshaded(Color("1a1a0a")), Vector3(0, -0.02, -0.26))
		"scarecrow":
			U.add_mesh(head, U.sphere_mesh(0.17), _m(Color("e8d8a0")), Vector3(0, 0.12, 0))
			U.add_mesh(head, U.cyl_mesh(0.3, 0.3, 0.02, 16), _m(skin), Vector3(0, 0.24, 0))
			U.add_mesh(head, U.cyl_mesh(0.1, 0.14, 0.14, 12), _m(skin), Vector3(0, 0.32, 0))
			for s in [-1, 1]:
				U.add_mesh(head, U.box_mesh(Vector3(0.04, 0.04, 0.02)), U.unshaded(Color("ff8020")), Vector3(s * 0.06, 0.15, -0.16), Vector3(0, 0, 45))
			U.add_mesh(head, U.box_mesh(Vector3(0.12, 0.015, 0.02)), U.unshaded(Color("3a1a0a")), Vector3(0, 0.05, -0.16))
		"harpy":
			U.add_mesh(head, U.sphere_mesh(0.16), _m(Color("f0d0b8")), Vector3(0, 0.12, 0))
			for s in [-1, 1]:
				U.add_mesh(head, U.sphere_mesh(1.0), U.unshaded(Color("c03030")), Vector3(s * 0.06, 0.12, -0.145), Vector3.ZERO, Vector3(0.025, 0.035, 0.01))
			U.add_mesh(head, U.sphere_mesh(0.18, 0.36, true), _m(cloth), Vector3(0, 0.14, 0.02))
			U.add_mesh(head, U.capsule_mesh(0.07, 0.4), _m(cloth), Vector3(0, -0.05, 0.12), Vector3(15, 0, 0))
			for i in 3:
				U.add_mesh(head, U.capsule_mesh(0.025, 0.2), _m(skin), Vector3((i - 1) * 0.06, 0.32, 0.05), Vector3(-30, 0, (i - 1) * 20))
		"gargoyle":
			U.add_mesh(head, U.sphere_mesh(0.17), sm, Vector3(0, 0.1, -0.02), Vector3.ZERO, Vector3(1, 0.9, 1.1))
			for s in [-1, 1]:
				U.add_mesh(head, U.cyl_mesh(0.0, 0.04, 0.2, 6), _m(skin.darkened(0.3)), Vector3(s * 0.1, 0.25, 0.02), Vector3(-30, 0, s * -25))
				U.add_mesh(head, U.sphere_mesh(0.025), U.unshaded(c2), Vector3(s * 0.06, 0.12, -0.17))

func height() -> float:
	return _h * scale.y

# ---------------------------------------------------------------- 动画
func play_attack(_k: int = -1) -> void:
	attack_t = 0.0

func play_hit() -> void:
	hit_t = 0.0

func play_cast_release() -> void:
	cast_release_t = 0.0

func play_emote(_e: String) -> void:
	pass

func set_combat_ready(v: bool) -> void:
	combat_ready = v

func set_ranged_mode(_v: bool) -> void:
	pass

func set_dead(v: bool) -> void:
	if v and dead_t < 0.0:
		dead_t = 0.0
	elif not v:
		dead_t = -1.0
		body.rotation = Vector3.ZERO
		body.position = Vector3.ZERO

func animate(delta: float, st: Dictionary) -> void:
	if body == null:
		return
	_dt = delta
	t += delta
	var spd: float = absf(st.get("speed", 0.0)) + absf(st.get("strafe", 0.0))
	var moving := spd > 0.3
	var run := clampf(spd / 7.0, 0.0, 1.2)
	if moving:
		phase += delta * (5.0 + 7.0 * run)
	var s := clampf(16.0 * delta, 0.0, 1.0)
	if dead_t >= 0.0:
		dead_t += delta
		var k := clampf(dead_t / 0.5, 0.0, 1.0)
		if rig == "biped":
			body.rotation.x = lerpf(0.0, PI * 0.5, k * k)
			body.position.y = 0.12 * k
		elif rig == "blob":
			body.scale = Vector3(1.0 + k * 0.4, 1.0 - k * 0.7, 1.0 + k * 0.4)
		else:
			body.rotation.z = lerpf(0.0, PI * 0.5, k * k)
			body.position.y = 0.05 * k
		return
	var atk := 0.0
	if attack_t >= 0.0:
		attack_t += delta
		atk = sin(clampf(attack_t / 0.4, 0.0, 1.0) * PI)
		if attack_t > 0.4:
			attack_t = -1.0
	var hit := 0.0
	if hit_t >= 0.0:
		hit_t += delta
		hit = sin(clampf(hit_t / 0.25, 0.0, 1.0) * PI)
		if hit_t > 0.25:
			hit_t = -1.0
	var sw := sin(phase)
	match rig:
		"quad":
			var amp := 0.5 * run if moving else 0.0
			for i in legs.size():
				var ph := sw if (i == 0 or i == 3) else -sw
				legs[i].rotation.x = lerpf(legs[i].rotation.x, ph * amp, s)
				knees[i].rotation.x = lerpf(knees[i].rotation.x, -maxf(0.0, ph) * amp * 0.8, s)
			torso.position.y += 0.0
			body.position.y = lerpf(body.position.y, absf(sw) * 0.04 * run, s)
			if head:
				head.rotation.x = lerpf(head.rotation.x, -atk * 0.5 + hit * 0.3 + sin(t * 1.5) * 0.04, s)
				head.position.z = head.position.z
			if tail:
				tail.rotation.y = sin(t * (3.0 + 6.0 * run)) * 0.3
			torso.rotation.x = lerpf(torso.rotation.x, atk * 0.15 - hit * 0.1, s)
		"spider":
			for i in legs.size():
				var ph2 := sin(phase + i * 1.3)
				legs[i].rotation.x = lerpf(legs[i].rotation.x, ph2 * 0.3 * run if moving else 0.0, s)
				knees[i].rotation.y = lerpf(knees[i].rotation.y, maxf(0.0, ph2) * 0.4 * run if moving else 0.0, s)
			torso.rotation.x = lerpf(torso.rotation.x, -atk * 0.35 - hit * 0.1, s)
			torso.position.y = 0.45 + sin(t * 2.0) * 0.01
		"crab":
			for i in legs.size():
				legs[i].rotation.z = sin(phase * 1.5 + i) * 0.3 * run if moving else 0.0
			for i in arms.size():
				arms[i].rotation.x = lerpf(arms[i].rotation.x, atk * 0.8 + sin(t * 2.0 + i) * 0.08, s)
			torso.rotation.x = lerpf(torso.rotation.x, -hit * 0.15, s)
		"blob":
			var squash := sin(t * 3.0 + phase) * 0.06 + (absf(sin(phase)) * 0.15 if moving else 0.0)
			torso.scale = Vector3(1.0 + squash, 1.0 - squash + atk * 0.2, 1.0 + squash)
			torso.position.y = (absf(sin(phase)) * 0.25 if moving else 0.0) + atk * 0.15
		"hop":
			torso.position.y = 0.15 + (absf(sin(phase * 0.8)) * 0.15 if moving else 0.0)
		"biped":
			var amp2 := lerpf(0.4, 0.8, run) if moving else 0.0
			if legs.size() >= 2:
				legs[0].rotation.x = lerpf(legs[0].rotation.x, sw * amp2, s)
				legs[1].rotation.x = lerpf(legs[1].rotation.x, -sw * amp2, s)
				knees[0].rotation.x = lerpf(knees[0].rotation.x, -maxf(0.0, -cos(phase)) * amp2, s)
				knees[1].rotation.x = lerpf(knees[1].rotation.x, -maxf(0.0, cos(phase)) * amp2, s)
			if arms.size() >= 2:
				var cast_v := 1.0 if (st.get("casting", false) or st.get("channel", false)) else 0.0
				var rel_v := 0.0
				if cast_release_t >= 0.0:
					cast_release_t += delta
					rel_v = sin(clampf(cast_release_t / 0.4, 0.0, 1.0) * PI)
					if cast_release_t > 0.4:
						cast_release_t = -1.0
				var aim := 1.0 if st.get("aiming", false) else 0.0
				var lx := -sw * amp2 * 0.8 + cast_v * 1.1 + aim * 1.3
				var rx := sw * amp2 * 0.8 + atk * 2.2 + cast_v * 1.1 + rel_v * 1.3 + aim * 1.4
				arms[0].rotation = arms[0].rotation.lerp(Vector3(lx, 0, 0.15 + (sin(t * 6.0) * 0.4 if wings.size() > 0 else 0.0)), s)
				arms[1].rotation = arms[1].rotation.lerp(Vector3(rx, 0, -0.15 - (sin(t * 6.0) * 0.4 if wings.size() > 0 else 0.0)), s)
				elbows[0].rotation.x = lerpf(elbows[0].rotation.x, -0.3 - cast_v * 0.5, s)
				elbows[1].rotation.x = lerpf(elbows[1].rotation.x, -0.3 - atk * 0.6 - cast_v * 0.5, s)
			torso.rotation.x = lerpf(torso.rotation.x, (0.12 * run if moving else 0.0) + atk * 0.2 - hit * 0.2, s)
			torso.rotation.y = lerpf(torso.rotation.y, -atk * 0.4, s)
			body.position.y = lerpf(body.position.y, absf(sw) * 0.04 * run + sin(t * 2.0) * 0.008, s)
			for w in wings:
				w.rotation.y = sin(t * 8.0) * 0.25
