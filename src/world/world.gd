class_name World
extends Node3D
## 游戏世界：加载区域、玩家、HUD、昼夜与天气、传送/返程/飞行

const SKY_SHADER := preload("res://src/render/sky.gdshader")
## 原版《剑与远征》绘本配色 +《洛奇M》柔光：奶油色主光、蓝紫环境填充。
const SUN_DAY := ArtStyle.SUN_DAY
const AMB_DAY := ArtStyle.AMBIENT_DAY
const FOG_DAY := ArtStyle.FOG_DAY
const FOG_MAX := 0.42
const SKY_TOP_DAY := ArtStyle.SKY_TOP
const SKY_HOR_DAY := ArtStyle.SKY_HORIZON

var zone: Zone
## 常驻区域数据壳；开放世界的生成内容由 streamer 控制。zone 是玩家当前所在区域。
var zones := {}
var far_land: FarLandscape
var streamer: WorldStream
var _transition_busy := false
var _region_t := 0.0
var player: Player
var hud: Control
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var weather := "clear"
var weather_t := 0.0
var weather_amt := 0.0
var rain: CPUParticles3D
var _lightning_t := 5.0
var _flash := 0.0
var _autosave := 60.0
var _lamp_t := 0.0
var _amb_t := 1.0
var atmosphere := EnvironmentWeather.new()
var volume_atmosphere: VolumetricAtmosphere
var loading := false
var fade: ColorRect
var fade_label: Label

func _ready() -> void:
	Game.world = self
	_build_env()
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = HUD.new()
	hud_layer.add_child(hud)
	Game.hud = hud
	var fl := CanvasLayer.new()
	fl.layer = 50
	add_child(fl)
	fade = ColorRect.new()
	fade.color = Color(0.025, 0.035, 0.07, 1)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fade)
	fade_label = Label.new()
	fade_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_label.add_theme_font_size_override("font_size", 34)
	fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fade.add_child(fade_label)
	_build_loading()
	var start_zone: String = Game.pd.get("zone", "vale")
	# 旧存档坐标 → 当前大世界坐标（v1 区域各自独立坐标；v2 第一版拼接偏移；v3 当前布局）
	var ver := int(Game.pd.get("world_ver", 1))
	if ver < WorldLayout.SAVE_VER:
		if WorldLayout.in_overworld(start_zone) and Game.pd.get("pos", Vector3.ZERO) != Vector3.ZERO:
			Game.pd["pos"] += WorldLayout.offset(start_zone) - WorldLayout.legacy_offset(ver, start_zone)
		var bd: Dictionary = Game.pd.get("bind", {})
		if WorldLayout.in_overworld(bd.get("zone", "")) and bd.get("pos", Vector3.ZERO) != Vector3.ZERO:
			bd["pos"] += WorldLayout.offset(bd["zone"]) - WorldLayout.legacy_offset(ver, bd["zone"])
		Game.pd["world_ver"] = WorldLayout.SAVE_VER
	# The city was rebuilt inside the same world region; migrate locations
	# independently after old world offsets and before loading the player.
	var city_layout := preload("res://src/world/city_layout.gd")
	if int(Game.pd.get("city_ver", 0)) < city_layout.SAVE_VER:
		Game.pd = city_layout.migrate(Game.pd, city_layout.scene_anchors())
	var spawn := ""
	if Game.pd.get("new", false):
		spawn = "start"
	await _load_zone(start_zone, spawn, Game.pd.get("pos", Vector3.ZERO))
	if Game.pd.get("new", false):
		Game.pd.erase("new")
		Game.save_game()
		hud.show_intro()

