class_name DataJobSpells
extends RefCounted
## Authoritative advancement kits. IDs are stable for saves and action bars.

static func skill(n: String, job: String, school: String, target_: String, effects: Array, desc_: String, extra: Dictionary = {}) -> Dictionary:
	var cls: String = {"paladin": "warrior", "berserker": "warrior", "dark_mage": "mage", "elementalist": "mage", "radiant": "priest", "shadow_priest": "priest", "assassin": "rogue", "duelist": "rogue", "marksman": "gunner", "gadgeteer": "gunner"}[job]
	var sp := {"name": n, "class": cls, "requires_spec": job, "school": school, "target": target_, "icon": {"fire": "fireball", "frost": "frostbolt", "water": "renew", "lightning": "thunder_strike", "light": "holy", "shadow": "mind_blast", "wind": "wind"}.get(school, "slash"), "color": Color("d5b7ef"), "effects": effects, "desc": desc_, "rotation_role": desc_, "gcd": 0.85, "range": 2.4 if job in ["paladin", "berserker", "shadow_priest", "assassin", "duelist"] else 28.0, "cost": 0, "ranks": [{"lvl": 15}]}
	sp.merge(extra, true)
	if job in ["paladin", "berserker", "shadow_priest", "assassin", "duelist", "gadgeteer"]:
		sp["gcd"] = extra.get("gcd", 0.7)
	return sp

static func g(key: String, amount: float, when: Dictionary = {}) -> Dictionary:
	return {"type": "gauge", "gauge": key, "add": amount, "when": when}

