class_name DataMobs
extends RefCounted
## 怪物与生物数据

static func mobs() -> Dictionary:
	var m := {}
	# ================= 晨露谷 · 晨钟修道院 (1-5)
	m["young_wolf"] = {"name": "幼狼", "model": "wolf", "lvl": [1, 2], "fam": "wolf", "type": "beast", "color": Color("8a8580"), "color2": Color("d8d0c8"), "scale": 0.8,
		"loot": {"junk": ["j_wolf_fang", "j_wolf_pelt"], "mat": "mat_leather"}, "spells": []}
	m["timber_wolf"] = {"name": "森林狼", "model": "wolf", "lvl": [2, 3], "fam": "wolf", "type": "beast", "color": Color("6a5a4a"), "color2": Color("c8b8a0"), "scale": 0.95,
		"loot": {"junk": ["j_wolf_fang", "j_wolf_pelt"], "mat": "mat_leather"}, "spells": ["mob_bite"]}
	m["jelly_slime"] = {"name": "果冻史莱姆", "model": "slime", "lvl": [2, 3], "fam": "slime", "type": "elemental", "color": Color("80e0a0"), "scale": 1.0, "neutral": true,
		"loot": {"junk": ["j_jelly"]}, "speed": 4.5}
	m["ratman_worker"] = {"name": "掘地鼠人苦工", "model": "ratman", "lvl": [3, 4], "fam": "ratman", "type": "humanoid", "color": Color("8a7058"), "color2": Color("e0c080"), "scale": 0.85,
		"loot": {"junk": ["j_rat_candle", "j_dirty_cloth"], "humanoid": true}, "flee": true, "weapon": "pick"}
	m["bandit_thug_s"] = {"name": "灰巾帮小喽啰", "model": "humanoid", "lvl": [4, 5], "fam": "bandit", "type": "humanoid", "color": Color("6a6a70"), "color2": Color("8a8a8a"),
		"loot": {"junk": ["j_gray_bandana", "j_dirty_cloth"], "humanoid": true}, "flee": true, "weapon": "dagger", "outfit": "bandit"}
	m["garrok"] = {"name": "加洛克", "sub": "灰巾帮头目", "model": "humanoid", "lvl": [6, 6], "fam": "bandit", "type": "humanoid", "color": Color("4a4a50"), "color2": Color("a03030"),
		"hp_mul": 1.6, "dmg_mul": 1.3, "scale": 1.15, "named": true, "respawn": 120.0, "loot": {"junk": ["j_gray_bandana"], "humanoid": true, "green": 0.4},
		"weapon": "sword", "outfit": "bandit_boss", "spells": ["mob_cleave"]}
	m["rabbit"] = {"name": "野兔", "model": "rabbit", "lvl": [1, 1], "fam": "critter", "type": "critter", "color": Color("b09070"), "critter": true, "neutral": true,
		"loot": {"junk": ["j_rabbit_foot"]}, "speed": 5.0}
	m["deer"] = {"name": "小鹿", "model": "deer", "lvl": [1, 1], "fam": "critter", "type": "critter", "color": Color("c08a5a"), "critter": true, "neutral": true, "speed": 8.0,
		"loot": {}}
	# ================= 晨露谷 · 金穗镇周边 (5-10)
	m["boar"] = {"name": "石牙野猪", "model": "boar", "lvl": [5, 6], "fam": "boar", "type": "beast", "color": Color("7a5a48"), "color2": Color("f0e8d0"),
		"loot": {"junk": ["j_boar_tusk"], "mat": "mat_leather"}, "spells": ["mob_charge"]}
	m["rot_boar"] = {"name": "石牙野猪王", "sub": "稀有", "model": "boar", "lvl": [8, 8], "fam": "boar", "type": "beast", "color": Color("5a4038"), "color2": Color("ffffff"),
		"scale": 1.5, "rare": true, "hp_mul": 2.2, "dmg_mul": 1.4, "respawn": 600.0, "loot": {"junk": ["j_boar_tusk"], "items": ["r_tusk_ring"]}, "spells": ["mob_charge", "mob_stomp"]}
	m["prowler"] = {"name": "林地潜猎狼", "model": "wolf", "lvl": [7, 8], "fam": "wolf", "type": "beast", "color": Color("4a4a4a"), "color2": Color("9a9a9a"), "scale": 1.05,
		"loot": {"junk": ["j_wolf_fang", "j_wolf_pelt"], "mat": "mat_leather"}, "spells": ["mob_bite", "mob_rabies"]}
	m["greymane"] = {"name": "灰鬃", "sub": "稀有", "model": "wolf", "lvl": [6, 6], "fam": "wolf", "type": "beast", "color": Color("b0b0b8"), "color2": Color("ffffff"),
		"scale": 1.35, "rare": true, "hp_mul": 2.0, "dmg_mul": 1.3, "respawn": 600.0, "loot": {"junk": ["j_wolf_pelt"], "items": ["r_greymane_cloak"]}, "spells": ["mob_bite", "mob_rabies"]}
	m["ratman_digger"] = {"name": "掘地鼠人挖掘工", "model": "ratman", "lvl": [6, 7], "fam": "ratman", "type": "humanoid", "color": Color("7a6048"), "color2": Color("d0a060"),
		"loot": {"junk": ["j_rat_candle", "j_dirty_cloth"], "humanoid": true, "mat2": "mat_copper"}, "flee": true, "weapon": "pick"}
	m["ratman_geomancer"] = {"name": "掘地鼠人地卜师", "model": "ratman", "lvl": [7, 8], "fam": "ratman", "type": "humanoid", "color": Color("6a5a70"), "color2": Color("a080d0"),
		"loot": {"junk": ["j_rat_candle"], "humanoid": true}, "caster": "mob_firebolt", "weapon": "staff", "hp_mul": 0.85}
	m["ratman_foreman"] = {"name": "掘地鼠人监工", "model": "ratman", "lvl": [8, 8], "fam": "ratman", "type": "humanoid", "color": Color("5a4a38"), "color2": Color("ffd040"),
		"scale": 1.05, "loot": {"junk": ["j_rat_candle"], "humanoid": true}, "weapon": "mace", "spells": ["mob_enrage"]}
	m["grizzik"] = {"name": "格里奇", "sub": "鼠人大头目", "model": "ratman", "lvl": [9, 9], "fam": "ratman", "type": "humanoid", "color": Color("4a3a30"), "color2": Color("ffd040"),
		"scale": 1.35, "named": true, "hp_mul": 1.8, "dmg_mul": 1.3, "respawn": 180.0, "loot": {"junk": ["j_rat_candle"], "humanoid": true, "green": 0.5}, "weapon": "pick", "spells": ["mob_stomp", "mob_enrage"]}
	m["bandit_thug"] = {"name": "灰巾帮暴徒", "model": "humanoid", "lvl": [7, 8], "fam": "bandit", "type": "humanoid", "color": Color("5a5a62"), "color2": Color("8a8a8a"),
		"loot": {"junk": ["j_gray_bandana", "j_dirty_cloth"], "humanoid": true}, "flee": true, "weapon": "sword", "outfit": "bandit"}
	m["bandit_rogue"] = {"name": "灰巾帮扒手", "model": "humanoid", "lvl": [8, 9], "fam": "bandit", "type": "humanoid", "color": Color("3a3a42"), "color2": Color("6a6a6a"),
		"loot": {"junk": ["j_gray_bandana"], "humanoid": true}, "flee": true, "weapon": "dagger", "outfit": "bandit", "atk_speed": 1.6, "dmg_mul": 0.8}
	m["bandit_apprentice"] = {"name": "灰巾帮魔导学徒", "model": "humanoid", "lvl": [8, 9], "fam": "bandit", "type": "humanoid", "color": Color("5a4a6a"), "color2": Color("8a7aa0"),
		"loot": {"junk": ["j_gray_bandana"], "humanoid": true}, "caster": "mob_frostbolt", "weapon": "staff", "outfit": "bandit_mage", "hp_mul": 0.85}
	m["stark"] = {"name": "斯塔克", "sub": "灰巾帮队长", "model": "humanoid", "lvl": [10, 10], "fam": "bandit", "type": "humanoid", "color": Color("2a2a30"), "color2": Color("a02020"),
		"scale": 1.15, "named": true, "hp_mul": 1.9, "dmg_mul": 1.3, "respawn": 180.0, "loot": {"junk": ["j_gray_bandana"], "humanoid": true, "green": 0.6},
		"weapon": "sword2", "outfit": "bandit_boss", "spells": ["mob_cleave", "mob_enrage"]}
	m["frogman_scout"] = {"name": "潮蛙人斥候", "model": "frogman", "lvl": [5, 6], "fam": "frog", "type": "humanoid", "color": Color("5a9a7a"), "color2": Color("e0d090"),
		"loot": {"junk": ["j_frog_scale"]}, "flee": true, "weapon": "spear", "speed": 7.5}
	m["frogman_fisher"] = {"name": "潮蛙人渔夫", "model": "frogman", "lvl": [6, 7], "fam": "frog", "type": "humanoid", "color": Color("4a8a9a"), "color2": Color("e0d090"),
		"loot": {"junk": ["j_frog_scale"]}, "flee": true, "weapon": "spear", "spells": ["mob_throw"]}
	m["frogman_priest"] = {"name": "潮蛙人潮汐祭司", "model": "frogman", "lvl": [7, 8], "fam": "frog", "type": "humanoid", "color": Color("6a6ab0"), "color2": Color("f0e0a0"),
		"loot": {"junk": ["j_frog_scale"]}, "caster": "mob_lightning", "spells": ["mob_heal"], "weapon": "staff", "hp_mul": 0.85}
	m["gurglu"] = {"name": "咕噜鲁", "sub": "老蛙王", "model": "frogman", "lvl": [9, 9], "fam": "frog", "type": "humanoid", "color": Color("3a7a5a"), "color2": Color("ffd040"),
		"scale": 1.45, "named": true, "hp_mul": 1.8, "dmg_mul": 1.25, "respawn": 180.0, "loot": {"junk": ["j_frog_scale"], "green": 0.5}, "weapon": "spear", "spells": ["mob_lightning", "mob_heal"]}
	m["forest_spider"] = {"name": "林蛛", "model": "spider", "lvl": [6, 7], "fam": "spider", "type": "beast", "color": Color("4a3a3a"), "color2": Color("a04040"),
		"loot": {"junk": ["j_spider_silk"]}, "spells": ["mob_poison", "mob_web"]}
	m["weaver"] = {"name": "织网者薇丝", "sub": "林蛛母后", "model": "spider", "lvl": [9, 9], "fam": "spider", "type": "beast", "color": Color("2a1a2a"), "color2": Color("e04080"),
		"scale": 1.8, "named": true, "hp_mul": 1.8, "dmg_mul": 1.25, "respawn": 180.0, "loot": {"junk": ["j_spider_silk"], "green": 0.5}, "spells": ["mob_poison", "mob_web"]}
	m["grizzly"] = {"name": "灰熊", "model": "bear", "lvl": [8, 9], "fam": "bear", "type": "beast", "color": Color("6a5040"), "color2": Color("4a3a30"),
		"hp_mul": 1.1, "loot": {"junk": ["j_bear_paw"], "mat": "mat_leather"}, "spells": ["mob_stomp"]}
	m["rogue_golem"] = {"name": "失控的魔导傀儡", "model": "golem", "lvl": [8, 10], "fam": "golem", "type": "mechanical", "color": Color("a08a60"), "color2": Color("60c0ff"),
		"loot": {"junk": ["j_gear"], "mat2": "mat_aether"}, "speed": 6.0, "atk_speed": 2.6, "dmg_mul": 1.15}
	m["gear_spider"] = {"name": "齿轮蜘蛛", "model": "spider", "lvl": [8, 9], "fam": "golem", "type": "mechanical", "color": Color("9a9080"), "color2": Color("ffb040"), "metal": true, "scale": 0.8,
		"loot": {"junk": ["j_gear"]}, "spells": ["mob_shoot"]}
	m["mk0"] = {"name": "原型机 MK-0", "sub": "稀有精英", "model": "golem", "lvl": [10, 10], "fam": "golem", "type": "mechanical", "color": Color("c0a040"), "color2": Color("ff4040"),
		"scale": 1.6, "rare": true, "elite": true, "hp_mul": 1.2, "respawn": 300.0, "loot": {"junk": ["j_gear"], "items": ["b_mk0_core"], "green": 1.0}, "spells": ["mob_stomp", "mob_bomb"]}
	m["hyena_warrior"] = {"name": "狂牙鬣人", "model": "hyena", "lvl": [8, 9], "fam": "hyena", "type": "humanoid", "color": Color("b09060"), "color2": Color("5a4030"),
		"loot": {"junk": ["j_hyena_charm"], "humanoid": true}, "flee": true, "weapon": "axe"}
	m["hyena_thrower"] = {"name": "狂牙鬣人投矛手", "model": "hyena", "lvl": [9, 10], "fam": "hyena", "type": "humanoid", "color": Color("a08050"), "color2": Color("6a4a30"),
		"loot": {"junk": ["j_hyena_charm"], "humanoid": true}, "ranged": "mob_throw", "weapon": "spear"}
	m["grok"] = {"name": "格罗克", "sub": "狂牙之王", "model": "hyena", "lvl": [11, 11], "fam": "hyena", "type": "humanoid", "color": Color("8a6a40"), "color2": Color("c03020"),
		"scale": 1.6, "elite": true, "named": true, "hp_mul": 1.0, "respawn": 300.0, "loot": {"junk": ["j_hyena_charm"], "items": ["b_grok_axe"], "green": 0.8, "humanoid": true},
		"weapon": "axe2", "spells": ["mob_cleave", "mob_enrage", "mob_charge"]}
	# ================= 潮风高地 (10-15)
	m["reef_crab"] = {"name": "礁石蟹", "model": "crab", "lvl": [10, 11], "fam": "crab", "type": "beast", "color": Color("d06040"), "color2": Color("f0d0a0"),
		"loot": {"junk": ["j_crab_shell"]}, "spells": ["mob_pinch"], "armor_mul": 1.6}
	m["giant_crab"] = {"name": "巨钳蟹", "model": "crab", "lvl": [11, 12], "fam": "crab", "type": "beast", "color": Color("b04030"), "color2": Color("f0c090"), "scale": 1.4,
		"loot": {"junk": ["j_crab_shell"]}, "spells": ["mob_pinch", "mob_stomp"], "armor_mul": 1.8}
	m["highland_wolf"] = {"name": "高地狼", "model": "wolf", "lvl": [10, 11], "fam": "wolf", "type": "beast", "color": Color("9a8a70"), "color2": Color("e0d8c0"), "scale": 1.1,
		"loot": {"junk": ["j_wolf_fang", "j_wolf_pelt"], "mat": "mat_leather"}, "spells": ["mob_bite"]}
	m["highland_boar"] = {"name": "高地野猪", "model": "boar", "lvl": [11, 12], "fam": "boar", "type": "beast", "color": Color("6a4a3a"), "color2": Color("f0e8d0"), "scale": 1.15,
		"loot": {"junk": ["j_boar_tusk"], "mat": "mat_leather"}, "spells": ["mob_charge"]}
	m["scarecrow"] = {"name": "疯长的稻草人", "model": "scarecrow", "lvl": [11, 12], "fam": "scarecrow", "type": "elemental", "color": Color("d0b060"), "color2": Color("6a5a8a"),
		"loot": {"junk": ["j_straw"]}, "speed": 6.0, "spells": ["mob_roots"]}
	m["arsonist"] = {"name": "灰巾帮纵火犯", "model": "humanoid", "lvl": [11, 12], "fam": "bandit", "type": "humanoid", "color": Color("6a4a3a"), "color2": Color("ff8030"),
		"loot": {"junk": ["j_gray_bandana"], "humanoid": true, "mat_cloth2": true}, "flee": true, "caster": "mob_firebolt", "weapon": "torch", "outfit": "bandit"}
	m["bandit_sentry"] = {"name": "灰巾帮哨兵", "model": "humanoid", "lvl": [12, 13], "fam": "bandit", "type": "humanoid", "color": Color("4a4a52"), "color2": Color("7a7a7a"),
		"loot": {"junk": ["j_gray_bandana"], "humanoid": true, "mat_cloth2": true}, "flee": true, "weapon": "sword", "outfit": "bandit_armored", "spells": ["mob_cleave"]}
	m["bandit_gunner"] = {"name": "灰巾帮火枪手", "model": "humanoid", "lvl": [12, 13], "fam": "bandit", "type": "humanoid", "color": Color("5a4a3a"), "color2": Color("8a7a6a"),
		"loot": {"junk": ["j_gray_bandana"], "humanoid": true, "mat_cloth2": true}, "ranged": "mob_shoot", "weapon": "gun", "outfit": "bandit"}
	m["bandit_tech"] = {"name": "灰巾帮魔导技师", "model": "humanoid", "lvl": [13, 13], "fam": "bandit", "type": "humanoid", "color": Color("4a5a6a"), "color2": Color("e0a040"),
		"loot": {"junk": ["j_gear"], "humanoid": true, "mat_cloth2": true}, "caster": "mob_lightning", "spells": ["mob_bomb"], "weapon": "wrench", "outfit": "bandit_mage", "hp_mul": 0.9}
	m["varga"] = {"name": "瓦尔加", "sub": "铁腕", "model": "humanoid", "lvl": [14, 14], "fam": "bandit", "type": "humanoid", "color": Color("3a3a42"), "color2": Color("b02020"),
		"scale": 1.25, "named": true, "hp_mul": 2.0, "dmg_mul": 1.3, "respawn": 180.0, "loot": {"junk": ["j_gray_bandana"], "humanoid": true, "green": 0.7},
		"weapon": "mace2", "outfit": "bandit_boss", "spells": ["mob_whirl", "mob_enrage"]}
	m["rust_golem"] = {"name": "锈蚀的魔导傀儡", "model": "golem", "lvl": [12, 14], "fam": "golem", "type": "mechanical", "color": Color("8a6a50"), "color2": Color("ff9040"),
		"loot": {"junk": ["j_gear"], "mat2": "mat_aether"}, "speed": 6.0, "atk_speed": 2.6, "dmg_mul": 1.15, "spells": ["mob_stomp"]}
	m["steam_spider"] = {"name": "蒸汽蜘蛛", "model": "spider", "lvl": [12, 13], "fam": "golem", "type": "mechanical", "color": Color("8a8a90"), "color2": Color("ff6040"), "metal": true,
		"loot": {"junk": ["j_gear"]}, "spells": ["mob_shoot"]}
	m["harpy"] = {"name": "风鸣鸟妖", "model": "harpy", "lvl": [13, 14], "fam": "harpy", "type": "humanoid", "color": Color("a0b0d0"), "color2": Color("e0c0a0"),
		"loot": {"junk": ["j_feather"], "humanoid": true}, "spells": ["mob_rabies"], "speed": 8.0}
	m["harpy_witch"] = {"name": "风鸣巫母", "model": "harpy", "lvl": [14, 14], "fam": "harpy", "type": "humanoid", "color": Color("8070b0"), "color2": Color("f0e0c0"),
		"loot": {"junk": ["j_feather"], "humanoid": true}, "caster": "mob_wind", "hp_mul": 0.9}
	m["harpy_matron"] = {"name": "希尔维亚", "sub": "风鸣鸟妖女王", "model": "harpy", "lvl": [15, 15], "fam": "harpy", "type": "humanoid", "color": Color("6050a0"), "color2": Color("ffd040"),
		"scale": 1.45, "named": true, "hp_mul": 2.0, "dmg_mul": 1.2, "respawn": 180.0, "loot": {"junk": ["j_feather"], "green": 0.7}, "caster": "mob_wind", "spells": ["mob_whirl"]}
	m["windmill_rat"] = {"name": "田野硕鼠", "model": "rabbit", "lvl": [10, 10], "fam": "critter", "type": "critter", "color": Color("7a6a5a"), "critter": true, "neutral": true, "loot": {}}
	# ================= 余烬夜航 · 港外货栈、旧轨道与雾灯海岸 (15-20，单人主线)
	m["e_dock_runner"] = {"name": "余烬走私客", "model": "humanoid", "lvl": [15, 15], "fam": "ember", "type": "humanoid", "color": Color("63574a"), "color2": Color("b16b47"),
		"respawn": 90.0, "loot": {"junk": ["j_dirty_cloth", "j_gray_bandana"], "humanoid": true, "mat_cloth2": true, "green": 0.06}, "weapon": "dagger", "outfit": "bandit", "spells": []}
	m["e_dock_gunner"] = {"name": "护货火枪手", "model": "humanoid", "lvl": [16, 16], "fam": "ember", "type": "humanoid", "color": Color("59544b"), "color2": Color("ae7655"),
		"respawn": 90.0, "loot": {"junk": ["j_gray_bandana"], "humanoid": true, "mat_cloth2": true, "green": 0.06}, "ranged": "mob_shoot", "weapon": "gun", "outfit": "bandit", "dmg_mul": 0.9}
	m["e_dock_master"] = {"name": "柯林·赤帆", "sub": "余烬货栈主管", "model": "humanoid", "lvl": [16, 16], "fam": "ember", "type": "humanoid", "color": Color("50463f"), "color2": Color("ba6144"),
		"named": true, "hp_mul": 1.5, "dmg_mul": 1.05, "scale": 1.1, "respawn": 180.0,
		"loot": {"junk": ["j_gray_bandana"], "humanoid": true, "mat_cloth2": true, "green": 0.4}, "weapon": "sword", "outfit": "bandit_boss", "spells": ["mob_cleave"]}
	m["e_rail_guard"] = {"name": "劫轨魔导傀儡", "model": "golem", "lvl": [16, 16], "fam": "golem", "type": "mechanical", "color": Color("8e7960"), "color2": Color("dd9b59"),
		"respawn": 90.0, "loot": {"junk": ["j_gear"], "mat2": "mat_aether", "green": 0.06}, "speed": 6.0, "atk_speed": 2.6, "spells": ["mob_stomp"]}
	m["e_rail_saboteur"] = {"name": "余烬轨道破坏师", "model": "humanoid", "lvl": [17, 17], "fam": "ember", "type": "humanoid", "color": Color("5b6270"), "color2": Color("c18d4b"),
		"respawn": 90.0, "hp_mul": 0.9, "loot": {"junk": ["j_gear"], "humanoid": true, "mat_cloth2": true, "mat2": "mat_aether", "green": 0.07},
		"caster": "mob_lightning", "weapon": "wrench", "outfit": "bandit_mage", "spells": ["mob_bomb"]}
	m["e_signal_spider"] = {"name": "信号蒸汽蜘蛛", "model": "spider", "lvl": [17, 17], "fam": "golem", "type": "mechanical", "color": Color("8c8d8f"), "color2": Color("dfa365"), "metal": true,
		"respawn": 90.0, "loot": {"junk": ["j_gear"], "mat2": "mat_aether", "green": 0.06}, "spells": ["mob_shoot", "mob_web"]}
	m["e_rail_foreman"] = {"name": "赫兹·断轨", "sub": "调度破坏者", "model": "humanoid", "lvl": [17, 17], "fam": "ember", "type": "humanoid", "color": Color("4c5460"), "color2": Color("c9904d"),
		"named": true, "hp_mul": 1.55, "dmg_mul": 1.05, "scale": 1.1, "respawn": 180.0,
		"loot": {"junk": ["j_gear"], "humanoid": true, "mat_cloth2": true, "mat2": "mat_aether", "green": 0.45}, "weapon": "mace", "outfit": "bandit_boss", "spells": ["mob_bomb"]}
	m["e_coast_runner"] = {"name": "雾岸夜航搬运工", "model": "humanoid", "lvl": [18, 18], "fam": "ember", "type": "humanoid", "color": Color("59676a"), "color2": Color("a57c5d"),
		"respawn": 90.0, "loot": {"junk": ["j_dirty_cloth"], "humanoid": true, "mat_cloth2": true, "green": 0.07}, "weapon": "sword", "outfit": "bandit", "spells": []}
	m["e_tide_golem"] = {"name": "潮汐装运傀儡", "model": "golem", "lvl": [18, 18], "fam": "golem", "type": "mechanical", "color": Color("778b8b"), "color2": Color("80bfc7"),
		"respawn": 90.0, "loot": {"junk": ["j_gear"], "mat2": "mat_aether", "green": 0.07}, "speed": 6.0, "atk_speed": 2.6, "spells": ["mob_stomp"]}
	m["e_lens_keeper"] = {"name": "雾灯镜阵看守", "model": "humanoid", "lvl": [19, 19], "fam": "ember", "type": "humanoid", "color": Color("58627a"), "color2": Color("98b6c9"),
		"respawn": 90.0, "hp_mul": 0.9, "loot": {"junk": ["j_dirty_cloth"], "humanoid": true, "mat_cloth2": true, "mat2": "mat_aether", "green": 0.08},
		"caster": "mob_frostbolt", "weapon": "staff", "outfit": "bandit_mage", "spells": []}
	m["e_coast_master"] = {"name": "塞薇拉·雾灯", "sub": "夜航领航者", "model": "humanoid", "lvl": [19, 19], "fam": "ember", "type": "humanoid", "color": Color("4e5a70"), "color2": Color("bf9360"),
		"named": true, "hp_mul": 1.6, "dmg_mul": 1.05, "scale": 1.1, "respawn": 180.0,
		"loot": {"junk": ["j_gray_bandana"], "humanoid": true, "mat_cloth2": true, "mat2": "mat_aether", "green": 0.5, "items": ["b_ember_focus", "b_ember_gun"], "pick": 1},
		"ranged": "mob_shoot", "weapon": "gun", "outfit": "bandit_boss", "spells": ["mob_bomb"]}
	m["e_ember_guard"] = {"name": "余烬核心卫兵", "model": "humanoid", "lvl": [19, 19], "fam": "ember", "type": "humanoid", "color": Color("514b47"), "color2": Color("c77349"),
		"respawn": 90.0, "loot": {"junk": ["j_gray_bandana"], "humanoid": true, "mat_cloth2": true, "green": 0.08}, "weapon": "sword", "outfit": "bandit_armored", "spells": ["mob_cleave"]}
	m["e_ember_mage"] = {"name": "余烬燃芯法师", "model": "humanoid", "lvl": [20, 20], "fam": "ember", "type": "humanoid", "color": Color("63516d"), "color2": Color("de9164"),
		"respawn": 90.0, "hp_mul": 0.9, "loot": {"junk": ["j_dirty_cloth"], "humanoid": true, "mat_cloth2": true, "mat2": "mat_aether", "green": 0.08},
		"caster": "mob_firebolt", "weapon": "staff", "outfit": "bandit_mage", "spells": []}
	m["e_ember_commander"] = {"name": "雷纳德·烬誓", "sub": "余烬夜航指挥官", "model": "humanoid", "lvl": [20, 20], "fam": "ember", "type": "humanoid", "color": Color("484448"), "color2": Color("cd7950"),
		"named": true, "hp_mul": 1.75, "dmg_mul": 1.1, "scale": 1.15, "respawn": 180.0,
		"loot": {"junk": ["j_gray_bandana"], "humanoid": true, "mat_cloth2": true, "mat2": "mat_aether", "green": 0.55, "items": ["b_ember_blade", "b_ember_focus", "b_ember_gun"], "pick": 1},
		"weapon": "sword", "outfit": "bandit_boss", "spells": ["mob_cleave", "mob_bomb"]}
	# ================= 风语旧圣堂（副本，精英）
	m["d_sapling"] = {"name": "腐根树苗", "model": "treant", "lvl": [14, 14], "fam": "plant", "type": "elemental", "color": Color("6a7a3a"), "color2": Color("a0c060"), "scale": 0.6,
		"hp_mul": 0.5, "dmg_mul": 0.6, "loot": {}, "no_xp": true}
	m["d_treant"] = {"name": "腐根树妖", "model": "treant", "lvl": [14, 15], "fam": "plant", "type": "elemental", "color": Color("5a6a3a"), "color2": Color("90b050"), "elite": true,
		"loot": {"junk": ["j_rotwood"], "green": 0.12}, "spells": ["mob_roots"], "speed": 5.5}
	m["d_vine"] = {"name": "荆棘爬行者", "model": "slime", "lvl": [14, 15], "fam": "plant", "type": "elemental", "color": Color("4a7a3a"), "elite": true, "scale": 1.4,
		"loot": {"junk": ["j_rotwood"], "green": 0.12}, "spells": ["mob_poison"]}
	m["d_bandit"] = {"name": "灰巾帮精锐", "model": "humanoid", "lvl": [14, 15], "fam": "bandit_d", "type": "humanoid", "color": Color("3a3a42"), "color2": Color("a02020"), "elite": true,
		"loot": {"junk": ["j_gray_bandana"], "humanoid": true, "green": 0.12, "mat_cloth2": true}, "weapon": "sword", "outfit": "bandit_armored", "spells": ["mob_cleave"]}
	m["d_bandit_gunner"] = {"name": "灰巾帮神枪手", "model": "humanoid", "lvl": [14, 15], "fam": "bandit_d", "type": "humanoid", "color": Color("4a3a32"), "color2": Color("a02020"), "elite": true,
		"loot": {"junk": ["j_gray_bandana"], "humanoid": true, "green": 0.12}, "ranged": "mob_shoot", "weapon": "gun", "outfit": "bandit", "dmg_mul": 0.9}
	m["d_bandit_mage"] = {"name": "灰巾帮咒术师", "model": "humanoid", "lvl": [14, 15], "fam": "bandit_d", "type": "humanoid", "color": Color("4a3a5a"), "color2": Color("a060ff"), "elite": true,
		"loot": {"junk": ["j_gray_bandana"], "humanoid": true, "green": 0.12}, "caster": "mob_shadowbolt", "weapon": "staff", "outfit": "bandit_mage", "hp_mul": 0.85}
	m["d_gargoyle"] = {"name": "圣堂石像鬼", "model": "gargoyle", "lvl": [15, 15], "fam": "gargoyle", "type": "elemental", "color": Color("8a8a90"), "color2": Color("c0a0ff"), "elite": true,
		"loot": {"junk": ["j_stone_chip"], "green": 0.12}, "armor_mul": 1.5, "spells": ["mob_stomp"]}
	m["boss_rootguard"] = {"name": "厄尔班", "sub": "腐根守卫", "model": "treant", "rep": {"abbey": 300}, "lvl": [15, 15], "fam": "boss", "type": "elemental", "color": Color("4a5a2a"), "color2": Color("c0e060"),
		"scale": 2.3, "boss": true, "elite": true, "hp_mul": 2.6, "dmg_mul": 1.15, "leash": 34.0, "respawn": 0.0, "adds": "d_sapling",
		"ember_flag": "sanctum_ember_root", "ember_name": "腐根火种",
		"loot": {"items": ["b_rootguard_staff", "b_rootguard_cloak", "b_rootguard_bracer"], "pick": 2, "quest": "q_rotheart"}, "spells": ["mob_roots", "mob_stomp", "mob_enrage"]}
	m["boss_lake"] = {"name": "莱克", "sub": "双枪 · 灰巾帮副首领", "model": "humanoid", "rep": {"city": 300}, "lvl": [15, 15], "fam": "boss", "type": "humanoid", "color": Color("2a2a32"), "color2": Color("b02020"),
		"scale": 1.3, "boss": true, "elite": true, "hp_mul": 2.6, "dmg_mul": 1.1, "leash": 34.0, "respawn": 0.0, "ranged": "mob_shoot", "weapon": "gun", "outfit": "bandit_boss",
		"ember_flag": "sanctum_ember_lake", "ember_name": "灰巾火种",
		"loot": {"items": ["b_lake_gun", "b_lake_vest", "b_lake_blade"], "pick": 2, "quest": "q_lake_pistol"}, "spells": ["mob_bomb", "mob_shoot", "mob_enrage"]}
	m["boss_sanctum_lantern"] = {"name": "阿尔诺", "sub": "圣歌看守", "model": "humanoid", "rep": {"abbey": 400}, "lvl": [16, 16], "fam": "boss", "type": "undead", "color": Color("4a3f5a"), "color2": Color("d0b0ff"),
		"scale": 1.45, "boss": true, "elite": true, "hp_mul": 2.8, "dmg_mul": 1.1, "leash": 30.0, "respawn": 0.0, "adds": "d_gargoyle",
		"ember_flag": "sanctum_ember_nave", "ember_name": "圣歌火种",
		"loot": {"items": ["b_victor_robe", "b_victor_dagger"], "pick": 1}, "spells": ["mob_shadowbolt", "mob_shield", "mob_summon"]}
	m["boss_victor"] = {"name": "维克托", "sub": "堕落的守钟人", "model": "humanoid", "rep": {"city": 400}, "lvl": [16, 16], "fam": "boss", "type": "undead", "color": Color("3a3a4a"), "color2": Color("a080ff"),
		"scale": 1.6, "boss": true, "elite": true, "hp_mul": 3.2, "dmg_mul": 1.15, "leash": 34.0, "respawn": 0.0, "weapon": "mace2", "outfit": "knight_dark", "adds": "d_gargoyle",
		"loot": {"items": ["b_victor_hammer", "b_victor_robe", "b_victor_helm", "b_victor_dagger"], "pick": 2, "quest": "q_bell_shard"}, "spells": ["mob_bell", "mob_cleave", "mob_shield", "mob_enrage"]}
	# Sea-temple redesign preserves IDs used by saves, loot and quest counters.
	for id in ["d_bandit","d_bandit_gunner","d_bandit_mage","boss_lake"]:
		m[id]["model"]="ratman"
		m[id]["type"]="humanoid"
		m[id]["fam"]="ratman" if id!="boss_lake" else "boss"
		m[id].erase("outfit")
		m[id]["color"]=Color("80684e")
		m[id]["color2"]=Color("9c9272")
		if id!="boss_lake":m[id]["loot"]["junk"]=["j_rat_candle","j_dirty_cloth"]
	m["d_bandit"]["name"]="圣堂鼠人掠夺者"
	m["d_bandit"]["weapon"]="mace"
	m["d_bandit_gunner"]["name"]="圣堂鼠人巡猎者"
	m["d_bandit_gunner"]["weapon"]="pick"
	m["d_bandit_gunner"].erase("ranged")
	m["d_bandit_gunner"]["spells"]=["mob_cleave"]
	m["d_bandit_mage"]["name"]="圣堂鼠人巫祝"
	m["boss_lake"]["name"]="碎帆·拉克"
	m["boss_lake"]["sub"]="鼠人拾荒头目"
	m["boss_lake"]["weapon"]="mace"
	m["boss_lake"].erase("ranged")
	m["boss_lake"]["spells"]=["mob_cleave","mob_stomp","mob_enrage"]
	m["boss_lake"]["ember_name"]="旧航火种"
	for id in ["d_gargoyle","boss_sanctum_lantern","boss_victor"]:
		m[id]["model"]="treant"
		m[id]["type"]="elemental"
		m[id]["color"]=Color("596843")
		m[id]["color2"]=Color("849360")
		m[id].erase("outfit")
		m[id].erase("weapon")
	m["d_gargoyle"]["name"]="盘根魔物"
	m["d_gargoyle"]["fam"]="plant"
	m["d_gargoyle"]["loot"]["junk"]=["j_rotwood"]
	m["boss_sanctum_lantern"]["name"]="缠殿者"
	m["boss_sanctum_lantern"]["sub"]="侵占祈航祭坛的古藤"
	m["boss_sanctum_lantern"]["scale"]=2.0
	m["boss_sanctum_lantern"]["ember_name"]="潮汐火种"
	m["boss_victor"]["name"]="覆钟古根"
	m["boss_victor"]["sub"]="占据旧出航钟台的植物魔物"
	m["boss_victor"]["scale"]=2.5
	return m

