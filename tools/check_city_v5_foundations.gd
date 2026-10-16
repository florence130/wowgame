extends Node
## Read-only audit of saved scene placement against the real TerrainData resource.
## Does not instantiate World, load a character, generate terrain, or save gameplay.
const PLAN := "res://docs/city_v5/layout.json"
const SCENE := "res://scenes/zones/tidewind_highlands.tscn"
const TERRAIN := "res://data/terrain/tidewind.res"
var out := "res://.local/city_v5/foundation_audit.json"
var terrain: TerrainData
var origin := Vector2.ZERO
var manifests := {}
var scene_transforms := {}
var source_hashes := {}

func _ready() -> void:
	Game.slot_index=-1
	Game.world=null
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):out=arg.substr(4)
	call_deferred("run")

func props(state:SceneState,index:int) -> Dictionary:
	var result:Dictionary={}
	for j in state.get_node_property_count(index):result[String(state.get_node_property_name(index,j))]=state.get_node_property_value(index,j)
	return result

func point2(value:Array) -> Vector2:
	return Vector2(value[0],value[1])

func sample(x:float,z:float) -> float:
	return terrain.sample(x-origin.x,z-origin.y)

func polygon_for(info:Dictionary) -> PackedVector2Array:
	var points:=PackedVector2Array()
	if info.has("footprint_polygon"):
		for p in info.footprint_polygon:points.append(point2(p))
	elif info.id=="governor_palace":
		# Actual union of authored side wings (20x70 at x=+-40) and rear wing (60x22 at z24).
		for p in [[-50,-35],[-30,-35],[-30,13],[30,13],[30,-35],[50,-35],[50,35],[-50,35]]:points.append(point2(p))
	elif info.id=="civic_hall":
		# Three authored shells: centre 36x40, side wings 26x36 at x=+-31.
		for p in [[-44,-18],[-18,-18],[-18,-20],[18,-20],[18,-18],[44,-18],[44,18],[18,18],[18,20],[-18,20],[-18,18],[-44,18]]:points.append(point2(p))
	else:
		var w:float=info.footprint[0]*.5;var d:float=info.footprint[1]*.5
		points=PackedVector2Array([Vector2(-w,-d),Vector2(w,-d),Vector2(w,d),Vector2(-w,d)])
	return points

func measured(xf:Transform3D,p:Vector2,street_y:float,bottom_y:float,kind:String) -> Dictionary:
	var world:Vector3=xf*Vector3(p.x,0,p.y)
	var h:=sample(world.x,world.z)
	return {"kind":kind,"local_model":[p.x,p.y],"city":[world.x,world.z],"terrain_y":h,"street_y":street_y,"foundation_bottom_y":bottom_y,"terrain_minus_street":h-street_y,"exposed_foundation_gap":maxf(0,bottom_y-h),"terrain_above_floor":maxf(0,h-xf.origin.y)}

func entries_for(info:Dictionary) -> Array:
	var result:=[]
	if info.has("entry"):
		for entry in info.entry:
			if not entry is Dictionary:continue
			result.append({"p":Vector2(entry.position[0],entry.position[2]),"outward":Vector2(entry.outward[0],entry.outward[2]),"depth":float(entry.get("approach_depth",3.0))+1.0})
	elif info.has("entries"):
		for entry in info.entries:
			var p:=Vector2(entry[0],entry[2])
			var outward:=Vector2(0,-1 if p.y<=0 or info.id=="governor_palace" else 1)
			result.append({"p":p,"outward":outward,"depth":7.0})
	return result

