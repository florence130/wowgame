class_name DataCombatExpansion
extends RefCounted
## Codex integration/localization layer. Stable worker IDs remain intact.
const PATH := "res://data/combat_expansion.json"
const TEXT := {
	"pd_sweeping_oath":["誓约横扫","正面3.5码最多4个敌人受到16–22物理伤害，获得1神圣之力。需要盾牌；不产生誓约接续。群怪时取代部分誓约斩，单体积攒较慢。"],
	"pd_hallowed_verdict":["神圣裁决","消耗5神圣之力，对周围4.5码最多5个敌人造成30–38圣光伤害，并恢复自身5%生命。较长的起手和收招，适合留满量表后处理群怪。"],
	"pd_bastion_ward":["堡垒庇护","消耗2神圣之力，使8码内队友受到的伤害降低10%、移动速度降低12%，持续6秒。保护队伍会推迟下一次圣光冲击。"],
	"pd_rebuke":["盾缘斥断","打断3码内敌人的可打断施法，锁定该系法术3秒。需要盾牌，不产生神圣之力；留给危险读条。"],
	"bk_reaping_cleave":["收割横斩","正面3.5码最多5个敌人受到16–22物理伤害，获得8狂怒。不消耗也不触发血性接续；群怪收益更高，单体资源效率低于斩裂。"],
	"bk_blood_cyclone":["浴血旋风","消耗40狂怒，对周围4码最多5个敌人造成30–38物理伤害，获得5秒血性接续。比嗜血斩多消耗10狂怒，且没有吸血。"],
	"bk_grit":["咬牙坚守","消耗25狂怒，使自身受到的伤害降低25%，持续4秒。占用接近一次嗜血斩的资源，用于承受高压攻击。"],
	"bk_pummel":["碎咒拳","接触时打断敌人施法，锁定该系3秒，获得8狂怒。需要近身，前摇0.12秒；提前读懂敌人起手。"],
	"dm_blizzard_burst":["霜风爆裂","咏唱1.4秒，消耗10%法力，对目标周围4.5码最多5个敌人造成15–20冰霜伤害并减速20%，持续5秒。获得1冰印记，命中恢复4%法力。"],
	"dm_umbral_nova":["幽暗新星","消耗3余烬和10%法力，对目标周围4.5码最多5个敌人造成34–42暗影伤害，命中恢复4%法力。多目标释放；单体虚空脉冲更有效率。"],
	"dm_frost_ward":["凝霜护障","消耗2冰印记，获得相当于自身7%生命的护盾，持续6秒。防御会用掉原本可让两次火法加速30%的冰印记。"],
	"dm_scorch":["灼火烙印","移动中瞬发，消耗8%法力，造成10–14火焰伤害，随后8秒内每2秒造成5伤害。命中获得1余烬，不消耗冰印记。"],
	"el_riptide_ring":["回潮之环","消耗6%法力，咏唱0.9秒，使自身周围4.5码最多5个敌人受到15–19水伤害并浸水，获得2潮涌。需靠近敌群，不能代替远处的浪涌。"],
	"el_overload":["潮雷过载","消耗4潮涌和12%法力，咏唱1.5秒，造成74–88雷伤害；浸水目标额外受到25%伤害。获得回流水势，使下一发水弹加速50%。"],
	"el_static_snare":["缚潮电网","消耗1潮涌和5%法力，造成6–9雷伤害。已浸水的目标被定身2.5秒，否则减速25%、持续3秒；首领免疫定身。"],
	"el_sea_mist":["海雾同行","消耗1潮涌和3%法力，使10码内队友移速提高10%、受到伤害降低6%，持续6秒。用于转场和承伤，会减少输出可用潮涌。"],
	"wh_dawn_bloom":["拂晓水华","消耗2水华和10%法力，咏唱1.2秒，为10码内队友施加9秒祝福，每3秒恢复2%生命。每次有效治疗为施法者恢复0.6%法力；会推迟三水华的大治愈。"],
	"wh_sanctuary_veil":["圣域薄幕","消耗8%法力，使8码内队友获得相当于各自5%生命的护盾，持续6秒。不治疗、不产生水华，应在伤害到来前使用。"],
	"wh_sunlit_flash":["晨光急救","咏唱0.6秒、消耗10%法力，恢复友方9%生命。不产生水华；比清风疗愈更快，但法力效率更低。"],
	"wh_zephyr_hush":["止咒清风","消耗3%法力，打断24码内敌人的可打断施法，锁定该系3秒。用于提前避免伤害，需要兼顾队友的治疗。"],
	"cl_hammer_sweep":["双辉横锤","需要双手锤，对周围3.2码最多5个敌人造成15–20物理伤害，获得7光和7雷。群体建立仇恨；单体积攒少于双辉重击。"],
	"cl_thunder_nova":["轰雷圣环","消耗50光、50雷以及雷霆附魔，对周围4.5码最多5个敌人造成36–44雷伤害，获得6秒余光。比雷霆破击更耗量表，适合群怪。"],
	"cl_storm_ward":["雷铠坚守","消耗25雷，使自身受到伤害降低20%，持续4秒。只保护自己，保留光量表用于余光治疗或圣光守护。"],
	"cl_silencing_clap":["震锤封咒","消耗15光，打断5码内敌人的可打断施法，锁定该系3秒。进场前留下足够的光量表。"],
	"as_fan_of_knives":["淬毒飞刃","消耗35能量，使周围3.5码最多5个敌人受到15–20物理伤害并中毒，获得1连击点。毒每3秒造成4自然伤害；目标同时流血时，每跳为你恢复5能量。"],
	"as_hamstring":["断筋刃","消耗20能量，造成30%武器伤害加4，使目标减速30%、持续5秒，并获得1连击点。需要双匕首，用于追击脱离的目标。"],
	"as_evasive_veil":["影步薄幕","消耗20能量，使自身受到伤害降低20%、移速提高10%，持续4秒。防御会消耗本可用于积攒连击的能量。"],
	"as_kick":["断咒踢","消耗15能量，接触时打断敌人施法并锁定该系3秒，不产生连击点。需要双匕首；与原有脚踢共用冷却。"],
	"ms_crescent_flurry":["弦月连斩","细剑横扫正面3.2码最多4个敌人，造成15–20物理伤害，获得10共鸣。有暗刃时额外获得8共鸣并消耗暗刃；不会产生回响。"],
	"ms_counter_thrust":["刃反刺","举起细剑，在0.5秒内迎接正面近战攻击：挡下该次攻击、反击22–28伤害并获得15共鸣。普通敌人眩晕0.5秒；范围机制不能刃反。"],
	"ms_dusk_chain":["暮影连锁","消耗35共鸣，咏唱0.75秒，造成20–26暗影伤害，再向附近最多2个敌人连锁16–20伤害，每跳衰减30%。有回响时瞬发并消耗回响。"],
	"ms_disrupting_thrust":["截咒突刺","细剑接触时打断3码内敌人施法，锁定该系2.5秒并获得8共鸣。需要预留0.12秒前摇；与原有脚踢共用冷却。"],
	"cannon_suppressing_fire":["压制射击","消耗1发弹药，对目标周围4码最多5个敌人造成15–20物理伤害并减速25%、持续4秒，获得1瞄准。用于群体积攒与控制。"],
	"cannon_ricochet":["跳弹射击","消耗1发弹药和1瞄准，对首个目标造成45%远程武器伤害加6，再跳向附近最多2个敌人，每跳14–18伤害并衰减30%。会推迟二瞄准爆发。"],
	"cannon_brace":["架枪固守","消耗1发弹药，使自身受到伤害降低20%、移速降低40%，持续4秒。用弹仓容量换取站定承伤，危险范围仍需离开。"],
	"cannon_speed_load":["战术快装","消耗1瞄准，引导0.6秒后补入2发弹药，期间可按60%速度移动。弹仓不高于4发时可用；更快补弹会推迟瞄准爆发。"],
	"mech_flak_burst":["破片散射","外装甲下，对目标周围4码最多5个敌人造成18–24物理伤害，增加20热量。热量不高于78时可用，群攻会更快占满散热余量。"],
	"mech_coolant_spray":["冷却喷流","外装甲下，对正面5码最多5个敌人造成15–20冰霜伤害并减速25%、持续4秒，降低15热量。至少需要15热量；冷却量低于主动散热。"],
	"mech_shield_projector":["护盾投射","外装甲下，使6码内队友受到伤害降低10%，持续5秒，并增加16热量。热量不高于80时可用；防御同样会占用热量余量。"],
	"mech_static_pulse":["电磁截断","外装甲下，打断14码内敌人施法并锁定该系2.5秒，增加12热量。热量不高于85时可用，需为高热状态预留余量。"]
}

