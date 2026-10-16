extends Node
## 导出区域俯视地图（MapGen）为 PNG：godot --headless --path . res://tests/mapshot.tscn -- tidewind
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var zid: String = args[0] if args.size() > 0 else "tidewind"
	var path: String = DB.zones[zid]["scene"]
	var z: Node = load(path).instantiate()
	add_child(z)
	await get_tree().process_frame
	var tex := MapGen.build(z)
	var out := ProjectSettings.globalize_path("res://.shots/map_%s.png" % zid)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	tex.get_image().save_png(out)
	print("MAPSHOT ", out)
	get_tree().quit()
