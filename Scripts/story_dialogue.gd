extends Control

signal advance_requested
signal pause_requested

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	%NarrativeBody.mouse_filter = Control.MOUSE_FILTER_PASS
	%NarrativeBody.add_theme_font_override("normal_font", preload("res://Scripts/game_fonts.gd").BOLD)
	%NarrativeTag.add_theme_font_override("font", preload("res://Scripts/game_fonts.gd").BOLD)
	for state in ["normal", "hover", "pressed", "disabled"]:
		%NarrativePrimary.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(_fit)
	_fit()
	$Canvas/Pause.pressed.connect(func(): pause_requested.emit())
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			%NarrativeBody.stop_reveal()
	)

func _fit() -> void:
	var factor := minf(size.x / 1920.0, size.y / 1080.0)
	$Canvas.scale = Vector2.ONE * factor
	$Canvas.position = (size - Vector2(1920, 1080) * factor) * 0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance_requested.emit()
		accept_event()
