@tool
extends Node3D
## Portable campfire: the scene owns geometry, collision, flame material and light.
@export var lit := true:
	set(value):
		lit = value
		if is_inside_tree():
			$Flames.visible = lit
			$FireLight.visible = lit
var elapsed := 0.0

func _ready() -> void:
	$Flames.visible = lit
	$FireLight.visible = lit
	set_process(not Engine.is_editor_hint())

func _process(delta: float) -> void:
	elapsed += delta
	$FireLight.light_energy = 3.4 + sin(elapsed * 8.7) * 0.17 + sin(elapsed * 13.1) * 0.13
