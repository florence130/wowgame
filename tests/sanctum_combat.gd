extends Node
## Continuous native movement + ordinary combat APIs. No granted seeds, kill
## commands, repositioning, invulnerability, healing injection or frozen mobs.
const CURRENT_DATA := "res://assets/models/sanctum_v2/sanctum_data.json"
var current_layout: Dictionary
const BOSS_IDS := ["boss_rootguard","boss_lake","boss_sanctum_lantern","boss_victor"]
var scene_resource: PackedScene
var out_dir := "res://.shots/sanctum_combat"
var visual := false
var allow_bell := false
var run_seed := 17
var loaded := 0.0
var active := false
var elapsed := 0.0
var index := 0
var route: Array = []
var moving := false
var segment_time := 0.0
var spell_time := 0.0
var sample_time := 0.0
var samples: Array = []
var events: Array = []
var kills: Array = []
var encounters := {}
var observed := {}
var last_positions := {}
var teleports := 0
var walked := 0.0
var death_count := 0
var cast_counts := {}
var cast_outcomes := {}
var gate_flags := {}
var locked_path_errors := 0
var regrouping := false
var regroup_time := 0.0

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new();runner.set_script(get_script());runner.set_meta("runner",true)
		get_tree().root.add_child.call_deferred(runner)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):out_dir=arg.substr(4)
		if arg.begins_with("seed="):run_seed=int(arg.substr(5))
		if arg=="visual=true":visual=true
		if arg=="allow_bell=true":allow_bell=true
	seed(run_seed)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Game.new_character("圣堂战斗检查","warrior",DB.random_appearance(7,"f"))
	Game.slot_index=-1
	Game.pd["level"]=15;Game.pd["zone"]="sanctum";Game.pd["new"]=false
	current_layout = JSON.parse_string(FileAccess.get_file_as_string(CURRENT_DATA))
	var start: Dictionary = current_layout.start
	Game.pd["pos"]=Vector3(start.x, start.y + 0.1, start.z)
	Game.pd["flags"]={}
	# Explicit representative level-15 equipment fixture, using real item stats.
	for slot in ["head","chest","wrist","hands","waist","legs","feet"]:
		Game.pd["equip"][slot]="gen|%s|mail|green|15|bear" % slot
	Game.pd["equip"]["back"]="gen|back|cloth|green|15|bear"
	Game.pd["equip"]["main"]="gen|sword|green|15|bear"
	Game.pd["equip"]["off"]="gen|shield|green|15|bear"
	for id in DB.classes.warrior.spells:
		var rank := 0
		while DB.spell_rank_level(id,rank+1)<=15:rank+=1
		if rank>0:Game.pd["spells"][id]=rank
	Specs.choose("paladin", true)
	for key in ["move_forward","move_back","strafe_left","strafe_right","turn_left","turn_right","jump"]:Game.keybinds[key]=KEY_NONE
	Game.keybinds.move_forward=KEY_F13
	U.bmat(2,Color.GRAY)
	scene_resource=load("res://scenes/zones/windwhisper_sanctum.tscn")
	var route_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sanctum_route_current.json"))
	for waypoint in route_data.waypoints:
		var pt: Array = waypoint.position
		route.append({"position":Vector3(pt[0],pt[1],pt[2]),"phase":int(waypoint.phase)})
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")

func forward(value: bool) -> void:
	if moving==value:return
	moving=value
	var event:=InputEventKey.new();event.keycode=KEY_F13;event.pressed=value
	Input.parse_input_event(event)

