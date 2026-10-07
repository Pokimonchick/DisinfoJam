class_name SettingsPanel
extends Control

signal closed


func _ready() -> void:
	%Tooltips.toggled.connect(GameSettings.set_tooltips_enabled)
	%ChoiceOverlay.toggled.connect(GameSettings.set_choice_overlay_enabled)
	%MusicVolume.value_changed.connect(_on_music_volume_changed)
	%SfxVolume.value_changed.connect(_on_sfx_volume_changed)
	%Close.pressed.connect(close)


func present() -> void:
	%Tooltips.set_pressed_no_signal(GameSettings.tooltips_enabled)
	%ChoiceOverlay.set_pressed_no_signal(GameSettings.choice_overlay_enabled)
	%MusicVolume.set_value_no_signal(GameSettings.music_volume * 100.0)
	%SfxVolume.set_value_no_signal(GameSettings.sfx_volume * 100.0)
	%MusicPercent.text = "%d%%" % roundi(GameSettings.music_volume * 100.0)
	%SfxPercent.text = "%d%%" % roundi(GameSettings.sfx_volume * 100.0)
	show()
	%Tooltips.grab_focus()


func close() -> void:
	GameSettings.flush_audio_settings()
	hide()
	closed.emit()


func _on_music_volume_changed(value: float) -> void:
	%MusicPercent.text = "%d%%" % roundi(value)
	GameSettings.set_music_volume(value / 100.0)


func _on_sfx_volume_changed(value: float) -> void:
	%SfxPercent.text = "%d%%" % roundi(value)
	GameSettings.set_sfx_volume(value / 100.0)
