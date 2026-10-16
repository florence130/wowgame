extends RefCounted
## Finished nave geometry is fitted to the saved whitebox, not to a new layout.
const O = preload("res://tools/sanctum_ocean_dressing.gd")
const LIGHT = preload("res://src/render/sanctum_light.gd")
const STONE := Color("aaa38f")
const TRIM := Color("c4bdab")
const SHADE := Color("858573")
const BLUE := Color("627b8a")

static func box(parent: Node3D, size: Vector3, p: Vector3, c: Color, rot := Vector3.ZERO) -> void:
	O.box(parent,size,p,c,rot)

static func arc(parent: Node3D, p: Vector3, rx: float, ry: float, thickness: float, depth: float, yaw := 0.0) -> void:
	var node := Node3D.new();node.position=p;node.rotation_degrees.y=yaw;parent.add_child(node)
	for i in 16:
		var a := float(i)/16.0*PI;var b := float(i+1)/16.0*PI
		var outer_a := Vector3(cos(a)*rx,sin(a)*ry,0)
		var outer_b := Vector3(cos(b)*rx,sin(b)*ry,0)
		var inner_a := Vector3(cos(a)*(rx-thickness),sin(a)*(ry-thickness),0)
		var inner_b := Vector3(cos(b)*(rx-thickness),sin(b)*(ry-thickness),0)
		var tris: Array=[]
		for face in [-depth*.5,depth*.5]:
			var shift := Vector3(0,0,face)
			tris.append([outer_a+shift,outer_b+shift,inner_b+shift])
			tris.append([outer_a+shift,inner_b+shift,inner_a+shift])
		for pair in [[outer_a,outer_b],[inner_b,inner_a]]:
			var s := Vector3(0,0,depth*.5)
			tris.append([pair[0]-s,pair[0]+s,pair[1]+s])
			tris.append([pair[0]-s,pair[1]+s,pair[1]-s])
		O.mesh(node,tris,TRIM.darkened(.035*float(i%3)),"StoneVoussoir")

static func pier(parent: Node3D, p: Vector3) -> void:
	# Cover the existing 1.4m square piers with broad, physically readable faces.
	box(parent,Vector3(3.05,.34,3.05),p+Vector3(0,.17,0),SHADE)
	box(parent,Vector3(2.65,.50,2.65),p+Vector3(0,.59,0),TRIM)
	box(parent,Vector3(2.10,9.2,2.10),p+Vector3(0,5.44,0),STONE)
	box(parent,Vector3(2.38,.33,2.38),p+Vector3(0,10.20,0),SHADE)
	box(parent,Vector3(2.70,.50,2.70),p+Vector3(0,10.60,0),TRIM)
	box(parent,Vector3(2.20,2.55,2.20),p+Vector3(0,12.12,0),STONE)
	box(parent,Vector3(2.82,.42,2.82),p+Vector3(0,13.60,0),TRIM)
	# Broad patches, occasional missing edging: abandonment is in the silhouette.
	for item in [[Vector3(1.07,2.2,.25),Vector3(.03,2.6,.9)],[Vector3(-.4,.08,1.4),Vector3(.75,.15,.65)]]:
		box(parent,item[1],p+item[0],Color("8b9272"))

static func vault(parent: Node3D, z0: float, z1: float, center := 104.0, half := 13.0, spring := 35.2, rise := 4.25) -> void:
	for i in 20:
		var a := float(i)/20.0*PI;var b := float(i+1)/20.0*PI
		var va := Vector3(center+half*cos(a),spring+rise*sin(a),z0)
		var vb := Vector3(center+half*cos(b),spring+rise*sin(b),z0)
		var vc := Vector3(vb.x,vb.y,z1);var vd := Vector3(va.x,va.y,z1)
		O.mesh(parent,[[va,vb,vc],[va,vc,vd]],Color("777f80").lightened(.025*float(i%3)),"FacetedVaultSoffit")