func _build_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("noise_tex", BrushTerrain.get_noise_texture())
	for k in [["moon_tex", "moon"], ["stars_tex", "stars"]]:
		var tp := "res://assets/textures/env/%s.png" % k[1]
		if ResourceLoader.exists(tp):
			sky_mat.set_shader_parameter(k[0], load(tp))
			sky_mat.set_shader_parameter("has_%s" % k[0], 1.0)
	sky_mat.set_shader_parameter("cloud_tex", preload("res://assets/textures/environment_packs/sky_clouds.png"))
	sky_mat.set_shader_parameter("cloud_detail_tex", preload("res://assets/textures/environment_packs/sky_cloud_detail.png"))
	sky_mat.set_shader_parameter("stars_tex", preload("res://assets/textures/environment_packs/sky_stars.png"))
	sky_mat.set_shader_parameter("has_stars_tex", 1.0)
	add_child(AmbientLife.new())
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMB_DAY
	env.ambient_light_energy = 0.72
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# 色调与大气按洛奇M 提尔克那白昼参数校准（docs/art_direction_v3/MM_STYLE_ANALYSIS.md §3）：
	# 不再用后处理拉饱和度；远景靠深度雾变成蓝灰（空气透视），近景保持原色
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = FOG_DAY
	env.fog_density = FOG_MAX
	env.fog_depth_begin = 85.0
	env.fog_depth_end = 650.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_sun_scatter = 0.0
	env.glow_enabled = true
	# Keep a restrained bloom in the hand-painted style.  The previous zero
	# bloom made lit windows, lamps and arcane waystones look like flat paint.
	env.glow_intensity = 0.32
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2
	# 屏幕空间环境光遮蔽：洛奇M 用小半径、高强度的接触阴影（墙脚、檐下、草根）
	env.ssao_enabled = Game.settings.get("ssao", true)
	env.ssao_radius = 1.05
	env.ssao_intensity = 1.25
	env.ssao_power = 1.15
	env.ssao_light_affect = 0.18
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.03
	we.environment = env
	add_child(we)
	volume_atmosphere = VolumetricAtmosphere.new()
	add_child(volume_atmosphere)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = Game.settings.get("shadows", true)
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_fade_start = 0.8
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.8
	sun.light_energy = 1.18
	sun.shadow_opacity = 0.76
	sun.shadow_blur = 1.4
	add_child(sun)
	moon = DirectionalLight3D.new()
	# Lavender-blue key: cooler than daylight, but bright enough to describe
	# terrain and character silhouettes without turning the world monochrome.
	moon.light_color = Color("aeb9ee")
	moon.light_energy = 0.0
	moon.shadow_enabled = Game.settings.get("shadows", true)
	moon.directional_shadow_max_distance = 140.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moon.shadow_bias = 0.035
	moon.shadow_normal_bias = 0.8
	moon.shadow_opacity = 0.72
	moon.shadow_blur = 1.8
	add_child(moon)
	rain = CPUParticles3D.new()
	rain.amount = 1400
	rain.lifetime = 1.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(30, 1, 30)
	rain.direction = Vector3(0.1, -1, 0)
	rain.spread = 3.0
	rain.gravity = Vector3(0, -30, 0)
	rain.initial_velocity_min = 18.0
	rain.initial_velocity_max = 24.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.03, 0.7)
	var rm := U.unshaded(Color(0.75, 0.82, 0.95, 0.45), true).duplicate()
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.material = rm
	rain.mesh = qm
	rain.emitting = false
	rain.local_coords = false
	add_child(rain)

func _exit_tree() -> void:
	EnvironmentWeather.reset_globals()

# ================================================================ 载入画面
const TIPS := [
	"按 I 打开地下城查找器，可以直接进入风语旧圣堂。",
	"按 K 打开专业技能面板——制作不需要工作台，随时随地都能进行。",
	"在旅店或城市里休息会积累「精力充沛」，击杀怪物获得双倍经验。",
	"晴岚港的社会保障局每天都会发放一份冒险者补助。",
	"幻化师可以把装备换成衣柜里任何收集过的外观。",
	"交易所的售价越接近市价，越容易在时限内卖出。",
	"右键点击 NPC 对话，头顶有黄色「!」的 NPC 可以接任务。",
	"本作没有死亡惩罚：不会损失经验、金钱或装备耐久。",
	"魔导列车连接晴岚港与金穗镇——前提是信号灯已经修好。",
	"按住鼠标右键可以转动视角，滚轮缩放镜头距离。",
]

var load_box: Control
var load_title: Label
var load_sub: Label
var load_desc: Label
var load_tip: Label

class LoadSpinner extends Control:
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		for i in 3:
			var a0 := t * (2.4 + i * 0.7) + i * 2.1
			draw_arc(c, 18.0 + i * 7.0, a0, a0 + 1.6, 24, Color(UITheme.GOLD, 0.85 - i * 0.22), 3.0, true)

func _build_loading() -> void:
	load_box = VBoxContainer.new()
	load_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_box.alignment = BoxContainer.ALIGNMENT_CENTER
	load_box.add_theme_constant_override("separation", 14)
	load_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	load_box.visible = false
	fade.add_child(load_box)
	load_title = UITheme.label("", 46, UITheme.GOLD, true)
	load_sub = UITheme.label("", 18, UITheme.TEXT_DIM)
	load_desc = UITheme.label("", 18, UITheme.TEXT)
	load_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	load_desc.custom_minimum_size = Vector2(760, 0)
	for l in [load_title, load_sub, load_desc]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		load_box.add_child(l)
	var sp := LoadSpinner.new()
	sp.custom_minimum_size = Vector2(80, 80)
	sp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	load_box.add_child(sp)
	load_tip = UITheme.label("", 16, Color("a8c8ff"))
	load_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_tip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	load_box.add_child(load_tip)

func _show_loading(zd: Dictionary) -> void:
	fade_label.text = ""
	load_title.text = zd.get("name", "")
	load_sub.text = ("等级 %s" % zd["levels"]) if zd.has("levels") else ""
	load_desc.text = zd.get("desc", "")
	load_tip.text = "提示：" + TIPS[randi() % TIPS.size()]
	load_box.visible = true
	load_title.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(load_title, "modulate:a", 1.0, 0.4)

