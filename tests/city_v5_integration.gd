extends Node
## Real-world, headless-compatible v5 acceptance. All writes use a disposable slot (-1).
## Run: Godot --headless --fixed-fps 60 --path . res://tests/city_v5_integration.tscn -- phase=all
const NPC_IDS := "admiral,airship_captain,ambassador,archbishop,archivist,armor_shop,artisan_master,astronomer,auctioneer,banker,banker2,bath_attendant,black_marketeer,butler,canal_keeper,canal_officer,citizen,clergy,clock_keeper,cook_master,customs_officer,dock_worker,doctor,expo_guide,ferry_clerk,finance_minister,florist,gate_captain,governor,guard_city,guard_city_f,guild_master,guild_reg,harbor_master,inn_keeper2,item_shop,jeweler,judge,lecturer,librarian,lighthouse_keeper,mage_master,mayor,merchant_captain,merchant_head,nurse,opera_manager,outer_farmer,park_keeper,portal_mage,potion_shop,rare_shop,refugee,researcher,sailor,scholar,scholar_master,shipwright,smith_master,stable_city,station_master,t_gunner_3,t_mage_3,t_rogue_3,t_warrior_3,tavern_keeper,tax_officer,transmog,warehouse_keeper,weapon_shop,welfare_officer"
const POI_IDS := "poi_academy,poi_airport,poi_archive,poi_artisan,poi_bath,poi_blackmarket,poi_canal,poi_canal_bureau,poi_cathedral,poi_city_inn,poi_citygate,poi_citygate_n,poi_citygate_se,poi_clergy,poi_clock,poi_cook,poi_court,poi_customs,poi_drain,poi_exchange,poi_farmland,poi_governor,poi_guild,poi_harbor,poi_hospital,poi_institute,poi_library,poi_lighthouse,poi_mage_guild,poi_market,poi_merchant_hq,poi_north_port,poi_north_slope,poi_opera,poi_outer,poi_park,poi_plaza,poi_portal_hall,poi_residency,poi_scholar,poi_shipyard,poi_shop_0,poi_shop_1,poi_shop_2,poi_shop_3,poi_shop_4,poi_shop_5,poi_shop_6,poi_smith,poi_solenne,poi_south_port,poi_spring,poi_station,poi_tavern,poi_tax,poi_warehouse,poi_welfare"
var out := "res://.local/city_v5/integration"
var phase := "all"
var checks: Array = []
var plan: Dictionary
var landmark_manifest: Dictionary
var world: World
var player: Player
var city: Zone
var started := 0
var phase_started := 0
var finished := false
var plan_sha := ""
var artifact_sha := {}

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.substr(4)
		if arg.begins_with("phase="): phase = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	FileAccess.open(out.path_join(".gdignore"), FileAccess.WRITE)
	var raw := FileAccess.get_file_as_string("res://docs/city_v5/layout.json")
	plan = JSON.parse_string(raw)
	plan_sha = raw.sha256_text()
	for path in ["res://scenes/zones/tidewind_highlands.tscn","res://data/terrain/tidewind.res","res://tools/gen_solenne.gd","res://src/world/city_ward.gd","res://tests/city_v5_integration.gd"]:
		artifact_sha[path]=FileAccess.get_sha256(path)
	landmark_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/city_v5/landmarks/manifest.json"))
	Game.slot_index = -1
	Game.new_character("主城集成临时验证", "warrior", DB.random_appearance(7,"f"))
	Game.slot_index = -1
	Game.pd["zone"] = "tidewind"
	Game.pd["world_ver"] = WorldLayout.SAVE_VER
	Game.pd["city_ver"] = 5
	Game.pd["new"] = false
	Game.pd["pos"] = Vector3(330,26,450) + WorldLayout.offset("tidewind")
	Game.pd["level"] = 15
	Game.pd["flags"]["city_access"] = true
	Game.pd["money"] = 100000
	# Per-process settings only; no settings file is saved.
	Game.settings["grass"] = false
	Game.time_of_day = 10.0
	started = Time.get_ticks_msec()
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	run.call_deferred()

func _process(_delta: float) -> void:
	if finished: return
	if is_instance_valid(Game.player): Game.player.hp = Game.player.max_hp
	if started > 0 and Time.get_ticks_msec()-started > 1200000:
		check(false,"global wall-clock watchdog",{"seconds":1200})
		finish()

