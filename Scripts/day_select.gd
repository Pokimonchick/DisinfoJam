extends Control


const GREEN_DAY_TEXTURE = preload("res://Assets/UI/Untitled (13)/Rectangle 1867.png")
const GRAY_DAY_TEXTURE = preload("res://Assets/UI/Untitled (13)/Rectangle 1868.png")

@onready var day_1_button: TextureButton = $RightArea/Days/Day1Button
@onready var day_2_button: TextureButton = $RightArea/Days/Day2Button
@onready var continue_button: TextureButton = $RightArea/ContinueButton
@onready var back_button: TextureButton = $RightArea/TopButtons/BackButton
@onready var score_value: Label = $LeftPanel/ScoreBackground/ScoreValue
@onready var day_1_completed_marker: Control = $RightArea/Days/Day1Button/CompletedMarker
@onready var day_2_completed_marker: Control = $RightArea/Days/Day2Button/CompletedMarker
var selected_day: int = 1

func _ready() -> void:
	day_1_button.pressed.connect(_on_day_1_pressed)
	day_2_button.pressed.connect(_on_day_2_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)

	day_1_button.button_pressed = true
	update_day_visuals()
	
	day_2_button.disabled = !GameState.day_1_completed
	score_value.text = str(GameState.society_points)
	day_1_completed_marker.visible = GameState.day_1_completed
	day_2_completed_marker.visible = GameState.day_2_completed

	day_2_button.disabled = not GameState.day_1_completed

	continue_button.disabled = false
	continue_button.grab_focus()


func _on_day_1_pressed() -> void:
	selected_day = 1

	day_1_button.button_pressed = true
	day_2_button.button_pressed = false

	update_day_visuals()

	continue_button.disabled = false
	continue_button.grab_focus()


func _on_day_2_pressed() -> void:
	if not GameState.day_1_completed:
		return

	selected_day = 2

	day_1_button.button_pressed = false
	day_2_button.button_pressed = true

	update_day_visuals()

	continue_button.disabled = false
	continue_button.grab_focus()


func _on_continue_pressed() -> void:
	if selected_day == 1:
		get_tree().change_scene_to_file("res://Scenes/day_1.tscn")

	elif selected_day == 2 && GameState.day_1_completed:
		get_tree().change_scene_to_file("res://Scenes/day_2.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func set_day_texture(button: TextureButton, texture: Texture2D) -> void:
	button.texture_normal = texture
	button.texture_pressed = texture
	button.texture_hover = texture
	button.texture_focused = texture


func update_day_visuals() -> void:
	if selected_day == 1 or GameState.day_1_completed:
		set_day_texture(day_1_button, GREEN_DAY_TEXTURE)
	else:
		set_day_texture(day_1_button, GRAY_DAY_TEXTURE)

	if selected_day == 2 or GameState.day_2_completed:
		set_day_texture(day_2_button, GREEN_DAY_TEXTURE)
	else:
		set_day_texture(day_2_button, GRAY_DAY_TEXTURE)

	day_1_completed_marker.visible = GameState.day_1_completed
	day_2_completed_marker.visible = GameState.day_2_completed
