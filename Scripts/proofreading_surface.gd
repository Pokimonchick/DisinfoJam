class_name ProofreadingSurface
extends Control

signal changed

@export var pencil_color := Color("953e3b", 0.87)
@export_range(1.0, 6.0, 0.2) var line_width := 2.4

var input_enabled := true:
	set(value):
		input_enabled = value
		if not value:
			cancel_stroke()
var drawing_enabled := false:
	set(value):
		drawing_enabled = value
		if not value:
			cancel_stroke()
var state: ProofreadingState
var label: RichTextLabel
var _lines: Array = []
var _words: Array = []
var _segments: Array = []
var _last_point := Vector2.ZERO
var _drawing := false
var _corrected: Dictionary = {}
var _core_corrected: Dictionary = {}
var _wrong_coverage: Dictionary = {}
var _geometry_dirty := false
var _point_count := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind(body: RichTextLabel, article_state: ProofreadingState) -> void:
	cancel_stroke()
	if is_instance_valid(label):
		if label.resized.is_connected(_invalidate_geometry):
			label.resized.disconnect(_invalidate_geometry)
		if label.theme_changed.is_connected(_invalidate_geometry):
			label.theme_changed.disconnect(_invalidate_geometry)
		if label.get_v_scroll_bar().value_changed.is_connected(_scroll_changed):
			label.get_v_scroll_bar().value_changed.disconnect(_scroll_changed)
	label = body
	state = article_state
	_lines.clear()
	_words.clear()
	if is_instance_valid(label) and state != null:
		label.text = state.display_text
		label.resized.connect(_invalidate_geometry)
		label.theme_changed.connect(_invalidate_geometry)
		label.get_v_scroll_bar().value_changed.connect(_scroll_changed)
		_invalidate_geometry()
	queue_redraw()

func clear() -> void:
	bind(null, null)

func _invalidate_geometry() -> void:
	if _geometry_dirty:
		return
	_geometry_dirty = true
	_rebuild_geometry.call_deferred()

func _scroll_changed(_value: float) -> void:
	# A scrolling wheel does not join points at two different scroll positions.
	if _drawing:
		finish_stroke()
	queue_redraw()

func _rebuild_geometry() -> void:
	_geometry_dirty = false
	_lines.clear()
	_words.clear()
	if not is_instance_valid(label) or state == null or not label.is_finished():
		return
	var style := label.get_theme_stylebox("normal")
	var margin := Vector2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP))
	var font := label.get_theme_font("normal_font")
	var font_size := label.get_theme_font_size("normal_font_size")
	var text_server := TextServerManager.get_primary_interface()
	for index in label.get_line_count():
		var span := label.get_line_range(index)
		# Godot includes a virtual final paragraph separator in the final range.
		var start := mini(span.x, state.display_text.length())
		var end := mini(span.y, state.display_text.length())
		while start < end and state.display_text[start] in ["\n", "\r"]:
			start += 1
		while end > start and state.display_text[end - 1] in ["\n", "\r"]:
			end -= 1
		var shaped := TextLine.new()
		shaped.add_string(state.display_text.substr(start, end - start), font, font_size)
		_lines.append({"start": start, "end": end, "y": margin.y + label.get_line_offset(index), "height": float(label.get_line_height(index)), "x": margin.x, "width": float(label.get_line_width(index)), "shape": shaped})
	var target_ids: Dictionary = {}
	for target in state.targets:
		target_ids[int(target.id)] = true
	for word in ProofreadingState.words(state.display_text):
		var rects: Array = []
		for line in _lines:
			var first := maxi(int(word.start), int(line.start))
			var last := mini(int(word.start + word.length), int(line.end))
			if first >= last:
				continue
			var shaped: TextLine = line.shape
			for selection in text_server.shaped_text_get_selection(shaped.get_rid(), first - int(line.start), last - int(line.start)):
				rects.append(Rect2(float(line.x) + selection.x, float(line.y), selection.y - selection.x, float(line.height)))
		_words.append({"start": int(word.start), "typo": target_ids.has(int(word.start)), "rects": rects})
	queue_redraw()

