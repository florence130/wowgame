extends SceneTree
## Offline, source-preserving runtime packaging. Run with an isolated Godot project:
## godot --headless --path .local/vale_godot --script ABS/tools/vale_runtime/pack_buildings.gd -- ABS/output
## Source geometry is never altered. Opaque surfaces batch by material CONTENT,
## spatial cell and moving branch; transparent source surfaces stay separate.
const ROOT = "E:/wowgame/"
const SOURCES = {
	"chapel":"assets/models/abbey_kit_v3/build005/assemblies/Chapel_Open_Interior.glb",
	"belltower":"assets/models/abbey_kit_v3/build005/assemblies/BellTower.glb",
	"courtyard":"assets/models/abbey_kit_v3/build005/assemblies/CourtyardArchitecture.glb",
	"farm":"assets/models/vale_kit_v1/build_008/godot/assemblies/VALE_farm.scn",
	"barn":"assets/models/vale_kit_v1/build_008/godot/assemblies/VALE_barn.scn",
	"windmill":"assets/models/vale_kit_v1/build_008/godot/assemblies/VALE_windmill.scn"
}
## 打包前对源装配的修改（用户 2026-10-05 反馈）：按节点名前缀
##  scale：绕节点自身原点（家具底面中心）放大；remove：删除；material：换成构件库 K| 材质（游戏端换建筑着色器）
const TWEAKS = {
	"chapel": {"scale": {"Lectern": 1.7, "Altar": 1.3, "Reredos": 1.25},
		"material": {"Stone entry tread": "K|2|cfc8ba|st_stone|1.6", "Entry landing closed core": "K|2|cfc8ba|st_stone|1.6", "Entry threshold stone": "K|2|b9b2a3|st_stone|1.6"}},
	"courtyard": {"remove": ["ABY_Detail_OakDoubleDoor"]},
}
const CELL = Vector3(8,6,8)

func apply_tweaks(id:String,source:Node3D) -> void:
	if not TWEAKS.has(id):return
	var tw:Dictionary=TWEAKS[id]
	var mats:Dictionary={}
	for n in source.find_children("*","Node3D",true,false):
		if not is_instance_valid(n):continue
		var nm:String=n.name
		for pre in tw.get("remove",[]):
			if nm.begins_with(pre):
				n.get_parent().remove_child(n);n.free();break
		if not is_instance_valid(n):continue
		for pre in tw.get("scale",{}):
			if nm.begins_with(pre):(n as Node3D).scale*=float(tw.scale[pre])
		for pre in tw.get("material",{}):
			if nm.begins_with(pre) and n is MeshInstance3D:
				var key:String=tw.material[pre]
				if not mats.has(key):
					var m=StandardMaterial3D.new();m.resource_name=key;m.albedo_color=Color(key.split("|")[2]);mats[key]=m
				for i in (n as MeshInstance3D).mesh.get_surface_count():(n as MeshInstance3D).set_surface_override_material(i,mats[key])
var signature_cache:Dictionary={}
var texture_cache:Dictionary={}
var failure_messages:Array=[]
var records:Array=[]

func _initialize() -> void:
	call_deferred("run_pack")

func sha(bytes:PackedByteArray) -> String:
	var c=HashingContext.new();c.start(HashingContext.HASH_SHA256);c.update(bytes);return c.finish().hex_encode()

func stable(v, depth:int=0) -> String:
	if v==null:return "null"
	if v is Texture2D:
		var id=v.get_instance_id()
		if not texture_cache.has(id):
			var im=v.get_image()
			texture_cache[id]="texture:%s:%s:%s:%s:%s"%[im.get_width(),im.get_height(),im.get_format(),im.has_mipmaps(),sha(im.get_data())] if im else "missing_texture"
		return texture_cache[id]
	if v is Resource:
		if depth>6:return v.get_class()
		var terms:Array=[v.get_class()]
		for p in v.get_property_list():
			var key:String=p.name
			if int(p.usage)&PROPERTY_USAGE_STORAGE==0 or key in ["resource_name","resource_path","resource_local_to_scene","script"] or key.begins_with("metadata/"):continue
			terms.append(key+"="+stable(v.get(key),depth+1))
		terms.sort()
		return "|".join(terms)
	return var_to_str(v)