static func buff(id: String, n: String, dur: float, mods: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var a := {"id": id, "name": n, "icon": "arcane_intellect", "dur": dur, "type": "buff", "mods": mods}
	a.merge(extra, true)
	return {"type": "self_aura", "aura": a}

static func consume(id: String) -> Dictionary:
	return {"type": "consume_aura", "id": id}

static func damage(lo: float, hi: float, coef: float = 0.3, extra: Dictionary = {}) -> Dictionary:
	var e := {"type": "damage", "min": lo, "max": hi, "coef": coef}
	e.merge(extra, true)
	return e

static func weapon(pct: float, bonus: float = 0, extra: Dictionary = {}) -> Dictionary:
	var e := {"type": "weapon", "pct": pct, "bonus": bonus}
	e.merge(extra, true)
	return e

static func cost(key: String, amount: float) -> Dictionary:
	return {"gauge": key, "amount": amount}

static func projectile(color: Color, speed: float = 34.0, size_: float = 0.14) -> Dictionary:
	return {"color": color, "speed": speed, "size": size_}

static func spells() -> Dictionary:
	var s := {}
	# Sword -> shield -> spender. Counters accelerate, rather than replace, this loop.
	s["pd_oath_cut"] = skill("誓约斩", "paladin", "physical", "enemy", [weapon(0.23, 4), g("holy_power", 1), buff("pd_oath", "誓约接续", 5)], "命中获得1神圣之力；5秒内下一次盾击额外获得1点。", {"requires": {"shield": true}, "windup": 0.16, "recovery": 0.24, "animation": "slash", "threat_bonus": 35})
	s["pd_shield_bash"] = skill("盾击", "paladin", "physical", "enemy", [weapon(0.29, 5), g("holy_power", 1), g("holy_power", 1, {"self_aura": "pd_oath"}), consume("pd_oath")], "命中获得1神圣之力；接誓约斩时获得2点。高仇恨，冷却3秒。", {"requires": {"shield": true}, "cd": 3.0, "windup": 0.18, "recovery": 0.26, "animation": "shield", "threat_bonus": 90})
	s["pd_radiant_strike"] = skill("圣光冲击", "paladin", "light", "enemy", [damage(36, 44, 0, {"ap_coef": 0.16, "bonus_when": {"self_aura": "pd_counter"}, "bonus_mul": 1.3}), buff("pd_resolve", "圣光坚守", 3, {"dmg_taken": -0.12}), consume("pd_counter")], "消耗3神圣之力，无额外冷却；获得3秒12%减伤。盾反成功后下一发增伤30%。", {"gauge_cost": cost("holy_power", 3), "windup": 0.2, "recovery": 0.24, "animation": "shield", "range": 12.0, "threat_bonus": 65})
	s["pd_riposte"] = skill("盾反", "paladin", "physical", "self", [{"type": "riposte", "window": 0.55, "min": 22, "max": 28, "stun": 0.8, "gauge": "holy_power", "gauge_add": 2}], "预判0.55秒内一次近战攻击：挡下、反击、获得2神圣之力并强化下一发圣光冲击。范围机制不能盾反。", {"requires": {"shield": true}, "cd": 8.0, "gcd": 0.0, "icon": "shield_wall"})
	s["pd_holy_bulwark"] = skill("圣盾", "paladin", "light", "self", [buff("pd_holy_bulwark", "圣盾", 5, {"dmg_taken": -0.3})], "5秒内减伤30%，冷却45秒。", {"requires": {"shield": true}, "cd": 45.0, "gcd": 0.0, "icon": "shield_wall"})
	s["pd_guard"] = skill("守护", "paladin", "light", "friend", [{"type": "guard", "pct": 0.25, "range": 12.0, "dur": 6.0}], "消耗1神圣之力，为12码内队友分担25%伤害，持续6秒。分担伤害由你承担。", {"gauge_cost": cost("holy_power", 1), "range": 12.0, "cd": 18.0, "gcd": 0.0, "icon": "taunt"})
	# Build -> bloodthirst -> empowered build. No duplicate rage/momentum pool.
	s["bk_rend_slash"] = skill("斩裂", "berserker", "physical", "enemy", [weapon(0.29, 5, {"bonus_when": {"self_aura": "bk_flow"}, "bonus_mul": 1.2}), g("fury", 12), g("fury", 6, {"self_aura": "bk_flow"}), consume("bk_flow")], "命中获得12狂怒。嗜血斩后的下一次斩裂增伤20%，额外获得6狂怒。", {"windup": 0.2, "recovery": 0.28, "animation": "slash"})
	s["bk_bloodthirst"] = skill("嗜血斩", "berserker", "physical", "enemy", [weapon(0.54, 8, {"lifesteal": 0.18}), buff("bk_flow", "血性接续", 5)], "消耗30狂怒，无额外冷却；实际伤害18%吸血，并强化下一次斩裂。", {"gauge_cost": cost("fury", 30), "windup": 0.24, "recovery": 0.3, "animation": "heavy"})
	s["bk_execute"] = skill("处决", "berserker", "physical", "enemy", [weapon(0.81, 10, {"execute_bonus_threshold": 0.3, "execute_multiplier": 1.3, "lifesteal": 0.25}), buff("bk_flow", "血性接续", 5)], "消耗50狂怒。目标低于30%生命增伤30%，实际伤害25%吸血；冷却12秒。", {"gauge_cost": cost("fury", 50), "cd": 12.0, "windup": 0.32, "recovery": 0.34, "animation": "heavy"})
	s["bk_frenzy"] = skill("狂乱", "berserker", "physical", "self", [buff("bk_frenzy", "狂乱", 8, {"attack_speed": 0.2, "skill_haste": 0.15, "dmg_taken": 0.1})], "8秒普攻加速20%、技能间隔缩短15%，受伤增加10%。不凭空生成狂怒。", {"cd": 40.0, "gcd": 0.0, "icon": "bloodrage"})
	s["bk_iron_charge"] = skill("铁血冲锋", "berserker", "physical", "enemy", [{"type": "charge", "max_distance": 8.0}], "最多8码重新接敌，不生成免费狂怒，无伤害免疫。", {"range": 8.0, "min_range": 3.0, "cd": 12.0, "gcd": 0.0, "icon": "charge"})
	# Ice buys fire casts one mark at a time; fire feeds the independent shadow release.
	s["dm_frost_spike"] = skill("霜刺", "dark_mage", "frost", "enemy", [damage(13, 17, 0.15), {"type": "energize", "pct": 0.28}, g("ice_mark", 2)], "咏唱1.25秒；命中恢复28%法力、获得2冰印记。冰系伤害较低。", {"cast": 1.25, "projectile": projectile(Color("89d4ef"))})
	s["dm_ice_lance"] = skill("冰枪", "dark_mage", "frost", "enemy", [damage(9, 13, 0.1), {"type": "energize", "pct": 0.08}, g("ice_mark", 1)], "移动填充，命中恢复8%法力、获得1冰印记。冷却8秒。", {"cd": 8.0, "projectile": projectile(Color("ade5fa"), 42)})
	var fire_speed := {"gauge": "ice_mark", "threshold": 1, "max": 0.3}
	s["dm_flame_bolt"] = skill("烈焰弹", "dark_mage", "fire", "enemy", [damage(48, 56, 0.45), g("ember", 1)], "消耗14%法力，咏唱1.65秒；有冰印记时快30%，只消耗1枚。命中获得1余烬。", {"cost_pct_max": 0.14, "cast": 1.65, "cast_by_gauge": fire_speed, "consume_gauge_amount": 1, "projectile": projectile(Color("f9a04b"))})
	s["dm_pyroblast"] = skill("炎爆", "dark_mage", "fire", "enemy", [damage(72, 84, 0.5), {"type": "aura", "aura": {"id": "dm_burn", "name": "灼烧", "icon": "fireball", "dur": 6.0, "type": "debuff", "tick": {"interval": 2.0, "dmg": 7, "school": "fire"}}}, g("ember", 1)], "消耗20%法力，咏唱2秒；1冰印记加速30%。附6秒灼烧，命中获得1余烬，冷却18秒。", {"cost_pct_max": 0.2, "cast": 2.0, "cd": 18.0, "cast_by_gauge": fire_speed, "consume_gauge_amount": 1, "projectile": projectile(Color("ff9b54"), 30, 0.2)})
	s["dm_firestorm"] = skill("焚风", "dark_mage", "fire", "enemy", [{"type": "aoe", "center": "target", "radius": 4.0, "min": 24, "max": 30, "coef": 0.25, "max_targets": 5}, g("ember", 1)], "消耗18%法力，咏唱1.6秒；1冰印记加速30%。4码范围最多5目标，只生成1余烬。", {"cost_pct_max": 0.18, "cast": 1.6, "cast_by_gauge": fire_speed, "consume_gauge_amount": 1})
	s["dm_shadow_bolt"] = skill("暗影箭", "dark_mage", "shadow", "enemy", [damage(18, 24, 0.2)], "消耗6%法力的移动填充；伤害低于火法，不抢冰印记或余烬。", {"cost_pct_max": 0.06, "projectile": projectile(Color("ab80cf"), 38)})
	s["dm_void_pulse"] = skill("虚空脉冲", "dark_mage", "shadow", "enemy", [damage(50, 60, 0.4), {"type": "energize", "pct": 0.06}], "消耗3余烬释放暗系爆发，命中恢复6%法力；不抢冰印记，冷却4秒。", {"gauge_cost": cost("ember", 3), "cd": 4.0, "projectile": projectile(Color("9c76c5"))})
	s["dm_soul_siphon"] = skill("灵魂榨取", "dark_mage", "shadow", "enemy", [damage(8, 12, 0.08), {"type": "energize", "pct": 0.07}], "应急引导3秒，每秒低伤害并恢复7%法力；不生成冰印记。", {"channel": 3.0, "ticks": 3, "cd": 16.0})
	# Wet -> consume tide with lightning -> quick water return.
	var wet := {"type": "aura", "aura": {"id": "el_wet", "name": "浸水", "icon": "renew", "dur": 8.0, "type": "debuff", "mods": {"speed": -0.15}}}
	s["el_water_bolt"] = skill("水弹", "elementalist", "water", "enemy", [damage(16, 20, 0.2), wet, g("tide", 1), g("tide", 1, {"self_aura": "el_return"}), {"type": "energize", "pct": 0.06}, consume("el_return")], "免费水法：回6%法力、获得1潮涌并浸水。雷法后的下一发快50%，获得2潮涌。", {"cast": 1.1, "cast_by_aura": {"id": "el_return", "mul": 0.5}, "projectile": projectile(Color("63c2db"))})
	var thunder := damage(30, 38, 0.3, {"bonus_when": {"target_aura": "el_wet"}, "bonus_mul": 1.25})
	s["el_lightning"] = skill("雷击", "elementalist", "lightning", "enemy", [thunder, buff("el_return", "回流水势", 5)], "消耗2潮涌及8%法力；对浸水目标增伤25%，强化下一发水弹。", {"gauge_cost": cost("tide", 2), "cost_pct_max": 0.08, "cast": 0.65})
	s["el_chain_lightning"] = skill("连锁闪电", "elementalist", "lightning", "enemy", [thunder.duplicate(true), {"type": "chain", "min": 24, "max": 30, "coef": 0.2, "jumps": 3, "radius": 6.0, "falloff": 0.25}, buff("el_return", "回流水势", 5)], "消耗2潮涌及10%法力，连锁最多3个额外目标，每跳衰减25%；强化下一发水弹。", {"gauge_cost": cost("tide", 2), "cost_pct_max": 0.1, "cast": 1.2})
	s["el_surge"] = skill("浪涌", "elementalist", "water", "enemy", [{"type": "aoe", "center": "target", "radius": 4.5, "min": 14, "max": 20, "coef": 0.15, "max_targets": 5, "aura": wet["aura"]}, g("tide", 1)], "为4.5码范围最多5目标浸水，获得1潮涌；准备连锁，冷却7秒。", {"cost_pct_max": 0.04, "cd": 7.0, "cast": 0.7})
	s["el_thunderstorm"] = skill("雷暴", "elementalist", "lightning", "enemy", [{"type": "aoe", "center": "target", "radius": 5.0, "min": 38, "max": 46, "coef": 0.3, "max_targets": 5}, buff("el_return", "回流水势", 5)], "消耗3潮涌及12%法力，5码雷暴；强化下一发水弹，冷却20秒。", {"gauge_cost": cost("tide", 3), "cost_pct_max": 0.12, "cast": 1.3, "cd": 20.0})
	s["el_tide_shield"] = skill("潮汐护盾", "elementalist", "water", "self", [buff("el_tide_shield", "潮汐护盾", 6, {}, {"absorb_pct": 0.08})], "消耗2潮涌获得8%生命护盾，持续6秒；保命占用输出资源，冷却20秒。", {"gauge_cost": cost("tide", 2), "cd": 20.0, "gcd": 0.0, "icon": "pwshield"})
	s["el_holy_beam"] = skill("圣光束", "elementalist", "light", "friend", [{"type": "heal_pct", "pct": 0.08}], "消耗8%法力，咏唱1.4秒，恢复友方8%生命。", {"cost_pct_max": 0.08, "cast": 1.4, "cd": 10.0, "range": 24.0, "vfx": "heal"})
	s["el_cleanse"] = skill("净化之光", "elementalist", "light", "friend", [{"type": "dispel_debuff", "count": 1}], "消耗4%法力，驱散一个可驱散减益。", {"cost_pct_max": 0.04, "cd": 12.0, "range": 24.0})
	# Water maintenance -> effective wind healing -> water blooms -> efficient light recovery.
	s["wh_water_blessing"] = skill("潮汐祝福", "radiant", "water", "friend", [g("bloom", 1, {"no_target_aura": "wh_water_blessing"}), {"type": "aura", "aura": {"id": "wh_water_blessing", "name": "潮汐祝福", "icon": "renew", "dur": 12.0, "type": "buff", "tick": {"interval": 3.0, "heal_pct": 0.025, "caster_power_pct_on_heal": 0.008}}}], "耗4%法力，12秒持续恢复；首次给予祝福获1水华。有效HoT每跳为施法者回0.8%法力；提前刷新不刷资源。", {"cost_pct_max": 0.04, "range": 24.0})
	s["wh_wind_mend"] = skill("清风疗愈", "radiant", "wind", "friend", [{"type": "heal_pct", "pct": 0.1, "bonus_when": {"target_aura": "wh_water_blessing"}, "bonus_mul": 1.25}, g("bloom", 1, {"effective_heal": true})], "耗4%法力，咏唱1.1秒治疗10%生命；潮汐祝福提高治疗25%。有效治疗获得1水华，过量治疗不生成。", {"cost_pct_max": 0.04, "cast": 1.1, "range": 24.0, "vfx": "heal"})
	s["wh_pure_light"] = skill("圣光大治愈", "radiant", "light", "friend", [{"type": "heal_pct", "pct": 0.23}, g("bloom", -3, {"gauge_min": {"bloom": 3}})], "通常耗8%法力、咏唱2.1秒。3水华时免费、咏唱1.05秒并消耗3水华，治疗23%生命。", {"cost_pct_max": 0.08, "cost_by_gauge": {"gauge": "bloom", "threshold": 3, "mul": 0.0}, "cast": 2.1, "cast_by_gauge": {"gauge": "bloom", "threshold": 3, "max": 0.5}, "consume_gauge_on_cast": false, "range": 24.0, "vfx": "heal"})
	s["wh_luminous_wave"] = skill("光辉庇护", "radiant", "light", "friend", [{"type": "heal_pct", "pct": 0.04}, {"type": "aura", "aura": {"id": "wh_luminous_wave", "name": "光辉庇护", "icon": "pwshield", "dur": 6.0, "type": "buff", "absorb_pct": 0.1}}], "消耗1水华及3%法力，治疗4%生命并给予10%生命护盾，冷却14秒。", {"gauge_cost": cost("bloom", 1), "cost_pct_max": 0.03, "range": 24.0, "cd": 14.0, "vfx": "heal"})
	s["wh_gale"] = skill("风刃", "radiant", "wind", "enemy", [damage(14, 18, 0.15), {"type": "energize", "pct": 0.04}], "治疗空档的低伤害攻击，命中回4%法力；不生成水华。", {"cast": 0.85})
	s["wh_wind_step"] = skill("疾风术", "radiant", "wind", "self", [{"type": "party_aura", "radius": 12.0, "aura": {"id": "wh_wind_step", "name": "疾风术", "icon": "sprint", "dur": 5.0, "type": "buff", "mods": {"speed": 0.15}}}], "附近队友移速提高15%，持续5秒。", {"cd": 25.0, "gcd": 0.0, "cost_pct_max": 0.02})
	s["wh_cleanse"] = skill("澄净水流", "radiant", "water", "friend", [{"type": "dispel_debuff", "count": 1}], "耗3%法力，驱散一个可驱散减益。", {"cost_pct_max": 0.03, "cd": 8.0, "range": 24.0})
	# Dual build -> bolt enchant -> balanced release -> choose one free light payoff.
	var hammer := {"weapon": "mace2"}
	s["cl_holy_mace"] = skill("双辉重击", "shadow_priest", "physical", "enemy", [weapon(0.25, 4), g("light", 12), g("bolt", 12)], "同时积攒12光、12雷；专注时对应量表额外增加6。", {"requires": hammer, "windup": 0.22, "recovery": 0.28, "animation": "hammer", "threat_bonus": 55})
	s["cl_thunder_brand"] = skill("雷霆附魔", "shadow_priest", "lightning", "self", [buff("cl_thunder_brand", "雷霆附魔", 12, {}, {"enchant": {"school": "lightning", "min": 3, "max": 5, "ap_coef": 0.03, "interval": 1.0}})], "消耗20雷，12秒锤击附雷伤并解锁雷鸣破击；已有附魔不能重复施放。", {"gauge_cost": cost("bolt", 20), "requires": {"weapon": "mace2", "no_aura_self": "cl_thunder_brand"}, "gcd": 0.0})
	s["cl_lightning_smash"] = skill("雷鸣破击", "shadow_priest", "lightning", "enemy", [damage(48, 58, 0, {"ap_coef": 0.2}), buff("cl_afterglow", "双辉余光", 6), consume("cl_thunder_brand")], "附魔后消耗40光和40雷释放雷击；解锁一次免费光治疗或壁垒，无额外冷却。", {"gauge_costs": {"light": 40, "bolt": 40}, "requires": {"weapon": "mace2", "has_aura_self": "cl_thunder_brand"}, "windup": 0.3, "recovery": 0.32, "animation": "hammer", "threat_bonus": 85})
	s["cl_light_guard"] = skill("辉光壁垒", "shadow_priest", "light", "self", [buff("cl_light_guard", "辉光壁垒", 4, {"dmg_taken": -0.15}), {"type": "party_aura", "radius": 6.0, "aura": {"id": "cl_party_guard", "name": "辉光庇护", "icon": "pwshield", "dur": 4.0, "type": "buff", "absorb_pct": 0.035}}, consume("cl_afterglow")], "消耗30光，4秒自身减伤15%、附近队友3.5%生命护盾；双辉余光时免费并消耗余光。", {"gauge_cost": cost("light", 30), "gauge_cost_by_aura": "cl_afterglow", "cd": 4.0, "gcd": 0.0})
	s["cl_radiant_mend"] = skill("圣辉修复", "shadow_priest", "light", "friend", [{"type": "heal_pct", "pct": 0.12}, consume("cl_afterglow")], "消耗30光恢复友方12%生命；双辉余光时免费并消耗余光，与壁垒二选一。", {"gauge_cost": cost("light", 30), "gauge_cost_by_aura": "cl_afterglow", "cd": 4.0, "range": 18.0, "vfx": "heal"})
	s["cl_gauge_exchange"] = skill("双辉调律", "shadow_priest", "light", "self", [{"type": "gauge_balance", "a": "light", "b": "bolt", "pct": 0.5}], "将高量表的差额一半转给低量表，总量守恒，弥补光防护或雷附魔造成的失衡。", {"cd": 6.0, "gcd": 0.0})
	s["cl_light_focus"] = skill("光辉专注", "shadow_priest", "light", "self", [buff("cl_light_focus", "光辉专注", 6, {}, {"gauge_bonus": {"light": 6}})], "6秒内锤击多生成6光；与雷专注互斥，用于额外治疗压力。", {"cd": 12.0, "gcd": 0.0, "remove_aura_on_cast": "cl_bolt_focus"})
	s["cl_bolt_focus"] = skill("雷霆专注", "shadow_priest", "lightning", "self", [buff("cl_bolt_focus", "雷霆专注", 6, {}, {"gauge_bonus": {"bolt": 6}})], "6秒内锤击多生成6雷；与光专注互斥，用于补附魔消耗。", {"cd": 12.0, "gcd": 0.0, "remove_aura_on_cast": "cl_light_focus"})
	s["cl_provoke"] = skill("誓约挑衅", "shadow_priest", "light", "enemy", [{"type": "taunt"}], "迫使敌人转向你，不打断首领技能。", {"range": 18.0, "cd": 8.0, "gcd": 0.0, "icon": "taunt"})
	# Bleed enables poison energy return; poison finisher accelerates the next builder.
	var knives := {"weapon": "dagger", "dual_daggers": true}
	s["as_venomous_cut"] = skill("淬毒双刺", "assassin", "physical", "enemy", [weapon(0.65, 6), {"type": "combo", "n": 1}, {"type": "combo", "n": 1, "when": {"self_aura": "as_edge"}}, {"type": "aura", "aura": {"id": "as_poison", "name": "淬毒", "icon": "poison", "dur": 12.0, "type": "debuff", "dispel": true, "tick": {"interval": 3.0, "dmg": 4, "school": "nature", "caster_energy": 5, "requires_aura": "as_bleed"}}}, consume("as_edge")], "耗20能量，命中+1连击并维持毒。毒跳伤时目标流血则回5能量；毒刃终结后下一击+2连击。", {"requires": knives, "cost": 20, "windup": 0.12, "recovery": 0.2, "animation": "dual"})
	s["as_backstab"] = skill("伏击", "assassin", "physical", "enemy", [weapon(0.8, 10, {"bonus_when": {"behind_or_stealth": true}, "bonus_mul": 1.25}), {"type": "combo", "n": 2}], "耗25能量，命中+2连击；背后或潜行增伤25%。正面仍可施放，冷却5秒。", {"requires": knives, "cost": 25, "cd": 5.0, "windup": 0.14, "recovery": 0.22, "animation": "dual"})
	s["as_death_mark"] = skill("绞杀印记", "assassin", "physical", "enemy", [{"type": "finisher_aura_scaled", "durations": [9, 12, 15, 18, 21], "damages": [3, 4, 5, 6, 7], "aura_base": {"id": "as_bleed", "name": "绞杀出血", "icon": "rupture", "type": "debuff", "tick": {"interval": 3.0, "dmg": 3, "school": "physical"}}}], "耗25能量及连击，施加9–21秒出血，让淬毒跳伤返还能量；适合4–5连击维护。", {"requires": {"combo": true, "weapon": "dagger", "dual_daggers": true}, "cost": 25, "windup": 0.14, "recovery": 0.22, "animation": "dual"})
	s["as_envenom"] = skill("毒刃终结", "assassin", "nature", "enemy", [{"type": "finisher_damage", "spell": true, "per_cp": [[8, 10], [16, 20], [24, 30], [32, 40], [40, 50]], "ap_per_cp": 0.015, "bonus_when": {"target_aura": "as_poison"}, "bonus_mul": 1.25}, buff("as_edge", "毒刃接续", 5)], "耗25能量及连击，造成毒属性终结伤害；中毒目标增伤25%，强化下一次双刺的连击生成。", {"requires": {"combo": true, "weapon": "dagger", "dual_daggers": true}, "cost": 25, "windup": 0.18, "recovery": 0.22, "animation": "dual"})
	s["as_shadow_step"] = skill("影步", "assassin", "shadow", "enemy", [{"type": "teleport_behind", "max_distance": 6.0}], "沿可通行路径接近目标背后，最多6码，无无敌帧。", {"range": 6.0, "cd": 14.0, "cost": 10, "gcd": 0.0, "icon": "shadow_strike"})
	# One resonance budget; magic and rapier return each other's tempo.
	var rapier := {"weapon": "rapier"}
	s["ms_arcane_edge"] = skill("无相刺击", "duelist", "physical", "enemy", [weapon(0.29, 4, {"bonus_when": {"self_aura": "ms_shadow_edge"}, "bonus_mul": 1.35}), g("resonance", 10), {"type": "self_aura", "when": {"self_aura": "ms_shadow_edge"}, "aura": {"id": "ms_echo", "name": "剑鸣回响", "icon": "slash", "dur": 5.0, "type": "buff"}}, consume("ms_shadow_edge")], "命中获10共鸣。接暗影矢增伤35%，并使下一发暗影矢瞬发。", {"requires": rapier, "windup": 0.14, "recovery": 0.2, "animation": "thrust"})
	s["ms_shadow_bolt"] = skill("暗影矢", "duelist", "shadow", "enemy", [damage(16, 22, 0, {"ap_coef": 0.12}), g("resonance", 20), buff("ms_shadow_edge", "暗刃接续", 5), consume("ms_echo")], "免费咏唱0.75秒，命中获20共鸣并强化刺击；剑鸣回响时瞬发。", {"requires": rapier, "cast": 0.75, "cast_by_aura": {"id": "ms_echo", "mul": 0.0}, "range": 16.0, "projectile": projectile(Color("aa86cc"))})
	s["ms_unbound"] = skill("无相贯穿", "duelist", "neutral", "enemy", [damage(54, 64, 0, {"ap_coef": 0.18}), buff("ms_echo", "剑鸣回响", 5)], "消耗60共鸣，0.3秒蓄力，无额外冷却；下一发暗影矢瞬发。两个魔法→刺击往返可攒一次。", {"requires": rapier, "gauge_cost": cost("resonance", 60), "windup": 0.3, "recovery": 0.26, "animation": "thrust", "range": 5.0})
	s["ms_spellblade"] = skill("暗刃附魔", "duelist", "shadow", "self", [buff("ms_spellblade", "暗刃附魔", 6, {}, {"enchant": {"school": "shadow", "min": 3, "max": 5, "ap_coef": 0.025, "interval": 0.85}})], "至少30共鸣可用，但不消耗共鸣；6秒细剑附暗伤，冷却18秒。", {"requires": {"weapon": "rapier", "gauge_min": {"resonance": 30}}, "cd": 18.0, "gcd": 0.0})
	s["ms_phase_lunge"] = skill("掠影突刺", "duelist", "neutral", "enemy", [{"type": "charge", "max_distance": 6.0}], "最多6码接敌，无免费共鸣或无敌帧。", {"requires": rapier, "range": 6.0, "min_range": 3.0, "cd": 12.0, "gcd": 0.0, "icon": "charge"})
	# Six-round magazine + two aim marks; autos cannot bypass ammo costs.
	var gun := {"ranged_weapon": true}
	var bullet := projectile(Color("ffe0a0"), 60, 0.06)
	bullet["kind"] = "bullet"
	s["cannon_steady"] = skill("步枪点射", "marksman", "physical", "enemy", [{"type": "ranged", "pct": 0.6, "bonus": 7, "rap_coef": 0.06, "bonus_when": {"self_aura": "cannon_breach"}, "bonus_mul": 1.2}, g("aim", 1), consume("cannon_breach")], "消耗1发，命中获1瞄准（最多2）。接手炮后的下一发增伤20%，不用法力。", {"requires": gun, "gauge_cost": cost("ammo", 1), "windup": 0.18, "recovery": 0.18, "animation": "rifle", "projectile": bullet})
	s["cannon_burst"] = skill("远距手炮", "marksman", "physical", "enemy", [{"type": "ranged", "pct": 1.25, "bonus": 22, "rap_coef": 0.12}, buff("cannon_breach", "破甲弹道", 5)], "消耗2发及2瞄准，无额外冷却；单体重击并强化下一次步枪点射。", {"requires": gun, "gauge_costs": {"ammo": 2, "aim": 2}, "range": 30.0, "windup": 0.28, "recovery": 0.3, "animation": "cannon", "projectile": bullet.duplicate(true)})
	s["cannon_barrage"] = skill("榴弹齐射", "marksman", "physical", "enemy", [{"type": "aoe", "center": "target", "radius": 4.0, "min": 22, "max": 28, "rap_coef": 0.08, "max_targets": 5}], "消耗2发及2瞄准，4码物理爆炸；群怪时替代手炮，无额外冷却。", {"requires": gun, "gauge_costs": {"ammo": 2, "aim": 2}, "windup": 0.26, "recovery": 0.28, "animation": "cannon"})
	s["cannon_shotgun"] = skill("霰弹扇扫", "marksman", "physical", "none", [{"type": "aoe", "radius": 5.0, "frontal": true, "min": 12, "max": 18, "rap_coef": 0.05, "max_targets": 4}, g("aim", 1)], "消耗1发，前方5码扇形霰弹；命中至少一敌获1瞄准，冷却3秒。", {"requires": gun, "gauge_cost": cost("ammo", 1), "cd": 3.0, "windup": 0.12, "recovery": 0.24, "animation": "shotgun"})
	s["cannon_reload"] = skill("战术换弹", "marksman", "physical", "self", [g("ammo", 3)], "引导1.2秒，0.6秒和1.2秒各装3发；可缓慢移动。中断保留已装弹药，瞄准不清空。", {"requires": {"ranged_weapon": true, "gauge_max": {"ammo": 5}}, "channel": 1.2, "ticks": 2, "move_cast": true, "move_cast_speed": 0.6, "animation": "reload", "icon": "steady_shot"})
	s["cannon_recoil"] = skill("战术后撤", "marksman", "physical", "self", [{"type": "leap_back", "dist": 4.0}], "消耗20耐力沿地面后撤4码，无伤害免疫。", {"cd": 16.0, "gcd": 0.0, "cost": {"stamina": 20}, "icon": "recoil_jump"})
	# No passive combat cooling: high heat strengthens weapons, rail releases heat.
	s["mech_armor"] = skill("外装甲展开", "gadgeteer", "neutral", "self", [buff("mech_armor", "外装甲", 0, {"dmg_taken": -0.06}, {"toggle": true})], "展开/收起外装甲，减伤6%，解锁机甲攻击；不携带机械生物。", {"cd": 3.0, "gcd": 0.0, "icon": "pwshield"})
	s["mech_piston"] = skill("活塞重拳", "gadgeteer", "physical", "enemy", [damage(16, 20, 0, {"ap_coef": 0.11, "bonus_when": {"gauge_min": {"heat": 50}}, "bonus_mul": 1.2}), g("heat", 18), damage(6, 8, 0, {"when": {"self_aura": "mech_cooled"}}), consume("mech_cooled")], "命中增加18热；50热以上增伤20%。贯击后下一拳附小冲击。", {"requires": {"has_aura_self": "mech_armor", "gauge_max": {"heat": 82}}, "range": 2.4, "windup": 0.2, "recovery": 0.24, "animation": "piston"})
	s["mech_rocket"] = skill("肩载魔导弹", "gadgeteer", "neutral", "enemy", [damage(22, 28, 0, {"rap_coef": 0.09, "bonus_when": {"gauge_min": {"heat": 50}}, "bonus_mul": 1.2}), g("heat", 24)], "命中增加24热；50热以上增伤20%。远处接续单体输出，冷却4秒。", {"requires": {"has_aura_self": "mech_armor", "gauge_max": {"heat": 76}}, "range": 16.0, "cd": 4.0, "windup": 0.16, "recovery": 0.24, "animation": "rocket", "projectile": projectile(Color("a1d7ec"), 35)})
	s["mech_rail"] = skill("魔导贯击", "gadgeteer", "neutral", "enemy", [damage(44, 54, 0, {"rap_coef": 0.15}), buff("mech_cooled", "冷却回压", 5)], "至少60热时蓄力0.5秒，排60热释放贯击，强化下一拳；无额外冷却。", {"requires": {"has_aura_self": "mech_armor"}, "gauge_cost": cost("heat", 60), "range": 12.0, "windup": 0.5, "recovery": 0.28, "animation": "rail"})
	s["mech_overdrive"] = skill("外骨骼超频", "gadgeteer", "neutral", "self", [buff("mech_overdrive", "外骨骼超频", 6, {"dmg_done": 0.15, "dmg_taken": 0.08}), g("heat", 15)], "40–85热时增加15热，6秒伤害提高15%、受伤增加8%；推入高热后需安排贯击。", {"requires": {"has_aura_self": "mech_armor", "gauge_min": {"heat": 40}, "gauge_max": {"heat": 85}}, "cd": 24.0, "gcd": 0.0, "icon": "bloodrage"})
	s["mech_vent"] = skill("紧急散热", "gadgeteer", "neutral", "self", [g("heat", -30)], "20热以上引导1.2秒，每0.6秒排30热；可缓慢移动。无法接敌时恢复，损失输出时间。", {"requires": {"has_aura_self": "mech_armor", "gauge_min": {"heat": 20}}, "channel": 1.2, "ticks": 2, "move_cast": true, "move_cast_speed": 0.6, "icon": "frost"})
	var icons := {"pd_oath_cut": "heroic_strike", "pd_shield_bash": "shield_wall", "pd_radiant_strike": "heroic_strike", "bk_bloodthirst": "mortal_strike", "bk_execute": "execute_slash", "cl_holy_mace": "mortal_strike", "as_venomous_cut": "poison", "as_backstab": "mutilate", "as_death_mark": "rupture", "as_envenom": "eviscerate", "ms_unbound": "arcane_barrage", "cannon_steady": "steady_shot", "cannon_burst": "aether_shot", "cannon_barrage": "scatter_volley", "cannon_shotgun": "scatter_volley", "mech_piston": "mortal_strike", "mech_rocket": "aether_shot", "mech_rail": "arcane_barrage"}
	for sid in icons: s[sid]["icon"] = icons[sid]
	return s
