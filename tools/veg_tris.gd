extends SceneTree
## 打印植被模型（原模型 / 绘本版 / proxy）的三角形数，用于远景 LOD 决策
func _tri(m: Mesh) -> int:
	var t := 0
	for i in m.get_surface_count():
		var ar := m.surface_get_arrays(i)
		t += (ar[Mesh.ARRAY_INDEX].size() if ar[Mesh.ARRAY_INDEX] != null and ar[Mesh.ARRAY_INDEX].size() > 0 else ar[Mesh.ARRAY_VERTEX].size()) / 3
	return t

func _initialize() -> void:
	for n in ["pine_0", "oak_0", "oak_1", "round_0", "birch_0", "bush_0"]:
		var s := "VEG %-8s" % n
		for sb in [false, true]:
			var parts := Forest._veg_parts(n, sb)
			var t := 0
			for p in parts:
				t += _tri(p[0])
			s += "  %s=%d(%d parts)" % ["storybook" if sb else "plain", t, parts.size()]
		print(s)
	var far := FarLandscape.new()
	print("FAR cone tree tris=", _tri(far._tree_mesh()))
	far.free()
	quit()
