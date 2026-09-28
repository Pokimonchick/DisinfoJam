extends Node

signal changed

const SETTINGS_PATH := "user://settings.cfg"

var tooltips_enabled := true
var choice_overlay_enabled := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var saved_value: Variant = config.get_value("interface", "tooltips", true)
	if saved_value is bool:
		tooltips_enabled = saved_value
	var saved_overlay: Variant = config.get_value("interface", "choice_overlay", false)
	if saved_overlay is bool:
		choice_overlay_enabled = saved_overlay


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
