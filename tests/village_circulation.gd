extends "res://tests/art_style.gd"
## Real static collision sweeps along the authored circulation centre lines.
## Teleporting between route starts is fixture setup, not traversal evidence.

func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	var zone:Zone=Game.world.zones.vale
	var routes:Array=zone.get_meta("mmo_road_paths",[])
	check(routes.size()==4,"four town connections available in normal entry")
	var rows:Array=[]
	for ri in routes.size():
		if "walk_only=true" in OS.get_cmdline_user_args():break
		var route:Array=routes[ri]
		var failures:Array=[]
		var walked:=0.0
		for i in range(1,route.size()):
			var a:Vector2=route[i-1];var b:Vector2=route[i]
			var from:=Vector3(a.x,U.ground_height(get_tree(),a.x,a.y,40)+.12,a.y)
			await Game.world._teleport_to(from)
			await get_tree().physics_frame
			Game.player.set_physics_process(false)
			var to:=Vector3(b.x,U.ground_height(get_tree(),b.x,b.y,40)+.12,b.y)
			var motion:=to-from
			var collision:=KinematicCollision3D.new()
			if Game.player.test_move(Transform3D(Game.player.global_basis,from),motion,collision):
				# A gentle terrain touch is expected with a capsule near a slope;
				# solid architecture/trees/props must never block the route.
				var collider:Node=collision.get_collider()
				var ancestor:Node=collider
				while ancestor and not ancestor is BrushTerrain:ancestor=ancestor.get_parent()
				if ancestor==null:
					failures.append({"segment":i,"collider":str(collision.get_collider().get_path())})
			walked+=a.distance_to(b)
		rows.append({"route":ri,"metres":walked,"points":route.map(func(p):return [p.x,p.y]),"static_blockers":failures})
		check(failures.is_empty(),"route %d capsule sweeps clear of architecture, props and trees"%ri)
	var walk_report:Dictionary={}
	if "walk=true" in OS.get_cmdline_user_args() and not routes.is_empty():
		walk_report=await walk_road(routes[0])
		check(walk_report.reached==routes[0].size(),"native forward input completes the southern town connection")
		check(walk_report.teleport_samples==0 and walk_report.maximum_ground_gap<1.5,"town walk has no teleport or unsupported fall")
	FileAccess.open(out+"/circulation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"routes":rows,"walk":walk_report},"\t"))
	if DisplayServer.get_name()!="headless":
		await capture("town_player_camera",435,500,0,9,-.25)
		await capture("town_south_road_camera",455,552,0,9,-.25)
		await capture("town_east_road_camera",512,470,90,9,-.25)
	get_tree().quit(1 if checks.any(func(c):return not c.pass) else 0)

func walk_road(route:Array)->Dictionary:
	var p:Player=Game.player
	var start:Vector2=route[0]
	await Game.world._teleport_to(Vector3(start.x,U.ground_height(get_tree(),start.x,start.y,40)+.1,start.y))
	p.set_physics_process(true)
	for key in ["move_forward","move_back","strafe_left","strafe_right","turn_left","turn_right","jump"]:Game.keybinds[key]=KEY_NONE
	Game.keybinds.move_forward=KEY_F13
	var key:=InputEventKey.new();key.keycode=KEY_F13;key.pressed=true
	Input.parse_input_event(key)
	var reached:=0;var elapsed:=0.0;var walked:=0.0;var max_gap:=0.0;var jumps:=0
	var last:=p.global_position
	while elapsed<80.0 and reached<route.size():
		await get_tree().physics_frame
		var dt:=get_physics_process_delta_time()
		elapsed+=dt
		var goal:Vector2=route[reached]
		var offset:=Vector2(p.global_position.x,p.global_position.z).distance_to(goal)
		if offset<.65:reached+=1
		else:p.face_towards(Vector3(goal.x,p.global_position.y,goal.y))
		var distance:=last.distance_to(p.global_position)
		if distance>3.0:jumps+=1
		walked+=distance;last=p.global_position
		var ground:=U.ground_height(get_tree(),last.x,last.z,last.y+8)
		max_gap=maxf(max_gap,absf(last.y-ground))
	key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
	return {"reached":reached,"waypoints":route.size(),"seconds":elapsed,"metres":walked,"teleport_samples":jumps,"maximum_ground_gap":max_gap}