func material_key(mat:Material) -> String:
	if mat==null:return "none"
	var id=mat.get_instance_id()
	if not signature_cache.has(id):signature_cache[id]=stable(mat).sha256_text()
	return signature_cache[id]

func relative_transform(node:Node3D,ancestor:Node3D) -> Transform3D:
	var result=Transform3D.IDENTITY;var current:Node=node
	while current!=ancestor and current!=null:
		if current is Node3D:result=current.transform*result
		current=current.get_parent()
	return result

func array_count(a:Array) -> int:
	return a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX]!=null and a[Mesh.ARRAY_INDEX].size()>0 else a[Mesh.ARRAY_VERTEX].size()

func transparent(mat:Material) -> bool:
	return mat is BaseMaterial3D and (mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or mat.albedo_color.a<.999)

func moving_ancestor(n:Node,source:Node) -> Node3D:
	var cur=n
	while cur!=source and cur!=null:
		if String(cur.name).begins_with("ROTOR_PIVOT"):return cur as Node3D
		cur=cur.get_parent()
	return null

func load_source(path:String) -> Node3D:
	if path.ends_with(".scn"):
		var packed=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		return packed.instantiate() if packed else null
	var doc=GLTFDocument.new();var state=GLTFState.new()
	if doc.append_from_file(path,state)!=OK:return null
	return doc.generate_scene(state)

func add_owned(parent:Node,child:Node,owner_root:Node) -> void:
	parent.add_child(child);child.owner=owner_root

func cell_of(point:Vector3) -> String:
	return "%d_%d_%d"%[floori(point.x/CELL.x),floori(point.y/CELL.y),floori(point.z/CELL.z)]

func add_collision_tri(groups:Dictionary,a:Vector3,b:Vector3,c:Vector3) -> void:
	if (b-a).cross(c-a).length_squared()<1e-15:return
	var cell=cell_of((a+b+c)/3)
	if not groups.has(cell):groups[cell]=PackedVector3Array()
	var f:PackedVector3Array=groups[cell];f.append(a);f.append(b);f.append(c);groups[cell]=f

func add_surface_collision(id:String,mi:MeshInstance3D,arrays:Array,xf:Transform3D,groups:Dictionary) -> int:
	var name_lower=String(mi.name).to_lower()
	if id=="chapel" and (name_lower.begins_with("stone entry tread") or name_lower.begins_with("wood stair")):return 0
	var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var count=array_count(arrays);var accepted=0
	for i in range(0,count,3):
		var a=xf*verts[indices[i] if not indices.is_empty() else i]
		var b=xf*verts[indices[i+1] if not indices.is_empty() else i+1]
		var c=xf*verts[indices[i+2] if not indices.is_empty() else i+2]
		if id=="chapel" and minf(a.y,minf(b.y,c.y))>4.2:continue
		if (b-a).cross(c-a).length_squared()<1e-15:continue
		add_collision_tri(groups,a,b,c);accepted+=1
	return accepted

func collision_body(owner_root:Node3D,groups:Dictionary) -> int:
	var body=StaticBody3D.new();body.name="SolidCollision";body.collision_layer=1;body.collision_mask=0
	add_owned(owner_root,body,owner_root)
	for cell in groups:
		var shape=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(groups[cell])
		var cs=CollisionShape3D.new();cs.name="Cell_"+cell;cs.shape=shape;add_owned(body,cs,owner_root)
	return groups.size()

