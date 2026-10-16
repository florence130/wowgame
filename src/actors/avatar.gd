class_name Avatar
extends Node3D
## 程序化卡通人形角色（洛奇M式 Q 版比例）：捏脸 + 装备外观 + 程序动画
## 朝向 -Z，原点在脚底。

var app: Dictionary = {}
var gear: Dictionary = {}
var combat_ready := false

# 骨架节点
var body: Node3D
var hips: Node3D
var torso: Node3D
var neck: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var back_attach: Node3D
var hip_attach: Node3D
var weapon_main: Node3D
var weapon_off: Node3D
var weapon_ranged: Node3D

# 动画状态
var t := 0.0
var walk_phase := 0.0
var attack_t := -1.0
var attack_kind := 0
var hit_t := -1.0
var cast_release_t := -1.0
var emote := ""
var emote_t := 0.0
var dead_t := -1.0
var state := {}
var _skin_h := 1.0
var _scale_h := 1.0
var _dt := 0.016
var mech_parts: Array[Node3D] = []
var mech_deployed := false

const HAIR_STYLES := 10

func setup(appearance: Dictionary, gear_vis: Dictionary = {}) -> void:
	app = appearance
	gear = gear_vis
	_build()

func set_gear(g: Dictionary) -> void:
	gear = g
	_build()

func set_appearance(a: Dictionary) -> void:
	app = a
	_build()

func _clear() -> void:
	mech_parts.clear()
	for c in get_children():
		remove_child(c)
		c.queue_free()

func _gc(slot: String, default_c: Color) -> Color:
	if gear.has(slot):
		return gear[slot].get("color", default_c)
	return default_c

