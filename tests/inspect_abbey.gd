extends SceneTree
## Debug: dump abbey building packs and their placement in the vale zone.
## godot --headless --path E:/wowgame --script res://tests/inspect_abbey.gd

func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is VisualInstance3D:
		var b: AABB = t * (n as VisualInstance3D).get_aabb()
		acc[0] = b if acc[0] == null else (acc[0] as AABB).merge(b)
		acc[1] += 1
	for c in n.get_children():
		_aabb(c, t, acc)

func _initialize() -> void:
	for id in ["chapel", "belltower", "courtyard"]:
		var ps := load("res://assets/models/vale_runtime_v1/build001/%s.scn" % id) as PackedScene
		var inst := ps.instantiate()
		var acc := [null, 0]
		_aabb(inst, Transform3D.IDENTITY, acc)
		print("PACK ", id, " visuals=", acc[1], " aabb=", acc[0], " root_scale=", (inst as Node3D).scale if inst is Node3D else "-")
		inst.free()
	var zs := load("res://scenes/zones/dawnmist_vale.tscn") as PackedScene
	var z := zs.instantiate()
	for n in z.find_children("*", "", true, false):
		if n.get("kind") != null and str(n.get("kind")).begins_with("abbey"):
			var n3 := n as Node3D
			print("NODE ", n.name, " kind=", n.get("kind"), " pos=", n3.position, " rot=", n3.rotation_degrees.y, " scale=", n3.scale, " size=", n.get("size"), " asset=", n.get("asset_scene"))
	z.free()
	quit()