func ramp(owner_root:Node3D,name:String,width:float,low:Vector2,high:Vector2) -> Dictionary:
	# Vector2 = (local Z, height); only a collision plane, no invented visual asset.
	var a=Vector3(-width/2,low.y,low.x);var b=Vector3(width/2,low.y,low.x)
	var c=Vector3(width/2,high.y,high.x);var d=Vector3(-width/2,high.y,high.x)
	var body=StaticBody3D.new();body.name=name;body.collision_layer=1;body.collision_mask=0;add_owned(owner_root,body,owner_root)
	var shape=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(PackedVector3Array([a,c,b,a,d,c]))
	var cs=CollisionShape3D.new();cs.name="SmoothWalkingSurface";cs.shape=shape;add_owned(body,cs,owner_root)
	body.set_meta("collision_only",true)
	return {"name":name,"width":width,"lower_zy":[low.x,low.y],"upper_zy":[high.x,high.y]}

func add_chapel_lights(owner_root:Node3D) -> Array:
	var data:Array=[]
	for z in [-2.0,2.0]:
		var light=OmniLight3D.new();light.name="InteriorWarmLight_"+("Front" if z<0 else "Rear")
		light.position=Vector3(0,4.7,z);light.light_color=Color("FFD98A");light.light_energy=1.4
		light.omni_range=5.5;light.omni_attenuation=1.2;light.shadow_enabled=z<0;light.distance_fade_enabled=true
		light.distance_fade_begin=35;light.distance_fade_length=12
		add_owned(owner_root,light,owner_root)
		data.append({"position":[0,4.7,z],"energy":1.4,"range":5.5,"shadow_enabled":light.shadow_enabled})
	return data

func check_scene(path:String,expected_triangles:int) -> Dictionary:
	var deps=ResourceLoader.get_dependencies(path)
	var ps=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
	if ps==null:return {"passed":false,"reason":"Could not reload"}
	var n=ps.instantiate();var triangles=0;var meshes=0;var glass:Array=[];var bad:Array=[];var sigs:Dictionary={};var textures:Dictionary={};var bb=AABB();var first=true
	for child in n.find_children("*","MeshInstance3D",true,false):
		meshes+=1
		var aabb=relative_transform(child,n)*child.get_aabb();bb=aabb if first else bb.merge(aabb);first=false
		for i in child.mesh.get_surface_count():
			var ar=child.mesh.surface_get_arrays(i);triangles+=array_count(ar)/3
			if ar[Mesh.ARRAY_TEX_UV]==null or ar[Mesh.ARRAY_NORMAL]==null:bad.append("missing_uv_or_normal:"+child.name)
			var m=child.get_active_material(i)
			if not m is BaseMaterial3D or m.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED:bad.append("not_lit_pbr:"+child.name)
			else:
				sigs[material_key(m)]=true
				if m.normal_enabled and m.normal_texture!=null and (ar[Mesh.ARRAY_TANGENT]==null or ar[Mesh.ARRAY_TANGENT].size()!=ar[Mesh.ARRAY_VERTEX].size()*4):bad.append("missing_normal_map_tangents:"+child.name)
				for t in [m.albedo_texture,m.normal_texture]:
					if t:textures[stable(t)]=true
				if transparent(m) and child.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:bad.append("transparent_casts_opaque_shadow:"+child.name)
				if m.resource_name in ["ABY2_glass","ABY2_window_glow"]:
					var good=transparent(m) and absf(m.albedo_color.a-.28)<.00001
					glass.append({"name":m.resource_name,"alpha":m.albedo_color.a,"mode":m.transparency,"shadow":child.cast_shadow,"passed":good})
					if not good:bad.append("window_alpha:"+m.resource_name)
	var hashes=sigs.keys();hashes.sort()
	var out={"passed":deps.is_empty() and bad.is_empty() and triangles==expected_triangles,"dependencies":deps,"triangles":triangles,"meshes":meshes,"material_content_count":sigs.size(),"material_content_hashes":hashes,"embedded_texture_content_count":textures.size(),"windows":glass,"errors":bad,"bounds_min":[bb.position.x,bb.position.y,bb.position.z],"bounds_max":[bb.end.x,bb.end.y,bb.end.z]}
	n.free();return out

