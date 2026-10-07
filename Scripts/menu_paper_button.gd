@tool
extends Button

@export var paper_color := Color("f4e6bf")
@export var hover_color := Color("edc96c")
@export var ink_color := Color("35291f")
@export var backing_color := Color("8e3b2d")

var _emphasis := 0.0
var _hover_tween: Tween

func _ready() -> void:
	# Native Button keeps input, disabled states and keyboard navigation.
	# Only its drawing is replaced with a cut-paper silhouette.
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	mouse_entered.connect(func(): _animate_hover(1.0))
	mouse_exited.connect(func(): _animate_hover(0.0))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _animate_hover(value: float) -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_method(_set_emphasis, _emphasis, value if not disabled else 0.0, 0.15)

func _set_emphasis(value: float) -> void:
	_emphasis = value
	queue_redraw()

func _shape() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(10, 8), Vector2(size.x - 52, 0),
		Vector2(size.x, size.y * 0.46), Vector2(size.x - 54, size.y - 10),
		Vector2(0, size.y)])

func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _shape())

func _draw() -> void:
	var shape := _shape()
	var emphasis := _emphasis if not disabled else 0.0
	var shift := Vector2(10, -3) * emphasis
	var fill := paper_color.lerp(hover_color, emphasis)
	var text_color := ink_color
	if disabled:
		fill = Color("9baca3")
		text_color = Color("46574e")
	draw_set_transform(Vector2(-8, 14))
	draw_colored_polygon(shape, Color(0.03, 0.04, 0.035, 0.4))
	draw_set_transform(Vector2(-7, 9) + shift)
	draw_colored_polygon(shape, backing_color if not disabled else Color("536459"))
	draw_set_transform(shift + (Vector2(0, 3) if is_pressed() else Vector2.ZERO))
	draw_colored_polygon(shape, fill)
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, ink_color, 2.0, true)
	draw_line(Vector2(35, size.y - 22), Vector2(size.x - 68, size.y - 31), Color(ink_color, 0.16), 2.0, true)
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var available := size.x - 116.0
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if text_width > available:
		font_size = maxi(16, floori(font_size * available / text_width))
	var baseline := (size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size) - 4.0
	draw_string(font, Vector2(38, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, available, font_size, text_color)
	if has_focus() and not disabled:
		draw_line(Vector2(34, size.y - 17), Vector2(size.x - 64, size.y - 26), backing_color, 5.0, true)
	draw_set_transform(Vector2.ZERO)
