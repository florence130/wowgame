extends Node
## 免费许可音频：assets/third_party/free_audio/CREDITS.txt。
## 地图日夜保持同源主题；缺失资源保持安静，不叠加随机程序化旋律。
const BGM := {
	"menu": "res://assets/audio/orchestral/menu.ogg",
	"vale_day": "res://assets/audio/orchestral/vale.ogg",
	"vale_night": "res://assets/audio/orchestral/vale.ogg",
	"tidewind_day": "res://assets/audio/orchestral/tidewind.ogg",
	"tidewind_night": "res://assets/audio/orchestral/tidewind.ogg",
	"city_day": "res://assets/audio/orchestral/city.ogg",
	"city_night": "res://assets/audio/orchestral/city.ogg",
	"sanctum_day": "res://assets/audio/orchestral/sanctum.ogg",
	"sanctum_night": "res://assets/audio/orchestral/sanctum.ogg",
	"combat": "res://assets/audio/free/combat_day.ogg",
}
const AMB := {
	"forest_day": "res://assets/audio/free/forest_day.ogg",
	"forest_night": "res://assets/audio/free/forest_night.ogg",
	"village_day": "res://assets/audio/free/village_day.ogg",
	"village_night": "res://assets/audio/free/village_night.ogg",
}
const SFX_KEYS := ["hit", "hit_crit", "swing", "block", "cast", "fire", "frost", "holy", "heal", "shadow", "arcane", "shot", "levelup", "loot", "coin", "quest_accept", "quest_progress", "quest_done", "error", "click", "open", "close", "equip", "learn", "death", "jump", "aggro", "portal", "train", "bell", "thunder"]
const COMBAT_SOURCES := {"hit":"blade", "hit_crit":"blade", "swing":"swing", "block":"metal", "fire":"fire", "frost":"frost", "water":"water", "thunder":"lightning", "lightning":"lightning", "holy":"light", "light":"light", "heal":"light", "shadow":"shadow", "arcane":"shadow", "wind":"swing", "cast":"shadow", "step_stone_a":"step_stone_a", "step_stone_b":"step_stone_b", "step_dirt":"step_dirt"}
const COMBAT_GAPS := {"hit":0.045,"hit_crit":0.045,"swing":0.06,"block":0.06,"fire":0.08,"frost":0.08,"water":0.08,"thunder":0.1,"lightning":0.1,"holy":0.1,"light":0.1,"heal":0.1,"shadow":0.08,"arcane":0.08,"wind":0.08,"cast":0.1,"shot":0.06}
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _spatial_players: Array[AudioStreamPlayer3D] = []
var _last_combat_sound := {}
var _spatial_cursor := 0
var _next := 0
var _music_mode := "field"
var _rng := RandomNumberGenerator.new()
# 真实音频（BGM 与环境音各一路，平滑淡入淡出）
var _bgm: AudioStreamPlayer
var _bgm_out: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _amb_out: AudioStreamPlayer
var _bgm_mode := ""
var _bgm_on := false
var _amb_want := ""
var _amb_mode := ""
var _amb_target := -80.0
var _amb_check := 0.0
var _last_amb_volume := -1.0
var _tracks := {}
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	for i in 16:
		var spatial := AudioStreamPlayer3D.new()
		spatial.bus = "Master"
		spatial.unit_size = 10.0
		spatial.max_distance = 48.0
		spatial.max_db = 0.0
		spatial.attenuation_filter_cutoff_hz = 14000.0
		add_child(spatial)
		_spatial_players.append(spatial)
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = "Master"
	_bgm.volume_db = -80.0
	add_child(_bgm)
	_bgm_out = AudioStreamPlayer.new()
	_bgm_out.volume_db = -80.0
	add_child(_bgm_out)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Master"
	_amb.volume_db = -80.0
	add_child(_amb)
	_amb_out = AudioStreamPlayer.new()
	_amb_out.volume_db = -80.0
	add_child(_amb_out)
	_build()
	_load_tracks()

func _build() -> void:
	for key in SFX_KEYS:
		var path := "res://assets/audio/free/%s.ogg" % key
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
		else:
			push_warning("Missing licensed sound: " + key)
	for key in COMBAT_SOURCES:
		var path := "res://assets/audio/combat/%s.wav" % COMBAT_SOURCES[key]
		var stream := AudioStreamWAV.load_from_file(path)
		if stream != null:
			_streams[key] = stream

