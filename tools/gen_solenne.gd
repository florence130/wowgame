class_name GenSolenne
extends RefCounted
## 晴岚港 v5: authored districts, native-scale buildings and connected civil works.
const PLAN := "res://docs/city_v5/layout.json"
const WATER := 8.0
const RIVER_HALF := 26.0
const CIVIL := "res://assets/models/city_v5/civil/"
const BAKED := "res://assets/models/city_v5/civil_generated/"
static var _plan: Dictionary = {}
static var _civil_index := 0
static var _building_grades: Dictionary = {}

static func plan() -> Dictionary:
	if _plan.is_empty():_plan=JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	return _plan

static func _pts(values: Array) -> Array:
	var result:=[]
	for v in values:result.append(Vector2(v[0],v[1]))
	return result

static func _interp(values: Array, t: float, axis: int) -> float:
	var other:=1-axis
	if t<=float(values[0][axis]):return float(values[0][other])
	for i in values.size()-1:
		if t<=float(values[i+1][axis]):return lerpf(float(values[i][other]),float(values[i+1][other]),(t-float(values[i][axis]))/maxf(float(values[i+1][axis])-float(values[i][axis]),.001))
	return float(values[-1][other])

static func coast_x(z: float) -> float:
	return _interp(plan()["coast_west"],z,1)

static func south_coast_z(x: float) -> float:
	return _interp(plan()["coast_south"],x,0)

static func river_dist(x: float,z: float) -> float:
	var p:=Vector2(x,z);var best:=INF
	var r:Array=plan()["river"]
	for i in r.size()-1:best=minf(best,ZoneBuilder._seg_dist(p,Vector2(r[i][0],r[i][1]),Vector2(r[i+1][0],r[i+1][1])))
	return best

static func in_city(x: float,z: float) -> bool:
	return x<366.0 and z>160.0 and z<1200.0

static func is_water(x: float,z: float) -> bool:
	return x<coast_x(z) or z>south_coast_z(x) or river_dist(x,z)<RIVER_HALF

static func _grade(x:float,z:float) -> float:
	var west:=1.0-smoothstep(-880.0,-280.0,x)
	var north:=1.0-smoothstep(380.0,650.0,z)
	var hgt:=20.0+40.0*west*north
	hgt+=18.0*(1.0-smoothstep(-800.0,-610.0,x))*smoothstep(570.0,690.0,z)*(1.0-smoothstep(840.0,940.0,z))
	for t in plan()["terraces"]:
		var dx:=maxf(0,absf(x-float(t.c[0]))-float(t.size[0])*.5)
		var dz:=maxf(0,absf(z-float(t.c[1]))-float(t.size[1])*.5)
		hgt=lerpf(hgt,float(t.y),1.0-smoothstep(0,32,Vector2(dx,dz).length()))
	var coast_distance:=south_coast_z(x)-z
	if x>-690 and x<210:hgt=lerpf(13.0,hgt,smoothstep(12.0,55.0,coast_distance))
	var dr:=river_dist(x,z)
	hgt=lerpf(14.0,hgt,smoothstep(30.0,80.0,dr))
	return hgt

static func city_h(_noise: FastNoiseLite,x:float,z:float) -> float:
	if is_water(x,z):return 2.0
	var hgt:=_grade(x,z)
	hgt=lerpf(3.0,hgt,smoothstep(0.0,12.0,x-coast_x(z)))
	hgt=lerpf(3.0,hgt,smoothstep(0.0,3.5,south_coast_z(x)-z))
	return lerpf(2.0,hgt,smoothstep(26.0,30.0,river_dist(x,z)))

static func build(b: ZoneBuilder) -> void:
	_civil_index=0;_building_grades.clear()
	b.block_fns.append(func(x,z):return in_city(x,z))
	_prepare_ground(b)
	_roads(b)
	_compounds(b)
	_buildings(b)
	_waterfront(b)
	_bridges(b)
	_defences(b)
	_transport(b)
	_gardens(b)
	_life(b)
	print("CITY V5 GENERATED: ",plan().buildings.size()," native buildings; ",plan().roads.size()," connected streets; no old manor assets")

