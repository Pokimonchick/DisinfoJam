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


func _streams(audio: Node) -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	var players: Array = audio.get("_sfx_players")
	for player in players:
		if player.stream != null:
			result.append(player.stream)
	return result


func _step(dialogue, seconds: float) -> void:
	# Manual deltas keep timing assertions independent of the machine's frame rate.
	dialogue._process(seconds)


func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	var settings: Node = root.get_node("GameSettings")
	var saved_sfx_volume: float = settings.get("sfx_volume")
	var master_was_muted: bool = AudioServer.is_bus_mute(0)
	# Direct assignment avoids setters, save timers and settings.cfg writes.
	settings.set("sfx_volume", 1.0)
	AudioServer.set_bus_mute(0, true)
	audio.call("stop_sfx")
	# Load after autoloads exist: SceneTree --script compiles before their globals.
	var reveal_script = load("res://Scripts/dialogue_reveal.gd")
	var dialogue = reveal_script.new()
	dialogue.bbcode_enabled = true
	dialogue.size = Vector2(500, 200)
	dialogue.characters_per_second = 10.0
	dialogue.start_delay_seconds = 0.2
	dialogue.pitch_variation = 0.0
	root.add_child(dialogue)

	var body := "[b]Ёж[/b], привет!"
	dialogue.reveal(body)
	check(dialogue.text == body and dialogue.get_parsed_text() == "Ёж, привет!" and dialogue.visible_characters == 0 and dialogue.is_revealing(), "BBCode and Cyrillic are assigned intact before reveal begins")
	_step(dialogue, 0.15)
	check(dialogue.visible_characters == 0 and _streams(audio).is_empty(), "The initial delay keeps text and voice quiet")
	_step(dialogue, 0.16)
	check(dialogue.visible_characters == 1 and dialogue.visible_characters_behavior == TextServer.VC_CHARS_AFTER_SHAPING, "The first Unicode character appears with shaping preserved")
	check(_streams(audio).size() == 1 and _streams(audio)[0] == dialogue.heroine_voice, "Cyrillic Ё uses the heroine voice through the shared SFX pool")
	audio.call("stop_sfx")
	_step(dialogue, 0.1)
	check(dialogue.visible_characters == 2 and dialogue.text == body and dialogue.get_parsed_text() == "Ёж, привет!", "Gradual reveal leaves the full BBCode text unchanged")
	audio.call("stop_sfx")
	dialogue.set_reveal_paused(true)
	_step(dialogue, 5.0)
	check(dialogue.is_revealing() and dialogue.visible_characters == 2 and _streams(audio).is_empty() and not dialogue.is_processing(), "Pause preserves the visible count and prevents catch-up audio")
	dialogue.set_reveal_paused(false)
	_step(dialogue, 0.1)
	check(dialogue.visible_characters == 3 and dialogue.is_revealing() and dialogue.is_processing(), "Resume advances from the paused position without consuming paused time")
	audio.call("stop_sfx")
	check(dialogue.finish_reveal() and dialogue.visible_characters == -1 and not dialogue.is_revealing() and _streams(audio).is_empty(), "Finish reveals the complete body without generating voices")
	check(not dialogue.finish_reveal(), "Finish returns false once text is already complete")

	dialogue.characters_per_second = 0.0
	dialogue.reveal("[i]Мгновенно[/i]")
	check(dialogue.visible_characters == -1 and not dialogue.is_revealing() and _streams(audio).is_empty(), "Zero speed disables typing and audio")
	dialogue.characters_per_second = 10.0
	dialogue.start_delay_seconds = 0.0
	dialogue.reveal("")
	check(dialogue.visible_characters == -1 and not dialogue.is_revealing(), "An empty body completes immediately")
	dialogue.reveal("Скрытый текст")
	_step(dialogue, 0.101)
	var before_hide: int = dialogue.visible_characters
	dialogue.hide()
	audio.call("stop_sfx")
	_step(dialogue, 2.0)
	check(not dialogue.is_revealing() and dialogue.visible_characters == before_hide and _streams(audio).is_empty(), "Hiding cancels typing instead of continuing invisible dialogue")
	dialogue.show()
	dialogue.reveal("Остановить")
	_step(dialogue, 0.101)
	dialogue.stop_reveal()
	audio.call("stop_sfx")
	_step(dialogue, 2.0)
	check(dialogue.visible_characters == 1 and not dialogue.is_revealing() and _streams(audio).is_empty(), "Explicit stop keeps the partial text and prevents further voices")

	dialogue.reveal("Тихо", reveal_script.Speaker.SILENT)
	_step(dialogue, 0.101)
	check(dialogue.visible_characters == 1 and _streams(audio).is_empty(), "SILENT speakers reveal letters without voice audio")
	dialogue.reveal(" ,.!?…\n", reveal_script.Speaker.HEROINE)
	_step(dialogue, 3.0)
	check(not dialogue.is_revealing() and _streams(audio).is_empty(), "Spaces, punctuation and line breaks never start a voice")
	dialogue.punctuation_pause_seconds = 0.2
	dialogue.reveal("А,Б")
	_step(dialogue, 0.101)
	_step(dialogue, 0.1)
	audio.call("stop_sfx")
	_step(dialogue, 0.15)
	check(dialogue.visible_characters == 2 and dialogue.is_revealing() and _streams(audio).is_empty(), "A comma adds a pause longer than the normal character interval")

	dialogue.reveal("Босс", reveal_script.Speaker.BOSS)
	_step(dialogue, 0.101)
	check(_streams(audio).size() == 1 and _streams(audio)[0] == dialogue.boss_voice and dialogue.boss_voice != dialogue.heroine_voice, "The boss selects a distinct default stream through the same SFX pool")
	audio.call("stop_sfx")
	dialogue.reveal("Абвгдежзий", reveal_script.Speaker.HEROINE)
	_step(dialogue, 5.0)
	check(dialogue.visible_characters == -1 and not dialogue.is_revealing() and _streams(audio).size() == 1, "A long frame reveals all due letters but starts at most one voice")

	dialogue.free()
	audio.call("stop_sfx")
	settings.set("sfx_volume", saved_sfx_volume)
	AudioServer.set_bus_mute(0, master_was_muted)
	print("DIALOGUE REVEAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
