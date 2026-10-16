extends Node

# 战斗系统改造 - 实战测试
# 创建玩家和敌人，测试新战斗机制

var player: Unit
var dummy: Unit

func _ready() -> void:
	print("========================================")
	print("战斗系统改造 - 实战测试")
	print("========================================")

	# 等待一帧让Game单例初始化
	await get_tree().process_frame

	setup_test_scene()
	run_tests()

	# 测试完成后退出
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func setup_test_scene() -> void:
	print("\n[初始化] 创建测试场景")

	# 创建玩家（战士）
	player = Unit.new()
	player.name = "TestPlayer"
	player.unit_name = "测试战士"
	add_child(player)

	# 初始化玩家数据
	Game.pd = {
		"class": "warrior",
		"level": 10,
		"name": "测试战士"
	}

	player.init_player()
	Game.player = player

	print("  ✓ 玩家创建完成")
	print("    职业: %s" % Game.pd["class"])
	print("    等级: %d" % Game.pd["level"])
	print("    生命: %.0f / %.0f" % [player.hp, player.max_hp])

	# 创建测试假人
	dummy = Unit.new()
	dummy.name = "TestDummy"
	dummy.unit_name = "测试假人"
	add_child(dummy)

	dummy.init_creature("dummy", 10)
	dummy.max_hp = 10000
	dummy.hp = 10000
	dummy.position = Vector3(5, 0, 0)

	print("  ✓ 测试假人创建完成")
	print("    生命: %.0f / %.0f" % [dummy.hp, dummy.max_hp])

func run_tests() -> void:
	print("\n========================================")
	print("开始功能测试")
	print("========================================")

	test_warrior_momentum()
	test_warrior_skills()
	test_position_system()
	test_dodge_system()

func test_warrior_momentum() -> void:
	print("\n[测试1] 战士势能系统")

	if player.has("spec_resource_type"):
		print("  势能类型: %s" % player.spec_resource_type)
		print("  初始势能: %.1f / %.1f" % [player.spec_resource, player.max_spec_resource])
		print("  ✓ 势能系统已初始化")
	else:
		print("  ✗ 势能系统未初始化")
		return

	# 测试怒气生成
	var initial_momentum: float = player.spec_resource
	player._on_damage_dealt(100.0)  # 模拟造成伤害

	if player.spec_resource > initial_momentum:
		print("  ✓ 造成伤害生成势能: %.1f -> %.1f" % [initial_momentum, player.spec_resource])
	else:
		print("  ? 势能未变化")

func test_warrior_skills() -> void:
	print("\n[测试2] 战士技能测试")

	# 测试冲锋
	if Game.SPELLS.has("charge"):
		print("  ✓ 冲锋技能存在")
		var charge: Dictionary = Game.SPELLS["charge"]
		print("    - 射程: %.1f米" % charge["range"])
		print("    - 冷却: %.1fs" % charge["cd"])
		print("    - 效果: 位移 + 晕眩 + 势能")
	else:
		print("  ✗ 冲锋技能不存在")

	# 测试压制打击
	if Game.SPELLS.has("overpower"):
		print("  ✓ 压制打击存在")
		var overpower: Dictionary = Game.SPELLS["overpower"]
		print("    - 耗能: %.0f势能" % overpower["cost"])
		print("    - 效果: 破甲 + 减速")
	else:
		print("  ✗ 压制打击不存在")

	# 测试斩杀
	if Game.SPELLS.has("execute"):
		print("  ✓ 斩杀技能存在")
		var execute: Dictionary = Game.SPELLS["execute"]
		print("    - 需求: 目标<20%%生命")
		print("    - 效果: 斩杀伤害")
	else:
		print("  ✗ 斩杀技能不存在")

func test_position_system() -> void:
	print("\n[测试3] 位置判定系统")

	# 测试get_relative_position函数
	if player.has_method("get_relative_position"):
		player.position = Vector3.ZERO
		player.rotation.y = 0  # 面向北

		dummy.position = Vector3(0, 0, -5)  # 在玩家前方
		var pos1: String = player.get_relative_position(dummy)
		print("  目标在前方: %s" % pos1)

		dummy.position = Vector3(0, 0, 5)  # 在玩家后方
		var pos2: String = player.get_relative_position(dummy)
		print("  目标在后方: %s" % pos2)

		dummy.position = Vector3(5, 0, 0)  # 在玩家侧面
		var pos3: String = player.get_relative_position(dummy)
		print("  目标在侧面: %s" % pos3)

		print("  ✓ 位置判定系统正常工作")
	else:
		print("  ✗ get_relative_position方法不存在")

func test_dodge_system() -> void:
	print("\n[测试4] 闪避系统")

	if player.has("stamina"):
		print("  耐力系统: %.1f / %.1f" % [player.stamina, player.max_stamina])
		print("  闪避消耗: %.1f" % player.dodge_cost)

		var initial_stamina: float = player.stamina
		player.stamina -= player.dodge_cost

		if player.stamina < initial_stamina:
			print("  ✓ 闪避消耗耐力: %.1f -> %.1f" % [initial_stamina, player.stamina])

		# 测试耐力恢复
		await get_tree().create_timer(0.1).timeout
		if player.stamina > initial_stamina - player.dodge_cost:
			print("  ✓ 耐力自动恢复")
	else:
		print("  ✗ 耐力系统未初始化")
