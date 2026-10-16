@tool
extends EditorScenePostImport
## Optional import script when importing the source GLB instead of supplied .scn.
## Assign this as the GLB advanced import script, then reimport that asset.
func _post_import(scene: Node) -> Object:
	visit(scene)
	return scene
func visit(n: Node) -> void:
	if n is MeshInstance3D:
		for i in n.mesh.get_surface_count():
			var m = n.mesh.surface_get_material(i)
			if m is BaseMaterial3D:
				m.roughness = 1.0
				m.metallic_specular = 0.0
				m.metallic = 0.0
				m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for child in n.get_children(): visit(child)
