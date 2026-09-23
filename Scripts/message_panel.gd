class_name MessagePanel
extends Control

signal primary_pressed
signal secondary_pressed

@onready var tag_label: Label = %Tag
@onready var title_label: Label = %Title
@onready var body_label: RichTextLabel = %Body
@onready var primary_button: Button = %Primary
@onready var secondary_button: Button = %Secondary

func _ready() -> void:
	primary_button.pressed.connect(func(): primary_pressed.emit())
	secondary_button.pressed.connect(func(): secondary_pressed.emit())

func present(tag: String, title: String, body: String, primary: String, secondary: String = "") -> void:
	tag_label.text = tag
	title_label.text = title
	body_label.text = body
	body_label.visible = not body.is_empty()
	if body_label.visible:
		body_label.scroll_to_line(0)
	primary_button.text = primary
	secondary_button.text = secondary
	secondary_button.visible = not secondary.is_empty()
	show()
	primary_button.grab_focus()
