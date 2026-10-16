extends Node3D
## 临时探针：节点缩放后碰撞体是否跟着缩放（Godot 4.7，当前物理引擎）
func _ready() -> void:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * 2.0
	add_child(holder)
	var body := StaticBody3D.new()
	holder.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2, 2, 2)
	cs.shape = bs
	body.add_child(cs)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	for x in [0.5, 1.5, 2.5, 3.5]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 10, 0), Vector3(x, -10, 0))
		var r := space.intersect_ray(q)
		print("PROBE x=%.1f hit=%s" % [x, str(not r.is_empty())])
	print("PROBE expect: scaled box half-width 2.0 => hit at 0.5,1.5 only; unscaled half 1.0 => hit only 0.5")
	get_tree().quit()