static func _road_h(p: Vector2) -> float:
	for level in plan().road_levels:
		if p.distance_to(Vector2(level[0],level[1]))<1:return float(level[2])
	if p.x>-180.0 and p.y>=535.0 and p.y<=650.0:return 20.0
	if p.x>230.0 and p.y<500.0:return 26.0
	if p.x>=-150.0 and p.y>=650.0 and p.y<=890.0:return 18.0
	if p.x>=-900 and p.x<=-680 and p.y>=600.0 and p.y<=885.0:return 38.0
	if p.x>=-665 and p.x<=-330 and p.y>=600.0:return 13.0
	return _grade(p.x,p.y)

static func _prepare_ground(b: ZoneBuilder) -> void:
	for t in plan().terraces:b.flatten_rect(t.c[0],t.c[1],t.size[0],t.size[1],t.y,12)
	for t in plan().terraces:
		b.paint_rect(t.c[0],t.c[1],t.size[0],t.size[1],5)
	_grade_road_corridors(b)
	for s in plan().squares:b.flatten_rect(s.c[0],s.c[1],s.size[0],s.size[1],s.y,1.5 if s.id=="cathedral_square" else 7)
	for g in plan().gardens:b.flatten_rect(g.c[0],g.c[1],g.size[0],g.size[1],g.y,5)
	for item in plan().buildings:
		var x:float=item.c[0];var z:float=item.c[1];var yaw:=deg_to_rad(float(item.yaw))
		var front:=Vector2(x,z)+Vector2(-sin(yaw),-cos(yaw))*(float(item.size[2])*.5+3)
		var hgt:float=item.get("y",b.h(front.x,front.y));_building_grades[item.id]=hgt
		b.flatten_rect(x,z,float(item.size[0])+4,float(item.size[2])+5,hgt,4,yaw)
		b.flatten_rect(front.x,front.y,10,16,hgt,8,yaw)
	for g in plan().gates:
		var elevation:=18.0 if g[0]=="southeast" else 26.0
		b.flatten_rect(g[1],g[2],84,74,elevation,25)
	# The narrow final pass protects the complete carriageway and sidewalk.
	# Contributions are accumulated before writing, so intersecting streets never
	# overwrite each other in road-list order. Their shared junctions have one Y.
	_grade_road_corridors(b)
	_seat_building_ground(b)
	for iz in range(maxi(0,int((170-b.org.y)/b.cs)),mini(b.res,int((1160-b.org.y)/b.cs))):
		for ix in range(0,mini(b.res,int((366-b.org.x)/b.cs))):
			var x:=ix*b.cs+b.org.x;var z:=iz*b.cs+b.org.y
			if is_water(x,z):b.data.heights[iz*(b.res+1)+ix]=2.0

