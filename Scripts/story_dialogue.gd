extends "res://Scripts/editorial_card.gd"
## Original story/endings card restored from c885dde; tutorial has its own UI.

signal advance_requested
signal pause_requested

func _ready() -> void:
	super._ready()
	focus_mode = Control.FOCUS_ALL
	%NarrativeBody.mouse_filter = Control.MOUSE_FILTER_PASS
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			%NarrativeBody.stop_reveal()
	)

func format_body(body: String) -> String:
	return body

func update_text_layout() -> void:
	%NarrativeBody.scroll_to_line(0)

func focus_continue() -> void:
	%NarrativePrimary.grab_focus()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		advance_requested.emit()
		accept_event()
