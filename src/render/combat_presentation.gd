class_name CombatPresentation
extends RefCounted
## Production bridge for the independently authored presentation module.
static var _module: Script

static func available() -> bool:
	if _module == null and ResourceLoader.exists("res://src/render/combat_feedback.gd"):
		_module = load("res://src/render/combat_feedback.gd")
	return _module != null and _module.can_instantiate()

static func emit(caster: Unit, origin: Vector3, destination: Vector3, school: String, style: String, strength: float = 1.0) -> bool:
	if not caster.is_player or not caster.get_parent() is Node3D or not available():
		return false
	var parent: Node3D = caster.get_parent()
	var palette: String = {"holy":"light", "neutral":"arcane"}.get(school, school)
	_module.emit(parent, parent.to_local(origin), parent.to_local(destination), palette, style, strength)
	return true

static func anticipate(caster: Unit, sp: Dictionary, target: Unit) -> void:
	var destination := target.chest_pos() if is_instance_valid(target) else caster.chest_pos() + caster.forward_dir()
	emit(caster, caster.chest_pos(), destination, str(sp.get("school", "arcane")), "cast", 0.6)

static func release(caster: Unit, sp: Dictionary, target: Unit) -> void:
	if not caster.is_player:
		return
	var school: String = sp.get("school", "physical")
	var destination := target.chest_pos() if is_instance_valid(target) else caster.chest_pos() + caster.forward_dir()
	var animation: String = sp.get("animation", "")
	var style: String = {"hammer":"heavy", "piston":"heavy", "dual":"slash", "stab":"thrust", "rapier":"thrust", "rifle":"shot", "shotgun":"shot", "cannon":"shot", "rocket":"shot", "rail":"shot"}.get(animation, animation)
	if style not in ["slash", "heavy", "shield", "thrust", "shot"]:
		style = "shot" if sp.has("projectile") else "cast"
	for effect in sp.get("effects", []):
		if effect.get("type", "") == "aoe":
			var center := caster.global_position
			if effect.get("center", "self") == "target" and is_instance_valid(target):
				center = target.global_position
			center += Vector3.UP * .06
			emit(caster, center, center, school, "aoe", float(effect.get("radius", 3.0)))
			return
		if effect.get("type", "") in ["heal", "heal_pct", "heal_self_pct"]:
			emit(caster, caster.chest_pos(), destination, school, "heal", 0.85)
			return
	emit(caster, caster.chest_pos(), destination, school, style, 1.2 if style == "heavy" else 0.8)

static func contact(caster: Unit, target: Unit, school: String, critical: bool) -> bool:
	return emit(caster, caster.chest_pos(), target.chest_pos(), school, "impact", 1.35 if critical else 0.8)
