extends Node
## Never saves a character. Core invariants, real level-1 combat, and rendered UI evidence.
var checks: Array = []
var out := "res://.local/combat_icons_20261006"
var root3d: Node3D
var p: Player

func _ready() -> void:
	if not has_meta("runner"):
		var runner := Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(runner)
		return
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"pass": ok, "label": label})
	print(("COMBAT PASS " if ok else "COMBAT FAIL ") + label)

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func character(cls: String) -> void:
	Game.slot_index = -1
	Game.new_character("循环验证", cls, DB.random_appearance(7, "f"))
	Game.pd["new"] = false

func pending_count() -> int:
	var n := 0
	for entry in Game.pd.get("pending_loot", []):
		n += entry.n
	return n

func loot_checks() -> void:
	character("mage")
	Game.pd.bag.fill(null)
	var source := {"money": 37, "items": [["mat_leather", 3]]}
	Game.receive_loot(source)
	check(Game.pd.money == 37 and Game.count_item("mat_leather") == 3 and source.items.is_empty(), "loot money/items delivered without interaction")
	Game.receive_loot(source)
	check(Game.pd.money == 37 and Game.count_item("mat_leather") == 3, "same source cannot duplicate loot")
	var stack: int = DB.get_item("mat_leather").get("stack", 1)
	for i in Game.BAG_SIZE:
		Game.pd.bag[i] = {"id": "hearthstone", "n": 1}
	Game.pd.bag[0] = {"id": "mat_leather", "n": stack - 1}
	var observed := [0]
	var observe := func(): observed[0] = pending_count()
	Game.inventory_changed.connect(observe)
	Game.receive_loot({"money": 2, "items": [["mat_leather", 4]]})
	check(Game.count_item("mat_leather") == stack and pending_count() == 3 and Game.pd.money == 39, "partial stack and full bag preserve exact overflow")
	check(observed[0] == 3, "inventory notification exposes final overflow count to UI")
	Game.inventory_changed.disconnect(observe)
	# Same variant serialization used by save_character, without opening a real save.
	var f := FileAccess.open(out + "/pending_test.sav", FileAccess.WRITE)
	f.store_string(var_to_str(Game.pd))
	f.close()
	f = FileAccess.open(out + "/pending_test.sav", FileAccess.READ)
	Game.pd = str_to_var(f.get_as_text())
	f.close()
	check(pending_count() == 3, "pending loot survives save serialization")
	Game.remove_item("hearthstone", 1)
	await get_tree().process_frame
	check(pending_count() == 0 and Game.count_item("mat_leather") == stack + 3, "freeing one slot automatically delivers overflow once")
	Game.inventory_changed.emit()
	await get_tree().process_frame
	check(Game.count_item("mat_leather") == stack + 3, "repeat inventory signals do not duplicate items")
	Game.pd.bag.fill(null)
	for qid in DB.quests:
		var q: Dictionary = DB.quests[qid]
		for i in q.get("obj", []).size():
			var obj: Dictionary = q.obj[i]
			if obj.type == "collect":
				var prog: Array = []
				prog.resize(q.obj.size())
				prog.fill(0)
				Game.pd.quests[qid] = {"p": prog}
				Game.receive_loot({"items": [[obj.item, 1]]})
				check(Game.objective_progress(qid, i) == 1, "automatic quest-item pickup advances collection progress")
				return

func starter_checks() -> void:
	var pairs := {"warrior": ["slash", "charge"], "mage": ["frostbolt", "fireball"], "priest": ["smite", "shadow_word_pain"], "rogue": ["poisoned_blade", "eviscerate"], "gunner": ["steady_shot", "aether_shot"]}
	for cls in pairs:
		character(cls)
		var ready := true
		for sid in pairs[cls]:
			ready = ready and Game.spell_rank(sid) == 1 and Game.pd.bars.has({"t": "spell", "id": sid})
		check(ready, cls + " level-1 rotation learned and placed on bar")
		var unique := true
		for sid in DB.classes[cls].spells:
			unique = unique and IconArt.texture("skills/" + sid) != null
		check(unique, cls + " entire skillbook has dedicated icon art")
	character("mage")
	check(Game.pd.spells.size() == 2, "mage starts with exactly two class skills")
	check(DB.spell_rank_level("frost_armor", 1) == 3 and DB.spell_rank_level("frost_nova", 1) == 4 and DB.spell_rank_level("living_bomb", 1) == 6, "mage additional tools unlock progressively")
	Game.pd.spells = {"fireball": 3, "frost_armor": 1}
	for i in Game.BAR_SLOTS:
		Game.pd.bars[i] = {"t": "spell", "id": "fireball"}
	var bars: Array = Game.pd.bars.duplicate(true)
	Game._grant_starter_rotation()
	check(Game.spell_rank("fireball") == 3 and Game.spell_rank("frostbolt") == 1 and Game.pd.bars == bars, "old character gains new skills without overwriting ranks or full bars")
	Game.pd.bars[7] = null
	Game.pd.spells.erase("frostbolt")
	Game._grant_starter_rotation()
	check(Game.pd.bars[7] == {"t": "spell", "id": "frostbolt"}, "old character places missing starter skill only in empty slot")

