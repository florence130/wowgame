extends Node

# 战斗系统改造测试脚本
# 测试所有新增的职业机制和技能效果

func _ready() -> void:
	print("========================================")
	print("战斗系统改造测试")
	print("========================================")

	test_warrior_momentum()
	test_mage_charges()
	test_priest_marks()
	test_rogue_combo()

	print("\n========================================")
	print("测试完成")
	print("========================================")

func test_warrior_momentum() -> void:
	print("\n[测试1] 战士势能系统")

	# 创建测试玩家
	if not Game.player:
		print("  ✗ 玩家不存在，跳过测试")
		return

	var player = Game.player

	# 检查势能变量
	if player.has("spec_resource_type"):
		print("  势能类型: %s" % player.spec_resource_type)
		print("  当前势能: %.1f / %.1f" % [player.spec_resource, player.max_spec_resource])
		print("  ✓ 战士势能系统已初始化")
	else:
		print("  ✗ 势能系统未初始化")

	# 测试势能技能
	var has_charge: bool = Game.SPELLS.has("charge")
	var has_execute: bool = Game.SPELLS.has("execute")
	print("  冲锋技能: %s" % ("存在" if has_charge else "不存在"))
	print("  斩杀技能: %s" % ("存在" if has_execute else "不存在"))

func test_mage_charges() -> void:
	print("\n[测试2] 法师充能系统")

	var player = Game.player
	if not player:
		print("  ✗ 玩家不存在，跳过测试")
		return

	# 检查充能变量
	if player.has("fire_charges"):
		print("  火焰充能: %d" % player.fire_charges)
		print("  冰霜充能: %d" % player.frost_charges)
		print("  ✓ 法师充能系统已初始化")
	else:
		print("  ✗ 充能系统未初始化")

	# 测试充能技能
	var has_fire_blast: bool = Game.SPELLS.has("fire_blast")
	var has_frostbolt: bool = Game.SPELLS.has("frostbolt_new")
	print("  火焰冲击: %s" % ("存在" if has_fire_blast else "不存在"))
	print("  寒冰箭: %s" % ("存在" if has_frostbolt else "不存在"))

func test_priest_marks() -> void:
	print("\n[测试3] 牧师标记系统")

	var player = Game.player
	if not player:
		print("  ✗ 玩家不存在，跳过测试")
		return

	# 检查标记变量
	if player.has("holy_marks"):
		print("  圣光标记: %d" % player.holy_marks)
		print("  暗影标记: %d" % player.shadow_marks)
		print("  ✓ 牧师标记系统已初始化")
	else:
		print("  ✗ 标记系统未初始化")

	# 测试标记技能
	var has_holy_fire: bool = Game.SPELLS.has("holy_fire")
	var has_shadow_word_pain: bool = Game.SPELLS.has("shadow_word_pain")
	print("  神圣之火: %s" % ("存在" if has_holy_fire else "不存在"))
	print("  暗言术·痛: %s" % ("存在" if has_shadow_word_pain else "不存在"))

func test_rogue_combo() -> void:
	print("\n[测试4] 盗贼连招系统")

	var player = Game.player
	if not player:
		print("  ✗ 玩家不存在，跳过测试")
		return

	# 检查连击点
	if player.has("combo"):
		print("  当前连击点: %d / 5" % player.combo)
		print("  ✓ 盗贼连击系统已存在")
	else:
		print("  ✗ 连击系统未初始化")

	# 测试盗贼技能
	var has_poisoned_blade: bool = Game.SPELLS.has("poisoned_blade")
	var has_shadow_strike: bool = Game.SPELLS.has("shadow_strike")
	var has_eviscerate: bool = Game.SPELLS.has("eviscerate")
	print("  毒刃: %s" % ("存在" if has_poisoned_blade else "不存在"))
	print("  暗影突袭: %s" % ("存在" if has_shadow_strike else "不存在"))
	print("  剔骨: %s" % ("存在" if has_eviscerate else "不存在"))
