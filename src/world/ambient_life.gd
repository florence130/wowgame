class_name AmbientLife
extends Node3D
## 环境小动物：白天野外的蝴蝶（跟随玩家，半径约 18m）与大世界上空的飞鸟。
## 素材由 tools/reftexture/adapt_env.py 改编（参考素材的剪影重画翅纹、改本作配色）。
## 副本、夜晚、下雨时不出现；城区地面（潮风高地城墙内）不放蝴蝶。

const SHADER := preload("res://src/render/critter.gdshader")
var butterflies: GPUParticles3D
var birds: GPUParticles3D
var _t := 0.0

func _ready() -> void:
	butterflies = _make("res://assets/textures/env/fx_butterfly.png", 0, 4.0, 0.5, 14, 9.0, 0.38)
	var pm: ParticleProcessMaterial = butterflies.process_material
	pm.emission_box_extents = Vector3(18, 1.2, 18)
	pm.direction = Vector3(1, 0.2, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.3
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.turbulence_noise_scale = 3.5
	pm.turbulence_influence_min = 0.08
	pm.turbulence_influence_max = 0.16
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 0.999
	birds = _make("res://assets/textures/env/fx_bird.png", 1, 2.0, 1.0, 10, 28.0, 1.5)
	pm = birds.process_material
	pm.emission_box_extents = Vector3(160, 12, 160)
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 180.0
	pm.flatness = 1.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3.ZERO

func _make(tex: String, mode: int, cols: float, row_scale: float, amount: int, life: float, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-200, -40, -200), Vector3(400, 120, 400))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if ResourceLoader.exists(tex):
		m.set_shader_parameter("atlas", load(tex))
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("cols", cols)
	m.set_shader_parameter("row_scale", row_scale)
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p

func _process(delta: float) -> void:
	var pl = Game.player
	var w = Game.world
	if pl == null or not is_instance_valid(pl) or not pl.is_inside_tree() or w == null:
		butterflies.emitting = false
		birds.emitting = false
		return
	var pos: Vector3 = pl.global_position
	butterflies.global_position = pos + Vector3(0, 1.4, 0)
	birds.global_position = pos + Vector3(0, 46, 0)
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	var zone_id: String = Game.pd.get("zone", "")
	var outdoors := WorldLayout.in_overworld(zone_id)
	var day: bool = w.night_factor() < 0.35
	var clear: bool = w.weather == "clear" or w.weather_amt < 0.3
	var local := pos - WorldLayout.offset(zone_id)
	var in_city := zone_id == "tidewind" and local.x < 300.0 and local.z > -604.0 and local.z < 1090.0
	butterflies.emitting = outdoors and day and clear and not in_city
	birds.emitting = outdoors and day and clear
