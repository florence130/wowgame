class_name GatherNode
extends StaticBody3D
## 可采集物体：右键/F 采集（引导读条）

const TYPES := {
	"herb_dew": {"name": "晨露草", "item": "q_herb_dew", "quest": true, "verb": "采集"},
	"grape_crate": {"name": "葡萄酒箱", "item": "q_grape_crate", "quest": true, "verb": "搬运"},
	"fishing_net": {"name": "鲍勃的渔网", "item": "q_fishing_net", "quest": true, "verb": "收起"},
	"lumber_pile": {"name": "优质木材", "item": "q_lumber", "quest": true, "verb": "搬运"},
	"miner_body": {"name": "老汤米的遗物", "item": "q_miner_badge", "quest": true, "verb": "搜索"},
	"signal_part": {"name": "信号灯零件", "item": "q_signal_part", "quest": true, "verb": "拾取"},
	"crop_sample": {"name": "变异的麦穗", "item": "q_crop_sample", "quest": true, "verb": "采集"},
	# 余烬章节的外勤物证；visual 复用已有模型类别，不产生无图标的占位物。
	"ember_ledger": {"name": "灰烬账本", "item": "q_ash_ledger", "quest": true, "verb": "取出", "visual": "signal_part"},
	"ember_manifest": {"name": "失踪的账页", "item": "q_ledger_page", "quest": true, "verb": "取回", "visual": "signal_part"},
	"ember_cargo": {"name": "封存货箱标签", "item": "q_e_cargo_seal", "quest": true, "verb": "撕下", "visual": "grape_crate"},
	"ember_dispatch": {"name": "篡改的调度单", "item": "q_e_dispatch", "quest": true, "verb": "收集", "visual": "signal_part"},
	"ember_signal": {"name": "信号继电器", "item": "q_e_signal_part", "quest": true, "verb": "拆下", "visual": "signal_part"},
	"ember_cache": {"name": "密封补给箱", "item": "q_e_coast_cache", "quest": true, "verb": "搬运", "visual": "grape_crate"},
	"ember_rescue": {"name": "船员急救包", "item": "q_e_rescue_kit", "quest": true, "verb": "收回", "visual": "signal_part"},
	"ember_frame": {"name": "航标镜架", "item": "q_e_lens_frame", "quest": true, "verb": "取下", "visual": "signal_part"},
	"ember_cipher": {"name": "航标密文", "item": "q_e_cipher", "quest": true, "verb": "抄录", "visual": "signal_part"},
	"ember_charge": {"name": "余烬装药", "item": "q_e_charge", "quest": true, "verb": "撤下", "visual": "grape_crate"},
	"ember_shutdown": {"name": "停机阀组件", "item": "q_e_shutdown", "quest": true, "verb": "拆卸", "visual": "signal_part"},
	"herb": {"name": "宁神花", "item": "mat_herb", "quest": false, "verb": "采集"},
	"ore": {"name": "铜矿脉", "item": "mat_copper", "quest": false, "verb": "开采"},
}