func check(ok: bool, label: String, details = null) -> void:
	var row := {"pass":ok,"label":label,"details":details}
	checks.append(row)
	print("CITY_V5 ", JSON.stringify(row))
	write_report(false)

func write_report(complete: bool) -> void:
	var report := {"complete":complete,"passed":complete and checks.all(func(c):return c.pass),"phase":phase,"slot_index":Game.slot_index,"layout_sha256":plan_sha,"artifacts_at_start_sha256":artifact_sha,"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0,"checks":checks,"scope":"Real World/Zone/Player, streamed scene instances and physics ticks; headless run, no visual acceptance."}
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))

func finish() -> void:
	if finished: return
	finished = true
	if is_instance_valid(player): player.autorun=false
	check(Game.slot_index==-1,"never-saved character slot")
	write_report(true)
	var failures := checks.filter(func(c):return not c.pass).size()
	print("CITY_V5_RESULT checks=",checks.size()," failures=",failures," report=",out.path_join("report.json"))
	get_tree().quit(0 if failures==0 else 1)

func ticks(n: int) -> void:
	for i in n: await get_tree().physics_frame

func wp(x: float,z: float,y: float = NAN) -> Vector3:
	var p := Vector3(x,0,z) + WorldLayout.offset("tidewind")
	p.y = city.terrain.get_height_global(p.x,p.z) if is_nan(y) else y
	return p

func local_pos(p: Vector3) -> Array:
	var v := p-WorldLayout.offset("tidewind")
	return [snappedf(v.x,.01),snappedf(v.y,.01),snappedf(v.z,.01)]

func floor_hit(p: Vector3,above: float=0.5,below: float=2.0) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*above,p-Vector3.UP*below,1))

func collision_names() -> Array:
	var result := []
	for i in player.get_slide_collision_count():
		var hit := player.get_slide_collision(i)
		var collider := hit.get_collider() as Node
		result.append({"node":str(collider.get_path()) if collider else "null","position":local_pos(hit.get_position()),"normal":str(hit.get_normal())})
	return result

func capsule_overlaps(p: Vector3) -> Array:
	var shape := CapsuleShape3D.new()
	shape.height=1.7; shape.radius=.4
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape=shape; q.collision_mask=1
	q.transform=Transform3D(Basis.IDENTITY,p+Vector3(0,.9,0))
	var names := []
	for hit in world.get_world_3d().direct_space_state.intersect_shape(q,8):
		names.append(str(hit.collider.get_path()))
	return names

func teleport(p: Vector3) -> void:
	player.autorun=false
	player.set_target(null)
	Game.hud.close_all()
	await world._teleport_to(p)
	await ticks(30)

func build_spec(id: String) -> Dictionary:
	for item in plan.buildings:
		if item.id==id:return item
	return {}

func building(id: String) -> ModelProp:
	return city.get_node_or_null("Buildings/"+id) as ModelProp

func entry(id: String,forward: float=0.0,index: int=0) -> Vector3:
	var prop := building(id)
	var item := build_spec(id)
	var p := Vector3(0,0,-float(item.size[2])*.5)
	var direction:=1.0
	for info in landmark_manifest.assets:
		if item.asset==info.id:
			var point:Array=info.entries[index]
			p=Vector3(point[0],point[1],point[2])
			direction=-1.0 if p.z>=float(info.footprint[1])*.5-.01 else 1.0
	p.z += forward*direction
	return prop.to_global(p)

func npc_target(id: String) -> Vector3:
	for row in plan.npcs:
		if row.id==id:
			return wp(row.p[0],row.p[1],row.get("y",NAN))
	return Vector3.ZERO

func road_points(id: String) -> Array:
	var points:=[]
	for road in plan.roads:
		if road.id==id:
			for p in road.pts:points.append(wp(p[0],p[1]))
	return points