static func high_window(parent: Node3D, p: Vector3, yaw: float) -> void:
	var node := Node3D.new();node.position=p;node.rotation_degrees.y=yaw;node.name="ClerestoryLightNiche";parent.add_child(node)
	# A sealed pale glass niche on the existing wall; no unbuilt exterior opening.
	box(node,Vector3(2.25,3.55,.15),Vector3(0,1.8,-.08),Color("526b76"))
	var glass := U.mat(Color("b3cfcd"),.55).duplicate() as StandardMaterial3D
	U.add_mesh(node,U.box_mesh(Vector3(1.48,2.65,.04)),glass,Vector3(0,1.65,.04))
	for x in [-1.0,1.0]:box(node,Vector3(.28,3.7,.5),Vector3(x,1.85,.18),TRIM)
	arc(node,Vector3(0,3.0,.18),1.15,.88,.23,.5)
	box(node,Vector3(2.50,.30,.75),Vector3(0,.13,.2),TRIM)
	box(node,Vector3(.10,2.65,.13),Vector3(0,1.65,.12),SHADE)

static func foliage(parent: Node3D, p: Vector3, size: float, seed_v: int) -> void:
	# Irregular contiguous leaf masses around roots, with no identical garland rhythm.
	for i in 18:
		var a := float(i)*2.399+float(seed_v)*.6
		var r := size*(.30+.12*float(i%5))
		var base := p+Vector3(cos(a)*r,.06+float(i%3)*.16,sin(a)*r)
		O.leaf(parent,base,size*(.8+.15*float(i%4)),rad_to_deg(a),-58+float(i%5)*20,Color("687e50").lightened(.04*float(i%3)))
	var points := [p+Vector3(-size,.1,.5),p+Vector3(-.4,.30,0),p+Vector3(.5,.24,-.3),p+Vector3(size,.08,-.7)]
	O.ivy(parent,points,size*.16,5)

static func paving(parent: Node3D) -> void:
	# Inset color faces on the original collision floor. No raised runway.
	box(parent,Vector3(6.6,.012,99),Vector3(104,24.045,86.5),Color("70828b"))
	for x in [99.55,108.45]:box(parent,Vector3(.52,.012,99),Vector3(x,24.047,86.5),BLUE)
	for z in [48.0,73.0,98.0,123.0]:O.wave(parent,Vector3(104,24.06,z),3.3,true)
	for z in range(42,139,4):
		for x in [94.5,98.0,110.0,113.5]:
			var color := Color("b1ad9b").darkened(.02*float((z+int(x))%4))
			var ox := .12*sin(float(z+x))
			box(parent,Vector3(3.2,.008,3.7),Vector3(x+ox,24.028,float(z)),color)

