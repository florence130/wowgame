extends "res://tests/job_arena.gd"
## Render-only examples and action evidence. Gauge sample values are explicitly injected.
const OUTPUT := "res://.local/combat_jobs/presentation_v2"
var action_records: Array = []

func _ready() -> void:
	super._ready()
	capture_mode = true
	call_deferred("run_presentation")

func render_wait(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw

func sample(name_: String) -> void:
	await render_wait(2)
	get_viewport().get_texture().get_image().save_png(OUTPUT + "/" + name_ + ".png")

func run_presentation() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var examples := {
		"paladin": {"holy_power": 3}, "berserker": {"fury": 55},
		"dark_mage": {"ice_mark": 3, "ember": 3}, "elementalist": {"tide": 2},
		"radiant": {"bloom": 3}, "shadow_priest": {"light": 52, "bolt": 44},
		"assassin": {}, "duelist": {"resonance": 60},
		"marksman": {"ammo": 4, "aim": 2}, "gadgeteer": {"heat": 84}}
	for job in examples:
		choose_job(job)
		_connect_player()
		player.set_physics_process(false)
		player.set_process(false)
		await render_wait(20)
		player.gauges.clear()
		for key in examples[job]: player.gauge_add(key, examples[job][key])
		if job == "assassin":
			player.combo = 4
			player.combo_target = enemy
			enemy.add_aura({"id": "as_poison", "dur": 12.0, "type": "debuff"}, player)
			enemy.add_aura({"id": "as_bleed", "dur": 12.0, "type": "debuff"}, player)
		if job == "shadow_priest": player.add_aura({"id": "cl_thunder_brand", "dur": 12.0, "type": "buff"}, player)
		await sample("gauge_" + job)
	print("PRESENTATION gauges: injected UI state examples (not rotation evidence)")
	var actions := [
		["paladin", "pd_shield_bash"], ["berserker", "bk_bloodthirst"],
		["shadow_priest", "cl_holy_mace"], ["assassin", "as_venomous_cut"],
		["duelist", "ms_arcane_edge"], ["marksman", "cannon_steady"],
		["marksman", "cannon_reload"], ["gadgeteer", "mech_piston"],
		["gadgeteer", "mech_rail"], ["dark_mage", "dm_ice_lance"],
		["radiant", "wh_water_blessing"], ["paladin", "dodge_roll"]]
	for action in actions:
		var job: String = action[0]
		var sid: String = action[1]
		choose_job(job)
		_connect_player()
		player.cam_yaw = 0.85
		player.cam_dist = 4.2
		player.cam_dist_target = 4.2
		player.cam_pitch = -0.12
		player.stats["crit"] = 0.0
		player.stats["spell_crit"] = 0.0
		player.set_target(patient if job == "radiant" else enemy)
		await render_wait(24)
		if sid == "bk_bloodthirst": player.gauge_add("fury", 40)
		if sid == "mech_rail": player.gauge_add("heat", 72)
		if sid == "cannon_reload": player.gauge_clear("ammo")
		var record := {"job": job, "skill": sid, "resource_setup_injected": sid in ["bk_bloodthirst", "mech_rail", "cannon_reload"], "frames": [], "resolved": []}
		player.spell_resolved.connect(func(resolved_sid, hit): record["resolved"].append({"skill": resolved_sid, "hit": hit}))
		var sp := DB.spell(sid, 1)
		var windup: float = sp.get("windup", 0.16)
		var duration: float = windup + float(sp.get("recovery", 0.24))
		if sid == "cannon_reload": duration = 1.2
		if sid == "dodge_roll": duration = 0.28
		var captures := [1, maxi(2, int(windup * 0.65 * 60)), maxi(3, int(windup * 60) + 1), int((windup + 0.08) * 60), int(duration * 60), int((duration + 0.15) * 60)]
		if sid == "cannon_reload": captures = [1, 12, 25, 37, 55, 73]
		player.cast_spell_id(sid)
		player.auto_attack = false
		player.auto_shoot = false
		for frame in range(1, int((duration + 0.2) * 60) + 2):
			await render_wait(1)
			if frame in captures:
				var name_: String = "action_%s_%02d" % [sid, frame]
				get_viewport().get_texture().get_image().save_png(OUTPUT + "/" + name_ + ".png")
				record["frames"].append({"frame": frame, "hp": enemy.hp, "style": player.model.skill_style, "pose_time": player.model.attack_t, "image": name_ + ".png"})
		action_records.append(record)
		print("PRESENTATION action ", sid, " resolved=", record["resolved"])
	var report := FileAccess.open(OUTPUT + "/evidence.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"ui_samples_injected": true, "actions": action_records, "saved_character": false}, "\t"))
	report.close()
	Game.hud = null
	Game.world = null
	Game.player = null
	get_tree().quit()