func run() -> void:
	await get_tree().process_frame
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	world=Game.world;player=Game.player;city=world.zones["tidewind"]
	await ticks(30)
	check(world.streamer!=null,"actual seamless world and streamer loaded",world.zones.keys())
	check(plan.version==5,"v5 layout loaded",plan_sha)
	if phase in ["all","actors"]: await actors_and_pois()
	if phase in ["all","gates"]: await gates()
	if phase in ["all","gates","ward"]: await boundaries()
	if phase in ["all","routes"]: await routes()
	if phase in ["all","transport"]: await transport_and_streaming()
	if phase=="probe":await ground_probe()
	if phase=="court":await station_court_routes()
	if phase=="new_routes":await representative_routes()
	if phase=="station_plaza":await station_plaza_routes()
	if phase=="focused":
		await walk("academy terrace approach",[wp(-510,450),wp(-510,405),wp(-505,392,44),wp(-505,350,44),entry("academy",-7),entry("academy",3),npc_target("lecturer")+Vector3(0,0,2)])
		await walk("porch to interior customs",[entry("customs",-8),entry("customs",4)])
		await walk("porch to interior bath",[entry("bath",-8),entry("bath",4)])
	finish()

func ground_probe() -> void:
	for spec in [["southeast",293.0,247.0,740.0],["north",-70.0,-70.0,205.0]]:
		await teleport(wp(spec[1],spec[3]))
		var rows:=[]
		for i in 13:
			var x:float=lerpf(spec[1],spec[2],float(i)/12.0)
			var z:float=spec[3] if spec[0]=="southeast" else 185.0+float(i)*4.0
			var p:=wp(x,z)
			var hit:=floor_hit(p,3,90)
			rows.append({"local":[x,z],"terrain_height":p.y,"physics_hit":local_pos(hit.position) if not hit.is_empty() else null,"collider":str(hit.collider.get_path()) if not hit.is_empty() else null,"normal":str(hit.normal) if not hit.is_empty() else null,"ready":world.ground_ready(p)})
		check(true,"ground probe "+spec[0],rows)

func actors_and_pois() -> void:
	var ids := {};var expected_ids := NPC_IDS.split(",")
	for source in city.actor_sources:
		if source is NpcSpot:ids[source.npc_id]=true
	for id in expected_ids:check(ids.has(id),"NPC compatibility "+id)
	var live_seen := {}
	for row in plan.npcs:
		var expected := wp(row.p[0],row.p[1],row.get("y",NAN))
		var spot: NpcSpot = null
		for source in city.actor_sources:
			if source is NpcSpot and source.npc_id==row.id and U.flat_dist(source.global_position,expected)<.2:
				spot=source;break
		if spot==null:
			check(false,"NPC marker "+row.id,{"at":row.p});continue
		var npc: NPC = city.npc_instances.get(spot)
		if not is_instance_valid(npc):
			await teleport(expected+Vector3(3,0,3))
			npc=city.npc_instances.get(spot)
		if not is_instance_valid(npc):
			check(false,"NPC live instance "+row.id,{"at":row.p});continue
		var floor := floor_hit(npc.global_position)
		var supported: bool = not floor.is_empty() and absf(npc.global_position.y-floor.position.y)<.3
		var clear := capsule_overlaps(npc.global_position)
		var height_ok := absf(npc.global_position.y-expected.y)<.85
		var above_water:bool=npc.global_position.y>=city.water_level()-.2
		check(supported and clear.is_empty() and height_ok and above_water,"NPC physical placement "+row.id,{"planned":local_pos(expected),"actual":local_pos(npc.global_position),"floor":local_pos(floor.position) if not floor.is_empty() else null,"overlaps":clear,"above_water":above_water,"authored_height_matches":height_ok})
		live_seen[row.id]=true
	check(live_seen.size()==71,"all 71 unique city NPC IDs instantiated",live_seen.size())
	var poi_map := {}
	for poi in city.pois:poi_map[poi.poi_id]=poi
	for id in POI_IDS.split(","):check(poi_map.has(id),"POI compatibility "+id)
	for row in plan.pois:
		var poi: POI = poi_map.get(row.id)
		if poi==null:continue
		check(U.flat_dist(poi.global_position,wp(row.p[0],row.p[1]))<.1 and absf(poi.radius-row.radius)<.01,"POI runtime position "+row.id,{"at":local_pos(poi.global_position),"radius":poi.radius})