static func _grade_road_corridors(b: ZoneBuilder) -> void:
	var length_:int=b.data.heights.size()
	var weighted:=PackedFloat64Array();weighted.resize(length_)
	var weights:=PackedFloat64Array();weights.resize(length_)
	var coverage:=PackedFloat32Array();coverage.resize(length_)
	for road in plan().roads:
		var pts:=_pts(road.pts)
		var core:float=float(road.width)*.5+float(road.walk)+b.cs
		var outer:float=core+5.0
		for segment in pts.size()-1:
			var a:Vector2=pts[segment];var c:Vector2=pts[segment+1]
			var ab:=c-a;var denom:=ab.length_squared()
			if denom<.0001:continue
			var ya:float=road.heights[segment];var yc:float=road.heights[segment+1]
			var x0:=maxi(0,int(floor((minf(a.x,c.x)-outer-b.org.x)/b.cs)))
			var x1:=mini(b.res,int(ceil((maxf(a.x,c.x)+outer-b.org.x)/b.cs)))
			var z0:=maxi(0,int(floor((minf(a.y,c.y)-outer-b.org.y)/b.cs)))
			var z1:=mini(b.res,int(ceil((maxf(a.y,c.y)+outer-b.org.y)/b.cs)))
			for iz in range(z0,z1+1):
				for ix in range(x0,x1+1):
					var p:=Vector2(ix*b.cs+b.org.x,iz*b.cs+b.org.y)
					var t:=clampf((p-a).dot(ab)/denom,0,1)
					var distance:=p.distance_to(a+ab*t)
					if distance>=outer or is_water(p.x,p.y):continue
					var influence:=1.0-smoothstep(core,outer,distance)
					var weight:=influence*exp(-2.0*distance*distance/(core*core))
					var index:=iz*(b.res+1)+ix
					weighted[index]+=lerpf(ya,yc,t)*weight
					weights[index]+=weight
					coverage[index]=maxf(coverage[index],influence)
	for i in length_:
		if weights[i]>.000001:
			b.data.heights[i]=lerpf(b.data.heights[i],weighted[i]/weights[i],coverage[i])
	# Blend weights can otherwise create an accelerating lip where a branch's
	# influence ends. Project the complete road grid onto a modest grade bound.
	# Eight-neighbour constraints preserve diagonal as well as axial streets.
	var pairs:=PackedInt32Array()
	var limits:=PackedFloat32Array()
	var row_size:=b.res+1
	for iz in range(1,b.res):
		for ix in range(1,b.res):
			var index:=iz*row_size+ix
			if coverage[index]<.999:continue
			for offset in [1,row_size,row_size-1,row_size+1]:
				var other:int=index+offset
				if coverage[other]<.999:continue
				pairs.append(index);pairs.append(other)
				limits.append(.16*b.cs*(1.41421356237 if offset==row_size-1 or offset==row_size+1 else 1.0))
	for pass_ in 120:
		var largest:=0.0
		for k in limits.size():
			var a:int=pairs[k*2];var c:int=pairs[k*2+1]
			var diff:float=b.data.heights[c]-b.data.heights[a]
			var excess:=absf(diff)-limits[k]
			if excess>.00001:
				var correction:=signf(diff)*excess*.5
				b.data.heights[a]+=correction;b.data.heights[c]-=correction
				largest=maxf(largest,excess)
		if largest<.0001:break

static func _seat_building_ground(b:ZoneBuilder) -> void:
	# Parcel halos must not let a neighbour bury a ground floor or excavate
	# another building's foundation. Reassert only the physical parcel contact,
	# with a narrow transition; the main street corridor remains outside it.
	for item in plan().buildings:
		var yaw:=deg_to_rad(float(item.yaw))
		var grade:float=_building_grades[item.id]
		b.flatten_rect(item.c[0],item.c[1],float(item.size[0])+2.0,float(item.size[2])+2.0,grade,1.0,yaw)

static func _native(b:ZoneBuilder,path:String,id:String,pos:Vector3,sz:Vector3,yaw:float=0,label:String="",kind:String="house") -> ModelProp:
	var p:=ModelProp.new();p.name=id;p.asset_scene=path;p.kind=kind;p.size=sz
	p.position=pos;p.rotation_degrees.y=yaw;p.label=label
	b.groups.Buildings.add_child(p);b.block(pos.x,pos.z,maxf(sz.x,sz.z)*.55)
	return p

static func _bake(b:ZoneBuilder,m:CityV5Mesh,id:String,collide:bool=true) -> void:
	var path:=BAKED+id+".scn";var aabb:=m.pack(path,collide)
	var center:=aabb.get_center()
	var p:=_native(b,path,id,center,aabb.size,0,"","block");p.collide=collide;_civil_index+=1

static func _own_asset(n:Node,root:Node) -> void:
	n.owner=root
	for child in n.get_children():_own_asset(child,root)

static func _junction(p:Vector2,road_id:String) -> bool:
	for r in plan().roads:
		if r.id==road_id:continue
		var pts:=_pts(r.pts)
		for i in pts.size()-1:
			if ZoneBuilder._seg_dist(p,pts[i],pts[i+1])<float(r.width)*.5+float(r.walk)+2:return true
	return false

