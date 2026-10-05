extends Node

signal changed
signal audio_changed

const SETTINGS_PATH := "user://settings.cfg"

var tooltips_enabled := true
var choice_overlay_enabled := false
var music_volume := 1.0
var sfx_volume := 1.0
var _audio_dirty := false
var _audio_save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audio_save_timer = Timer.new()
	_audio_save_timer.one_shot = true
	_audio_save_timer.wait_time = 0.25
	_audio_save_timer.timeout.connect(flush_audio_settings)
	add_child(_audio_save_timer)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var saved_value: Variant = config.get_value("interface", "tooltips", true)
	if saved_value is bool:
		tooltips_enabled = saved_value
	var saved_overlay: Variant = config.get_value("interface", "choice_overlay", false)
	if saved_overlay is bool:
		choice_overlay_enabled = saved_overlay
	music_volume = _read_volume(config, "music_volume")
	sfx_volume = _read_volume(config, "sfx_volume")


func _exit_tree() -> void:
	flush_audio_settings()


func _read_volume(config: ConfigFile, key: String) -> float:
	var value: Variant = config.get_value("audio", key, 1.0)
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), 0.0, 1.0)
	return 1.0


func set_music_volume(value: float) -> void:
	if not is_finite(value):
		return
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(music_volume, value):
		return
	music_volume = value
	_queue_audio_save()


func set_sfx_volume(value: float) -> void:
	if not is_finite(value):
		return
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(sfx_volume, value):
		return
	sfx_volume = value
	_queue_audio_save()


func _queue_audio_save() -> void:
	_audio_dirty = true
	_audio_save_timer.start()
	audio_changed.emit()


func flush_audio_settings() -> void:
	if not _audio_dirty:
		return
	if is_instance_valid(_audio_save_timer):
		_audio_save_timer.stop()
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	if config.save(SETTINGS_PATH) == OK:
		_audio_dirty = false
	else:
		push_warning("Не удалось сохранить настройки звука.")


func set_tooltips_enabled(value: bool) -> void:
	if tooltips_enabled == value:
		return
	tooltips_enabled = value
	_save_interface_setting("tooltips", value)
	changed.emit()


func set_choice_overlay_enabled(value: bool) -> void:
	if choice_overlay_enabled == value:
		return
	choice_overlay_enabled = value
	_save_interface_setting("choice_overlay", value)
	changed.emit()


func _save_interface_setting(key: String, value: bool) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("interface", key, value)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Не удалось сохранить настройки интерфейса.")