func walk(label: String, points: Array, blocked_expected: bool=false,swim_allowed: bool=false) -> bool:
	if points.size()<2:return false
	var walk_start:Vector3=points[0]
	# Setup on the actual exterior ground, never below a neighbouring slope.
	# Authored transport/spawn checks intentionally do not apply this setup adjustment.
	walk_start.y=maxf(walk_start.y,city.terrain.get_height_global(walk_start.x,walk_start.z))
	await teleport(walk_start)
	player.walking=false
	var ok := true;var elapsed := 0.0;var unsupported := 0;var maximum_unsupported := 0;var samples := [];var blockers := []
	var destination: Vector3=points[1]
	for leg in range(1,points.size()):
		destination=points[leg]
		var closest := U.flat_dist(player.global_position,destination)
		var limit := int((closest/Player.RUN_SPEED+10.0)*60.0)
		var still := 0
		player.face_towards(destination);player.autorun=true
		for tick in limit:
			await get_tree().physics_frame
			elapsed+=1.0/60.0
			var dist := U.flat_dist(player.global_position,destination)
			if dist<.65:break
			player.face_towards(destination)
			if dist<closest-.025:closest=dist;still=0
			else:still+=1
			if tick%30==0:
				var hit := floor_hit(player.global_position)
				var support: bool=(not hit.is_empty() and player.global_position.y-hit.position.y<.65) or (swim_allowed and player.swimming)
				unsupported=0 if support else unsupported+30
				maximum_unsupported=maxi(maximum_unsupported,unsupported)
				samples.append({"p":local_pos(player.global_position),"support":support,"stream_ready":world.ground_ready(player.global_position)})
			if still>180 or (player.swimming and not swim_allowed) or maximum_unsupported>120:break
		player.autorun=false
		if U.flat_dist(player.global_position,destination)>=.65 or absf(player.global_position.y-destination.y)>1.2:
			blockers=collision_names();ok=false;break
	await ticks(3)
	if blockers.is_empty():blockers=collision_names()
	var result:bool=(not ok and blockers.any(func(c):return "/Barrier" in c.node)) if blocked_expected else ok and maximum_unsupported<=120 and (not player.swimming or swim_allowed)
	check(result,"Player walk "+label,{"expected_block":blocked_expected,"swim_allowed":swim_allowed,"reached":ok,"start":local_pos(walk_start),"end":local_pos(player.global_position),"target":local_pos(destination),"target_height_error":absf(player.global_position.y-destination.y),"seconds":snappedf(elapsed,.01),"maximum_unsupported_ticks":maximum_unsupported,"swimming":player.swimming,"collisions":blockers,"samples":samples})
	return result

func gates() -> void:
	for g in plan.gates:
		var id: String=g[0]
		var outward:=Vector3(0,0,-1) if id=="north" else Vector3(1,0,0)
		# Sample each endpoint separately: outside ground can differ from the gate foundation.
		var start:=wp(float(g[1])+outward.x*23,float(g[2])+outward.z*23)
		var end:=wp(float(g[1])-outward.x*23,float(g[2])-outward.z*23)
		Game.pd.flags.erase("city_access")
		await teleport(start)
		city.refresh_gates();await ticks(3)
		var gate:=building("gate_"+id)
		var barrier:Node=gate.get_node_or_null("_gen/Barrier") if gate else null
		check(barrier!=null,"locked gate live barrier "+id)
		await walk(id+" locked",[start,end],true)
		Game.pd.flags.city_access=true
		city.refresh_gates();await ticks(3)
		check(gate!=null and gate.get_node_or_null("_gen/Barrier")==null,"unlocked gate removes barrier "+id)
		await walk(id+" unlocked",[start,end])
		await walk(id+" authorized exit",[end,start])

func surface_anchor(x:float,z:float,hint:float,label:String) -> Vector3:
	var p:=wp(x,z,hint)
	# Keep the real player at the prepared destination; otherwise the live streamer
	# immediately restores its old focus and can evict the surface before this ray.
	await teleport(p)
	var hit:=floor_hit(p,6,64)
	var valid:bool=not hit.is_empty() and hit.normal.y>.65 and hit.position.y>=hint-4.0
	check(valid,"physical deck anchor "+label,{"requested":local_pos(p),"floor":local_pos(hit.position) if not hit.is_empty() else null,"collider":str(hit.collider.get_path()) if not hit.is_empty() else null})
	return hit.position if valid else p