func run() -> void:
	var start:=Time.get_ticks_msec()
	for path in [PLAN,SCENE,TERRAIN,"res://assets/models/city_v5/architecture/manifest.json","res://assets/models/city_v5/landmarks/manifest.json"]:source_hashes[path]=FileAccess.get_sha256(path)
	for path in ["res://assets/models/city_v5/architecture/manifest.json","res://assets/models/city_v5/landmarks/manifest.json"]:
		var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		for row in doc.assets:manifests[row.id]=row
	var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	var packed:=load(SCENE) as PackedScene
	var state:=packed.get_state()
	for i in state.get_node_count():
		var id:=String(state.get_node_name(i));var values:=props(state,i)
		var xf:Transform3D=values.get("transform",Transform3D.IDENTITY)
		if id=="Terrain":origin=Vector2(xf.origin.x,xf.origin.z)
		if String(state.get_node_path(i,true)).trim_prefix("./")=="Buildings":scene_transforms[id]=xf
	terrain=load(TERRAIN) as TerrainData
	var buildings:=[];var issues:=[];var mismatches:=[];var missing:=[];var samples_count:=0
	for row in plan.buildings:
		if not scene_transforms.has(row.id) or not manifests.has(row.asset):missing.append(row.id);continue
		var xf:Transform3D=scene_transforms[row.id];var info:Dictionary=manifests[row.asset]
		if Vector2(xf.origin.x,xf.origin.z).distance_to(point2(row.c))>.02 or absf(wrapf(rad_to_deg(xf.basis.get_euler().y)-float(row.yaw),-180,180))>.01:mismatches.append(row.id)
		var street_y:float=xf.origin.y+float(info.get("street_y",-.6))
		var bottom_y:float=xf.origin.y+float(info.get("foundation_bottom_y",info.get("foundation_y",-1.2)))
		var poly:=polygon_for(info);var boundary:=[];var corners:=[];var approaches:=[]
		var max_gap:=0.0;var max_buried:=0.0;var max_entry_error:=0.0
		for index in poly.size():
			var a:=poly[index];var b:=poly[(index+1)%poly.size()]
			var steps:=maxi(1,int(ceil(a.distance_to(b)/2.0)))
			for k in steps:
				var p:=a.lerp(b,float(k)/float(steps));var hit:=measured(xf,p,street_y,bottom_y,"structural_perimeter")
				boundary.append(hit);max_gap=maxf(max_gap,hit.exposed_foundation_gap);max_buried=maxf(max_buried,hit.terrain_above_floor)
		var w:float=info.footprint[0]*.5;var d:float=info.footprint[1]*.5
		for p in [Vector2(-w,-d),Vector2(w,-d),Vector2(w,d),Vector2(-w,d)]:
			var hit:=measured(xf,p,street_y,bottom_y,"nominal_rectangle_corner")
			hit["inside_actual_footprint"]=Geometry2D.is_point_in_polygon(p,poly)
			hit["used_for_failure"]=false
			corners.append(hit)
		for entry in entries_for(info):
			# The street landing, beyond the authored stair/ramp, is sampled separately from the raised door floor.
			var p:Vector2=entry.p+entry.outward*entry.depth
			var hit:=measured(xf,p,street_y,bottom_y,"entry_street_landing")
			approaches.append(hit);max_entry_error=maxf(max_entry_error,absf(hit.terrain_minus_street))
		var risks:=[]
		if max_gap>.20:risks.append("terrain_below_foundation_bottom")
		if max_buried>.25:risks.append("terrain_above_ground_floor")
		if max_entry_error>.85:risks.append("entry_landing_height_mismatch")
		var summary:={"id":row.id,"asset":row.asset,"scene_root_y":xf.origin.y,"authored_grade":row.get("y",null),"street_y":street_y,"foundation_bottom_y":bottom_y,"footprint_source":"manifest_polygon" if info.has("footprint_polygon") else ("authored_shell_union" if info.id in ["governor_palace","civic_hall"] else "manifest_rectangle"),"perimeter_sample_count":boundary.size(),"max_exposed_foundation_gap":max_gap,"max_terrain_above_floor":max_buried,"max_entry_grade_error":max_entry_error,"risks":risks,"perimeter":boundary,"rectangle_corners":corners,"entry_landings":approaches}
		buildings.append(summary);samples_count+=boundary.size()+corners.size()+approaches.size()
		if not risks.is_empty():issues.append({"id":row.id,"risks":risks,"max_exposed_foundation_gap":max_gap,"max_terrain_above_floor":max_buried,"max_entry_grade_error":max_entry_error,"worst_samples":boundary.filter(func(h):return h.exposed_foundation_gap>.20 or h.terrain_above_floor>.25).slice(0,12),"entry_landings":approaches})
	var stable:=true
	for path in source_hashes:stable=stable and source_hashes[path]==FileAccess.get_sha256(path)
	var report:={"complete":true,"stable_sources":stable,"slot_index":Game.slot_index,"world_instanced":Game.world!=null,"source_hashes":source_hashes,"layout_version":plan.version,"expected_buildings":plan.buildings.size(),"checked_buildings":buildings.size(),"samples":samples_count,"perimeter_max_step_m":2.0,"terrain_origin":[origin.x,origin.y],"thresholds":{"exposed_gap":.20,"terrain_above_floor":.25,"entry_grade_error":.85},"missing":missing,"scene_layout_mismatches":mismatches,"issues":issues,"buildings":buildings,"elapsed_seconds":float(Time.get_ticks_msec()-start)/1000,"scope":"Saved scene transforms + actual TerrainData; no World or physics instances. Nominal rectangle corners outside an L/U silhouette are recorded, not treated as structural support. Entry samples are outside model ramps; paths and custom aprons still require actual Player verification."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CITY_FOUNDATIONS buildings=",buildings.size()," samples=",samples_count," issues=",issues.size()," mismatches=",mismatches.size()," stable=",stable," report=",out)
	get_tree().quit(0 if stable and missing.is_empty() and mismatches.is_empty() else 2)
