class_name VillageComposition
extends RefCounted
## Town circulation and canopy clearance, applied to the zone's private data
## before streaming registers terrain, vegetation, visual meshes or collisions.
const CENTER := Vector2(435,470)
const STEP := 2.0
const GRID := Rect2i(0,0,141,151)
const ORIGIN := Vector2(290,300)
const ASSETS := "res://assets/models/roadside_cc0/rebuilt/"
static var _road_cells:Dictionary={}
static var _obstacle_cells:Dictionary={}

static func apply(zone: Zone) -> void:
	if zone.has_meta("mmo_composition") or zone.terrain == null:
		return
	var houses: Array=[]
	var obstacles: Array=[]
	var meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/village_kit/buildings.json"))
	for n in zone.find_children("*","",true,false):
		if n is Waystone:
			obstacles.append({"inverse":n.transform.affine_inverse(),"node":n,"half":Vector2(2.7,2.7)})
		if n is ModelProp and n.collide and n.kind not in ["field","rug","web"] and not n.asset_scene.contains("/village_kit/"):
			var footprint:Vector3=n.size
			if ModelProp.LIB.has(n.kind):
				var mode:String=ModelProp.LIB[n.kind][2]
				var nominal:=ModelProp.nominal(n.model_name())
				if mode=="fixed":footprint=nominal
				elif mode=="x":footprint=nominal*n.size.x/maxf(nominal.x,.01)
			obstacles.append({"inverse":n.transform.affine_inverse(),"node":n,"half":Vector2(footprint.x,footprint.z)*.5})
		if n is ModelProp and n.asset_scene.contains("/village_kit/"):
			var id: String=n.asset_scene.get_file().get_basename()
			if meta.has(id):
				houses.append({"inverse":n.transform.affine_inverse(),"node":n,"half":Vector2(meta[id].w,meta[id].d)*.5})
	var data:=zone.terrain.data
	_index_obstacles(obstacles)
	data.texture_overrides=data.texture_overrides.duplicate()
	data.texture_overrides[5]="res://assets/textures/mmo/town_stone.png"
	var grid:=AStarGrid2D.new()
	grid.region=GRID;grid.cell_size=Vector2.ONE*STEP
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(GRID.size.y):
		for x in range(GRID.size.x):
			var point:=ORIGIN+Vector2(x,y)*STEP
			var height:=_height(zone,point)
			var steep:=maxf(absf(_height(zone,point+Vector2(STEP,0))-height),absf(_height(zone,point+Vector2(0,STEP))-height))/STEP
			var nearby:Array=_obstacle_cells.get(Vector2i(point/16.0),[])
			var blocked:=not _clear(point,houses,3.2) or not _clear(point,nearby,1.6) or steep>.65 or height<data.water_level+1.1
			grid.set_point_solid(Vector2i(x,y),blocked)
			if not blocked:
				grid.set_point_weight_scale(Vector2i(x,y),1.0+steep*5.0)
	var routes: Array=[]
	for pair in [[Vector2(435,486),Vector2(455,580)],[Vector2(415,470),Vector2(320,455)],[Vector2(455,470),Vector2(550,470)],[Vector2(455,448),Vector2(486,330)]]:
		var start:=_nearest(grid,pair[0])
		var end:=_nearest(grid,pair[1])
		var ids:=grid.get_id_path(start,end)
		var points: Array[Vector2]=[]
		for id in ids:points.append(ORIGIN+Vector2(id)*STEP)
		if points.size()>1:
			routes.append(points)
			_paint_route(zone,points,houses)
	_index_roads(routes)
	var trimmed:=_canopies(zone,houses,routes)
	var placed:=_roadside(zone,houses,routes)
	zone.set_meta("mmo_composition",{"vegetation_cleared":trimmed,"road_count":routes.size(),"props":placed,"source":"Kenney CC0 / rebuilt project materials"})
	zone.set_meta("mmo_road_paths",routes)
	print("MMO COMPOSITION ",JSON.stringify(zone.get_meta("mmo_composition")))

static func _height(zone:Zone,p:Vector2)->float:
	var origin:=zone.terrain.position
	return zone.terrain.data.sample(p.x-origin.x,p.y-origin.z)+origin.y

static func _index_obstacles(obstacles:Array)->void:
	_obstacle_cells.clear()
	for obstacle in obstacles:
		var xf:Transform3D=obstacle.inverse.affine_inverse()
		var half:Vector2=obstacle.half
		var lo:=Vector2(INF,INF);var hi:=Vector2(-INF,-INF)
		for sx in [-1.0,1.0]:
			for sz in [-1.0,1.0]:
				var q:Vector3=xf*Vector3(half.x*sx,0,half.y*sz)
				lo=lo.min(Vector2(q.x,q.z));hi=hi.max(Vector2(q.x,q.z))
		# 1.6m local-box expansion may extend sqrt(2) farther on a diagonal.
		var first:=Vector2i((lo-Vector2.ONE*3.0)/16.0)
		var last:=Vector2i((hi+Vector2.ONE*3.0)/16.0)
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var key:=Vector2i(x,y)
				if not _obstacle_cells.has(key):_obstacle_cells[key]=[]
				_obstacle_cells[key].append(obstacle)