static func _roads(b:ZoneBuilder) -> void:
	for r in plan().roads:
		var m:=CityV5Mesh.new();var pts:=_pts(r.pts);_paint_path(b,pts,float(r.width)*.5+float(r.walk))
		for i in pts.size()-1:
			var a:Vector2=pts[i];var c:Vector2=pts[i+1];var direction:Vector2=(c-a).normalized()
			var side:=Vector2(-direction.y,direction.x);var steps:=maxi(1,int(ceil(a.distance_to(c)/4)))
			for k in steps:
				var p0:=a.lerp(c,float(k)/steps);var p1:=a.lerp(c,float(k+1)/steps);var mid:Vector2=(p0+p1)*.5
				if is_water(mid.x,mid.y):continue
				var y0:=b.h(p0.x,p0.y)+.035;var y1:=b.h(p1.x,p1.y)+.035
				m.ribbon([Vector3(p0.x,y0,p0.y),Vector3(p1.x,y1,p1.y)],r.width,.12,"paving" if float(r.width)<3 else "road")
				if float(r.walk)<=0:continue
				for sign_ in [-1,1]:
					var off:Vector2=side*sign_*(float(r.width)*.5+float(r.walk)*.5)
					if _junction(mid+off,r.id):continue
					m.ribbon([Vector3(p0.x+off.x,y0+.13,p0.y+off.y),Vector3(p1.x+off.x,y1+.13,p1.y+off.y)],r.walk,.22,"paving")
					var curb:Vector2=side*sign_*(float(r.width)*.5+.15)
					m.ribbon([Vector3(p0.x+curb.x,y0+.17,p0.y+curb.y),Vector3(p1.x+curb.x,y1+.17,p1.y+curb.y)],.35,.24,"cap")
		_bake(b,m,"road_"+r.id,false)

static func _paint_path(b:ZoneBuilder,pts:Array,width:float) -> void:
	b.roads.append([pts,width])
	for i in pts.size()-1:
		var a:Vector2=pts[i];var c:Vector2=pts[i+1];var n:=maxi(1,int(ceil(a.distance_to(c)/3)))
		for j in n+1:
			var p:=a.lerp(c,float(j)/n)
			if not is_water(p.x,p.y):b.paint_circle(p.x,p.y,width*.85,5,1,.25)

static func _compounds(b:ZoneBuilder) -> void:
	for s in plan().squares:
		var m:=CityV5Mesh.new();var x:float=s.c[0];var z:float=s.c[1];var h:float=s.y
		m.box(Vector3(x,h-.11,z),Vector3(s.size[0],.24,s.size[1]),"paving")
		for side in [-1,1]:m.box(Vector3(x+side*(float(s.size[0])*.5-3),h+.015,z),Vector3(.45,.025,float(s.size[1])-5),"cap")
		_bake(b,m,"square_"+s.id,false)
	for spec in [[-907,407,-807,407,60,44],[-774,407,-668,407,60,44],[-628,404,-529,404,44,31],[-491,404,-391,404,44,31],[-900,855,-834,855,38,23],[-796,867,-691,867,38,16]]:
		var m:=CityV5Mesh.new();var pts:=[Vector3(spec[0],spec[4],spec[1]),Vector3(spec[2],spec[4],spec[3])]
		m.ribbon(pts,2.2,float(spec[4])-float(spec[5])+1,"stone")
		m.ribbon([pts[0]+Vector3.UP*.2,pts[1]+Vector3.UP*.2],2.7,.6,"cap")
		_bake(b,m,"retaining_%d"%_civil_index)
	# A continuous harbour working terrace replaces separate excavations per office.
	var harbor_wall:=CityV5Mesh.new()
	for span in [[-632.0,-570.0],[-570.0,-435.0],[-435.0,-325.0]]:
		var a:=Vector3(span[0],b.h(span[0],546)+.3,550)
		var c:=Vector3(span[1],b.h(span[1],546)+.3,550)
		harbor_wall.quad(Vector3(a.x,12.6,a.z),Vector3(c.x,12.6,c.z),c,a,"stone")
		harbor_wall.ribbon([a,c],2.2,.5,"cap")
	_bake(b,harbor_wall,"harbor_retaining")
	_quay(b,[Vector2(-745,631),Vector2(-745,697)],"cathedral_east_terrace",38,2.4)
	var merchant_wall:=CityV5Mesh.new()
	merchant_wall.ribbon([Vector3(29,26,500),Vector3(127,26,500)],1.2,6.4,"stone")
	merchant_wall.ribbon([Vector3(29,26.15,500),Vector3(127,26.15,500)],1.6,.4,"cap")
	_bake(b,merchant_wall,"merchant_rear_retaining")
	# Lower academy court is reached from its east-facing houses; the upper lane stays above.
	var academy_edge:=CityV5Mesh.new()
	var edge_points:=[]
	for z in [262.0,300.0,340.0,378.0]:
		var t:float=(z-245.0)/205.0
		edge_points.append(Vector3(-661,lerpf(_road_h(Vector2(-670,245)),_road_h(Vector2(-670,450)),t)+.2,z))
	academy_edge.ribbon(edge_points,2,17,"stone")
	academy_edge.ribbon(edge_points,2.5,.5,"cap")
	_bake(b,academy_edge,"academy_upper_lane_retaining")

