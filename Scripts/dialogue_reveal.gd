class_name DialogueReveal
extends RichTextLabel

enum Speaker { SILENT, HEROINE, BOSS }

@export_range(0.0, 120.0, 1.0) var characters_per_second: float = 38.0
@export_range(0.0, 1.0, 0.01) var punctuation_pause_seconds: float = 0.12
@export_range(0.0, 1.0, 0.01) var start_delay_seconds: float = 0.25
@export var heroine_voice: AudioStream = preload("res://Assets/Sounds/dialogue_heroine.wav")
@export var boss_voice: AudioStream = preload("res://Assets/Sounds/dialogue_boss.wav")
@export_range(-40.0, 6.0, 0.5) var voice_volume_db: float = -5.0
@export_range(0.0, 0.25, 0.01) var pitch_variation: float = 0.04

var _speaker: Speaker = Speaker.HEROINE
var _plain_text: String = ""
var _total_characters: int = 0
var _revealing: bool = false
var _reveal_paused: bool = false
var _time_until_character: float = 0.0
var _voice_random := RandomNumberGenerator.new()


func _ready() -> void:
	_voice_random.randomize()
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	visibility_changed.connect(_on_visibility_changed)
	_sync_processing()


func reveal(body: String, speaker: Speaker = Speaker.HEROINE) -> void:
	stop_reveal()
	_speaker = speaker
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	text = body
	_plain_text = get_parsed_text()
	_total_characters = get_total_character_count()
	_revealing = characters_per_second > 0.0 and _total_characters > 0
	visible_characters = 0 if _revealing else -1
	_time_until_character = start_delay_seconds + 1.0 / characters_per_second if _revealing else 0.0
	scroll_to_line(0)
	_sync_processing()


func finish_reveal() -> bool:
	if not _revealing:
		return false
	visible_characters = -1
	stop_reveal()
	return true


func stop_reveal() -> void:
	_revealing = false
	_time_until_character = 0.0
	set_process(false)


func set_reveal_paused(value: bool) -> void:
	_reveal_paused = value
	_sync_processing()


func is_revealing() -> bool:
	return _revealing


func _process(delta: float) -> void:
	if not _revealing or _reveal_paused:
		return
	if not is_visible_in_tree():
		stop_reveal()
		return
	if characters_per_second <= 0.0:
		finish_reveal()
		return
	_time_until_character -= delta
	var play_blip: bool = false
	while _time_until_character <= 0.0 and visible_characters < _total_characters:
		var character: String = _plain_text.substr(visible_characters, 1)
		visible_characters += 1
		_time_until_character += 1.0 / characters_per_second
		if _is_voiced_character(character):
			play_blip = true
		elif character in [".", ",", "!", "?", ":", ";", "…", "\n"]:
			_time_until_character += punctuation_pause_seconds
	# A slow frame can advance several glyphs, but never starts a burst of voices.
	if play_blip:
		var voice: AudioStream = null
		if _speaker == Speaker.HEROINE:
			voice = heroine_voice
		elif _speaker == Speaker.BOSS:
			voice = boss_voice
		if voice != null:
			AudioManager.play_sfx(voice, voice_volume_db, 1.0 + _voice_random.randf_range(-pitch_variation, pitch_variation))
	if visible_characters >= _total_characters:
		visible_characters = -1
		stop_reveal()


func _is_voiced_character(character: String) -> bool:
	if character.is_empty():
		return false
	var codepoint: int = character.unicode_at(0)
	return (
		(codepoint >= 48 and codepoint <= 57)
		or (codepoint >= 65 and codepoint <= 90)
		or (codepoint >= 97 and codepoint <= 122)
		or (codepoint >= 0x0400 and codepoint <= 0x052F)
	)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		stop_reveal()
	else:
		_sync_processing()


func _sync_processing() -> void:
	set_process(_revealing and not _reveal_paused and is_visible_in_tree())