static func _clear(point:Vector2,houses:Array,margin:float)->bool:
	for house in houses:
		var q:Vector3=house.inverse*Vector3(point.x,house.node.position.y,point.y)
		var s:float=house.node.transform.basis.x.length()
		var extra:=margin/maxf(s,.01)
		if absf(q.x)<house.half.x+extra and absf(q.z)<house.half.y+extra:return false
	return true

static func _nearest(grid:AStarGrid2D,point:Vector2)->Vector2i:
	var center:=Vector2i((point-ORIGIN)/STEP)
	for radius in 20:
		for y in range(center.y-radius,center.y+radius+1):
			for x in range(center.x-radius,center.x+radius+1):
				var id:=Vector2i(x,y)
				if grid.is_in_boundsv(id) and not grid.is_point_solid(id):return id
	return center

static func _paint_route(zone:Zone,points:Array[Vector2],houses:Array)->void:
	var data:=zone.terrain.data
	var origin:=zone.terrain.position
	for i in range(1,points.size()):
		var a:=points[i-1];var b:=points[i]
		var lo:Vector2=a.min(b)-Vector2.ONE*6
		var hi:Vector2=a.max(b)+Vector2.ONE*6
		for z in range(maxi(0,floori((lo.y-origin.z)/data.cell_size)),mini(data.resolution,ceili((hi.y-origin.z)/data.cell_size))):
			for x in range(maxi(0,floori((lo.x-origin.x)/data.cell_size)),mini(data.resolution,ceili((hi.x-origin.x)/data.cell_size))):
				var p:=Vector2(x*data.cell_size+origin.x,z*data.cell_size+origin.z)
				if not _clear(p,houses,.9):continue
				var distance:=p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))
				var uneven:=sin(p.x*.19+p.y*.11)*.26+sin(p.y*.37)*.16
				var weight:=1.0-smoothstep(2.6+uneven,4.4+uneven,distance)
				if weight>.01:data.paint_pixel(x,z,5 if p.distance_to(CENTER)<35 else 2,weight*.96)

static func _index_roads(routes:Array)->void:
	_road_cells.clear()
	for route in routes:
		for i in range(1,route.size()):
			var a:Vector2=route[i-1];var b:Vector2=route[i]
			var lo:Vector2i=Vector2i((a.min(b)-Vector2.ONE*24.0)/16.0)
			var hi:Vector2i=Vector2i((a.max(b)+Vector2.ONE*24.0)/16.0)
			for y in range(lo.y,hi.y+1):
				for x in range(lo.x,hi.x+1):
					var key:=Vector2i(x,y)
					if not _road_cells.has(key):_road_cells[key]=[]
					_road_cells[key].append([a,b])

static func _road_distance(p:Vector2,_routes:Array)->float:
	var distance:=INF
	for segment in _road_cells.get(Vector2i(p/16.0),[]):
		distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,segment[0],segment[1])))
	return distance

static func _canopies(zone:Zone,houses:Array,routes:Array)->int:
	var trimmed:=0
	for n in zone.find_children("*","",true,false):
		if not n is Forest or n.kind not in ["oak","birch","pine","rock"]:continue
		var points:=PackedVector3Array();var scales:=PackedFloat32Array();var shapes:=PackedVector3Array();var ids:=PackedInt32Array()
		for i in n.points.size():
			var local:Vector3=n.transform*n.points[i]
			var p:=Vector2(local.x,local.z)
			var in_town:=p.distance_to(CENTER)<112.0
			var is_tree:bool=n.kind!="rock"
			var size:float=n.scales[i] if i<n.scales.size() else 1.0
			var clearance:float=8.0 if is_tree else maxf(5.0,size*2.0+3.0)
			var remove:bool=_road_distance(p,routes)<clearance or (is_tree and in_town and (p.distance_to(CENTER)<36.0 or not _clear(p,houses,4.5)))
			if remove:
				trimmed+=1
				continue
			points.append(n.points[i])
			scales.append(size*.84 if in_town and is_tree else size)
			var seed_id:int=n.point_ids[i] if i<n.point_ids.size() else i
			var shape:Vector3=n.shapes[i] if i<n.shapes.size() else Vector3(float(hash(seed_id*7919)%628)/100.0,1,1)
			if in_town and is_tree:
				shape.y*=.78;shape.z*=.78
			shapes.append(shape)
			ids.append(seed_id)
		n.points=points;n.scales=scales;n.shapes=shapes;n.point_ids=ids
	return trimmed

static func _roadside(zone:Zone,houses:Array,routes:Array)->int:
	var group:=zone.get_node_or_null("Props")
	if group==null:return 0
	var placed:=0
	for item in [["cart-high",Vector2(442,551),65.0],["cart",Vector2(464,564),-15.0],["stall-bench",Vector2(440,545),10.0],["banner-green",Vector2(462,548),-15.0]]:
		var p:Vector2=item[1]
		if not _clear(p,houses,2.5) or _road_distance(p,routes)<4.4:continue
		var prop:=ModelProp.new()
		prop.name="Roadside_"+str(placed)
		prop.kind="cart"
		prop.asset_scene=ASSETS+item[0]+".glb"
		prop.position=Vector3(p.x,_height(zone,p)+.025,p.y)
		prop.rotation.y=deg_to_rad(item[2])
		prop.collide=true
		group.add_child(prop)
		placed+=1
	return placed