func play(key: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(key):
		return
	var v: float = Game.settings.get("sfx", 0.7) if is_instance_valid(Game) else 0.7
	if v <= 0.01:
		return
	var p := _players[_next]
	_next = (_next + 1) % 12
	p.stream = _streams[key]
	p.volume_db = vol_db + linear_to_db(v)
	p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
	p.play()

func play_at(key: String, pos: Vector3, vol_db: float = 0.0) -> void:
	if not _streams.has(key):
		return
	var pl = Game.player
	if pl != null and is_instance_valid(pl):
		var d: float = pl.global_position.distance_to(pos)
		if d > 48.0:
			return
	var v: float = Game.settings.get("sfx", 0.7)
	if v <= 0.01:
		return
	var now := Time.get_ticks_usec() * 0.000001
	if COMBAT_GAPS.has(key):
		if now - float(_last_combat_sound.get(key, -100.0)) < float(COMBAT_GAPS[key]):
			return
		_last_combat_sound[key] = now
	# Reuse idle voices first. A distant cue cannot cut off a nearer contact.
	var voice: AudioStreamPlayer3D
	for step in _spatial_players.size():
		var candidate := _spatial_players[(_spatial_cursor + step) % _spatial_players.size()]
		if not candidate.playing:
			voice = candidate
			_spatial_cursor = (_spatial_cursor + step + 1) % _spatial_players.size()
			break
	if voice == null:
		return
	voice.global_position = pos + Vector3.UP
	voice.stream = _streams[key]
	voice.volume_db = vol_db + linear_to_db(v)
	voice.pitch_scale = _rng.randf_range(0.97, 1.03) * (0.88 if key == "hit_crit" else 1.0)
	voice.play()

func set_music(mode: String) -> void:
	_music_mode = mode
	var key := "bgm:" + mode
	# 战斗也使用完整授权音频。
	_bgm_on = _tracks.has(key)
	if _bgm_on:
		# 临时昼夜同曲时保留进度，只改变音量。
		if _bgm.stream == _tracks[key]:
			_bgm_mode = mode
		if _bgm_mode != mode or _bgm.stream == null:
			_bgm_out.stop()
			var old := _bgm
			_bgm = _bgm_out
			_bgm_out = old
			_bgm_mode = mode
			_bgm.stream = _tracks[key]
			_bgm.stop()
		# 换曲或之前被静音/淡出 stop 过：从一个较低但听得见的音量淡入
		var mv: float = Game.settings.get("music", 0.4)
		if not _bgm.playing and mv > 0.01:
			_bgm.volume_db = -40.0
			_bgm.play()

## 环境音：户外自然昼夜纹理，由 world 按玩家位置设置。
func set_ambience(kind: String) -> void:
	if _amb_want != kind:
		_amb_want = kind
		_amb_check = 0.0  # 立刻重算，进城/出城不用等下一次轮询

## 载入真实音频并设为循环（ogg/mp3 用 loop 属性，wav 用整曲前向循环）
func _load_tracks() -> void:
	for mode in BGM:
		var t := _load_looping(String(BGM[mode]))
		if t != null:
			_tracks["bgm:" + mode] = t
	for k in AMB:
		var t2 := _load_looping(String(AMB[k]))
		if t2 != null:
			_tracks["amb:" + k] = t2

func _load_looping(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		# wav 可能是压缩流（QOA/ADPCM），loop_begin/loop_end 的单位是「帧」而不是字节，
		# 所以用「时长 × 采样率」求帧数，整曲前向循环。
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			var frames := int(round(w.get_length() * float(w.mix_rate)))
			if frames > 0:
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = frames
	return s

## BGM 与环境音的平滑切换（每帧推进音量；环境音每 4 秒确认白天/夜晚与进没进城）
func _fade_audio(delta: float, mv: float) -> void:
	var bgm_db := -80.0 if mv <= 0.01 else linear_to_db(mv) - 3.0
	if _music_mode.ends_with("_night"):
		bgm_db -= 5.0 # 临时同曲低音量；尚非钢琴竖琴改编
	var av: float = Game.settings.get("sfx", 0.7)
	if av != _last_amb_volume:
		_last_amb_volume = av
		_amb_check = 0.0
	var amb_db := -80.0 if av <= 0.01 else linear_to_db(av) - 7.0
	for outgoing in [_bgm_out, _amb_out]:
		outgoing.volume_db = move_toward(outgoing.volume_db, -80.0, 32.0 * delta)
		if outgoing.volume_db <= -79.0:
			outgoing.stop()
	if mv <= 0.01:
		_bgm_out.stop()
	if av <= 0.01:
		_amb_out.stop()
	# 设置里解除静音后恢复播放，不需要再次进入场景。
	if _bgm_on and mv > 0.01 and not _bgm.playing:
		_bgm.volume_db = -40.0
		_bgm.play()
	_bgm.volume_db = move_toward(_bgm.volume_db, bgm_db if _bgm_on else -80.0, 40.0 * delta)
	if _bgm.volume_db <= -79.0 and _bgm.playing:
		_bgm.stop()
	_amb_check -= delta
	if _amb_check <= 0.0:
		_amb_check = 4.0
		var want := ""
		if _amb_want != "" and av > 0.01:
			var night: bool = Game.time_of_day < 5.5 or Game.time_of_day > 20.0
			want = "%s_%s" % [_amb_want, "night" if night else "day"]
		var key := "amb:" + want
		if want == "" or not _tracks.has(key):
			if _amb_mode != "":
				_amb_mode = ""
				_amb_target = -80.0
		elif _amb_mode != want:
			_amb_out.stop()
			var old := _amb
			_amb = _amb_out
			_amb_out = old
			_amb_mode = want
			_amb.stream = _tracks[key]
			_amb.volume_db = -40.0  # 从可听见的音量淡入，避免同帧被判成静音而 stop
			_amb.play()
			_amb_target = amb_db
		else:
			_amb_target = amb_db
			if not _amb.playing:
				_amb.volume_db = -40.0
				_amb.play()
	_amb.volume_db = move_toward(_amb.volume_db, _amb_target, 18.0 * delta)
	if _amb.volume_db <= -79.0 and _amb.playing:
		_amb.stop()

func _process(delta: float) -> void:
	var mv: float = Game.settings.get("music", 0.4) if is_instance_valid(Game) else 0.4
	if is_instance_valid(Game):
		_fade_audio(delta, mv)