func _build() -> void:
	_clear()
	var female: bool = app.get("gender", "f") == "f"
	var skin: Color = app.get("skin", Color("fbd5bd"))
	var hc: Color = app.get("hair_color", Color("c08040"))
	var h: float = app.get("height", 1.0)
	var b: float = app.get("build", 1.0)
	_scale_h = h * (0.93 if female else 1.0)
	var skin_m := U.char_mat(skin)
	var sw := (0.155 if female else 0.19) * b  # 肩宽
	var leg_len := 0.74 if female else 0.78
	var chest_c: Color = _gc("chest", _gc("shirt", skin))
	var has_chest := gear.has("chest") or gear.has("shirt")
	var legs_c: Color = _gc("legs", Color("4a4a5a"))
	var feet_c: Color = _gc("feet", skin.darkened(0.1))
	var hands_c: Color = _gc("hands", skin)
	var robe: bool = gear.has("chest") and gear["chest"].get("robe", false)

	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	body.scale = Vector3(_scale_h, _scale_h, _scale_h)
	hips = Node3D.new()
	hips.position = Vector3(0, leg_len, 0)
	body.add_child(hips)
	# 骨盆
	U.add_mesh(hips, U.sphere_mesh(0.13 * b, 0.2), U.char_mat(legs_c), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.05 if female else 1.0, 1.0, 0.85))
	# 躯干
	torso = Node3D.new()
	hips.add_child(torso)
	var tm := U.char_mat(chest_c)
	var top_r := (0.15 if female else 0.18) * b
	var bot_r := (0.115 if female else 0.15) * b
	U.add_mesh(torso, U.cyl_mesh(top_r, bot_r, 0.4, 14), tm, Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 1, 0.78))
	U.add_mesh(torso, U.sphere_mesh(top_r, top_r * 1.4), tm, Vector3(0, 0.39, 0), Vector3.ZERO, Vector3(1, 1, 0.78))
	if female and has_chest:
		U.add_mesh(torso, U.sphere_mesh(0.07 * b), tm, Vector3(-0.055, 0.29, -0.075), Vector3.ZERO, Vector3(1, 0.9, 0.8))
		U.add_mesh(torso, U.sphere_mesh(0.07 * b), tm, Vector3(0.055, 0.29, -0.075), Vector3.ZERO, Vector3(1, 0.9, 0.8))
	# 衣服装饰：领口/衣襟
	if gear.has("chest"):
		var c2: Color = gear["chest"].get("color2", chest_c.lightened(0.25))
		U.add_mesh(torso, U.box_mesh(Vector3(0.05, 0.36, 0.02)), U.char_mat(c2, false), Vector3(0, 0.22, -top_r * 0.8 + 0.005))
		U.add_mesh(torso, U.torus_mesh(0.07, 0.1), U.char_mat(c2), Vector3(0, 0.46, 0), Vector3.ZERO, Vector3(1, 0.6, 0.85))
		var ct: String = gear["chest"].get("type", "cloth")
		if ct == "mail" or ct == "plate":
			U.add_mesh(torso, U.cyl_mesh(top_r * 1.05, top_r * 1.02, 0.08, 14), U.char_mat(chest_c.lightened(0.15)), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	if gear.has("tabard"):
		var tc: Color = gear["tabard"]["color"]
		var tc2: Color = gear["tabard"].get("color2", Color("e8c27a"))
		U.add_mesh(torso, U.box_mesh(Vector3(0.2, 0.5, 0.02)), U.char_mat(tc), Vector3(0, 0.12, -top_r * 0.82))
		U.add_mesh(torso, U.box_mesh(Vector3(0.2, 0.5, 0.02)), U.char_mat(tc), Vector3(0, 0.12, top_r * 0.82))
		U.add_mesh(torso, U.sphere_mesh(0.045), U.char_mat(tc2, false), Vector3(0, 0.24, -top_r * 0.82 - 0.012), Vector3.ZERO, Vector3(1, 1.2, 0.3))
	# 腰带
	var waist_c: Color = _gc("waist", chest_c.darkened(0.35))
	U.add_mesh(torso, U.cyl_mesh(bot_r * 1.08, bot_r * 1.1, 0.06, 14), U.char_mat(waist_c), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	if gear.has("waist"):
		U.add_mesh(torso, U.box_mesh(Vector3(0.06, 0.05, 0.02)), U.char_mat(Color("e8c27a"), false), Vector3(0, 0.03, -bot_r * 0.85))
	# 长袍下摆
	if robe:
		var rl := 0.62 if female else 0.66
		U.add_mesh(hips, U.cyl_mesh(bot_r * 1.05, 0.25 * b, rl, 14), U.char_mat(chest_c), Vector3(0, -rl * 0.5 + 0.05, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
		var c3: Color = gear["chest"].get("color2", chest_c.darkened(0.3))
		U.add_mesh(hips, U.cyl_mesh(0.255 * b, 0.26 * b, 0.05, 14), U.char_mat(c3), Vector3(0, -rl + 0.075, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
	elif female and not gear.has("legs") and has_chest:
		U.add_mesh(hips, U.cyl_mesh(bot_r * 1.05, 0.2, 0.25, 14), U.char_mat(chest_c), Vector3(0, -0.08, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
	# 颈与头
	neck = Node3D.new()
	neck.position = Vector3(0, 0.46, 0)
	torso.add_child(neck)
	U.add_mesh(neck, U.cyl_mesh(0.045, 0.05, 0.1), skin_m, Vector3(0, 0.03, 0))
	head = Node3D.new()
	head.position = Vector3(0, 0.07, 0)
	neck.add_child(head)
	_build_head(skin, hc, female)
	# 手臂
	var sleeve_c: Color = chest_c if has_chest else skin
	arm_l = _make_arm(-1, sw, sleeve_c, skin, hands_c, female)
	arm_r = _make_arm(1, sw, sleeve_c, skin, hands_c, female)
	elbow_l = arm_l.get_node("Elbow")
	elbow_r = arm_r.get_node("Elbow")
	hand_l = elbow_l.get_node("Hand")
	hand_r = elbow_r.get_node("Hand")
	# 腿
	leg_l = _make_leg(-1, legs_c, feet_c, robe, b, female)
	leg_r = _make_leg(1, legs_c, feet_c, robe, b, female)
	knee_l = leg_l.get_node("Knee")
	knee_r = leg_r.get_node("Knee")
	# 披风
	back_attach = Node3D.new()
	back_attach.position = Vector3(0, 0.3, top_r * 0.8 + 0.03)
	torso.add_child(back_attach)
	hip_attach = Node3D.new()
	hip_attach.position = Vector3(-0.16 * b, 0.0, 0.02)
	hips.add_child(hip_attach)
	if gear.has("back"):
		var cc: Color = gear["back"]["color"]
		var cape := Node3D.new()
		cape.name = "Cape"
		cape.position = Vector3(0, 0.44, top_r * 0.75)
		torso.add_child(cape)
		U.add_mesh(cape, U.box_mesh(Vector3(sw * 2.1, 0.85, 0.025)), U.char_mat(cc), Vector3(0, -0.42, 0.02), Vector3(-6, 0, 0))
		U.add_mesh(cape, U.box_mesh(Vector3(sw * 2.15, 0.06, 0.03)), U.char_mat(cc.lightened(0.2)), Vector3(0, -0.02, 0))
	_build_weapons()
	U.merge_levels(body)
	_build_mech_armor()
	_update_sheath()

func set_mech_armor(on: bool) -> void:
	mech_deployed = on
	for part in mech_parts:
		part.visible = on
	for weapon in [weapon_main, weapon_off, weapon_ranged]:
		if is_instance_valid(weapon): weapon.visible = not on

func skill_release_origin(style: String) -> Vector3:
	if style in ["rifle", "shotgun", "cannon"] and is_instance_valid(weapon_ranged):
		return weapon_ranged.to_global(Vector3(0, 0.65, -0.02))
	if style == "rocket": return arm_l.to_global(Vector3(0, 0.02, -0.24))
	return elbow_r.to_global(Vector3(0, -0.43, -0.07))

func _build_mech_armor() -> void:
	var metal := U.char_mat(Color("526777"))
	var trim := U.char_mat(Color("c9a06b"))
	for bone in [torso, arm_l, arm_r, elbow_l, elbow_r, knee_l, knee_r]:
		var part := Node3D.new()
		part.name = "MechArmor"
		bone.add_child(part)
		mech_parts.append(part)
		if bone == torso:
			U.add_mesh(part, U.box_mesh(Vector3(0.38, 0.32, 0.15)), metal, Vector3(0, 0.23, -0.13))
			U.add_mesh(part, U.box_mesh(Vector3(0.13, 0.16, 0.025)), trim, Vector3(0, 0.24, -0.22))
			U.add_mesh(part, U.box_mesh(Vector3(0.28, 0.35, 0.18)), metal, Vector3(0, 0.25, 0.19))
		elif bone in [arm_l, arm_r]:
			U.add_mesh(part, U.box_mesh(Vector3(0.19, 0.13, 0.21)), metal, Vector3(0, -0.025, 0))
			U.add_mesh(part, U.box_mesh(Vector3(0.2, 0.035, 0.22)), trim, Vector3(0, 0.025, 0))
		else:
			U.add_mesh(part, U.box_mesh(Vector3(0.15, 0.22, 0.16)), metal, Vector3(0, -0.12, 0))
			U.add_mesh(part, U.box_mesh(Vector3(0.16, 0.035, 0.17)), trim, Vector3(0, -0.04, 0))
			if bone == elbow_r:
				U.add_mesh(part, U.cyl_mesh(0.065, 0.075, 0.3, 12), metal, Vector3(0, -0.27, -0.07))
				U.add_mesh(part, U.cyl_mesh(0.06, 0.06, 0.025, 12), trim, Vector3(0, -0.43, -0.07))
	set_mech_armor(mech_deployed)

func _make_arm(side: int, sw: float, sleeve: Color, skin: Color, hands_c: Color, female: bool) -> Node3D:
	var sh := Node3D.new()
	sh.position = Vector3(side * sw, 0.4, 0)
	torso.add_child(sh)
	var ar := 0.042 if female else 0.05
	U.add_mesh(sh, U.capsule_mesh(ar, 0.3), U.char_mat(sleeve), Vector3(0, -0.13, 0))
	var el := Node3D.new()
	el.name = "Elbow"
	el.position = Vector3(0, -0.27, 0)
	sh.add_child(el)
	var fore_c := sleeve if gear.has("chest") and gear["chest"].get("robe", false) else skin
	if gear.has("hands"):
		fore_c = hands_c
	U.add_mesh(el, U.capsule_mesh(ar * 0.9, 0.27), U.char_mat(fore_c), Vector3(0, -0.12, 0))
	if gear.has("wrist"):
		U.add_mesh(el, U.cyl_mesh(ar * 1.15, ar * 1.15, 0.08), U.char_mat(gear["wrist"]["color"]), Vector3(0, -0.17, 0))
	if gear.has("hands"):
		U.add_mesh(el, U.cyl_mesh(ar * 1.2, ar * 1.05, 0.07), U.char_mat(hands_c.lightened(0.1)), Vector3(0, -0.2, 0))
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, -0.27, 0)
	el.add_child(hand)
	U.add_mesh(hand, U.sphere_mesh(ar * 1.05), U.char_mat(hands_c), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.15, 1))
	return sh

func _make_leg(side: int, legs_c: Color, feet_c: Color, robe: bool, b: float, female: bool) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(side * 0.075 * b, 0, 0)
	hips.add_child(hip)
	var lr := (0.06 if female else 0.068) * b
	if not robe:
		U.add_mesh(hip, U.capsule_mesh(lr, 0.42), U.char_mat(legs_c), Vector3(0, -0.18, 0))
	var knee := Node3D.new()
	knee.name = "Knee"
	knee.position = Vector3(0, -0.38, 0)
	hip.add_child(knee)
	var shin_c := legs_c
	var boots := gear.has("feet")
	if not gear.has("legs") and not robe:
		shin_c = app.get("skin", Color("fbd5bd")) if female else legs_c
	U.add_mesh(knee, U.capsule_mesh(lr * 0.88, 0.4), U.char_mat(shin_c), Vector3(0, -0.18, 0))
	if boots:
		var ft: String = gear["feet"].get("type", "cloth")
		if ft != "cloth":
			U.add_mesh(knee, U.cyl_mesh(lr * 1.08, lr * 1.0, 0.2), U.char_mat(feet_c), Vector3(0, -0.27, 0))
	var foot := Node3D.new()
	foot.name = "Foot"
	foot.position = Vector3(0, -0.36, 0)
	knee.add_child(foot)
	U.add_mesh(foot, U.box_mesh(Vector3(0.09, 0.07, 0.17)), U.char_mat(feet_c), Vector3(0, -0.025, -0.035))
	U.add_mesh(foot, U.sphere_mesh(0.047), U.char_mat(feet_c), Vector3(0, -0.02, -0.11), Vector3.ZERO, Vector3(1, 0.75, 1))
	return hip

# ---------------------------------------------------------------- 头部/脸/发型
func _build_head(skin: Color, hc: Color, female: bool) -> void:
	var R := 0.17
	var face: int = app.get("face", 0)
	var hs = [Vector3(1.0, 1.0, 1.0), Vector3(0.96, 1.04, 0.97), Vector3(1.04, 0.97, 1.0)][clampi(face, 0, 2)]
	var hroot := Node3D.new()
	hroot.name = "HeadRoot"
	hroot.position = Vector3(0, R * 0.95, 0)
	hroot.scale = hs
	head.add_child(hroot)
	var skin_m := U.char_mat(skin)
	U.add_mesh(hroot, U.sphere_mesh(R, R * 2.0, false, 20), skin_m)
	# 下巴（圆润）
	U.add_mesh(hroot, U.sphere_mesh(R * 0.7), skin_m, Vector3(0, -R * 0.42, -R * 0.18), Vector3.ZERO, Vector3(1.0, 0.75, 1.0))
	# 耳朵
	for s in [-1, 1]:
		U.add_mesh(hroot, U.sphere_mesh(0.03), skin_m, Vector3(s * R * 0.98, -0.01, 0.01), Vector3.ZERO, Vector3(0.5, 1.0, 0.8))
	# 眼睛
	var eye_style: int = app.get("eye", 0)
	var ec: Color = app.get("eye_color", Color("8a5a30"))
	for s in [-1, 1]:
		var ex = s * 0.066
		var ey := -0.02
		var ez := -sqrt(R * R - ex * ex - ey * ey) + 0.006
		var eye := Node3D.new()
		eye.position = Vector3(ex, ey, ez)
		eye.rotation = Vector3(0, -s * 0.38, 0)
		hroot.add_child(eye)
		match eye_style:
			3:
				# 笑眼 ^ ^
				U.add_mesh(eye, U.torus_mesh(0.022, 0.03, 16), U.unshaded(Color("2a1a1a")), Vector3(0, -0.005, -0.004), Vector3(90, 0, 0), Vector3(1, 1, 0.55))
				U.add_mesh(eye, U.box_mesh(Vector3(0.07, 0.04, 0.03)), skin_m, Vector3(0, -0.026, 0.004))
			_:
				var ew = [0.034, 0.038, 0.036][eye_style]
				var eh = [0.05, 0.044, 0.032][eye_style]
				U.add_mesh(eye, U.sphere_mesh(1.0, 2.0, false, 12), U.unshaded(Color("fffdf8")), Vector3.ZERO, Vector3.ZERO, Vector3(ew, eh, 0.012))
				U.add_mesh(eye, U.sphere_mesh(1.0, 2.0, false, 12), U.unshaded(ec), Vector3(0, -0.004, -0.006), Vector3.ZERO, Vector3(ew * 0.78, eh * 0.82, 0.01))
				U.add_mesh(eye, U.sphere_mesh(1.0, 2.0, false, 10), U.unshaded(ec.darkened(0.6)), Vector3(0, -0.006, -0.0105), Vector3.ZERO, Vector3(ew * 0.42, eh * 0.48, 0.006))
				U.add_mesh(eye, U.sphere_mesh(1.0, 2.0, false, 8), U.unshaded(Color.WHITE), Vector3(s * -0.008, 0.01, -0.0135), Vector3.ZERO, Vector3(0.009, 0.011, 0.004))
				# 上睫毛
				U.add_mesh(eye, U.box_mesh(Vector3(ew * 2.3, 0.009, 0.01)), U.unshaded(Color("2a1a1a")), Vector3(s * 0.004, eh * 0.95, -0.004), Vector3(0, 0, -s * 8))
				if female:
					U.add_mesh(eye, U.box_mesh(Vector3(0.016, 0.007, 0.008)), U.unshaded(Color("2a1a1a")), Vector3(s * ew * 1.15, eh * 0.75, -0.002), Vector3(0, 0, -s * 35))
		# 眉毛
		var brow: int = app.get("brow", 0)
		var bc := hc.darkened(0.35)
		var brow_rot = [-s * 6, s * 10, -s * 16][clampi(brow, 0, 2)]
		var brow_w := 0.05 if female else 0.058
		U.add_mesh(hroot, U.box_mesh(Vector3(brow_w, 0.011 if female else 0.015, 0.01)), U.unshaded(bc), Vector3(ex * 1.02, 0.058, ez + 0.012), Vector3(0, -s * 22, brow_rot))
	# 嘴
	var mouth: int = app.get("mouth", 0)
	var mz := -R * 0.93
	match mouth:
		0:
			U.add_mesh(hroot, U.torus_mesh(0.012, 0.018, 12), U.unshaded(Color("8a3a3a")), Vector3(0, -0.085, mz), Vector3(90, 0, 0), Vector3(1, 1, 0.5))
			U.add_mesh(hroot, U.box_mesh(Vector3(0.05, 0.02, 0.02)), skin_m, Vector3(0, -0.078, mz + 0.008))
		1:
			U.add_mesh(hroot, U.box_mesh(Vector3(0.026, 0.006, 0.008)), U.unshaded(Color("7a3030")), Vector3(0, -0.09, mz))
		2:
			U.add_mesh(hroot, U.sphere_mesh(1.0), U.unshaded(Color("a03a3a")), Vector3(0, -0.09, mz), Vector3.ZERO, Vector3(0.012, 0.014, 0.005))
	if app.get("blush", false):
		for s in [-1, 1]:
			U.add_mesh(hroot, U.sphere_mesh(1.0), U.unshaded(Color(1.0, 0.55, 0.55, 0.35)), Vector3(s * 0.085, -0.06, -R * 0.84), Vector3(0, -s * 30, 0), Vector3(0.025, 0.012, 0.004))
	if app.get("beard", false):
		U.add_mesh(hroot, U.sphere_mesh(R * 0.62), U.char_mat(hc.darkened(0.15)), Vector3(0, -R * 0.62, -R * 0.38), Vector3.ZERO, Vector3(1.05, 0.7, 0.75))
		U.add_mesh(hroot, U.box_mesh(Vector3(0.07, 0.016, 0.02)), U.char_mat(hc.darkened(0.15)), Vector3(0, -0.068, mz + 0.004))
	if gear.get("mask", false):
		U.add_mesh(hroot, U.sphere_mesh(R * 1.02, R * 2.04, true), U.char_mat(Color("5a5a62")), Vector3(0, -0.035, 0), Vector3(180, 0, 0), Vector3(1.0, 0.75, 1.0))
	# 头盔/帽子 或 头发
	var helm_type := ""
	if gear.has("head"):
		helm_type = gear["head"].get("type", "")
	_build_hair(hroot, hc, R, helm_type)
	if helm_type != "":
		_build_helm(hroot, R, helm_type, gear["head"]["color"], gear["head"].get("color2", gear["head"]["color"].lightened(0.3)))

func _build_hair(hroot: Node3D, hc: Color, R: float, helm: String) -> void:
	var hm := U.char_mat(hc)
	var style: int = app.get("hair", 0)
	var full_helm := helm in ["mail", "leather", "plate"]
	if full_helm:
		return
	var show_cap := helm in ["", "bandana", "goggles"]
	if show_cap:
		U.add_mesh(hroot, U.sphere_mesh(R * 1.08, R * 2.16, true, 20), hm, Vector3(0, 0.0, 0.004), Vector3(-8, 0, 0))
	# 后脑
	U.add_mesh(hroot, U.sphere_mesh(R * 1.02), hm, Vector3(0, -0.01, 0.045), Vector3.ZERO, Vector3(1.04, 0.95, 0.85))
	# 刘海
	var bang_n := 5
	match style:
		2:
			for i in 7:
				var a := (i - 3) * 0.32
				U.add_mesh(hroot, U.cyl_mesh(0.0, 0.05, 0.16, 8), hm, Vector3(sin(a) * R * 0.75, R * 0.75, cos(a) * R * 0.2 + 0.05), Vector3(-30 + absf(a) * 10, 0, -rad_to_deg(a) * 0.9))
			bang_n = 3
		1, 3:
			bang_n = 4
	for i in bang_n:
		var fx := (float(i) / (bang_n - 1) - 0.5) * R * 1.35
		var sweep := 0.0
		if style == 1 or style == 3:
			sweep = 25.0
		var len := 0.12 + (0.03 if i % 2 == 0 else 0.0)
		U.add_mesh(hroot, U.capsule_mesh(0.032, len), hm, Vector3(fx, R * 0.42, -R * 0.82), Vector3(-20, 0, sweep + fx * 120.0))
	# 侧发
	var side_len := 0.0
	match style:
		3: side_len = 0.24
		5: side_len = 0.26
		7, 8: side_len = 0.3
		4, 6, 9: side_len = 0.16
		_: side_len = 0.12
	for s in [-1, 1]:
		U.add_mesh(hroot, U.capsule_mesh(0.04 if style != 5 else 0.06, side_len), hm, Vector3(s * R * 0.9, -side_len * 0.32, -R * 0.25), Vector3(0, 0, s * 4))
	match style:
		4:
			U.add_mesh(hroot, U.sphere_mesh(0.035), U.char_mat(Color("d04060")), Vector3(0, R * 0.55, R * 0.92))
			U.add_mesh(hroot, U.capsule_mesh(0.065, 0.42), hm, Vector3(0, R * 0.1, R * 1.25), Vector3(28, 0, 0))
		5:
			U.add_mesh(hroot, U.sphere_mesh(R * 1.12), hm, Vector3(0, -0.04, 0.05), Vector3.ZERO, Vector3(1.05, 0.85, 0.95))
		6:
			for s in [-1, 1]:
				U.add_mesh(hroot, U.sphere_mesh(0.03), U.char_mat(Color("e04070")), Vector3(s * R * 0.95, R * 0.5, R * 0.3))
				U.add_mesh(hroot, U.capsule_mesh(0.06, 0.48), hm, Vector3(s * R * 1.25, -R * 0.55, R * 0.35), Vector3(10, 0, s * 12))
		7:
			for i in 7:
				var fx2 := (float(i) / 6.0 - 0.5) * R * 1.7
				var ln := 0.5 + (0.06 if i % 2 == 0 else 0.0) - absf(fx2) * 0.6
				U.add_mesh(hroot, U.capsule_mesh(0.05, ln), hm, Vector3(fx2, -ln * 0.42 + 0.02, R * 0.72 + absf(fx2) * 0.15), Vector3(10, 0, fx2 * 40.0))
		8:
			for i in 7:
				var px := (float(i) / 6.0 - 0.5) * R * 1.9
				for j in 4:
					U.add_mesh(hroot, U.sphere_mesh(0.06), hm, Vector3(px + sin(j * 1.7 + i) * 0.015, -0.05 - j * 0.11, R * 0.75 + absf(px) * 0.2), Vector3.ZERO, Vector3(1, 1.15, 0.85))
		9:
			U.add_mesh(hroot, U.sphere_mesh(0.085), hm, Vector3(0, R * 0.95, R * 0.45))
			U.add_mesh(hroot, U.torus_mesh(0.05, 0.075), U.char_mat(Color("e0c050")), Vector3(0, R * 0.82, R * 0.4), Vector3(-30, 0, 0))

func _build_helm(hroot: Node3D, R: float, kind: String, c: Color, c2: Color) -> void:
	var m := U.char_mat(c)
	match kind:
		"mail", "plate":
			U.add_mesh(hroot, U.sphere_mesh(R * 1.13, R * 2.26, true, 20), m, Vector3(0, -0.01, 0.0))
			U.add_mesh(hroot, U.cyl_mesh(R * 1.13, R * 1.15, 0.05, 20), U.char_mat(c2), Vector3(0, 0.0, 0))
			U.add_mesh(hroot, U.box_mesh(Vector3(0.025, 0.11, 0.03)), m, Vector3(0, -0.03, -R * 1.08))
			U.add_mesh(hroot, U.sphere_mesh(R * 1.05), m, Vector3(0, -0.05, 0.05), Vector3.ZERO, Vector3(1.08, 0.9, 0.92))
		"leather":
			U.add_mesh(hroot, U.sphere_mesh(R * 1.12, R * 2.24, true, 20), m, Vector3(0, -0.01, 0.005), Vector3(-6, 0, 0))
			U.add_mesh(hroot, U.cyl_mesh(R * 1.14, R * 1.14, 0.035, 20), U.char_mat(c2), Vector3(0, 0.0, 0))
		"hat":
			U.add_mesh(hroot, U.cyl_mesh(R * 1.9, R * 1.9, 0.025, 24), m, Vector3(0, R * 0.55, 0))
			U.add_mesh(hroot, U.cyl_mesh(0.0, R * 0.95, 0.42, 16), m, Vector3(0, R * 0.55 + 0.2, 0.05), Vector3(-12, 0, 0))
			U.add_mesh(hroot, U.cyl_mesh(R * 0.97, R * 0.97, 0.04, 16), U.char_mat(Color("e8c27a")), Vector3(0, R * 0.6, 0))
		"strawhat":
			U.add_mesh(hroot, U.cyl_mesh(R * 2.0, R * 2.0, 0.025, 24), m, Vector3(0, R * 0.55, 0))
			U.add_mesh(hroot, U.sphere_mesh(R * 1.0, R * 2.0, true), m, Vector3(0, R * 0.5, 0))
			U.add_mesh(hroot, U.cyl_mesh(R * 1.0, R * 1.0, 0.03, 16), U.char_mat(Color("c03030")), Vector3(0, R * 0.6, 0))
		"cap":
			U.add_mesh(hroot, U.sphere_mesh(R * 1.1, R * 2.2, true), m, Vector3(0, R * 0.25, 0))
			U.add_mesh(hroot, U.box_mesh(Vector3(R * 1.4, 0.015, 0.12)), m, Vector3(0, R * 0.3, -R * 1.05))
			U.add_mesh(hroot, U.sphere_mesh(0.025), U.char_mat(Color("e8c27a")), Vector3(0, R * 0.7, -R * 0.95))
		"tricorn":
			U.add_mesh(hroot, U.cyl_mesh(R * 1.6, R * 1.6, 0.03, 3), m, Vector3(0, R * 0.62, 0), Vector3(0, 180, 0))
			U.add_mesh(hroot, U.sphere_mesh(R * 1.02, R * 2.04, true), m, Vector3(0, R * 0.55, 0))
			U.add_mesh(hroot, U.cyl_mesh(R * 1.62, R * 1.62, 0.012, 3), U.char_mat(Color("e8c27a")), Vector3(0, R * 0.64, 0), Vector3(0, 180, 0))
		"bandana":
			U.add_mesh(hroot, U.sphere_mesh(R * 1.12, R * 2.24, true, 18), m, Vector3(0, 0.0, 0.01), Vector3(-15, 0, 0))
			U.add_mesh(hroot, U.capsule_mesh(0.025, 0.16), m, Vector3(0.04, 0.0, R * 1.08), Vector3(40, 0, 30))
		"goggles":
			U.add_mesh(hroot, U.torus_mesh(0.025, 0.045), U.char_mat(Color("8a6a40")), Vector3(-0.055, R * 0.62, -R * 0.75), Vector3(60, 0, 0))
			U.add_mesh(hroot, U.torus_mesh(0.025, 0.045), U.char_mat(Color("8a6a40")), Vector3(0.055, R * 0.62, -R * 0.75), Vector3(60, 0, 0))
			U.add_mesh(hroot, U.cyl_mesh(0.03, 0.03, 0.01), U.unshaded(Color("80d0ff")), Vector3(-0.055, R * 0.62, -R * 0.77), Vector3(60, 0, 0))
			U.add_mesh(hroot, U.cyl_mesh(0.03, 0.03, 0.01), U.unshaded(Color("80d0ff")), Vector3(0.055, R * 0.62, -R * 0.77), Vector3(60, 0, 0))
		"minerhat":
			U.add_mesh(hroot, U.sphere_mesh(R * 1.12, R * 2.24, true), m, Vector3(0, R * 0.2, 0))
			U.add_mesh(hroot, U.cyl_mesh(R * 1.25, R * 1.25, 0.02, 20), m, Vector3(0, R * 0.22, 0))
			U.add_mesh(hroot, U.cyl_mesh(0.03, 0.035, 0.04), U.unshaded(Color("fff0a0")), Vector3(0, R * 0.65, -R * 1.0), Vector3(80, 0, 0))

# ---------------------------------------------------------------- 武器
func _build_weapons() -> void:
	weapon_main = null
	weapon_off = null
	weapon_ranged = null
	if gear.has("main"):
		weapon_main = WeaponModel.make(gear["main"].get("wtype", gear["main"].get("type", "sword")), gear["main"].get("color", Color("b0b0b8")), gear["main"].get("q", 1))
	if gear.has("off"):
		weapon_off = WeaponModel.make(gear["off"].get("wtype", gear["off"].get("type", "shield")), gear["off"].get("color", Color("8a6a40")), gear["off"].get("q", 1), gear["off"].get("color2", Color("e8c27a")))
	if gear.has("ranged"):
		weapon_ranged = WeaponModel.make(gear["ranged"].get("wtype", "gun"), gear["ranged"].get("color", Color("7a5a3a")), gear["ranged"].get("q", 1))

func main_wtype() -> String:
	if gear.has("main"):
		return gear["main"].get("wtype", gear["main"].get("type", "sword"))
	return ""

func set_combat_ready(v: bool) -> void:
	if v == combat_ready:
		return
	combat_ready = v
	_update_sheath()

var _ranged_mode := false
func set_ranged_mode(v: bool) -> void:
	if v == _ranged_mode:
		return
	_ranged_mode = v
	_update_sheath()

func _reparent(n: Node3D, p: Node3D, pos: Vector3, rot: Vector3) -> void:
	if n == null:
		return
	if n.get_parent():
		n.get_parent().remove_child(n)
	p.add_child(n)
	n.position = pos
	n.rotation_degrees = rot

func _update_sheath() -> void:
	if hand_r == null:
		return
	var wt := main_wtype()
	var two := wt in ["staff", "sword2", "axe2", "mace2", "polearm", "spear", "pick"]
	if _ranged_mode and weapon_ranged:
		var rt: String = gear["ranged"].get("wtype", "gun")
		_reparent(weapon_ranged, hand_r, Vector3(0, 0, 0), Vector3(-90, 0, 0) if rt == "bow" else Vector3(180, 0, 0))
		_reparent(weapon_main, back_attach, Vector3(0.05, 0.0, 0.03), Vector3(0, 0, 150))
		_reparent(weapon_off, back_attach, Vector3(0, -0.1, 0.06), Vector3(0, 0, 0))
		return
	if combat_ready:
		if weapon_main:
			if wt == "staff":
				_reparent(weapon_main, hand_r, Vector3(0, 0, 0), Vector3(0, 0, 0))
			else:
				_reparent(weapon_main, hand_r, Vector3(0, -0.02, 0), Vector3(-90, 0, 0))
		if weapon_off:
			if gear["off"].get("wtype", gear["off"].get("type", "")) == "shield":
				_reparent(weapon_off, elbow_l, Vector3(-0.06, -0.15, 0), Vector3(0, 0, 90))
			else:
				_reparent(weapon_off, hand_l, Vector3(0, -0.02, 0), Vector3(-90, 0, 0))
		if weapon_ranged:
			_reparent(weapon_ranged, back_attach, Vector3(-0.08, 0.0, 0.05), Vector3(0, 0, -140))
	else:
		if weapon_main:
			if two:
				_reparent(weapon_main, back_attach, Vector3(0.0, 0.0, 0.03), Vector3(0, 0, 150))
			elif wt == "dagger":
				_reparent(weapon_main, hip_attach, Vector3(0, -0.02, 0), Vector3(180, 0, 0))
			else:
				_reparent(weapon_main, hip_attach, Vector3(0, 0.02, 0.03), Vector3(160, 0, 8))
		if weapon_off:
			if gear["off"].get("wtype", gear["off"].get("type", "")) == "shield":
				_reparent(weapon_off, back_attach, Vector3(0, -0.12, 0.05), Vector3(0, 0, 0))
			else:
				_reparent(weapon_off, hips, Vector3(0.16, 0.02, 0.03), Vector3(160, 0, -8))
		if weapon_ranged:
			_reparent(weapon_ranged, back_attach, Vector3(-0.08, 0.0, 0.05), Vector3(0, 0, -140))

# ---------------------------------------------------------------- 动画
func play_attack(kind: int = -1) -> void:
	if attack_t >= 0.0 and skill_style != "":
		return
	attack_t = 0.0
	attack_kind = kind if kind >= 0 else randi() % 3
	attack_duration = 0.42

var attack_duration := 0.42

var skill_style := ""
var skill_windup := 0.18
var roll_t := -1.0

func play_skill_attack(windup: float, recovery: float, style: String = "slash") -> void:
	visual_hit_pause = 0
	attack_t = 0.0
	skill_style = style
	skill_windup = maxf(0.06, windup)
	attack_duration = skill_windup + maxf(0.08, recovery)
	cast_release_t = -1

func cancel_skill() -> void:
	visual_hit_pause = 0
	if roll_t >= 0:
		roll_t = -1
		body.rotation.x = 0
		body.position = Vector3.ZERO
	attack_t = -1
	skill_style = ""
	cast_release_t = -1

func play_roll() -> void:
	cancel_skill()
	roll_t = 0

func play_hit() -> void:
	if attack_t < 0.0:
		hit_t = 0.0

func play_cast_release() -> void:
	cast_release_t = 0.0

var visual_hit_pause := 0.0

func impact_pause(duration: float) -> void:
	visual_hit_pause = maxf(visual_hit_pause, minf(duration, 0.05))

func reach_skill_contact() -> void:
	# Only the current action's commitment may advance its pose. A delayed spell hit may not.
	if skill_style != "" and attack_t >= 0 and attack_t < skill_windup and visual_hit_pause <= 0:
		animate(skill_windup - attack_t, state)

func play_emote(e: String) -> void:
	emote = e
	emote_t = 0.0

func set_dead(v: bool) -> void:
	if v and dead_t < 0.0:
		dead_t = 0.0
	elif not v:
		dead_t = -1.0
		body.rotation = Vector3.ZERO
		body.position = Vector3.ZERO

## state: speed(前进速度,负为后退), strafe, air, casting, channel, swim, sit, mounted
func animate(delta: float, st: Dictionary) -> void:
	state = st
	if body == null:
		return
	if visual_hit_pause > 0.0 and dead_t < 0.0:
		visual_hit_pause = maxf(0.0, visual_hit_pause - delta)
		return
	_dt = delta
	t += delta
	var spd: float = st.get("speed", 0.0)
	var strafe: float = st.get("strafe", 0.0)
	var air: bool = st.get("air", false)
	var moving := absf(spd) > 0.3 or absf(strafe) > 0.3
	var run_amt := clampf(maxf(absf(spd), absf(strafe)) / 7.0, 0.0, 1.0)
	if moving:
		walk_phase += delta * (5.0 + 6.0 * run_amt) * (1.0 if spd >= -0.1 else -1.0)
		emote = ""
	var sw := sin(walk_phase)
	var cw := cos(walk_phase)
	# 默认姿势
	var lhip := 0.0
	var rhip := 0.0
	var lknee := 0.0
	var rknee := 0.0
	var lsh := Vector3(0, 0, 0.12)
	var rsh := Vector3(0, 0, -0.12)
	var lel := 0.0
	var rel := 0.0
	var torso_rx := 0.0
	var torso_ry := 0.0
	var body_y := 0.0
	var head_rx := 0.0
	var breathe := sin(t * 2.0) * 0.012
	if dead_t >= 0.0:
		dead_t += delta
		var k := clampf(dead_t / 0.6, 0.0, 1.0)
		body.rotation.x = lerpf(0.0, PI * 0.5, k * k)
		body.position.y = lerpf(0.0, 0.12, k)
		body.position.z = lerpf(0.0, 0.5, k)
		_apply(0.3, -0.2, -0.3, -0.2, Vector3(0.4, 0, 0.5), Vector3(0.4, 0, -0.5), -0.2, -0.2, 0, 0, 0, 0)
		return
	if st.get("mounted", false):
		_apply(0.9, 0.9, -1.2, -1.2, Vector3(0.5, 0, 0.15), Vector3(0.5, 0, -0.15), -0.6, -0.6, 0.05, 0, 0.0, 0)
		return
	if st.get("sit", false):
		body_y = -0.42
		_apply(1.45, 1.45, -1.5, -1.5, Vector3(0.1, 0, 0.2), Vector3(0.1, 0, -0.2), -0.3, -0.3, 0.1, 0, body_y, 0)
		return
	if st.get("swim", false):
		var s2 := sin(t * 4.0)
		_apply(-0.3 + s2 * 0.3, -0.3 - s2 * 0.3, -0.2, -0.2, Vector3(2.4 + s2 * 0.4, 0, 0.4), Vector3(2.4 - s2 * 0.4, 0, -0.4), -0.2, -0.2, 0.9 if moving else 0.2, 0, -0.1, -0.5)
		return
	if moving:
		var amp := lerpf(0.45, 0.85, run_amt)
		lhip = sw * amp
		rhip = -sw * amp
		lknee = -maxf(0.0, -cw) * amp * 1.4 - 0.1
		rknee = -maxf(0.0, cw) * amp * 1.4 - 0.1
		lsh = Vector3(-sw * amp * 0.9, 0, 0.12)
		rsh = Vector3(sw * amp * 0.9, 0, -0.12)
		lel = -0.3 - run_amt * 0.6
		rel = -0.3 - run_amt * 0.6
		torso_rx = run_amt * 0.18 * signf(spd + 0.01)
		body_y = absf(sin(walk_phase)) * 0.05 * run_amt
		torso_ry = sw * 0.08
		if absf(strafe) > absf(spd):
			torso_ry += signf(strafe) * -0.3
	else:
		lsh.z += breathe * 2.0
		rsh.z -= breathe * 2.0
		lel = -0.12
		rel = -0.12
		if combat_ready:
			lknee = -0.25
			rknee = -0.25
			lhip = 0.25
			rhip = -0.05
			body_y = -0.04
			rsh = Vector3(0.35, 0, -0.25)
			rel = -0.9
			lsh = Vector3(0.3, 0, 0.25)
			lel = -0.8
	if air:
		lhip = 0.6
		rhip = -0.1
		lknee = -1.0
		rknee = -0.3
		lsh = Vector3(0.3, 0, 0.6)
		rsh = Vector3(0.3, 0, -0.6)
	# 施法
	if st.get("casting", false) or st.get("channel", false):
		var wob := sin(t * 10.0) * 0.06
		lsh = Vector3(1.1 + wob, 0, 0.35)
		rsh = Vector3(1.1 - wob, 0, -0.35)
		lel = -0.7
		rel = -0.7
		if st.get("cast_animation", "") == "reload":
			rsh = Vector3(0.65, 0, -0.2)
			lsh = Vector3(0.8, 0, -0.45)
			lel = -1.25 + sin(t * 12.0) * 0.15
			rel = -0.8
	if _ranged_mode and st.get("aiming", false) and st.get("cast_animation", "") != "reload":
		rsh = Vector3(1.45, 0, -0.05)
		rel = -0.1
		lsh = Vector3(1.35, 0.0, -0.45)
		lel = -0.7
	# 施法释放
	if cast_release_t >= 0.0:
		cast_release_t += delta
		var k2 := cast_release_t / 0.4
		if k2 >= 1.0:
			cast_release_t = -1.0
		else:
			var e := sin(k2 * PI)
			rsh = Vector3(1.4 * e + rsh.x * (1.0 - e), 0, -0.1)
			rel = -0.1
			lsh = lsh.lerp(Vector3(0.6, 0, 0.5), e)
	# 攻击挥砍
	var baseline_r := rsh
	var baseline_l := lsh
	var baseline_rel := rel
	var baseline_lel := lel
	var baseline_twist := torso_ry
	var baseline_lean := torso_rx
	if attack_t >= 0.0:
		attack_t += delta
		var dur := attack_duration
		var k3 := attack_t / dur
		if k3 >= 1.0:
			attack_t = -1.0
			skill_style = ""
		else:
			var wt := main_wtype()
			match attack_kind:
				0:
					var wind := smoothstep(0.0, 0.35, k3)
					var strike := smoothstep(0.35, 0.65, k3)
					var x := lerpf(rsh.x, 2.6, wind)
					x = lerpf(x, -0.2, strike)
					rsh = Vector3(x, 0, -0.2 - strike * 0.3)
					rel = -0.4 * (1.0 - strike)
					torso_ry = lerpf(0.3 * wind, -0.45, strike)
				1:
					var wind2 := smoothstep(0.0, 0.3, k3)
					var strike2 := smoothstep(0.3, 0.6, k3)
					rsh = Vector3(1.4, 0, lerpf(-1.4 * wind2, 0.6, strike2))
					rel = -0.2
					torso_ry = lerpf(0.5 * wind2, -0.6, strike2)
				_:
					var wind3 := smoothstep(0.0, 0.3, k3)
					var strike3 := smoothstep(0.3, 0.5, k3)
					rsh = Vector3(lerpf(0.3, 1.5, wind3) + strike3 * 0.2, 0, -0.1)
					rel = lerpf(-1.6 * wind3, 0.0, strike3)
					torso_rx = strike3 * 0.15
			if wt == "staff" or wt == "":
				pass
			if skill_style != "":
				# Every pose reaches contact at the exact Unit windup, then returns to locomotion.
				var wind := smoothstep(0.0, skill_windup * 0.65, attack_t)
				var strike := smoothstep(skill_windup * 0.65, skill_windup, attack_t)
				var recover := smoothstep(skill_windup, attack_duration, attack_t)
				var pose_r := Vector3(0.4, 0, -0.25)
				var pose_l := Vector3(0.3, 0, 0.25)
				var bend_r := -0.9
				var bend_l := -0.8
				var twist := 0.0
				var lean := 0.0
				match skill_style:
					"shield":
						pose_l = Vector3(lerpf(0.6, 1.45, strike), 0, 0.18)
						bend_l = lerpf(-1.4 * wind, -0.2, strike)
						lean = strike * 0.18
					"heavy", "hammer":
						pose_r = Vector3(lerpf(2.75 * wind, 0.55, strike), 0, -0.18)
						pose_l = Vector3(pose_r.x - 0.1, 0, -0.45)
						bend_r = -0.35
						bend_l = -0.65
						lean = lerpf(-0.15 * wind, 0.28, strike)
					"dual":
						pose_r = Vector3(1.25, 0, lerpf(-0.9 * wind, 0.2, strike))
						pose_l = Vector3(1.2, 0, lerpf(0.8 * wind, -0.2, strike))
						bend_r = lerpf(-1.0, -0.1, strike)
						bend_l = lerpf(-0.9, -0.1, strike)
						lean = strike * 0.12
					"thrust", "piston":
						pose_r = Vector3(lerpf(0.55 * wind, 1.5, strike), 0, -0.1)
						bend_r = lerpf(-1.65, -0.05, strike)
						pose_l = Vector3(0.75, 0, 0.2)
						twist = lerpf(0.25 * wind, -0.25, strike)
					"rifle", "shotgun", "cannon", "rail", "rocket":
						var recoil := sin(clampf((attack_t - skill_windup) / 0.13, 0, 1) * PI)
						pose_r = Vector3(1.45 - recoil * (0.22 if skill_style == "rifle" else 0.38), 0, -0.05)
						pose_l = Vector3(1.35 - recoil * 0.12, 0, -0.45)
						bend_r = -0.12 - recoil * 0.3
						bend_l = -0.7
						lean = -recoil * 0.12
						if skill_style == "rocket":
							pose_r = baseline_r
							pose_l = baseline_l
							bend_r = baseline_rel
							bend_l = baseline_lel
					_:
						pose_r = Vector3(1.4, 0, lerpf(-1.1 * wind, 0.6, strike))
						bend_r = -0.3
						twist = lerpf(0.4 * wind, -0.45, strike)
				var blend := smoothstep(0.0, skill_windup * 0.35, attack_t) * (1.0 - recover)
				rsh = baseline_r.lerp(pose_r, blend)
				lsh = baseline_l.lerp(pose_l, blend)
				rel = lerpf(baseline_rel, bend_r, blend)
				lel = lerpf(baseline_lel, bend_l, blend)
				torso_ry = lerpf(baseline_twist, twist, blend)
				torso_rx = lerpf(baseline_lean, lean, blend)
	# 受击
	if hit_t >= 0.0:
		hit_t += delta
		if hit_t > 0.25:
			hit_t = -1.0
		else:
			torso_rx -= sin(hit_t / 0.25 * PI) * 0.18
	# 表情动作
	if emote != "" and not moving:
		emote_t += delta
		match emote:
			"wave":
				rsh = Vector3(0.2, 0, -2.6)
				rel = sin(emote_t * 10.0) * 0.4 - 0.5
				if emote_t > 2.5:
					emote = ""
			"bow":
				torso_rx = sin(clampf(emote_t / 1.5, 0.0, 1.0) * PI) * 0.8
				if emote_t > 1.6:
					emote = ""
			"cheer":
				lsh = Vector3(0.2, 0, 2.7)
				rsh = Vector3(0.2, 0, -2.7)
				body_y = absf(sin(emote_t * 8.0)) * 0.12
				if emote_t > 2.0:
					emote = ""
			"dance":
				var dp := emote_t * 7.0
				body_y = absf(sin(dp)) * 0.1
				lsh = Vector3(0.3, 0, 1.6 + sin(dp) * 0.6)
				rsh = Vector3(0.3, 0, -1.6 + sin(dp) * 0.6)
				lhip = sin(dp) * 0.3
				rhip = -sin(dp) * 0.3
				torso_ry = sin(dp * 0.5) * 0.4
			"talk":
				rsh = Vector3(0.6 + sin(emote_t * 5.0) * 0.2, 0, -0.3)
				rel = -0.8
				if emote_t > 2.0:
					emote = ""
			"point":
				rsh = Vector3(1.5, 0, -0.1)
				rel = 0.0
				if emote_t > 2.0:
					emote = ""
	if roll_t >= 0:
		lhip = 0.85
		rhip = 0.85
		lknee = -1.45
		rknee = -1.45
		lsh = Vector3(0.9, 0, 0.2)
		rsh = Vector3(0.9, 0, -0.2)
		lel = -1.2
		rel = -1.2
	_apply(lhip, rhip, lknee, rknee, lsh, rsh, lel, rel, torso_rx, torso_ry, body_y, head_rx)
	_orient_skill_weapons()
	if roll_t >= 0:
		roll_t += delta
		var roll_phase := clampf(roll_t / 0.28, 0, 1)
		body.rotation.x = -TAU * smoothstep(0, 1, roll_phase)
		# Rotate around the tucked body's center, keeping the avatar above the floor.
		body.position = Vector3(0, body_y + 0.85 * _scale_h, 0) - body.basis * Vector3(0, 0.85, 0)
		body.position.y -= sin(roll_phase * PI) * 0.08
		if roll_phase >= 1:
			roll_t = -1
			body.rotation.x = 0
			body.position = Vector3(0, body_y, 0)

func _orient_skill_weapons() -> void:
	if not combat_ready or _ranged_mode or mech_deployed: return
	var amount := 0.0
	if attack_t >= 0 and skill_style in ["thrust", "dual", "heavy", "hammer", "shield"]:
		amount = smoothstep(skill_windup * 0.65, skill_windup, attack_t) * (1.0 - smoothstep(skill_windup, attack_duration, attack_t))
	var direction := -global_basis.z.normalized()
	for weapon in [weapon_main, weapon_off]:
		if not is_instance_valid(weapon): continue
		var shield: bool = weapon == weapon_off and gear.get("off", {}).get("wtype", "") == "shield"
		if weapon == weapon_main and main_wtype() == "staff": continue
		var neutral := Quaternion.from_euler(Vector3(0, 0, PI * 0.5) if shield else Vector3(-PI * 0.5, 0, 0))
		var desired := Quaternion(Vector3.FORWARD if shield else Vector3.UP, direction)
		var parent_rotation: Quaternion = weapon.get_parent().global_basis.orthonormalized().get_rotation_quaternion()
		weapon.quaternion = neutral.slerp(parent_rotation.inverse() * desired, amount)

func _apply(lhip: float, rhip: float, lknee: float, rknee: float, lsh: Vector3, rsh: Vector3, lel: float, rel: float, trx: float, tryy: float, by: float, hrx: float) -> void:
	var s := 18.0 * _dt
	s = clampf(s, 0.0, 1.0)
	if skill_style != "" and attack_t >= 0:
		s = 1.0
	leg_l.rotation.x = lerpf(leg_l.rotation.x, lhip, s)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, rhip, s)
	knee_l.rotation.x = lerpf(knee_l.rotation.x, lknee, s)
	knee_r.rotation.x = lerpf(knee_r.rotation.x, rknee, s)
	arm_l.rotation = arm_l.rotation.lerp(lsh, s)
	arm_r.rotation = arm_r.rotation.lerp(rsh, s)
	elbow_l.rotation.x = lerpf(elbow_l.rotation.x, lel, s)
	elbow_r.rotation.x = lerpf(elbow_r.rotation.x, rel, s)
	torso.rotation.x = lerpf(torso.rotation.x, trx, s)
	torso.rotation.y = lerpf(torso.rotation.y, tryy, s)
	body.position.y = lerpf(body.position.y, by, s)
	head.rotation.x = lerpf(head.rotation.x, hrx, s)

func height() -> float:
	return 1.62 * _scale_h
