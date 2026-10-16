class_name VolumetricAtmosphere
extends Node3D
## Camera-centered Ethereal adaptation using native, shadow-aware volume integration.
var volume: FogVolume
var material: ShaderMaterial

func _ready() -> void:
	name = "EtherealAtmosphere"
	volume = FogVolume.new()
	volume.name = "HeightFog"
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	volume.size = Vector3(560, 260, 560)
	material = ShaderMaterial.new()
	material.shader = preload("res://src/render/ethereal_fog.gdshader")
	material.set_shader_parameter("fog_noise", preload("res://assets/textures/environment_packs/fog_noise.png"))
	volume.material = material
	add_child(volume)

func update(world: Node3D, weather: EnvironmentWeather, night: float) -> void:
	var enabled: bool = Game.settings.get("volumetric_fog", true) and RenderingServer.get_current_rendering_method() == "forward_plus"
	world.env.volumetric_fog_enabled = enabled
	if not enabled:
		volume.visible = false
		return
	volume.visible = true
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position
	var ground: float = world.player.global_position.y if is_instance_valid(world.player) else global_position.y - 2.0
	material.set_shader_parameter("ground_height", ground)
	# A clear night has a low, camera-height haze of its own.  Weather stacks on
	# top of it; the extra density is deliberately small so close props retain
	# warm lamp and moon contrast while the far field gains visible layers.
	# Raise the clear-night floor slightly so distant layers separate in a
	# readable blue-violet veil; keep the value below the rain/mist branch so
	# close props and character silhouettes stay crisp.
	var night_haze := night * (0.0052 + (1.0 - weather.overcast) * 0.0018)
	material.set_shader_parameter("density", lerpf(0.0011, 0.013, weather.mist) + weather.rain * 0.0035 + night_haze)
	material.set_shader_parameter("fog_color", world.env.fog_light_color.lerp(Color("354a83"), night * 0.45))
	world.env.volumetric_fog_density = 0.0
	world.env.volumetric_fog_length = 220.0
	world.env.volumetric_fog_detail_spread = 0.65
	world.env.volumetric_fog_anisotropy = lerpf(0.72, 0.30, weather.overcast)
	world.env.volumetric_fog_ambient_inject = lerpf(0.12, 0.17, night)
	world.env.volumetric_fog_temporal_reprojection_enabled = true
	world.env.volumetric_fog_temporal_reprojection_amount = 0.85
	world.env.volumetric_fog_sky_affect = 0.0
	# Forward sun scattering naturally forms rays where actual tree/building shadows interrupt light.
	world.sun.light_volumetric_fog_energy = (1.0 - night) * (1.0 - weather.overcast * 0.92) * 2.2
	# Let the moon key tint the mist and shoreline air just enough to make
	# moonlight visible in the scene (the sun remains the dominant daytime key).
	world.moon.light_volumetric_fog_energy = night * 0.74
