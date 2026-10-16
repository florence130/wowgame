class_name DataSpecs
extends RefCounted
## 15 级转职数据（取代旧天赋系统 data_talents.gd）。
## 每个基础职业在 15 级选择一个转职；转职授予：
##   grants   主动技能（进技能书并自动上动作条，需 requires_spec 才能使用）
##   passives 被动技能：永久生效的数值，字段与旧天赋效果键一致（stats / stats_pct / school_dmg / cost_pct / cd_pct /
##            dot_pct / heal_pct / cast_pct / dur_pct / dmg_taken / threat / speed / ranged_dmg / hp_pct / regen / haste）
##   traits   特性：改变技能行为或带触发条件，见 src/core/specs.gd::trait_active
## 技能 id 必须存在于 data_spells.gd，转职专属技能带 "requires_spec": <转职 id>。

const CHOOSE_LEVEL := 15

static func specs() -> Dictionary:
	return {
		"warrior": [
			{"id": "paladin", "name": "圣骑士", "color": Color("f0d890"), "icon": "shield_wall",
				"desc": "誓约斩接盾击积攒神圣之力，圣光冲击消耗并提供短防护；预判盾反加速循环，守护队友会占用神圣之力。",
				"role": "近战 · 坦克",
				"grants": ["pd_oath_cut", "pd_shield_bash", "pd_radiant_strike", "pd_riposte", "pd_holy_bulwark", "pd_guard"],
				"passives": [
					{"id": "bw_toughness", "name": "钢铁之躯", "desc": "生命值上限提高10%。", "hp_pct": 0.10},
					{"id": "bw_shield_training", "name": "护甲训练", "desc": "护甲提高15%。", "stats_pct": {"armor": 0.15}},
					{"id": "bw_threat", "name": "仇恨掌控", "desc": "造成的威胁值提高25%。", "threat": 0.25},
				],
				"traits": [
					{"id": "bw_last_stand", "name": "背水一战", "desc": "生命低于35%时，受到的伤害降低15%。",
						"trigger": "self_hp_below", "value": 0.35, "mods": {"dmg_taken": -0.15}},
				]},
			{"id": "berserker", "name": "狂战士", "color": Color("d02020"), "icon": "reckless_fury",
				"desc": "斩裂积攒狂怒，嗜血斩消耗并强化下一次斩裂；用狂乱加速循环，留怒气用于低血处决。",
				"role": "近战 · 单体爆发",
				"grants": ["bk_rend_slash", "bk_bloodthirst", "bk_frenzy", "bk_execute", "bk_iron_charge"],
				"passives": [
					{"id": "bk_bloodlust", "name": "嗜血", "desc": "攻击速度提高10%。", "haste": 0.10},
					{"id": "bk_reckless", "name": "鲁莽", "desc": "受到的伤害提高5%。", "dmg_taken": 0.05},
				],
				"traits": [
					{"id": "bk_enrage", "name": "狂怒", "desc": "生命低于40%时，物理伤害提高25%。",
						"trigger": "self_hp_below", "value": 0.4, "mods": {"school_dmg": {"physical": 0.25}}},
				]},
		],
		"mage": [
			{"id": "elementalist", "name": "元素法师", "color": Color("78dbd5"), "icon": "arcane_barrage",
				"desc": "水法浸水并积攒潮涌，雷法消耗潮涌并强化下一发水法；单体与连锁共用水雷回路，护盾占用潮涌。",
				"role": "远程 · 控制 / 元素输出",
				"schools": ["water", "lightning", "light"],
				"grants": ["el_water_bolt", "el_tide_shield", "el_surge", "el_lightning", "el_chain_lightning", "el_thunderstorm", "el_holy_beam", "el_cleanse"],
				"passives": [
					{"id": "el_attunement", "name": "元素共鸣", "desc": "水、雷、光系伤害各提高6%。",
						"school_dmg": {"water": 0.06, "lightning": 0.06, "light": 0.06}},
					{"id": "el_flow", "name": "灵动", "desc": "法力回复速度提高20%。", "regen": 0.20},
				],
				"traits": [
					{"id": "el_tidal_ward", "name": "潮涌庇护", "desc": "每层潮涌使受到的伤害降低2%，最多降低10%。",
						"taken_per_gauge": {"gauge": "tide", "per": -0.02, "max": -0.10}},
				]},
			{"id": "dark_mage", "name": "黑魔法师", "color": Color("b060ff"), "icon": "pyroblast",
				"desc": "霜刺回蓝并准备两枚冰印记，逐枚加速火法；火法积攒余烬供暗系爆发，暗影箭用于移动填充。",
				"role": "远程 · 持续伤害 / 爆发",
				"schools": ["fire", "frost", "shadow"],
				"grants": ["dm_frost_spike", "dm_ice_lance", "dm_flame_bolt", "dm_pyroblast", "dm_firestorm", "dm_shadow_bolt", "dm_void_pulse", "dm_soul_siphon"],
				"passives": [
					{"id": "dm_forbidden", "name": "禁忌知识", "desc": "火焰、冰霜、暗影伤害各提高6%。",
						"school_dmg": {"fire": 0.06, "frost": 0.06, "shadow": 0.06}},
					{"id": "dm_corrosion", "name": "侵蚀", "desc": "持续伤害提高20%。", "dot_pct": 0.20},
				],
				"traits": [
					{"id": "dm_siphon", "name": "汲取", "desc": "目标生命低于30%时，暗影与火焰伤害额外提高15%。",
						"trigger": "target_hp_below", "value": 0.3, "mods": {"school_dmg": {"shadow": 0.15, "fire": 0.15}}},
				]},
		],
		"priest": [
			{"id": "radiant", "name": "白魔法师", "color": Color("ffe080"), "icon": "flash_heal",
				"desc": "水祝福维持持续治疗，强化风治疗；有效风治疗生成水华，三水华换取免费快速圣光，或保留一水华应对护盾需求。",
				"role": "治疗",
				"grants": ["wh_wind_mend", "wh_water_blessing", "wh_luminous_wave", "wh_pure_light", "wh_wind_step", "wh_cleanse", "wh_gale"],
				"passives": [
					{"id": "rd_healing", "name": "圣光祝福", "desc": "治疗效果提高12%。", "heal_pct": 0.12},
					{"id": "rd_focus", "name": "祈祷专注", "desc": "施法速度提高6%。", "cast_pct": 0.06},
				],
				"traits": []},
			{"id": "shadow_priest", "name": "圣职者", "color": Color("edcc80"), "icon": "thunder_strike",
				"desc": "双手锤积攒光雷双量表，雷附魔后用双辉破击收束，余光在治疗和壁垒中二选一；专注与调律处理失衡。",
				"role": "近战 · 双量表坦克", "weapons": ["mace2"], "armor": ["mail"],
				"grants": ["cl_holy_mace", "cl_light_guard", "cl_thunder_brand", "cl_radiant_mend", "cl_lightning_smash", "cl_gauge_exchange", "cl_light_focus", "cl_bolt_focus", "cl_provoke"],
				"passives": [
					{"id": "cl_endurance", "name": "誓约之躯", "desc": "生命提高15%，受到伤害降低10%。", "hp_pct": 0.15, "dmg_taken": -0.10},
					{"id": "cl_threat", "name": "守护誓约", "desc": "威胁提高30%，护甲提高15%。", "threat": 0.30, "stats_pct": {"armor": 0.15}},
				],
				"traits": []},
		],
		"rogue": [
			{"id": "assassin", "name": "刺杀者", "color": Color("fff569"), "icon": "kidney_shot",
				"desc": "维持毒与出血获得能量回授；攒连击维护出血或释放毒终结，毒终结强化下一次双刺；伏击兼顾正面循环与背后奖励。",
				"role": "近战 · 爆发",
				"grants": ["as_venomous_cut", "as_backstab", "as_death_mark", "as_envenom", "as_shadow_step"],
				"passives": [
					{"id": "as_lethality", "name": "致命", "desc": "致命一击几率提高3%。", "stats": {"crit": 3}},
					{"id": "as_venom", "name": "剧毒", "desc": "持续伤害提高25%。", "dot_pct": 0.25},
				],
				"traits": []},
			{"id": "duelist", "name": "魔法剑士", "color": Color("c0c0c0"), "icon": "mutilate",
				"desc": "暗影矢强化细剑刺击，细剑返回瞬发暗影；两个往返积攒共鸣释放无相贯穿；只使用共鸣，不再额外消耗能量。",
				"role": "近战 · 魔法混合", "weapons": ["rapier"],
				"grants": ["ms_arcane_edge", "ms_shadow_bolt", "ms_spellblade", "ms_unbound", "ms_phase_lunge"],
				"passives": [
					{"id": "du_footwork", "name": "步法", "desc": "躲闪提高4%。", "stats": {"dodge": 4}},
					{"id": "du_tempo", "name": "节奏", "desc": "攻击速度提高8%。", "haste": 0.08},
				],
				"traits": []},
		],
		"gunner": [
			{"id": "marksman", "name": "枪炮师", "color": Color("abd473"), "icon": "aether_shot",
				"desc": "六发弹仓。步枪和霰弹积攒瞄准，手炮或榴弹花两发及两瞄准；分段换弹保留已装填弹药，保留机械猎犬。",
				"role": "远程 · 物理输出",
				"grants": ["cannon_steady", "cannon_burst", "cannon_shotgun", "cannon_barrage", "cannon_reload", "cannon_recoil"],
				"passives": [
					{"id": "mk_aim", "name": "稳定瞄准", "desc": "远程武器伤害提高10%。", "ranged_dmg": 0.10},
					{"id": "mk_eye", "name": "鹰眼", "desc": "致命一击几率提高3%。", "stats": {"crit": 3}},
				],
				"traits": []},
			{"id": "gadgeteer", "name": "机甲师", "color": Color("e0a050"), "icon": "summon_hound",
				"desc": "展开外装甲，重拳与导弹升温；高热强化攻击，贯击排热并强化下一拳；离开接敌范围时可主动散热，不带宠物。",
				"role": "近中程 · 单体输出",
				"grants": ["mech_armor", "mech_piston", "mech_rocket", "mech_rail", "mech_overdrive", "mech_vent"],
				"passives": [
					{"id": "gd_overclock", "name": "超频", "desc": "攻击速度提高8%。", "haste": 0.08},
					{"id": "gd_swift", "name": "轻装", "desc": "移动速度提高6%。", "speed": 0.06},
				],
				"traits": []},
		],
	}
