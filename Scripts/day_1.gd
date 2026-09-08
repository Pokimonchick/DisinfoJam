extends Control


enum Phase {
	SUMMARY,
	READ_CHOICE,
	EXTRA_READING,
	PUBLISH_CHOICE,
	HERO_MONOLOGUE,
	RESULT
}


const DAY1_DATA = preload("res://Data/day1_data.gd")

@onready var background = $Background

@export var normal_background: Texture2D
@export var publish_background: Texture2D

@onready var dialogue_background = $Interface/DialogueBackground
@onready var dialogue_text = $Interface/DialogueText
@onready var speaker_ui = $Interface/SpeakerUI
@onready var read_more_button = $Interface/ReadChoiceUI/ReadMoreButton
@onready var publish_button = $Interface/ReadChoiceUI/PublishButton
@onready var read_choice_ui = $Interface/ReadChoiceUI
@onready var dim_overlay = $Interface/DimOverlay
@onready var publish_choice_ui = $Interface/PublishChoiceUI
@onready var approve_button = $Interface/PublishChoiceUI/ApproveButton
@onready var disapprove_button = $Interface/PublishChoiceUI/DisapproveButton
@onready var hero_ui = $Interface/HeroUI
@onready var hero_dialogue_text = $Interface/HeroUI/HeroDialogueText
@onready var result_ui = $Interface/ResultUI
@onready var result_explanation = $Interface/ResultUI/Explanation
@onready var result_score = $Interface/ResultUI/ScoreBackground/Score
@onready var result_continue_button = $Interface/ResultUI/ContinueButton

var phase: Phase = Phase.SUMMARY
var dialogue_index: int = 0
var current_lines: Array[String] = []
var pending_score_change: int = 0

func _ready() -> void:
	background.texture = normal_background

	current_lines = DAY1_DATA.SUMMARY_LINES
	read_choice_ui.hide()
	dim_overlay.hide()
	publish_choice_ui.hide()
	hero_ui.hide()
	result_ui.hide()

	read_more_button.pressed.connect(_on_read_more_pressed)
	publish_button.pressed.connect(_on_publish_pressed)

	approve_button.pressed.connect(_on_approve_pressed)
	disapprove_button.pressed.connect(_on_disapprove_pressed)
	result_continue_button.pressed.connect(_on_result_continue_pressed)

	show_line()


func show_line() -> void:
	if phase == Phase.HERO_MONOLOGUE:
		hero_dialogue_text.text = current_lines[dialogue_index]
	else:
		dialogue_text.text = current_lines[dialogue_index]
		speaker_ui.visible = not (
			phase == Phase.EXTRA_READING
			and dialogue_index >= DAY1_DATA.EXTRA_NARRATION_START
		)


func _on_read_more_pressed() -> void:
	phase = Phase.EXTRA_READING
	dialogue_index = 0
	current_lines = DAY1_DATA.EXTRA_LINES

	read_choice_ui.hide()
	speaker_ui.show()

	show_line()


func enter_publish_choice() -> void:
	phase = Phase.PUBLISH_CHOICE
	dialogue_index = 0

	background.texture = publish_background

	read_choice_ui.hide()
	dialogue_background.hide()
	dialogue_text.hide()
	speaker_ui.hide()
	dim_overlay.show()
	publish_choice_ui.show()


func _on_publish_pressed() -> void:
	enter_publish_choice()


func start_hero_monologue(lines: Array[String]) -> void:
	phase = Phase.HERO_MONOLOGUE

	background.texture = normal_background

	dim_overlay.hide()
	publish_choice_ui.hide()
	dialogue_background.show()
	dialogue_text.hide()
	speaker_ui.hide()
	hero_ui.show()

	current_lines = lines
	dialogue_index = 0
	show_line()


func _on_approve_pressed() -> void:
	pending_score_change = DAY1_DATA.APPROVE_SCORE
	start_hero_monologue(DAY1_DATA.APPROVE_LINES)


func _on_disapprove_pressed() -> void:
	pending_score_change = DAY1_DATA.DISAPPROVE_SCORE
	start_hero_monologue(DAY1_DATA.DISAPPROVE_LINES)


func enter_result() -> void:
	phase = Phase.RESULT
	GameState.complete_day_1(pending_score_change)

	background.texture = publish_background
	dialogue_background.hide()
	hero_ui.hide()
	dialogue_text.hide()
	speaker_ui.hide()
	dim_overlay.show()
	publish_choice_ui.hide()

	var sign := ""
	if pending_score_change > 0:
		sign = "+"

	if pending_score_change == DAY1_DATA.APPROVE_SCORE:
		result_explanation.text = DAY1_DATA.APPROVE_RESULT
	else:
		result_explanation.text = DAY1_DATA.DISAPPROVE_RESULT

	result_score.text = sign + str(pending_score_change) + " очков общества"
	result_ui.show()
	result_continue_button.grab_focus()


func _on_result_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/day_select.tscn")


func _input(event: InputEvent) -> void:
	if phase == Phase.SUMMARY or phase == Phase.EXTRA_READING or phase == Phase.HERO_MONOLOGUE:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				dialogue_index += 1

				if dialogue_index < current_lines.size():
					show_line()
				else:
					if phase == Phase.SUMMARY:
						phase = Phase.READ_CHOICE
						read_choice_ui.show()

					elif phase == Phase.EXTRA_READING:
						enter_publish_choice()

					elif phase == Phase.HERO_MONOLOGUE:
						enter_result()
