class_name CityV5StationPlaza
extends RefCounted
## Station forecourt south of the public street, keeping the x=0 court exit clear.
## CANDIDATE ONLY: user requested station views / Tripo module design first.
## Do not integrate until the new station design determines the final forecourt.
## Integration: prepare_ground(b) with final ground shaping; build(b, _bake) after
## ordinary streets/compounds. bake Callable signature is (ZoneBuilder, CityV5Mesh, id, collide).
const GRADE := 18.0
const WEST := 8.0
const EAST := 112.0
const NORTH := 748.0
const SOUTH := 773.0

static func metadata() -> Dictionary:
	return {"id":"station_forecourt","label":"车站前广场","c":[60,760.5],"size":[104,25],"y":GRADE,"public_road_clear_until_z":747,"court_exit_clear_x":[-3,3],"pedestrian_axis":{"x":60,"width":12,"z":[747,777]},"dropoff_band":{"x":[18,102],"z":[748,754]},"gathering_area":{"x":[8,112],"z":[755,773]},"notes":"Forecourt remains level with the station street landing. Existing station steps handle the 0.6m rise to the hall. NPCs, train and flight markers are not moved."}

static func prepare_ground(b:ZoneBuilder) -> void:
	# No broad falloff: do not rewrite the adjacent public road or the x=0 courtyard passage.
	b.flatten_rect(60,760.5,104,25,GRADE,.75)
	b.paint_rect(60,760.5,104,25,5)

static func _band(mesh:CityV5Mesh,c:Vector2,size:Vector2,y:float,material:String) -> void:
	mesh.box(Vector3(c.x,y-.015,c.y),Vector3(size.x,.03,size.y),material)

static func build(b:ZoneBuilder,bake:Callable) -> void:
	var paving:=CityV5Mesh.new()
	# Flush visual surfacing; TerrainData supplies walking support. No invisible curb edge.
	_band(paving,Vector2(60,760.5),Vector2(104,25),GRADE+.028,"paving")
	# Distinct drop-off bay with two links through the public pavement. The main carriageway remains untouched.
	_band(paving,Vector2(60,751),Vector2(84,6),GRADE+.036,"road")
	for x in [24.0,96.0]:_band(paving,Vector2(x,745.5),Vector2(12,5),GRADE+.03,"road")
	# Twelve-metre gathering axis visibly joins the station's actual central doorway.
	_band(paving,Vector2(60,760),Vector2(12,26),GRADE+.045,"cap")
	for x in [53.5,66.5]:_band(paving,Vector2(x,762),Vector2(.35,22),GRADE+.05,"dark")
	# A legible perimeter frames the pedestrian room without fencing its exits.
	for x in [8.35,111.65]:_band(paving,Vector2(x,762.5),Vector2(.7,21),GRADE+.046,"cap")
	for span in [[8.0,43.0],[77.0,112.0]]:
		_band(paving,Vector2((span[0]+span[1])*.5,772.6),Vector2(span[1]-span[0],.7),GRADE+.046,"cap")
	for span in [[8.0,28.0],[40.0,52.0],[68.0,80.0],[92.0,112.0]]:
		_band(paving,Vector2((span[0]+span[1])*.5,754.5),Vector2(span[1]-span[0],.55),GRADE+.047,"cap")
	# Short paving courses give human scale to the 104m frontage.
	for x in range(12,112,8):_band(paving,Vector2(float(x),763.5),Vector2(.14,17),GRADE+.05,"stone")
	# Flat compass inlay reinforces the arrival axis without obstructing passenger flow.
	var center:=Vector3(60,GRADE+.055,763)
	for i in 8:
		var a:=float(i)*TAU/8.0;var next:=float(i+1)*TAU/8.0
		var radius:=3.6 if i%2==0 else 1.65
		var radius_next:=3.6 if (i+1)%2==0 else 1.65
		paving.tri(center,center+Vector3(sin(a)*radius,0,cos(a)*radius),center+Vector3(sin(next)*radius_next,0,cos(next)*radius_next),"dark" if i%2==0 else "stone")
	bake.call(b,paving,"station_forecourt_paving",false)
	# Seating and planting are concentrated at the sides. The broad centre stays clear.
	for x in [18.0,102.0]:
		var flower:=b.prop("flowerbed",x,768,0,Vector3(12,.55,3.2),Color.WHITE,Color("668455"),Color("c5b897"),2,"",0,"Props",GRADE)
		flower.name="station_forecourt_flower_%d"%int(x)
	for spec in [[29.0,767.0,90.0],[91.0,767.0,270.0],[18.0,758.0,180.0],[102.0,758.0,180.0]]:
		var bench:=b.prop("bench",spec[0],spec[1],spec[2],Vector3(3.2,1,1),Color.WHITE,Color.WHITE,Color("715c45"),0,"",0,"Props",GRADE)
		bench.name="station_forecourt_bench_%d_%d"%[int(spec[0]),int(spec[1])]
	for x in [10.0,110.0]:
		var lamp:=b.prop("lamp2",x,755.5,0,Vector3(2,5,.6),Color.WHITE,Color.WHITE,Color.WHITE,0,"",0,"Props",GRADE)
		lamp.name="station_forecourt_lamp_%d"%int(x)
	b.block(60,760.5,54)
