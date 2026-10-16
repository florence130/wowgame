extends RefCounted
## 15–20 级潮风高地外勤布置。只添加到当前 Zone 实例，不改保存场景。

static func apply(zone: Node) -> void:
	if zone.zone_id != "tidewind" or zone.has_meta("ember_chapter_applied"):
		return
	zone.set_meta("ember_chapter_applied", true)
	# 证据采集点：放在城内已有设施附近，玩家不需要反复跑回副本。
	_gather(zone, "ember_archive_ledger", "ember_ledger", Vector3(-148, 35, 282), 1, 7.0)
	_gather(zone, "ember_customs_pages", "ember_manifest", Vector3(-348, 35, 585), 4, 12.0)
	# 港口转运点：位于东门外旧灰巾帮营地北侧的平地。
	_poi(zone, "poi_ember_transfer", "东郊余烬转运点", Vector3(505, 50, 158), 38.0)
	_npc(zone, "e_port_agent", Vector3(520, 50, 175))
	_spawn(zone, "e_dock_runner", 6, Vector3(505, 55, 145), 22.0, 15)
	_spawn(zone, "e_dock_gunner", 6, Vector3(535, 55, 150), 22.0, 16)
	_spawn(zone, "e_dock_master", 1, Vector3(518, 55, 135), 10.0, 16)
	_gather(zone, "ember_cargo_tags", "ember_cargo", Vector3(490, 55, 170), 4, 18.0)

	# 旧铁路站场北侧：与现有锈蚀傀儡刷新区错开一段距离。
	_poi(zone, "poi_ember_rail", "站场北侧余烬调度区", Vector3(350, 70, 270), 38.0)
	_spawn(zone, "e_rail_guard", 8, Vector3(350, 70, 270), 24.0, 16)
	_spawn(zone, "e_rail_saboteur", 8, Vector3(325, 70, 250), 24.0, 17)
	_spawn(zone, "e_signal_spider", 7, Vector3(380, 70, 250), 20.0, 17)
	_spawn(zone, "e_rail_foreman", 1, Vector3(365, 70, 235), 10.0, 17)
	_gather(zone, "ember_dispatch_forms", "ember_dispatch", Vector3(335, 70, 295), 3, 18.0)
	_gather(zone, "ember_signal_relays", "ember_signal", Vector3(365, 70, 295), 4, 18.0)

	# 海岸前哨：设置在农庄与礁石海滩之间的草地高台，远离水线。
	_poi(zone, "poi_ember_coast", "礁石海滩东侧海岸前哨", Vector3(610, 55, 770), 42.0)
	_npc(zone, "e_coast_agent", Vector3(610, 55, 790))
	_spawn(zone, "e_coast_runner", 8, Vector3(610, 55, 770), 24.0, 18)
	_spawn(zone, "e_tide_golem", 8, Vector3(640, 55, 780), 24.0, 18)
	_spawn(zone, "e_lens_keeper", 6, Vector3(655, 55, 750), 20.0, 19)
	_spawn(zone, "e_coast_master", 1, Vector3(675, 55, 735), 10.0, 19)
	_gather(zone, "ember_coast_cache", "ember_cache", Vector3(575, 55, 805), 4, 20.0)
	_gather(zone, "ember_rescue_kits", "ember_rescue", Vector3(590, 55, 825), 6, 20.0)
	_gather(zone, "ember_lens_frames", "ember_frame", Vector3(665, 55, 790), 4, 18.0)

	# 山麓指挥营地：与鸣风崖方向相连的平地，不把刷怪点放在海滩坡面。
	_poi(zone, "poi_ember_command", "山麓余烬指挥营地", Vector3(740, 55, 660), 42.0)
	_spawn(zone, "e_ember_guard", 8, Vector3(725, 55, 670), 25.0, 19)
	_spawn(zone, "e_ember_mage", 6, Vector3(760, 55, 655), 22.0, 20)
	_spawn(zone, "e_ember_commander", 1, Vector3(780, 55, 635), 10.0, 20)
	_gather(zone, "ember_ciphers", "ember_cipher", Vector3(710, 55, 645), 3, 18.0)
	_gather(zone, "ember_charges", "ember_charge", Vector3(700, 55, 690), 4, 18.0)
	_gather(zone, "ember_shutdowns", "ember_shutdown", Vector3(775, 55, 690), 3, 18.0)

static func _poi(zone: Node, id: String, title: String, pos: Vector3, radius: float) -> void:
	var p := POI.new()
	p.name = id
	p.poi_id = id
	p.title = title
	p.radius = radius
	p.priority = 7
	p.position = pos
	zone.add_child(p)

static func _npc(zone: Node, id: String, pos: Vector3) -> void:
	var n := NpcSpot.new()
	n.name = "ember_npc_" + id
	n.npc_id = id
	n.wander = 4.0
	n.position = pos
	zone.add_child(n)

static func _spawn(zone: Node, id: String, count: int, pos: Vector3, radius: float, level: int) -> void:
	var s := MobSpawner.new()
	s.name = "ember_spawn_" + id
	s.mob_id = id
	s.count = count
	s.radius = radius
	s.level_override = level
	s.respawn = 90.0
	s.wander = 7.0
	s.required_quest = "q_c19"
	s.position = pos
	zone.add_child(s)

static func _gather(zone: Node, node_name: String, node_type: String, pos: Vector3, count: int, radius: float) -> void:
	var s := GatherSpot.new()
	s.name = node_name
	s.node_type = node_type
	s.count = count
	s.radius = radius
	s.respawn = 25.0
	s.position = pos
	zone.add_child(s)
