extends Node

enum Cue { UI_CLICK, PAPER_TURN, PAPER_PUT, TOOL_PICKUP, TOOL_PUT, COFFEE, WARNING }

const CUE_STREAMS := {
	Cue.UI_CLICK: preload("res://Assets/Sounds/UI щелчок.wav"),
	Cue.PAPER_TURN: preload("res://Assets/Sounds/Бумага перелистывание.wav"),
	Cue.PAPER_PUT: preload("res://Assets/Sounds/Бумага падение.wav"),
	Cue.TOOL_PICKUP: preload("res://Assets/Sounds/Предмет взять.wav"),
	Cue.TOOL_PUT: preload("res://Assets/Sounds/Предмет положить.wav"),
	Cue.COFFEE: preload("res://Assets/Sounds/Глоток кофе.wav"),
	Cue.WARNING: preload("res://Assets/Sounds/Предупреждение.wav"),
}
const CUE_GAINS_DB := {
	Cue.UI_CLICK: -4.0, Cue.PAPER_TURN: -5.0, Cue.PAPER_PUT: 3.0,
	Cue.TOOL_PICKUP: 5.0, Cue.TOOL_PUT: -6.0, Cue.COFFEE: 4.0, Cue.WARNING: -9.0,
}

@export_range(2, 32, 1) var sfx_voice_count: int = 8
@export_range(0.0, 3.0, 0.05) var crossfade_seconds: float = 0.6
@export_range(-40.0, 0.0, 0.5) var music_gain_db: float = 0.0
@export_range(-40.0, 0.0, 0.5) var sfx_gain_db: float = -8.0

var _music_players: Array[AudioStreamPlayer] = []
var _music_sources: Array[AudioStream] = [null, null]
var _music_loops: Array[bool] = [false, false]
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _active_music := 0
var _requested_music: AudioStream
var _requested_loop := true
var _requested_volume_db := 0.0
var _music_tween: Tween
var _sfx_loop_player: AudioStreamPlayer
var _sfx_loop_owner: Node
var _sfx_loop_source: AudioStream
var _loop_streams: Dictionary = {}
var _warning_at_ms := -1000


func _ready() -> void:
	_ensure_bus(&"Music")
	_ensure_bus(&"SFX")
	_music_players.assign([$MusicA, $MusicB])
	for index in maxi(sfx_voice_count, 1):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		player.bus = &"SFX"
		$SFX.add_child(player)
		_sfx_players.append(player)
	# One tool is held at a time. Its loop cannot be stolen by dialogue blips.
	_sfx_loop_player = AudioStreamPlayer.new()
	_sfx_loop_player.name = "ToolLoop"
	_sfx_loop_player.bus = &"SFX"
	$SFX.add_child(_sfx_loop_player)
	set_process(false)
	for player in _music_players:
		player.bus = &"Music"
		player.finished.connect(_on_music_finished.bind(player))
	GameSettings.audio_changed.connect(_apply_volumes)
	_apply_volumes()


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")


func play_music(stream: AudioStream, volume_db: float = 0.0, loop: bool = true) -> void:
	if stream == null:
		stop_music()
		return
	if stream == _requested_music and loop == _requested_loop and is_equal_approx(volume_db, _requested_volume_db):
		return
	if _music_tween:
		_music_tween.kill()
	_requested_music = stream
	_requested_loop = loop
	_requested_volume_db = volume_db
	var target := -1
	for index in _music_players.size():
		if _music_sources[index] == stream and _music_loops[index] == loop and _music_players[index].playing:
			target = index
			break
	if target == -1:
		target = 1 - _active_music
		var player := _music_players[target]
		player.stop()
		player.stream = _prepare_music_stream(stream, loop)
		player.volume_linear = 0.0
		_music_sources[target] = stream
		_music_loops[target] = loop
		player.play()
	_active_music = target
	_fade_music(target, db_to_linear(volume_db))


func stop_music() -> void:
	if _requested_music == null:
		return
	_requested_music = null
	if _music_tween:
		_music_tween.kill()
	_fade_music(-1, 0.0)


func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null or GameSettings.sfx_volume <= 0.0:
		return
	var voice := _sfx_cursor
	for offset in _sfx_players.size():
		var index := (_sfx_cursor + offset) % _sfx_players.size()
		if not _sfx_players[index].playing:
			voice = index
			break
	_sfx_cursor = (voice + 1) % _sfx_players.size()
	var player := _sfx_players[voice]
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch_scale, 0.01)
	player.play()


