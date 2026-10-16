class_name Commands
extends RefCounted
## 聊天命令（含测试用 GM 命令）

static func run(t: String) -> void:
	var parts := t.substr(1).split(" ", false)
	if parts.is_empty():
		return
	var cmd := parts[0].to_lower()
	var p: Player = Game.player
	match cmd:
		"help", "?":
			Game.msg("命令：/sit /dance /wave /bow /cheer /played /who /gm ...（详见菜单-操作说明）", Color("80d0ff"))
		"sit":
			p.set_sitting(not p.sitting)
		"dance", "wave", "bow", "cheer", "point":
			if p.model:
				p.model.play_emote(cmd)
			var txt = {"dance": "开始跳舞。", "wave": "挥了挥手。", "bow": "鞠了一躬。", "cheer": "欢呼起来！", "point": "指向前方。"}[cmd]
			Game.msg("%s%s" % [Game.pd["name"], txt], Color("ffbb60"))
		"played":
			var s: float = Game.pd.get("played", 0.0)
			Game.msg("游戏总时间：%d小时%d分钟" % [int(s / 3600), int(fmod(s, 3600) / 60)], Color("ffff80"))
		"who":
			Game.msg("在线：%s — %d级 %s（单机模式）" % [Game.pd["name"], Game.pd["level"], DB.classes[Game.pd["class"]]["name"]], Color("ffff80"))
		"gm":
			_gm(parts)
		_:
			Game.err("未知命令。输入 /help 查看帮助。")

static func _gm(parts: PackedStringArray) -> void:
	if parts.size() < 2:
		return
	var p: Player = Game.player
	var a := parts[2] if parts.size() > 2 else ""
	match parts[1]:
		"level":
			var l := clampi(int(a), 1, DB.MAX_LEVEL)
			while Game.pd["level"] < l:
				Game.give_xp(DB.xp_to_next(Game.pd["level"]) - Game.pd["xp"])
		"money":
			Game.add_money(int(a))
		"item":
			Game.add_item(a, int(parts[3]) if parts.size() > 3 else 1)
		"time":
			Game.time_of_day = clampf(float(a), 0.0, 23.99)
		"weather":
			Game.world.weather = a
			Game.world.weather_amt = 1.0 if a != "clear" else 0.0
		"speed":
			p.base_speed = 7.0 * maxf(0.5, float(a))
		"heal":
			p.set_hp(p.max_hp)
			p.add_power(p.max_power)
		"tp":
			Game.world.travel(a, parts[3] if parts.size() > 3 else "")
		"quest":
			if parts.size() > 3 and parts[2] == "complete":
				var qid := parts[3]
				if Game.pd["quests"].has(qid):
					var q: Dictionary = DB.quests[qid]
					for i in q.get("obj", []).size():
						var o: Dictionary = q["obj"][i]
						if o["type"] == "collect":
							Game.add_item(o["item"], o["n"] - Game.count_item(o["item"]), true)
						else:
							Game.pd["quests"][qid]["p"][i] = o.get("n", 1)
					Game.quest_log_changed.emit()
					Game.npc_markers_dirty.emit()
		"learn":
			for sid in DB.classes[Game.pd["class"]]["spells"]:
				var ranks: Array = DB.spells[sid].get("ranks", [])
				for r in ranks.size():
					if DB.spell_rank_level(sid, r + 1) <= Game.pd["level"]:
						Game.pd["spells"][sid] = r + 1
			Game.spells_changed.emit()
		"spec":
			# /gm spec <转职id>：直接转职（免费、不检查等级）；/gm spec reset：回到未转职
			if a == "reset":
				Game.pd["spec"] = ""
			elif DB.spec_index.has(a):
				Game.pd["spec"] = a
			Specs.invalidate()
			Specs.sync_spells(true)
			if Game.player:
				Game.player.recalc_stats()
			Game.spells_changed.emit()
			Game.msg("转职：%s。" % (Specs.current().get("name", "未转职")), Color("ffff80"))
		"achiev":
			if a == "reset":
				Game.pd["achiev"] = {}
				Game.achieve_changed.emit()
				Game.msg("成就记录已清空。", Color("ffff80"))
			else:
				Game.msg("成就：已完成 %d/%d，累计 %d 点。" % [Achieve.count_done(), DataAchiev.LIST.size(), Achieve.total_points()], Color("ffff80"))
	Game.msg("GM：%s" % " ".join(parts), Color("ff80ff"))
