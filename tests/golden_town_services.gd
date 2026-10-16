extends "res://tests/art_style.gd"
## Saved-scene merchant: physical approach, actual dialogue buttons and purchase,
## learn item, summon. Disposable character (inherited slot_index = -1).

func _button(window: NpcWindow, needle: String) -> Button:
	for child in window.content.get_children():
		if child is Button and child.text.contains(needle):
			return child
	return null

func shot(label: String) -> void:
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(out + "/" + label + ".png")

func run() -> void:
	get_tree().auto_accept_quit = false
	get_tree().root.gui_disable_input = true
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	await Game.world._teleport_to(Vector3(470.5, 18.0, 498.7))
	await get_tree().physics_frame
	var merchant: NPC
	var count := 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.npc_id == "mount_merchant_vale":
			merchant = npc
			count += 1
	check(count == 1, "saved town spawns exactly one Freya mount merchant")
	if merchant == null:
		get_tree().quit(1)
		return
	check(merchant.nd.get("vendor", "") == "stable" and merchant.nd.get("riding", false), "merchant offers mount stock and riding instruction")
	check(Rep.faction_of_npc(merchant.npc_id) == "goldshire", "merchant uses Golden Town reputation discounts")
	var p: Player = Game.player
	p.set_physics_process(false)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	var approach := Vector3.ZERO
	var space: PhysicsDirectSpaceState3D = Game.world.get_world_3d().direct_space_state
	for step in 16:
		var direction := Vector3(cos(TAU * step / 16.0), 0, sin(TAU * step / 16.0))
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = capsule
		var start := merchant.global_position + direction * 3.0
		start.y = Game.world.zone.terrain.get_height_global(start.x, start.z) + 0.15
		q.transform.origin = start + Vector3.UP * 0.85
		q.motion = -direction * 1.5
		q.collision_mask = 1
		q.exclude = [p.get_rid()]
		var sweep: PackedFloat32Array = space.cast_motion(q)
		if sweep[0] >= 0.999:
			p.global_position = start
			approach = q.motion
			break
	check(approach.length() > 1.0, "merchant has a full player capsule approach path")
	if approach.length() > 1.0:
		var blocked := p.move_and_collide(approach)
		check(blocked == null and p.global_position.distance_to(merchant.global_position) < 2.0, "player physically approaches merchant without wall collision")
	p.cam_yaw = merchant.rotation.y + PI
	p.cam_pitch = -0.15
	p.cam_dist = 5.0
	Game.hud.show()
	merchant.interact(p)
	await wait(0.3)
	var window: NpcWindow = Game.hud.win["npc"]
	check(window.visible and window.npc == merchant, "interacting with saved merchant opens actual NPC dialogue")
	Game.pd["bag"].fill(null)
	Game.pd["riding"] = false
	Game.pd["level"] = 9
	Game.pd["money"] = 200000
	window._render()
	var riding := _button(window, "学习初级骑术")
	check(riding != null, "riding training dialogue option is present")
	if riding:
		riding.pressed.emit()
	check(not Game.pd["riding"] and Game.pd["money"] == 200000, "level nine training is rejected without charging")
	Game.pd["level"] = 10
	p.recalc_stats()
	Game.pd["money"] = 7000
	window._render()
	riding = _button(window, "学习初级骑术")
	if riding:
		riding.pressed.emit()
	check(not Game.pd["riding"] and Game.pd["money"] == 7000, "insufficient training money is rejected without charging")
	Game.pd["money"] = 200000
	window._render()
	riding = _button(window, "学习初级骑术")
	if riding:
		riding.pressed.emit()
	check(Game.pd["riding"] and Game.pd["money"] == 192000, "actual riding button teaches skill and charges eighty silver")
	var goods := _button(window, "出售的货物")
	check(goods != null, "merchant gossip offers goods")
	if goods:
		goods.pressed.emit()
	await wait(0.2)
	check(window.mode == "vendor" and window._vendor_list().has("mount_horse_item"), "actual vendor view lists horse reins")
	shot("01_freya_vendor")
	var price := window._price("mount_horse_item")
	var money_before: int = Game.pd["money"]
	window._buy(window._vendor_list().find("mount_horse_item"))
	check(Game.count_item("mount_horse_item") == 1 and Game.pd["money"] == money_before - price, "actual vendor purchase adds reins and charges current reputation price")
	p.use_item_id("mount_horse_item")
	await wait(0.3)
	check(Mounts.learned("horse") and Game.count_item("mount_horse_item") == 0, "using purchased reins learns horse and consumes item")
	Game.hud.close_all()
	p.set_physics_process(true)
	check(Mounts.summon("horse"), "purchased horse can be summoned")
	await wait(2.5)
	check(p.mounted and p.mount_id == "horse", "summon cast completes and player rides the purchased horse")
	shot("02_freya_purchased_horse")
	p.dismount()
	Game.slot_index = -1
	FileAccess.open(out + "/services.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	print("GOLDEN TOWN SERVICES DONE ", checks.size(), " checks")
	get_tree().quit(1 if checks.any(func(c): return not c["pass"]) else 0)
