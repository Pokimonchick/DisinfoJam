extends Node2D

const STROKE_WIDTH := 5.0
const DRAW_TIME := 0.38

var _stroke: Line2D
var _draw_tween: Tween
var _path := PackedVector2Array()
var _progress := 0.0:
	set(value):
		_progress = value
		_update_stroke()

func _ready() -> void:
	_stroke = Line2D.new()
	_stroke.width = STROKE_WIDTH
	_stroke.texture = _make_pencil_texture()
	_stroke.texture_mode = Line2D.LINE_TEXTURE_TILE
	_stroke.joint_mode = Line2D.LINE_JOINT_ROUND
	_stroke.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_stroke.end_cap_mode = Line2D.LINE_CAP_ROUND
	_stroke.antialiased = true
	add_child(_stroke)

func trace(headline: Label) -> void:
	clear()
	if headline.text.is_empty():
		return
	var font := headline.get_theme_font("font")
	var font_size := headline.get_theme_font_size("font_size")
	var line_height := font.get_height(font_size) + headline.get_theme_constant("line_spacing")
	var text_height := minf(headline.size.y, headline.get_line_count() * line_height)
	var top_left := to_local(headline.global_position)
	var box := Rect2(top_left - Vector2(7.0, 7.0), Vector2(headline.size.x + 14.0, text_height + 14.0))
	_path = _outline_path(box)
	_progress = 0.0
	_draw_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_draw_tween.tween_property(self, "_progress", 1.0, DRAW_TIME)

func clear() -> void:
	if _draw_tween and _draw_tween.is_valid():
		_draw_tween.kill()
	_path.clear()
	_progress = 0.0
	if _stroke:
		_stroke.clear_points()

func _outline_path(box: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius := 12.0
	var left := box.position.x
	var right := box.end.x
	var top := box.position.y
	var bottom := box.end.y
	# Begin below the text, like a pencil underline, then circle the block.
	points.append(Vector2(left + radius, bottom))
	points.append(Vector2(right - radius, bottom + 0.5))
	points.append(Vector2(right - 3.0, bottom - 3.0))
	points.append(Vector2(right, bottom - radius))
	points.append(Vector2(right + 0.4, top + radius))
	points.append(Vector2(right - 3.0, top + 3.0))
	points.append(Vector2(right - radius, top))
	points.append(Vector2(left + radius, top - 0.5))
	points.append(Vector2(left + 3.0, top + 3.0))
	points.append(Vector2(left, top + radius))
	points.append(Vector2(left - 0.4, bottom - radius))
	points.append(Vector2(left + 3.0, bottom - 3.0))
	points.append(Vector2(left + radius + 3.0, bottom + 0.7))
	return points

func _update_stroke() -> void:
	if not _stroke or _path.size() < 2:
		return
	var total_length := 0.0
	for index in range(1, _path.size()):
		total_length += _path[index - 1].distance_to(_path[index])
	var remaining := total_length * _progress
	var visible_points := PackedVector2Array([_path[0]])
	for index in range(1, _path.size()):
		var segment := _path[index - 1].distance_to(_path[index])
		if remaining < segment:
			visible_points.append(_path[index - 1].lerp(_path[index], remaining / segment))
			break
		visible_points.append(_path[index])
		remaining -= segment
	_stroke.points = visible_points

func _make_pencil_texture() -> ImageTexture:
	var image := Image.create(32, 8, false, Image.FORMAT_RGBA8)
	for y in 8:		for x in 32:
			var grain := (x * 37 + y * 71 + x * y * 11) % 31
			var edge := 0.55 if y == 0 or y == 7 else 1.0
			var alpha := int((172 + grain * 2) * edge)
			if grain < 3:
				alpha /= 3
			image.set_pixel(x, y, Color8(166 + grain / 3, 35 + grain / 4, 38 + grain / 5, alpha))
	return ImageTexture.create_from_image(image)
