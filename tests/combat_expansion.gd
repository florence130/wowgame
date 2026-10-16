extends "res://tests/job_combat.gd"
## Isolated native casts. Resources/aura prerequisites are explicit fixtures;
## these are mechanism checks, not a claim of a sustained player rotation.

func prepare(sp: Dictionary) -> void:
	ready()
	p.hp=p.max_hp*.5
	for key in p.gauge_costs(sp):
		p.gauges[key]=maxf(p.gauge(key),float(p.gauge_costs(sp)[key]))
	for key in sp.get("requires",{}).get("gauge_min",{}):
		p.gauges[key]=maxf(p.gauge(key),float(sp.requires.gauge_min[key]))
	for key in sp.get("requires",{}).get("gauge_max",{}):
		p.gauges[key]=minf(p.gauge(key),float(sp.requires.gauge_max[key]))
	var requirement: String=sp.get("requires",{}).get("has_aura_self","")
	if requirement != "":
		p.add_aura({"id":requirement,"name":"Fixture prerequisite","dur":30.0,"type":"buff"},p)
	if p.is_interrupt_skill(sp):
		d.stop_cast()
		d.gcd=0;d.action_lock=0;d.cooldowns.clear()
		d.begin_cast({"id":"fixture_danger","name":"Fixture dangerous cast","school":"shadow","cast":4.0,"target":"enemy","range":30.0,"gcd":0.0,"effects":[{"type":"damage","min":30,"max":30}]},p)

func run() -> void:
	out="res://.local/gameplay_world_20261016/expansion"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	seed(851)
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DataCombatExpansion.PATH))
	check(catalog.skills.size()==40,"forty new active skills in current package")
	var kit_total:=0
	for sid in DB.spells:
		if DB.spells[sid].has("requires_spec"):kit_total+=1
	check(kit_total==105,"advancement catalog expanded from 65 to 105")
	for job in catalog.jobs:
		var sd: Dictionary=DB.spec_index[job]
		check(catalog.jobs[job].new_grants.size()==4,job+" has four new skills")
		for sid in catalog.jobs[job].new_grants:
			var observed:=false
			var sp: Dictionary
			for attempt in 8:
				fixture(sd["class"],job)
				sp=DB.spell(sid,1)
				prepare(sp)
				var before_hp:=d.hp
				var before_self:=p.hp
				var gauges_before:=p.gauges.duplicate()
				var started:=await cast(sid)
				observed=started and (d.hp<before_hp or p.hp>before_self or p.gauges!=gauges_before)
				for effect in sp.effects:
					if effect.type in ["self_aura","party_aura"]:
						observed=observed or (started and not p.get_aura(effect.aura.id).is_empty())
					if effect.type=="interrupt":
						observed=started and not d.is_casting()
					if effect.type=="riposte":
						var hp_before:=p.hp
						var resonance:=p.gauge("resonance")
						d.face_towards(p.global_position)
						d.deal_melee_damage(p,40,"Fixture melee")
						observed=started and p.hp==hp_before and p.gauge("resonance")==resonance+15
				if observed:break
			check(observed,sid+" native cast produces an observable effect")
			check(Game.spell_rank(sid)==1 and Game.pd.bars.has({"t":"spell","id":sid}),sid+" learned and placed on a real action bar")
			check(sp.name==DataCombatExpansion.TEXT[sid][0] and sp.desc==DataCombatExpansion.TEXT[sid][1],sid+" production text migrated")
	fixture("rogue","assassin")
	var interrupt:=DB.spell("as_kick",1)
	prepare(interrupt)
	await cast("as_kick")
	check(p.cooldown_remaining(DB.spell("kick",1))>0,"new and inherited rogue interrupts share a cooldown")
	fixture("mage","dark_mage")
	p.gauges["ice_mark"]=2
	var normal: float=DB.spell("dm_flame_bolt",1).cast
	var faster:=p.cast_time(DB.spell("dm_flame_bolt",1))
	check(is_equal_approx(faster,normal*.7),"ice marks shorten fire cast by thirty percent, not to 0.3 seconds")
	fixture("priest","radiant")
	p.power=p.max_power*.3
	p.hp=p.max_hp*.5
	var mana_before:=p.power
	var hp_before:=p.hp
	p.add_aura(DB.spell("wh_dawn_bloom",1).effects[0].aura,p)
	p._tick_auras(3.1)
	check(p.hp>hp_before and p.power>mana_before,"Dawn Bloom heals and returns mana on an effective tick")
	p.hp=p.max_hp
	mana_before=p.power
	p._tick_auras(3.1)
	check(p.power==mana_before,"overhealing Dawn Bloom does not return mana")
	FileAccess.open(out+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"fixture":"isolated native casts with explicitly seeded prerequisites"},"\t"))
	print("EXPANSION RESULT checks=",checks.size()," failed=",failed)
	get_tree().quit(1 if failed else 0)
