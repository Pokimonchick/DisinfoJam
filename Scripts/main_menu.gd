extends Control

func _ready() -> void:
	$StartButton.pressed.connect(_on_start_pressed)
	$StartButton.grab_focus()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/day_select.tscn")
