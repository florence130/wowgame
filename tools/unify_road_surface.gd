extends Node

func _ready() -> void:
	for id in ["vale", "tidewind"]:
		var path := "res://data/terrain/%s.res" % id
		var data := load(path) as TerrainData
		var before := data.heights.duplicate()
		data.layer_colors = PackedColorArray(ArtStyle.TERRAIN_COLORS)
		WorldLayout.stitch_road_surface(data, Vector2.ZERO if id == "vale" else GenTidewind.ORIGIN, id)
		assert(data.heights == before, "Surface repair must preserve elevations")
		assert(ResourceSaver.save(data, path) == OK)
		print("SURFACE UPDATED ", id, "; heights preserved")
	get_tree().quit()
