class_name SettingsPanel
extends Control

signal closed


func _ready() -> void:
	%Tooltips.toggled.connect(GameSettings.set_tooltips_enabled)
	%ChoiceOverlay.toggled.connect(GameSettings.set_choice_overlay_enabled)
	%Close.pressed.connect(close)


func present() -> void:
	%Tooltips.set_pressed_no_signal(GameSettings.tooltips_enabled)
	%ChoiceOverlay.set_pressed_no_signal(GameSettings.choice_overlay_enabled)
	show()
	%Tooltips.grab_focus()


func close() -> void:
	hide()
	closed.emit()
