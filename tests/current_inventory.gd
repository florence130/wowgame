extends "res://tests/environment_pack.gd"
## Read-only inventory of currently instantiated buildings and their resolved assets.
func run() -> void:
	while not is_instance_valid(Game.world) or Game.world.loading or not is_instance_valid(Game.player):
		await get_tree().process_frame
	var rows: Array = []
	for zone_id in Game.world.zones:
		var zone: Node = Game.world.zones[zone_id]
		var buildings: Node = zone.get_node_or_null("Buildings")
		if buildings == null:
			continue
		for prop in buildings.get_children():
			if prop is ModelProp:
				rows.append({"zone":zone_id,"node":str(prop.name),"kind":prop.kind,"asset":prop.asset_scene,"modular":prop.get_meta("modular_asset_scene", ""),"pos":[prop.global_position.x,prop.global_position.y,prop.global_position.z]})
	var grouped := {}
	for row in rows:
		var key: String = row.asset if row.asset != "" else "(procedural/legacy)"
		grouped[key] = int(grouped.get(key,0)) + 1
	var report := {"rows":rows,"grouped":grouped,"zones":Game.world.zones.keys()}
	var p := "res://.local/current_inventory_20261011.json"
	FileAccess.open(p,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CURRENT INVENTORY ",JSON.stringify({"count":rows.size(),"grouped":grouped}))
	get_tree().quit()
