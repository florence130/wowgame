extends OmniLight3D
## Real local illumination, budgeted by World. Attached effects inherit motion/lifetime.
var base_energy := 1.5
var flicker := 0.0
var night_only := false
var phase := 0.0
var age := 0.0
var envelope := 1.0

static func attach(parent: Node3D, pos: Vector3, color: Color, radius: float, energy: float, flame: bool = false, only_night: bool = false) -> OmniLight3D:
	var light = load("res://src/render/local_light.gd").new()
	light.position = pos
	light.light_color = color
	light.omni_range = radius
	light.omni_attenuation = 1.35
	light.base_energy = energy
	light.flicker = 0.065 if flame else 0.0
	light.night_only = only_night
	light.light_energy = energy
	light.light_volumetric_fog_energy = 0.15
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 0.7
	light.shadow_blur = 1.2
	light.distance_fade_enabled = true
	light.distance_fade_begin = 45.0
	light.distance_fade_length = 20.0
	light.distance_fade_shadow = 24.0
	light.visible = false
	parent.add_child(light)
	return light

func _ready() -> void:
	add_to_group("environment_local_lights")
	phase = float(get_instance_id() % 1000) * 0.17
	# Initial selection also handles a newly spawned spell between budget updates.
	if is_instance_valid(Game.world):
		Game.world._update_effect_lights()

func _process(delta: float) -> void:
	age += delta
	if not visible:
		return
	var pulse := 1.0 + flicker * (sin(age * 7.1 + phase) * 0.6 + sin(age * 11.3 + phase * 2.0) * 0.4)
	var night := smoothstep(0.02, 0.65, Game.world.night_factor()) if night_only and is_instance_valid(Game.world) else 1.0
	light_energy = base_energy * pulse * envelope * night
