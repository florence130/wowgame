extends "res://tests/job_arena.gd"
## Rendered native keyboard casts. Prerequisites are deliberately seeded only
## in this presentation fixture; the full dungeon run is a separate check.
const CASES := [
	["paladin","pd_shield_bash"],["paladin","pd_hallowed_verdict"],
	["berserker","bk_reaping_cleave"],["berserker","bk_blood_cyclone"],
	["dark_mage","dm_scorch"],["dark_mage","dm_blizzard_burst"],["dark_mage","dm_umbral_nova"],
	["elementalist","el_riptide_ring"],["elementalist","el_overload"],
	["radiant","wh_sunlit_flash"],["radiant","wh_wind_mend"],
	["shadow_priest","cl_thunder_nova"],["assassin","as_fan_of_knives"],
	["duelist","ms_arcane_edge"],["duelist","ms_unbound"],
	["marksman","cannon_ricochet"],["gadgeteer","mech_coolant_spray"]
]

func capture_all() -> void:
	var out := "res://.shots/gameplay_world_20261016/combat_showcase"
	var selected: PackedStringArray=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("skills="):selected=arg.substr(7).split(",")
		if arg.begins_with("out="):out=arg.substr(4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var report: Array = []
	for item in CASES:
		var job: String=item[0]
		var sid: String=item[1]
		if not selected.is_empty() and sid not in selected:continue
		choose_job(job)
		_connect_player()
		player.enter_combat()
		player.cam_dist=9;player.cam_dist_target=9;player.cam_pitch=-.25
		player.cooldowns.clear();player.gcd=0;player.action_lock=0
		var sp:=DB.spell(sid,1)
		for key in player.gauge_costs(sp):
			player.gauges[key]=maxf(player.gauge(key),float(player.gauge_costs(sp)[key]))
		for key in sp.get("requires",{}).get("gauge_min",{}):
			player.gauges[key]=maxf(player.gauge(key),float(sp.requires.gauge_min[key]))
		for key in sp.get("requires",{}).get("gauge_max",{}):
			player.gauges[key]=minf(player.gauge(key),float(sp.requires.gauge_max[key]))
		var aura: String=sp.get("requires",{}).get("has_aura_self","")
		if aura!="":player.add_aura({"id":aura,"name":"画面检查前置","dur":30.0,"type":"buff"},player)
		player.set_target(patient if sp.get("target","")=="friend" else enemy)
		patient.hp=patient.max_hp*.5
		await get_tree().create_timer(.3).timeout
		var resolutions: Array=[]
		player.spell_resolved.connect(func(id,landed):resolutions.append({"skill":id,"landed":landed}))
		var validation:=player.check_cast(sp,player.target)
		var slot: int=Game.pd.bars.find({"t":"spell","id":sid})
		var key:=InputEventKey.new()
		key.keycode=Game.bar_keys[slot%12];key.shift_pressed=slot>=12;key.pressed=true
		Input.parse_input_event(key)
		await get_tree().process_frame
		key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
		var sample_times: Array=[]
		var captures: Array=[]
		var previous:=0.0
		for time in [.05,.15,.3,.5,.75,1.0,1.5,1.9]:
			await get_tree().create_timer(float(time)-previous).timeout
			previous=float(time)
			await RenderingServer.frame_post_draw
			var filename:=sid+"_%03d.png"%int(float(time)*100)
			get_viewport().get_texture().get_image().save_png(out+"/"+filename)
			sample_times.append(time);captures.append(filename)
		var live:=0
		if CombatPresentation.available():live=int(CombatPresentation._module._live_count())
		report.append({"job":job,"skill":sid,"bar_slot":slot,"validation":validation,"resolved":resolutions,"samples":captures,"seconds":sample_times,"fx_after_1_9s":live})
		print("SHOWCASE ",job," ",sid," slot=",slot)
	FileAccess.open(out+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":report,"fixture":"native keyboard input, seeded prerequisites, passive target"},"\t"))
	get_tree().quit()
