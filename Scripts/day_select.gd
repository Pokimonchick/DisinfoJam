extends Control


@onready var day_1_button: TextureButton = $RightArea/Days/Day1Button
@onready var continue_button: TextureButton = $RightArea/ContinueButton
@onready var next_button: TextureButton = $RightArea/NextButton
@onready var back_button: TextureButton = $RightArea/TopButtons/BackButton


func _ready() -> void:
	day_1_button.pressed.connect(_on_day_1_pressed)
	continue_button.pressed.connect(_open_day_1)
	next_button.pressed.connect(_open_day_1)
	back_button.pressed.connect(_on_back_pressed)

	day_1_button.button_pressed = true
	continue_button.grab_focus()


func _on_day_1_pressed() -> void:
	day_1_button.button_pressed = true
	continue_button.grab_focus()


func _open_day_1() -> void:
	get_tree().change_scene_to_file("res://Scenes/day_1.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
