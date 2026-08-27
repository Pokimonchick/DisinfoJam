extends PanelContainer

signal selected

@onready var headline_label = $MarginContainer/VBoxContainer/Headline
@onready var body_label = $MarginContainer/VBoxContainer/Body

func setup(headline: String, body: String) -> void:
	headline_label.text = headline
	body_label.text = body

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit()