func make_player(cls: String) -> Player:
	character(cls)
	var unit := Player.new()
	root3d.add_child(unit)
	unit.set_physics_process(false)
	unit.set_process(false)
	Game.player = unit
	return unit

func dummy() -> Unit:
	var d := Unit.new()
	root3d.add_child(d)
	d.position = Vector3(0, 0, -10)
	d.max_hp = 100000
	d.hp = d.max_hp
	d.set_physics_process(false)
	return d

func cast_complete(unit: Unit, sid: String, target: Unit) -> bool:
	unit.gcd = 0
	unit.cooldowns.erase(sid)
	var sp := DB.spell(sid, maxi(1, Game.spell_rank(sid)))
	unit.face_towards(target.global_position)
	var ok := unit.begin_cast(sp, target)
	if not unit.casting.is_empty():
		unit._tick_cast(unit.casting.total + 0.01)
	await wait(0.6) # Real projectile travel; no substitution of damage effects.
	return ok

func mechanics_checks() -> void:
	root3d = Node3D.new()
	add_child(root3d)
	p = make_player("mage")
	var d := dummy()
	p.begin_cast(DB.spell("fireball", 1), d)
	p._tick_cast(0.7)
	p.take_damage(1, "physical", d)
	check(not p.casting.is_empty() and is_equal_approx(p.casting.elapsed, 0.7), "ordinary hit does not delay or interrupt player cast")
	d.apply_effects({"effects": [{"type": "interrupt", "lock": 4.0}]}, p)
	check(p.casting.is_empty() and p.school_lock.has("fire"), "explicit interrupt still stops cast and locks school")
	p.school_lock.clear()
	p.gcd = 0
	p.power = 0
	p.begin_cast(DB.spell("frost_nova", 1), p)
	p._tick_cast(1.0)
	p.take_damage(1, "physical", d)
	p._tick_cast(2.01)
	check(p.casting.is_empty() and is_equal_approx(p.power, p.max_power * 0.54), "recovery channel restores 54 percent through ordinary hits")
	p.power = 0
	check(await cast_complete(p, "frostbolt", d) and p.power >= p.max_power * 0.14, "mage can recover from zero mana while dealing damage")
	var mana_before := p.power
	var hp_before := d.hp
	check(await cast_complete(p, "fireball", d) and p.power < mana_before and d.hp < hp_before, "mage fire spender consumes mana and deals damage")
	p.power = p.max_power * 0.5
	var casts_ok := true
	for round_i in 4:
		for sid in ["fireball", "fireball", "frostbolt", "frostbolt"]:
			casts_ok = await cast_complete(p, sid, d) and casts_ok
	check(casts_ok and p.power >= p.max_power * 0.5, "four fire/ice loops remain sustainable without passive regen or drinking")
	p.in_combat = false
	p.power = 0
	p._regen_acc = 0
	p._tick_regen(1.0)
	check(p.power >= p.max_power * 0.08, "out-of-combat recovery reduces waiting")
	p.free()
	for cls in ["priest", "gunner"]:
		p = make_player(cls)
		p.power = 0
		var builder: String = "smite" if cls == "priest" else "steady_shot"
		check(await cast_complete(p, builder, d) and p.power >= p.max_power * 0.12, cls + " recovers from zero with a damaging builder")
		var spender: String = "holy_fire" if cls == "priest" else "aether_shot"
		await cast_complete(p, builder, d)
		mana_before = p.power
		check(await cast_complete(p, spender, d) and p.power < mana_before, cls + " can spend regenerated resource")
		p.free()
	p = make_player("warrior")
	d.position.z = -3
	p.spec_resource = 0
	check(await cast_complete(p, "slash", d) and p.spec_resource >= 30, "warrior builds momentum from zero")
	await cast_complete(p, "slash", d)
	# 战士新系统无queued攻击，跳过该测试
	p.free()
	p = make_player("rogue")
	for i in 3:
		await cast_complete(p, "poisoned_blade", d)
	check(p.combo == 3, "rogue starter builds three combo points")
	p._tick_regen(1.0)
	p._tick_regen(1.0)
	mana_before = p.power
	check(await cast_complete(p, "eviscerate", d) and p.combo == 0 and is_equal_approx(p.power, mana_before - 25 + 15), "rogue finisher consumes points and refunds energy per point")
	p.free()
	d.free()
	Game.player = null
	root3d.queue_free()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")

