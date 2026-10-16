class_name MenuWindow
extends UIWindow
## 游戏菜单 / 设置 / 操作说明

var page := "main"
var front_end := false

func _init() -> void:
	_init_window("游戏菜单", Vector2(420, 300), "menu")

func refresh() -> void:
	clear_body()
	match page:
		"main": _main()
		"settings": _settings()
		"help": _help()
		"audio_credits": _audio_credits()

func close_window() -> void:
	page = "main"
	super.close_window()

func _main() -> void:
	title_label.text = "游戏菜单"
	for e in [["继续游戏", func(): close_window()], ["设置", func(): page = "settings"; refresh()], ["操作说明", func(): page = "help"; refresh()],
			["保存游戏", func(): Game.save_game(); Game.msg("游戏已保存。", Color("80ff80"))],
			["返回角色选择", func(): Game.save_game(); Game.set_meta("front_end_select", true); get_tree().change_scene_to_file("res://scenes/boot.tscn")],
			["退出游戏", func(): Game.save_game(); get_tree().quit()]]:
		var b := UITheme.button(e[0], e[1])
		b.custom_minimum_size = Vector2(380, 46)
		body.add_child(b)

func _slider(label: String, key: String, mn: float, mx: float, step: float) -> void:
	var h := HBoxContainer.new()
	var l := UITheme.label(label, 16)
	l.custom_minimum_size.x = 140
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = Game.settings.get(key, mn)
	s.custom_minimum_size = Vector2(180, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UITheme.label(str(s.value), 15, UITheme.TEXT_DIM)
	v.custom_minimum_size.x = 50
	s.value_changed.connect(func(x):
		Game.settings[key] = x
		v.text = str(snappedf(x, step))
		_apply())
	h.add_child(s)
	h.add_child(v)
	body.add_child(h)

func _check(label: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = Game.settings.get(key, false)
	c.toggled.connect(func(v): Game.settings[key] = v; _apply())
	body.add_child(c)

func _apply() -> void:
	Game.save_settings()
	if Game.world:
		Game.world.sun.shadow_enabled = Game.settings.get("shadows", true)
		if Game.player:
			Game.player.camera.far = Game.settings.get("view_dist", 700.0)
	if Game.hud:
		Game.hud.fps_label.visible = Game.settings.get("show_fps", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if Game.settings.get("fullscreen", false) else DisplayServer.WINDOW_MODE_WINDOWED)

func _settings() -> void:
	title_label.text = "设置"
	_slider("鼠标灵敏度", "mouse_sens", 0.05, 1.0, 0.05)
	_slider("音效音量", "sfx", 0.0, 1.0, 0.05)
	_slider("音乐音量", "music", 0.0, 1.0, 0.05)
	_slider("一天时长(分钟)", "day_minutes", 4.0, 120.0, 1.0)
	_slider("视距", "view_dist", 200.0, 1200.0, 50.0)
	_check("实时阴影", "shadows")
	_check("显示名牌 (V)", "nameplates")
	var loot_note := CheckBox.new()
	loot_note.text = "怪物掉落自动入包（满包时暂存）"
	loot_note.button_pressed = true
	loot_note.disabled = true
	body.add_child(loot_note)
	_check("动态天气", "weather")
	_check("体积雾与阳光光束", "volumetric_fog")
	_check("夜间远景柔焦", "depth_of_field")
	_check("显示帧率", "show_fps")
	_check("全屏 (Alt+Enter)", "fullscreen")
	_check("反转鼠标Y轴", "invert_y")
	if front_end:
		_check("开始界面减少视角运动", "menu_reduce_motion")
	body.add_child(UITheme.button("音频来源与致谢", func(): page = "audio_credits"; refresh()))
	body.add_child(UITheme.button("返回", func():
		if front_end:
			close_window()
		else:
			page = "main"
			refresh()))

func _audio_credits() -> void:
	title_label.text = "音频来源与致谢"
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.custom_minimum_size = Vector2(380, 0)
	r.text = """当前主界面与地图音乐：Scott Buckley
Moonlight / Childhood / Midsommar / Snowfall / Undertow
Released under CC-BY 4.0. www.scottbuckley.com.au
修改：统一音量与 OGG 转码，保留完整曲目。
[url=https://www.scottbuckley.com.au/library/]作者与曲目来源[/url]
[url=https://creativecommons.org/licenses/by/4.0/]当前地图音乐许可[/url]
夜间暂用同曲低音量，钢琴与竖琴改编尚未完成。

战斗音乐及保留的历史资源：Beau Buckley（Opus Magno）
Plains 01 / Plains 02 / Castle 03 / Cave 01 / Battle 01 / Opening 03
许可：CC BY-SA 4.0；改编音乐沿用同一许可。
改动：音量与循环处理；夜间减速、钢琴与竖琴配器、精简伴奏；菜单为钢琴与竖琴改编。
[url=https://opengameart.org/users/opus-magno]音乐作者与原曲[/url]
[url=https://creativecommons.org/licenses/by-sa/4.0/]音乐许可[/url]

战斗与脚步音效：Freesound 的 yutface、CogFireStudios、spycrah、qubodup、Nox_Sound、BigKahuna360、LucasDuff、MattLeschuck、sgossner、d00121058。许可：CC0。
短音效经裁剪、单声道转换、淡入淡出及音量调整；逐项来源存于 assets/third_party/combat_freesound/CREDITS.txt。
[url=https://freesound.org/people/CogFireStudios/sounds/547040/]挥砍接触音[/url] · [url=https://freesound.org/people/spycrah/sounds/471095/]金属格挡音[/url]

界面与其他音效：Kenney（Interface Sounds / RPG Audio / Impact Sounds）、HaelDB（RPG Sound Pack）。
枪声：Michel Baradari（apollo-music.de），CC BY 3.0；音量调整与 OGG 转码。
[url=https://opengameart.org/content/chaingun-pistol-rifle-shotgun-shots]枪声原作[/url]
[url=https://creativecommons.org/licenses/by/3.0/]枪声许可[/url]
环境音：TinyWorlds（Forest Ambience）、Wolfgang_ / Ted Kerr（Crickets Ambient Noise）。许可：CC0。
[url=https://kenney.nl/assets]Kenney[/url]
[url=https://opengameart.org/content/rpg-sound-pack]RPG Sound Pack[/url]
[url=https://opengameart.org/content/forest-ambience]Forest Ambience[/url]
[url=https://opengameart.org/content/crickets-ambient-noise-loopable]Crickets Ambient Noise[/url]
[url=https://creativecommons.org/publicdomain/zero/1.0/]CC0 许可[/url]
改动：音量、部分音效变调与淡出、环境音循环。

改编音色：GeneralUser GS，S. Christian Collins。
[url=https://github.com/mrbumpy409/GeneralUser-GS]音色库与许可说明[/url]"""
	r.meta_clicked.connect(func(url): OS.shell_open(str(url)))
	body.add_child(r)
	body.add_child(UITheme.button("返回设置", func(): page = "settings"; refresh()))

func _help() -> void:
	title_label.text = "操作说明"
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.custom_minimum_size = Vector2(560, 0)
	r.text = """[b][color=#e8c27a]移动[/color][/b]
W/S 前进/后退    A/D 转向    Q/E 平移    空格 跳跃
按住右键拖动：转动视角并让角色转身（此时A/D变为平移）
按住左键拖动：只转动视角    左右键同时按住：前进
R 或 NumLock：自动奔跑    / 切换步行    X 坐下    滚轮 缩放镜头

[b][color=#e8c27a]战斗与交互[/color][/b]
左键点击：选择目标    右键点击：攻击敌人 / 与NPC对话
怪物掉落自动入包；背包满时暂存，腾出空间后自动补入。
Tab 选择最近的敌人    F 与附近的对象交互    1~0、-、= 使用动作条（Shift+数字 使用第二排）
ESC 取消目标/关闭窗口/打开菜单

[b][color=#e8c27a]界面[/color][/b]
C/B 角色与背包（同一页，装备+预览+属性+背包）    P 技能书    N 转职（技能书的转职页签）
K 专业    L 任务日志    I 副本    O 邮箱    Y 成就    J 坐骑    M 地图    V 名牌    Enter 聊天
15级选择转职，首次免费；改换需脱战、动作结束，并支付20银。转职技能自动加入技能书与动作条。
训练师、军需官与各方势力会把信件寄到邮箱，附件记得领取。
成就记录任务、击杀、首领、探索、采集制造、交易所成交与声望；达成即刻结算奖励。
Alt+Z 隐藏界面    PrintScreen 截图

[b][color=#e8c27a]命令[/color][/b]
/help /sit /dance /wave /bow /cheer /played /who
测试命令：/gm level 数字、/gm money 数字、/gm item 物品ID、/gm time 小时、/gm weather rain|clear|storm|fog、/gm speed 倍数、/gm talents reset、/gm achiev reset"""
	body.add_child(r)
	body.add_child(UITheme.button("返回", func(): page = "main"; refresh()))