# ================================================================ 区域加载
func _set_fade(a: float, text: String = "") -> void:
	fade_label.text = text
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", a, 0.35)
	await tw.finished

func _load_zone(zone_id: String, spawn_name: String, pos: Vector3 = Vector3.ZERO, yaw: float = INF) -> void:
	loading = true
	fade.modulate.a = 1.0
	var zd: Dictionary = DB.zones.get(zone_id, DB.zones["vale"])
	_show_loading(zd)
	await get_tree().process_frame
	await get_tree().process_frame
	await _unload_all()
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	# Region descriptors stay resident; expensive generated content is spatially streamed.
	if WorldLayout.in_overworld(zone_id) and Game.settings.get("world_streaming", true):
		streamer = WorldStream.new()
		streamer.name = "WorldStream"
		add_child(streamer)
	var ids: Array = WorldLayout.zones() if WorldLayout.in_overworld(zone_id) else [zone_id]
	ids.erase(zone_id)
	ids.push_front(zone_id)
	for id in ids:
		ResourceLoader.load_threaded_request(DB.zones[id]["scene"])
	for id in ids:
		var path: String = DB.zones[id]["scene"]
		var ps: PackedScene = null
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		ps = ResourceLoader.load_threaded_get(path)
		if ps == null:
			ps = load(path)
		var z: Zone = ps.instantiate()
		z.position = WorldLayout.offset(id) if ids.size() > 1 else Vector3.ZERO
		# 15–20 级外勤内容随潮风高地实例加入，早于流式登记以纳入演员来源。
		if id == "tidewind":
			preload("res://src/world/ember_chapter.gd").apply(z)
		if streamer:
			streamer.register_zone(z)
		add_child(z)
		zones[id] = z
		print("[world] zone %s instanced at %s in %d ms" % [id, z.position, Time.get_ticks_msec() - t0])
		await get_tree().process_frame
	zone = zones[zone_id]
	# 远景地貌：包住所有已加载地形的并集
	var fl_entries := []
	var outer_kept := false
	for id in ids:
		var z: Zone = zones[id]
		var cfg = DB.zones[id].get("far_land")
		if z.terrain and cfg != null:
			fl_entries.append([z.terrain, cfg.get("sea", [])])
		# 多块地形的外围大水面会互相重叠闪烁：只保留一块
		if z.terrain:
			var wo := z.terrain.find_child("WaterOuter", true, false)
			if wo:
				if outer_kept:
					wo.visible = false
				outer_kept = true
	if not fl_entries.is_empty():
		far_land = FarLandscape.new()
		far_land.name = "FarLandscape"
		add_child(far_land)
		far_land.setup_multi(fl_entries)
		print("[world] far landscape in %d ms" % (Time.get_ticks_msec() - t0))
	if Game.settings.get("grass", true):
		for id in ids:
			var z: Zone = zones[id]
			if z.terrain:
				var gf := GrassField.new()
				gf.name = "GrassField"
				z.add_child(gf)
				gf.setup(z.terrain)
	print("[world] zones instanced in %d ms" % (Time.get_ticks_msec() - t0))
	Game.zone = zone
	Game.pd["zone"] = zone_id
	if player == null:
		player = Player.new()
		player.name = "Player"
		zone.add_child(player)
		Game.player = player
	else:
		zone.add_child(player)
	print("[world] player added")
	await get_tree().physics_frame
	print("[world] after physics frame")
	var sp: Node3D = null
	if spawn_name != "":
		sp = zone.get_spawn(spawn_name)
	if sp != null:
		pos = sp.global_position
		yaw = sp.global_rotation.y
	elif pos == Vector3.ZERO:
		var any := zone.get_spawn("start")
		if any == null and zone.terrain:
			# 没有 start 出生点：取离地图中心最近的墓地/出生点（大世界里 (0,0,0) 可能属于另一块区域）
			var sz := zone.terrain.data.world_size()
			any = zone.nearest_graveyard(zone.terrain.global_position + Vector3(sz * 0.5, 0, sz * 0.5))
		if any:
			pos = any.global_position
			yaw = any.global_rotation.y
	if streamer:
		await streamer.prepare(pos)
	var gh := U.ground_height(get_tree(), pos.x, pos.z, pos.y)
	if zone_id == "sanctum":
		if int(Game.pd.get("sanctum_layout_ver", 0)) < 2 and pos.y < 22.0:
			var revised_floor := SanctumFlow.floor_y(Vector2(pos.x, pos.z))
			if revised_floor != INF:pos.y = revised_floor+.1
		Game.pd["sanctum_layout_ver"] = 2
		# Saved interior positions must stay below the hillside and upper storey.
		# Probe beside the saved feet rather than using the surface heightfield.
		var near_floor := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.3, 0), pos - Vector3(0, 2, 0), 1))
		gh = near_floor.position.y if not near_floor.is_empty() else pos.y
	if pos.y < gh - 0.5:
		pos.y = gh
	player.global_position = pos + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	if yaw != INF:
		player.rotation.y = yaw
		player.cam_yaw = yaw
	player.cam_pivot.global_position = player.global_position + Vector3(0, 1.5, 0)
	t0 = Time.get_ticks_msec()
	for id in ids:
		zones[id].populate()
	print("[world] populated in %d ms, units=%d" % [Time.get_ticks_msec() - t0, get_tree().get_nodes_in_group("units").size()])
	if player.pet and is_instance_valid(player.pet):
		if player.pet.get_parent():
			player.pet.get_parent().remove_child(player.pet)
		zone.units_root.add_child(player.pet)
		player.pet.global_position = player.global_position + Vector3(1.5, 0.5, 1.5)
	# 出生点可能落在另一块拼接区域里（例如旧存档坐标）：按玩家实际位置校正当前区域
	var rid := region_at(player.global_position)
	if rid != "" and rid != zone_id:
		zone_id = rid
		zone = zones[rid]
		Game.zone = zone
		Game.pd["zone"] = rid
		zd = DB.zones[rid]
	if zd.get("dungeon", false):
		_spawn_companions()
	_spawn_postboxes(zone, zone_id)
	_pick_weather(true)
	Sfx.set_music(zone.music_mode(player.global_position))
	Game.zone_entered.emit(zone_id)
	Game.center_text.emit(zd["name"], "")
	hud.on_zone_loaded()
	await get_tree().create_timer(0.3).timeout
	loading = false
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): load_box.visible = false)