static func _buildings(b:ZoneBuilder) -> void:
	for item in plan().buildings:
		var path:String="res://assets/models/city_v5/"+item.family+"/"+item.asset+".glb"
		var p:=_native(b,path,item.id,Vector3(item.c[0],_building_grades[item.id]+.6,item.c[1]),Vector3(item.size[0],item.size[1],item.size[2]),item.yaw,item.label)
		p.set_meta("city_layout_version",5)
		var yaw:=deg_to_rad(float(item.yaw));var front:=Vector2(-sin(yaw),-cos(yaw));var c:=Vector2(item.c[0],item.c[1])+front*(float(item.size[2])*.5+2.2)
		b.paint_rect(c.x,c.y,float(item.size[0])+2,6,5,yaw)
		var apron:=CityV5Mesh.new();var along:=Vector2(cos(yaw),-sin(yaw))*(float(item.size[0])*.5+1)
		var divisions:=maxi(1,int(ceil(along.length()*2/3)))
		for i in divisions:
			var left:Vector2=c-along+along*2*float(i)/divisions
			var right:Vector2=c-along+along*2*float(i+1)/divisions
			var a:=left-front*2.75;var d:=right-front*2.75
			var cc:=right+front*2.75;var bb:=left+front*2.75
			apron.quad(Vector3(a.x,b.h(a.x,a.y)+.045,a.y),Vector3(d.x,b.h(d.x,d.y)+.045,d.y),Vector3(cc.x,b.h(cc.x,cc.y)+.045,cc.y),Vector3(bb.x,b.h(bb.x,bb.y)+.045,bb.y),"paving")
		_bake(b,apron,"apron_"+item.id,false)

static func _quay(b:ZoneBuilder,pts:Array,id:String,top:float=13,width:float=4.5) -> void:
	var p3:=[]
	for p in pts:p3.append(Vector3(p.x,top-.16,p.y))
	var m:=CityV5Mesh.new();m.ribbon(p3,width,top-1,"stone");var caps:=[]
	for p in p3:caps.append(p+Vector3.UP*.16)
	m.ribbon(caps,width+.5,.5,"cap");_bake(b,m,id)

