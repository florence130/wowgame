extends SceneTree

func _initialize() -> void:
	var catalog: Dictionary = load("res://src/data/data_job_spells.gd").spells()
	var out := {}
	for sid in catalog:
		out[sid] = clean(catalog[sid])
	var file := FileAccess.open("E:/wow-combat-lab/reference/current_kits.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	print("EXPORTED ", out.size(), " skills")
	quit()

func clean(value: Variant) -> Variant:
	if value is Color:
		return "#" + value.to_html()
	if value is Dictionary:
		var result := {}
		for key in value:
			if key in ["name", "desc", "rotation_role"]:
				continue
			result[key] = clean(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(clean(entry))
		return result
	return value
