class_name DataSpells
extends RefCounted
## 职业与技能数据
## 技能 rank 采用路径覆盖：{"lvl":学习等级,"train":训练费用(铜),"set":{"cost":..,"e0.min":..}}

static func classes() -> Dictionary:
	return {
		"warrior": {
			"name": "战士", "color": Color("c79c6e"), "power": "rage", "icon": "sword", "role": "近战 · 坦克",
			"armor": ["cloth", "leather", "mail"],
			"weapons": ["sword", "axe", "mace", "dagger", "sword2", "axe2", "mace2", "polearm", "staff", "shield", "gun", "bow"],
			"base": {"str": 23, "agi": 20, "sta": 22, "int": 20, "spi": 21},
			"growth": {"str": 2.1, "agi": 1.3, "sta": 1.9, "int": 0.2, "spi": 0.5},
			"hp1": 20, "hpg": 13, "mana1": 0, "manag": 0,
			"desc": "身披重甲的前线斗士。蓄积势能爆发连招，势能越高移动越快。双连招路径适应不同战况。",
			"start_items": ["w_recruit_sword", "shirt_recruit", "legs_recruit", "feet_recruit", "food_bread"],
			"spells": ["gather_momentum", "battle_shout", "slash", "heavy_slash", "execute_slash", "whirlwind", "thunder_strike", "earth_shatter", "armor_break", "mortal_strike", "reckless_fury", "charge", "taunt"],
			"rotation": "蓄势待发积累势能 → 单体用斩击连招，AOE用旋风斩连招；怒气够时释放爆发技能。势能影响移动速度。",
			"melee": true,
		},
		"mage": {
			"name": "法师", "color": Color("69ccf0"), "power": "mana", "icon": "fire", "role": "远程 · 法术输出",
			"armor": ["cloth"],
			"weapons": ["staff", "dagger", "sword", "offhand"],
			"base": {"str": 20, "agi": 20, "sta": 20, "int": 23, "spi": 22},
			"growth": {"str": 0.3, "agi": 0.4, "sta": 0.9, "int": 2.1, "spi": 1.9},
			"hp1": 42, "hpg": 10, "mana1": 140, "manag": 20,
			"desc": "在冰与火之间循环的元素学者。火系消耗法力爆发，冰系恢复法力并控制敌人。",
			"start_items": ["w_apprentice_staff", "chest_apprentice_robe", "feet_recruit", "drink_water"],
			"spells": ["fireball", "frostbolt", "ice_lance", "pyroblast", "frost_nova", "living_bomb", "arcane_barrage", "arcane_missiles", "ice_barrier", "frost_armor", "arcane_intellect", "polymorph", "blink"],
			"rotation": "火球术/炎爆术与活动炸弹打火焰输出，寒冰箭/冰枪/冰霜新星控场，奥术飞弹与奥术弹幕填补空档。",
			"melee": false,
		},
		"priest": {
			"name": "牧师", "color": Color("ffffff"), "power": "mana", "icon": "holy", "role": "治疗 · 法术输出",
			"armor": ["cloth"],
			"weapons": ["mace", "staff", "dagger", "offhand"],
			"base": {"str": 20, "agi": 20, "sta": 20, "int": 22, "spi": 23},
			"growth": {"str": 0.3, "agi": 0.4, "sta": 0.9, "int": 1.9, "spi": 2.1},
			"hp1": 32, "hpg": 9, "mana1": 110, "manag": 18,
			"desc": "信奉圣光的治愈者。通过双标记系统(圣光/暗影)增强治疗和伤害。",
			"start_items": ["w_acolyte_mace", "chest_acolyte_robe", "feet_recruit", "drink_water"],
			"spells": ["smite", "holy_fire", "penance", "shadow_word_pain", "mind_blast", "mind_flay", "shadow_word_death", "flash_heal", "renew", "power_word_shield", "psychic_scream", "power_word_fortitude"],
			"rotation": "圣光路线：惩击/神圣之火堆圣光标记 → 苦修爆发；暗影路线：暗言术痛/心灵震爆堆暗影标记 → 暗言术灭斩杀",
			"melee": false,
		},
		"rogue": {
			"name": "盗贼", "color": Color("fff569"), "power": "energy", "icon": "dagger", "role": "近战 · 爆发输出",
			"armor": ["cloth", "leather"],
			"weapons": ["dagger", "sword", "mace", "gun", "bow"],
			"base": {"str": 21, "agi": 23, "sta": 21, "int": 20, "spi": 20},
			"growth": {"str": 1.0, "agi": 2.2, "sta": 1.3, "int": 0.3, "spi": 0.4},
			"hp1": 25, "hpg": 11, "mana1": 0, "manag": 0,
			"desc": "潜伏于阴影中的刺客。积攒连击点数，以终结技一击致命；擅长潜行、控制与闪避。",
			"start_items": ["w_worn_dagger", "shirt_recruit", "legs_leather_recruit", "feet_recruit", "food_bread"],
			"spells": ["poisoned_blade", "shadow_strike", "mutilate", "eviscerate", "rupture", "kidney_shot", "stealth", "vanish", "sprint", "evasion", "kick", "blind"],
			"rotation": "邪恶攻击积攒连击点 → 3–5点剔骨终结并返还能量；等待能量时保持自动攻击。",
			"melee": true,
		},
		"gunner": {
			"name": "魔导枪手", "color": Color("abd473"), "power": "mana", "icon": "gun", "role": "远程 · 物理输出 · 宠物",
			"armor": ["cloth", "leather"],
			"weapons": ["gun", "bow", "axe", "sword", "dagger", "polearm", "axe2", "staff"],
			"base": {"str": 20, "agi": 23, "sta": 21, "int": 21, "spi": 21},
			"growth": {"str": 0.6, "agi": 2.1, "sta": 1.5, "int": 0.9, "spi": 0.9},
			"hp1": 28, "hpg": 11, "mana1": 80, "manag": 13,
			"desc": "手持魔导火枪的猎手，与发条机械猎犬并肩作战。远距离压制，善用控制与机动。",
			"start_items": ["w_recruit_rifle", "w_hand_axe", "shirt_recruit", "legs_leather_recruit", "feet_recruit", "food_bread"],
			"spells": ["auto_shot", "steady_shot", "aether_shot", "summon_hound", "bayonet", "corrosive_round", "weak_mark", "concussive", "hawk_stance", "scatter_volley", "recoil_jump"],
			"rotation": "稳固射击回蓝 → 以太弹消耗法力；自动射击持续输出，机械猎犬牵制敌人。",
			"melee": false,
		},
	}

static func common_spells() -> Array:
	return ["attack", "hearthstone_cast", "dodge_roll"]