func boundaries() -> void:
	var ward:Node3D=city.get_node_or_null("Buildings/CityAccessBoundary")
	check(ward!=null,"CityWard runtime boundary exists")
	if ward==null:return
	check(ward.is_in_group("gates") and ward.get("flag")=="city_access","CityWard follows live access flag")
	check(not world.streamer.records.any(func(r):return r.node==ward),"CityWard excluded from scenery eviction")
	Game.pd.flags.erase("city_access");city.refresh_gates();await ticks(3)
	var expected_count:int=ward.get("points").size()
	check(ward.find_children("Barrier_CityAccess_*","StaticBody3D",true,false).size()==expected_count,"locked CityWard builds every physical segment",expected_count)
	var far_anchor:Node3D=world.zones.vale.get_spawn("start")
	await teleport(far_anchor.global_position)
	check(is_instance_valid(ward) and ward.find_children("Barrier_CityAccess_*","StaticBody3D",true,false).size()==expected_count,"locked CityWard remains resident outside city")
	Game.pd.flags.city_access=true;city.refresh_gates();await ticks(3)
	var water_y:=city.water_level()-1.25
	var rail_out:=await surface_anchor(285,850.95,32.2,"rail outside")
	var rail_in:=await surface_anchor(245,850.59,32.2,"rail inside")
	var pier_out:=await surface_anchor(-455,670,13.3,"pier outside")
	var pier_in:=await surface_anchor(-455,638,13.3,"pier inside")
	var cases:=[
		["river mouth",wp(-295,662.8,water_y),wp(-240,636.4,water_y),true],
		["east watergate",wp(312,580,water_y),wp(272,580,water_y),true],
		["elevated railway",rail_out,rail_in,false],
		["harbor pier",pier_out,pier_in,false],
	]
	for test in cases:
		Game.pd.flags.erase("city_access");city.refresh_gates();await ticks(3)
		await walk("boundary "+test[0]+" locked",[test[1],test[2]],true,test[3])
		Game.pd.flags.city_access=true;city.refresh_gates();await ticks(3)
		check(ward.find_children("Barrier_CityAccess_*","StaticBody3D",true,false).is_empty(),"CityWard clears after authorization "+test[0])
		await walk("boundary "+test[0]+" authorized ingress",[test[1],test[2]],false,test[3])
		await walk("boundary "+test[0]+" authorized exit",[test[2],test[1]],false,test[3])

func routes() -> void:
	Game.pd.flags.city_access=true;city.refresh_gates()
	await walk("east gate to civic and banker",[wp(330,450),wp(235,450),wp(-40,450),wp(-166,450),wp(-166,366),entry("civic",-8),entry("civic",3),npc_target("banker")+Vector3(0,0,2)])
	await walk("banker to auctioneer",[npc_target("banker")+Vector3(0,0,2),entry("civic",3),entry("civic",-8),wp(-165,370),wp(-165,450),wp(-150,480),wp(-120,493),entry("exchange",-7),entry("exchange",3),npc_target("auctioneer")+Vector3(-2,0,0)])
	await walk("auctioneer to smith",[npc_target("auctioneer")+Vector3(-2,0,0),entry("exchange",3),entry("exchange",-7),wp(-126,493),wp(-180,493),entry("smith",-5),entry("smith",3),npc_target("smith_master")+Vector3(2,0,-2)])
	await walk("north bridge to station hall",[wp(20,530),wp(20,580,20),wp(20,650),wp(20,705),wp(45,720),wp(46,745),entry("station",-7),entry("station",3),npc_target("station_master")+Vector3(0,0,-2)])
	await walk("academy terrace approach",[wp(-510,450),wp(-510,405),wp(-505,392,44),wp(-505,350,44),entry("academy",-7),entry("academy",3),npc_target("lecturer")+Vector3(0,0,2)])
	await walk("palace terrace and courtyard",[wp(-790,450),wp(-790,420),wp(-776,412,60),wp(-776,352,60),wp(-790,337,60),entry("palace",-7),entry("palace",3),npc_target("governor")+Vector3(0,0,2)])
	await walk("authored harbor ramp",road_points("harbor_ramp"))
	var harbor_return:=road_points("harbor_ramp")
	harbor_return.reverse()
	await walk("authored harbor ramp return",harbor_return)
	await walk("authored tavern walk",road_points("tavern_walk"))
	var tavern_return:=road_points("tavern_walk")
	tavern_return.reverse()
	await walk("authored tavern walk return",tavern_return)
	await station_court_routes()
	await representative_routes()
	if building("station_forecourt_paving")!=null:await station_plaza_routes()
	for id in ["civic","market","cathedral","station","academy","palace","guild","exchange","court","bath","portal","mage","opera","hospital","customs","terminal"]:
		await walk("porch to interior "+id,[entry(id,-8),entry(id,4)])
	for id in ["station","market"]:
		await walk("hall through to rear exit "+id,[entry(id,-7),entry(id,3),entry(id,3,1),entry(id,-7,1)])

