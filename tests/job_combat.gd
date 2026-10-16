extends Node
## Isolated native-cast regression. Never reads or writes a real character slot.
var root3d: Node3D
var p: Player
var d: Unit
var checks: Array = []
var failed := 0
var out := "res://.local/combat_jobs"

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
	failed += 0 if ok else 1
	print(("JOB PASS " if ok else "JOB FAIL ") + label)

func fixture(cls: String, job: String) -> void:
	Game.player = null
	if is_instance_valid(root3d):
		root3d.free()
	root3d = Node3D.new()
	add_child(root3d)
	Game.slot_index = -1
	Game.new_character("转职接力验证", cls, DB.random_appearance(7, "f"))
	Game.pd["new"] = false
	Game.pd["level"] = 15
	Game.pd["money"] = 10000
	var weapon: String = {"paladin": "sword", "berserker": "axe2", "dark_mage": "staff", "elementalist": "staff", "radiant": "staff", "shadow_priest": "mace2", "assassin": "dagger", "duelist": "rapier", "marksman": "sword", "gadgeteer": "sword"}[job]
	Game.pd["equip"]["main"] = "gen|%s|green|15|bear" % weapon
	if job == "paladin":
		Game.pd["equip"]["off"] = "gen|shield|green|15|bear"
	if job == "assassin":
		Game.pd["equip"]["off"] = "gen|dagger|green|15|monkey"
	if cls == "gunner":
		Game.pd["equip"]["ranged"] = "gen|gun|green|15|monkey"
	p = Player.new()
	root3d.add_child(p)
	p.set_physics_process(false)
	p.set_process(false)
	Game.player = p
	check(Specs.choose(job, true), job + " selects successfully")
	d = Unit.new()
	root3d.add_child(d)
	d.position = Vector3(0, 0, -2.5)
	d.max_hp = 100000
	d.hp = d.max_hp
	d.level = 15
	d.stats = {"dodge": 0.0, "parry": 0.0, "crit": 0.0, "spell_crit": 0.0}
	d.set_physics_process(false)
	p.stats["crit"] = 0.0
	p.stats["spell_crit"] = 0.0
	p.target = d
	p.face_towards(d.position)

func cast(sid: String, tgt: Unit = null) -> bool:
	var sp := DB.spell(sid, maxi(1, Game.spell_rank(sid)))
	if tgt == null:
		tgt = p if sp.get("target", "") in ["friend", "self", "none"] else d
	p.face_towards(tgt.global_position)
	var ok := p.begin_cast(sp, tgt)
	if not p.casting.is_empty():
		p._tick_cast(float(p.casting["total"]) + 0.01)
	p._tick_action(0.65)
	await get_tree().create_timer(0.25).timeout
	return ok

func ready() -> void:
	p.gcd = 0.0
	p.action_lock = 0.0
	p.cooldowns.clear()
	p.power = p.max_power

func kit_checks() -> void:
	for job in DB.spec_index:
		var sd: Dictionary = DB.spec_index[job]
		fixture(sd["class"], job)
		var valid := true
		for sid in sd["grants"]:
			valid = valid and DB.spells.has(sid) and Game.spell_rank(sid) == 1 and Game.pd["bars"].has({"t": "spell", "id": sid}) and Specs.spell_allowed(sid, job)
		check(valid, job + " entire kit learned, on bars, and usable by this advancement")
		var bars_valid := true
		for b in Game.pd["bars"]:
			if b != null and b.get("t") == "spell":
				bars_valid = bars_valid and Specs.spell_allowed(b["id"], job)
		check(bars_valid, job + " bars contain no retired combat skills")
		p.in_combat = true
		check(Specs.can_choose(Specs.options()[0]["id"]) != "", job + " cannot change during combat")
		p.in_combat = false

func healer_checks() -> void:
	fixture("priest", "radiant")
	p.hp = p.max_hp * 0.4
	var h := p.hp
	check(await cast("wh_wind_mend", p) and p.hp > h, "wind mend restores actual health through native cast")
	ready()
	check(await cast("wh_water_blessing", p), "water HoT native cast")
	h = p.hp
	p._tick_auras(3.01)
	check(p.hp > h, "water blessing heals on tick")
	ready()
	await cast("wh_luminous_wave", p)
	check(p.get_aura("wh_luminous_wave").get("absorb", 0) >= p.max_hp * 0.1, "white mage shield uses target max HP")
	var ally := Unit.new()
	root3d.add_child(ally)
	ally.faction = "companion"
	ally.position = Vector3(2, 0, 0)
	ready()
	await cast("wh_wind_step", p)
	check(ally.aura_mod("speed") > 0.1, "wind step buffs nearby companion")
	check(p.check_cast(DB.spell("mind_blast", 1), d) != "", "white mage cannot borrow dark priest burst")