func begin_stroke(viewport_point: Vector2) -> bool:
	if not input_enabled or not drawing_enabled or state == null or not can_process() or not is_visible_in_tree() or _geometry_dirty or state.strokes.size() >= ProofreadingState.MAX_STROKES:
		return false
	var point := _local_point(viewport_point)
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	_segments.clear()
	_corrected.clear()
	_core_corrected.clear()
	_wrong_coverage.clear()
	_point_count = 0
	_drawing = true
	_last_point = point
	_append_point(point)
	return true

func extend_stroke(viewport_point: Vector2) -> void:
	if not _drawing:
		return
	var point := _local_point(viewport_point).clamp(Vector2.ZERO, size)
	var distance := _last_point.distance_to(point)
	if distance < 1.5:
		return
	var count := maxi(1, ceili(distance / 4.0))
	var origin := _last_point
	for index in range(1, count + 1):
		if _point_count >= ProofreadingState.MAX_POINTS - 3:
			finish_stroke()
			return
		var next := origin.lerp(point, float(index) / count)
		_score_segment(_last_point, next)
		_append_point(next)
		_last_point = next
	queue_redraw()

func finish_stroke() -> void:
	if not _drawing:
		return
	_drawing = false
	var segments: Array = []
	for segment in _segments:
		if segment.points.size() >= 2:
			segments.append(segment)
	var wrong: Array = []
	for word_start in _wrong_coverage:
		if float(_wrong_coverage[word_start].length) >= float(_wrong_coverage[word_start].threshold):
			wrong.append(word_start)
	# A deliberately crossed correct word must not reward its neighbour's margin.
	var hits := _corrected.keys() if wrong.is_empty() else _core_corrected.keys()
	if not segments.is_empty():
		state.add_stroke({"segments": segments, "corrected": hits, "wrong": wrong})
		changed.emit()
	_segments.clear()
	queue_redraw()

func cancel_stroke() -> void:
	_drawing = false
	_segments.clear()
	queue_redraw()

func undo_last() -> bool:
	cancel_stroke()
	if state != null and state.undo_last():
		queue_redraw()
		changed.emit()
		return true
	return false

