extends Node3D
## Continuous route and room orbit clearance against actual saved collisions.
## Gates unlocked and scene AI disabled: spatial evidence, not combat.
const FLOW = preload("res://src/data/data_sanctum_flow.gd")
var out_dir := "res://.shots/sanctum_camera_audit"
var scene_path := "res://scenes/zones/windwhisper_sanctum.tscn"
var samples: Array=[]

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):out_dir=arg.substr(4)
		if arg.begins_with("scene="):
			push_error("旧版地图选择入口已移除")
			get_tree().quit(2)
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Game.new_character("圣堂连续镜头空间检查","warrior",DB.random_appearance(7,"f"));Game.slot_index=-1
	for flag in ["sanctum_ember_root","sanctum_ember_lake","sanctum_ember_nave","sanctum_final_open"]:Game.pd["flags"][flag]=true
	var zone:Node3D=load(scene_path).instantiate();add_child(zone)
	for frame in 3:await get_tree().physics_frame
	# PROCESS_MODE_DISABLED removes inherited CollisionObject3D bodies from
	# physics by default. Freeze scripts while keeping real walls/roofs active.
	zone.set_process(false);zone.set_physics_process(false)
	for node in zone.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new();sphere.radius=.25
	for phase in FLOW.layout().route:
		for i in phase.points3.size()-1:
			var aa=phase.points3[i];var bb=phase.points3[i+1]
			var a:=Vector3(aa[0],aa[1],aa[2]);var b:=Vector3(bb[0],bb[1],bb[2])
			var steps:=maxi(1,int(ceil(a.distance_to(b)/2.5)))
			var yaw:=atan2(-(b-a).x,-(b-a).z)
			for j in steps+1:
				var p:=a.lerp(b,float(j)/steps)
				p.y=FLOW.floor_y(Vector2(p.x,p.z),int(phase.phase))
				for pitch in [-.4,-.65]:
					for heading in [yaw,yaw+PI]:probe(space,sphere,p+Vector3.UP*1.55,heading,pitch,"route",String(phase.name)+"_"+str(i),int(phase.phase))
	# Every principal arena: centre and eight positions 7m from it, full orbit.
	for boss in FLOW.layout().bosses:
		for ring in 9:
			var p:=Vector3(boss.point[0],boss.level+1.55,boss.point[1])
			if ring>0:p+=Vector3(cos(float(ring-1)*TAU/8),0,sin(float(ring-1)*TAU/8))*7
			for yaw_step in 12:
				for pitch in [-.4,-.65]:probe(space,sphere,p,float(yaw_step)*TAU/12,pitch,"arena",String(boss.section),int(boss.number))
	# Optional rooms: centre with full orbit. Small side rooms may contract but
	# must retain a useful tactical view, without approaching a first-person lens.
	for room in FLOW.layout().side_rooms:
		var p:=Vector3(room.center[0],room.level+1.55,room.center[1])
		for yaw_step in 12:probe(space,sphere,p,float(yaw_step)*TAU/12,-.4,"side",String(room.id),int(room.phase))
	var report:={"kind":"saved_scene_continuous_camera_clearance","scene":scene_path,"conditions":{"gates_open":true,"AI_disabled":true,"sphere_radius":.25,"margin":.3,"distance":16,"route_spacing_max_m":2.5,"pitches":[-.4,-.65],"route_forward_and_reverse":true,"arena_orbits":12},"samples":samples}
	FileAccess.open(out_dir+"/camera_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAMERA AUDIT ",samples.size()," samples saved ",out_dir)
	get_tree().quit()

func probe(space:PhysicsDirectSpaceState3D,sphere:SphereShape3D,p:Vector3,yaw:float,pitch:float,kind:String,label:String,phase:int) -> void:
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=sphere;query.collision_mask=1
	query.transform=Transform3D(Basis.IDENTITY,p)
	query.motion=Basis.from_euler(Vector3(pitch,yaw,0))*Vector3.BACK*16
	var fraction:=space.cast_motion(query)
	var length:=16.0 if fraction[0]>=1 else maxf(0,16*fraction[0]-.3)
	var collider:="";var hit:=Vector3.ZERO
	if length<15.6:
		query.transform.origin=p+query.motion*minf(1,fraction[1]+.015);query.motion=Vector3.ZERO
		var info:=space.get_rest_info(query)
		if not info.is_empty():
			var node:=instance_from_id(info.collider_id) as Node
			collider=String(node.get_path()) if node else "unknown";hit=info.point
		if collider.is_empty():
			var ray:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p,p+Basis.from_euler(Vector3(pitch,yaw,0))*Vector3.BACK*16,1))
			if not ray.is_empty():collider=String(ray.collider.get_path());hit=ray.position
	samples.append({"kind":kind,"label":label,"phase":phase,"pivot":[p.x,p.y,p.z],"yaw":yaw,"pitch":pitch,"length":length,"collider":collider,"hit":[hit.x,hit.y,hit.z]})
