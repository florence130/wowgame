extends SceneTree
func _initialize() -> void:
	call_deferred("run_check")
var entries: Array = []
var failed: int = 0
func inspect(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var m = node.get_active_material(i)
			if m != null and (m.resource_name.begins_with("ABY2_glass") or m.resource_name.begins_with("ABY2_window_glow")):
				var supported_alpha_modes = [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]
				var ok = m is BaseMaterial3D and m.transparency in supported_alpha_modes and m.albedo_color.a > 0 and m.albedo_color.a < 1 and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var mode_name = "TRANSPARENCY_ALPHA_DEPTH_PRE_PASS" if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS else "TRANSPARENCY_ALPHA"
				entries.append({"name":m.resource_name,"passed":ok,"transparency":m.transparency,"transparency_name":mode_name,"alpha":m.albedo_color.a,"shading_mode":m.shading_mode,"shadow_casting":node.cast_shadow})
				if not ok:failed+=1
	for child in node.get_children():inspect(child)
func run_check() -> void:
	var folder="E:/wowgame/.local/abbey_glass_probe"
	var doc=GLTFDocument.new();var state=GLTFState.new()
	var err=doc.append_from_file(folder+"/window_transparent.glb",state)
	var imported=doc.generate_scene(state) if err==OK else null
	if imported==null:failed+=1
	else:
		root.add_child(imported);inspect(imported);imported.free()
	if entries.size()!=2:failed+=1
	var report={"passed":failed==0,"engine":Engine.get_version_info(),"load_error":err,"window_materials":entries,"scope":"Actual Godot GLB import, alpha transparency, per-pixel lit material and shadow flags; not a headless raster visibility test"}
	var file=FileAccess.open(folder+"/godot_glass_evidence.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("GODOT_GLASS_CHECK ",JSON.stringify(report));quit(0 if failed==0 else 1)
