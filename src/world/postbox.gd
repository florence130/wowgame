class_name Postbox
extends StaticBody3D
## 世界里的邮箱柱：靠近后按交互键（默认 F）打开邮箱窗口。
## 摆放表见 DataWorld.postboxes()，由 world.gd 在区域加载时生成。

const WOOD := Color("6a4a30")
const BODY_C := Color("c0503a")
const GOLD := Color("e8c27a")

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	_build()

func _build() -> void:
	# 底座 + 柱身
	U.add_mesh(self, U.cyl_mesh(0.22, 0.26, 0.12, 8), U.mat(WOOD.darkened(0.15)), Vector3(0, 0.06, 0))
	U.add_mesh(self, U.cyl_mesh(0.09, 0.12, 1.25, 8), U.mat(WOOD), Vector3(0, 0.62, 0))
	# 箱体与顶盖
	U.add_mesh(self, U.box_mesh(Vector3(0.46, 0.5, 0.34)), U.mat(BODY_C), Vector3(0, 1.42, 0))
	U.add_mesh(self, U.box_mesh(Vector3(0.52, 0.09, 0.4)), U.mat(BODY_C.darkened(0.22)), Vector3(0, 1.72, 0))
	# 投信口（面向 +Z）与黄铜饰条
	U.add_mesh(self, U.box_mesh(Vector3(0.28, 0.045, 0.02)), U.mat(Color("2a2018")), Vector3(0, 1.56, 0.176))
	U.add_mesh(self, U.box_mesh(Vector3(0.48, 0.05, 0.02)), U.mat(GOLD), Vector3(0, 1.28, 0.176))
	# 小旗（有信号旗的味道，也方便远处看见）
	U.add_mesh(self, U.cyl_mesh(0.03, 0.03, 0.3, 6), U.mat(GOLD), Vector3(0.2, 1.86, 0.0))
	U.add_mesh(self, U.box_mesh(Vector3(0.14, 0.1, 0.02)), U.mat(Color("f2ede0")), Vector3(0.28, 1.94, 0.0))
	U.add_cyl_shape(self, 0.24, 1.5, Vector3(0, 0.9, 0))

func can_interact() -> bool:
	return true

func interact(_p: Player) -> void:
	if Game.hud == null:
		return
	Game.hud.open_window("mail")
	Sfx.play("open")
