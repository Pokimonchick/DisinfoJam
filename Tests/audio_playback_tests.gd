extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	var settings: Node = root.get_node("GameSettings")
	var saved_volume: float = settings.sfx_volume
	var master_muted := AudioServer.is_bus_mute(0)
	settings.sfx_volume = 1.0 # Direct field assignment never writes settings.cfg.
	AudioServer.set_bus_mute(0, true)
	audio.stop_sfx()
	var container := Control.new()
	root.add_child(container)
	var button := Button.new()
	var physical := Button.new()
	container.add_child(button)
	container.add_child(physical)
	var excluded: Array[BaseButton] = [physical]
	audio.bind_ui_buttons(container, excluded)
	audio.bind_ui_buttons(container, excluded)
	button.pressed.emit()
	var voices: Array = audio._sfx_players
	var occupied := 0
	for voice in voices:
		if voice.stream != null:
			occupied += 1
	check(occupied == 1, "Repeated UI binding still emits only one click")
	audio.stop_sfx()
	physical.pressed.emit()
	check(voices.all(func(voice): return voice.stream == null), "Physical controls are excluded from generic clicks")
	audio._warning_at_ms = -1000
	audio.play_cue(audio.Cue.WARNING)
	var cursor: int = audio._sfx_cursor
	audio.play_cue(audio.Cue.WARNING)
	check(audio._sfx_cursor == cursor, "Rejected actions cannot stack rapid warnings")

	var pencil: AudioStreamWAV = load("res://Assets/Sounds/Карандаш.wav")
	var eraser: AudioStreamWAV = load("res://Assets/Sounds/Ластик.wav")
	var original_loop := pencil.loop_mode
	var loop_player: AudioStreamPlayer = audio._sfx_loop_player
	var player_count := audio.get_node("SFX").get_child_count()
	audio.start_sfx_loop(button, pencil, 14.0)
	var prepared: AudioStreamWAV = loop_player.stream
	check(loop_player.playing and loop_player.bus == &"SFX" and prepared.loop_mode == AudioStreamWAV.LOOP_FORWARD and prepared.loop_end > 0, "Friction uses a real native SFX loop")
	check(prepared != pencil and pencil.loop_mode == original_loop, "Loop setup never changes the imported source")
	await create_timer(pencil.get_length() + 0.1).timeout
	check(loop_player.playing, "Friction continues past the sample's first complete cycle")
	for index in 20:
		audio.start_sfx_loop(button, pencil, 14.0)
		audio.play_sfx(audio.CUE_STREAMS[audio.Cue.UI_CLICK])
	check(loop_player.playing and loop_player.stream == prepared and audio.get_node("SFX").get_child_count() == player_count, "Motion and a saturated one-shot pool cannot allocate or steal the friction voice")
	audio.stop_sfx_loop(physical)
	check(loop_player.playing, "An inactive tool cannot stop another tool's loop")
	audio.stop_sfx_loop(button)
	check(not loop_player.playing and loop_player.stream == null, "The owner can release its loop immediately")
	audio.start_sfx_loop(button, pencil, 14.0)
	check(loop_player.stream == prepared, "Resuming contact reuses the prepared stream")
	button.process_mode = Node.PROCESS_MODE_DISABLED
	audio._process(0.01)
	check(not loop_player.playing, "Disabling the owner stops friction even while AudioManager processes always")
	button.process_mode = Node.PROCESS_MODE_INHERIT
	audio.start_sfx_loop(button, pencil, 14.0)
	button.hide()
	audio._process(0.01)
	check(not loop_player.playing, "Hiding a loop owner stops friction")
	button.show()
	audio.start_sfx_loop(button, eraser, 14.0)
	check(audio._sfx_loop_source == eraser and audio._loop_streams.size() == 2, "Changing tools selects a separate cached loop")
	settings.sfx_volume = 0.0
	audio._apply_volumes()
	check(not loop_player.playing and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "Muting SFX stops continuous playback")
	audio.start_sfx_loop(button, pencil)
	check(not loop_player.playing, "Muted effects cannot start another loop")
	settings.sfx_volume = 1.0
	audio._apply_volumes()
	audio.start_sfx_loop(button, pencil)
	button.free()
	audio._process(0.01)
	check(not loop_player.playing, "Removing a loop owner cannot leave a dangling sound")
	container.free()
	audio.stop_sfx()
	settings.sfx_volume = saved_volume
	audio._apply_volumes()
	AudioServer.set_bus_mute(0, master_muted)
	# Let the mixer release stopped one-shots before the test tears down audio.
	await create_timer(0.1).timeout
	print("AUDIO PLAYBACK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