static func _waterfront(b:ZoneBuilder) -> void:
	_quay(b,[Vector2(-640,930),Vector2(-620,735),Vector2(-550,650),Vector2(-332,650)],"harbor_west_north")
	_quay(b,[Vector2(-240,679),Vector2(-180,735),Vector2(-180,930),Vector2(80,1030),Vector2(230,1010)],"harbor_east")
	var river:=_pts(plan().river)
	for sign_ in [-1,1]:
		var bank:=[]
		for i in river.size():
			var prev:Vector2=river[maxi(i-1,0)];var next:Vector2=river[mini(i+1,river.size()-1)]
			var tangent:Vector2=(next-prev).normalized();var normal:=Vector2(-tangent.y,tangent.x)
			var q:Vector2=river[i]+normal*sign_*(RIVER_HALF+1.6)
			if q.y>south_coast_z(q.x)+2:continue
			bank.append(q)
		if bank.size()>1:_quay(b,bank,"riverbank_%s"%str(sign_),14,3.2)
	for x in [-530,-455,-380]:
		_quay(b,[Vector2(x,645),Vector2(x,736)],"pier_%d"%abs(x),13,12)
		for z in [670,700,728]:b.prop("barrel",x-4,z,0,Vector3(.65,.7,.65),Color.WHITE,Color.WHITE,Color("333b40"),0,"",0,"Props",13.3)
	_quay(b,[Vector2(-640,930),Vector2(-568,995),Vector2(-430,1048)],"breakwater",13,15)
	var beacon_base:=CityV5Mesh.new()
	beacon_base.box(Vector3(-430,7,1048),Vector3(30,12,30),"stone")
	beacon_base.box(Vector3(-430,12.875,1048),Vector3(31,.25,31),"cap")
	_bake(b,beacon_base,"lighthouse_platform")
	_native(b,CIVIL+"harbor_passenger_65.glb","passenger_ship",Vector3(-418,8,701),Vector3(13,24,65),0,"","steamship")
	_native(b,CIVIL+"harbor_sailing_52.glb","merchant_ship",Vector3(-493,8,704),Vector3(12,42,52),0,"","galleon")
	_native(b,CIVIL+"harbor_sailing_52.glb","outer_ship",Vector3(-300,8,955),Vector3(12,42,52),30,"","galleon")
	for z in [748,814,877]:_native(b,CIVIL+"harbor_crane.glb","crane_%d"%z,Vector3(-632,13,z),Vector3(12,23,14),270,"","crane")
	b.landmark("beacon",-430,1048,0,Vector3(9,40,9),Color("eadfc9"),Color("557b94"),Color("b8ad99"),0,"港口灯塔",13)
	b.landmark("goddess",-210,938,0,Vector3(1,39,1),Color.WHITE,Color("739890"),Color("d9d0bb"),0,"迎海女神",13)
	for i in 18:b.prop("crate",-652+float(i%3)*4,744+float(i/3)*18,0,Vector3(1.8,1.8,1.8),Color.WHITE,Color.WHITE,Color("8f704e"),i%3,"",0,"Props",13)

static func _bridges(b:ZoneBuilder) -> void:
	for p in [Vector2(20,580),Vector2(200,580)]:
		var yaw:=0.0 if p.x<100 else -22.6
		_native(b,CIVIL+"city_bridge_74.glb","bridge_%d"%int(p.x),Vector3(p.x,20,p.y),Vector3(22,9,74),yaw,"","bridge")

static func _defences(b:ZoneBuilder) -> void:
	var wall:=_pts(plan().wall)
	for i in wall.size()-1:
		var a:Vector2=wall[i];var c:Vector2=wall[i+1];var dir:Vector2=(c-a).normalized();var len_:float=a.distance_to(c)
		var intervals:=[[0.0,len_]]
		for gate in plan().gates+[ ["water",292,580,90], ["rail",261.14,850.74,90] ]:
			var gp:=Vector2(gate[1],gate[2]);var along:float=(gp-a).dot(dir)
			if ZoneBuilder._seg_dist(gp,a,c)>2:continue
			var radius:=34.0 if gate[0]=="water" else (14.0 if gate[0]=="rail" else 25.0)
			var next:=[]
			for interval in intervals:
				if float(interval[0])<along-radius:next.append([interval[0],minf(interval[1],along-radius)])
				if float(interval[1])>along+radius:next.append([maxf(interval[0],along+radius),interval[1]])
			intervals=next
		var serial:=0
		for interval in intervals:
			var length_:float=interval[1]-interval[0];var count:=maxi(1,int(ceil(length_/32.0)))
			for k in count:
				var p:Vector2=a+dir*(float(interval[0])+(float(k)+.5)*length_/count)
				_native(b,CIVIL+"city_wall_32.glb","wall_%d_%d"%[i,serial],Vector3(p.x,b.h(p.x,p.y)-.4,p.y),Vector3(32,18,7),rad_to_deg(atan2(-dir.y,dir.x)),"","wall")
				serial+=1
		var tower_clear:=true
		for gate in plan().gates:
			if a.distance_to(Vector2(gate[1],gate[2]))<42:tower_clear=false
		if i%2==0 and tower_clear:_native(b,CIVIL+"city_corner_tower.glb","bastion_%d"%i,Vector3(a.x,b.h(a.x,a.y)-.4,a.y),Vector3(22,30,22),0,"","tower")
	for g in plan().gates:
		var gate:=_native(b,CIVIL+"city_gate_grand.glb","gate_"+g[0],Vector3(g[1],b.h(g[1],g[2]),g[2]),Vector3(50,30,18),g[3],"","gate")
		gate.flag="city_access"
	var watergate:=b.prop("arch",292,580,90,Vector3(65,32,9),Color("c4b9a1"),Color("55728a"),Color("d9c9a6"),0,"水关",0,"Buildings",7)
	watergate.flag="city_access"
	var rail_portal:=CityV5Mesh.new()
	for z in [839.24,862.24]:
		rail_portal.box(Vector3(261.14,31,z),Vector3(8,22,5),"stone")
		rail_portal.box(Vector3(261.14,42.4,z),Vector3(9,.8,6),"cap")
	rail_portal.box(Vector3(261.14,41,850.74),Vector3(8,2,28),"stone")
	_bake(b,rail_portal,"rail_wall_portal")
	var ward:=CityWard.new();ward.name="CityAccessBoundary"
	var boundary:=_pts(plan().wall)
	var south:=_pts(plan().coast_south);south.reverse()
	for p in south:
		if p.x<=230 and p.x>=-880:boundary.append(p)
	var west:=_pts(plan().coast_west);west.reverse()
	for p in west:boundary.append(p)
	ward.points=PackedVector2Array(boundary);b.groups.Buildings.add_child(ward)

