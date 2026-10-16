extends "res://tests/job_combat.gd"
## Native 90s sustain + pressure + interruption. No injected resources/CD resets after setup.
var results := {}
var patient: Unit
const PRIORITIES := {
	"paladin": ["pd_radiant_strike", "pd_shield_bash", "pd_oath_cut"],
	"berserker": ["bk_execute", "bk_bloodthirst", "bk_rend_slash"],
	"dark_mage": ["dm_void_pulse", "dm_pyroblast", "dm_flame_bolt", "dm_frost_spike"],
	"elementalist": ["el_lightning", "el_water_bolt"],
	"radiant": ["wh_pure_light", "wh_wind_mend", "wh_water_blessing", "wh_gale"],
	"shadow_priest": ["cl_lightning_smash", "cl_thunder_brand", "cl_holy_mace"],
	"assassin": ["as_envenom", "as_death_mark", "as_backstab", "as_venomous_cut"],
	"duelist": ["ms_unbound", "ms_arcane_edge", "ms_shadow_bolt"],
	"marksman": ["cannon_burst", "cannon_reload", "cannon_steady"],
	"gadgeteer": ["mech_rail", "mech_rocket", "mech_piston"]}
const CORE := {"paladin": ["pd_oath_cut", "pd_shield_bash", "pd_radiant_strike"], "berserker": ["bk_rend_slash", "bk_bloodthirst"], "dark_mage": ["dm_frost_spike", "dm_flame_bolt", "dm_void_pulse"], "elementalist": ["el_water_bolt", "el_lightning"], "radiant": ["wh_water_blessing", "wh_wind_mend", "wh_pure_light"], "shadow_priest": ["cl_holy_mace", "cl_thunder_brand", "cl_lightning_smash", "cl_light_guard"], "assassin": ["as_venomous_cut", "as_death_mark", "as_envenom"], "duelist": ["ms_arcane_edge", "ms_shadow_bolt", "ms_unbound"], "marksman": ["cannon_steady", "cannon_burst", "cannon_reload"], "gadgeteer": ["mech_piston", "mech_rocket", "mech_rail"]}

func policy(job: String, moving: bool = false) -> Array:
	match job:
		"paladin":
			return ["pd_radiant_strike", "pd_shield_bash", "pd_oath_cut"] if not p.get_aura("pd_oath").is_empty() else ["pd_radiant_strike", "pd_oath_cut"]
		"berserker":
			return ["bk_frenzy", "bk_execute", "bk_bloodthirst", "bk_rend_slash"]
		"dark_mage":
			if moving:
				return ["dm_void_pulse", "dm_ice_lance", "dm_shadow_bolt"]
			if p.power < p.max_power * 0.4 or p.gauge("ice_mark") == 0:
				return ["dm_void_pulse", "dm_frost_spike"]
			return ["dm_void_pulse", "dm_pyroblast", "dm_flame_bolt"]
		"elementalist":
			return ["el_lightning", "el_water_bolt"]
		"radiant":
			if patient.get_aura("wh_water_blessing").is_empty():
				return ["wh_water_blessing"]
			if p.gauge("bloom") >= 3 and patient.hp < patient.max_hp * 0.83:
				return ["wh_pure_light"]
			if patient.hp < patient.max_hp * 0.83:
				return ["wh_wind_mend"]
			return ["wh_gale"]
		"shadow_priest":
			if not p.get_aura("cl_afterglow").is_empty():
				return ["cl_light_guard", "cl_radiant_mend"]
			if absf(p.gauge("light") - p.gauge("bolt")) >= 24 and not p.cooldowns.has("cl_gauge_exchange"):
				return ["cl_gauge_exchange"]
			return ["cl_lightning_smash", "cl_thunder_brand", "cl_holy_mace"]
		"assassin":
			if p.combo >= 4:
				if d.get_aura("as_bleed").get("rem", 0) < 3:
					return ["as_death_mark"]
				return ["as_envenom"]
			if not p.cooldowns.has("as_backstab") and p.power < 25:
				return [] # Pool for the efficient two-point builder instead of starving it.
			return ["as_backstab", "as_venomous_cut"]
		"duelist":
			if p.gauge("resonance") >= 60:
				return ["ms_unbound"]
			return ["ms_arcane_edge"] if not p.get_aura("ms_shadow_edge").is_empty() else ["ms_shadow_bolt"]
		"marksman":
			if p.gauge("ammo") <= 1:
				return ["cannon_reload"]
			return ["cannon_burst", "cannon_steady"]
		"gadgeteer":
			if p.gauge("heat") >= 72:
				return ["mech_rail"]
			return ["mech_overdrive", "mech_rocket", "mech_piston", "mech_rail"]
	return []

