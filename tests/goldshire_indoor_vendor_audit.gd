extends Node
## 金穗镇室内穿模与坐骑商人回归检查。
## 重点是当前保存场景的实际实例：室内 NPC 必须落在对应房屋内层、地板上且不与建筑碰撞体重叠；
## 新坐骑商人必须是可交互 NPC，并沿用 stable 货单和骑术服务链路。

const TOWN_POINT := Vector3(435.0, 18.0, 500.0)
const MOUNT_VENDOR_ID := "mount_merchant_vale"
const EXPECTED_MOUNT_POS := Vector3(470.49, 17.2, 498.69)
const INDOOR_IDS := ["faria", "argo", "dorn", "britta", "kate", "duke",
	"t_warrior_2", "t_mage_2", "t_priest_2", "t_rogue_2", "t_gunner_2", "ron"]

var fails := 0
var meta: Dictionary = {}

func check(ok: bool, label: String) -> void:
	print("GOLD_VENDOR ", "PASS " if ok else "FAIL ", label)
	if not ok:
		fails += 1

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.new_character("金穗镇室内测", "warrior", DB.random_appearance(17, "f"))
	Game.slot_index = -1
	Game.pd["zone"] = "vale"
	Game.pd["level"] = 15
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/village_kit/buildings.json"))
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	_run.call_deferred()

func _run() -> void:
	for _i in 500:
		await get_tree().process_frame
		if is_instance_valid(Game.world) and is_instance_valid(Game.player) and not Game.world.loading:
			break
	if not is_instance_valid(Game.world) or not is_instance_valid(Game.player):
		check(false, "世界加载")
		_finish()
		return
	await Game.world._teleport_to(TOWN_POINT)
	await get_tree().create_timer(1.0).timeout
	_check_vendor()
	_check_indoor_npcs()
	_finish()

func _find_npc(id: String) -> NPC:
	for node in get_tree().get_nodes_in_group("npcs"):
		var npc := node as NPC
		if npc != null and npc.npc_id == id:
			return npc
	return null

func _check_vendor() -> void:
	var data: Dictionary = DB.npcs.get(MOUNT_VENDOR_ID, {})
	check(not data.is_empty(), "坐骑商人数据存在（%s）" % MOUNT_VENDOR_ID)
	check(String(data.get("name", "")) == "芙蕾雅", "坐骑商人有明确名称")
	check(String(data.get("vendor", "")) == "stable", "坐骑商人沿用 stable 货单")
	check(bool(data.get("riding", false)), "坐骑商人提供骑术服务")
	check(DB.vendors.get("stable", []).has("mount_horse_item"), "stable 货单含高地骏马缰绳")
	var npc := _find_npc(MOUNT_VENDOR_ID)
	check(npc != null, "金穗镇场景实例化坐骑商人")
	if npc == null:
		return
	check(npc.global_position.distance_to(EXPECTED_MOUNT_POS) < 1.5, "坐骑商人在马厩门外可走地面（%.2fm）" % npc.global_position.distance_to(EXPECTED_MOUNT_POS))
	var hit := _floor_hit(npc)
	check(not hit.is_empty() and absf(float(hit.position.y) - npc.global_position.y) < 0.5, "坐骑商人站在地面而非浮空")
	check(_building_overlap(npc).is_empty(), "坐骑商人不与马厩墙体重叠")

func _find_house_for(pos: Vector3) -> Dictionary:
	for node in Game.world.find_children("*", "ModelProp", true, false):
		var prop := node as ModelProp
		if prop == null or not prop.asset_scene.contains("/village_kit/"):
			continue
		var id := prop.asset_scene.get_file().get_basename()
		var m: Dictionary = meta.get(id, {})
		if m.is_empty() or not m.has("bbox"):
			continue
		var local := prop.global_transform.affine_inverse() * pos
		var bb: Array = m["bbox"]
		if local.x > float(bb[0]) + 0.2 and local.x < float(bb[2]) - 0.2 and local.z > -float(bb[3]) + 0.2 and local.z < -float(bb[1]) - 0.2:
			return {"prop": prop, "id": id, "local": local, "meta": m}
	return {}

func _check_indoor_npcs() -> void:
	var checked := 0
	for id in INDOOR_IDS:
		var npc := _find_npc(id)
		check(npc != null, "%s 已实例化" % id)
		if npc == null:
			continue
		var room := _find_house_for(npc.global_position)
		check(not room.is_empty(), "%s 位于房屋内而非墙外" % id)
		if room.is_empty():
			continue
		var prop: ModelProp = room["prop"]
		var local: Vector3 = room["local"]
		var m: Dictionary = room["meta"]
		var inner: Array = m.get("inner", [])
		var inside := inner.size() >= 4 and local.x > float(inner[0]) + 0.2 and local.x < float(inner[1]) - 0.2 and local.z > float(inner[2]) + 0.2 and local.z < float(inner[3]) - 0.2
		check(inside, "%s 位于室内可行走区域（局部 %.2f, %.2f）" % [id, local.x, local.z])
		check(absf(npc.global_position.y - prop.global_position.y) < 0.65, "%s 与室内地板高度一致" % id)
		var floor := _floor_hit(npc)
		check(not floor.is_empty() and absf(float(floor.position.y) - npc.global_position.y) < 0.5, "%s 脚下有地板碰撞" % id)
		var overlap := _building_overlap(npc)
		check(overlap.is_empty(), "%s 胶囊不穿入墙体/家具碰撞%s" % [id, "" if overlap.is_empty() else "：" + ", ".join(overlap)])
		checked += 1
	check(checked == INDOOR_IDS.size(), "金穗镇室内 NPC 全部完成穿模检查（%d）" % checked)

func _floor_hit(npc: NPC) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(npc.global_position + Vector3(0, 2.2, 0), npc.global_position + Vector3(0, -2.2, 0))
	q.collision_mask = 1
	q.exclude = [npc.get_rid()]
	return Game.world.get_world_3d().direct_space_state.intersect_ray(q)

func _building_overlap(npc: NPC) -> Array:
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, npc.global_position + Vector3(0, 0.85, 0))
	q.collision_mask = 1
	q.exclude = [npc.get_rid()]
	var hits: Array = Game.world.get_world_3d().direct_space_state.intersect_shape(q, 24)
	var blocked: Array = []
	for hit in hits:
		var collider: Object = hit.get("collider")
		if collider is Node and String((collider as Node).get_path()).contains("/Buildings/"):
			blocked.append(String((collider as Node).get_path()))
	return blocked

func _finish() -> void:
	print("GOLD_VENDOR RESULT ", "PASS" if fails == 0 else "%d FAIL" % fails)
	get_tree().quit(1 if fails > 0 else 0)