func play_cue(cue: Cue) -> void:
	if GameSettings.sfx_volume <= 0.0:
		return
	if cue == Cue.WARNING:
		var now := Time.get_ticks_msec()
		if now - _warning_at_ms < 750:
			return
		_warning_at_ms = now
	play_sfx(CUE_STREAMS[cue], CUE_GAINS_DB[cue])


func bind_ui_buttons(container: Node, excluded: Array[BaseButton] = []) -> void:
	var click := play_cue.bind(Cue.UI_CLICK)
	for button: BaseButton in container.find_children("*", "BaseButton", true, false):
		if not excluded.has(button) and not button.pressed.is_connected(click):
			button.pressed.connect(click)


func start_sfx_loop(owner: Node, stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or not is_instance_valid(owner) or not owner.can_process() or GameSettings.sfx_volume <= 0.0:
		return
	if _sfx_loop_owner == owner and _sfx_loop_source == stream and _sfx_loop_player.playing:
		return # Mouse motion keeps the same playback instead of restarting it.
	if not _loop_streams.has(stream):
		var prepared := stream.duplicate() as AudioStream
		if prepared is AudioStreamWAV:
			prepared.loop_mode = AudioStreamWAV.LOOP_FORWARD
			prepared.loop_begin = 0
			prepared.loop_end = roundi(prepared.get_length() * prepared.mix_rate)
		elif prepared is AudioStreamMP3 or prepared is AudioStreamOggVorbis:
			prepared.set("loop", true)
		_loop_streams[stream] = prepared
	_sfx_loop_player.stop()
	_sfx_loop_owner = owner
	_sfx_loop_source = stream
	_sfx_loop_player.stream = _loop_streams[stream]
	_sfx_loop_player.volume_db = volume_db
	_sfx_loop_player.play()
	set_process(true)


func stop_sfx_loop(owner: Node = null) -> void:
	if owner != null and _sfx_loop_owner != owner:
		return
	_sfx_loop_player.stop()
	_sfx_loop_player.stream = null
	_sfx_loop_owner = null
	_sfx_loop_source = null
	set_process(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(_sfx_loop_owner) or not _sfx_loop_owner.can_process():
		stop_sfx_loop()
	elif _sfx_loop_owner is CanvasItem and not _sfx_loop_owner.is_visible_in_tree():
		stop_sfx_loop()


func stop_sfx() -> void:
	for player in _sfx_players:
		player.stop()
		player.stream = null
	stop_sfx_loop()


func _fade_music(target: int, gain: float) -> void:
	if crossfade_seconds <= 0.0:
		for index in _music_players.size():
			_music_players[index].volume_linear = gain if index == target else 0.0
		_finish_music_fade()
		return
	_music_tween = create_tween().set_parallel(true)
	for index in _music_players.size():
		_music_tween.tween_property(_music_players[index], "volume_linear", gain if index == target else 0.0, crossfade_seconds)
	_music_tween.chain().tween_callback(_finish_music_fade)


func _finish_music_fade() -> void:
	for index in _music_players.size():
		if _music_players[index].volume_linear <= 0.0:
			_music_players[index].stop()
			_music_players[index].stream = null
			_music_sources[index] = null


func _prepare_music_stream(stream: AudioStream, loop: bool) -> AudioStream:
	var prepared := stream.duplicate() as AudioStream
	if prepared is AudioStreamMP3 or prepared is AudioStreamOggVorbis:
		prepared.set("loop", loop)
	elif prepared is AudioStreamWAV:
		# Keep authored WAV loop points; unlooped streams restart on finished.
		if not loop:
			prepared.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return prepared


func _on_music_finished(player: AudioStreamPlayer) -> void:
	var index := _music_players.find(player)
	if index == _active_music and _requested_music != null:
		if _requested_loop:
			player.play()
		else:
			_requested_music = null


func _apply_volumes() -> void:
	_set_bus_volume(&"Music", GameSettings.music_volume, music_gain_db)
	_set_bus_volume(&"SFX", GameSettings.sfx_volume, sfx_gain_db)
	if GameSettings.sfx_volume <= 0.0:
		stop_sfx_loop()


func _set_bus_volume(bus: StringName, value: float, gain_db: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, gain_db + linear_to_db(maxf(value, 0.0001)))
