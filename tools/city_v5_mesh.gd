class_name CityV5Mesh
extends RefCounted
## Baked civil geometry in metres. Ribbons share mitered vertices at corners.
var surfaces := {}
var bounds := AABB()
var first := true
var collision_faces := PackedVector3Array()

func tri(a: Vector3, b: Vector3, c: Vector3, material: String = "stone") -> void:
	if not surfaces.has(material):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[material] = st
	var st: SurfaceTool = surfaces[material]
	var normal := (b - a).cross(c - a).normalized()
	# Godot front faces use clockwise winding; retain the outward authored normal.
	for p in [a, c, b]:
		st.set_normal(normal)
		st.set_uv(Vector2(p.x + p.z * 0.37, p.y + p.z * 0.79) * 0.25)
		st.add_vertex(p)
		bounds = AABB(p, Vector3.ZERO) if first else bounds.expand(p)
		first = false

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, material: String = "stone") -> void:
	tri(a, b, c, material)
	tri(a, c, d, material)

func box(c: Vector3, s: Vector3, material: String = "stone") -> void:
	var a := c - s * 0.5
	var b := c + s * 0.5
	quad(Vector3(a.x,b.y,a.z),Vector3(a.x,b.y,b.z),Vector3(b.x,b.y,b.z),Vector3(b.x,b.y,a.z),material)
	quad(Vector3(a.x,a.y,b.z),Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),Vector3(b.x,a.y,b.z),material)
	quad(Vector3(a.x,a.y,a.z),Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,a.y,a.z),material)
	quad(Vector3(b.x,a.y,b.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z),Vector3(a.x,a.y,b.z),material)
	quad(Vector3(a.x,a.y,b.z),Vector3(a.x,b.y,b.z),Vector3(a.x,b.y,a.z),Vector3(a.x,a.y,a.z),material)
	quad(Vector3(b.x,a.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,b.y,b.z),Vector3(b.x,a.y,b.z),material)

func ribbon(points: Array, width: float, depth: float, material: String = "stone") -> void:
	var left := []
	var right := []
	for i in points.size():
		var before: Vector3 = points[maxi(0,i-1)]
		var after: Vector3 = points[mini(points.size()-1,i+1)]
		var dir := (after-before).normalized()
		var side := Vector3(-dir.z,0,dir.x).normalized()
		var scale_miter := 1.0
		if i>0 and i<points.size()-1:
			var incoming: Vector3 = (points[i]-before).normalized()
			scale_miter = 1.0 / maxf(absf(side.dot(Vector3(-incoming.z,0,incoming.x))),0.6)
		left.append(points[i]+side*width*.5*scale_miter)
		right.append(points[i]-side*width*.5*scale_miter)
	for i in points.size()-1:
		var a: Vector3=left[i];var b: Vector3=left[i+1];var c: Vector3=right[i+1];var d: Vector3=right[i]
		var low:=Vector3(0,depth,0)
		quad(a,b,c,d,material)
		quad(a-low,b-low,b,a,material)
		quad(d,c,c-low,d-low,material)
		quad(a-low,d-low,c-low,b-low,material)
		if i==0:quad(a,d,d-low,a-low,material)
		if i==points.size()-2:quad(b-low,c-low,c,b,material)

func pack(path: String, collision: bool = true) -> AABB:
	var root := Node3D.new()
	root.name = "CivilAssembly"
	var mesh := ArrayMesh.new()
	for key in surfaces:
		var st: SurfaceTool = surfaces[key]
		var mat: Material
		match key:
			"road": mat=U.bmat(2,Color("8f918e"),"pt_rubble",3.5)
			"paving": mat=U.bmat(2,Color("d4c9b1"),"pt_ashlar",3.0)
			"cap": mat=U.bmat(2,Color("e3dac6"),"pt_ashlar",2.0)
			"dark": mat=U.bmat(6,Color("333d43"))
			"brick": mat=U.bmat(1,Color("a36552"))
			_: mat=U.bmat(2,Color("b4ac99"),"pt_rubble",4.0)
		st.set_material(mat)
		st.commit(mesh)
	var mi:=MeshInstance3D.new();mi.name="CivilMesh";mi.mesh=mesh
	mi.position=-bounds.get_center()
	root.add_child(mi);mi.owner=root
	if collision:
		var body:=StaticBody3D.new();body.name="CivilCollision"
		body.position=-bounds.get_center()
		root.add_child(body);body.owner=root
		var cs:=CollisionShape3D.new()
		if collision_faces.is_empty():cs.shape=mesh.create_trimesh_shape()
		else:
			var shape:=ConcavePolygonShape3D.new();shape.set_faces(collision_faces);cs.shape=shape
		body.add_child(cs);cs.owner=root
	var scene:=PackedScene.new();scene.pack(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	ResourceSaver.save(scene,path)
	root.free()
	return bounds
