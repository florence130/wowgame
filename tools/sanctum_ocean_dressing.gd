extends RefCounted
## Authored sea-temple ornaments. Coordinates follow the approved whitebox.
## All additions are visual: existing architecture owns traversal/collision.
const STONE := Color("b8b19e")
const BLUE := Color("627b8a")
const ROOT := Color("515743")
const LEAF := Color("697f4c")
const WOOD := Color("756349")
static var _materials := {}

static func material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if _materials.has(key):return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://src/render/sanctum_flat.gdshader")
	mat.set_shader_parameter("base_color",color)
	_materials[key]=mat
	return mat

static func mesh(parent: Node3D, triangles: Array, color: Color, name_v: String, double_sided := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in triangles:
		var normal: Vector3 = (tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
		for point in tri:
			st.set_normal(normal)
			st.add_vertex(point)
	var mat := material(color)
	# Thin symbols/cloth use the local double-sided shader; solids remain closed.
	var instance := U.add_mesh(parent,st.commit(),mat)
	instance.name=name_v
	return instance

static func box(parent: Node3D, size: Vector3, p: Vector3, color: Color, rotation := Vector3.ZERO) -> MeshInstance3D:
	return U.add_mesh(parent,U.box_mesh(size),material(color),p,rotation)

static func line(parent: Node3D, points: Array, width: float, color: Color, floor_v := false) -> void:
	var triangles: Array=[]
	for i in points.size()-1:
		var a: Vector3=points[i];var b: Vector3=points[i+1]
		var side: Vector3=(b-a).normalized().cross(Vector3.UP if floor_v else Vector3.FORWARD)*width*.5
		triangles.append([a-side,b+side,b-side])
		triangles.append([a-side,a+side,b+side])
	mesh(parent,triangles,color,"WornWave",true)

static func wave(parent: Node3D, p: Vector3, width: float, floor_v := false) -> void:
	for row in 2:
		var points: Array=[]
		for i in 19:
			var x := (float(i)/18.0-.5)*width
			var y := sin(float(i)/18.0*TAU*1.5)*width*.10-float(row)*width*.21
			points.append(p+(Vector3(x,0,y) if floor_v else Vector3(x,y,0)))
		line(parent,points,width*.055,Color("b5baa9") if floor_v else Color("c4c2ab"),floor_v)

static func shell(parent: Node3D, p: Vector3, radius: float) -> Node3D:
	var node := Node3D.new();node.name="SeaGoddessShell";node.position=p;parent.add_child(node)
	# A seven-rib scallop silhouette rather than fine sculptural texture.
	for i in 7:
		var a := deg_to_rad(13.0+float(i)*22.0)
		var b := deg_to_rad(13.0+float(i+1)*22.0)
		var mid := (a+b)*.5
		var base := Vector3(0,-radius*.3,.18)
		var left := Vector3(cos(a)*radius,sin(a)*radius,0)
		var right := Vector3(cos(b)*radius,sin(b)*radius,0)
		var ridge := Vector3(cos(mid)*radius*.96,sin(mid)*radius*.96,.45)
		mesh(node,[[base,left,ridge],[base,ridge,right]],STONE.lightened(.06 if i%2==0 else 0.0),"ShellRib_%d"%i,true)
	box(node,Vector3(radius*.52,.34,.6),Vector3(0,-radius*.3,0),STONE)
	return node

static func banner(parent: Node3D, p: Vector3, yaw := 0.0, scale_v := 1.0) -> void:
	var node := Node3D.new();node.name="FadedVoyageBanner";node.position=p;node.rotation_degrees.y=yaw;node.scale=Vector3.ONE*scale_v;parent.add_child(node)
	box(node,Vector3(2.7,.12,.15),Vector3(0,4.2,0),WOOD)
	# Missing lower corner and a torn split are silhouette damage, not noise.
	var outline := [Vector3(-1.05,4.1,0),Vector3(1.05,4.1,0),Vector3(1.02,.4,.05),Vector3(.56,.12,.10),Vector3(.42,.63,.09),Vector3(.15,.18,.08),Vector3(-.82,.38,.04)]
	var triangles: Array=[]
	for i in range(1,outline.size()-1):triangles.append([outline[0],outline[i],outline[i+1]])
	mesh(node,triangles,BLUE,"TornFlatCloth",true)
	wave(node,Vector3(0,2.0,.14),1.38)
	var mark := shell(node,Vector3(0,3.07,.13),.42)
	mark.name="BannerShellMark"

static func votive_boat(parent: Node3D, p: Vector3, yaw := 0.0, scale_v := 1.0, sail := true) -> void:
	var node := Node3D.new();node.name="VoyageVotiveBoat";node.position=p;node.rotation_degrees.y=yaw;node.scale=Vector3.ONE*scale_v;parent.add_child(node)
	var stern := Vector3(-1.5,.6,0);var bow := Vector3(1.5,.8,0)
	var a := Vector3(-.8,.45,-.42);var b := Vector3(.9,.45,-.42)
	var c := Vector3(.9,.45,.42);var d := Vector3(-.8,.45,.42)
	var keel_a := Vector3(-.75,.05,0);var keel_b := Vector3(.9,.05,0)
	mesh(node,[[stern,a,keel_a],[a,b,keel_b],[a,keel_b,keel_a],[b,bow,keel_b],[bow,c,keel_b],[c,d,keel_a],[c,keel_a,keel_b],[d,stern,keel_a],[a,d,c],[a,c,b]],WOOD,"FacetedVotiveHull",true)
	if sail:
		box(node,Vector3(.1,1.8,.1),Vector3(-.12,1.3,0),WOOD.darkened(.15))
		mesh(node,[[Vector3(-.17,2.14,.02),Vector3(-.17,.92,.02),Vector3(.96,1.0,.02)]],Color("a9ac94"),"WeatheredVotiveSail",true)

static func leaf(parent: Node3D, p: Vector3, size_v: float, yaw: float, tilt: float, color: Color) -> void:
	var node := Node3D.new();node.position=p;node.rotation_degrees=Vector3(tilt,yaw,0);parent.add_child(node)
	var outline := [Vector3(0,0,0),Vector3(-.28,.22,0),Vector3(-.36,.52,0),Vector3(-.20,.83,0),Vector3(0,1,0),Vector3(.20,.83,0),Vector3(.36,.52,0),Vector3(.28,.22,0)]
	var ridge := Vector3(0,.5,.14)*size_v
	var lit: Array=[];var shade: Array=[]
	for i in outline.size():
		var tri := [outline[i]*size_v,ridge,outline[(i+1)%outline.size()]*size_v]
		if i<4:lit.append(tri)
		else:shade.append(tri)
	mesh(node,lit,color,"BroadIvyLeaf",true)
	mesh(node,shade,color.darkened(.10),"LeafShadowPlane",true)

static func ivy(parent: Node3D, points: Array, radius: float, leaves := 12) -> void:
	# Thick tapered polygon segments, anchored to a specified crack/edge path.
	var node := Node3D.new();node.name="AuthoredVine";parent.add_child(node)
	for i in points.size()-1:
		var a: Vector3=points[i];var b: Vector3=points[i+1]
		var r := radius*lerpf(1,.3,float(i)/float(points.size()-1))
		var stem := U.add_mesh(node,U.cyl_mesh(r*.65,r,(b-a).length(),6),material(ROOT),(a+b)*.5)
		stem.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	for i in leaves:
		var t := clampf((float(i)+sin(float(i)*2.3)*.24)/maxf(1.0,float(leaves-1)),0,1)
		var part := t*float(points.size()-1)
		var idx := mini(int(part),points.size()-2)
		var p: Vector3=points[idx].lerp(points[idx+1],part-float(idx))
		var side := -1.0 if i%2==0 else 1.0
		leaf(node,p+Vector3(side*radius*.45,0,radius*.40),radius*(1.5+float(i%4)*.23),side*42.0+sin(float(i)*1.7)*35.0,-45.0+float(i%5)*23.0,LEAF.lightened(float(i%3)*.04))

static func floor_seal(parent: Node3D, p: Vector3, radius: float) -> void:
	var node := Node3D.new();node.name="WornPrayerPaving";node.position=p;parent.add_child(node)
	# Inset in the existing floor; never becomes a raised obstacle or warning circle.
	for span_v in [[0,7],[9,19],[22,32]]:
		var points: Array=[]
		for i in range(span_v[0],span_v[1]+1):
			var a := float(i)/32.0*TAU
			points.append(Vector3(cos(a)*radius,.038,sin(a)*radius))
		line(node,points,.18,BLUE.darkened(.20),true)
	wave(node,Vector3(0,.043,.5),radius*1.15,true)

static func prayer_pedestal(parent: Node3D, p: Vector3, yaw := 0.0) -> void:
	var node := Node3D.new();node.name="AbandonedVotiveStand";node.position=p;node.rotation_degrees.y=yaw;parent.add_child(node)
	box(node,Vector3(2.5,.4,1.7),Vector3(0,.2,0),STONE.darkened(.08))
	box(node,Vector3(1.8,1.3,1.2),Vector3(0,1.05,0),STONE)
	box(node,Vector3(2.6,.24,1.7),Vector3(.07,1.78,0),STONE,Vector3(0,0,-3))
	votive_boat(node,Vector3(0,1.86,0),0,.65)
	wave(node,Vector3(0,1.1,.62),1.15)

static func arch_rib(parent: Node3D, z: float) -> void:
	var node := Node3D.new();node.name="NaveVaultRib";parent.add_child(node)
	for i in 14:
		var a := float(i)/14.0*PI;var b := float(i+1)/14.0*PI
		var pa := Vector3(104+15.35*cos(a),33.4+6.0*sin(a),z)
		var pb := Vector3(104+15.35*cos(b),33.4+6.0*sin(b),z)
		var beam := box(node,Vector3(.48,(pb-pa).length()+.08,.65),(pa+pb)*.5,STONE.darkened(.06))
		beam.basis=Basis(Quaternion(Vector3.UP,(pb-pa).normalized()))
	for x in [88.65,119.35]:
		box(node,Vector3(.70,9.1,.95),Vector3(x,28.55,z),STONE.darkened(.08))
		box(node,Vector3(1.05,.32,1.3),Vector3(x,24.16,z),STONE.darkened(.14))
		box(node,Vector3(1.04,.45,1.24),Vector3(x,33.2,z),STONE)

static func wall_bay(parent: Node3D, x: float, z: float, inward: float) -> void:
	# Blind arcades sit against the original side wall, without new openings.
	for side in [-1.0,1.0]:
		box(parent,Vector3(.22,6,.30),Vector3(x,28,z+side*4.2),STONE.darkened(.12))
	for i in 10:
		var a := float(i)/10.0*PI;var b := float(i+1)/10.0*PI
		var pa := Vector3(x,31+3.2*sin(a),z+4.2*cos(a))
		var pb := Vector3(x,31+3.2*sin(b),z+4.2*cos(b))
		var beam := box(parent,Vector3(.28,(pb-pa).length()+.04,.26),(pa+pb)*.5,STONE.darkened(.12))
		beam.basis=Basis(Quaternion(Vector3.UP,(pb-pa).normalized()))
	for dz in [-2.2,2.2]:
		# Quiet weathering patches are broad sculpted faces, not busy grunge.
		mesh(parent,[[Vector3(x+inward*.03,24.3,z+dz-1),Vector3(x+inward*.03,25.8,z+dz-.65),Vector3(x+inward*.03,24.8,z+dz+1)]],Color("899077"),"LowMossStain",true)

static func nave(parent: Node3D) -> void:
	var node := Node3D.new();node.name="OceanNave";parent.add_child(node)
	for z in [101.0,115.0,129.0]:
		wall_bay(node,88.06,z,1)
		wall_bay(node,119.94,z,-1)
	# Broad muted tide-disc gives the weathered relief a readable backing.
	var panel := U.add_mesh(node,U.cyl_mesh(6.6,6.6,.20,12),material(Color("7d908f")),Vector3(104,31.6,32.0),Vector3(90,0,0))
	panel.name="TideDiscBacking"
	# End-wall relief is behind the 28m boss arena, on the old altar wall.
	var relief := shell(node,Vector3(104,31.5,32.4),4.8)
	var goddess := Node3D.new();goddess.name="WeatheredSeaGoddessRelief";goddess.position=Vector3(104,26.2,33.2);node.add_child(goddess)
	U.add_mesh(goddess,U.cyl_mesh(.60,1.30,4.1,7),material(STONE.lightened(.14)),Vector3(0,2.05,.1))
	U.add_mesh(goddess,U.cyl_mesh(.68,.58,1.0,7),material(STONE.lightened(.14)),Vector3(0,4.55,.1))
	U.add_mesh(goddess,U.sphere_mesh(.53,1.08,false,8),material(STONE.lightened(.14)),Vector3(0,5.48,.28))
	for side in [-1.0,1.0]:
		var a := Vector3(side*.62,4.8,.18)
		var b := Vector3(side*1.15,4.0,.30)
		var arm := U.add_mesh(goddess,U.cyl_mesh(.19,.24,(b-a).length(),6),material(STONE.lightened(.08)),(a+b)*.5)
		arm.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
		U.add_mesh(goddess,U.sphere_mesh(.23,.48,false,6),material(STONE.lightened(.10)),b)
	box(node,Vector3(4.6,.55,2.4),Vector3(104,24.55,34.2),STONE)
	# A shallow plinth grounds the ceremonial relief against the back wall.
	box(node,Vector3(5.4,.50,1.3),Vector3(104,25.95,33.1),STONE.darkened(.12))
	votive_boat(node,Vector3(102.6,25,34.2),-12,.72)
	votive_boat(node,Vector3(105.4,25,34.2),18,.53,false)
	for x in [86.0,122.0]:
		banner(node,Vector3(x,27,45),18 if x<100 else -18,1.28 if x<100 else .94)
	for z in [103.0,117.0,131.0]:
		for x in [90.0,118.0]:
			banner(node,Vector3(x,29,z),45 if x<100 else -45,1.04)
	for item in [[Vector3(90,24,123),20.0],[Vector3(118,24,110),-20.0],[Vector3(87,24,65),15.0],[Vector3(121,24,65),-15.0]]:
		prayer_pedestal(node,item[0],item[1])
	floor_seal(node,Vector3(104,24,82),5.2)
	# Roots follow wall corners and altar sides, never the arena's centre.
	ivy(node,[Vector3(85.4,24.2,44),Vector3(87.6,25.3,42),Vector3(88.5,27.6,40.4),Vector3(91.3,30.8,38.1),Vector3(95,31.4,35),Vector3(95.8,33.8,34),Vector3(99,35,32)],.70,22)
	ivy(node,[Vector3(122.9,24.2,45),Vector3(120.7,26.5,43),Vector3(121,28.6,41.6),Vector3(118.8,29.5,38),Vector3(118.3,34,38)],.85,20)
	ivy(node,[Vector3(89.1,24.1,99),Vector3(89.1,25.4,101),Vector3(89.1,29,103),Vector3(89.1,33,104)],.48,12)
	ivy(node,[Vector3(118.9,24.1,119),Vector3(118.9,25.8,117),Vector3(118.9,30,115),Vector3(118.9,34,113)],.52,12)
	# Fallen pew pieces remain along the side seating band.
	for item in [[Vector3(90,24.32,114),23.0],[Vector3(117,24.34,132),-17.0]]:
		box(node,Vector3(3.4,.25,.6),item[0],WOOD,Vector3(8,item[1],12))
		relief.set_meta("theme","sea_goddess_voyage")
	for p in [Vector3(89.2,24.16,101),Vector3(118.9,24.16,118),Vector3(87,24.16,43),Vector3(121.8,24.16,44.8)]:
		box(node,Vector3(1.8,.30,.8),p,STONE.darkened(.18),Vector3(9,18,12))
		mesh(node,[[p+Vector3(-.8,-.11,-1.4),p+Vector3(.9,-.11,-.6),p+Vector3(.7,-.11,2.2)],[p+Vector3(-.8,-.11,-1.4),p+Vector3(.7,-.11,2.2),p+Vector3(-.7,-.11,1.6)]],Color("788168"),"RootDampPaving",true)

static func garden(parent: Node3D) -> void:
	var node := Node3D.new();node.name="VinePrayerCourt";parent.add_child(node)
	floor_seal(node,Vector3(38,18,134),6.0)
	prayer_pedestal(node,Vector3(23,18,143),45)
	prayer_pedestal(node,Vector3(52,18,119),-35)
	shell(node,Vector3(42,20.8,116),2.2)
	banner(node,Vector3(25,20,125),30,.95)
	banner(node,Vector3(54,20,142),-35,.9)
	ivy(node,[Vector3(18,18.2,135),Vector3(18,19,128),Vector3(21,21,122),Vector3(24,22.4,121)],.80,18)
	ivy(node,[Vector3(26,18.2,117),Vector3(33,18.25,115.7),Vector3(41,18.35,115),Vector3(44,19.4,115.7)],.62,18)
	ivy(node,[Vector3(57,18.15,136),Vector3(57.2,19.3,128),Vector3(54.8,21.2,123),Vector3(52,22.4,119.5)],.9,18)
	# Old inner prayer garden replaces maintained herb pots, outside the boss court.
	for item in [[Vector3(44,18,176),-10.0],[Vector3(54,18,172),12.0]]:
		prayer_pedestal(node,item[0],item[1])
	ivy(node,[Vector3(58,18.2,180),Vector3(58,20,176),Vector3(57.8,22.5,171)],.52,12)
	ivy(node,[Vector3(39,18.2,179),Vector3(40,18.25,174),Vector3(41,18.4,168)],.44,12)
	for p in [Vector3(25,18.22,120),Vector3(54,18.22,124)]:
		box(node,Vector3(1.6,.4,.7),p,STONE.darkened(.12),Vector3(8,18,5))

static func votive_room(parent: Node3D, p: Vector3) -> void:
	prayer_pedestal(parent,p+Vector3(0,0,-4))
	shell(parent,p+Vector3(0,2.6,-4.5),1.4)

static func build(parent: Node3D) -> void:
	garden(parent)
	rat_occupation(parent)
	architectural_finish(parent)
	# Many small leaf facets share a palette. Bake their transforms into a few
	# color meshes while retaining the authored room/ornament nodes for editing.
	for room_name in ["VinePrayerCourt","RatOfferingStores","RatDeliveryCourt","TempleArchitecturalFinish"]:
		batch_visuals(parent.get_node(room_name))

static func framed_arch(parent: Node3D, center: Vector3, half_width: float, spring_h: float, rise: float, yaw := 0.0) -> void:
	var arch := Node3D.new();arch.name="OldStoneArch";arch.position=center;arch.rotation_degrees.y=yaw;parent.add_child(arch)
	for x in [-half_width,half_width]:
		box(arch,Vector3(.65,spring_h,.8),Vector3(x,spring_h*.5,0),STONE.darkened(.12))
		box(arch,Vector3(1,.35,1.1),Vector3(x,.18,0),STONE.darkened(.18))
		box(arch,Vector3(.95,.4,1),Vector3(x,spring_h-.2,0),STONE)
	for i in 12:
		var a := float(i)/12*PI;var b := float(i+1)/12*PI
		var pa := Vector3(cos(a)*half_width,spring_h+sin(a)*rise,0)
		var pb := Vector3(cos(b)*half_width,spring_h+sin(b)*rise,0)
		var block := box(arch,Vector3(.58,(pb-pa).length()-.035,.85),(pa+pb)*.5,STONE.lightened(.045 if i%3==0 else 0))
		block.basis=Basis(Quaternion(Vector3.UP,(pb-pa).normalized()))

static func architectural_finish(parent: Node3D) -> void:
	var node := Node3D.new();node.name="TempleArchitecturalFinish";parent.add_child(node)
	# Underground vault rhythm, with supports tight against old storage walls.
	for z in [123.0,135.0]:framed_arch(node,Vector3(107,8,z),17.6,6.4,5.0)
	for p in [Vector3(94,8.1,140),Vector3(121,8.1,137),Vector3(91,8.1,131)]:
		box(node,Vector3(2.2,.18,1.6),p,Color("797b62"),Vector3(0,12,0))
		for i in 3:box(node,Vector3(.85,.35,.6),p+Vector3(float(i)*.65,.18,.7),STONE.darkened(.16),Vector3(8,float(i)*19,13))
	# Departure bell platform: temple origins remain visible under living roots.
	for p in [Vector3(25,32,16),Vector3(47,32,16),Vector3(20,32,43),Vector3(52,32,43)]:
		box(node,Vector3(1.8,.5,1.8),p+Vector3(0,.25,0),STONE.darkened(.12))
		box(node,Vector3(1.15,5,1.15),p+Vector3(0,3,0),STONE)
		box(node,Vector3(1.7,.4,1.7),p+Vector3(0,5.7,0),STONE)
	banner(node,Vector3(25,34,16.8),0,1.0)
	box(node,Vector3(6,4.6,.55),Vector3(36,35.4,12.8),STONE.darkened(.10))
	box(node,Vector3(6.6,.35,.85),Vector3(36,37.9,12.8),STONE)
	shell(node,Vector3(36,35.7,13.2),2.2)
	ivy(node,[Vector3(19,32.1,27),Vector3(20,33,22),Vector3(24,34,17),Vector3(25,37,16)],.8,24)
	ivy(node,[Vector3(51,32.1,40),Vector3(53,33,33),Vector3(52,35,26),Vector3(47,37,17)],.7,24)
	# Only edge fragments: main axis, staircase and boss circles remain clear.
	for item in [[Vector3(17.5,32.2,33),22.0],[Vector3(53,32.2,22),-12.0],[Vector3(86,24.2,47),20.0]]:
		box(node,Vector3(2.3,.45,1),item[0],STONE.darkened(.12),Vector3(9,item[1],7))

static func rat_shelter(parent: Node3D, p: Vector3, yaw: float) -> void:
	var hut := Node3D.new();hut.name="ScavengedRatNest";hut.position=p;hut.rotation_degrees.y=yaw;parent.add_child(hut)
	for x in [-1.7,1.7]:
		for z in [-1.2,1.2]:
			box(hut,Vector3(.16,2.9,.16),Vector3(x,1.45,z),WOOD,Vector3(0,0,5 if x<0 else -4))
	mesh(hut,[[Vector3(-2,2.6,-1.5),Vector3(2,2.9,-1.5),Vector3(1.8,2.3,1.5)],[Vector3(-2,2.6,-1.5),Vector3(1.8,2.3,1.5),Vector3(-1.8,2.4,1.5)]],BLUE.darkened(.22),"SalvagedVoyageCloth",true)
	for i in 5:
		box(hut,Vector3(.45,1.4+float(i%2)*.3,.13),Vector3(-1.45+float(i)*.7,.7,-1.15),WOOD.darkened(float(i%3)*.06),Vector3(0,0,-6+float(i)*3))
	for x in [-1.7,1.7]:
		for y in [1.1,2.3]:box(hut,Vector3(.25,.10,.25),Vector3(x,y,1.2),Color("a4936b"))
	U.add_mesh(hut,U.cyl_mesh(1.1,1.3,.18,9),material(Color("867452")),Vector3(0,.10,0))
	U.add_mesh(hut,U.sphere_mesh(.65,.40,false,8),material(Color("82755e")),Vector3(.4,.27,-.2))
	U.add_mesh(hut,U.cyl_mesh(.3,.5,.65,7),material(Color("8b7861")),Vector3(-1.2,.33,1.0))

static func offering_rack(parent: Node3D, p: Vector3, yaw: float) -> void:
	var rack := Node3D.new();rack.name="OldVotiveStorageRack";rack.position=p;rack.rotation_degrees.y=yaw;parent.add_child(rack)
	for x in [-1.7,1.7]:box(rack,Vector3(.18,3.6,.18),Vector3(x,1.8,0),WOOD.darkened(.1))
	for y in [.4,1.8,3.1]:
		box(rack,Vector3(3.7,.18,1.1),Vector3(0,y,0),WOOD)
		votive_boat(rack,Vector3(-.65,y+.12,0),12,.43,y<2)
		U.add_mesh(rack,U.cyl_mesh(.3,.22,.28,7),material(STONE.darkened(.15)),Vector3(.8,y+.24,0))

static func rat_occupation(parent: Node3D) -> void:
	var stores := Node3D.new();stores.name="RatOfferingStores";parent.add_child(stores)
	# Old offering storage, not another goddess sanctuary. Occupation sits in
	# perimeter bays; the freight crossing and uphill departure stay unobstructed.
	offering_rack(stores,Vector3(110,8,110),0)
	offering_rack(stores,Vector3(119.8,8,136),-90)
	rat_shelter(stores,Vector3(95,8,136),-28)
	rat_shelter(stores,Vector3(118,8,142),22)
	shell(stores,Vector3(107,12.2,108.4),1.3)
	banner(stores,Vector3(121.5,10,122),-65,.75)
	ivy(stores,[Vector3(87.5,8.1,129),Vector3(88.3,10,130),Vector3(90,13,133)],.42,12)
	for z in [119.0,134.0]:
		# Shallow wall piers articulate the high stores without narrowing paths.
		box(stores,Vector3(.55,10,.8),Vector3(125.3,13,z),STONE.darkened(.12))
	var court := Node3D.new();court.name="RatDeliveryCourt";parent.add_child(court)
	rat_shelter(court,Vector3(157,20,120),-18)
	rat_shelter(court,Vector3(191,20,149),160)
	offering_rack(court,Vector3(191,20,118),0)
	banner(court,Vector3(163,22,112.8),0,1.05)
	shell(court,Vector3(181,24.3,112.7),2.0)
	prayer_pedestal(court,Vector3(195,20,132),-80)
	ivy(court,[Vector3(151,20.1,122),Vector3(153,22,119),Vector3(158,24,114),Vector3(163,24.7,112.8)],.65,20)
	ivy(court,[Vector3(196.7,20.1,143),Vector3(196.8,21.6,137),Vector3(197,23,131)],.6,16)
	# Scavenged boat parts mark the old delivery function along the cargo edge.
	votive_boat(court,Vector3(188,20.2,153),-35,1.2,false)

static func batch_visuals(parent: Node3D) -> void:
	var groups := {}
	var instances := parent.find_children("*","MeshInstance3D",true,false)
	for mi: MeshInstance3D in instances:
		var mat: Material=mi.material_override
		if mat==null:continue
		var key := mat.get_instance_id()
		if not groups.has(key):
			var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key]={"tool":st,"material":mat}
		var transform_v := mi.transform
		var ancestor: Node=mi.get_parent()
		while ancestor!=parent:
			if ancestor is Node3D:transform_v=ancestor.transform*transform_v
			ancestor=ancestor.get_parent()
		var normal_basis := transform_v.basis.inverse().transposed()
		var tool: SurfaceTool=groups[key].tool
		for surface in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arr[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array=arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			for i in indices.size() if not indices.is_empty() else vertices.size():
				var index: int=indices[i] if not indices.is_empty() else i
				tool.set_normal((normal_basis*normals[index]).normalized())
				tool.add_vertex(transform_v*vertices[index])
	for mi: MeshInstance3D in instances:mi.free()
	for key in groups:
		var combined := U.add_mesh(parent,groups[key].tool.commit(),groups[key].material)
		combined.name="BakedOceanPalette_"+str(parent.get_child_count())