func _unload_all() -> void:
	if is_instance_valid(streamer):
		await streamer.shutdown()
		streamer.free()
	streamer = null
	if zones.is_empty() and zone == null:
		return
	for u in get_tree().get_nodes_in_group("allies"):
		if u.role != "pet":
			u.queue_free()
	if player and player.get_parent():
		player.get_parent().remove_child(player)
	if player and player.pet and is_instance_valid(player.pet) and player.pet.get_parent():
		player.pet.get_parent().remove_child(player.pet)
	for id in zones:
		if is_instance_valid(zones[id]):
			zones[id].queue_free()
	if zone and is_instance_valid(zone) and not zones.values().has(zone):
		zone.queue_free()
	zones.clear()
	zone = null
	Game.zone = null
	if far_land and is_instance_valid(far_land):
		far_land.queue_free()
	far_land = null

## 该位置属于哪个已加载区域（按地形范围；不在任何地形上时返回 ""）
func region_at(p: Vector3) -> String:
	for id in zones:
		var z: Zone = zones[id]
		if z.terrain and z.terrain.is_inside(p.x, p.z):
			return id
	return ""

## 无缝大世界里跨越区域边界：只切换当前区域（名称、天气、音乐、地图），不重新加载
func _enter_region(id: String) -> void:
	if not zones.has(id) or zones[id] == zone:
		return
	zone = zones[id]
	Game.zone = zone
	Game.pd["zone"] = id
	var zd: Dictionary = DB.zones[id]
	_pick_weather(false)
	if not player.in_combat:
		Sfx.set_music(zone.music_mode(player.global_position))
	Game.zone_entered.emit(id)
	Game.center_text.emit(zd["name"], ("等级 %s" % zd["levels"]) if zd.has("levels") else "")
	hud.on_zone_loaded()

func _update_region(delta: float) -> void:
	if zones.size() < 2 or loading:
		return
	_region_t -= delta
	if _region_t > 0.0:
		return
	_region_t = 0.4
	var id := region_at(player.global_position)
	if id == "" or zones[id] == zone:
		return
	# 迟滞：进入新区域 6m 后才切换，避免在接缝线上来回闪
	var t: BrushTerrain = zones[id].terrain
	var s := t.data.world_size()
	var o := t.global_position
	var p := player.global_position
	var inner := minf(minf(p.x - o.x, o.x + s - p.x), minf(p.z - o.z, o.z + s - p.z))
	if inner >= 6.0:
		_enter_region(id)

## 同一大世界内的瞬移（传送、飞行、列车、炉石）：渐隐 → 移动 → 更新区域 → 渐显
func _teleport_to(p: Vector3, y: float = INF) -> void:
	loading = true
	player.stop_cast(false)
	if streamer:
		await streamer.prepare(p)
	player.global_position = p + Vector3(0, 0.5, 0)
	player.velocity = Vector3.ZERO
	if y != INF:
		player.rotation.y = y
		player.cam_yaw = y
	player.cam_pivot.global_position = player.global_position + Vector3(0, 1.5, 0)
	var id := region_at(player.global_position)
	if id != "":
		_enter_region(id)
	if is_instance_valid(player.pet):
		player.pet.global_position = player.global_position + Vector3(1.5, 0.5, 1.5)
	await get_tree().physics_frame
	loading = false