func rotation(job: String) -> void:
	fixture(DB.spec_index[job]["class"], job)
	p.in_combat = true
	d.in_combat = true
	d.is_boss = true
	d.stats["armor"] = DataMobs.base_armor(15)
	p.auto_attack = job in ["paladin", "berserker", "shadow_priest", "assassin", "duelist"]
	p.power = p.max_power
	patient = Unit.new()
	root3d.add_child(patient)
	patient.faction = "companion"
	patient.max_hp = 2000
	patient.hp = 1600
	patient.in_combat = true
	patient.position = Vector3(1, 0, 0)
	patient.set_physics_process(false)
	if job == "gadgeteer":
		p.begin_cast(DB.spell("mech_armor", 1), p)
	var counts := {}
	p.spell_resolved.connect(func(sid, hit):
		if hit: counts[sid] = int(counts.get(sid, 0)) + 1)
	var start_hp := d.hp
	var max_block := 0.0
	var blocked := 0.0
	var cap_time := {}
	var quarter_damage := [0.0, 0.0, 0.0]
	var quarter_previous := d.hp
	var last_patient_hp := patient.hp
	var effective_healing := 0.0
	var lowest_patient := patient.hp
	var interruptions := 0
	for frame in 5400:
		var dt := 1.0 / 60.0
		var seconds := frame / 60.0
		# An actual cast/action cancellation followed by a short mechanism movement pause.
		if frame in [1200, 2400, 3600, 4800]:
			p.stop_cast()
			p.cancel_action()
			interruptions += 1
		var moving := fmod(seconds, 20.0) < 1.0 and frame >= 1200
		if job == "radiant" and frame % 60 == 0:
			patient.take_damage(90, "shadow", d, false, "治疗压力", true)
			last_patient_hp = patient.hp
		if job in ["paladin", "shadow_priest", "berserker"] and frame % 180 == 0:
			p.take_damage(p.max_hp * 0.015, "physical", d, false, "坦克压力")
		p._tick_timers(dt)
		p._tick_auras(dt)
		p._tick_cast(dt)
		p._tick_auto(dt)
		p._tick_regen(dt)
		d._tick_auras(dt)
		patient._tick_auras(dt)
		effective_healing += maxf(0, patient.hp - last_patient_hp)
		last_patient_hp = patient.hp
		lowest_patient = minf(lowest_patient, patient.hp)
		if frame % 1800 == 1799:
			quarter_damage[frame / 1800] = quarter_previous - d.hp
			quarter_previous = d.hp
		for key in p.gauges:
			if p.gauge(key) >= float(Unit.GAUGE_MAX.get(key, 100)):
				cap_time[key] = float(cap_time.get(key, 0)) + dt
		if p.gcd <= 0 and p.action_lock <= 0 and not p.is_casting() and not moving:
			var accepted := false
			for sid in policy(job):
				var sp := DB.spell(sid, 1)
				var tgt := patient if sp.get("target", "") == "friend" and job == "radiant" else (p if sp.get("target", "") in ["self", "none", "friend"] else d)
				if p.check_cast(sp, tgt) == "" and p.begin_cast(sp, tgt):
					accepted = true
					break
			if not accepted:
				blocked += dt
				max_block = maxf(max_block, blocked)
			else:
				blocked = 0
		await get_tree().process_frame
	var core_ok := true
	for sid in CORE[job]:
		core_ok = core_ok and int(counts.get(sid, 0)) >= (4 if sid in ["wh_water_blessing", "wh_pure_light", "as_death_mark", "as_envenom"] else 8)
	check(core_ok, job + " repeatedly completes every core stage, including its spender/recovery")
	check(max_block < 4.0 and not p.dead and not patient.dead, job + " recovers from interruptions without resource deadlock")
	var cap_ok := true
	for key in cap_time:
		# Small readiness stacks intentionally wait for their follow-up/healing need.
		if key in ["light", "bolt", "fury", "resonance", "heat"]:
			cap_ok = cap_ok and float(cap_time[key]) < 18.0
	check(cap_ok, job + " does not sit at capped secondary resources for >20% of combat")
	check(p.spec_resource_type == "" and p.spec_resource == 0 and p.fire_charges == 0 and p.holy_marks == 0, job + " has no hidden retired resource loop")
	if job == "radiant":
		check(effective_healing > 7000 and lowest_patient > 0, "white mage sustains effective healing against 4.5% HP/s for 90s")
	else:
		check(quarter_damage[2] > quarter_damage[0] * 0.65, job + " retains output after 60s instead of exhausting its opening resources")
	results[job] = {"seconds": 90, "damage": start_hp - d.hp, "resolved": counts, "remaining_power": p.power, "gauges": p.gauges.duplicate(), "cap_seconds": cap_time, "max_resource_block": max_block, "third_damage": quarter_damage, "effective_healing": effective_healing, "lowest_patient_hp": lowest_patient, "interruptions": interruptions}
	print("CYCLE ", job, " ", JSON.stringify(results[job]))

func run() -> void:
	seed(20261013)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for job in PRIORITIES:
		await rotation(job)
	var report := FileAccess.open(out + "/cycles_v2.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"results": results, "failed": failed, "fixture": "90s native cast/impact; green level15 weapons; same-level armored boss; real healing pressure; four action cancellations; no resource/CD refill", "saved_character": false}, "\t"))
	report.close()
	print("CYCLES DONE failed=", failed)
	get_tree().quit(1 if failed > 0 else 0)
