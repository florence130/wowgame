extends Node
## Read-only sampling of the saved TerrainData. Does not instance the city.

var terrain: TerrainData
var plan: Dictionary
var origin := Vector2.ZERO
var bridges: Array = []
var report: Dictionary

func transform_record(scene_text: String, node_name: String) -> Dictionary:
	var re := RegEx.new()
	re.compile('(?s)\\[node name="' + node_name + '"[^\\n]*\\]\\n(.*?)(?=\\n\\[|$)')
	var found := re.search(scene_text)
	if found == null:
		return {}
	var tr := RegEx.new()
	tr.compile('transform = Transform3D\\(([^)]+)\\)')
	var hit := tr.search(found.get_string(1))
	if hit == null:
		return {}
	var raw := hit.get_string(1).split(',')
	var v: Array[float] = []
	for x in raw:
		v.append(float(x.strip_edges()))
	return {"c":Vector2(v[9],v[11]),"y":v[10],"yaw":atan2(v[2],v[0])}

func sample(p: Vector2) -> float:
	return terrain.sample(p.x-origin.x,p.y-origin.y)

func boundary_interp(values: Array, t: float, axis: int) -> float:
	var other := 1-axis
	if t<=float(values[0][axis]):return float(values[0][other])
	for i in range(values.size()-1):
		if t<=float(values[i+1][axis]):
			return lerpf(float(values[i][other]),float(values[i+1][other]),(t-float(values[i][axis]))/maxf(float(values[i+1][axis])-float(values[i][axis]),.001))
	return float(values[-1][other])

func point_is_water(p: Vector2) -> bool:
	if p.x<boundary_interp(plan.coast_west,p.y,1) or p.y>boundary_interp(plan.coast_south,p.x,0):return true
	for i in range(plan.river.size()-1):
		var a:=Vector2(plan.river[i][0],plan.river[i][1])
		var b:=Vector2(plan.river[i+1][0],plan.river[i+1][1])
		var q:=a+(b-a)*clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
		if p.distance_to(q)<26:return true
	return false

func excluded(p: Vector2) -> String:
	for b in bridges:
		var q: Vector2 = p-b.c
		var c := cos(float(b.yaw))
		var s := sin(float(b.yaw))
		var local := Vector2(c*q.x-s*q.y,s*q.x+c*q.y)
		if absf(local.x)<11.5 and absf(local.y)<37.5:
			return "authored_bridge_deck_above_terrain"
	if point_is_water(p):
		return "water_or_unbridged_road_design_gap"
	return ""

func nearby(p: Vector2) -> Array:
	var near: Array = []
	for b in plan.buildings:
		var dist := p.distance_to(Vector2(b.c[0],b.c[1]))
		if dist<55:
			near.append({"id":b.id,"c":b.c,"declared_grade":b.get("y",null),"center_distance":snappedf(dist,.01)})
	near.sort_custom(func(a,b):return a.center_distance<b.center_distance)
	return near.slice(0,5)