static func _transport(b:ZoneBuilder) -> void:
	# One level bridge deck prevents the former terrain-scaled modules creating ledges.
	var rail:=CityV5Mesh.new()
	rail.ribbon([Vector3(58,32,850),Vector3(382,32,850)],8.6,1.2,"paving")
	for x in range(60,381,20):
		var grade:=b.h(x,850)
		rail.box(Vector3(x,(grade+25.8)*.5,850),Vector3(2.4,25.8-grade,8.6),"brick")
		if x==380:continue
		for j in 12:
			var u0:=float(j)/12;var u1:=float(j+1)/12
			var x0:=x+1.2+17.6*u0;var x1:=x+1.2+17.6*u1
			var y0:=25.8+4.2*sin(u0*PI);var y1:=25.8+4.2*sin(u1*PI)
			rail.quad(Vector3(x0,30.8,845.7),Vector3(x1,30.8,845.7),Vector3(x1,y1,845.7),Vector3(x0,y0,845.7),"brick")
			rail.quad(Vector3(x0,y0,854.3),Vector3(x1,y1,854.3),Vector3(x1,30.8,854.3),Vector3(x0,30.8,854.3),"brick")
			rail.quad(Vector3(x0,y0,854.3),Vector3(x0,y0,845.7),Vector3(x1,y1,845.7),Vector3(x1,y1,854.3),"stone")
	_bake(b,rail,"rail_viaduct")
	var rails:=CityV5Mesh.new()
	for z in [848.8,851.2]:rails.ribbon([Vector3(58,32.12,z),Vector3(382,32.12,z)],.13,.12,"dark")
	for x in range(60,381,3):rails.box(Vector3(x,32.035,850),Vector3(.32,.07,3.4),"dark")
	_bake(b,rails,"rail_tracks",false)
	b.prop("train",178,850,0,Vector3(16,4,3.5),Color.WHITE,Color("a9463d"),Color("e0bd78"),1,"",0,"Props",34)
	var m:=CityV5Mesh.new();m.box(Vector3(-901,59.5,230),Vector3(66,1,40),"paving");_bake(b,m,"airship_platform")
	b.prop("airship",-910,230,90,Vector3(12,12,36),Color("efe1c6"),Color("566e8f"),Color("765b42"),0,"",0,"Props",75)
	b.landmark("clock_spire",-65,416,0,Vector3(12,44,12),Color("ddcfb7"),Color("5d748c"),Color("b4aa94"),0,"晴岚钟楼",26)