func cleric_checks() -> void:
	fixture("priest", "shadow_priest")
	check(Game.can_equip(DB.get_item("gen|mace2|green|15"), false) and Game.can_equip(DB.get_item("gen|chest|mail|green|15"), false), "cleric may equip double-handed mace and mail")
	await cast("cl_holy_mace", d)
	check(p.gauge("light") == 12 and p.gauge("bolt") == 12, "cleric main attack generates both gauges")
	ready()
	await cast("cl_light_focus", p)
	ready()
	await cast("cl_holy_mace", d)
	check(p.gauge("light") == 30 and p.gauge("bolt") == 24, "light focus boosts only light generation")
	ready()
	await cast("cl_bolt_focus", p)
	check(p.get_aura("cl_light_focus").is_empty(), "light and bolt focus mutually exclude")
	p.gauge_clear("light")
	p.gauge_clear("bolt")
	p.gauge_add("light", 80)
	p.gauge_add("bolt", 20)
	ready()
	await cast("cl_gauge_exchange", p)
	check(p.gauge("light") == 50 and p.gauge("bolt") == 50, "gauge conversion balances while preserving total energy")
	ready()
	await cast("cl_thunder_brand", p)
	check(p.gauge("bolt") == 30 and not p.get_aura("cl_thunder_brand").is_empty(), "lightning enchant pays bolt gauge")
	p.enchant_timer = 0.0
	for attempt in 10:
		p.deal_melee_damage(d, 10, "enchant probe")
		if p.enchant_timer > 0:
			break
	check(p.enchant_timer > 0.0, "enchant procs only on landed melee attack with internal cooldown")
	p.hp = p.max_hp * 0.4
	var h := p.hp
	ready()
	await cast("cl_radiant_mend", p)
	check(p.hp > h and p.gauge("light") == 20, "cleric heal spends light and restores health")
	ready()
	await cast("cl_provoke", d)
	check(d.top_threat() == p and d.target == p, "cleric has native taunt")

func melee_checks() -> void:
	fixture("rogue", "assassin")
	await cast("as_venomous_cut", d)
	check(p.combo == 1 and not d.get_aura("as_poison").is_empty(), "assassin gains combo and poison")
	for attempt in 4:
		ready()
		await cast("as_venomous_cut", d)
	ready()
	await cast("as_death_mark", d)
	check(p.combo == 0 and not d.get_aura("as_bleed").is_empty(), "assassin spender consumes combo and applies bleeding")
	Game.pd["equip"].erase("off")
	check(p.check_cast(DB.spell("as_venomous_cut", 1), d) != "", "assassin requires two daggers")
	fixture("rogue", "duelist")
	check(Game.can_equip(DB.get_item("gen|rapier|green|15"), false), "spellblade rapier obtainable and equippable")
	for attempt in 6:
		ready()
		await cast("ms_arcane_edge", d)
	check(p.gauge("resonance") == 60, "spellblade melee builds resonance")
	ready()
	check(await cast("ms_unbound", d) and p.gauge("resonance") == 0, "neutral finisher consumes resonance")
	ready()
	check(p.check_cast(DB.spell("ms_shadow_bolt", 1), d) == "", "spellblade shadow generates resonance without requiring it")

func gunner_checks() -> void:
	fixture("gunner", "marksman")
	var mana := p.power
	for attempt in 2:
		ready()
		await cast("cannon_steady", d)
	check(p.gauge("ammo") == 4 and p.gauge("aim") == 2 and p.power == mana, "firearms spend real ammo and build aim without magic mana")
	ready()
	check(await cast("cannon_burst", d) and p.gauge("ammo") == 2 and p.gauge("aim") == 0, "hand cannon consumes ammo and aim")
	check(p.check_cast(DB.spell("aether_shot", 1), d) != "", "artillerist cannot borrow magic shot")
	fixture("gunner", "gadgeteer")
	check(p.check_cast(DB.spell("mech_piston", 1), d) != "", "mech requires deployed armor")
	await cast("mech_armor", p)
	ready()
	await cast("mech_piston", d)
	check(p.gauge("heat") == 18 and p.aura_mod("dmg_taken") < 0, "mech punch builds heat and armor reduces incoming damage")
	p.gauge_add("heat", 76)
	ready()
	check(p.check_cast(DB.spell("mech_rocket", 1), d) != "", "mech blocks overheating attacks")
	await cast("mech_vent", p)
	check(p.gauge("heat") == 34, "two vent ticks shed sixty heat")
	check(p.check_cast(DB.spell("summon_hound", 1), p) != "", "mech cannot summon mechanical pets")

