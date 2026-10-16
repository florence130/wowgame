extends RefCounted
## 海神旧圣堂 v2 摆件：灯具、侧室陈设、宝箱。几何结构在 Blender 外壳里，这里只放可交互 / 发光 / 家具类物件。
const KIT := "res://assets/models/sanctum_unity_v2/kit/"
const LOCAL_LIGHT = preload("res://src/render/local_light.gd")
const SAVED_LIGHT = preload("res://src/render/sanctum_light.gd")
const CHEST = preload("res://src/world/sanctum_chest.gd")
const WARM := Color("ffc88b")
const STONE := Color("aea58d")
const WOOD := Color("69513a")
const LAMP_STYLES := ["hall", "cellar", "cave", "tunnel", "arcade", "tower"]

static func kit(parent: Node3D, id: String, p: Vector3, scale_v := Vector3.ONE, yaw := 0.0) -> Node3D:
	var packed := load(KIT + id + ".glb") as PackedScene
	if not packed:
		return null
	var root := packed.instantiate() as Node3D
	root.name = id + "_" + str(parent.get_child_count())
	root.position = p
	root.scale = scale_v
	root.rotation_degrees.y = yaw
	parent.add_child(root)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var original: Material = mi.mesh.surface_get_material(i)
			var nm := original.resource_name.to_lower() if original else ""
			var mat: Material
			if "glow" in nm:
				mat = U.mat(WARM, 2.4)
			elif "wood" in nm or "timber" in nm:
				mat = U.bmat(6, WOOD)
			elif "iron" in nm or "bronze" in nm:
				mat = U.bmat(7, Color("686859"))
			else:
				mat = U.bmat(2, STONE)
			mi.set_surface_override_material(i, mat)
	return root

static func lamp(parent: Node3D, p: Vector3, scale_v := 1.3, reach := 14.0, power := 1.4) -> void:
	var fixture := kit(parent, "floor_lamp", p, Vector3.ONE * scale_v, 0)
	if fixture:
		var light := LOCAL_LIGHT.attach(fixture, Vector3(0, 1.5, 0), WARM, reach, power)
		light.set_script(SAVED_LIGHT)
		light.set("authored_energy", power)

static func _prop(b: ZoneBuilder, kind: String, x: float, z: float, y: float, size := Vector3.ONE, yaw := 0.0, text := "") -> void:
	b.prop(kind, x, z, yaw, size, STONE, Color("8a9c6b"), WOOD, 0, text, 0, "Props", y)

static func build(b: ZoneBuilder, data: Dictionary) -> void:
	# 路灯：只在封闭 / 暗处放，露天空间靠日光；每盏贴通道一侧（离中线 3.4m）
	for l in data.lamps:
		if not String(l.style) in LAMP_STYLES:
			continue
		var yaw := float(l.yaw)
		var side := 1.0 if (int(abs(float(l.x) * 7.0 + float(l.z) * 3.0)) % 2 == 0) else -1.0
		var nx := -sin(yaw) * side * 3.6
		var nz := cos(yaw) * side * 3.6
		lamp(b.groups.Props, Vector3(float(l.x) + nx, float(l.y), float(l.z) + nz), 1.15, 13.0, 1.25)
	for room in data.side:
		_side_room(b, room)

static func _side_room(b: ZoneBuilder, room: Dictionary) -> void:
	var x := float(room.x)
	var z := float(room.z)
	var y := float(room.y)
	var marker := Node3D.new()
	marker.name = String(room.id)
	marker.position = Vector3(x, y, z)
	marker.set_meta("use", room.use)
	b.groups.Props.add_child(marker)
	if room.use == "empty":
		return
	lamp(b.groups.Props, Vector3(x - 3.0, y, z + 2.5), 1.0, 12.0, 1.1)
	match String(room.use):
		"chest":
			var chest := StaticBody3D.new()
			chest.set_script(CHEST)
			chest.set("chest_id", String(room.id))
			chest.position = Vector3(x, y, z - 3)
			chest.name = String(room.id) + "_Chest"
			b.groups.Props.add_child(chest)
			_prop(b, "barrel", x + 4, z + 2, y, Vector3(1, 1.2, 1))
		"bed":
			_prop(b, "bed", x + 4, z, y, Vector3(2, 1, 3))
			_prop(b, "table", x - 4, z - 3, y, Vector3(1.5, 1, 1.2))
		"shrine":
			_prop(b, "altar", x, z - 3, y, Vector3(3.2, 1.2, 1.6))