static func spells() -> Dictionary:
	var s := {}
	# ------------------------------------------------------------ 通用
	s["attack"] = {"name": "攻击", "icon": "sword", "color": Color("d8d8d8"), "toggle_attack": true, "gcd": 0.0, "target": "enemy", "range": 5.0,
		"desc": "开始或停止近战自动攻击。"}
	s["hearthstone_cast"] = {"name": "返程石", "icon": "hearth", "color": Color("7fb2ff"), "cast": 10.0, "cd": 300.0, "gcd": 0.0, "target": "self",
		"effects": [{"type": "hearth"}], "desc": "引导10秒，将你传送回绑定的旅店。"}

	# 通用闪避（所有职业）
	s["dodge_roll"] = {"name": "闪避翻滚", "icon": "sprint", "color": Color("80c0ff"), "gcd": 0.0, "cd": 2.0, "target": "self",
		"effects": [{"type": "dodge", "invincible_frames": 0.8, "distance": 8.0}, {"type": "stamina_cost", "amount": 30.0}],
		"desc": "消耗30点耐力，向前翻滚8码并在0.8秒内免疫伤害。连续使用耐力消耗递增（30→50→80）。"}

	# 坐骑：模型 / 配色 / 速度都写在 src/data/data_mounts.gd，这里只声明召唤技能
	s["mount_horse"] = {"name": "高地骏马", "icon": "horse", "color": Color("c7905a"), "cast": 1.5, "gcd": 1.5, "target": "self", "no_combat": true,
		"effects": [{"type": "mount", "mount": "horse"}], "desc": "召唤高地骏马。移动速度提高60%。"}
	s["mount_deer"] = {"name": "晨露白鹿", "icon": "horse", "color": Color("f2eee2"), "cast": 1.5, "gcd": 1.5, "target": "self", "no_combat": true,
		"effects": [{"type": "mount", "mount": "deer"}], "desc": "召唤晨露白鹿。移动速度提高60%。"}
	s["mount_wolf"] = {"name": "灰巾座狼", "icon": "horse", "color": Color("8a8a94"), "cast": 1.5, "gcd": 1.5, "target": "self", "no_combat": true,
		"effects": [{"type": "mount", "mount": "wolf"}], "desc": "召唤灰巾座狼。移动速度提高75%。"}
	s["mount_mech"] = {"name": "魔导机车", "icon": "gear", "color": Color("e0a050"), "cast": 1.5, "gcd": 1.5, "target": "self", "no_combat": true,
		"effects": [{"type": "mount", "mount": "mech"}], "desc": "召唤魔导机车。移动速度提高80%。"}
	s["mount_bear"] = {"name": "铁鬃战熊", "icon": "horse", "color": Color("7a5a3a"), "cast": 1.5, "gcd": 1.5, "target": "self", "no_combat": true,
		"effects": [{"type": "mount", "mount": "bear"}], "desc": "召唤铁鬃战熊。移动速度提高90%。"}
	s["eat_drink"] = {"name": "进食", "icon": "bread", "color": Color("e0b070"), "gcd": 0.0, "target": "self", "desc": ""}

	# ------------------------------------------------------------ 战士
	# 基础技能
	s["attack"] = {"name": "攻击", "icon": "sword", "color": Color("d8d8d8"), "toggle_attack": true, "gcd": 0.0, "target": "enemy", "range": 5.0,
		"desc": "开始或停止近战自动攻击。普攻产生5点怒气。"}

	# 蓄力技能
	s["gather_momentum"] = {"name": "蓄势待发", "class": "warrior", "icon": "shout", "color": Color("ffd700"), "school": "physical",
		"channel": 1.5, "ticks": 3, "cd": 3.0, "target": "self", "move_cast": true, "cast_move_multiplier": 0.7,
		"effects": [
			{"type": "momentum", "amount": 15}
		],
		"desc": "引导1.5秒，每0.5秒获得15势能（共45）。引导时可移动，速度降低30%；中断保留已获得的势能。",
		"ranks": [{"lvl": 1}]}

	s["battle_shout"] = {"name": "战吼激励", "class": "warrior", "icon": "shout", "color": Color("e0a030"), "school": "physical",
		"cost": 0, "cd": 20.0, "target": "self",
		"effects": [
			{"type": "momentum", "amount": 30},
			{"type": "self_aura", "aura": {"id": "battle_shout", "name": "战吼激励", "icon": "shout", "color": Color("e0a030"),
				"dur": 10.0, "type": "buff", "mods": {"dmg_done": 0.15}}}
		],
		"desc": "立即获得30点势能，并使攻击力提高15%，持续10秒。",
		"ranks": [{"lvl": 2, "train": 50}]}

	# 连招路径A：狂暴之刃（单体）
	s["slash"] = {"name": "斩击", "class": "warrior", "icon": "sword", "color": Color("d8aa62"), "school": "physical",
		"cost": {"momentum": 15}, "cd": 0.0, "target": "enemy", "range": 5.0,
		"effects": [
			{"type": "damage", "min": 80, "max": 120},
			{"type": "energize", "amount": 10},
			{"type": "combo_chain_set", "chain": "slash_2", "window": 4.0}
		],
		"desc": "造成80-120点物理伤害，产生10点怒气。消耗15点势能。解锁【重劈】4秒。",
		"ranks": [{"lvl": 1}]}

	s["heavy_slash"] = {"name": "重劈", "class": "warrior", "icon": "sword", "color": Color("ff8040"), "school": "physical",
		"cost": {"momentum": 20}, "cd": 0.0, "target": "enemy", "range": 5.0,
		"requires": {"combo_chain": "slash_2"},
		"effects": [
			{"type": "damage", "min": 150, "max": 200},
			{"type": "energize", "amount": 15},
			{"type": "combo_chain_set", "chain": "slash_3", "window": 4.0}
		],
		"desc": "需要【斩击】连招链。造成150-200点物理伤害，产生15点怒气。消耗20点势能。解锁【终结斩】4秒。",
		"ranks": [{"lvl": 3, "train": 80}]}

	s["execute_slash"] = {"name": "终结斩", "class": "warrior", "icon": "sword", "color": Color("ff2020"), "school": "physical",
		"cost": {"momentum": 25}, "cd": 0.0, "target": "enemy", "range": 5.0,
		"requires": {"combo_chain": "slash_3"},
		"effects": [
			{"type": "damage", "min": 250, "max": 350, "execute_bonus": true},
			{"type": "energize", "amount": 20},
			{"type": "combo_chain_clear"}
		],
		"desc": "需要【重劈】连招链。造成250-350点物理伤害,目标生命<20%时伤害翻倍。产生20点怒气。消耗25点势能。",
		"ranks": [{"lvl": 5, "train": 150}]}

	# 连招路径B：横扫千军（AOE）
	s["whirlwind"] = {"name": "旋风斩", "class": "warrior", "icon": "nova", "color": Color("80c0ff"), "school": "physical",
		"cost": {"momentum": 20}, "cd": 0.0, "target": "none", "range": 5.0,
		"effects": [
			{"type": "aoe", "radius": 5.0, "min": 60, "max": 90},
			{"type": "energize", "amount": 10},
			{"type": "combo_chain_set", "chain": "whirl_2", "window": 4.0}
		],
		"vfx": "nova",
		"desc": "5米范围AOE，造成60-90点物理伤害，产生10点怒气。消耗20点势能。解锁【雷霆一击】4秒。",
		"ranks": [{"lvl": 4, "train": 100}]}

	s["thunder_strike"] = {"name": "雷霆一击", "class": "warrior", "icon": "charge", "color": Color("ffd700"), "school": "physical",
		"cost": {"momentum": 25}, "cd": 0.0, "target": "none", "range": 6.0,
		"requires": {"combo_chain": "whirl_2"},
		"effects": [
			{"type": "aoe", "radius": 6.0, "min": 100, "max": 150},
			{"type": "knockback", "distance": 2.0},
			{"type": "energize", "amount": 15},
			{"type": "combo_chain_set", "chain": "whirl_3", "window": 4.0}
		],
		"vfx": "nova",
		"desc": "需要【旋风斩】连招链。6米范围AOE，造成100-150点物理伤害并击退2米。产生15点怒气。消耗25点势能。解锁【大地震击】4秒。",
		"ranks": [{"lvl": 7, "train": 400}]}

	s["earth_shatter"] = {"name": "大地震击", "class": "warrior", "icon": "nova", "color": Color("a05020"), "school": "physical",
		"cost": {"momentum": 30}, "cd": 0.0, "target": "none", "range": 8.0,
		"requires": {"combo_chain": "whirl_3"},
		"effects": [
			{"type": "aoe", "radius": 8.0, "min": 180, "max": 250},
			{"type": "stun", "duration": 2.0},
			{"type": "energize", "amount": 20},
			{"type": "combo_chain_clear"}
		],
		"vfx": "nova",
		"desc": "需要【雷霆一击】连招链。8米范围AOE，造成180-250点物理伤害并眩晕2秒。产生20点怒气。消耗30点势能。",
		"ranks": [{"lvl": 10, "train": 800}]}

	# 爆发技能
	s["armor_break"] = {"name": "破甲重击", "class": "warrior", "icon": "bleed", "color": Color("ff4040"), "school": "physical",
		"cost": {"momentum": 50, "rage": 30}, "cd": 12.0, "target": "enemy", "range": 5.0,
		"effects": [
			{"type": "damage", "min": 400, "max": 550},
			{"type": "aura", "aura": {"id": "armor_break", "name": "破甲", "icon": "bleed", "color": Color("b02020"),
				"dur": 10.0, "type": "debuff", "mods": {"armor": -0.3}}}
		],
		"desc": "造成400-550点物理伤害，降低目标30%护甲10秒。消耗50点势能和30点怒气。",
		"ranks": [{"lvl": 8, "train": 600}]}

	s["mortal_strike"] = {"name": "致死打击", "class": "warrior", "icon": "sword", "color": Color("d02020"), "school": "physical",
		"cost": {"momentum": 60, "rage": 40}, "cd": 8.0, "target": "enemy", "range": 5.0,
		"effects": [
			{"type": "damage", "min": 500, "max": 700},
			{"type": "aura", "aura": {"id": "mortal_wound", "name": "重伤", "icon": "bleed", "color": Color("8b0000"),
				"dur": 6.0, "type": "debuff", "mods": {"healing_taken": -0.5}}}
		],
		"desc": "造成500-700点物理伤害，使目标治疗效果降低50%，持续6秒。消耗60点势能和40点怒气。",
		"ranks": [{"lvl": 12, "train": 1000}]}

	s["reckless_fury"] = {"name": "狂暴之怒", "class": "warrior", "icon": "shout", "color": Color("ff0000"), "school": "physical",
		"cost": {"momentum": 80, "rage": 50}, "cd": 30.0, "target": "enemy", "range": 5.0,
		"effects": [
			{"type": "damage", "min": 800, "max": 1100},
			{"type": "self_aura", "aura": {"id": "reckless", "name": "狂暴", "icon": "shout", "color": Color("ff0000"),
				"dur": 6.0, "type": "buff", "mods": {"crit": 0.5, "dmg_taken": 0.3}}},
			{"type": "combo_chain_clear"}
		],
		"desc": "造成800-1100点物理伤害，暴击率+50%但受到伤害+30%，持续6秒。消耗80点势能和50点怒气。清空连招链。",
		"ranks": [{"lvl": 16, "train": 2000}]}

	# 工具技能
	s["charge"] = {"name": "冲锋", "class": "warrior", "icon": "charge", "color": Color("c06030"), "school": "physical",
		"cost": 0, "cd": 15.0, "gcd": 0.0, "target": "enemy", "range": 25.0, "min_range": 8.0,
		"directional": true,
		"forward": [
			{"type": "charge"},
			{"type": "stun", "duration": 1.5},
			{"type": "momentum", "amount": 15},
			{"type": "energize", "amount": 20}
		],
		"backward": [
			{"type": "dash", "distance": -8.0},
			{"type": "momentum", "amount": 10}
		],
		"desc": "前：冲向目标，眩晕1.5秒，产生15势能和20怒气。后：向后跃退8米，产生10势能。",
		"ranks": [{"lvl": 4, "train": 100}]}

	s["taunt"] = {"name": "嘲讽", "class": "warrior", "icon": "scream", "color": Color("ff8000"), "school": "physical",
		"cost": {"rage": 10}, "cd": 8.0, "target": "enemy", "range": 10.0,
		"effects": [
			{"type": "taunt", "duration": 3.0},
			{"type": "threat", "amount": 300},
			{"type": "self_aura", "aura": {"id": "defensive", "name": "防御姿态", "icon": "shield", "color": Color("8080ff"),
				"dur": 3.0, "type": "buff", "mods": {"dmg_taken": -0.2}}}
		],
		"desc": "强制目标攻击你3秒，威胁值+300%，自身受到伤害-20%。消耗10点怒气。",
		"ranks": [{"lvl": 6, "train": 200}]}
	# ------------------------------------------------------------ 法师
	# ============================================================ 法师
	# 火冰充能系统：火系技能产生火焰充能(0-3层)，冰系技能产生冰霜充能(0-3层)
	# 当火焰充能和冰霜充能同时达到3层时，自动触发"奥术爆发"状态(10秒)
	# 奥术爆发期间：施法速度+30%，法术伤害+20%，移动速度+20%

	s["frostbolt"] = {"name": "寒冰箭", "class": "mage", "icon": "frost", "color": Color("80d0ff"), "school": "frost",
		"cost": 0, "cast": 1.5, "target": "enemy", "range": 30.0,
		"projectile": {"speed": 24.0, "color": Color("a0e0ff"), "size": 0.3},
		"combo_chain_set": "frostbolt_hit",
		"combo_window": 4.0,
		"effects": [
			{"type": "damage", "min": 180, "max": 220},
			{"type": "aura", "aura": {"id": "chilled", "name": "冰冻", "icon": "frost", "color": Color("80d0ff"), "dur": 6.0, "type": "debuff", "mods": {"speed": -0.4}}},
			{"type": "add_charge", "charge_type": "frost", "amount": 1}
		],
		"desc": "造成180-220点冰霜伤害，减速目标40%持续6秒。产生1层冰霜充能。命中后4秒内可使用冰枪术。",
		"rotation_role": "冰系基础输出，产生冰霜充能", "ranks": [{"lvl": 1}]}

	s["fireball"] = {"name": "火球术", "class": "mage", "icon": "fire", "color": Color("ff7020"), "school": "fire",
		"cost": 0, "cast": 2.0, "target": "enemy", "range": 30.0,
		"projectile": {"speed": 26.0, "color": Color("ff8030"), "size": 0.35},
		"combo_chain_set": "fireball_hit",
		"combo_window": 4.0,
		"effects": [
			{"type": "damage", "min": 280, "max": 340},
			{"type": "aura", "aura": {"id": "fireball_dot", "name": "燃烧", "icon": "fire", "color": Color("ff7020"), "dur": 6.0, "type": "debuff", "tick": {"interval": 2.0, "dmg": 30, "school": "fire"}}},
			{"type": "add_charge", "charge_type": "fire", "amount": 1}
		],
		"desc": "造成280-340点火焰伤害+90点持续伤害(6秒)。产生1层火焰充能。命中后4秒内可使用炎爆术。",
		"rotation_role": "火系基础输出，产生火焰充能", "ranks": [{"lvl": 1}]}

	s["ice_lance"] = {"name": "冰枪术", "class": "mage", "icon": "icicle", "color": Color("a0e0ff"), "school": "frost",
		"cost": 0, "cd": 0.0, "target": "enemy", "range": 40.0,
		"requires": {"combo_chain": "frostbolt_hit"},
		"projectile": {"speed": 50.0, "color": Color("c0f0ff"), "size": 0.25},
		"effects": [
			{"type": "damage", "min": 120, "max": 150, "bonus_if_slowed": 2.0},
			{"type": "add_charge", "charge_type": "frost", "amount": 1},
			{"type": "combo_chain_clear"}
		],
		"desc": "需要【寒冰箭】命中。瞬发，造成120-150点冰霜伤害，对减速目标伤害翻倍。产生1层冰霜充能。",
		"rotation_role": "冰系连招终结", "ranks": [{"lvl": 8, "train": 300}]}

	s["pyroblast"] = {"name": "炎爆术", "class": "mage", "icon": "fireball", "color": Color("ff3010"), "school": "fire",
		"cost": 0, "cast": 3.0, "cd": 0.0, "target": "enemy", "range": 30.0,
		"requires": {"combo_chain": "fireball_hit"},
		"projectile": {"speed": 20.0, "color": Color("ff4020"), "size": 0.5},
		"effects": [
			{"type": "damage", "min": 600, "max": 700},
			{"type": "aura", "aura": {"id": "pyroblast_dot", "name": "灼烧", "icon": "fire", "color": Color("ff3010"), "dur": 12.0, "type": "debuff", "tick": {"interval": 3.0, "dmg": 60, "school": "fire"}}},
			{"type": "add_charge", "charge_type": "fire", "amount": 2},
			{"type": "combo_chain_clear"}
		],
		"desc": "需要【火球术】命中。3秒施法，造成600-700点火焰伤害+240点持续伤害(12秒)。产生2层火焰充能。",
		"rotation_role": "火系连招终结，高伤害", "ranks": [{"lvl": 12, "train": 800}]}

	s["frost_nova"] = {"name": "冰霜新星", "class": "mage", "icon": "nova", "color": Color("a0e0ff"), "school": "frost",
		"cost": 0, "cd": 25.0, "target": "none",
		"effects": [
			{"type": "aoe", "radius": 10.0, "min": 100, "max": 140, "aura": {"id": "frost_nova", "name": "冰霜新星", "icon": "nova", "color": Color("a0e0ff"), "dur": 8.0, "type": "debuff", "root": true}},
			{"type": "add_charge", "charge_type": "frost", "amount": 2}
		],
		"vfx": "frostnova",
		"desc": "定身10码内所有敌人8秒，造成100-140点冰霜伤害。产生2层冰霜充能。",
		"rotation_role": "控制+充能", "ranks": [{"lvl": 4, "train": 100}]}

	s["living_bomb"] = {"name": "活体炸弹", "class": "mage", "icon": "bomb", "color": Color("ff6010"), "school": "fire",
		"cost": 0, "cd": 12.0, "target": "enemy", "range": 40.0,
		"effects": [
			{"type": "aura", "aura": {"id": "living_bomb", "name": "活体炸弹", "icon": "bomb", "color": Color("ff6010"), "dur": 12.0, "type": "debuff", "tick": {"interval": 3.0, "dmg": 50, "school": "fire"}, "on_expire": {"type": "aoe", "radius": 10.0, "min": 200, "max": 250}}},
			{"type": "add_charge", "charge_type": "fire", "amount": 2}
		],
		"desc": "在目标身上放置炸弹，12秒内造成200点持续伤害，到期时爆炸对10码内敌人造成200-250点火焰伤害。产生2层火焰充能。",
		"rotation_role": "AOE+充能", "ranks": [{"lvl": 6, "train": 100}]}

	s["arcane_barrage"] = {"name": "奥术弹幕", "class": "mage", "icon": "arcane", "color": Color("c080ff"), "school": "arcane",
		"cost": 0, "cd": 3.0, "target": "enemy", "range": 40.0,
		"requires": {"min_charges": 3},
		"projectile": {"speed": 35.0, "color": Color("d090ff"), "size": 0.3},
		"effects": [
			{"type": "damage", "min": 150, "max": 200, "per_charge": 50},
			{"type": "consume_all_charges"}
		],
		"desc": "需要至少3层充能(任意类型)。消耗所有充能,每层造成额外50点奥术伤害。",
		"rotation_role": "充能消耗技能", "ranks": [{"lvl": 14, "train": 900}]}

	s["arcane_missiles"] = {"name": "奥术飞弹", "class": "mage", "icon": "missiles", "color": Color("d080ff"), "school": "arcane",
		"cost": 0, "channel": 3.0, "ticks": 3, "target": "enemy", "range": 30.0,
		"requires": {"has_aura_self": "arcane_surge"},
		"projectile": {"speed": 30.0, "color": Color("e0a0ff"), "size": 0.2},
		"effects": [
			{"type": "damage", "min": 240, "max": 240}
		],
		"desc": "需要【奥术爆发】状态。引导3秒，每秒发射一枚飞弹，每枚造成240点奥术伤害，共720点。",
		"rotation_role": "奥术爆发期间爆发输出", "ranks": [{"lvl": 10, "train": 500}]}

	s["blink"] = {"name": "闪现术", "class": "mage", "icon": "blink", "color": Color("b0a0ff"),
		"cost": 0, "cd": 15.0, "gcd": 0.0, "target": "self",
		"effects": [
			{"type": "blink", "dist": 20.0},
			{"type": "clear_control"}
		],
		"desc": "向前瞬移20码，解除昏迷和定身。",
		"rotation_role": "机动性", "ranks": [{"lvl": 10, "train": 500}]}

	s["ice_barrier"] = {"name": "寒冰护体", "class": "mage", "icon": "icebarrier", "color": Color("a0d0ff"),
		"cost": 0, "cd": 25.0, "target": "self",
		"effects": [
			{"type": "self_aura", "aura": {"id": "ice_barrier", "name": "寒冰护体", "icon": "icebarrier", "color": Color("a0d0ff"), "dur": 60.0, "type": "buff", "absorb": 800}}
		],
		"desc": "形成寒冰护盾，吸收800点伤害，持续60秒。",
		"rotation_role": "防御", "ranks": [{"lvl": 12, "train": 800}]}

	s["polymorph"] = {"name": "变形术", "class": "mage", "icon": "sheep", "color": Color("f0f0f0"), "school": "arcane",
		"cost": 0, "cast": 1.5, "cd": 0.0, "target": "enemy", "range": 30.0,
		"effects": [
			{"type": "aura", "aura": {"id": "polymorph", "name": "变形术", "icon": "sheep", "color": Color("f0f0f0"), "dur": 30.0, "type": "debuff", "incap": true, "break_on_damage": true, "sheep": true}}
		],
		"requires": {"poly_target": true},
		"desc": "将敌人变成绵羊，无法行动30秒。受伤解除。仅对野兽与人型生物有效。",
		"rotation_role": "控制", "ranks": [{"lvl": 8, "train": 300}]}

	s["frost_armor"] = {"name": "霜甲术", "class": "mage", "icon": "armor", "color": Color("80c0ff"),
		"cost": 0, "target": "self",
		"effects": [
			{"type": "self_aura", "aura": {"id": "frost_armor", "name": "霜甲术", "icon": "armor", "color": Color("80c0ff"), "dur": 1800.0, "type": "buff", "stats": {"armor": 150}}}
		],
		"desc": "护甲值提高150点，持续30分钟。",
		"rotation_role": "防御buff", "ranks": [{"lvl": 3, "train": 20}]}

	s["arcane_intellect"] = {"name": "奥术智慧", "class": "mage", "icon": "arcane", "color": Color("c080ff"),
		"cost": 0, "target": "friend", "range": 30.0,
		"effects": [
			{"type": "aura", "aura": {"id": "arcane_intellect", "name": "奥术智慧", "icon": "arcane", "color": Color("c080ff"), "dur": 3600.0, "type": "buff", "stats": {"int": 60}}}
		],
		"desc": "智力提高60点，持续60分钟。",
		"rotation_role": "团队buff", "ranks": [{"lvl": 5, "train": 100}]}

	# ------------------------------------------------------------ 牧师
	# ============================================================ 牧师
	# 双标记系统：圣光标记(holy_mark)用于增强治疗，暗影标记(shadow_mark)用于增强伤害
	# 标记在目标身上，最多各5层，30秒后衰减

	s["smite"] = {"name": "惩击", "class": "priest", "icon": "holy", "color": Color("ffe080"), "school": "holy",
		"cost": 0, "cast": 1.5, "target": "enemy", "range": 30.0,
		"effects": [
			{"type": "damage", "min": 150, "max": 180},
			{"type": "add_mark", "mark_type": "holy", "amount": 1}
		],
		"desc": "造成150-180点神圣伤害。为目标添加1层圣光标记(最多5层)。",
		"rotation_role": "圣光标记生成", "ranks": [{"lvl": 1}]}

	s["holy_fire"] = {"name": "神圣之火", "class": "priest", "icon": "holyfire", "color": Color("ffb040"), "school": "holy",
		"cost": 0, "cast": 2.0, "cd": 10.0, "target": "enemy", "range": 30.0,
		"effects": [
			{"type": "damage", "min": 300, "max": 350},
			{"type": "aura", "aura": {"id": "holy_fire_dot", "name": "神圣之火", "icon": "holyfire", "color": Color("ffb040"), "dur": 7.0, "type": "debuff", "tick": {"interval": 1.0, "dmg": 30, "school": "holy"}}},
			{"type": "add_mark", "mark_type": "holy", "amount": 2}
		],
		"desc": "造成300-350点神圣伤害+210点持续伤害(7秒)。为目标添加2层圣光标记。",
		"rotation_role": "圣光标记快速生成+DOT", "ranks": [{"lvl": 5}]}

	s["penance"] = {"name": "苦修", "class": "priest", "icon": "penance", "color": Color("ffd080"), "school": "holy",
		"cost": 0, "channel": 2.0, "ticks": 3, "cd": 9.0, "target": "enemy", "range": 40.0,
		"requires": {"holy_marks_min": 3},
		"effects": [
			{"type": "damage", "min": 200, "max": 200, "per_holy_mark": 40},
			{"type": "consume_marks", "mark_type": "holy"}
		],
		"desc": "需要目标有至少3层圣光标记。引导2秒，发射3道圣光，每道造成200点+每层圣光标记40点伤害。消耗所有圣光标记。",
		"rotation_role": "圣光标记消耗爆发", "ranks": [{"lvl": 10}]}

	s["shadow_word_pain"] = {"name": "暗言术：痛", "class": "priest", "icon": "shadow", "color": Color("8040c0"), "school": "shadow",
		"cost": 0, "target": "enemy", "range": 30.0,
		"effects": [
			{"type": "aura", "aura": {"id": "sw_pain", "name": "暗言术：痛", "icon": "shadow", "color": Color("8040c0"), "dur": 18.0, "type": "debuff", "tick": {"interval": 3.0, "dmg": 50, "school": "shadow"}}},
			{"type": "add_mark", "mark_type": "shadow", "amount": 1}
		],
		"desc": "造成300点暗影持续伤害(18秒)。为目标添加1层暗影标记(最多5层)。",
		"rotation_role": "暗影标记生成+DOT", "ranks": [{"lvl": 1}]}

	s["mind_blast"] = {"name": "心灵震爆", "class": "priest", "icon": "brain", "color": Color("b060ff"), "school": "shadow",
		"cost": 0, "cast": 1.5, "cd": 8.0, "target": "enemy", "range": 30.0,
		"effects": [
			{"type": "damage", "min": 350, "max": 400},
			{"type": "add_mark", "mark_type": "shadow", "amount": 2}
		],
		"desc": "造成350-400点暗影伤害。为目标添加2层暗影标记。",
		"rotation_role": "暗影标记快速生成", "ranks": [{"lvl": 3}]}

	s["mind_flay"] = {"name": "精神鞭笞", "class": "priest", "icon": "mindflay", "color": Color("9050d0"), "school": "shadow",
		"cost": 0, "channel": 3.0, "ticks": 3, "target": "enemy", "range": 30.0,
		"effects": [
			{"type": "damage", "min": 100, "max": 100, "per_shadow_mark": 30},
			{"type": "aura", "aura": {"id": "mind_flay_slow", "name": "精神鞭笞", "icon": "mindflay", "color": Color("9050d0"), "dur": 3.0, "type": "debuff", "mods": {"speed": -0.5}}}
		],
		"desc": "引导3秒，每秒造成100点+每层暗影标记30点伤害，并减速目标50%。",
		"rotation_role": "暗影标记增强伤害+控制", "ranks": [{"lvl": 7}]}

	s["shadow_word_death"] = {"name": "暗言术：灭", "class": "priest", "icon": "skull", "color": Color("a030b0"), "school": "shadow",
		"cost": 0, "cd": 12.0, "target": "enemy", "range": 30.0,
		"requires": {"shadow_marks_min": 3},
		"effects": [
			{"type": "damage", "min": 400, "max": 500, "per_shadow_mark": 80, "execute_bonus_threshold": 0.2, "execute_multiplier": 2.0},
			{"type": "consume_marks", "mark_type": "shadow"}
		],
		"desc": "需要目标有至少3层暗影标记。造成400-500点+每层暗影标记80点暗影伤害。对生命低于20%的目标伤害翻倍。消耗所有暗影标记。",
		"rotation_role": "暗影标记消耗斩杀", "ranks": [{"lvl": 12}]}

	s["flash_heal"] = {"name": "快速治疗", "class": "priest", "icon": "heal", "color": Color("ffffa0"), "school": "holy",
		"cost": 0, "cast": 1.5, "target": "friend", "range": 40.0,
		"effects": [
			{"type": "heal", "min": 400, "max": 500, "per_holy_mark": 60}
		],
		"desc": "治疗一个友方目标400-500点生命值。目标身上每层圣光标记额外治疗60点。",
		"rotation_role": "圣光标记增强治疗", "ranks": [{"lvl": 1}]}

	s["renew"] = {"name": "恢复", "class": "priest", "icon": "renew", "color": Color("a0ffa0"), "school": "holy",
		"cost": 0, "target": "friend", "range": 40.0,
		"effects": [
			{"type": "aura", "aura": {"id": "renew", "name": "恢复", "icon": "renew", "color": Color("a0ffa0"), "dur": 15.0, "type": "buff", "tick": {"interval": 3.0, "heal": 80}}}
		],
		"desc": "在15秒内为目标恢复400点生命值。",
		"rotation_role": "HOT", "ranks": [{"lvl": 2}]}

	s["power_word_shield"] = {"name": "真言术：盾", "class": "priest", "icon": "pwshield", "color": Color("fff0a0"),
		"cost": 0, "cd": 6.0, "target": "friend", "range": 40.0,
		"requires": {"no_aura_target": "weakened_soul"},
		"effects": [
			{"type": "aura", "aura": {"id": "pw_shield", "name": "真言术：盾", "icon": "pwshield", "color": Color("fff0a0"), "dur": 30.0, "type": "buff", "absorb": 600}},
			{"type": "aura", "aura": {"id": "weakened_soul", "name": "虚弱灵魂", "icon": "shadow", "color": Color("806060"), "dur": 15.0, "type": "debuff"}}
		],
		"desc": "为目标套上神圣护盾，吸收600点伤害，持续30秒。之后15秒内目标无法再次受到护盾。",
		"rotation_role": "护盾", "ranks": [{"lvl": 4}]}

	s["psychic_scream"] = {"name": "心灵尖啸", "class": "priest", "icon": "scream", "color": Color("8040a0"), "school": "shadow",
		"cost": 0, "cd": 30.0, "target": "none",
		"effects": [
			{"type": "aoe", "radius": 8.0, "min": 0, "max": 0, "max_targets": 3, "aura": {"id": "fear", "name": "恐惧", "icon": "scream", "color": Color("8040a0"), "dur": 8.0, "type": "debuff", "fear": true, "break_on_damage_chance": 0.25}}
		],
		"desc": "发出一声尖啸，使附近最多3名敌人恐惧逃跑，持续8秒。",
		"rotation_role": "AOE控制", "ranks": [{"lvl": 9}]}

	s["power_word_fortitude"] = {"name": "真言术：韧", "class": "priest", "icon": "fort", "color": Color("e0e0ff"),
		"cost": 0, "target": "friend", "range": 30.0,
		"effects": [
			{"type": "aura", "aura": {"id": "pw_fortitude", "name": "真言术：韧", "icon": "fort", "color": Color("e0e0ff"), "dur": 1800.0, "type": "buff", "stats": {"sta": 60}}}
		],
		"desc": "使目标耐力提高60点，持续30分钟。",
		"rotation_role": "团队buff", "ranks": [{"lvl": 1}]}

	# ------------------------------------------------------------ 盗贼
	s["poisoned_blade"] = {
		"name": "毒刃", "class": "rogue", "icon": "dagger", "color": Color("60c040"),
		"school": "physical", "cost": 30, "gcd": 1.0, "target": "enemy", "range": 5.0,
		"effects": [
			{"type": "weapon", "pct": 1.2},
			{"type": "combo", "n": 1},
			{"type": "aura", "aura": {
				"id": "poison_dot", "name": "毒性", "icon": "poison", "color": Color("60c040"),
				"dur": 6.0, "type": "debuff", "max_stacks": 3,
				"tick": {"interval": 2.0, "dmg": 10, "school": "nature"}
			}}
		],
		"desc": "造成120%武器伤害，产生1连击点。使目标中毒，6秒内受到30点自然伤害（可叠3层）。",
		"ranks": [{"lvl": 1}]
	}

	s["shadow_strike"] = {
		"name": "暗影突袭", "class": "rogue", "icon": "dagger", "color": Color("8040c0"),
		"school": "shadow", "cost": 40, "cd": 12.0, "gcd": 1.0, "target": "enemy", "range": 20.0,
		"requires": {"stealth_or_behind": true},
		"effects": [
			{"type": "teleport_behind"},
			{"type": "weapon", "pct": 1.5},
			{"type": "combo", "n": 2}
		],
		"desc": "瞬移到目标背后，造成150%武器伤害，产生2连击点。需要在潜行或目标侧面/背后。",
		"ranks": [{"lvl": 3}]
	}

	s["mutilate"] = {
		"name": "割裂", "class": "rogue", "icon": "dagger", "color": Color("e04040"),
		"school": "physical", "cost": 50, "gcd": 1.0, "target": "enemy", "range": 5.0,
		"requires": {"dual_wield": true},
		"effects": [
			{"type": "weapon", "pct": 1.0, "main_hand": true},
			{"type": "weapon", "pct": 1.0, "off_hand": true},
			{"type": "combo", "n": 2, "n_from_behind": 3}
		],
		"desc": "双武器同时攻击，各造成100%武器伤害。产生2连击点，从背后使用产生3点。需要双持。",
		"ranks": [{"lvl": 5}]
	}

	s["eviscerate"] = {
		"name": "剔骨", "class": "rogue", "icon": "bleed", "color": Color("e04040"),
		"school": "physical", "cost": 25, "gcd": 1.0, "target": "enemy", "range": 5.0,
		"requires": {"combo": true},
		"effects": [{
			"type": "finisher_damage",
			"per_cp": [[60, 60], [130, 130], [210, 210], [300, 300], [400, 400]],
			"ap_per_cp": 0.15,
			"energy_per_cp": 5
		}],
		"desc": "终结技，消耗所有连击点造成伤害并返还能量（每点5能量）：\n1点：60伤害\n3点：210伤害\n5点：400伤害",
		"ranks": [{"lvl": 1}]
	}

	s["rupture"] = {
		"name": "割裂出血", "class": "rogue", "icon": "bleed", "color": Color("c03030"),
		"school": "physical", "cost": 25, "gcd": 1.0, "target": "enemy", "range": 5.0,
		"requires": {"combo": true},
		"effects": [{
			"type": "finisher_aura_scaled",
			"durations": [8.0, 12.0, 16.0, 20.0, 24.0],
			"damages": [30, 40, 50, 60, 75],
			"aura_base": {
				"id": "rupture", "name": "割裂出血", "icon": "bleed", "color": Color("c03030"),
				"type": "debuff",
				"tick": {"interval": 2.0, "dmg": 30, "school": "physical"}
			}
		}],
		"desc": "终结技，使目标持续流血：\n1点：8秒120伤害\n3点：16秒400伤害\n5点：24秒900伤害",
		"ranks": [{"lvl": 7}]
	}

	s["kidney_shot"] = {
		"name": "肾击", "class": "rogue", "icon": "kick", "color": Color("c0a060"),
		"school": "physical", "cost": 25, "gcd": 1.0, "target": "enemy", "range": 5.0,
		"requires": {"combo": true},
		"effects": [{
			"type": "finisher_stun",
			"durations": [1.0, 1.0, 2.0, 2.0, 3.0]
		}],
		"desc": "终结技，昏迷目标：\n1-2点：1秒\n3-4点：2秒\n5点：3秒",
		"ranks": [{"lvl": 9}]
	}

	s["stealth"] = {
		"name": "潜行", "class": "rogue", "icon": "stealth", "color": Color("8080a0"),
		"cost": 0, "cd": 10.0, "gcd": 0.0, "target": "self", "no_combat": true, "cd_on_end": true,
		"effects": [{
			"type": "self_aura", "aura": {
				"id": "stealth", "name": "潜行", "icon": "stealth", "color": Color("8080a0"),
				"dur": 0.0, "type": "buff", "stealth": true,
				"mods": {"speed": -0.3}, "toggle": true
			}
		}],
		"desc": "进入潜行状态，移动速度-30%。潜行时暗影突袭无冷却。",
		"ranks": [{"lvl": 1}]
	}

	s["vanish"] = {
		"name": "消失", "class": "rogue", "icon": "stealth", "color": Color("6060a0"),
		"cost": 0, "cd": 120.0, "gcd": 0.0, "target": "self",
		"effects": [
			{"type": "clear_threat"},
			{"type": "self_aura", "aura": {
				"id": "vanish", "name": "消失", "icon": "stealth", "color": Color("6060a0"),
				"dur": 5.0, "type": "buff", "stealth": true, "invincible": true
			}}
		],
		"desc": "立即进入潜行并在5秒内免疫所有攻击。清空仇恨。",
		"ranks": [{"lvl": 11}]
	}

	s["sprint"] = {
		"name": "疾跑", "class": "rogue", "icon": "sprint", "color": Color("e0e080"),
		"cost": 0, "cd": 60.0, "gcd": 0.0, "target": "self",
		"effects": [{
			"type": "self_aura", "aura": {
				"id": "sprint", "name": "疾跑", "icon": "sprint", "color": Color("e0e080"),
				"dur": 8.0, "type": "buff", "mods": {"speed": 0.7}
			}
		}],
		"desc": "移动速度提高70%，持续8秒。",
		"ranks": [{"lvl": 1}]
	}

	s["evasion"] = {
		"name": "闪避", "class": "rogue", "icon": "evade", "color": Color("80e080"),
		"cost": 0, "cd": 120.0, "gcd": 0.0, "target": "self",
		"effects": [{
			"type": "self_aura", "aura": {
				"id": "evasion", "name": "闪避", "icon": "evade", "color": Color("80e080"),
				"dur": 10.0, "type": "buff", "mods": {"dodge": 0.5}
			}
		}],
		"desc": "躲闪几率提高50%，持续10秒。",
		"ranks": [{"lvl": 8}]
	}

	s["kick"] = {
		"name": "脚踢", "class": "rogue", "icon": "kick", "color": Color("d0b080"),
		"cost": 25, "cd": 15.0, "gcd": 0.0, "target": "enemy", "range": 5.0,
		"effects": [
			{"type": "damage", "min": 10, "max": 10},
			{"type": "interrupt", "lock": 4.0}
		],
		"desc": "踢击目标，打断其施法并锁定该系法术4秒。",
		"ranks": [{"lvl": 6}]
	}

	s["blind"] = {
		"name": "致盲", "class": "rogue", "icon": "fear", "color": Color("a08060"),
		"cost": 0, "cd": 120.0, "gcd": 1.0, "target": "enemy", "range": 10.0,
		"effects": [{
			"type": "aura", "aura": {
				"id": "blind", "name": "致盲", "icon": "fear", "color": Color("a08060"),
				"dur": 6.0, "type": "debuff", "incap": true, "break_on_damage": true
			}
		}],
		"desc": "致盲目标6秒，受到伤害解除。",
		"ranks": [{"lvl": 12}]
	}

	# ------------------------------------------------------------ 魔导枪手
	s["steady_shot"] = {"name": "稳固射击", "class": "gunner", "icon": "gun", "color": Color("88c5ad"), "school": "physical", "cost": 0, "cast": 1.5, "target": "enemy", "range": 35.0, "min_range": 5.0, "rotation_role": "装填回蓝",
		"requires": {"ranged_weapon": true}, "projectile": {"speed": 50.0, "color": Color("a0ead1"), "size": 0.12, "kind": "bullet"},
		"effects": [{"type": "ranged", "pct": 0.7, "bonus": 2, "rap_coef": 0.06}, {"type": "energize", "pct": 0.12}],
		"desc": "稳固瞄准射击，造成70%远程武器伤害外加少量伤害，并恢复12%最大法力。", "ranks": [{"lvl": 1}]}
	s["auto_shot"] = {"name": "自动射击", "class": "gunner", "icon": "gun", "color": Color("c0a070"), "gcd": 0.0, "target": "enemy", "range": 35.0, "min_range": 5.0,
		"toggle_shoot": true, "requires": {"ranged_weapon": true}, "desc": "开始自动射击目标。", "ranks": [{"lvl": 1}]}
	s["bayonet"] = {"name": "刺刀突刺", "class": "gunner", "icon": "axe", "color": Color("c08050"), "school": "physical", "cost": 15, "cd": 6.0, "target": "enemy", "range": 5.0,
		"effects": [{"type": "weapon", "bonus": 5}],
		"desc": "以近战武器猛刺，造成武器伤害外加{e0.bonus}点伤害。",
		"ranks": [{"lvl": 1}, {"lvl": 8, "train": 200, "set": {"cost": 25, "e0.bonus": 11}}, {"lvl": 16, "train": 1400, "set": {"cost": 35, "e0.bonus": 21}}]}
	s["summon_hound"] = {"name": "召唤机械猎犬", "class": "gunner", "icon": "pet", "color": Color("d0a050"), "cost": 30, "cast": 3.0, "target": "self", "no_combat": false,
		"effects": [{"type": "summon_pet", "pet": "pet_clockhound"}], "desc": "召唤你的发条机械猎犬并肩作战。若猎犬已被击毁则将其修复。", "ranks": [{"lvl": 1}]}
	s["corrosive_round"] = {"name": "腐蚀弹", "class": "gunner", "icon": "poison", "color": Color("60c040"), "school": "nature", "cost": 15, "target": "enemy", "range": 35.0, "min_range": 5.0,
		"requires": {"ranged_weapon": true}, "projectile": {"speed": 45.0, "color": Color("80e060"), "size": 0.15},
		"effects": [{"type": "aura", "aura": {"id": "corrosive", "name": "腐蚀弹", "icon": "poison", "color": Color("60c040"), "dur": 15.0, "type": "debuff", "tick": {"interval": 3.0, "dmg": 4, "school": "nature", "rap_coef": 0.02}}}],
		"desc": "射出腐蚀弹，在15秒内造成{corr_total}点自然伤害。",
		"ranks": [{"lvl": 4, "train": 100}, {"lvl": 10, "train": 500, "set": {"cost": 25, "e0.aura.tick.dmg": 8}}]}
	s["aether_shot"] = {"name": "以太弹", "class": "gunner", "icon": "arcane", "color": Color("a080ff"), "school": "arcane", "cost": 18, "cd": 6.0, "target": "enemy", "range": 35.0, "min_range": 5.0, "rotation_role": "消耗法力 · 爆发射击",
		"requires": {"ranged_weapon": true}, "projectile": {"speed": 50.0, "color": Color("c0a0ff"), "size": 0.2},
		"effects": [{"type": "ranged", "bonus": 13, "pct": 0.0, "rap_coef": 0.15}],
		"desc": "射出一枚以太弹，造成{e0.bonus}点外加远程攻击强度15%的奥术伤害。",
		"ranks": [{"lvl": 1}, {"lvl": 12, "train": 600, "set": {"cost": 30, "e0.bonus": 21}}]}
	s["weak_mark"] = {"name": "弱点标记", "class": "gunner", "icon": "mark", "color": Color("ff4040"), "cost": 15, "gcd": 1.5, "target": "enemy", "range": 60.0,
		"effects": [{"type": "aura", "aura": {"id": "weak_mark", "name": "弱点标记", "icon": "mark", "color": Color("ff4040"), "dur": 120.0, "type": "debuff", "mods": {"dmg_taken": 0.06}}}],
		"desc": "标记目标的弱点，使其受到的伤害提高6%，持续2分钟。", "ranks": [{"lvl": 6, "train": 200}]}
	s["concussive"] = {"name": "震荡射击", "class": "gunner", "icon": "gun", "color": Color("80a0e0"), "cost": 20, "cd": 12.0, "target": "enemy", "range": 35.0, "min_range": 5.0,
		"requires": {"ranged_weapon": true}, "projectile": {"speed": 50.0, "color": Color("a0c0ff"), "size": 0.15},
		"effects": [{"type": "aura", "aura": {"id": "concussive", "name": "震荡射击", "icon": "gun", "color": Color("80a0e0"), "dur": 4.0, "type": "debuff", "mods": {"speed": -0.5}}}],
		"desc": "使目标移动速度降低50%，持续4秒。", "ranks": [{"lvl": 8, "train": 300}]}
	s["hawk_stance"] = {"name": "鹰眼姿态", "class": "gunner", "icon": "mark", "color": Color("f0a030"), "cost": 20, "target": "self",
		"effects": [{"type": "self_aura", "aura": {"id": "hawk_stance", "name": "鹰眼姿态", "icon": "mark", "color": Color("f0a030"), "dur": 0.0, "type": "buff", "stats": {"rap": 20}, "toggle": true}}],
		"desc": "进入鹰眼姿态，远程攻击强度提高20点。", "ranks": [{"lvl": 10, "train": 500}]}
	s["scatter_volley"] = {"name": "散射弹", "class": "gunner", "icon": "missiles", "color": Color("e0a060"), "school": "physical", "cost": 40, "cd": 10.0, "target": "enemy", "range": 35.0, "min_range": 5.0,
		"requires": {"ranged_weapon": true},
		"effects": [{"type": "ranged_multi", "targets": 3, "radius": 10.0, "bonus": 30}],
		"desc": "向目标及其附近最多2名敌人各射出一发子弹，造成远程武器伤害外加{e0.bonus}点伤害。", "ranks": [{"lvl": 12, "train": 600}]}
	s["recoil_jump"] = {"name": "后坐跃", "class": "gunner", "icon": "jump", "color": Color("80c0ff"), "cost": 15, "cd": 20.0, "gcd": 0.0, "target": "self",
		"effects": [{"type": "leap_back", "dist": 14.0}], "desc": "借助枪械后坐力向后跃出约14码。", "ranks": [{"lvl": 14, "train": 900}]}

	# ------------------------------------------------------------ 天赋终章技能（由对应天赋 grant 授予，训练师不出售）
	s["mortal_strike"] = {"name": "致死打击", "class": "warrior", "icon": "sword", "color": Color("ff6020"), "school": "physical", "cost": 30, "cd": 6.0, "target": "enemy", "range": 5.0, "talent": true,
		"effects": [{"type": "weapon", "pct": 1.1, "bonus": 8},
			{"type": "aura", "aura": {"id": "mortal_wound", "name": "致伤", "icon": "bleed", "color": Color("b02020"), "dur": 9.0, "type": "debuff", "tick": {"interval": 3.0, "dmg": 5, "school": "physical"}}}],
		"desc": "一次沉重的打击，造成110%武器伤害外加{e0.bonus}点伤害；伤口在9秒内还会流掉15点生命。"}
	s["shield_wall"] = {"name": "盾墙", "class": "warrior", "icon": "shield", "color": Color("d0d8e8"), "cost": 0, "cd": 180.0, "gcd": 0.0, "target": "self", "talent": true,
		"effects": [{"type": "self_aura", "aura": {"id": "shield_wall", "name": "盾墙", "icon": "shield", "color": Color("d0d8e8"), "dur": 8.0, "type": "buff", "mods": {"dmg_taken": -0.4}}}],
		"desc": "把盾牌插进地里，受到的所有伤害降低40%，持续8秒。冷却3分钟。"}
	s["pyroblast"] = {"name": "炎爆术", "class": "mage", "icon": "fire", "color": Color("ff3000"), "school": "fire", "cost": 80, "cast": 3.2, "target": "enemy", "range": 30.0, "talent": true,
		"projectile": {"speed": 20.0, "color": Color("ff6020"), "size": 0.5},
		"effects": [{"type": "damage", "min": 140, "max": 172, "coef": 0.85},
			{"type": "aura", "aura": {"id": "pyro_burn", "name": "燃烧", "icon": "fire", "color": Color("ff5010"), "dur": 6.0, "type": "debuff", "tick": {"interval": 2.0, "dmg": 8, "school": "fire"}}}],
		"desc": "投出一颗巨大的炎爆，造成{e0.min}到{e0.max}点火焰伤害，并在6秒内再造成24点火焰伤害。"}
	s["ice_barrier"] = {"name": "寒冰护体", "class": "mage", "icon": "pwshield", "color": Color("c0e8ff"), "cost": 40, "cd": 30.0, "target": "self", "talent": true,
		"effects": [{"type": "self_aura", "aura": {"id": "ice_barrier", "name": "寒冰护体", "icon": "pwshield", "color": Color("c0e8ff"), "dur": 30.0, "type": "buff", "absorb": 90, "absorb_scale": 6.0}}],
		"desc": "寒冰裹住全身，吸收{e0.aura.absorb}点伤害（并随等级提高），持续30秒。"}
	s["greater_heal"] = {"name": "强效治疗术", "class": "priest", "icon": "heal", "color": Color("ffffd0"), "school": "holy", "cost": 90, "cast": 3.0, "target": "friend", "range": 40.0, "talent": true,
		"effects": [{"type": "heal", "min": 175, "max": 205, "coef": 0.85}], "vfx": "heal",
		"desc": "把全部圣光灌注进一次祈祷，治疗目标{e0.min}到{e0.max}点生命值。"}
	s["shadowform"] = {"name": "暗影形态", "class": "priest", "icon": "shadow", "color": Color("6020a0"), "cost": 60, "target": "self", "talent": true,
		"effects": [{"type": "self_aura", "aura": {"id": "shadowform", "name": "暗影形态", "icon": "shadow", "color": Color("6020a0"), "dur": 900.0, "type": "buff", "toggle": true, "mods": {"dmg_done": 0.15, "dmg_taken": -0.1}}}],
		"desc": "让暗影从里到外重塑身躯：造成的伤害提高15%，受到的伤害降低10%，持续15分钟。再次施放可取消。"}
	s["cold_blood"] = {"name": "冷血", "class": "rogue", "icon": "eviscerate", "color": Color("ff4040"), "cost": 0, "cd": 120.0, "gcd": 0.0, "target": "enemy", "range": 30.0, "talent": true,
		"effects": [{"type": "energize", "amount": 60}, {"type": "combo", "n": 2}],
		"desc": "让心跳慢下来：立即恢复60点能量，并为当前目标累积2个连击点数。冷却2分钟。"}
	s["blade_flurry"] = {"name": "剑刃乱舞", "class": "rogue", "icon": "evade", "color": Color("f0c040"), "cost": 25, "cd": 120.0, "target": "self", "talent": true,
		"effects": [{"type": "self_aura", "aura": {"id": "blade_flurry", "name": "剑刃乱舞", "icon": "evade", "color": Color("f0c040"), "dur": 15.0, "type": "buff", "mods": {"attack_speed": 0.2, "dmg_done": 0.1}}}],
		"desc": "双刃转起：攻击速度提高20%，造成的伤害提高10%，持续15秒。冷却2分钟。"}
	s["aimed_shot"] = {"name": "瞄准射击", "class": "gunner", "icon": "aimed_shot", "color": Color("ffd080"), "school": "physical", "cost": 30, "cast": 3.0, "cd": 6.0, "target": "enemy", "range": 35.0, "min_range": 5.0, "talent": true,
		"requires": {"ranged_weapon": true}, "projectile": {"speed": 60.0, "color": Color("ffe080"), "size": 0.14, "kind": "bullet"},
		"effects": [{"type": "ranged", "pct": 1.6, "bonus": 10, "rap_coef": 0.15}],
		"desc": "用三秒的耐心压出一颗子弹：造成160%远程武器伤害外加{e0.bonus}点伤害与远程攻击强度加成。"}
	s["arcano_overload"] = {"name": "魔导过载", "class": "gunner", "icon": "gear", "color": Color("e0a050"), "cost": 30, "cd": 120.0, "target": "self", "talent": true,
		"effects": [{"type": "self_aura", "aura": {"id": "arcano_overload", "name": "魔导过载", "icon": "gear", "color": Color("e0a050"), "dur": 15.0, "type": "buff", "mods": {"attack_speed": 0.25, "cast_speed": 0.15}}}],
		"desc": "把安全阀拧到底：攻击速度提高25%，施法速度提高15%，持续15秒。冷却2分钟。"}

	# ------------------------------------------------------------ 宠物与同伴
	s["pet_bite"] = {"name": "撕咬", "icon": "fang", "color": Color("c08040"), "school": "physical", "cost": 0, "cd": 6.0, "target": "enemy", "range": 5.0,
		"effects": [{"type": "damage", "min": 5, "max": 9, "level_scale": 1.0}], "desc": ""}
	s["pet_growl"] = {"name": "低吼", "icon": "shout", "color": Color("c08040"), "cost": 0, "cd": 8.0, "target": "enemy", "range": 20.0,
		"effects": [{"type": "taunt"}], "desc": ""}
	s["npc_taunt"] = {"name": "嘲讽", "icon": "shout", "color": Color("e04040"), "cd": 8.0, "target": "enemy", "range": 20.0, "effects": [{"type": "taunt"}], "desc": ""}
	s["npc_shield_slam"] = {"name": "盾牌猛击", "icon": "shield", "color": Color("c0c0e0"), "cd": 6.0, "target": "enemy", "range": 5.0, "school": "physical",
		"effects": [{"type": "damage", "min": 18, "max": 26, "level_scale": 1.6}], "threat_bonus": 80, "desc": ""}
	s["npc_thunder"] = {"name": "雷霆一击", "icon": "nova", "color": Color("80a0ff"), "cd": 8.0, "target": "none", "school": "physical",
		"effects": [{"type": "aoe", "radius": 8.0, "min": 10, "max": 14, "level_scale": 1.0}], "vfx": "nova", "threat_bonus": 60, "desc": ""}
	s["npc_heal"] = {"name": "治疗术", "icon": "heal", "color": Color("ffffa0"), "school": "holy", "cast": 2.0, "target": "friend", "range": 40.0,
		"effects": [{"type": "heal", "min": 60, "max": 80, "level_scale": 5.0}], "vfx": "heal", "desc": ""}
	s["npc_renew"] = {"name": "恢复", "icon": "renew", "color": Color("a0ffa0"), "target": "friend", "range": 40.0, "cd": 3.0,
		"effects": [{"type": "aura", "aura": {"id": "renew_npc", "name": "恢复", "icon": "renew", "color": Color("a0ffa0"), "dur": 12.0, "type": "buff", "tick": {"interval": 3.0, "heal": 20, "level_scale": 2.0}}}], "desc": ""}
	s["npc_smite"] = {"name": "惩击", "icon": "holy", "color": Color("ffe080"), "school": "holy", "cast": 2.0, "target": "enemy", "range": 30.0,
		"effects": [{"type": "damage", "min": 20, "max": 26, "level_scale": 2.0}], "vfx": "holyhit", "desc": ""}
	s["npc_arrow"] = {"name": "瞄准射击", "icon": "bow", "color": Color("c0a070"), "school": "physical", "cast": 1.5, "cd": 4.0, "target": "enemy", "range": 35.0,
		"projectile": {"speed": 50.0, "color": Color("e0d0a0"), "size": 0.12, "kind": "arrow"},
		"effects": [{"type": "damage", "min": 30, "max": 42, "level_scale": 2.5}], "desc": ""}
	s["npc_multishot"] = {"name": "多重射击", "icon": "missiles", "color": Color("c0a070"), "school": "physical", "cd": 9.0, "target": "enemy", "range": 35.0,
		"effects": [{"type": "aoe", "radius": 8.0, "center": "target", "min": 18, "max": 24, "level_scale": 1.5}], "desc": ""}

	# ------------------------------------------------------------ 怪物技能
	s["mob_bite"] = {"name": "撕咬", "icon": "fang", "school": "physical", "cd": 8.0, "target": "enemy", "range": 5.0,
		"effects": [{"type": "weapon", "bonus": 2, "level_scale": 0.6}], "desc": ""}
	s["mob_rabies"] = {"name": "撕裂伤口", "icon": "bleed", "school": "physical", "cd": 14.0, "target": "enemy", "range": 5.0,
		"effects": [{"type": "aura", "aura": {"id": "mob_bleed", "name": "撕裂伤口", "icon": "bleed", "color": Color("b02020"), "dur": 9.0, "type": "debuff", "tick": {"interval": 3.0, "dmg": 2, "level_scale": 0.6, "school": "physical"}}}], "desc": ""}
	s["mob_firebolt"] = {"name": "火焰箭", "icon": "fire", "school": "fire", "cast": 2.0, "cd": 3.0, "target": "enemy", "range": 30.0,
		"projectile": {"speed": 22.0, "color": Color("ff8030"), "size": 0.25},
		"effects": [{"type": "damage", "min": 6, "max": 9, "level_scale": 1.5}], "desc": ""}
	s["mob_frostbolt"] = {"name": "寒冰箭", "icon": "frost", "school": "frost", "cast": 2.0, "cd": 3.0, "target": "enemy", "range": 30.0,
		"projectile": {"speed": 22.0, "color": Color("a0e0ff"), "size": 0.25},
		"effects": [{"type": "damage", "min": 5, "max": 8, "level_scale": 1.3}, {"type": "aura", "aura": {"id": "chilled", "name": "冰冻", "icon": "frost", "color": Color("80d0ff"), "dur": 4.0, "type": "debuff", "mods": {"speed": -0.3}}}], "desc": ""}
	s["mob_lightning"] = {"name": "闪电箭", "icon": "nature", "school": "nature", "cast": 2.0, "cd": 3.0, "target": "enemy", "range": 30.0,
		"projectile": {"speed": 40.0, "color": Color("a0c0ff"), "size": 0.2},
		"effects": [{"type": "damage", "min": 6, "max": 9, "level_scale": 1.5}], "desc": ""}
	s["mob_shadowbolt"] = {"name": "暗影箭", "icon": "shadow", "school": "shadow", "cast": 2.2, "cd": 3.0, "target": "enemy", "range": 30.0,
		"projectile": {"speed": 22.0, "color": Color("a060ff"), "size": 0.28},
		"effects": [{"type": "damage", "min": 7, "max": 10, "level_scale": 1.6}], "desc": ""}
	s["mob_heal"] = {"name": "治疗波", "icon": "heal", "school": "nature", "cast": 2.0, "cd": 12.0, "target": "self_or_ally", "range": 30.0,
		"effects": [{"type": "heal", "min": 20, "max": 26, "level_scale": 4.0}], "vfx": "heal", "desc": ""}
	s["mob_shoot"] = {"name": "射击", "icon": "gun", "school": "physical", "cd": 2.5, "target": "enemy", "range": 30.0, "min_range": 0.0,
		"projectile": {"speed": 55.0, "color": Color("ffe080"), "size": 0.1, "kind": "bullet"},
		"effects": [{"type": "damage", "min": 4, "max": 7, "level_scale": 1.2}], "desc": ""}
	s["mob_throw"] = {"name": "投掷", "icon": "axe", "school": "physical", "cd": 3.0, "target": "enemy", "range": 25.0,
		"projectile": {"speed": 26.0, "color": Color("c0a080"), "size": 0.2, "kind": "spear"},
		"effects": [{"type": "damage", "min": 4, "max": 7, "level_scale": 1.2}], "desc": ""}
	s["mob_web"] = {"name": "蛛网", "icon": "web", "school": "nature", "cd": 15.0, "target": "enemy", "range": 20.0,
		"projectile": {"speed": 20.0, "color": Color("f0f0f0"), "size": 0.3},
		"effects": [{"type": "aura", "aura": {"id": "web", "name": "蛛网", "icon": "web", "color": Color("f0f0f0"), "dur": 4.0, "type": "debuff", "root": true}}], "desc": ""}
	s["mob_poison"] = {"name": "毒液", "icon": "poison", "school": "nature", "cd": 10.0, "target": "enemy", "range": 5.0,
		"effects": [{"type": "aura", "aura": {"id": "mob_poison", "name": "毒液", "icon": "poison", "color": Color("60c040"), "dur": 12.0, "type": "debuff", "tick": {"interval": 3.0, "dmg": 2, "level_scale": 0.7, "school": "nature"}}}], "desc": ""}
	s["mob_charge"] = {"name": "冲撞", "icon": "charge", "school": "physical", "cd": 18.0, "target": "enemy", "range": 25.0, "min_range": 8.0,
		"effects": [{"type": "charge", "stun": 1.5}], "desc": ""}
	s["mob_cleave"] = {"name": "顺劈斩", "icon": "axe", "school": "physical", "cd": 9.0, "target": "enemy", "range": 6.0,
		"effects": [{"type": "aoe", "radius": 6.0, "center": "target", "min": 6, "max": 10, "level_scale": 1.6, "frontal": true}], "vfx": "slash", "desc": ""}
	s["mob_stomp"] = {"name": "践踏", "icon": "nova", "school": "physical", "cd": 16.0, "target": "none", "cast": 1.5,
		"effects": [{"type": "aoe", "radius": 8.0, "min": 8, "max": 12, "level_scale": 1.6, "aura": {"id": "stomp", "name": "践踏", "icon": "nova", "color": Color("c0a070"), "dur": 2.0, "type": "debuff", "stun": true}}], "vfx": "nova", "telegraph": 8.0, "desc": ""}
	s["mob_enrage"] = {"name": "激怒", "icon": "shout", "cd": 120.0, "target": "self", "hp_below": 0.3,
		"effects": [{"type": "self_aura", "aura": {"id": "enrage", "name": "激怒", "icon": "shout", "color": Color("ff3030"), "dur": 30.0, "type": "buff", "mods": {"attack_speed": 0.4, "dmg_done": 0.2}}}], "desc": ""}
	s["mob_bomb"] = {"name": "魔导炸弹", "icon": "explosion", "school": "fire", "cd": 10.0, "target": "ground_enemy", "range": 30.0, "cast": 0.5,
		"effects": [{"type": "ground_aoe", "radius": 5.0, "delay": 2.2, "min": 14, "max": 20, "level_scale": 2.2}], "desc": ""}
	s["mob_roots"] = {"name": "缠绕根须", "icon": "nature", "school": "nature", "cd": 14.0, "target": "enemy", "range": 30.0, "cast": 1.5,
		"effects": [{"type": "aura", "aura": {"id": "roots", "name": "缠绕根须", "icon": "nature", "color": Color("60a040"), "dur": 5.0, "type": "debuff", "root": true, "tick": {"interval": 1.0, "dmg": 2, "level_scale": 0.4, "school": "nature"}}}], "desc": ""}
	s["mob_summon"] = {"name": "召唤", "icon": "nature", "cd": 25.0, "target": "self", "cast": 2.0, "effects": [{"type": "summon_adds"}], "desc": ""}
	s["mob_whirl"] = {"name": "旋风斩", "icon": "axe", "school": "physical", "cd": 18.0, "target": "none", "cast": 1.5,
		"effects": [{"type": "aoe", "radius": 8.0, "min": 14, "max": 20, "level_scale": 1.8}], "vfx": "nova", "telegraph": 8.0, "desc": ""}
	s["mob_bell"] = {"name": "丧钟回响", "icon": "shadow", "school": "shadow", "cd": 20.0, "target": "none", "range": 40.0, "cast": 3.0,
		"effects": [{"type": "aoe", "radius": 40.0, "min": 16, "max": 22, "level_scale": 1.8}], "vfx": "shadownova", "desc": "", "telegraph_far": true}
	s["mob_shield"] = {"name": "防护屏障", "icon": "pwshield", "cd": 30.0, "target": "self", "hp_below": 0.6,
		"effects": [{"type": "self_aura", "aura": {"id": "mob_shield", "name": "防护屏障", "icon": "pwshield", "color": Color("80c0ff"), "dur": 10.0, "type": "buff", "absorb": 60, "absorb_scale": 8.0}}], "desc": ""}
	s["mob_wind"] = {"name": "狂风", "icon": "wind", "school": "nature", "cd": 12.0, "target": "enemy", "range": 30.0, "cast": 1.5,
		"projectile": {"speed": 26.0, "color": Color("d0ffe0"), "size": 0.35},
		"effects": [{"type": "damage", "min": 9, "max": 13, "level_scale": 1.6}, {"type": "knockback", "force": 6.0}], "desc": ""}
	s["mob_pinch"] = {"name": "钳击", "icon": "claw", "school": "physical", "cd": 7.0, "target": "enemy", "range": 5.0,
		"effects": [{"type": "weapon", "bonus": 4, "level_scale": 0.6}], "desc": ""}
	s.merge(DataJobSpells.spells(), true)
	# Advancement replaces combat skills, while unadvanced characters keep a modest starter kit.
	for sid in s:
		var sp: Dictionary = s[sid]
		if sp.has("class") and not sp.has("requires_spec"):
			for ei in sp.get("effects", []).size():
				var e: Dictionary = sp["effects"][ei]
				if e.get("type", "") in ["damage", "aoe"]:
					var scale_damage := maxf(float(e.get("min", 0)), float(e.get("max", 0))) > 80.0
					if scale_damage:
						for separator in ["-", "–", "到"]:
							sp["desc"] = str(sp.get("desc", "")).replace("%s%s%s" % [str(e.get("min", 0)), separator, str(e.get("max", 0))], "{e%d.min}%s{e%d.max}" % [ei, separator, ei])
					for key in ["min", "max", "per_charge", "per_holy_mark", "per_shadow_mark"]:
						if e.has(key) and scale_damage:
							e[key] = roundf(float(e[key]) * 0.18)
				if e.get("type", "") == "weapon" and float(e.get("bonus", 0)) > 80:
					e["bonus"] = roundf(float(e["bonus"]) * 0.18)
				if e.get("type", "") == "finisher_damage":
					for pair in e.get("per_cp", []):
						for i in pair.size():
							pair[i] = roundf(float(pair[i]) * 0.18)
				if e.get("type", "") == "finisher_aura_scaled":
					for i in e.get("damages", []).size():
						e["damages"][i] = roundf(float(e["damages"][i]) * 0.18)
				var aura: Dictionary = e.get("aura", {})
				if aura.get("tick", {}).get("dmg", 0) > 30:
					aura["tick"]["dmg"] = roundf(float(aura["tick"]["dmg"]) * 0.18)
		# Local timing applies to attacks only; displacement and defensive skills remain immediate.
		if sp.has("requires_spec") and not sp.has("windup") and not sp.has("cast") and not sp.has("channel"):
			for e in sp.get("effects", []):
				if e.get("type", "") in ["weapon", "finisher_damage"]:
					sp["windup"] = 0.14
					sp["recovery"] = 0.28
		# Boss casts expose their own interruptibility. Telegraph attacks bypass roll immunity.
		if sid in ["mob_stomp", "mob_whirl", "mob_bell", "mob_bomb"]:
			sp["mechanic"] = true
			sp["interruptible"] = sid == "mob_bell"
	s["dodge_roll"]["effects"][0].merge({"invincible_frames": 0.18, "distance": 3.8}, true)
	s["dodge_roll"]["requires"] = {"stamina_min": 30.0}
	s["dodge_roll"]["desc"] = "消耗耐力沿输入方向翻滚3.8码，0.18秒短闪避窗口；无法免疫持续伤害或首领范围机制。"
	s["evasion"]["effects"][0]["aura"]["mods"]["dodge"] = 0.15
	s["evasion"]["desc"] = "躲闪几率提高15%，持续10秒；不影响首领范围伤害。"
	s["vanish"]["effects"][1]["aura"].erase("invincible")
	s["vanish"]["desc"] = "短暂进入潜行5秒，保留首领仇恨；不提供伤害免疫，受伤或攻击会解除。"
	s["sprint"]["effects"][0]["aura"]["mods"]["speed"] = 0.25
	s["sprint"]["desc"] = "移动速度提高25%，持续8秒。"
	s["charge"]["effects"] = [{"type": "charge", "max_distance": 12.0, "stun": 1.0, "rage": 20}, {"type": "momentum", "amount": 15}]
	s["charge"]["range"] = 12.0
	s["charge"]["desc"] = "沿可通行路径冲向目标，最多12码；产生20怒气、15势能。普通敌人昏迷1秒，首领免疫。"
	s["blink"]["desc"] = "沿可通行路径向前闪移，最多6码；不能穿墙或跨层，无伤害免疫。"
	s["recoil_jump"]["desc"] = "沿地面后撤4码；不能穿墙，无伤害免疫。"
	for sid in s:
		for e in s[sid].get("effects", []):
			var a: Dictionary = e.get("aura", {})
			if a.get("type", "") == "debuff" and not sid.begins_with("mob_") and a.get("tick", {}).get("school", "") in ["nature", "shadow", "frost"]:
				a["dispel"] = true
	return s