func boundary_checks() -> void:
	fixture("warrior", "paladin")
	p.stamina = 20
	check(not p.begin_cast(DB.spell("dodge_roll", 1), p) and not p.motion_active, "exhausted player cannot roll without paying stamina")
	p.stamina = p.max_stamina
	p.invincible_frames = 0.18
	var h := p.hp
	p.take_damage(50, "fire", d, false, "mechanic", false, 0, true)
	check(p.hp < h, "mechanic damage bypasses roll window")
	h = p.hp
	p.take_damage(20, "shadow", d, false, "dot", true)
	check(p.hp < h, "periodic damage bypasses roll window")
	p.riposte_window = 1.2
	h = p.hp
	d.deal_melee_damage(p, 70, "boss stomp", 0, true, false, true)
	check(p.hp < h and p.riposte_window > 0, "boss AoE cannot be shield-countered")
	d.is_boss = true
	d.add_aura({"id": "probe_stun", "dur": 5.0, "stun": true, "type": "debuff"}, p)
	d.add_aura({"id": "probe_root", "dur": 5.0, "root": true, "type": "debuff"}, p)
	check(not d.is_stunned() and not d.is_rooted(), "all aura paths preserve boss control immunity")
	d.casting = {"sp": DB.spell("mob_stomp", 1), "target": p, "elapsed": 0.0, "total": 1.5, "channel": false}
	p.apply_effects({"effects": [{"type": "interrupt"}]}, d)
	check(d.is_casting(), "uninterruptible telegraph cannot be cancelled by interrupt skill")
	d.casting["sp"] = DB.spell("mob_bell", 1)
	p.apply_effects({"effects": [{"type": "interrupt"}]}, d)
	check(not d.is_casting(), "explicitly interruptible bell remains interruptible")
	p.add_aura({"id": "encounter_mark", "dur": 20.0, "type": "debuff"}, d)
	p.add_aura({"id": "poison_mark", "dur": 20.0, "type": "debuff", "dispel": true}, d)
	p.apply_effects({"effects": [{"type": "dispel_debuff", "count": 1}]}, p)
	check(not p.get_aura("encounter_mark").is_empty() and p.get_aura("poison_mark").is_empty(), "cleanse preserves non-dispellable encounter marks")
	p.gauge_add("holy_power", 5)
	p.in_combat = false
	p.invincible_frames = 0
	d.position = Vector3(0, 0, -2.5)
	ready()
	p.begin_cast(DB.spell("pd_shield_bash", 1), d)
	var before := d.hp
	check(not p.pending_action.is_empty() and d.hp == before, "melee strike has actual windup")
	p.begin_cast(DB.spell("dodge_roll", 1), p)
	p._tick_action(1.0)
	check(p.pending_action.is_empty() and d.hp == before, "roll cancels unlanded strike without dealing free damage")
	p.cancel_action()
	p.cooldowns.clear()
	p.in_combat = false
	check(Specs.choose("berserker", true) and p.gauges.is_empty() and p.riposte_window == 0 and p.invincible_frames == 0, "changing job clears old combat resources and counter window")
	# Real collision wall, using the player capsule and native physics tween.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 0.5)
	shape.shape = box
	wall.add_child(shape)
	root3d.add_child(wall)
	wall.position = Vector3(0, 1, -2)
	await get_tree().physics_frame
	p.position = Vector3.ZERO
	p._move_skill(Vector3(0, 0, -6), 0.2, 6)
	await get_tree().create_timer(0.3).timeout
	check(p.position.z > -1.6, "swept skill motion stops at wall instead of crossing")
	p.cancel_action()
	p.position = Vector3.ZERO
	p._move_skill(Vector3(0, 5, -2), 0.2, 6)
	check(not p.motion_active and p.position == Vector3.ZERO, "skill displacement refuses crossing different floors")
	# One short input buffer with preserved target, no stale target reuse.
	p.gcd = 0.12
	p.cast_spell_id("bk_rend_slash")
	check(p.buffered_skill == "bk_rend_slash", "near-GCD input is buffered")
	p.gcd = 0
	d.dead = true
	p._tick_skill_buffer(0.05)
	check(p.buffered_skill == "" and p.pending_action.is_empty(), "buffer discards dead intended target")

