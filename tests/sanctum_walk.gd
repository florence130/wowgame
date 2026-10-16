extends Node
## Native Player input, collision, fall logic and existing three Ally followers.
## All gates unlocked and mobs frozen: traversal evidence only, not a combat clear.
var out_dir := "res://.shots/sanctum_walk"
var visual := false
var focus := ""
var ready_time := 0.0
var started := false
var index := 0
var elapsed := 0.0
var segment_time := 0.0
var settle := 0.0
var sample_time := 0.0
var failed := 0
var samples: Array = []
var arrivals: Array = []
var previous := {}
var teleport_count := 0
var max_lag := 0.0
var player_last := Vector3.INF
var player_distance := 0.0
var player_teleports := 0
var routes: Array = []
var moving := false
var scene_resource: PackedScene

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out_dir = arg.substr(4)
		if arg == "visual=true": visual = true
		if arg.begins_with("focus="):focus=arg.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Game.new_character("圣堂行走检查", "warrior", DB.random_appearance(7,"f"))
	Game.slot_index = -1
	Game.pd["new"] = false
	Game.pd["level"] = 15
	Game.pd["zone"] = "sanctum"
	Game.pd["pos"] = Vector3(104,20.1,239)
	for flag in ["sanctum_ember_root", "sanctum_ember_lake", "sanctum_ember_nave"]:
		Game.pd["flags"][flag] = true
	for key in ["move_forward","move_back","strafe_left","strafe_right","turn_left","turn_right","jump"]:
		Game.keybinds[key] = KEY_NONE
	Game.keybinds["move_forward"] = KEY_F13
	# Prime the material resource before the large scene's threaded dependencies.
	U.bmat(2,Color.GRAY)
	scene_resource = load("res://scenes/zones/windwhisper_sanctum.tscn")
	# One continuous journey, including every optional room and the return from the bell.
	_add(0, [[104,219],[94,220],[85,220,"empty_gate"],[94,220],[104,219],[104,184],[120,184],[136,184],[148,184,"votive"],[136,184],[120,184],[104,184],[80,183]])
	_add(1, [[68,183],[68,192],[46,192],[46,200],[46,208,"tools"],[46,200],[46,192],[30,192],[30,158],[30,138],[16,138],[6,138,"hermit"],[16,138],[30,138],[38,152],[38,134,"garden"]])
	_add(2, [[64,130],[72,130],[72,115],[72,112],[84,112],[84,103],[86,91,"crypt"],[84,103],[84,112],[106,112],[106,126,"cellar"],[105,132],[105,140],[105,150,"empty_brew"],[105,140],[105,132],[106,126],[124,126],[126,126],[145,138],[151,142],[172,134,"yard"],[184,134],[200,133],[209,133,"ledger"],[200,133],[184,134],[172,134]])
	_add(3, [[172,106],[172,88],[186,88],[195,88,"dorm"],[186,88],[172,88],[172,84],[143,84],[104,84],[104,118],[104,106],[86,106],[79,105,"chapel"],[86,106],[104,106],[104,84],[104,50,"altar"]])
	_add(4, [[104,84],[78,84],[64,84],[64,62],[48,46],[36,32,"bell"],[48,46],[64,62],[64,84],[78,84],[104,84,"return_nave"]])
	if focus=="tools":
		routes.clear()
		Game.pd["pos"]=Vector3(46,18.1,192)
		_add(1,[[46,192],[46,200],[46,208,"tools_detail"],[46,200],[46,192,"tools_return"]])
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")

func _add(phase: int, points: Array) -> void:
	for p in points:
		routes.append({"x":float(p[0]),"z":float(p[1]),"phase":phase,"name":str(p[2]) if p.size()>2 else ""})

func _input_forward(value: bool) -> void:
	if moving == value: return
	moving = value
	var event := InputEventKey.new()
	event.keycode = KEY_F13
	event.pressed = value
	Input.parse_input_event(event)