func pack_one(id:String,out:String) -> Dictionary:
	var start=Time.get_ticks_msec();var path=ROOT+SOURCES[id];var source=load_source(path)
	if source==null:return {"id":id,"passed":false,"error":"source load failed"}
	apply_tweaks(id,source)
	var target=Node3D.new();target.name="ValeRuntime_"+id
	var groups:Dictionary={};var collisions:Dictionary={};var material_contents:Dictionary={};var names:Dictionary={};var source_surfaces=0;var source_triangles=0;var source_meshes=0;var source_ids:Dictionary={};var collision_triangles=0;var transparent_surfaces=0
	var rotor:Node3D=null;var rotor_source:Node3D=null;var bb=AABB();var first=true
	for node in source.find_children("*","MeshInstance3D",true,false):
		var mi=node as MeshInstance3D;source_meshes+=1
		var full_xf=relative_transform(mi,source);var abb=full_xf*mi.get_aabb();bb=abb if first else bb.merge(abb);first=false
		var moving=moving_ancestor(mi,source)
		if moving!=null and rotor==null:
			rotor=Node3D.new();rotor.name="Rotor";rotor.transform=relative_transform(moving,source);rotor_source=moving
			rotor.set_meta("rotation_axis","local_z");add_owned(target,rotor,target)
		var branch=rotor if moving!=null else target
		var xf=relative_transform(mi,rotor_source) if moving!=null else full_xf
		for i in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_primitive_type(i)!=Mesh.PRIMITIVE_TRIANGLES:failure_messages.append(id+":non_triangle_surface");continue
			var mat:Material=mi.get_active_material(i);var mk=material_key(mat)
			material_contents[mk]=true;source_ids[mat.get_instance_id()]=true
			if not names.has(mat.resource_name):names[mat.resource_name]={}
			names[mat.resource_name][mk]=true
			var ar=mi.mesh.surface_get_arrays(i);var tc=array_count(ar)/3
			source_surfaces+=1;source_triangles+=tc
			var is_alpha=transparent(mat)
			var shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if is_alpha else mi.cast_shadow
			var partition="alpha_%d_%d"%[mi.get_instance_id(),i] if is_alpha else cell_of(xf*mi.get_aabb().get_center())
			var key="%s:%s:%s:%d"%[branch.name,mk,partition,shadow]
			if is_alpha:transparent_surfaces+=1
			if not groups.has(key):
				var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(mat)
				groups[key]={"st":st,"branch":branch,"shadow":shadow,"material":mat,"alpha":is_alpha,"source_parts":0,"triangles":0,"partition":partition}
			groups[key].st.append_from(mi.mesh,i,xf);groups[key].source_parts+=1;groups[key].triangles+=tc
			if not is_alpha and moving==null:collision_triangles+=add_surface_collision(id,mi,ar,full_xf,collisions)
	var batches:Array=[];var batch_index=0
	for g in groups.values():
		var mesh=g.st.commit();var mi=MeshInstance3D.new();mi.name=("Glass_" if g.alpha else "Batch_")+str(batch_index)+"_"+g.material.resource_name
		mi.mesh=mesh;mi.cast_shadow=g.shadow;mi.set_meta("source_part_count",g.source_parts)
		add_owned(g.branch,mi,target);batch_index+=1
		batches.append({"node":mi.name,"material":g.material.resource_name,"material_sha256":material_key(g.material),"parts":g.source_parts,"triangles":g.triangles,"partition":g.partition,"branch":g.branch.name})
	var collision_cells=collision_body(target,collisions);var ramps:Array=[];var lights:Array=[]
	if id=="chapel":
		ramps.append(ramp(target,"EntrySmoothRamp",3.38,Vector2(-11.9325,0),Vector2(-9.5325,.904)))
		ramps.append(ramp(target,"EntryRampTopConnector",3.38,Vector2(-9.5325,.904),Vector2(-8.17,.904)))
		ramps.append(ramp(target,"SanctuarySmoothRamp",1.99,Vector2(2.60,.9),Vector2(3.65,1.384)))
		ramps.append(ramp(target,"SanctuaryRampTopConnector",1.99,Vector2(3.65,1.384),Vector2(4.015,1.384)))
		lights=add_chapel_lights(target)
	target.set_meta("source_path",SOURCES[id]);target.set_meta("source_sha256",FileAccess.get_sha256(path));target.set_meta("native_metre_scale",true)
	target.set_meta("source_triangle_count",source_triangles);target.set_meta("runtime_mesh_count",groups.size())
	var dest=out.path_join(id+".scn");var packed=PackedScene.new();var pack_error=packed.pack(target)
	var save_error=ResourceSaver.save(packed,dest,ResourceSaver.FLAG_BUNDLE_RESOURCES) if pack_error==OK else pack_error
	var report={"id":id,"file":id+".scn","source":SOURCES[id],"source_sha256":FileAccess.get_sha256(path),"source_meshes":source_meshes,"source_surfaces":source_surfaces,"source_triangles":source_triangles,"source_material_resources":source_ids.size(),"source_material_contents":material_contents.size(),"material_name_content_counts":{},"output_meshes":groups.size(),"transparent_surfaces_kept_separate":transparent_surfaces,"collision_cells":collision_cells,"collision_triangles":collision_triangles,"collision_policy":"chunked exact solid triangles; no whole-building box; chapel high triangles >4.2m and visual stair collisions omitted, smooth ramp planes added; moving windmill rotor excluded","ramps":ramps,"lights":lights,"bounds_min":[bb.position.x,bb.position.y,bb.position.z],"bounds_max":[bb.end.x,bb.end.y,bb.end.z],"rotor_transform":str(rotor.transform) if rotor else null,"batches":batches,"pack_error":pack_error,"save_error":save_error}
	for name in names:report.material_name_content_counts[name]=names[name].size()
	source.free();target.free();report["reloaded"]=check_scene(dest,source_triangles) if save_error==OK else {"passed":false}
	var expected_hashes=material_contents.keys();expected_hashes.sort();report["source_material_content_hashes"]=expected_hashes
	var bounds_match=true
	for axis in 3:
		bounds_match=bounds_match and absf(report.bounds_min[axis]-report.reloaded.bounds_min[axis])<.0001 and absf(report.bounds_max[axis]-report.reloaded.bounds_max[axis])<.0001
	report["visual_bounds_preserved"]=bounds_match
	report["passed"]=save_error==OK and report.reloaded.passed and report.reloaded.material_content_hashes==expected_hashes and bounds_match
	report["duration_ms"]=Time.get_ticks_msec()-start
	var f=FileAccess.open(out.path_join(id+"_report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("PACKED ",id," passed=",report.passed," meshes=",source_meshes,"->",groups.size()," triangles=",source_triangles," duration_ms=",report.duration_ms)
	return report

func run_pack() -> void:
	var args=OS.get_cmdline_user_args();var out=args[0] if args.size()>0 else ROOT+"assets/models/vale_runtime_v1/build001"
	DirAccess.make_dir_recursive_absolute(out)
	var only=args[1].split(",") if args.size()>1 else SOURCES.keys()
	for id in only:records.append(pack_one(id,out))
	var passed=failure_messages.is_empty()
	for r in records:passed=passed and r.passed
	var report={"passed":passed,"generator":"tools/vale_runtime/pack_buildings.gd","generator_sha256":FileAccess.get_sha256(ROOT+"tools/vale_runtime/pack_buildings.gd"),"engine":Engine.get_version_info(),"spatial_cell_metres":[8,6,8],"scope":"Offline native packs and reload checks. Pixel fidelity, gameplay walking and framerate require separate map tests.","records":records,"errors":failure_messages}
	var f=FileAccess.open(out.path_join("pack_report.json" if args.size()<2 else "pack_report_partial.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("RUNTIME_PACK_COMPLETE ",passed);quit(0 if passed else 1)