func run() -> void:
	seed(20261013)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	kit_checks()
	var intervals_valid := true
	for sid in DB.spells:
		for rank in maxi(1, DB.spells[sid].get("ranks", []).size()):
			for e in DB.spell(sid, rank + 1).get("effects", []):
				if e.has("min") and e.has("max"):
					intervals_valid = intervals_valid and e["min"] <= e["max"]
	check(intervals_valid, "all skill ranks preserve ordered damage intervals")
	await healer_checks()
	await cleric_checks()
	await melee_checks()
	await gunner_checks()
	await boundary_checks()
	fixture("rogue", "assassin")
	await cast("vanish", p)
	check(p.is_stealthed(), "vanish grants actual stealth")
	p.take_damage(12, "fire", d, false, "probe", true)
	check(not p.is_stealthed(), "damage removes vanish stealth")
	ready()
	await cast("vanish", p)
	ready()
	await cast("as_backstab", d)
	check(not p.is_stealthed(), "attacking from vanish removes stealth")
	fixture("mage", "dark_mage")
	check(p.begin_cast(DB.spell("dm_soul_siphon", 1), d), "siphon starts native channel")
	d.position.z = -45
	var before := d.hp
	p._tick_cast(1.1)
	check(not p.is_casting() and d.hp == before, "channel stops without damage after target leaves range")
	fixture("gunner", "gadgeteer")
	p.model.set_mech_armor(true)
	check(p.model.mech_parts.size() == 7 and p.model.mech_parts[0].visible, "mech armor is visible on seven animated bones")
	p.model.set_gear(Game.gear_visuals())
	check(p.model.mech_parts.size() == 7 and p.model.mech_parts[0].visible, "mech armor survives visual gear rebuild")
	p.model.set_mech_armor(false)
	check(not p.model.mech_parts[0].visible, "stowing armor hides its meshes")
	fixture("priest", "shadow_priest")
	Game.pd["equip"]["chest"] = "gen|chest|mail|green|15|bear"
	for i in Game.pd["bag"].size():
		Game.pd["bag"][i] = {"id": "food_bread", "n": 1}
	var money := int(Game.pd["money"])
	check(not Specs.choose("radiant", true) and Game.pd["spec"] == "shadow_priest" and Game.pd["money"] == money, "full bag prevents incompatible-gear change without charging or losing items")
	Game.pd["bag"][0] = null
	Game.pd["bag"][1] = null
	check(Specs.choose("radiant", true) and not Game.pd["equip"].has("chest") and not Game.pd["equip"].has("main"), "changing cleric to healer stows mail and double hammer")
	check(Game.count_item("gen|chest|mail|green|15|bear") == 1 and Game.count_item("gen|mace2|green|15|bear") == 1, "retired equipment remains in bag with no item loss")
	fixture("rogue", "assassin")
	p.gcd = 0.12
	p.cast_spell_id("as_venomous_cut")
	p.gcd = 0
	p._tick_skill_buffer(0.05)
	check(p.auto_attack and not p.pending_action.is_empty(), "buffered melee starts ordinary combat and native windup")
	fixture("warrior", "paladin")
	var boss := Mob.new()
	root3d.add_child(boss)
	boss.init_mob("boss_rootguard")
	boss.set_physics_process(false)
	boss.position = Vector3(0, 0, -2.5)
	p.invincible_frames = 0.18
	p.riposte_window = 1.2
	var health := p.hp
	check(boss.begin_cast(DB.spell("mob_stomp", 1), boss), "real sanctum boss starts its telegraphed native spell")
	boss._tick_cast(1.51)
	check(p.hp < health and p.riposte_window > 0, "real boss cast delivers AoE through roll and shield counter")
	fixture("rogue", "duelist")
	Game.pd["equip"].erase("off")
	check(Game._resolve_equip_slot(DB.get_item("gen|rapier|white|15")) == "main", "equipping spellblade rapier defaults to required main hand")
	fixture("priest", "shadow_priest")
	Game.pd["level"] = 14
	Game.pd["equip"].erase("chest")
	var armor := float(Game.calc_stats()["armor"])
	Game.pd["equip"]["chest"] = "gen|chest|mail|green|15|bear"
	check(Game.calc_stats()["armor"] == armor, "invalid lower-level saved equipment contributes no armor")
	p.recalc_stats()
	check(not Game.can_equip(DB.get_item(Game.pd["equip"]["main"]), false) and p.wdmg.x < 10, "lower-level saved cleric hammer cannot retain weapon damage")
	fixture("warrior", "paladin")
	Game.pd["spec"] = ""
	p.spec = ""
	p.recalc_stats()
	p.spec_resource_type = "momentum"
	Specs.invalidate()
	Specs.sync_spells(true)
	check(p.begin_cast(DB.spell("gather_momentum", 1), p), "starter warrior begins a real three-tick channel")
	p._tick_cast(0.51)
	p.stop_cast()
	check(p.spec_resource == 15, "interrupted gathering retains only the completed resource tick")
	ready()
	p.spec_resource = 0
	p.begin_cast(DB.spell("gather_momentum", 1), p)
	p._tick_cast(1.51)
	check(p.spec_resource == 45, "full gathering produces the advertised 45 momentum")
	ready()
	p.begin_cast(DB.spell("slash", 1), d)
	ready()
	check(p.check_cast(DB.spell("heavy_slash", 1), d) == "" and p.spec_resource == 30, "starter gathering supports the slash-to-heavy chain without a resource deadlock")
	var report := FileAccess.open(out + "/regression.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failed": failed, "saved_character": false}, "\t"))
	report.close()
	print("JOB DONE checks=%d failed=%d" % [checks.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)