static func _garden_props(b:ZoneBuilder,g:Dictionary) -> void:
	var x:float=g.c[0];var z:float=g.c[1];var w:float=g.size[0];var d:float=g.size[1];var y:float=g.y
	b.paint_rect(x,z,w,d,7)
	_paint_path(b,[Vector2(x-w*.5,z),Vector2(x+w*.5,z)],3)
	_paint_path(b,[Vector2(x,z-d*.5),Vector2(x,z+d*.5)],3)
	for sx in [-1,1]:
		for sz in [-1,1]:
			var c:=Vector2(x+sx*w*.27,z+sz*d*.27)
			b.prop("flowerbed",c.x,c.y,0,Vector3(w*.28,.55,d*.22),Color.WHITE,Color("63844c"),Color("c5b897"),int(sx+sz+2)%5,"",0,"Props",y)
			b.prop("hedge",c.x,c.y+sz*d*.12,0,Vector3(w*.29,1.0,1.1),Color.WHITE,Color("426449"),Color.WHITE,0,"",0,"Props",y)
			b.forest("oak",[Vector2(x+sx*w*.43,z+sz*d*.41)],Color("658953"),.8,1.0)
			b.prop("bench",x+sx*8,z+sz*7,0 if sz<0 else 180,Vector3(2.6,1,1),Color.WHITE,Color.WHITE,Color("715c45"),0,"",0,"Props",y)

static func _gardens(b:ZoneBuilder) -> void:
	for g in plan().gardens:_garden_props(b,g)
	for p in [[-180,411,26,8], [80,398,26,7], [60,710,18,8],[-785,676,38,6],[-540,371,44,5],[-820,390,60,7]]:
		b.prop("fountain",p[0],p[1],0,Vector3(p[3],3,p[3]),Color("e4dcc8"),Color("67949c"),Color("c4b596"),0,"",0,"Props",p[2])
	for r in plan().roads:
		var pts:=_pts(r.pts)
		for i in pts.size()-1:
			var a:Vector2=pts[i];var c:Vector2=pts[i+1];var dir:Vector2=(c-a).normalized();var side:=Vector2(-dir.y,dir.x)
			var n:=int(a.distance_to(c)/38)
			for k in n:
				var mid:=a.lerp(c,(float(k)+.5)/maxf(n,1))
				for sign_ in [-1,1]:
					var p:Vector2=mid+side*sign_*(float(r.width)*.5+float(r.walk)-.5)
					if is_water(p.x,p.y) or _junction(p,r.id):continue
					b.prop("lamp2",p.x,p.y,0,Vector3(2,5,.6),Color.WHITE,Color.WHITE,Color.WHITE,0,"",0,"Props")
	for x in [-250,-210,-150,-110]:b.forest("oak",[Vector2(x,375)],Color("62834c"),.8,1)
	for p in [Vector2(-860,430),Vector2(-720,431),Vector2(-620,430),Vector2(-560,430),Vector2(-460,430),Vector2(-400,430)]:b.forest("oak",[p],Color("62834c"),.85,1.1)
	# Small bosquets frame the main public rooms without blocking their central walks.
	for p in [Vector2(-272,410),Vector2(-272,431),Vector2(-88,410),Vector2(-88,431),Vector2(-4,714),Vector2(124,714),Vector2(-4,756),Vector2(124,756),Vector2(-611,620),Vector2(-594,620),Vector2(-402,620),Vector2(-385,620)]:
		b.forest("oak",[p],Color("62834c"),1.35,1.55)

static func _life(b:ZoneBuilder) -> void:
	for n in plan().npcs:b.npc(n.id,n.p[0],n.p[1],n.yaw,0,float(n.get("y",b.h(n.p[0],n.p[1]))))
	for p in plan().pois:b.poi(p.id,p.title,p.p[0],p.p[1],p.radius,p.priority,true,p.xp)
	for s in plan().spawns:b.spawn_point(s.id,s.p[0],s.p[1],s.yaw)
	b.prop("anvil",-186,511,0,Vector3.ONE,Color.WHITE,Color.WHITE,Color.WHITE,0,"",0,"Props",26.6)
	b.prop("brazier",-175,514,0,Vector3.ONE,Color.WHITE,Color("dc994e"),Color.WHITE,0,"",0,"Props",26.6)
