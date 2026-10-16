extends Node
## 城内传送石端到端：站到市政广场传送石旁 → 交互键打开菜单 → 列出其余 12 块 → 点「中央车站」→ 淡入淡出后落在车站传送石旁。
## Godot --path . res://tests/waystone_test.tscn
var fails := 0

func check(ok: bool, what: String) -> void:
	print("WAYSTONE ", "PASS " if ok else "FAIL ", what)
	if not ok:
		fails += 1

func _ready() -> void:
	if not has_meta("runner"):
		var n := Node.new()
		n.set_script(get_script())
		n.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(n)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.new_character("传送", "mage", DB.random_appearance(3, "f"))
	Game.slot_index = -1
	Game.pd["zone"] = "tidewind"
	Game.pd["level"] = 15
	Game.pd["flags"]["city_access"] = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	_run.call_deferred()

func _find(id: String) -> Waystone:
	for w in get_tree().get_nodes_in_group("waystones"):
		if w.ws_id == id:
			return w
	return null

func _run() -> void:
	for i in 400:
		await get_tree().process_frame
		if Game.player and Game.world and not Game.world.loading:
			break
	await get_tree().create_timer(2.0).timeout
	var p: Player = Game.player
	var stones := get_tree().get_nodes_in_group("waystones")
	check(stones.size() == 15, "城内 15 块传送石已生成（实际 %d）" % stones.size())
	var src := _find("ws_plaza")
	var dst := _find("ws_station")
	check(src != null and dst != null, "找到市政广场 / 中央车站传送石")
	if src == null or dst == null:
		get_tree().quit(1)
		return
	# 站到落点（石旁 3.4m），按交互键
	await Game.world._teleport_to(src.land_point(), deg_to_rad(src.land_yaw))
	await get_tree().create_timer(1.0).timeout
	check(p.global_position.distance_to(src.global_position) < 5.5, "玩家在传送石交互范围内（%.1fm）" % p.global_position.distance_to(src.global_position))
	p.interact_nearest()
	await get_tree().create_timer(0.3).timeout
	var win = Game.hud.win["npc"]
	check(win.visible and win.mode == "waystone", "交互打开传送石菜单")
	var btns: Array = []
	for c in win.content.get_children():
		if c is Button and c.text.contains("◆"):
			btns.append(c)
	check(btns.size() == 14, "菜单列出其余 14 个目的地（实际 %d）" % btns.size())
	var target: Button = null
	for b in btns:
		if b.text.contains(dst.title):
			target = b
	check(target != null, "菜单里有「%s」" % dst.title)
	if target:
		target.pressed.emit()
		for i in 300:
			await get_tree().process_frame
			if not Game.world.simulation_suspended() and p.global_position.distance_to(dst.land_point()) < 3.0:
				break
		await get_tree().create_timer(1.5).timeout
		var d := p.global_position.distance_to(dst.global_position)
		check(d < 6.0, "传送到中央车站传送石旁（距石心 %.1fm）" % d)
		check(not win.visible, "传送后菜单关闭")
		check(p.is_on_floor() and absf(p.global_position.y - dst.global_position.y) < 1.2, "落地站稳（y=%.2f，石基 %.2f）" % [p.global_position.y, dst.global_position.y])
	# 离开交互范围后菜单自动关闭
	p.interact_nearest()
	await get_tree().create_timer(0.3).timeout
	var opened: bool = win.visible
	p.global_position += Vector3(12, 0, 0)
	await get_tree().create_timer(0.5).timeout
	check(opened and not win.visible, "走远后传送石菜单自动关闭")
	print("WAYSTONE RESULT: ", "ALL PASS" if fails == 0 else "%d FAIL" % fails)
	get_tree().quit(1 if fails else 0)