func ground_ready(p: Vector3) -> bool:
	return streamer == null or streamer.ground_ready(p)

func simulation_suspended() -> bool:
	return loading or _transition_busy

func travel(zone_id: String, spawn_name: String = "", pos: Vector3 = Vector3.ZERO, yaw: float = INF) -> void:
	if loading or _transition_busy:
		return
	_transition_busy = true
	player.stop_cast(false)
	player.dismount()
	# 目标数据壳已在大世界中：先准备落点区块，再移动玩家。
	if zones.has(zone_id):
		var target := pos
		var ty := yaw
		if spawn_name != "":
			var sp: Node3D = zones[zone_id].get_spawn(spawn_name)
			if sp:
				target = sp.global_position
				ty = sp.global_rotation.y
		if target != Vector3.ZERO:
			await _set_fade(1.0, "")
			await _teleport_to(target, ty)
			await get_tree().create_timer(0.2).timeout
			await _set_fade(0.0)
			_transition_busy = false
			return
	await _set_fade(1.0)
	Game.save_game()
	await _load_zone(zone_id, spawn_name, pos, yaw)
	Game.save_game()
	_transition_busy = false

func hearth() -> void:
	var b: Dictionary = Game.pd["bind"]
	Vfx.column(zone, player.global_position, Color("80b0ff"), 3.0, 0.8)
	Sfx.play("portal")
	if b.has("spawn") and b["spawn"] != "":
		travel(b["zone"], b["spawn"])
	else:
		travel(b["zone"], "", b["pos"])

func respawn_player_at_graveyard() -> void:
	var gy: Node3D = null
	var bd := INF
	for z in zones.values():
		var g: Node3D = z.nearest_graveyard(player.global_position)
		if g and g.global_position.distance_to(player.global_position) < bd:
			bd = g.global_position.distance_to(player.global_position)
			gy = g
	if gy == null and zone:
		gy = zone.nearest_graveyard(player.global_position)
	if gy:
		await _teleport_to(gy.global_position)

func revive_player(at_graveyard: bool) -> void:
	if at_graveyard:
		await _set_fade(1.0, "灵魂正在归来……")
		await respawn_player_at_graveyard()
		player.revive(true)
		await get_tree().create_timer(0.5).timeout
		await _set_fade(0.0)
	else:
		player.revive(true)
	Game.msg("你复活了。（本作没有死亡惩罚）", Color("80ff80"))

func spawn_pet(owner_u: Unit, pet_id: String) -> Unit:
	var a := Ally.new()
	a.name = "Pet"
	zone.units_root.add_child(a)
	a.init_ally(pet_id, "pet", owner_u, owner_u.level)
	a.global_position = owner_u.global_position + owner_u.global_transform.basis * Vector3(-1.5, 0.5, 1.5)
	Vfx.burst(zone, a.global_position + Vector3(0, 0.5, 0), Color("ffd080"), 1.2)
	return a

## 邮箱柱：按 DataWorld.postboxes() 在区域里生成，只在首次进入该区域时创建
func _spawn_postboxes(z: Node3D, zone_id: String) -> void:
	if z == null or not is_instance_valid(z) or z.has_node("Postboxes"):
		return
	var spots: Array = DataWorld.postboxes().get(zone_id, [])
	if spots.is_empty():
		return
	var root := Node3D.new()
	root.name = "Postboxes"
	z.add_child(root)
	var o: Vector3 = WorldLayout.offset(zone_id)
	for e in spots:
		var b := Postbox.new()
		b.name = "Postbox_%d" % root.get_child_count()
		root.add_child(b)
		var gx := o.x + float(e[0])
		var gz := o.z + float(e[1])
		b.global_position = Vector3(gx, U.ground_height(get_tree(), gx, gz, o.y), gz)
		b.rotation.y = deg_to_rad(float(e[2]) if e.size() > 2 else 0.0)

func _spawn_companions() -> void:
	var ids := [["garon", "tank"], ["aria", "healer"], ["frey", "dps"]]
	var i := 0
	for e in ids:
		var a := Ally.new()
		a.name = "Comp_" + e[0]
		zone.units_root.add_child(a)
		a.init_ally(e[0], e[1], player, maxi(player.level, 15))
		a.global_position = player.global_position + Vector3(i * 1.5 - 1.5, 0.5, 2.5)
		i += 1
	Game.msg("同伴加隆、艾莉亚与芙蕾加入了你的队伍。", Color("80c0ff"))

## 飞行路线（白盒：渐隐过场）
func fly_to(fp_id: String) -> void:
	if loading or _transition_busy:
		return
	var fp: Dictionary = DB.flight_paths.get(fp_id, {})
	if fp.is_empty():
		return
	_transition_busy = true
	await _set_fade(1.0, "✈ 乘坐小型飞艇前往：%s……" % fp["name"])
	Sfx.play("portal")
	await get_tree().create_timer(1.6).timeout
	if zones.has(fp["zone"]):
		var sp: Node3D = zones[fp["zone"]].get_spawn(fp_id)
		if sp:
			await _teleport_to(sp.global_position, sp.global_rotation.y)
		await _set_fade(0.0)
	else:
		await _load_zone(fp["zone"], fp_id)
	_transition_busy = false