func _local_point(viewport_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_point

func _label_point(point: Vector2) -> Vector2:
	return label.get_global_transform_with_canvas().affine_inverse() * (get_global_transform_with_canvas() * point)

func _surface_point(body_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * (label.get_global_transform_with_canvas() * body_point)

func _append_point(point: Vector2) -> void:
	_point_count += 1
	var anchor := "desk"
	var character := -1
	var normalized := point / size.max(Vector2.ONE)
	if is_instance_valid(label):
		var body_point := _label_point(point)
		var content_y := body_point.y + label.get_v_scroll_bar().value
		if Rect2(Vector2.ZERO, label.size).has_point(body_point):
			for line in _lines:
				if content_y >= float(line.y) and content_y < float(line.y + line.height) and body_point.x >= float(line.x) and body_point.x <= float(line.x + line.width + 5.0) and int(line.start) < int(line.end):
					anchor = "text"
					character = int(line.start)
					normalized = Vector2(body_point.x / maxf(1, label.size.x), (content_y - float(line.y)) / maxf(1, float(line.height)))
					break
	var data := [normalized.x, normalized.y]
	if _segments.is_empty() or _segments[-1].anchor != anchor or int(_segments[-1].get("character", -1)) != character:
		var segment := {"anchor": anchor, "points": [data]}
		if anchor == "text":
			segment["character"] = character
		if not _segments.is_empty():
			# Shared boundary points keep one physical stroke continuous before scrolling.
			var boundary := _last_point.lerp(point, 0.5)
			_segments[-1].points.append(_encode_point(boundary, _segments[-1]))
			segment.points.push_front(_encode_point(boundary, segment))
			_point_count += 2
		_segments.append(segment)
	else:
		_segments[-1].points.append(data)

func _encode_point(point: Vector2, segment: Dictionary) -> Array:
	if segment.anchor == "desk":
		var normalized := point / size.max(Vector2.ONE)
		return [normalized.x, normalized.y]
	var body_point := _label_point(point)
	for line in _lines:
		if int(segment.character) == int(line.start):
			return [body_point.x / maxf(1, label.size.x), (body_point.y + label.get_v_scroll_bar().value - float(line.y)) / maxf(1, float(line.height))]
	return [0.0, 0.0]

func _score_segment(a: Vector2, b: Vector2) -> void:
	if not is_instance_valid(label):
		return
	var p := _label_point(a)
	var q := _label_point(b)
	var visible := Rect2(Vector2.ZERO, label.size)
	var clipped := _clip_segment(p, q, visible)
	if clipped.is_empty():
		return
	p = clipped[0] + Vector2(0, label.get_v_scroll_bar().value)
	q = clipped[1] + Vector2(0, label.get_v_scroll_bar().value)
	for word in _words:
		for rect: Rect2 in word.rects:
			if word.typo:
				# 2.1 in each dimension means a 4.41-times larger target area.
				var generous := Rect2(rect.get_center() - rect.size * 1.05, rect.size * 2.1)
				if not _clip_segment(p, q, generous).is_empty():
					_corrected[int(word.start)] = true
				if not _clip_segment(p, q, rect).is_empty():
					_core_corrected[int(word.start)] = true
			else:
				var core := rect.grow_individual(-1, -rect.size.y * 0.2, -1, -rect.size.y * 0.2)
				var overlap := _clip_segment(p, q, core)
				if overlap.size() == 2:
					var start: int = word.start
					if not _wrong_coverage.has(start):
						_wrong_coverage[start] = {"length": 0.0, "threshold": maxf(12.0, rect.size.x * 0.35)}
					_wrong_coverage[start].length += (overlap[0] as Vector2).distance_to(overlap[1])

static func _clip_segment(a: Vector2, b: Vector2, rect: Rect2) -> Array:
	var delta := b - a
	var low := 0.0
	var high := 1.0
	for axis in 2:
		if absf(delta[axis]) < 0.00001:
			if a[axis] < rect.position[axis] or a[axis] > rect.end[axis]:
				return []
		else:
			var first := (rect.position[axis] - a[axis]) / delta[axis]
			var last := (rect.end[axis] - a[axis]) / delta[axis]
			low = maxf(low, minf(first, last))
			high = minf(high, maxf(first, last))
			if low > high:
				return []
	return [a + delta * low, a + delta * high]

func _segment_body_point(segment: Dictionary, point: Array) -> Vector2:
	var character := int(segment.character)
	for line in _lines:
		if character >= int(line.start) and character < int(line.end):
			return Vector2(float(point[0]) * label.size.x, float(line.y) + float(point[1]) * float(line.height) - label.get_v_scroll_bar().value)
	return Vector2(-10000, -10000)

func _draw() -> void:
	if state != null:
		for stroke in state.strokes:
			_draw_segments(stroke.segments)
	_draw_segments(_segments)

func _draw_segments(segments: Array) -> void:
	for segment in segments:
		var points: Array = segment.points
		if points.size() < 2:
			continue
		if segment.anchor == "desk":
			var polyline := PackedVector2Array()
			for point in points:
				polyline.append(Vector2(point[0], point[1]) * size)
			draw_polyline(polyline, pencil_color, line_width, true)
		elif is_instance_valid(label):
			for index in range(1, points.size()):
				var a := _segment_body_point(segment, points[index - 1])
				var b := _segment_body_point(segment, points[index])
				var clipped := _clip_segment(a, b, Rect2(Vector2.ZERO, label.size))
				if clipped.size() == 2:
					draw_line(_surface_point(clipped[0]), _surface_point(clipped[1]), pencil_color, line_width, true)
