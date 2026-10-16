extends "res://src/render/local_light.gd"
## Saved sanctum fixtures enter the ordinary world light budget after zone setup.
@export var authored_energy := 1.5
func _ready() -> void:
	base_energy = authored_energy
	add_to_group("environment_local_lights")
	phase = float(get_instance_id() % 1000) * .17
