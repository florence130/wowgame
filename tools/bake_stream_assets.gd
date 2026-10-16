extends Node
## Rebuild only derived, versioned runtime assets; original maps/GLBs are never rewritten.
const Kit := preload("res://src/world/goldshire_kit.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Kit.BAKED))
	var ids: Array = Kit.LABELS.values()
	ids.append_array(Kit.HOMES)
	for id in ids:
		var root := Kit.create(id, true, false)
		if root == null:
			get_tree().quit(1)
			return
		_owners(root, root)
		var packed := PackedScene.new()
		var err := packed.pack(root)
		if err == OK:
			err = ResourceSaver.save(packed, Kit.BAKED + id + ".scn", ResourceSaver.FLAG_COMPRESS)
		root.free()
		if err != OK:
			push_error("Streaming bake failed: " + id)
			get_tree().quit(1)
			return
		FileAccess.open(Kit.BAKED + id + ".sha256", FileAccess.WRITE).store_string(Kit.bake_signature(id))
		print("[stream bake] ", id)
		Kit.cache.erase(id)
		await get_tree().process_frame
	get_tree().quit()

func _owners(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_owners(c, root)
