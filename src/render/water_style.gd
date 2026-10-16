class_name WaterStyle
extends RefCounted
## Shared purchased texture binding for terrain, ocean and small prop water.
static func configure(material: ShaderMaterial, strength: float = 1.0) -> void:
	material.set_shader_parameter("normal_tex", preload("res://assets/textures/environment_packs/water_normal.png"))
	material.set_shader_parameter("foam_tex", preload("res://assets/textures/environment_packs/water_foam.png"))
	material.set_shader_parameter("caustics_tex", preload("res://assets/textures/environment_packs/water_caustics.png"))
	material.set_shader_parameter("wave_strength", strength)
