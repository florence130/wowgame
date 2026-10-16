extends RefCounted
## Sanctum-only authored dressing. Clear walking axes and boss circles take priority.
const KIT := "res://assets/models/sanctum_unity_v2/kit/"
const LOCAL_LIGHT = preload("res://src/render/local_light.gd")
const SAVED_LIGHT = preload("res://src/render/sanctum_light.gd")
const FLOW = preload("res://src/data/data_sanctum_flow.gd")
const OCEAN = preload("res://tools/sanctum_ocean_dressing.gd")
const BLENDER_FINISH = preload("res://tools/sanctum_blender_finish.gd")
const WARM := Color("ffc88b")
const STONE := Color("aea58d")
const WOOD := Color("69513a")

static func raise_garden_eaves(model: Node3D) -> void:
	# Local Godot adaptation of the saved Unity eaves: retain solid roofs and
	# piers, but lift the two low garden galleries above the distant camera.
	var roofs := model.get_node_or_null("roofs") as MeshInstance3D
	if roofs==null:return
	var raised := ArrayMesh.new()
	for surface in roofs.mesh.get_surface_count():
		var arrays := roofs.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			var v := vertices[i]
			# glTF vertex compression shifts authored edges by a few millimetres.
			if v.x>=22.98 and v.x<=74.02 and v.z>=149.98 and v.z<=199.02 and v.y>=24.58 and v.y<=25.02:
				vertices[i].y+=6.0
		arrays[Mesh.ARRAY_VERTEX]=vertices
		raised.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		raised.surface_set_material(surface,roofs.mesh.surface_get_material(surface))
	roofs.mesh=raised
	# Extend the existing support rhythm to the new eave; no obstacle on paths.
	for x in range(28,65,8):
		U.add_mesh(model,U.box_mesh(Vector3(.85,6,.85)),OCEAN.material(STONE),Vector3(x,27.2,186.5))
	for z in range(156,185,8):
		U.add_mesh(model,U.box_mesh(Vector3(.85,6,.85)),OCEAN.material(STONE),Vector3(35.5,27.2,z))

static func architecture(model: Node3D) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "terrain": continue
		for i in mi.mesh.get_surface_count():
			var original: Material = mi.mesh.surface_get_material(i)
			var c: Color = original.albedo_color if original is StandardMaterial3D else Color.GRAY
			var mat: Material
			match String(mi.name):
				"walls", "detail":
					mat = OCEAN.material(Color("858975") if c.r < .5 else Color("c4bdab") if c.r > .7 else Color("aca590")).duplicate()
				"floor":
					mat = OCEAN.material(Color("8a816b") if c.g > c.r+.035 else Color("7d826f") if c.r < .48 else Color("aaa38e")).duplicate()
				"roofs", "buried_roofs": mat = OCEAN.material(Color("747d71") if mi.name == "buried_roofs" else Color("657988"))
				"props": mat = OCEAN.material(WOOD if c.r > c.g else Color("536544"))
			if mat:
				if mi.name in ["walls","detail","floor"]:
					mat.set_shader_parameter("joints_mode",1 if mi.name=="floor" else 2)
				# Exported meshes use world-space vertices and a shared zero origin.
				mat = mat.duplicate()
				mi.set_surface_override_material(i, mat)

static func prop(b: ZoneBuilder, kind: String, p: Vector3, size := Vector3.ONE, yaw := 0.0) -> Node3D:
	return b.prop(kind,p.x,p.z,yaw,size,STONE,Color("869366"),WOOD,0,"",0,"Props",p.y)

static func kit(parent: Node3D, id: String, p: Vector3, scale_v := Vector3.ONE, yaw := 0.0, collision := true) -> Node3D:
	var packed := load(KIT+id+".glb") as PackedScene
	if not packed: return null
	var root := packed.instantiate() as Node3D
	root.name = id+"_"+str(parent.get_child_count())
	root.position = p;root.scale=scale_v;root.rotation_degrees.y=yaw
	parent.add_child(root)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var original: Material = mi.mesh.surface_get_material(i)
			var name_m := original.resource_name.to_lower() if original else ""
			var mat: Material
			if "glow" in name_m: mat=U.mat(WARM,2.4)
			elif "wood" in name_m or "timber" in name_m: mat=OCEAN.material(WOOD.lightened(.12) if "dark" not in name_m else WOOD.darkened(.1))
			elif "iron" in name_m or "bronze" in name_m: mat=OCEAN.material(Color("686859"))
			else: mat=OCEAN.material(STONE)
			mi.set_surface_override_material(i,mat)
		if collision: mi.create_trimesh_collision()
	return root

