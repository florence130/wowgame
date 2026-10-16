extends Node3D
## Verify live imported geometry, side-room return paths and progression gates.
const FLOW = preload("res://src/data/data_sanctum_flow.gd")
var failures: Array = []
var checks := 0
class ChestVisitor extends Node3D:
	var in_combat := false

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		print("SANCTUM FAIL ", description)

func _ready() -> void:
	Game.new_character("路线检查", "warrior", DB.random_appearance(7, "f"))
	Game.slot_index = -1
	Game.pd["flags"] = {}
	var zone: Node3D = load("res://scenes/zones/windwhisper_sanctum.tscn").instantiate()
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for body in zone.get_node("Terrain").find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 0
	check(FLOW.layout().side_rooms.size() == 9, "nine optional spaces")
	check(FLOW.layout().side_rooms.filter(func(r): return r.use == "empty").size() == 2, "two deliberately empty rooms")
	check(FLOW.floor_y(Vector2(80,84),4)==24.0,"upper final approach resolves upper floor above enlarged crypt")
	check(FLOW.floor_y(Vector2(80,84),2)==8.0,"lower crypt resolves basement at overlapping coordinate")
	check(zone.get_node_or_null("Buildings/UnitySpatialSanctum") != null, "saved Unity spatial mesh in live scene")
	var spawners := zone.get_node("Spawners").get_children()
	var bosses := spawners.filter(func(s): return DB.mobs.get(s.mob_id, {}).get("boss", false))
	check(bosses.size() == 4, "exactly four bosses")
	for sp in spawners:
		check(sp.encounter_bounds.has_point(Vector2(sp.position.x, sp.position.z)), "spawn bounds " + sp.name)
	var gates: Array = get_tree().get_nodes_in_group("gates")
	check(gates.size() == 3, "three fire-seed gates")
	var space := get_world_3d().direct_space_state
	for p in [Vector2(104,110),Vector2(104,84),Vector2(104,50)]:
		var nave_roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,30,p.y),Vector3(p.x,65,p.y),1))
		check(not nave_roof.is_empty() and nave_roof.position.y>53.0 and nave_roof.position.y<55.0,"Blender tall nave retains real solid roof around 30m above floor " + str(p))
	for x in [88.5,119.5]:
		for z in [109.0,123.0,136.0]:
			var window := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x-1.8,39.45,z),Vector3(x+1.8,39.45,z),1))
			if not window.is_empty():print("WINDOW APERTURE HIT ",Vector2(x,z)," ",window.position," ",window.collider.get_path())
			check(window.is_empty(),"Blender actual high-window aperture " + str(Vector2(x,z)))
			var intact := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x-1.8,34.0,z),Vector3(x+1.8,34.0,z),1))
			check(not intact.is_empty(),"solid wall retained below clerestory " + str(Vector2(x,z)))
	for p in [Vector2(29,170),Vector2(49,192)]:
		var eave := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,34,p.y),Vector3(p.x,29,p.y),1))
		print("GARDEN EAVE ",p," hit=",eave.get("position",Vector3.ZERO))
		check(not eave.is_empty() and eave.position.y>=30.5,"raised garden gallery retains solid roof above distant camera " + str(p))
	var ground_mesh := zone.get_node_or_null("Buildings/UnitySpatialSanctum/terrain")
	check(ground_mesh!=null,"actual excavated earth surface is in the scene")
	var earth_query_layer := 1 << 20
	if ground_mesh:
		for body in ground_mesh.get_children():
			if body is StaticBody3D:
				body.collision_layer |= earth_query_layer
	for f in FLOW.rooms():
		if not f.get("buried",false):continue
		var rect := FLOW.bounds(f)
		var center := rect.get_center()
		var points: Array[Vector2] = [center]
		if f.id=="mortuary":points=[Vector2(72,115),Vector2(84,112)]
		# Sample beside the intended 8.5m doorway lintel to inspect the vault.
		if f.id=="side_crypt_link":points=[Vector2(84,102)]
		if f.id=="side_brew_link":points=[Vector2(105,140)]
		for p in points:
			var floor_level := FLOW.height(f,p)
			var surface := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,70,p.y),Vector3(p.x,0,p.y),earth_query_layer))
			check(not surface.is_empty() and surface.position.y>=float(f.roof_level)+.5,"soil covers underground " + String(f.id) + " " + str(p))
			var vault := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,floor_level+2,p.y),Vector3(p.x,float(f.roof_level)+.2,p.y),1))
			check(not vault.is_empty() and vault.position.y>=float(f.roof_level)-.5,"continuous vault over underground " + String(f.id) + " " + str(p))
	# Check the whole buried footprint on the live mesh, excluding the two
	# intentional portal excavations, rather than only the room centre.
	for f in FLOW.rooms():
		if not f.get("buried",false):continue
		var rect := FLOW.bounds(f)
		var covered := true
		var samples := 0
		var minimum := INF
		var worst := Vector2.ZERO
		for iz in ceili(rect.size.y):
			for ix in ceili(rect.size.x):
				var p := rect.position+Vector2(ix+.5,iz+.5)
				if not Geometry2D.is_point_in_polygon(p,FLOW.polygon(f)):continue
				var excavated := false
				for key in ["entry_cut","exit_cut"]:
					var cut := PackedVector2Array()
					for v in FLOW.layout().ground[key]:cut.append(Vector2(v[0],v[1]))
					if Geometry2D.is_point_in_polygon(p,cut):excavated=true
				if excavated:continue
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,70,p.y),Vector3(p.x,0,p.y),earth_query_layer))
				var thickness: float = hit.position.y-float(f.roof_level) if not hit.is_empty() else -INF
				samples+=1
				if thickness<minimum:minimum=thickness;worst=p
				covered=covered and thickness>=.5
		print("SANCTUM SOIL ",f.id," samples=",samples," min=",minimum," at=",worst)
		check(covered and samples>0,"whole underground footprint covered " + String(f.id)+" minimum="+str(minimum)+" at="+str(worst))
	for id in ["court","cloister","root_garden","supply_court","nave","bell_tower","side_gate_rest","side_tools","side_hermit","side_ledger","side_dorm","side_chapel"]:
		var f := FLOW.by_id(id)
		var p := FLOW.bounds(f).get_center()
		if id=="cloister":p=Vector2(48,192)
		var surface := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,70,p.y),Vector3(p.x,0,p.y),earth_query_layer))
		var expected := FLOW.height(f,p)
		check(not surface.is_empty() and expected-surface.position.y>.2 and expected-surface.position.y<.7,"above-ground foundation contacts surface " + id)
	for gate in gates:
		check(gate.get_node_or_null("Barrier") != null, "locked " + gate.flag)
		var blocked := true
		for off in [-float(gate.width)*.5+.65,0.0,float(gate.width)*.5-.65]:
			var a: Vector3 = gate.to_global(Vector3(off,2,-2))
			var b: Vector3 = gate.to_global(Vector3(off,2,2))
			blocked = blocked and not space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()
		if gate.flag == "sanctum_ember_root":
			for z in [124.7,126.0,130.0,137.0]:
				var y := FLOW.floor_y(Vector2(64,z),2)+.85
				blocked = blocked and not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(62,y,z),Vector3(66,y,z),1)).is_empty()
		check(blocked, "locked gate rejects crossing across doorway " + gate.flag)
	check(not _bell_reachable(space), "locked final doorway has no walkable side bypass")
	for stage in 4:
		if stage > 0:
			Game.pd.flags[["sanctum_ember_root", "sanctum_ember_lake", "sanctum_ember_nave"][stage - 1]] = true
		for gate in gates:
			gate.refresh_gate()
		for sp in bosses:
			var required: bool = (sp.mob_id == "boss_rootguard" and stage == 0) or (sp.mob_id == "boss_lake" and stage == 1) or (sp.mob_id == "boss_sanctum_lantern" and stage == 2) or (sp.mob_id == "boss_victor" and stage == 3)
			check(sp._unlocked() == required, "stage " + str(stage) + " boss " + sp.mob_id)
		check(Game.has_flag("sanctum_final_open") == (stage == 3), "three seeds at stage " + str(stage))
		for gate in gates:
			check((gate.get_node_or_null("Barrier") == null) == Game.has_flag(gate.flag), "gate state " + gate.flag + " stage " + str(stage))
			var sockets: Node3D = gate.get_node("FireSockets")
			var fixtures := sockets.get_children().filter(func(n):return n.has_meta("seed_flag"))
			check(fixtures.size() == (3 if gate.flag=="sanctum_final_open" else 1), "socket count " + gate.flag + " stage " + str(stage))
			for socket in fixtures:
				check(socket.get_meta("lit") == Game.has_flag(socket.get_meta("seed_flag")), "seed socket state " + String(socket.get_meta("seed_flag")) + " stage " + str(stage))
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(_bell_reachable(space), "unlocked final doorway connects nave to stair")
	var capsule := CapsuleShape3D.new()
	capsule.radius = .5
	capsule.height = 1.8
	for boss in FLOW.layout().bosses:
		var circle_floor := true
		var circle_clear := true
		for radius in [0.0,7.0,14.0]:
			for i in 24:
				var angle := TAU*i/24.0
				var p := Vector3(boss.point[0]+cos(angle)*radius,boss.level,boss.point[1]+sin(angle)*radius)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP,1))
				circle_floor = circle_floor and not hit.is_empty() and absf(hit.position.y-p.y)<.12
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape=capsule;q.collision_mask=1
				q.transform=Transform3D(Basis.IDENTITY,p+Vector3(0,1.08,0))
				circle_clear = circle_clear and space.intersect_shape(q).is_empty()
		check(circle_floor,"boss 28m circle has mesh floor " + String(boss.name))
		check(circle_clear,"boss 28m circle clear of scenery " + String(boss.name))
	var paths: Array = FLOW.layout().route.duplicate()
	paths.append_array(FLOW.layout().side_rooms)
	for route in paths:
		var pts: Array = route.points3
		for segment in range(pts.size()-1):
			var a := Vector2(pts[segment][0],pts[segment][2])
			var b := Vector2(pts[segment+1][0],pts[segment+1][2])
			var count := maxi(1,ceili(a.distance_to(b)/.4))
			var floor_ok := true
			var passage_ok := true
			var issue := ""
			for i in range(count+1):
				var p := a.lerp(b,float(i)/count)
				var y := FLOW.floor_y(p,int(route.phase))
				if y == INF:
					floor_ok=false;issue=str(p);continue
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y+1,p.y),Vector3(p.x,y-.8,p.y),1))
				if hit.is_empty() or absf(hit.position.y-y)>.12:
					floor_ok=false;issue=str(p)+" y="+str(y)+" hit="+str(hit.get("position",Vector3.ZERO))
				if i == count:
					continue
				var next := a.lerp(b,float(i+1)/count)
				var ny := FLOW.floor_y(next,int(route.phase))
				if ny == INF:
					continue
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape=capsule;q.collision_mask=1
				q.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,y+1.08,p.y))
				q.motion=Vector3(next.x-p.x,ny-y,next.y-p.y)
				var reverse := PhysicsShapeQueryParameters3D.new()
				reverse.shape=capsule;reverse.collision_mask=1
				reverse.transform=Transform3D(Basis.IDENTITY,q.transform.origin+q.motion)
				reverse.motion=-q.motion
				if space.cast_motion(q)[0]<.99 or space.cast_motion(reverse)[0]<.99:
					passage_ok=false;issue=str(p)+" y="+str(y)
					var probe := PhysicsShapeQueryParameters3D.new()
					probe.shape=capsule;probe.collision_mask=1
					probe.transform=Transform3D(Basis.IDENTITY,q.transform.origin+q.motion*.5)
					var overlapping := space.intersect_shape(probe)
					for obstacle in overlapping:
						issue += " collider="+str(obstacle.collider.get_path())
			check(floor_ok,"mesh floor " + String(route.name) + " segment " + str(segment) + " " + issue)
			check(passage_ok,"capsule both ways " + String(route.name) + " segment " + str(segment) + " " + issue)
	# A downward ray at overlapping cellar/nave coordinates must find both floors.
	for y in [8.0,24.0]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(105,y+1,126),Vector3(105,y-1,126),1))
		check(not hit.is_empty() and absf(hit.position.y-y)<.12,"separate cellar/nave floor " + str(y))
	var ceiling := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(105,10,126),Vector3(105,25,126),1))
	check(not ceiling.is_empty(),"solid ceiling separates cellar from nave")
	# Real collision height, not only the declared room specification.
	for id in ["cellar","side_crypt","side_brew"]:
		var f := FLOW.by_id(id)
		var p := FLOW.bounds(f).get_center()
		if id=="cellar":p=Vector2(105,126)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,10,p.y),Vector3(p.x,23,p.y),1))
		check(not hit.is_empty() and hit.position.y-8.0>=12.4,"MMO room real vertical clearance " + id + " roof="+str(hit.get("position",Vector3.ZERO)))
		if id!="cellar":check(FLOW.bounds(f).size.x>=20 and FLOW.bounds(f).size.y>=20,"MMO optional basement room footprint " + id)
	var lintel := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(105,10,141.5),Vector3(105,22,141.5),1))
	check(not lintel.is_empty() and lintel.position.y>=16.3,"MMO cellar side doorway has 8.5m headroom")
	var guard := Mob.new()
	zone.units_root.add_child(guard)
	guard.set_physics_process(false)
	guard.encounter_room="P6"
	guard.encounter_bounds=Rect2(96,117,18,18)
	guard.global_position=Vector3(105,8.1,126)
	guard.spawn_pos=guard.global_position
	var upstairs := Unit.new()
	add_child(upstairs)
	upstairs.faction="player"
	upstairs.global_position=Vector3(105,24.1,126)
	guard._check_aggro()
	check(guard.state==Mob.S.IDLE,"cellar guard does not aggro player above it")
	guard.add_threat(upstairs,1)
	guard._engage(upstairs)
	guard._combat(.01)
	check(guard.state==Mob.S.EVADE,"cross-storey combat returns to its encounter")
	var slope_guard := Mob.new()
	zone.units_root.add_child(slope_guard);slope_guard.set_physics_process(false)
	slope_guard.encounter_room="P7";slope_guard.encounter_bounds=Rect2(145,131,18,18)
	slope_guard.spawn_pos=Vector3(154,20,140)
	var leader := Unit.new();add_child(leader);leader.faction="player";leader.global_position=Vector3(148,19.1,137.4)
	var companion := Unit.new();add_child(companion);companion.faction="companion";companion.owner_unit=leader
	companion.global_position=Vector3(140,14,137)
	check(slope_guard._encounter_focus(companion)==leader,"slope entry redirects chase to leader without clearing threat")
	companion.global_position=Vector3(153,20,140)
	check(slope_guard._encounter_focus(companion)==companion,"companion resumes threat target after reaching encounter floor")
	leader.global_position=Vector3(105,24.1,126);companion.global_position=Vector3(105,24.1,126)
	guard.state=Mob.S.COMBAT;guard.threat.clear();guard.add_threat(companion,1);guard._combat(.01)
	check(guard.state==Mob.S.EVADE and guard.last_evade_reason=="different floor","owned companion upstairs cannot bypass cellar floor restriction")
	slope_guard.queue_free();leader.queue_free();companion.queue_free()
	guard.queue_free();upstairs.queue_free()
	var chests := zone.get_node("Props").get_children().filter(func(n): return n.get_script() == preload("res://src/world/sanctum_chest.gd"))
	check(chests.size()==2,"two optional chests")
	var visitor := ChestVisitor.new()
	add_child(visitor)
	for chest in chests:
		var before := int(Game.pd.money)
		visitor.global_position=chest.global_position+Vector3(20,0,0)
		chest.interact(visitor)
		check(Game.pd.money==before,"chest rejects distant interaction")
		visitor.global_position=chest.global_position+Vector3(0,0,1)
		visitor.in_combat=true
		chest.interact(visitor)
		check(Game.pd.money==before,"chest rejects combat interaction")
		visitor.in_combat=false
		chest.interact(visitor);chest.interact(visitor)
		check(Game.pd.money==before+120,"chest rewards exactly once")
		check(not chest.can_interact() and Game.has_flag("sanctum_chest_"+chest.chest_id),"chest persists opened state")
		var restored := StaticBody3D.new()
		restored.set_script(preload("res://src/world/sanctum_chest.gd"))
		restored.set("chest_id",chest.chest_id)
		add_child(restored)
		check(not restored.can_interact(),"reinstantiated chest stays open")
		restored.queue_free()
	print("SANCTUM ROUTE RESULT ", checks, " checks, failed ", failures.size())
	FileAccess.open("res://.local/sanctum_unity_workshop/spatial_route_report.json",FileAccess.WRITE).store_string(JSON.stringify({"version":FLOW.layout().version,"checks":checks,"failures":failures},"\t"))
	zone.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _upper_y(p: Vector2) -> float:
	var y := INF
	for f in FLOW.rooms():
		if int(f.phase) in [3,4] and f.kind != "blocked" and Geometry2D.is_point_in_polygon(p,FLOW.polygon(f)):
			y=minf(y,FLOW.height(f,p))
	return y

func _bell_reachable(space: PhysicsDirectSpaceState3D) -> bool:
	# Search the actual collision geometry around both sides of the door; a
	# centre-line-only gate test cannot detect a second entrance beside it.
	var pending: Array[Vector2] = [Vector2(104,84)]
	var visited := {Vector2(104,84):true}
	var shape := CapsuleShape3D.new()
	shape.radius=.5;shape.height=1.8
	var index := 0
	while index<pending.size():
		var p: Vector2=pending[index];index+=1
		if p==Vector2(64,84):return true
		var y := _upper_y(p)
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var next: Vector2=p+direction
			if visited.has(next) or next.x<54 or next.x>150 or next.y<58 or next.y>144:continue
			var ny := _upper_y(next)
			if ny==INF or absf(ny-y)>1:continue
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape=shape;q.collision_mask=1
			q.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,y+1.08,p.y))
			q.motion=Vector3(next.x-p.x,ny-y,next.y-p.y)
			if space.cast_motion(q)[0]>=.99:
				visited[next]=true
				pending.append(next)
	return false
