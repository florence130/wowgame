extends StaticBody3D
## Optional cache. Each chest pays once per character and never grants an ember.
@export var chest_id := ""
var unit_name := "修道院遗留宝箱"
var _opened := false
var _lid: Node3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("interactable")
	U.add_box_shape(self, Vector3(1.4, 1, 1), Vector3(0,.5,0))
	U.add_mesh(self,U.box_mesh(Vector3(1.4,.7,1)),U.mat(Color("805735")),Vector3(0,.35,0))
	_lid = Node3D.new()
	_lid.position = Vector3(0,.7,-.5)
	add_child(_lid)
	U.add_mesh(_lid,U.box_mesh(Vector3(1.45,.2,1.05)),U.mat(Color("c9a45d")),Vector3(0,.1,.5))
	_opened = Game.has_flag("sanctum_chest_" + chest_id)
	_refresh()

func _refresh() -> void:
	_lid.rotation_degrees.x = -100 if _opened else 0
	unit_name = "已开启的宝箱" if _opened else "修道院遗留宝箱"

func can_interact() -> bool:
	return not _opened

func interact(player: Node) -> void:
	if _opened or Game.has_flag("sanctum_chest_" + chest_id):
		return
	if player.in_combat:
		Game.err("战斗结束后才能开启宝箱。")
		return
	if global_position.distance_to(player.global_position) > 4.0:
		Game.err("距离太远。")
		return
	Game.pd.flags["sanctum_chest_" + chest_id] = true
	_opened = true
	Game.add_money(120)
	Game.save_game()
	_refresh()
