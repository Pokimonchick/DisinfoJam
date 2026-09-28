extends Node

signal changed

const SETTINGS_PATH := "user://settings.cfg"

var tooltips_enabled := true


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var saved_value: Variant = config.get_value("interface", "tooltips", true)
	if saved_value is bool:
		tooltips_enabled = saved_value


func set_tooltips_enabled(value: bool) -> void:
	if tooltips_enabled == value:
		return
	tooltips_enabled = value
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("interface", "tooltips", value)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Не удалось сохранить настройки интерфейса.")
	changed.emit()