static func illumination(parent: Node3D, p: Vector3, color: Color, reach: float, power: float) -> void:
	var light := LOCAL_LIGHT.attach(parent,p,color,reach,power)
	light.set_script(SAVED_LIGHT)
	light.set("authored_energy",power)

static func lamp(parent: Node3D, p: Vector3, scale_v := 1.3, reach := 14.0, power := 1.4) -> void:
	var fixture := kit(parent,"floor_lamp",p,Vector3.ONE*scale_v,0,false)
	if fixture: illumination(fixture,Vector3(0,1.5,0),WARM,reach,power)

static func strip(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	# Flush material strip, with no collision or rise under the player's feet.
	var delta := b-a
	var mesh := U.add_mesh(parent,U.box_mesh(Vector3(width,.018,Vector2(delta.x,delta.z).length())),OCEAN.material(color),(a+b)*.5+Vector3(0,.018,0))
	mesh.rotation.y=atan2(delta.x,delta.z)
	mesh.rotation.x=-atan2(delta.y,Vector2(delta.x,delta.z).length())
	mesh.name="PavingGuide_"+str(parent.get_child_count())

static func root_branch(parent: Node3D, points: Array, radius: float) -> void:
	# Authored root splines taper toward the garden. One mesh per branch, no
	# collision: the small surface roots do not create invisible capsule snags.
	var curve := Curve3D.new()
	curve.bake_interval=.65
	for i in points.size():
		var before: Vector3 = points[maxi(0,i-1)]
		var after: Vector3 = points[mini(points.size()-1,i+1)]
		var tangent := (after-before)*.18
		curve.add_point(points[i],-tangent if i>0 else Vector3.ZERO,tangent if i<points.size()-1 else Vector3.ZERO)
	var path := curve.get_baked_points()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in path.size():
		var tangent := (path[mini(i+1,path.size()-1)]-path[maxi(0,i-1)]).normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		var up := side.cross(tangent).normalized()
		var r := radius*lerpf(1,.06,float(i)/float(path.size()-1))
		for j in 9:
			var angle := float(j)/8.0*TAU
			var normal := side*cos(angle)+up*sin(angle)
			vertices.append(path[i]+normal*r)
			normals.append(normal)
			uv.append(Vector2(float(j)/8.0,float(i)*.23))
		if i==0:continue
		for j in 8:
			var a: int = (i-1)*9+j
			var b: int = i*9+j
			var c: int = i*9+j+1
			var d: int = (i-1)*9+j+1
			var reverse := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).dot(normals[a])>0
			indices.append_array(PackedInt32Array([a,c,b,a,d,c] if reverse else [a,b,c,a,c,d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance := U.add_mesh(parent,mesh,OCEAN.material(Color("494b38")))
	instance.name="GardenRoot_"+str(parent.get_child_count())

static func garden_tools(b: ZoneBuilder, x: float, y: float, z: float) -> void:
	var rack := Node3D.new()
	rack.name="GardenToolRack"
	b.groups.Props.add_child(rack)
	var wood := U.bmat(6,WOOD)
	var iron := U.bmat(7,Color("626862"))
	U.add_mesh(rack,U.box_mesh(Vector3(.16,.23,3.8)),wood,Vector3(x+4.8,y+1.8,z))
	for dz in [-1.1,0.0,1.1]:
		var bottom := Vector3(x+4.1,y+.45,z+dz)
		var top := Vector3(x+4.75,y+2.45,z+dz)
		var shaft := U.add_mesh(rack,U.cyl_mesh(.055,.065,(top-bottom).length(),8),wood,(top+bottom)*.5)
		shaft.basis=Basis(Quaternion(Vector3.UP,(top-bottom).normalized()))
		if dz<1:
			# Flattened spade blade, with a short collar joining the handle.
			U.add_mesh(rack,U.box_mesh(Vector3(.09,.56,.38)),iron,Vector3(x+4.02,y+.29,z+dz),Vector3(0,0,-12))
		else:
			U.add_mesh(rack,U.box_mesh(Vector3(.40,.12,.58)),iron,Vector3(x+4.0,y+.20,z+dz))
	# The rack is attached to the wall; its narrow collision stays off the axis.
	var body := StaticBody3D.new();rack.add_child(body)
	U.add_box_shape(body,Vector3(.75,2.5,3.8),Vector3(x+4.45,y+1.25,z))
	prop(b,"table",Vector3(x-3,y,z+2.5),Vector3(2.2,.95,1.2))
	prop(b,"flower_pot",Vector3(x-3,y+.95,z+2.5),Vector3(.6,.7,.6))

static func theme_traces(b: ZoneBuilder, d: Node3D) -> void:
	# Intrusion has two visible sources at the north garden wall, then follows
	# the retaining edge. Every large root stays outside the 28m boss circle.
	root_branch(d,[Vector3(24,20.5,122),Vector3(23,18.6,119),Vector3(19,18.3,122),Vector3(17.8,18.18,129),Vector3(18.8,18.10,133)],.65)
	root_branch(d,[Vector3(24,18.65,122),Vector3(28,18.22,117),Vector3(36,18.18,115.8),Vector3(43,18.07,116.5)],.48)
	root_branch(d,[Vector3(50,20.8,121),Vector3(52,18.6,120),Vector3(55,18.35,125),Vector3(57,18.14,132),Vector3(56,18.08,138)],.8)
	root_branch(d,[Vector3(50,18.75,121),Vector3(46,18.4,117),Vector3(42,18.13,115),Vector3(37,18.05,114.8)],.48)
	root_branch(d,[Vector3(52,18.45,121),Vector3(53,18.22,119),Vector3(56,18.10,121)],.24)
	# Dislodged coping occurs next to those roots, not as arbitrary rubble.
	for item in [[Vector3(23,18.2,118),Vector3(1.8,.4,.7),16.0],[Vector3(26,18.2,116.8),Vector3(1.2,.35,.8),-12.0],[Vector3(54.8,18.2,123),Vector3(1.5,.35,.7),22.0]]:
		var stone := U.add_mesh(d,U.box_mesh(item[1]),U.bmat(2,STONE.darkened(.2)),item[0])
		stone.rotation_degrees=Vector3(8,item[2],4)
	# Cart traffic explains the cellar's crossing and the uphill loading exit.
	var freight := [Vector2(106,126),Vector2(123,126),Vector2(126,126),Vector2(143,137),Vector2(150,142),Vector2(156,147)]
	for i in freight.size()-1:
		var a: Vector2=freight[i];var end: Vector2=freight[i+1]
		var side := (end-a).normalized().orthogonal()*.9
		for sign_v in [-1.0,1.0]:
			var prev: Vector2 = a+side*sign_v
			for j in range(1,9):
				var next: Vector2 = a.lerp(end,float(j)/8)+side*sign_v
				strip(d,Vector3(prev.x,FLOW.floor_y(prev,2),prev.y),Vector3(next.x,FLOW.floor_y(next,2),next.y),.13,Color("6d6c59"))
				prev=next
	# Drainage leads away from the freight apron; the hall retains a clean axis.
	for z in [118.0,121.0,124.0,127.0,130.0,133.0,136.0,139.0,142.0,145.0]:
		strip(d,Vector3(197,20,z),Vector3(197.8,20,z),.10,Color("56594e"))
	for z in [101.0,115.0,129.0]:
		for x in [89.0,119.0]:
			U.add_mesh(d,U.box_mesh(Vector3(1.6,.28,1.6)),U.bmat(9,STONE.darkened(.13)),Vector3(x,24.14,z))

static func build(b: ZoneBuilder) -> void:
	var d := Node3D.new();d.name="SanctumThemeDressing";b.groups.Props.add_child(d)
	# Arrival: the ruined central stair is the landmark; the lit western arcade is the viable turn.
	# Dry old offering stand; a working fountain contradicts century-long neglect.
	OCEAN.prayer_pedestal(d,Vector3(122,20,195),-20)
	for p in [Vector3(89,20,167),Vector3(119,20,168)]:
		prop(b,"tree",p,Vector3(3,7,3))
	for p in [Vector3(95,20,224),Vector3(113,20,215),Vector3(81,20,177),Vector3(71,18,194),Vector3(27,18,182)]: lamp(d,p)
	for z in [202.0,197.0,192.0]: strip(d,Vector3(97,20,z),Vector3(111,20,z),.2,Color("d0c1a0"))
	# Former prayer garden: votive remains are authored by the ocean kit below.
	for p in [Vector3(22,18,146),Vector3(54,18,120)]:
		prop(b,"wood_pile",p,Vector3(2.4,1.4,1.8),35)
	lamp(d,Vector3(54,18,138),1.5,16,1.6)
	# Underground freight: grouped wall bays, a broad free crossing and warm portal cues.
	for x in [98.0,102.0]:
		prop(b,"barrel",Vector3(x,8,109),Vector3(1.7,2.2,1.7))
	for z in [121.0,136.0]:
		prop(b,"crate",Vector3(123.5,8,z),Vector3(1.7,1.6,1.7))
	for p in [Vector3(75,8.75,116),Vector3(91,8,125),Vector3(116,8,139),Vector3(122,8,119),Vector3(133,11.5,126)]: lamp(d,p,1.5,18,1.8)
	for z in [117.0,134.0]:
		var chandelier := kit(d,"chandelier",Vector3(107,20.2,z),Vector3(2.3,2.3,2.3),0,false)
		if chandelier: illumination(chandelier,Vector3(0,-.6,0),WARM,22,2.5)
	strip(d,Vector3(96,8,125),Vector3(120,8,125),.3,Color("b4ac91"))
	strip(d,Vector3(127,8.5,128),Vector3(146,18,140),.3,Color("c2b28f"))
	# Service yard: cargo bays frame the arena; nothing fills its 28m combat circle.
	for p in [Vector3(157,20,151),Vector3(189,20,150),Vector3(193,20,125),Vector3(155,20,119)]:
		prop(b,"crate",p,Vector3(2.4,2,2.4))
	prop(b,"cart",Vector3(156,20,128),Vector3(2,1.4,2),90)
	prop(b,"barrel",Vector3(194,20,142),Vector3(2,2.3,2))
	prop(b,"sack",Vector3(193,20,145),Vector3(2,1.2,1.6))
	for p in [Vector3(152,20,144),Vector3(195,20,133),Vector3(179,20,114),Vector3(166,24,99)]: lamp(d,p,1.5,17,1.7)
	# Nave: two seated edges, repeated capitals and high pendants leave the axial view open.
	for z in [102.0,116.0,130.0]:
		for x in [91.0,117.0]:
			if z != 116.0:
				kit(d,"pew_2m",Vector3(89.5 if x<100 else 118.5,24,z),Vector3(2,1.5,1.5),90 if x<100 else -90)
	for p in [Vector3(90,24,136),Vector3(118,24,99),Vector3(81,24,87),Vector3(127,24,77),Vector3(87,24,49),Vector3(121,24,49),Vector3(95,24,34),Vector3(113,24,34)]: lamp(d,p,1.5,20,2.0)
	kit(d,"lectern",Vector3(120,24,64),Vector3.ONE*1.5,25)
	# End landmark: lamps mark the stair turn and frame the bell, outside the arena.
	for p in [Vector3(75,24,87),Vector3(59,27.4,74),Vector3(59,32,61),Vector3(22,32,44),Vector3(50,32,21)]: lamp(d,p,1.5,18,1.9)
	prop(b,"bell",Vector3(36,46,18),Vector3(4.2,4,4.2))
	theme_traces(b,d)
	OCEAN.build(d)
	BLENDER_FINISH.build(d)
