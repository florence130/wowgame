class_name CityMat
extends RefCounted
## 晴岚港 v7 城市材质：GLB 里材质名为 "C7_<name>"，加载时由 ModelProp 换成这里的共享材质。
## 贴图来自 tools/city_plan_v6 的程序化贴图（assets/textures/city_v7/<name>.png，夜景亮窗 <name>_em.png）。

const DIR := "res://assets/textures/city_v7/"
static var _cache := {}
static var _night := []          # [材质, 夜间强度]
static var _nf := 0.0

## 底色（与网页版一致）；贴图材质为白色，由贴图 × 顶点色决定颜色
const BASE := {
	"quay": Color("c8c2b6"), "curb": Color("d9d4ca"), "metal": Color("2b2e33"), "steel_red": Color("a3342a"),
	"gold": Color("d4a548"), "bronze": Color("a57a45"), "glass_lit": Color("dfe8ee"), "glow_lamp": Color("fff1cc"),
	"glow_arcane": Color("bfe6ff"), "clock": Color("faf3e2"), "water_s": Color(0.35, 0.65, 0.72, 0.85), "glass": Color(0.75, 0.85, 0.9, 0.45),
}
const NIGHT := {"glass_lit": 1.4, "glow_lamp": 2.5, "glow_arcane": 2.6, "clock": 0.8}
const DAY := {"glass_lit": 0.05, "glow_lamp": 0.3, "glow_arcane": 1.2}

static func get_mat(name: String) -> Material:
	if _cache.has(name):
		return _cache[name]
	var m := StandardMaterial3D.new()
	m.resource_name = "C7_" + name
	m.vertex_color_use_as_albedo = true
	# 手绘风格：全部哑光（粗糙度 1、镜面反射压到很低），明暗与质感来自手绘贴图，不靠高光
	m.roughness = 1.0
	m.metallic_specular = 0.12
	m.albedo_color = BASE.get(name, Color.WHITE)
	var tp := DIR + name + ".png"
	if ResourceLoader.exists(tp):
		m.albedo_texture = load(tp)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var ep := DIR + name + "_em.png"
	if ResourceLoader.exists(ep):
		m.emission_enabled = true
		m.emission = Color("ffc070")
		m.emission_texture = load(ep)
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY   # 只有窗户亮（默认 ADD 会让整面墙发光）
		m.emission_energy_multiplier = 0.0
		_night.append([m, 1.6 if name.begins_with("shop") else 1.2, 0.0])
	elif NIGHT.has(name):
		m.emission_enabled = true
		m.emission = Color("66c8ff") if name == "glow_arcane" else Color("ffd18a")
		_night.append([m, NIGHT[name], DAY.get(name, 0.0)])
		m.emission_energy_multiplier = DAY.get(name, 0.0)
	match name:
		"balus", "iron":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"water_s":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.12
			m.metallic = 0.1
			if ResourceLoader.exists("res://assets/textures/env/water_normal.png"):
				m.normal_enabled = true
				m.normal_texture = load("res://assets/textures/env/water_normal.png")
				m.normal_scale = 0.6
				m.uv1_triplanar = true
				m.uv1_scale = Vector3(0.08, 0.08, 0.08)
		"glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.35
			m.metallic = 0.0
			m.metallic_specular = 0.3
		"awning", "cloth", "glass_lit":
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"metal", "gold", "bronze", "steel_red":
			# 金属件只留一点点柔和的金属感，不再有镜面亮斑
			m.metallic = 0.25
			m.roughness = 0.75
			m.metallic_specular = 0.2
	_cache[name] = m
	set_night(_nf)
	return m

## 窗格（沿街楼构件 N|RRGGBB）：白天是深色映天空的玻璃，夜间发暖光；与 chunk 的亮窗贴图同一夜间系数
static func night_window(c: Color) -> StandardMaterial3D:
	var key := "N|" + c.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.2
	m.emission_enabled = true
	m.emission = Color("ffc470")
	m.emission_energy_multiplier = 0.0
	_night.append([m, 1.3, 0.0])
	_cache[key] = m
	set_night(_nf)
	return m

## 夜间系数 0..1（World 的昼夜循环调用）
static func set_night(nf: float) -> void:
	_nf = nf
	for e in _night:
		(e[0] as StandardMaterial3D).emission_energy_multiplier = nf * e[1] + (1.0 - nf) * e[2]

## 把场景里 C7_ 开头的表面材质换成共享城市材质，返回是否找到
static func apply(root: Node) -> bool:
	var found := false
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		if String(m3.name).begins_with("lotfar"):
			# 沿街楼白模代理：近处由 CityKitLots 的模块化构件顶替（KIT_RANGE 170m），这里 PROXY_BEGIN 起才画
			m3.visibility_range_begin = 128.0
			m3.visibility_range_begin_margin = 12.0
		if String(m3.name).begins_with("detail"):
			m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m3.visibility_range_end = 280.0
			m3.visibility_range_end_margin = 40.0
			m3.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		for i in m3.mesh.get_surface_count():
			var sm := m3.mesh.surface_get_material(i)
			if sm != null and sm.resource_name.begins_with("C7_"):
				m3.set_surface_override_material(i, get_mat(sm.resource_name.substr(3)))
				found = true
	return found