func _physics_process(delta: float) -> void:
	if not has_meta("runner"): return
	ready_time += delta
	if not Game.world or not is_instance_valid(Game.world.player):
		if ready_time>120: _finish("world load timeout")
		return
	var p: Player = Game.world.player
	if not started:
		# Freeze from the first populated frame. A branch-only start may be
		# inside an encounter; letting it run during warmup corrupts the test.
		for mob in get_tree().get_nodes_in_group("mobs"):
			mob.set_physics_process(false)
			mob.threat.clear()
			mob.leave_combat()
		p.target=null
		p.leave_combat()
		for ally in get_tree().get_nodes_in_group("allies"):
			ally.target=null
			ally.leave_combat()
	if not Game.world.ground_ready(p.global_position): return
	if not started:
		if ready_time < 5: return
		started = true
		p.set_process_unhandled_input(false)
		p.cam_dist_target = 16
		p.cam_dist = 16
		p.cam_pitch = -.4
		Game.time_of_day = 11
		Game.world.weather = "clear"
		Game.world.weather_amt = 0
		Game.world.weather_t = 9999
		Game.world.hud.hide()
		for mob in get_tree().get_nodes_in_group("mobs"): mob.set_physics_process(false)
		for hud in get_tree().get_nodes_in_group("hud"): hud.hide()
		print("WALK START ",routes.size()," waypoints; allies=",get_tree().get_nodes_in_group("allies").size())
		if get_tree().get_nodes_in_group("allies").size()!=3:
			_finish("expected exactly three active companions")
			return
	elapsed += delta
	segment_time += delta
	_sample(p,delta)
	if p.dead or p.global_position.y < 3:
		_finish("player dead/fell")
		return
	if index >= routes.size():
		_finish("")
		return
	var wp: Dictionary = routes[index]
	var target_y := SanctumFlow.floor_y(Vector2(wp.x,wp.z),wp.phase)
	var target := Vector3(wp.x,target_y,wp.z)
	var diff := target-p.global_position
	diff.y=0
	if diff.length()<.65:
		_input_forward(false)
		settle += delta
		var waiting := 2.5 if wp.name != "" else .05
		if settle < waiting: return
		var lag := _lag(p)
		var entry := {"i":index,"name":wp.name,"phase":wp.phase,"position":_vec(p.global_position),"target_y":target_y,"lag":lag,"camera":p.spring.get_hit_length(),"time":elapsed}
		arrivals.append(entry)
		if absf(p.global_position.y-target_y)>1: failed += 1;entry["height_failure"]=true
		if wp.name != "":
			print("WALK ARRIVE ",wp.name," y=",p.global_position.y," lag=",lag," cam=",p.spring.get_hit_length())
			if lag>12: failed+=1;entry["party_failure"]=true
			if visual: _shot(wp.name)
		index+=1;segment_time=0;settle=0
		return
	settle=0
	if segment_time>22:
		_finish("stuck at waypoint %d (%s), position %s" % [index,wp.name,p.global_position])
		return
	p.rotation.y=atan2(-diff.x,-diff.z)
	_input_forward(true)

func _lag(p: Player) -> float:
	var lag := 0.0
	for ally in get_tree().get_nodes_in_group("allies"):
		lag=maxf(lag,ally.global_position.distance_to(p.global_position))
	return lag

func _sample(p: Player,delta: float) -> void:
	if player_last.is_finite():
		var distance := p.global_position.distance_to(player_last)
		player_distance+=distance
		if distance>8:player_teleports+=1
	player_last=p.global_position
	for ally in get_tree().get_nodes_in_group("allies"):
		var id := str(ally.ally_id)
		if previous.has(id) and ally.global_position.distance_to(previous[id])>8:
			teleport_count+=1
		previous[id]=ally.global_position
	max_lag=maxf(max_lag,_lag(p))
	sample_time+=delta
	if sample_time<.25:return
	sample_time=0
	var party := []
	for ally in get_tree().get_nodes_in_group("allies"):
		party.append({"id":ally.ally_id,"position":_vec(ally.global_position)})
	samples.append({"t":elapsed,"i":index,"position":_vec(p.global_position),"floor":p.is_on_floor(),"camera":p.spring.get_hit_length(),"party":party})

func _vec(v: Vector3) -> Array:
	return [snappedf(v.x,.001),snappedf(v.y,.001),snappedf(v.z,.001)]

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out_dir)+"/%02d_%s.png" % [index,label])

func _finish(reason: String) -> void:
	_input_forward(false)
	if reason!="":failed+=1
	if teleport_count>0 or player_teleports>0:failed+=1
	var report := {"kind":"native_player_party_walk_noncombat","conditions":{"mobs_frozen":true,"all_seeds_granted":true,"normal_roof_collision":true,"normal_player_physics":true,"native_allies":3,"camera_target_m":16},"reason":reason,"failed":failed,"waypoints":routes.size(),"arrived":arrivals.size(),"elapsed_sim_seconds":elapsed,"walked_distance_m":player_distance,"player_teleports":player_teleports,"max_party_lag":max_lag,"party_teleports":teleport_count,"arrivals":arrivals,"samples":samples}
	FileAccess.open(out_dir+"/walk_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WALK DONE failed=",failed," arrived=",arrivals.size(),"/",routes.size()," teleports=",teleport_count," reason=",reason)
	get_tree().quit(0 if failed==0 else 1)
