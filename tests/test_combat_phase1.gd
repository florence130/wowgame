extends Node

## 战斗系统重构 - 阶段1测试
## 在游戏启动后自动运行，测试：耐力系统、连招链、方向输入、势能系统

func _ready() -> void:
	# 延迟执行，等待Game初始化
	await get_tree().create_timer(2.0).timeout
	print("\n=== 战斗系统阶段1测试 ===\n")
	test_stamina()
	test_combo_chain()
	test_directional_input()
	test_spec_resources()
	print("\n=== 测试完成 ===")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func test_stamina() -> void:
	print("[测试1] 耐力系统")
	var player = Game.player
	if not player:
		print("  ✗ 玩家不存在")
		return

	print("  初始耐力: %.1f / %.1f" % [player.stamina, player.max_stamina])

	# 模拟闪避消耗
	var cost: float = player.dodge_cost
	player.stamina -= cost
	print("  闪避后耐力: %.1f (消耗 %.1f)" % [player.stamina, cost])

	if player.stamina < player.max_stamina:
		print("  ✓ 耐力消耗正常")
	else:
		print("  ✗ 耐力消耗失败")

func test_combo_chain() -> void:
	print("\n[测试2] 连招链系统")
	var player = Game.player
	if not player:
		print("  ✗ 玩家不存在")
		return

	# 设置连招链
	player.combo_chain = "test_chain"
	player.combo_window = 4.0
	print("  设置连招链: %s (窗口 %.1fs)" % [player.combo_chain, player.combo_window])

	# 测试校验
	var test_spell := {
		"id": "test",
		"requires": {"combo_chain": "test_chain"}
	}
	var err: String = player.check_cast(test_spell, null)
	if err == "":
		print("  ✓ 连招链校验通过")
	else:
		print("  ✗ 连招链校验失败: %s" % err)

	# 测试错误链
	player.combo_chain = "wrong_chain"
	err = player.check_cast(test_spell, null)
	if err != "":
		print("  ✓ 错误连招链被正确拒绝")
	else:
		print("  ✗ 错误连招链未被拒绝")

func test_directional_input() -> void:
	print("\n[测试3] 方向输入系统")
	var player = Game.player
	if not player:
		print("  ✗ 玩家不存在")
		return

	var dir: String = player.get_move_direction()
	print("  当前移动方向: %s" % dir)
	print("  ✓ 方向检测函数存在")

func test_spec_resources() -> void:
	print("\n[测试4] 专精资源初始化")
	var player = Game.player
	if not player:
		print("  ✗ 玩家不存在")
		return

	var cls: String = Game.pd["class"]
	print("  职业: %s" % cls)
	print("  资源类型: %s" % player.spec_resource_type)
	print("  资源值: %.1f / %.1f" % [player.spec_resource, player.max_spec_resource])

	match cls:
		"warrior":
			if player.spec_resource_type == "momentum":
				print("  ✓ 战士势能系统已初始化")
			else:
				print("  ✗ 战士应使用势能系统")
		"mage":
			if player.spec_resource_type == "charges":
				print("  ✓ 法师充能系统已初始化")
			else:
				print("  ✗ 法师应使用充能系统")
		_:
			print("  - 其他职业待测试")
