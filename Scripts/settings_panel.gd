class_name SettingsPanel
extends Control

signal closed


func _ready() -> void:
	%Tooltips.toggled.connect(GameSettings.set_tooltips_enabled)
	%Close.pressed.connect(close)


func present() -> void:
	%Tooltips.set_pressed_no_signal(GameSettings.tooltips_enabled)
	show()
	%Tooltips.grab_focus()


func close() -> void:
	hide()
	closed.emit()