## 魔导列车（白盒：渐隐过场）
func ride_train(zone_id: String, spawn_name: String, station: String) -> void:
	if loading or _transition_busy:
		return
	_transition_busy = true
	player.stop_cast(false)
	player.dismount()
	await _set_fade(1.0, "🚂 魔导列车正在驶向：%s……" % station)
	await get_tree().create_timer(1.8).timeout
	if zones.has(zone_id):
		var sp: Node3D = zones[zone_id].get_spawn(spawn_name)
		if sp:
			await _teleport_to(sp.global_position, sp.global_rotation.y)
		await _set_fade(0.0)
	else:
		Game.save_game()
		await _load_zone(zone_id, spawn_name)
		Game.save_game()
	_transition_busy = false
	Game.msg("列车到站：%s。" % station, Color("80d0ff"))

# ================================================================ 昼夜与天气
func _pick_weather(force: bool = false) -> void:
	var zd: Dictionary = DB.zones.get(Game.pd.get("zone", "vale"), {})
	var w: Dictionary = zd.get("weather", {"clear": 1.0})
	if not Game.settings.get("weather", true):
		weather = "clear"
		return
	var r := randf()
	var acc := 0.0
	for k in w:
		acc += w[k]
		if r <= acc:
			weather = k
			break
	weather_t = randf_range(180.0, 420.0)
	if force:
		weather_amt = 1.0 if weather != "clear" else 0.0
	if weather in ["rain", "storm"]:
		Game.msg("天空下起了雨。" if weather == "rain" else "雷雨即将来临……", Color("a0c0ff"))

func _update_location_audio() -> void:
	if zone != null and is_instance_valid(zone):
		Sfx.set_ambience(zone.ambience(player.global_position))
		if not player.in_combat:
			var music := zone.music_mode(player.global_position)
			if Sfx._music_mode != music:
				Sfx.set_music(music)

func _process(delta: float) -> void:
	# 切换区域时玩家会短暂离开场景树（此时画面已全黑，跳过一帧无妨）
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	_update_region(delta)
	# 环境音（村庄/城区）：一秒一次，按玩家位置切换
	_amb_t -= delta
	if _amb_t <= 0.0:
		_amb_t = 1.0
		_update_location_audio()
	weather_t -= delta
	if weather_t <= 0.0:
		_pick_weather()
	if not Game.settings.get("weather", true):
		weather = "clear"
	var target_amt := 0.0 if weather == "clear" else 1.0
	weather_amt = move_toward(weather_amt, target_amt, delta * 0.05)
	_update_sky(delta)
	# 雨
	var raining := atmosphere.rain > 0.15
	rain.emitting = raining
	if raining:
		rain.global_position = player.camera.global_position + Vector3(0, 12, 0)
		rain.amount = maxi(100, int(1400 * atmosphere.rain))
	if atmosphere.storm > 0.6:
		_lightning_t -= delta
		if _lightning_t <= 0.0:
			_lightning_t = randf_range(6.0, 16.0)
			_flash = 1.0
			get_tree().create_timer(randf_range(0.5, 2.0)).timeout.connect(func(): Sfx.play("thunder", -4.0, 0.3))
	_flash = maxf(0.0, _flash - delta * 3.0)
	# 自动存档
	_autosave -= delta
	if _autosave <= 0.0:
		_autosave = 60.0
		Game.save_game()
	_lamp_t -= delta
	if _lamp_t <= 0.0:
		_lamp_t = 0.25
		_update_lamps()
		_update_effect_lights()

func night_factor() -> float:
	var t := Game.time_of_day
	if t >= 7.0 and t <= 18.5:
		return 0.0
	if t > 18.5 and t < 20.5:
		return smoothstep(18.5, 20.5, t)
	if t >= 5.0 and t < 7.0:
		return 1.0 - smoothstep(5.0, 7.0, t)
	return 1.0

