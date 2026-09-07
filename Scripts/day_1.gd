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

@onready var DialogueText = $Interface/DialogueText
@onready var read_more_button = $Interface/ReadChoiceUI/ReadMoreButton
@onready var publish_button = $Interface/ReadChoiceUI/PublishButton
@onready var read_choice_ui = $Interface/ReadChoiceUI

var phase: Phase = Phase.SUMMARY
var dialogue_index: int = 0
var current_lines: Array[String] = []

func _ready() -> void:
	current_lines = DAY1_DATA.SUMMARY_LINES
	read_choice_ui.hide()
	show_line()

	read_more_button.pressed.connect(_on_read_more_pressed)
	publish_button.pressed.connect(_on_publish_pressed)

func show_line() -> void:
	DialogueText.text = current_lines[dialogue_index]

func _on_read_more_pressed() -> void:
	phase = Phase.EXTRA_READING
	dialogue_index = 0
	current_lines = DAY1_DATA.EXTRA_LINES
	read_choice_ui.hide()
	show_line()

func _on_publish_pressed() -> void:
	phase = Phase.PUBLISH_CHOICE
	read_choice_ui.hide()
	print("Переходим к публикации")

func _input(event: InputEvent) -> void:
	if phase == Phase.SUMMARY or phase == Phase.EXTRA_READING:
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
						phase = Phase.PUBLISH_CHOICE
						print("Переходим к публикации")
