extends World
## Playable isolated fixture. Normal Player input, physics, animations and HUD.
const LOOPS = preload("res://tests/job_rotations.gd")
var enemy: Unit
var patient: Unit
var patient_frame: UnitFrame
var capture_mode := false
var boss_clock := 0.0
var telegraph_at := -1.0
var captured: Array = []
var input_checks: Array = []

func simulation_suspended() -> bool:
	return false

func ground_ready(_at: Vector3) -> bool:
	return true

func night_factor() -> float:
	return 0.0

func _ready() -> void:
	Game.slot_index = -1
	Game.world = self
	Game.zone = null
	Game.set_process(false)
	capture_mode = "capture=true" in OS.get_cmdline_user_args()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("8dabbc")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c2d5e5")
	environment.environment.ambient_light_energy = 0.75
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -35, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)
	_box(Vector3(0, -0.2, 0), Vector3(32, 0.4, 32), Color("718c83"))
	_box(Vector3(-6, 1.2, -3), Vector3(0.5, 2.4, 8), Color("6c7688"))
	_box(Vector3(6, 1.2, -3), Vector3(0.5, 2.4, 8), Color("6c7688"))
	choose_job("dark_mage")
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	layer.add_child(hud)
	Game.hud = hud
	_connect_player()
	var menu := VBoxContainer.new()
	menu.position = Vector2(20, 132)
	layer.add_child(menu)
	menu.add_child(UITheme.label("转职试战 · 独立角色，不保存\nW S / Q E移动，Tab选敌，1–=技能\n动作条翻滚，N转职面板\n首领红圈需离开；盾反只挡近战", 16))
	for job in LOOPS.PRIORITIES:
		var id: String = job
		menu.add_child(UITheme.button(DB.spec_index[id]["name"], func(): choose_job(id); _connect_player(), 145))
	patient_frame = UnitFrame.new()
	patient_frame.small = true
	patient_frame.position = Vector2(20, 610)
	layer.add_child(patient_frame)
	patient_frame.set_unit(patient)
	if capture_mode:
		call_deferred("capture_all")