func _update_sky(_delta: float) -> void:
	atmosphere.advance(weather, _delta)
	var t := Game.time_of_day
	var nf := night_factor()
	# Keep a night value lift while avoiding the crushed blacks that made tree
	# trunks, grass and the player read as one silhouette in the previous grade.
	env.adjustment_contrast = lerpf(1.03, 1.06, nf)
	# Keep the evening key above the horizon through 20:00; match the sky disk.
	# Night's key takes over before the setting sun disappears.
	# Fourteen daylight hours and ten night hours still form one continuous 24h orbit.
	var sun_ang := (t - 6.0) / 14.0 * PI if t >= 6.0 and t < 20.0 else PI + (t - 20.0 if t >= 20.0 else t + 4.0) / 10.0 * PI
	var sun_dir := Vector3(cos(sun_ang) * 0.8, sin(sun_ang), 0.45).normalized()
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.FORWARD)
	var moon_dir := -sun_dir
	moon_dir.y = absf(moon_dir.y) * 0.8 + 0.2
	moon_dir = moon_dir.normalized()
	moon.look_at_from_position(Vector3.ZERO, -moon_dir, Vector3.UP)
	var dusk := clampf(1.0 - absf(sun_dir.y) * 3.0, 0.0, 1.0) * (1.0 - smoothstep(20.0, 21.0, t) if t > 12.0 else 1.0)
	var wa := atmosphere.overcast
	var day_top := SKY_TOP_DAY
	var day_hor := SKY_HOR_DAY
	var dusk_hor := Color("e9b18e")
	# Keep the night sky clearly darker than the day palette while preserving
	# enough blue in the horizon for silhouettes and the moon to read.
	var night_top := Color(0.018, 0.028, 0.085)
	var night_hor := Color(0.075, 0.105, 0.24)
	var top := day_top.lerp(night_top, nf)
	var hor := day_hor.lerp(dusk_hor, dusk * 0.8).lerp(night_hor, nf)
	var gray := Color("91a9b4").lerp(Color("1d2e50"), nf)
	top = top.lerp(gray, wa * 0.85)
	hor = hor.lerp(gray.lightened(0.1), wa * 0.70)
	if _flash > 0.0:
		top = top.lerp(Color(0.9, 0.92, 1.0), _flash * 0.7)
		hor = hor.lerp(Color(0.9, 0.92, 1.0), _flash * 0.7)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", hor)
	sky_mat.set_shader_parameter("ground_color", hor.darkened(0.3))
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	sky_mat.set_shader_parameter("night", nf)
	sky_mat.set_shader_parameter("cloud_cover", atmosphere.cloud)
	sky_mat.set_shader_parameter("overcast", wa)
	sky_mat.set_shader_parameter("wind_speed", atmosphere.wind)
	sky_mat.set_shader_parameter("cloud_time", atmosphere.motion_time)
	sky_mat.set_shader_parameter("cloud_tint", Color("fff8e9").lerp(Color(1.0, 0.8, 0.7), dusk * 0.6))
	var sun_col := ArtStyle.warm_sun(dusk)
	sky_mat.set_shader_parameter("sun_color", sun_col)
	sun.light_color = sun_col.lerp(Color("d7e1ee"), wa * 0.65)
	sun.shadow_opacity = lerpf(0.88, 0.55, wa)
	sun.shadow_blur = lerpf(1.4, 3.0, wa)
	# Grazing sunlight needs depth bias to avoid striping on shallow terrain triangles.
	sun.shadow_bias = lerpf(0.08, 0.18, dusk)
	sun.shadow_normal_bias = 1.0
	var sun_up := smoothstep(-0.015, 0.22, sun_dir.y)
	sun.light_energy = 1.65 * sun_up * (1.0 - wa * 0.65) + _flash * 2.5
	sun.visible = sun_up > 0.01
	sun.shadow_enabled = Game.settings.get("shadows", true) and sun_up > 0.01
	var moon_key := (1.0 - smoothstep(-0.04, 0.18, sun_dir.y)) * nf
	# The moon supplies visible directional shape while warm windows and lamps
	# remain the local contrast anchors.  The previous 0.48 energy crushed
	# unlit terrain to black and made night read as a flat blue filter.
	moon.light_energy = 1.38 * moon_key * (1.0 - wa * 0.60)
	moon.light_color = Color("b9bcf5").lerp(Color("9d91c7"), wa * 0.35)
	moon.visible = moon_key > 0.01
	moon.shadow_enabled = Game.settings.get("shadows", true) and moon_key > 0.01
	# A slightly firmer, softer-edged moon shadow separates tree/building
	# silhouettes from the blue ambient fill without looking like a hard sun.
	moon.shadow_opacity = lerpf(0.62, 0.84, moon_key)
	moon.shadow_blur = lerpf(2.8, 1.9, moon_key)
	# Desaturate the ambient fill so the scene does not become a uniform blue
	# filter; blue comes from the directional moon and the distant haze.
	var amb_night := Color("596aa4")
	env.ambient_light_color = AMB_DAY.lerp(Color("baabb4"), dusk * 0.45).lerp(amb_night, nf)
	# More directional daylight gives trees/buildings shape; overcast retains soft fill.
	env.ambient_light_energy = lerpf(lerpf(0.40, 0.58, wa), 0.35, nf) + _flash * 0.25
	if Game.pd.get("zone", "") == "sanctum" and is_instance_valid(player):
		env.ambient_light_energy *= preload("res://src/render/sanctum_window_rig.gd").ambient_factor(player.global_position)
	# Bloom is mostly a night cue: warm windows and campfires get a soft halo,
	# while daytime materials retain their crisp painted edges.
	env.glow_intensity = lerpf(0.32, 0.54, nf) + _flash * 0.08
	env.glow_bloom = lerpf(0.04, 0.075, nf)
	# 夜间只让窗户、灯火等高亮光源泛光；角色浅色材质不进入 Bloom。
	env.glow_hdr_threshold = lerpf(1.28, 1.45, nf)
	env.ssao_enabled = Game.settings.get("ssao", true)
	# 雾色：白昼蓝灰 → 黄昏暖灰 → 夜晚深蓝（洛奇M 三个时段的 FogColor）
	env.fog_light_color = FOG_DAY.lerp(Color(0.62, 0.55, 0.52), dusk * 0.7).lerp(Color(0.12, 0.2, 0.38), nf).lerp(gray.lightened(0.15), wa * 0.6)
	# Far aerial perspective stays light; local volume supplies the foreground atmosphere.
	# Clear nights still get a thin ground haze.  Keep it depth-based so the
	# foreground remains warm and readable while distant hills/trees recede
	# into a distinctly blue layer (rain and mist continue to take priority).
	var night_haze := nf * (1.0 - wa * 0.45)
	var fog_mix := maxf(maxf(atmosphere.rain, atmosphere.mist), night_haze * 0.72)
	env.fog_density = lerpf(0.14, 0.78, fog_mix)
	env.fog_depth_begin = minf(lerpf(210.0, 100.0, atmosphere.rain), lerpf(210.0, 28.0, nf))
	env.fog_depth_end = minf(lerpf(1000.0, 480.0, atmosphere.rain), lerpf(1000.0, 285.0, nf))
	env.fog_aerial_perspective = lerpf(0.04, 0.58, nf)
	env.fog_sky_affect = lerpf(0.0, 0.26, nf)
	atmosphere.publish(hor, nf)
	volume_atmosphere.update(self, atmosphere, nf)
	_update_camera_depth(nf)
	Prop.set_night_factor(nf)
	CityMat.set_night(nf)