func _physics_process(delta: float) -> void:
	if not has_meta("runner"):return
	loaded+=delta
	if not Game.world or not is_instance_valid(Game.world.player):
		if loaded>120:finish("load timeout")
		return
	var p: Player=Game.world.player
	if not Game.world.ground_ready(p.global_position):return
	if not active:
		if loaded<5:return
		active=true
		p.set_process_unhandled_input(false)
		p.cam_dist=16;p.cam_dist_target=16;p.cam_pitch=-.4
		Game.time_of_day=11
		Game.world.weather="clear";Game.world.weather_amt=0;Game.world.weather_t=9999
		if get_tree().get_nodes_in_group("allies").size()!=3:finish("missing native companions");return
		print("COMBAT START seed=",run_seed," hp=",p.max_hp," armor=",p.stats.get("armor")," gear=",Game.pd.equip)
	elapsed+=delta
	observe(p,delta)
	if p.dead:finish("player death");return
	if p.global_position.y < -5.0:finish("player fell below the island");return
	if elapsed>1800:finish("run time limit");return
	var enemies:=engaged(p)
	if not enemies.is_empty():
		regrouping = true
		regroup_time = 0.0
		segment_time=0
		fight(p,enemies,delta)
		return
	if is_instance_valid(p.target) and p.target.dead:p.set_target(null)
	if regrouping:
		regroup_time += delta
		var together := true
		for ally in get_tree().get_nodes_in_group("allies"):
			if ally.dead or ally.global_position.distance_to(p.global_position) > 12.0:
				together = false
		if not together or p.hp < p.max_hp * .78:
			forward(false)
			if regroup_time > 35.0:
				finish("party could not regroup after combat");return
			return
		regrouping = false
	if index>=route.size():
		var bosses:=kills.filter(func(k):return k.boss)
		var missing := []
		for pull in current_layout.pulls:
			if kills.filter(func(k):return k.room==pull.id).size()<pull.mobs.size():missing.append(pull.id)
		finish("" if bosses.size()==4 and Game.has_flag("sanctum_final_open") and missing.is_empty() else "incomplete clear; missing pulls %s" % str(missing))
		return
	var wp:Dictionary=route[index]
	if int(wp.phase)>=2 and not Game.has_flag("sanctum_ember_root"):locked_path_errors+=1;finish("reached basement route without root seed");return
	if int(wp.phase)>=3 and not Game.has_flag("sanctum_ember_lake"):locked_path_errors+=1;finish("reached nave route without lake seed");return
	if int(wp.phase)>=4 and not Game.has_flag("sanctum_final_open"):locked_path_errors+=1;finish("reached final route without three seeds");return
	segment_time+=delta
	var diff:Vector3=wp.position-p.global_position;diff.y=0
	if diff.length()<.7:
		forward(false)
		events.append({"kind":"waypoint","i":index,"t":elapsed,"position":vec(p.global_position)})
		print("COMBAT WAYPOINT ",index," phase=",wp.phase," hp=",snappedf(p.hp,.1))
		index+=1;segment_time=0
		return
	if segment_time>25:
		var contacts := []
		for ci in p.get_slide_collision_count():
			var contact := p.get_slide_collision(ci)
			var collider := contact.get_collider()
			contacts.append({"path":str(collider.get_path()) if collider is Node else str(collider),"point":vec(contact.get_position()),"normal":vec(contact.get_normal())})
		events.append({"kind":"route_blocked","contacts":contacts,"target":vec(wp.position),"velocity":vec(p.velocity),"moving":moving,"key_pressed":Input.is_key_pressed(KEY_F13),"can_act":p.can_act()})
		print("COMBAT BLOCKED ",JSON.stringify(events.back()))
		finish("route stuck at %d position %s" % [index,p.global_position]);return
	p.rotation.y=atan2(-diff.x,-diff.z)
	forward(true)

func engaged(p: Player) -> Array:
	var enemies:=[]
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob.dead or mob.state!=Mob.S.COMBAT:continue
		for unit in mob.threat:
			if is_instance_valid(unit) and (unit==p or unit.owner_unit==p):
				enemies.append(mob);break
	enemies.sort_custom(func(a,b):return p.global_position.distance_to(a.global_position)<p.global_position.distance_to(b.global_position))
	return enemies

func fight(p: Player,enemies: Array,delta: float) -> void:
	var enemy:Mob=enemies[0]
	# Keep the current enemy until it dies to avoid every-frame target churn.
	if is_instance_valid(p.target) and p.target in enemies:enemy=p.target
	p.set_target(enemy)
	var diff:=enemy.global_position-p.global_position;diff.y=0
	if diff.length()>.1:p.rotation.y=atan2(-diff.x,-diff.z)
	forward(p.edge_dist(enemy)>3.3 and p.can_act())
	p.start_auto_attack()
	spell_time-=delta
	if spell_time>0:return
	spell_time=.15
	# Normal known-rank spells only, with the native cast/range/LOS checks.
	var priority: Array[String]=[]
	if enemy.is_casting() and not (allow_bell and enemy.mob_id=="boss_victor"):
		priority.append("pd_rebuke")
	if p.hp/p.max_hp<.5:priority.append("pd_holy_bulwark")
	if not enemy.is_casting():priority.append("pd_riposte")
	if enemies.size()>=2:priority.append("pd_hallowed_verdict")
	if enemies.size()>=3:priority.append("pd_sweeping_oath")
	priority.append_array(["pd_radiant_strike","pd_shield_bash","pd_oath_cut"])
	for id in priority:
		var rank:=Game.spell_rank(id)
		if rank<=0:continue
		var sp:=DB.spell(id,rank)
		if p.check_cast(sp,enemy)=="":
			p.cast_spell_id(id)
			break