func _box(at: Vector3, dimensions: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	U.add_mesh(body, U.box_mesh(dimensions), U.char_mat(color))
	add_child(body)
	body.position = at

func choose_job(job: String) -> void:
	Game.player = null
	if is_instance_valid(player):
		player.stop_cast()
		player.free()
	if is_instance_valid(enemy):
		enemy.free()
	if is_instance_valid(patient):
		patient.free()
	Game.new_character("试战角色", DB.spec_index[job]["class"], DB.random_appearance(7, "f"))
	Game.pd["new"] = false
	Game.pd["level"] = 15
	Game.pd["money"] = 10000
	var weapon: String = {"paladin": "sword", "berserker": "axe2", "dark_mage": "staff", "elementalist": "staff", "radiant": "staff", "shadow_priest": "mace2", "assassin": "dagger", "duelist": "rapier", "marksman": "sword", "gadgeteer": "sword"}[job]
	Game.pd.equip.main = "gen|%s|green|15|bear" % weapon
	if job == "paladin":
		Game.pd.equip.off = "gen|shield|green|15|bear"
	if job == "assassin":
		Game.pd.equip.off = "gen|dagger|green|15|monkey"
	if DB.spec_index[job]["class"] == "gunner":
		Game.pd.equip.ranged = "gen|gun|green|15|monkey"
	player = Player.new()
	add_child(player)
	Game.player = player
	Specs.choose(job, true)
	player.position = Vector3(0, 0.02, 2)
	player.cam_dist = 5.5
	player.cam_dist_target = 5.5
	player.cam_pitch = -0.15
	enemy = Unit.new()
	add_child(enemy)
	enemy.unit_name = "机制训练首领"
	enemy.level = 15
	enemy.is_boss = true
	enemy.max_hp = 5000
	enemy.hp = enemy.max_hp
	enemy.stats = {"crit": 0, "dodge": 0, "parry": 0, "armor": 160}
	enemy.position = Vector3(0, 0, -0.8)
	enemy.model = Avatar.new()
	enemy.add_child(enemy.model)
	enemy.model.setup(DB.random_appearance(4, "m"))
	enemy.scale = Vector3.ONE * 1.3
	enemy.face_towards(player.position)
	patient = Unit.new()
	add_child(patient)
	patient.set_physics_process(false)
	patient.faction = "companion"
	patient.unit_name = "治疗训练队友"
	patient.max_hp = 2000
	patient.hp = 1400
	patient.position = Vector3(2, 0, 1)
	patient.model = Avatar.new()
	patient.add_child(patient.model)
	patient.model.setup(DB.random_appearance(5, "f"))
	player.set_target(patient if job == "radiant" else enemy)
	player.face_towards(enemy.position)
	boss_clock = 0
	telegraph_at = -1
	if job == "gadgeteer":
		player.cast_spell_id("mech_armor")

func _connect_player() -> void:
	if not is_instance_valid(hud):
		return
	hud.player_frame.set_unit(player)
	hud.target_frame.set_unit(enemy)
	if is_instance_valid(patient_frame): patient_frame.set_unit(patient)
	player.cast_started.connect(hud._on_cast_start)
	player.cast_stopped.connect(hud._on_cast_stop)
	player.auras_changed.connect(hud._refresh_buffs)
	hud._refresh_all()

func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if capture_mode or not is_instance_valid(player) or player.dead or enemy.dead:
		return
	boss_clock += delta
	patient._tick_auras(delta)
	if player.spec == "radiant" and int(boss_clock) > int(boss_clock - delta):
		patient.take_damage(90, "shadow", enemy, false, "队友治疗压力", true)
	if int(boss_clock / 3.0) > int((boss_clock - delta) / 3.0) and enemy.edge_dist(player) <= 5:
		enemy.face_towards(player.position)
		enemy.model.play_attack(-1)
		enemy.deal_melee_damage(player, 30, "训练近战")
	if boss_clock >= 8 and telegraph_at < 0:
		telegraph_at = boss_clock + 2.0
		Vfx.telegraph(self, enemy.global_position, 8, 2.0, enemy)
	if telegraph_at > 0 and boss_clock >= telegraph_at:
		enemy.apply_effects(DB.spell("mob_stomp", 1), player)
		boss_clock = 0
		telegraph_at = -1

func capture_all() -> void:
	var path := "res://.local/combat_jobs/arena_v2"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	for job in LOOPS.PRIORITIES:
		choose_job(job)
		_connect_player()
		player.set_target(enemy)
		for frame in 35:
			await get_tree().process_frame
		var sid: String = LOOPS.PRIORITIES[job][-1]
		var index: int = Game.pd["bars"].find({"t": "spell", "id": sid})
		var input := InputEventKey.new()
		input.keycode = Game.bar_keys[index % 12]
		input.shift_pressed = index >= 12
		input.pressed = true
		Input.parse_input_event(input)
		input = input.duplicate()
		input.pressed = false
		Input.parse_input_event(input)
		for frame in 12:
			await get_tree().process_frame
		var accepted := player.gcd > 0 or player.is_casting()
		input_checks.append({"job": job, "spell": sid, "keyboard_accepted": accepted})
		print("ARENA INPUT ", job, " ", accepted)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path + "/" + job + ".png")
		captured.append(job)
		print("ARENA CAPTURE ", job)
	Game.hud = null
	Game.world = null
	Game.player = null
	var report := FileAccess.open(path + "/input.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(input_checks, "\t"))
	report.close()
	var failed := input_checks.filter(func(item): return not item.keyboard_accepted).size()
	var tree := get_tree()
	tree.create_timer(0.2).timeout.connect(tree.quit.bind(1 if failed else 0))
	queue_free()