static func altar(parent: Node3D) -> void:
	# Keep platform depth behind the boss floor; the 28m circle remains at y24.
	box(parent,Vector3(11.6,.30,2.2),Vector3(104,24.15,34.1),SHADE)
	box(parent,Vector3(9.8,.45,1.6),Vector3(104,24.53,33.5),STONE)
	box(parent,Vector3(8.2,.42,1.25),Vector3(104,24.95,33.1),TRIM)
	box(parent,Vector3(10.8,12.2,.36),Vector3(104,31,31.6),SHADE)
	arc(parent,Vector3(104,31.8,32),6.0,6.9,.65,.65)
	O.shell(parent,Vector3(104,32.5,32.3),5.4)
	# A complete faceted silhouette instead of the previous tiny cone symbol.
	var statue := Node3D.new();statue.position=Vector3(104,25.2,33.1);statue.name="SeaGoddessStoneFigure";parent.add_child(statue)
	var stone := Color("c0c1b6")
	var robe: Array=[]
	for i in 10:
		var a := float(i)/10*TAU;var b := float(i+1)/10*TAU
		var pa := Vector3(cos(a)*1.55,0,sin(a)*.8)
		var pb := Vector3(cos(b)*1.55,0,sin(b)*.8)
		var ta := Vector3(cos(a)*.58,4.5,sin(a)*.40)
		var tb := Vector3(cos(b)*.58,4.5,sin(b)*.40)
		robe.append([pa,pb,tb]);robe.append([pa,tb,ta])
	O.mesh(statue,robe,stone,"FoldedStoneRobe")
	U.add_mesh(statue,U.cyl_mesh(.90,.58,1.55,8),O.material(stone),Vector3(0,5.2,0))
	U.add_mesh(statue,U.sphere_mesh(.58,1.22,false,10),O.material(stone),Vector3(0,6.6,.13))
	# Draped hair and lowered arms give a calm feminine silhouette at long range.
	box(statue,Vector3(1.15,1.6,.50),Vector3(0,6.12,-.30),stone.darkened(.08))
	for side in [-1.0,1.0]:
		var a := Vector3(side*.78,5.85,.12);var b := Vector3(side*1.24,4.18,.38)
		var arm := U.add_mesh(statue,U.cyl_mesh(.27,.35,(b-a).length(),8),O.material(stone),(a+b)*.5)
		arm.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
		U.add_mesh(statue,U.sphere_mesh(.25,.62,false,8),O.material(stone),b)
	O.votive_boat(parent,Vector3(101.1,25.20,33.8),-16,.7)
	O.votive_boat(parent,Vector3(106.8,25.20,33.8),12,.6,false)
	for x in [89.0,119.0]:
		O.banner(parent,Vector3(x,29,40),0,1.6)
		foliage(parent,Vector3(x,24,40),1.7,int(x))
	O.ivy(parent,[Vector3(86,24.2,48),Vector3(88.3,26,43),Vector3(90.5,28,39),Vector3(91.2,32,37),Vector3(95,36,33)],.48,18)
	O.ivy(parent,[Vector3(122,24.2,48),Vector3(120,25.2,43),Vector3(119,29,39),Vector3(117,33,37),Vector3(114,35.6,33.5)],.60,19)

static func build(parent: Node3D) -> Node3D:
	var node := Node3D.new();node.name="FinishedSeaTempleNave";parent.add_child(node)
	paving(node)
	for z in [102.0,116.0,130.0]:
		for x in [91.0,117.0]:
			pier(node,Vector3(x,24,z))
			O.banner(node,Vector3(x+(1.12 if x<104 else -1.12),27.5,z+.1),90 if x<104 else -90,1.28)
			foliage(node,Vector3(x,24,z+1.6),1.45,int(x+z))
		arc(node,Vector3(104,35.2,z),13.1,4.25,.50,.72)
	vault(node,96,139)
	# Two side aisles retain the original doors, with thick longitudinal arcades.
	for x in [91.0,117.0]:
		for z in [109.0,123.0]:
			arc(node,Vector3(x,32.6,z),6.95,3.25,.65,1.45,90)
		for z in [109.0,123.0,136.0]:
			var inward := 1.0 if x<104 else -1.0
			high_window(node,Vector3(88.15 if x<104 else 119.85,34.1,z),90 if x<104 else -90)
			box(node,Vector3(.35,.45,41),Vector3(88.25 if x<104 else 119.75,33.3,118),TRIM)
			# Actual saved local light; participates in the normal world light budget.
			var light := LIGHT.new();light.position=Vector3(x+inward,34.5,z);light.light_color=Color("b9d4dd")
			light.omni_range=19;light.omni_attenuation=1.15;light.authored_energy=.65;light.light_energy=.65
			light.name="ClerestoryFill";node.add_child(light)
	altar(node)
	for p in [Vector3(87,24,68),Vector3(121,24,68),Vector3(86,24,85),Vector3(122,24,85)]:foliage(node,p,1.8,int(p.z+p.x))
	# Low fallen masonry and benches are deliberately confined to side bands.
	for p in [Vector3(90,24,108),Vector3(118,24,125),Vector3(86,24,55),Vector3(122,24,57)]:
		for i in 5:
			box(node,Vector3(.75+.2*float(i%2),.28+.18*float(i%3),.6),p+Vector3(sin(float(i)*2)*1.4,.20,cos(float(i)*1.7)*1.2),STONE.darkened(.08),Vector3(5,float(i)*27,7))
	O.batch_visuals(node)
	return node