static func apply(spells: Dictionary, specs: Dictionary) -> void:
	if not FileAccess.file_exists(PATH):
		return
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var aura_names := {}
	_gather_names(spells, aura_names)
	for id in TEXT:
		aura_names[id] = TEXT[id][0]
	aura_names.merge({"dm_chilled":"霜寒", "el_static_drag":"电流迟滞", "cannon_suppressed":"火力压制", "mech_coolant":"冷却浸润", "mech_projector":"护盾投射"}, true)
	for id in package.get("patches", {}):
		# Preserve the original, working overdrive modifier. The exported draft
		# renamed it to an unsupported key; no numerical rebalance is intended.
		if id == "mech_overdrive":
			continue
		if spells.has(id):
			spells[id].merge(_adapt(package.patches[id], aura_names), true)
	for id in package.skills:
		var sp: Dictionary = _adapt(package.skills[id], aura_names)
		sp["name"] = TEXT[id][0]
		sp["desc"] = TEXT[id][1]
		sp["rotation_role"] = TEXT[id][1]
		if id == "ms_counter_thrust":
			sp.effects[0]["weapon"] = "rapier"
		spells[id] = sp
	for cls in specs:
		for job in specs[cls]:
			if package.jobs.has(job.id):
				var authored_order: Array = package.jobs[job.id].suggested_bar.duplicate()
				for id in job.grants:
					if not authored_order.has(id):
						authored_order.append(id)
				job.grants = authored_order
				for id in package.jobs[job.id].new_grants:
					if not job.grants.has(id):
						job.grants.append(id)

static func _gather_names(value: Variant, names: Dictionary) -> void:
	if value is Dictionary:
		if value.has("id") and value.has("dur") and value.has("name"):
			names[value.id] = value.name
		for v in value.values():
			_gather_names(v, names)
	elif value is Array:
		for v in value:
			_gather_names(v, names)

static func _adapt(value: Variant, names: Dictionary) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = Color(value[key]) if key == "color" and value[key] is String else _adapt(value[key], names)
		if result.has("dur") and result.has("id"):
			result["name"] = names.get(result.id, "战斗状态")
		return result
	if value is Array:
		var result: Array = []
		for v in value:
			result.append(_adapt(v, names))
		return result
	return value
