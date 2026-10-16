extends RefCounted
const MODEL := "res://assets/models/sanctum_blender_ruin/sea_temple_ruin.glb"
const RIG = preload("res://src/render/sanctum_window_rig.gd")

static func build(parent: Node3D) -> void:
	var packed := load(MODEL) as PackedScene
	assert(packed!=null,"Build/import the Blender sea temple before generating sanctum")
	var model := packed.instantiate() as Node3D
	model.name="BlenderSeaTempleRuin";parent.add_child(model)
	for mi in model.find_children("*","MeshInstance3D",true,false):
		if String(mi.name).begins_with("Solid_Pier_"):
			mi.create_trimesh_collision()
	var rig := RIG.new();rig.name="SeaTempleWindowRig";parent.add_child(rig)
	for x in [89.3,118.7]:
		for z in [109.0,123.0,136.0]:
			window(rig,Vector3(x,39.5,z),Vector3(105 if x<104 else 103,24.0,z-7),4.2,Color("ccdce5"),55.0,40.0)
	# Soft high keys continue past the crossing and shape the sculpted altar.
	for p in [Vector3(88.8,46,65),Vector3(119.2,46,65),Vector3(96,50,40),Vector3(112,50,40)]:
		window(rig,p,Vector3(104,34,40 if p.z<50 else 59),3.6,Color("d6dfda"),56.0,44.0)

static func window(rig: Node3D, p: Vector3, target: Vector3, energy: float, color: Color, radius: float, angle: float) -> void:
	var light := SpotLight3D.new();rig.add_child(light)
	light.name="WindowKey_"+str(rig.get_child_count());light.position=p
	# Construction happens outside a SceneTree, so calculate local rotation.
	light.basis=Basis.looking_at((target-p).normalized())
	light.light_color=color;light.light_energy=energy
	light.spot_range=radius;light.spot_angle=angle;light.spot_attenuation=.65;light.spot_angle_attenuation=.85
	light.shadow_enabled=true;light.shadow_bias=.025;light.shadow_normal_bias=.35;light.shadow_blur=1.6
	light.light_volumetric_fog_energy=.0