func observe(p: Player,delta: float) -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		var id:=mob.get_instance_id()
		if not observed.has(id):
			observed[id]=true
			mob.died.connect(mob_died)
			mob.cast_started.connect(mob_cast.bind(mob))
			mob.cast_stopped.connect(mob_cast_stopped.bind(mob))
			events.append({"kind":"spawn","id":mob.mob_id,"room":mob.encounter_room,"level":mob.level,"max_hp":mob.max_hp,"position":vec(mob.global_position),"t":elapsed})
		if mob.state==Mob.S.COMBAT:
			var room:String=mob.encounter_room
			if not encounters.has(room):
				encounters[room]={"start":elapsed,"end":elapsed,"ids":{},"evades":0}
				print("COMBAT ENGAGE ",room," t=",elapsed)
			encounters[room].end=elapsed
			encounters[room].ids[mob.mob_id]=true
		if mob.state==Mob.S.EVADE and mob.get_meta("was_evading",false)==false:
			if encounters.has(mob.encounter_room):encounters[mob.encounter_room].evades+=1
			mob.set_meta("was_evading",true)
			events.append({"kind":"evade","id":mob.mob_id,"room":mob.encounter_room,"reason":mob.last_evade_reason,"position":vec(mob.global_position),"player":vec(p.global_position),"t":elapsed})
			print("COMBAT EVADE ",mob.mob_id," ",mob.encounter_room," reason=",mob.last_evade_reason," pos=",mob.global_position," player=",p.global_position)
		if mob.state!=Mob.S.EVADE:mob.set_meta("was_evading",false)
	for unit in [p]+get_tree().get_nodes_in_group("allies"):
		var id: int=unit.get_instance_id()
		if unit!=p and not observed.has(id):observed[id]=true;unit.died.connect(ally_died)
		if last_positions.has(id):
			var distance:float=unit.global_position.distance_to(last_positions[id])
			if distance>8:teleports+=1
			if unit==p:walked+=distance
		last_positions[id]=unit.global_position
	for flag in ["sanctum_ember_root","sanctum_ember_lake","sanctum_ember_nave","sanctum_final_open"]:
		if Game.has_flag(flag) and not gate_flags.has(flag):
			gate_flags[flag]=elapsed
			print("COMBAT FLAG ",flag," t=",elapsed)
	sample_time+=delta
	if sample_time<.5:return
	sample_time=0
	var party:=[]
	for ally in get_tree().get_nodes_in_group("allies"):
		var path: Array = ally._sanctum_follow.trail
		party.append({"id":ally.ally_id,"hp":ally.hp,"dead":ally.dead,"position":vec(ally.global_position),"path_points":path.size(),"path_head":vec(path[0]) if not path.is_empty() else [],"can_act":ally.can_act(),"casting":ally.is_casting()})
	samples.append({"t":elapsed,"i":index,"hp":p.hp,"max_hp":p.max_hp,"position":vec(p.global_position),"camera":p.spring.get_hit_length(),"party":party})

func mob_cast(label: String,_total: float,_channel: bool,mob: Mob) -> void:
	var key:=mob.mob_id+":"+label
	mob.set_meta("observed_cast",key)
	cast_counts[key]=int(cast_counts.get(key,0))+1
	if mob.is_boss:
		events.append({"kind":"boss_cast","id":mob.mob_id,"spell":label,"t":elapsed})
		if visual and cast_counts[key]==1:shot(mob.mob_id+"_cast")

func mob_cast_stopped(success: bool,mob: Mob) -> void:
	var key: String=mob.get_meta("observed_cast","")
	if key=="":return
	if not cast_outcomes.has(key):cast_outcomes[key]={"completed":0,"stopped":0}
	var outcome := "completed" if success else "stopped"
	cast_outcomes[key][outcome]+=1
	mob.remove_meta("observed_cast")
	if mob.is_boss:events.append({"kind":"boss_cast_end","id":mob.mob_id,"cast":key,"success":success,"t":elapsed})

func mob_died(unit: Unit) -> void:
	var mob:=unit as Mob
	kills.append({"id":mob.mob_id,"room":mob.encounter_room,"boss":mob.is_boss,"time":elapsed,"position":vec(mob.global_position)})
	if mob.is_boss:
		print("COMBAT BOSS KILL ",mob.mob_id," t=",elapsed)
		if visual:shot(mob.mob_id+"_defeated")

func ally_died(unit: Unit) -> void:
	death_count+=1
	events.append({"kind":"ally_death","id":unit.get("ally_id"),"t":elapsed})

func shot(label:String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out_dir)+"/%04d_%s.png" % [int(elapsed),label])

func vec(p:Vector3) -> Array:
	return [snappedf(p.x,.001),snappedf(p.y,.001),snappedf(p.z,.001)]

func finish(reason:String) -> void:
	forward(false)
	var report:Dictionary={"kind":"continuous_native_combat","seed":run_seed,"conditions":{"player_level":15,"gear":"level15 green mail, sword and shield; no talents","known_spells":"learnable ranks through level15","no_injected_healing":true,"no_seeds_granted":true,"native_companions":3,"mobs_active":true},"failed":0 if reason=="" else 1,"reason":reason,"waypoints":route.size(),"arrived":index,"elapsed_sim_seconds":elapsed,"walked_m":walked,"teleport_samples":teleports,"ally_deaths":death_count,"gate_flags":gate_flags,"encounters":encounters,"casts":cast_counts,"kills":kills,"events":events,"samples":samples}
	report["cast_outcomes"]=cast_outcomes
	report["allow_bell"]=allow_bell
	FileAccess.open(out_dir+"/combat_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COMBAT DONE failed=",report.failed," bosses=",kills.filter(func(k):return k.boss).size()," arrived=",index,"/",route.size()," reason=",reason)
	get_tree().quit(report.failed)