func vec(p: Vector2,y: float) -> Array:
	return [snappedf(p.x,.001),snappedf(y,.001),snappedf(p.y,.001)]

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	terrain=load("res://data/terrain/tidewind.res") as TerrainData
	plan=JSON.parse_string(FileAccess.get_file_as_string("res://docs/city_v5/layout.json"))
	var scene_text := FileAccess.get_file_as_string("res://scenes/zones/tidewind_highlands.tscn")
	var tf := transform_record(scene_text,"Terrain")
	if tf.is_empty():
		push_error("Could not read terrain origin; refusing guessed sampling")
		get_tree().quit(1)
		return
	origin=tf.c
	for name_ in ["bridge_20","bridge_200"]:
		var b:=transform_record(scene_text,name_)
		if not b.is_empty():bridges.append(b)
	var roads: Array = []
	var worst: Array = []
	var pits: Array = []
	var sampled := 0
	for r in plan.roads:
		var lanes: Array = []
		var lane_defs := [["center",0.0],["car_left",float(r.width)*.5-.25],["car_right",-float(r.width)*.5+.25],["walk_left",float(r.width)*.5+float(r.walk)*.5],["walk_right",-float(r.width)*.5-float(r.walk)*.5]]
		for lane in lane_defs:
			var all_points: Array = []
			var max_grade := 0.0
			var worst_one: Dictionary = {}
			for si in range(r.pts.size()-1):
				var a:=Vector2(r.pts[si][0],r.pts[si][1])
				var b:=Vector2(r.pts[si+1][0],r.pts[si+1][1])
				var direction:Vector2=(b-a).normalized()
				var side:=Vector2(-direction.y,direction.x)*float(lane[1])
				var n:=maxi(1,int(ceil(a.distance_to(b)/2.0)))
				var part: Array = []
				for i in range(n+1):
					var p:=a.lerp(b,float(i)/n)+side
					var h:=sample(p)
					var skip:=excluded(p)
					part.append({"p":p,"h":h,"exclude":skip})
					all_points.append({"segment":si,"position":vec(p,h),"exclude":skip})
					sampled+=1
					if i>0 and skip=="" and part[i-1].exclude=="":
						var prev:Dictionary=part[i-1]
						var slope:=absf(h-float(prev.h))/p.distance_to(prev.p)*100.0
						if slope>max_grade:
							max_grade=slope
							worst_one={"road":r.id,"lane":lane[0],"segment":si,"a":vec(prev.p,prev.h),"b":vec(p,h),"percent":snappedf(slope,.01),"degrees":snappedf(rad_to_deg(atan(slope/100.0)),.01),"nearby_buildings":nearby((p+prev.p)*.5)}
				for i in range(5,part.size()-5):
					if part[i-5].exclude!="" or part[i].exclude!="" or part[i+5].exclude!="":continue
					var chord:float=(float(part[i-5].h)+float(part[i+5].h))*.5
					var depth:=chord-float(part[i].h)
					if depth>1.5:
						pits.append({"road":r.id,"lane":lane[0],"position":vec(part[i].p,part[i].h),"depression_below_20m_chord":snappedf(depth,.01),"nearby_buildings":nearby(part[i].p)})
			if not worst_one.is_empty():worst.append(worst_one)
			lanes.append({"lane":lane[0],"offset":lane[1],"max_longitudinal_percent":snappedf(max_grade,.01),"samples":all_points})
		roads.append({"road":r.id,"lanes":lanes})
	worst.sort_custom(func(a,b):return a.percent>b.percent)
	pits.sort_custom(func(a,b):return a.depression_below_20m_chord>b.depression_below_20m_chord)
	report={"scope":"Read-only actual saved TerrainData.sample() along road centers, both carriageway edges and both sidewalk centers, spacing <=2m. No city or Player instancing; not runtime traversal acceptance.","terrain_sha256":FileAccess.get_sha256("res://data/terrain/tidewind.res"),"layout_sha256":FileAccess.get_sha256("res://docs/city_v5/layout.json"),"scene_sha256":FileAccess.get_sha256("res://scenes/zones/tidewind_highlands.tscn"),"terrain_resolution":terrain.resolution,"terrain_cell_size":terrain.cell_size,"terrain_origin":[origin.x,origin.y],"road_count":roads.size(),"sample_count":sampled,"worst_by_road_lane":worst,"depressions":pits,"roads":roads,"limitations":["Road ribbon mesh tops and elevated bridges are not TerrainData. Bridge footprints are excluded from terrain-slope alarms.","Water segments are marked excluded and must be validated separately as bridges or layout gaps.","A 2m finite difference can smooth sharper triangle normals; no real-player pass is inferred.","Nearby buildings are spatial context; causal attribution requires checking generation order and grading footprints."]}
	FileAccess.open("res://docs/city_v5/terrain_audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CITY_TERRAIN_AUDIT roads=",roads.size()," samples=",sampled," worst=",JSON.stringify(worst.slice(0,8)))
	get_tree().quit(0)
