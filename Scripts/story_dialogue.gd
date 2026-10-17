extends Control

signal advance_requested
signal pause_requested

const PAPER = preload("res://Assets/Assets for new version of game/tamagochi/Тамагочи/dialogue/dialogue background.png")
var _at_home := false
var _black: ColorRect

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	%NarrativeBody.mouse_filter = Control.MOUSE_FILTER_PASS
	%NarrativeBody.add_theme_font_override("normal_font", preload("res://Scripts/game_fonts.gd").BOLD)
	%NarrativeTag.add_theme_font_override("font", preload("res://Scripts/game_fonts.gd").BOLD)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	move_child(_black, 0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for button in [%NarrativePrimary, %NarrativeBack, %NarrativeSecondary]:
		button.hide()
		button.focus_mode = Control.FOCUS_NONE
	resized.connect(_fit)
	_fit()
	$Canvas/Pause.pressed.connect(func(): pause_requested.emit())
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			%NarrativeBody.stop_reveal()
	)
	set_home_style(false)

func set_home_style(value: bool) -> void:
	_at_home = value
	_black.visible = not value
	%NarrativeVisual.visible = value
	$Canvas/Pause.visible = value
	%NarrativeTag.visible = value
	$Canvas/Paper/Arrow.visible = value
	var paper: TextureRect = $Canvas/Paper
	paper.texture = PAPER if value else null
	paper.position = Vector2(160, 800) if value else Vector2.ZERO
	paper.size = Vector2(1600, 260) if value else Vector2(1920, 1080)
	%NarrativeBody.bbcode_enabled = not value
	%NarrativeBody.scroll_active = value
	%NarrativeBody.add_theme_font_size_override("normal_font_size", 32 if value else 52)
	%NarrativeBody.add_theme_color_override("default_color", Color("45213d") if value else Color.WHITE)
	if value:
		%NarrativeBody.position = Vector2(34, 70)
		%NarrativeBody.size = Vector2(1518, 138)
	else:
		%NarrativeBody.position = Vector2(250, 270)
		%NarrativeBody.size = Vector2(1420, 540)

func format_body(body: String) -> String:
	return body if _at_home else "[center]%s[/center]" % body.replace("[", "[lb]")

func update_text_layout() -> void:
	if not _at_home:
		_center_text.call_deferred()

func _center_text() -> void:
	if _at_home:
		return
	var height := minf(620.0, %NarrativeBody.get_content_height() + 8.0)
	%NarrativeBody.size = Vector2(1420, height)
	%NarrativeBody.position = Vector2(250, (1080.0 - height) * 0.5)

func focus_continue() -> void:
	grab_focus()

func _fit() -> void:
	var factor := minf(size.x / 1920.0, size.y / 1080.0)
	$Canvas.scale = Vector2.ONE * factor
	$Canvas.position = (size - Vector2(1920, 1080) * factor) * 0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		advance_requested.emit()
		accept_event()