func live_world_checks() -> void:
	character("mage")
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	p = Game.player
	Game.time_of_day = 12
	await wait(1)
	await shot("mage_hud")
	Game.hud.toggle_window("spells")
	await wait(0.5)
	await shot("mage_spellbook")
	Game.hud.close_all()
	# Isolate the two attackers from town guards and ambient mobs in this test only.
	for u in get_tree().get_nodes_in_group("units"):
		if u != p:
			u.process_mode = Node.PROCESS_MODE_DISABLED
	# Real AI, movement, incoming attacks and spell projectiles. Only starter gear/skills.
	var origin := p.global_position
	for trial in 3:
		seed(410 + trial)
		p.clear_auras()
		p.cooldowns.clear()
		p.gcd = 0
		p.hp = p.max_hp
		p.power = p.max_power
		p.leave_combat()
		var mobs: Array[Mob] = []
		for x in [-1.2, 1.2]:
			var m: Mob = Game.world.zones.vale.spawn_mob("young_wolf", origin + Vector3(x, 0, -9))
			m.level = 2 if trial == 2 else 1
			m._build_stats()
			m.no_xp = true
			m._engage(p)
			mobs.append(m)
		var start := Time.get_ticks_msec()
		var casts := {}
		while not p.dead and not (mobs[0].dead and mobs[1].dead) and Time.get_ticks_msec() - start < 45000:
			if p.casting.is_empty() and p.gcd <= 0:
				var tgt: Mob = mobs[0] if not mobs[0].dead else mobs[1]
				p.set_target(tgt)
				p.face_towards(tgt.global_position)
				var sid := "fireball"
				if p.power < 40:
					sid = "frostbolt"
				p.cast_spell_id(sid)
				casts[sid] = casts.get(sid, 0) + 1
			await wait(0.05)
		var duration := (Time.get_ticks_msec() - start) / 1000.0
		check(not p.dead and mobs[0].dead and mobs[1].dead, "level-1 mage defeats two simultaneous level-%d wolves trial %d" % [mobs[0].level, trial])
		print("COMBAT ENCOUNTER ", JSON.stringify({"trial": trial, "enemy_level": mobs[0].level, "seconds": duration, "hp": p.hp, "max_hp": p.max_hp, "mana": p.power, "max_mana": p.max_power, "casts": casts}))
		check(not mobs[0].has_loot() and not mobs[1].has_loot(), "both defeated enemies already transferred loot")
		check(mobs[0].last_attacker == p and mobs[1].last_attacker == p, "both kills credited to mage without guard assistance")
		var money: int = Game.pd.money
		mobs[0].loot_all()
		mobs[1].loot_all()
		check(Game.pd.money == money, "corpse interaction cannot award money twice")
		await shot("mage_two_wolves_%d" % trial)
		for m in mobs:
			m.queue_free()
		if p.dead:
			break
	# Compact contact sheet at actual slot size; does not modify the game's layout.
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(80, 50)
	panel.add_theme_stylebox_override("panel", UITheme.sb(Color("172333"), 12, 1, UITheme.LINE, 18))
	layer.add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	rows.add_child(UITheme.label("职业技能图标 · 52px", 20))
	for cls in DB.classes:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var label := UITheme.label(DB.classes[cls].name, 16)
		label.custom_minimum_size.x = 90
		row.add_child(label)
		for sid in DB.classes[cls].spells:
			var slot := Slot.new()
			slot.set_spell(sid)
			row.add_child(slot)
	await wait(0.5)
	await shot("skill_icon_sheet")
	layer.queue_free()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await loot_checks()
	starter_checks()
	await mechanics_checks()
	if not "core" in OS.get_cmdline_user_args():
		await live_world_checks()
	var failures := checks.filter(func(c): return not c["pass"]).size()
	FileAccess.open(out + "/results.json", FileAccess.WRITE).store_string(JSON.stringify(checks, "\t"))
	print("COMBAT RESULT %d PASS / %d FAIL" % [checks.size() - failures, failures])
	Game.slot_index = -1
	get_tree().quit(1 if failures else 0)