func _update_camera_depth(nf: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if camera.attributes == null:
		camera.attributes = CameraAttributesPractical.new()
	var lens := camera.attributes as CameraAttributesPractical
	if lens == null:
		return
	# Keep the player and nearby interaction space sharp as the camera zooms.
	var focus := camera.global_position.distance_to(player.global_position + Vector3.UP * 1.4) if is_instance_valid(player) else 10.0
	lens.dof_blur_far_distance = maxf(42.0, focus + 32.0)
	lens.dof_blur_far_transition = 85.0
	lens.dof_blur_amount = 0.018 * nf
	lens.dof_blur_far_enabled = Game.settings.get("depth_of_field", true) and nf > 0.01 and RenderingServer.get_current_rendering_method() != "gl_compatibility"
	lens.dof_blur_near_enabled = false

func _update_lamps() -> void:
	var nf := night_factor()
	var lamps := get_tree().get_nodes_in_group("lamp_lights")
	if nf < 0.02:
		for l in lamps:
			l.visible = false
			l.shadow_enabled = false
		for n in get_tree().get_nodes_in_group("night_only"):
			n.visible = false
		return
	for n in get_tree().get_nodes_in_group("night_only"):
		n.visible = true
	var pp := player.global_position
	lamps.sort_custom(func(a, b): return a.global_position.distance_squared_to(pp) < b.global_position.distance_squared_to(pp))
	for i in lamps.size():
		var lamp: OmniLight3D = lamps[i]
		var distance := lamp.global_position.distance_to(pp)
		lamp.visible = i < 14 and distance < 65.0
		lamp.light_energy = 2.2 * smoothstep(0.02, 0.60, nf)
		lamp.omni_range = 11.5
		lamp.shadow_enabled = lamp.visible and i < 2 and distance < 28.0 and Game.settings.get("shadows", true)
		lamp.shadow_bias = 0.04
		lamp.shadow_normal_bias = 0.7
		lamp.shadow_blur = 1.2
		lamp.light_volumetric_fog_energy = 0.15

func _update_effect_lights() -> void:
	if not is_instance_valid(player):
		return
	var lights := get_tree().get_nodes_in_group("environment_local_lights")
	var pp := player.global_position
	lights.sort_custom(func(a, b): return a.global_position.distance_squared_to(pp) < b.global_position.distance_squared_to(pp))
	var active := 0
	var shadowed := 0
	for light in lights:
		var distance: float = light.global_position.distance_to(pp)
		var available: bool = not light.night_only or night_factor() > 0.02
		light.visible = active < 8 and distance < 60.0 and available
		light.shadow_enabled = light.visible and shadowed < 1 and distance < 24.0 and Game.settings.get("shadows", true)
		if light.visible:
			active += 1
		if light.shadow_enabled:
			shadowed += 1
