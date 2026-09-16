class_name DeskProp
extends Control

signal activated

enum Kind { NOTE, FOLDER, COFFEE }

@export var kind: Kind = Kind.NOTE:
	set(value):
		kind = value
		queue_redraw()
@export var title := ""
@export_multiline var details := ""
@export var interactive := true

var _title_label: Label
var _details_label: Label
var _hover_tween: Tween
var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE
var _base_rotation := 0.0
var _is_hovered := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	pivot_offset = size / 2.0
	_base_position = position
	_base_scale = scale
	_base_rotation = rotation
	_create_labels()
	_apply_content()
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	gui_input.connect(_on_gui_input)
	resized.connect(func():
		pivot_offset = size / 2.0
		_layout_labels()
		queue_redraw()
	)

func set_content(next_title: String, next_details: String, next_tooltip: String) -> void:
	title = next_title
	details = next_details
	tooltip_text = next_tooltip
	_apply_content()

func _create_labels() -> void:
	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 18 if kind == Kind.NOTE else 16)
	_title_label.add_theme_color_override("font_color", Color("1e292c"))
	add_child(_title_label)
	_details_label = Label.new()
	_details_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_label.add_theme_font_size_override("font_size", 14)
	_details_label.add_theme_color_override("font_color", Color("4b4840"))
	add_child(_details_label)
	_layout_labels()

func _layout_labels() -> void:
	if _title_label == null:
		return
	var margin := 28.0 if kind == Kind.NOTE else 20.0
	_title_label.position = Vector2(margin, margin + 26.0)
	_title_label.size = Vector2(size.x - margin * 2.0, size.y * 0.38)
	_details_label.position = Vector2(margin, size.y * 0.48)
	_details_label.size = Vector2(size.x - margin * 2.0, size.y * 0.34)

func _apply_content() -> void:
	if _title_label == null:
		return
	_title_label.text = title
	_details_label.text = details
	queue_redraw()

func _set_hovered(value: bool) -> void:
	if not interactive or _is_hovered == value:
		return
	_is_hovered = value
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if value:
		z_index = 8
		_hover_tween.parallel().tween_property(self, "position", _base_position + Vector2(0.0, -12.0), 0.13)
		_hover_tween.parallel().tween_property(self, "scale", _base_scale * 1.035, 0.13)
	else:
		_hover_tween.parallel().tween_property(self, "position", _base_position, 0.16)
		_hover_tween.parallel().tween_property(self, "scale", _base_scale, 0.16)
		_hover_tween.tween_callback(func(): z_index = 0)
	queue_redraw()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activated.emit()
		accept_event()

func _draw() -> void:
	match kind:
		Kind.NOTE:
			_draw_note()
		Kind.FOLDER:
			_draw_folder()
		Kind.COFFEE:
			_draw_coffee()

func _draw_note() -> void:
	draw_set_transform(Vector2(7.0, 9.0), 0.0)
	draw_rect(Rect2(Vector2.ZERO, size - Vector2(14.0, 16.0)), Color("201817", 0.42), true)
	draw_set_transform(Vector2.ZERO, 0.0)
	draw_rect(Rect2(4.0, 4.0, size.x - 8.0, size.y - 8.0), Color("f2e7c8"), true)
	draw_rect(Rect2(4.0, 4.0, size.x - 8.0, 38.0), Color("e0cb9d"), true)
	for y in [size.y * 0.69, size.y * 0.79, size.y * 0.89]:
		draw_line(Vector2(28.0, y), Vector2(size.x - 28.0, y), Color("a9a083", 0.48), 1.0)
	if _is_hovered:
		draw_rect(Rect2(1.5, 1.5, size.x - 3.0, size.y - 3.0), Color("e8bd68"), false, 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(28.0, size.y - 20.0), "НАЖАТЬ, ЧТОБЫ ПРОЧИТАТЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("7e603d"))

func _draw_folder() -> void:
	draw_rect(Rect2(8.0, 16.0, size.x - 16.0, size.y - 25.0), Color("1e1919", 0.42), true)
	draw_rect(Rect2(3.0, 11.0, size.x - 11.0, size.y - 22.0), Color("b2774f"), true)
	draw_rect(Rect2(16.0, 1.0, size.x * 0.43, 35.0), Color("c8895c"), true)
	draw_rect(Rect2(3.0, 42.0, size.x - 11.0, 2.0), Color("71462f"), true)
	if _is_hovered:
		draw_rect(Rect2(1.5, 1.5, size.x - 4.0, size.y - 4.0), Color("e8bd68"), false, 4.0)

func _draw_coffee() -> void:
	var center := size / 2.0
	_draw_shadow_ellipse(center + Vector2(8.0, 12.0), Vector2(size.x * 0.31, size.y * 0.15), Color("1b1513", 0.42))
	draw_circle(center, minf(size.x, size.y) * 0.29, Color("d8d0bd"))
	draw_circle(center, minf(size.x, size.y) * 0.22, Color("55351f"))
	draw_arc(center + Vector2(size.x * 0.26, 0.0), minf(size.x, size.y) * 0.17, -PI * 0.65, PI * 0.65, 20, Color("d8d0bd"), 9.0)
	if _is_hovered:
		draw_arc(center, minf(size.x, size.y) * 0.37, 0.0, TAU, 24, Color("e8bd68"), 3.0)

func _draw_shadow_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 25:
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