## 等级对应的怪物基础属性（参考经典数值）
const HP_TABLE := [42, 42, 55, 71, 86, 102, 120, 137, 156, 176, 198, 222, 247, 273, 300, 328, 358, 390, 420, 450, 480]

static func base_hp(level: int) -> int:
	return HP_TABLE[clampi(level, 0, HP_TABLE.size() - 1)]

static func base_dmg(level: int) -> Vector2:
	var avg := 1.6 + level * 1.45
	return Vector2(avg * 0.78, avg * 1.22)

static func base_armor(level: int) -> int:
	return 15 + level * 18

static func xp_for_kill(mob_level: int, player_level: int, elite: bool) -> int:
	var base := mob_level * 5 + 45
	var diff := mob_level - player_level
	var gray := _gray_level(player_level)
	if mob_level <= gray:
		return 0
	var xp := 0.0
	if diff >= 0:
		xp = base * (1.0 + 0.05 * mini(diff, 4))
	else:
		var zd := 5.0 if player_level < 8 else (6.0 if player_level < 10 else (7.0 if player_level < 12 else 8.0))
		xp = base * (1.0 - float(-diff) / zd)
	if elite:
		xp *= 2.0
	return maxi(0, int(round(xp)))

static func _gray_level(pl: int) -> int:
	if pl <= 5:
		return 0
	if pl <= 39:
		return pl - 5 - pl / 10
	return pl - 1 - pl / 5
