class_name WeaponModel
extends RefCounted
## 程序化武器模型。握持点在原点，武器沿 +Y 方向延伸（剑刃/杖身）。

static func make(t: String, c: Color, q: int = 1, c2: Color = Color("e8c27a")) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_" + t
	var metal := U.char_mat(c.lightened(0.2))
	var dark := U.char_mat(Color("4a3a2a"))
	var gold := U.char_mat(Color("e8c27a"))
	var glow_c = [Color("ffffff"), Color("ffffff"), Color("60ff60"), Color("60a0ff"), Color("d070ff"), Color("ffa040")][clampi(q, 0, 5)]
	match t:
		"rapier":
			U.add_mesh(root, U.cyl_mesh(0.018, 0.018, 0.14), dark, Vector3.ZERO)
			U.add_mesh(root, U.torus_mesh(0.055, 0.08, 12), gold, Vector3(0, 0.08, 0), Vector3(90, 0, 0))
			U.add_mesh(root, U.cyl_mesh(0.002, 0.012, 0.85, 6), metal, Vector3(0, 0.52, 0))
		"sword", "sword2":
			var big := t == "sword2"
			var bl := 0.85 if big else 0.62
			var bw := 0.085 if big else 0.06
			U.add_mesh(root, U.cyl_mesh(0.022, 0.022, 0.16 if not big else 0.28), dark, Vector3(0, 0.0, 0))
			U.add_mesh(root, U.box_mesh(Vector3(0.24 if big else 0.18, 0.035, 0.05)), gold, Vector3(0, 0.09 if not big else 0.15, 0))
			U.add_mesh(root, U.box_mesh(Vector3(bw, bl, 0.018)), metal, Vector3(0, (0.1 if not big else 0.16) + bl * 0.5, 0))
			U.add_mesh(root, U.prism_mesh(Vector3(bw, 0.1, 0.018)), metal, Vector3(0, (0.1 if not big else 0.16) + bl + 0.05, 0))
			U.add_mesh(root, U.sphere_mesh(0.03), gold, Vector3(0, -0.09 if not big else -0.15, 0))
			if q >= 2:
				U.add_mesh(root, U.box_mesh(Vector3(bw * 0.25, bl * 0.8, 0.02)), U.unshaded(glow_c), Vector3(0, (0.1 if not big else 0.16) + bl * 0.5, 0))
		"axe", "axe2":
			var big2 := t == "axe2"
			var hl := 0.95 if big2 else 0.6
			U.add_mesh(root, U.cyl_mesh(0.022, 0.026, hl), dark, Vector3(0, hl * 0.35, 0))
			U.add_mesh(root, U.box_mesh(Vector3(0.22 if big2 else 0.16, 0.2 if big2 else 0.15, 0.025)), metal, Vector3(0.09 if big2 else 0.07, hl * 0.78, 0))
			U.add_mesh(root, U.cyl_mesh(0.12 if big2 else 0.09, 0.12 if big2 else 0.09, 0.026, 12), metal, Vector3(0.17 if big2 else 0.13, hl * 0.78, 0), Vector3(90, 0, 0), Vector3(0.6, 1, 1.4))
			if big2:
				U.add_mesh(root, U.cyl_mesh(0.1, 0.1, 0.026, 12), metal, Vector3(-0.14, hl * 0.78, 0), Vector3(90, 0, 0), Vector3(0.6, 1, 1.4))
		"mace", "mace2", "wrench":
			var big3 := t == "mace2"
			var hl2 := 0.95 if big3 else 0.55
			U.add_mesh(root, U.cyl_mesh(0.022, 0.026, hl2), dark, Vector3(0, hl2 * 0.35, 0))
			if t == "wrench":
				U.add_mesh(root, U.torus_mesh(0.04, 0.08), metal, Vector3(0, hl2 * 0.8, 0), Vector3(90, 0, 0))
			else:
				U.add_mesh(root, U.sphere_mesh(0.1 if big3 else 0.075), metal, Vector3(0, hl2 * 0.8, 0))
				for i in 6:
					var a := i * TAU / 6.0
					U.add_mesh(root, U.cyl_mesh(0.0, 0.025, 0.07, 6), metal, Vector3(cos(a) * 0.08, hl2 * 0.8, sin(a) * 0.08), Vector3(0, -rad_to_deg(a), -90))
		"dagger":
			U.add_mesh(root, U.cyl_mesh(0.02, 0.02, 0.12), dark, Vector3(0, 0, 0))
			U.add_mesh(root, U.box_mesh(Vector3(0.11, 0.025, 0.04)), gold, Vector3(0, 0.07, 0))
			U.add_mesh(root, U.prism_mesh(Vector3(0.05, 0.32, 0.015)), metal, Vector3(0, 0.24, 0))
		"staff":
			U.add_mesh(root, U.cyl_mesh(0.025, 0.03, 1.5), U.char_mat(c.darkened(0.2)), Vector3(0, 0.2, 0))
			U.add_mesh(root, U.torus_mesh(0.06, 0.1), gold, Vector3(0, 0.98, 0), Vector3(0, 0, 90))
			U.add_mesh(root, U.sphere_mesh(0.07), U.unshaded(glow_c.lerp(Color("80c0ff"), 0.5), false), Vector3(0, 0.98, 0))
		"polearm", "spear":
			U.add_mesh(root, U.cyl_mesh(0.022, 0.025, 1.8), dark, Vector3(0, 0.35, 0))
			U.add_mesh(root, U.prism_mesh(Vector3(0.09, 0.3, 0.02)), metal, Vector3(0, 1.4, 0))
			if t == "polearm":
				U.add_mesh(root, U.box_mesh(Vector3(0.16, 0.14, 0.02)), metal, Vector3(0.07, 1.2, 0))
		"pick":
			U.add_mesh(root, U.cyl_mesh(0.022, 0.026, 0.7), dark, Vector3(0, 0.25, 0))
			U.add_mesh(root, U.cyl_mesh(0.01, 0.03, 0.4, 6), metal, Vector3(0, 0.58, 0), Vector3(0, 0, 90))
		"torch":
			U.add_mesh(root, U.cyl_mesh(0.025, 0.03, 0.5), dark, Vector3(0, 0.15, 0))
			U.add_mesh(root, U.sphere_mesh(0.07), U.unshaded(Color("ffa040")), Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1, 1.4, 1))
		"gun":
			# 枪身沿 +Y（握把在原点）
			U.add_mesh(root, U.box_mesh(Vector3(0.05, 0.45, 0.07)), U.char_mat(Color("6a4a30")), Vector3(0, -0.12, 0.02))
			U.add_mesh(root, U.cyl_mesh(0.022, 0.022, 0.6), U.char_mat(Color("5a5a62")), Vector3(0, 0.35, -0.02))
			U.add_mesh(root, U.cyl_mesh(0.035, 0.035, 0.12), gold, Vector3(0, 0.12, -0.02))
			U.add_mesh(root, U.cyl_mesh(0.03, 0.03, 0.05), U.unshaded(Color("80c0ff")), Vector3(0, 0.2, 0.025), Vector3(90, 0, 0))
		"bow":
			for i in 9:
				var a := (i - 4) * 0.2
				U.add_mesh(root, U.box_mesh(Vector3(0.025, 0.13, 0.03)), U.char_mat(c.darkened(0.1)), Vector3(0, sin(a) * 0.6, -cos(a) * 0.15 + 0.15), Vector3(-rad_to_deg(a), 0, 0))
			U.add_mesh(root, U.cyl_mesh(0.004, 0.004, 1.0), U.unshaded(Color("f0f0e0")), Vector3(0, 0, 0.17))
		"shield":
			U.add_mesh(root, U.cyl_mesh(0.24, 0.24, 0.04, 16), U.char_mat(c), Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, 1, 1.15))
			U.add_mesh(root, U.torus_mesh(0.21, 0.25, 16), U.char_mat(c2), Vector3(0, 0, -0.01), Vector3(90, 0, 0), Vector3(1, 1, 1.15))
			U.add_mesh(root, U.sphere_mesh(0.05), U.char_mat(c2), Vector3(0, 0, -0.03))
		"offhand":
			U.add_mesh(root, U.box_mesh(Vector3(0.16, 0.2, 0.05)), U.char_mat(c), Vector3(0, 0.05, 0))
			U.add_mesh(root, U.box_mesh(Vector3(0.14, 0.18, 0.052)), U.char_mat(Color("f0e8d0")), Vector3(0.012, 0.05, 0))
			U.add_mesh(root, U.sphere_mesh(0.025), U.unshaded(Color("80c0ff")), Vector3(0, 0.07, -0.03))
		_:
			U.add_mesh(root, U.box_mesh(Vector3(0.05, 0.5, 0.02)), metal, Vector3(0, 0.3, 0))
	U.merge_meshes(root, true)
	return root