func station_court_routes() -> void:
	# Exit polylines from docs/city_v5/layout_audit.json; test actual props and grade.
	await walk("station shared court west exit",[wp(-60,810),wp(-118,810),wp(-130,810)])
	await walk("station shared court east exit",[wp(-60,810),wp(0,810),wp(0,765),wp(0,735)])

func representative_routes() -> void:
	for id in ["west_highstreet","terrace_lane","academy_lower_court"]:
		var authored:=road_points(id)
		check(authored.size()>=2,"representative authored route exists "+id)
		if authored.size()<2:continue
		await walk("full "+id,authored)
		authored.reverse()
		await walk("full "+id+" return",authored)
	# The centre waypoint lies on the authored 20m bridge deck, above the riverbed.
	var east_bridge:=[wp(235,515),wp(219,536),wp(200,580,20),wp(180,628),wp(175,650)]
	await walk("east bridge and both abutments",east_bridge)
	east_bridge.reverse()
	await walk("east bridge and both abutments return",east_bridge)
	for block in plan.get("blocks",[]):
		if block.id not in ["river_west","river_east"]:continue
		var center:Array=block.courtyard
		for index in block.exits.size():
			var portal:Array=block.exits[index]
			# Follow the courtyard opening and its authored side lane to public quay road.
			var points:=[wp(center[0],center[1]),wp(portal[0],portal[1]),wp(portal[0],693),wp(portal[0],705)]
			await walk("river block "+block.id+" exit "+str(index+1),points)

func station_plaza_routes() -> void:
	var plaza:=building("station_forecourt_paving")
	check(plaza!=null,"station forecourt geometry exists")
	if plaza==null:return
	await walk("station forecourt central arrival",[wp(60,735),wp(60,750),wp(60,762),entry("station",-7),entry("station",3)])
	await walk("station forecourt western gathering area",[wp(0,765),wp(12,755),wp(40,760),wp(60,762),entry("station",-7),entry("station",3)])
	await walk("station forecourt eastern gathering area",[wp(124,765),wp(108,755),wp(80,760),wp(60,762),entry("station",-7),entry("station",3)])

func landing(label: String, anchor: Node3D) -> void:
	await ticks(60)
	var hit:=floor_hit(player.global_position)
	var supported:bool=not hit.is_empty() and absf(player.global_position.y-hit.position.y)<.25
	check(U.flat_dist(player.global_position,anchor.global_position)<.3 and supported and world.ground_ready(player.global_position) and not player.swimming,label,{"anchor":local_pos(anchor.global_position),"player":local_pos(player.global_position),"floor":local_pos(hit.position) if not hit.is_empty() else null})

func transport_and_streaming() -> void:
	for row in plan.spawns:
		var anchor:=city.get_spawn(row.id)
		check(anchor!=null,"arrival anchor exists "+row.id)
		if anchor==null:continue
		await teleport(anchor.global_position)
		await landing("spawn support "+row.id,anchor)
	await world.ride_train("tidewind","st_solenne","晴岚港")
	await landing("real train arrival",city.get_spawn("st_solenne"))
	await world.fly_to("fp_solenne")
	await landing("real flight arrival",city.get_spawn("fp_solenne"))
	await teleport(entry("civic",-7))
	var prop:=building("civic")
	check(prop.get_node_or_null("_gen")!=null,"civic is loaded before stream departure")
	var before:int=world.streamer.released
	var far_anchor:Node3D=world.zones.vale.get_spawn("start")
	await teleport(far_anchor.global_position)
	await ticks(120)
	check(prop.get_node_or_null("_gen")==null and world.streamer.released>before,"distant city asset really evicted",{"released_before":before,"released_after":world.streamer.released})
	await world.ride_train("tidewind","st_solenne","晴岚港")
	await landing("return after eviction",city.get_spawn("st_solenne"))
	await walk("reloaded civic entrance",[entry("civic",-7),entry("civic",4)])
