extends SceneTree

# 快速验证战斗系统改造
# 运行: godot --headless --script tools/verify_combat_changes.gd

func _repeat_char(c: String, n: int) -> String:
	var result := ""
	for i in range(n):
		result += c
	return result

func _init():
	print("\n" + _repeat_char("=", 60))
	print("战斗系统改造验证")
	print(_repeat_char("=", 60))

	# 加载技能数据
	var SPELLS: Dictionary = DataSpells.spells()
	var CLASS: Dictionary = DataSpells.classes()

	print("\n[1] 职业配置检查")
	print(_repeat_char("-", 60))
	for cls in ["warrior", "mage", "rogue", "priest"]:
		var cfg = CLASS[cls]
		print("\n%s (%s)" % [cfg["name"], cls])
		print("  专精资源: %s" % cfg.get("spec_resource_type", "无"))
		print("  技能数量: %d" % cfg["spells"].size())
		var spell_names := []
		for sid in cfg["spells"]:
			if SPELLS.has(sid):
				spell_names.append(SPELLS[sid]["name"])
		print("  前5个技能: %s" % ", ".join(spell_names.slice(0, 5)))

	print("\n\n[2] 新技能系统检查")
	print(_repeat_char("-", 60))

	# 战士势能技能
	print("\n战士势能技能:")
	for sid in ["charge", "thunder_strike", "slash", "whirlwind"]:
		if SPELLS.has(sid):
			var sp = SPELLS[sid]
			print("  • %s: 消耗=%d, 效果=%s" % [sp["name"], sp.get("cost", 0), _get_effects_desc(sp)])

	# 法师充能技能
	print("\n法师充能技能:")
	for sid in ["fireball", "frostbolt", "fire_blast", "frost_nova"]:
		if SPELLS.has(sid):
			var sp = SPELLS[sid]
			print("  • %s: 消耗=%d, 施法=%.1fs, 效果=%s" % [sp["name"], sp.get("cost", 0), sp.get("cast", 0.0), _get_effects_desc(sp)])

	# 盗贼连击技能
	print("\n盗贼连击技能:")
	for sid in ["sinister_strike", "backstab", "eviscerate", "slice_and_dice"]:
		if SPELLS.has(sid):
			var sp = SPELLS[sid]
			print("  • %s: 消耗=%d, 效果=%s" % [sp["name"], sp.get("cost", 0), _get_effects_desc(sp)])

	# 牧师标记技能
	print("\n牧师标记技能:")
	for sid in ["smite", "holy_fire", "shadow_word_pain", "mind_blast"]:
		if SPELLS.has(sid):
			var sp = SPELLS[sid]
			print("  • %s: 消耗=%d, 效果=%s" % [sp["name"], sp.get("cost", 0), _get_effects_desc(sp)])

	print("\n\n[3] 新Effect类型统计")
	print(_repeat_char("-", 60))
	var effect_types := {}
	for sid in SPELLS:
		var sp = SPELLS[sid]
		for eff in sp.get("effects", []):
			var t: String = eff.get("type", "unknown")
			effect_types[t] = effect_types.get(t, 0) + 1

	var sorted_types := effect_types.keys()
	sorted_types.sort()
	for t in sorted_types:
		print("  %s: %d次" % [t, effect_types[t]])

	print("\n\n[4] 新Requires类型统计")
	print(_repeat_char("-", 60))
	var require_types := {}
	for sid in SPELLS:
		var sp = SPELLS[sid]
		var req = sp.get("requires", {})
		for k in req.keys():
			require_types[k] = require_types.get(k, 0) + 1

	if require_types.size() > 0:
		var sorted_reqs := require_types.keys()
		sorted_reqs.sort()
		for k in sorted_reqs:
			print("  %s: %d次" % [k, require_types[k]])
	else:
		print("  (无新requires类型)")

	print("\n\n[5] 技能消耗分析")
	print(_repeat_char("-", 60))
	var zero_cost := 0
	var has_cost := 0
	for sid in SPELLS:
		var sp = SPELLS[sid]
		if sp.get("cost", 0) == 0:
			zero_cost += 1
		else:
			has_cost += 1
	print("  0消耗技能: %d" % zero_cost)
	print("  有消耗技能: %d" % has_cost)
	print("  总技能数: %d" % SPELLS.size())

	print("\n\n" + _repeat_char("=", 60))
	print("验证完成！")
	print(_repeat_char("=", 60) + "\n")

	quit()

func _get_effects_desc(sp: Dictionary) -> String:
	var effects = sp.get("effects", [])
	if effects.is_empty():
		return "无"
	var types := []
	for eff in effects:
		var t: String = eff.get("type", "?")
		if not types.has(t):
			types.append(t)
	return ", ".join(types)