var node_type := "herb"
var spot: Node = null
var _vis: Node3D
var _glow: Node3D
var _check := 0.0
var _active := true

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("interactable")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.2, 1.2, 1.2)
	cs.shape = sh
	cs.position = Vector3(0, 0.6, 0)
	add_child(cs)
	_vis = Node3D.new()
	add_child(_vis)
	var visual_type := String(TYPES.get(node_type, {}).get("visual", node_type))
	match visual_type:
		"herb_dew", "herb", "crop_sample":
			var c := Color("90e0a0") if node_type == "herb_dew" else (Color("f0f0a0") if node_type == "herb" else Color("e0d060"))
			for i in 5:
				var a := i * TAU / 5.0
				U.add_mesh(_vis, U.capsule_mesh(0.05, 0.5), U.char_mat(Color("4a9a3a"), false), Vector3(cos(a) * 0.12, 0.25, sin(a) * 0.12), Vector3(cos(a) * 20, 0, sin(a) * 20))
				U.add_mesh(_vis, U.sphere_mesh(0.09), U.char_mat(c, false, 0.6), Vector3(cos(a) * 0.2, 0.5, sin(a) * 0.2))
		"grape_crate", "lumber_pile":
			if visual_type == "grape_crate":
				U.add_mesh(_vis, U.box_mesh(Vector3(0.8, 0.6, 0.6)), U.char_mat(Color("a06a40")), Vector3(0, 0.3, 0))
				for i in 6:
					U.add_mesh(_vis, U.sphere_mesh(0.09), U.char_mat(Color("7a3a9a"), false), Vector3((i % 3 - 1) * 0.2, 0.66, (i / 3 - 0.5) * 0.2))
			else:
				for i in 5:
					U.add_mesh(_vis, U.cyl_mesh(0.15, 0.15, 1.6, 8), U.char_mat(Color("9a6a40")), Vector3((i % 3 - 1) * 0.3, 0.15 + (i / 3) * 0.26, 0), Vector3(90, 0, 0))
		"fishing_net":
			U.add_mesh(_vis, U.box_mesh(Vector3(1.0, 0.15, 0.8)), U.char_mat(Color("c0b090")), Vector3(0, 0.08, 0))
			U.add_mesh(_vis, U.sphere_mesh(0.1), U.char_mat(Color("e04040")), Vector3(0.4, 0.2, 0.3))
		"miner_body":
			U.add_mesh(_vis, U.box_mesh(Vector3(0.6, 0.5, 0.4)), U.char_mat(Color("6a5040")), Vector3(0, 0.25, 0))
			U.add_mesh(_vis, U.sphere_mesh(0.25, 0.5, true), U.char_mat(Color("e0c040")), Vector3(0.5, 0.0, 0.2))
			U.add_mesh(_vis, U.cyl_mesh(0.02, 0.03, 0.8), U.char_mat(Color("5a4030")), Vector3(-0.4, 0.1, 0), Vector3(0, 0, 80))
		"signal_part":
			U.add_mesh(_vis, U.cyl_mesh(0.2, 0.2, 0.3, 10), U.char_mat(Color("a0a0a8")), Vector3(0, 0.15, 0))
			U.add_mesh(_vis, U.sphere_mesh(0.12), U.char_mat(Color("40ff60"), false, 0.8), Vector3(0, 0.35, 0))
		"ore":
			U.add_mesh(_vis, U.sphere_mesh(0.6, 1.2, false, 7), U.char_mat(Color("8a8070")), Vector3(0, 0.3, 0), Vector3(0, 0, 0), Vector3(1.2, 0.8, 1))
			for i in 4:
				U.add_mesh(_vis, U.sphere_mesh(0.14), U.char_mat(Color("e08040"), false, 0.3), Vector3(cos(i * 1.6) * 0.45, 0.4 + sin(i) * 0.15, sin(i * 1.6) * 0.45))
	# 任务物品发光提示
	_glow = MeshInstance3D.new()
	(_glow as MeshInstance3D).mesh = U.torus_mesh(0.7, 0.8, 24)
	(_glow as MeshInstance3D).material_override = U.unshaded(Color(1, 0.9, 0.3, 0.7), true)
	_glow.position.y = 0.05
	add_child(_glow)
	_refresh()

func _refresh() -> void:
	var t: Dictionary = TYPES.get(node_type, {})
	var needed = not t.get("quest", false) or Game.quest_needs_item(t.get("item", ""))
	_glow.visible = needed and t.get("quest", false)
	_active = needed

func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_refresh()
	if _glow.visible:
		_glow.rotation.y += delta
		_glow.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() / 300.0) * 0.08)

func can_interact() -> bool:
	return _active

func interact(p: Node) -> void:
	var t: Dictionary = TYPES.get(node_type, {})
	if not _active:
		if t.get("quest", false):
			Game.err("你现在不需要这个。")
		return
	if p.in_combat:
		Game.err("你正处于战斗中！")
		return
	var sp := {"id": "gather", "name": "%s：%s" % [t.get("verb", "采集"), t.get("name", "")], "cast": 1.5, "gcd": 0.0, "target": "self", "effects": []}
	if p.begin_cast(sp, p):
		var me := self
		var cb := func(ok: bool):
			if ok and is_instance_valid(me):
				me._complete(p)
		p.cast_stopped.connect(cb, CONNECT_ONE_SHOT)

func _complete(_p: Node) -> void:
	var t: Dictionary = TYPES.get(node_type, {})
	if Game.add_item(t.get("item", ""), 1) == 0:
		if spot and is_instance_valid(spot):
			spot.on_gathered(self)
		Achieve.bump("gather")
		queue_free()
