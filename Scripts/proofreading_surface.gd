class_name ProofreadingSurface
extends Control

signal changed

@export var pencil_color := Color("c96d62", 0.82)
@export_range(1.0, 6.0, 0.2) var line_width := 2.4

var input_enabled := true:
	set(value):
		input_enabled = value
		if not value:
			cancel_stroke()
			finish_erasure()
var drawing_enabled := false:
	set(value):
		drawing_enabled = value
		if not value:
			cancel_stroke()
var state: ProofreadingState
var label: RichTextLabel
var paper: Control
var exclusions: Array[Control] = []
var character_offset := 0
var text_opacity := 1.0:
	set(value):
		text_opacity = value
		queue_redraw()
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
var _erasing := false
var _erasure_changed := false
var _erase_point := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind(body: RichTextLabel, article_state: ProofreadingState, page_offset := -1) -> void:
	finish_erasure()
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
	character_offset = maxi(0, page_offset)
	_lines.clear()
	_words.clear()
	if is_instance_valid(label) and state != null:
		if page_offset < 0:
			label.text = state.display_text
		label.resized.connect(_invalidate_geometry)
		label.theme_changed.connect(_invalidate_geometry)
		label.get_v_scroll_bar().value_changed.connect(_scroll_changed)
		_invalidate_geometry()
	queue_redraw()

func clear() -> void:
	bind(null, null)

func set_page_offset(offset: int) -> void:
	finish_stroke()
	finish_erasure()
	character_offset = maxi(0, offset)
	_invalidate_geometry()
	queue_redraw()

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
	var visible_text := label.text
	for index in label.get_line_count():
		var span := label.get_line_range(index)
		# Godot includes a virtual final paragraph separator in the final range.
		var start := mini(span.x, visible_text.length())
		var end := mini(span.y, visible_text.length())
		while start < end and visible_text[start] in ["\n", "\r"]:
			start += 1
		while end > start and visible_text[end - 1] in ["\n", "\r"]:
			end -= 1
		var shaped := TextLine.new()
		shaped.add_string(visible_text.substr(start, end - start), font, font_size)
		_lines.append({"start": start + character_offset, "end": end + character_offset, "y": margin.y + label.get_line_offset(index), "height": float(label.get_line_height(index)), "x": margin.x, "width": float(label.get_line_width(index)), "shape": shaped})
	var target_ids: Dictionary = {}
	for target in state.targets:
		target_ids[int(target.id)] = true
	for word in ProofreadingState.words(state.display_text):
		if int(word.start + word.length) <= character_offset or int(word.start) >= character_offset + visible_text.length():
			continue
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
	if not _paper_contains(point):
		return false
	_segments.clear()
	_corrected.clear()
	_core_corrected.clear()
	_wrong_coverage.clear()
	_point_count = 0
	_drawing = true
	_last_point = point
	return true

func extend_stroke(viewport_point: Vector2) -> void:
	if not _drawing:
		return
	var point := _local_point(viewport_point)
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
		for part in _paper_parts(_last_point, next):
			_score_segment(part[0], part[1])
			_append_paper_part(part[0], part[1])
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
		state.add_stroke({"segments": segments, "corrected": hits, "wrong": wrong, "page_character": character_offset})
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

func _paper_contains(point: Vector2) -> bool:
	return not _paper_parts(point, point + Vector2(0.001, 0)).is_empty()

func _paper_parts(a: Vector2, b: Vector2) -> Array:
	# Clip in the rotated paper's coordinates, then subtract foreground controls.
	var transform := get_global_transform_with_canvas()
	var paper_transform := paper.get_global_transform_with_canvas() if is_instance_valid(paper) else transform
	var inverse := paper_transform.affine_inverse() * transform
	var bounds := Rect2(Vector2.ZERO, paper.size if is_instance_valid(paper) else size).grow(-line_width * 0.5)
	var clipped := _clip_segment(inverse * a, inverse * b, bounds)
	if clipped.is_empty():
		return []
	var to_surface := transform.affine_inverse() * paper_transform
	var parts: Array = [[to_surface * clipped[0], to_surface * clipped[1]]]
	for obstacle in exclusions:
		if not is_instance_valid(obstacle) or not obstacle.is_visible_in_tree():
			continue
		var to_obstacle := obstacle.get_global_transform_with_canvas().affine_inverse() * transform
		var from_obstacle := to_obstacle.affine_inverse()
		var kept: Array = []
		for part in parts:
			var p: Vector2 = to_obstacle * part[0]
			var q: Vector2 = to_obstacle * part[1]
			var blocked := _clip_segment(p, q, Rect2(Vector2.ZERO, obstacle.size).grow(line_width * 0.5))
			if blocked.is_empty():
				kept.append(part)
			else:
				if p.distance_to(blocked[0]) > 0.001:
					kept.append([part[0], from_obstacle * blocked[0]])
				if q.distance_to(blocked[1]) > 0.001:
					kept.append([from_obstacle * blocked[1], part[1]])
		parts = kept
	return parts

func _append_paper_part(a: Vector2, b: Vector2) -> void:
	var p := a / size.max(Vector2.ONE)
	var q := b / size.max(Vector2.ONE)
	var first := [p.x, p.y]
	var last := [q.x, q.y]
	if _segments.is_empty() or _segment_point(_segments[-1], _segments[-1].points[-1]).distance_to(a) > 0.01:
		_segments.append({"anchor": "desk", "points": [first, last]})
		_point_count += 2
	else:
		_segments[-1].points.append(last)
		_point_count += 1

func _stroke_visible(stroke: Dictionary) -> bool:
	var anchor: int = stroke.get("page_character", -1)
	if anchor < 0:
		# Older saves mixed text and desk anchors. Keep the whole mark on its
		# originating sheet instead of letting its blank-paper pieces leak across.
		anchor = 0
		for segment in stroke.segments:
			if segment.anchor == "text":
				anchor = int(segment.character)
				break
	return is_instance_valid(label) and anchor >= character_offset and anchor < character_offset + maxi(1, label.text.length())

func _segment_point(segment: Dictionary, point: Array) -> Vector2:
	if segment.anchor == "desk":
		return Vector2(point[0], point[1]) * size
	return _surface_point(_segment_body_point(segment, point))

func begin_erasure(viewport_point: Vector2, radius: float) -> bool:
	if not input_enabled or state == null or _geometry_dirty or not can_process() or not is_visible_in_tree():
		return false
	var point := _local_point(viewport_point)
	if not _paper_contains(point):
		return false
	finish_stroke()
	_erasing = true
	_erasure_changed = false
	_erase_point = point
	_erase_at(point, radius)
	return true

func extend_erasure(viewport_point: Vector2, radius: float) -> void:
	if not _erasing or not input_enabled:
		return
	var point := _local_point(viewport_point)
	var origin := _erase_point
	var count := maxi(1, ceili(origin.distance_to(point) / maxf(2.0, radius * 0.5)))
	for index in range(1, count + 1):
		var centre := origin.lerp(point, float(index) / count)
		if _paper_contains(centre):
			_erase_at(centre, radius)
	_erase_point = point

func finish_erasure() -> void:
	_erasing = false
	if _erasure_changed:
		_erasure_changed = false
		changed.emit()

func _erase_at(centre: Vector2, radius: float) -> void:
	for index in range(state.strokes.size() - 1, -1, -1):
		var stroke: Dictionary = state.strokes[index]
		if not _stroke_visible(stroke):
			continue
		var remaining: Array = []
		var touched := false
		for segment in stroke.segments:
			if not _segment_visible(segment):
				remaining.append(segment)
				continue
			var fragments: Array = []
			var run: Array = []
			for point_index in range(1, segment.points.size()):
				var a := _segment_point(segment, segment.points[point_index - 1])
				var b := _segment_point(segment, segment.points[point_index])
				var cut := _circle_interval(a, b, centre, radius)
				if cut.is_empty():
					if run.is_empty():
						run.append(segment.points[point_index - 1])
					run.append(segment.points[point_index])
					continue
				touched = true
				var p := Vector2(segment.points[point_index - 1][0], segment.points[point_index - 1][1])
				var q := Vector2(segment.points[point_index][0], segment.points[point_index][1])
				if cut[0] > 0.00001:
					if run.is_empty():
						run.append(segment.points[point_index - 1])
					var edge := p.lerp(q, cut[0])
					run.append([edge.x, edge.y])
				if run.size() >= 2:
					fragments.append(run)
				run = []
				if cut[1] < 0.99999:
					var edge := p.lerp(q, cut[1])
					run = [[edge.x, edge.y], segment.points[point_index]]
			if run.size() >= 2:
				fragments.append(run)
			for points in fragments:
				var fragment: Dictionary = segment.duplicate()
				fragment.points = points
				remaining.append(fragment)
		if not touched:
			continue
		var total := 0
		for segment in remaining:
			total += segment.points.size()
		if total > ProofreadingState.MAX_POINTS:
			# Preserve the original rather than deleting unrelated ink when the
			# save's point budget cannot represent another split.
			continue
		_erasure_changed = true
		if remaining.is_empty():
			state.strokes.remove_at(index)
		else:
			stroke.segments = remaining
			_rescore_stroke(stroke)
	queue_redraw()

static func _circle_interval(a: Vector2, b: Vector2, centre: Vector2, radius: float) -> Array:
	var delta := b - a
	var offset := a - centre
	var length_squared := delta.length_squared()
	if length_squared < 0.000001:
		return [0.0, 1.0] if offset.length_squared() < radius * radius else []
	var projection := offset.dot(delta)
	var discriminant := projection * projection - length_squared * (offset.length_squared() - radius * radius)
	if discriminant <= 0.0:
		return []
	var low := maxf(0.0, (-projection - sqrt(discriminant)) / length_squared)
	var high := minf(1.0, (-projection + sqrt(discriminant)) / length_squared)
	return [low, high] if high > low else []

func _rescore_stroke(stroke: Dictionary) -> void:
	_corrected.clear()
	_core_corrected.clear()
	_wrong_coverage.clear()
	for segment in stroke.segments:
		if not _segment_visible(segment):
			continue
		for index in range(1, segment.points.size()):
			_score_segment(_segment_point(segment, segment.points[index - 1]), _segment_point(segment, segment.points[index]))
	var wrong: Array = []
	for word_start in _wrong_coverage:
		if float(_wrong_coverage[word_start].length) >= float(_wrong_coverage[word_start].threshold):
			wrong.append(word_start)
	var preserved_corrected: Array = stroke.get("corrected", []).filter(func(id): return int(id) < character_offset or int(id) >= character_offset + label.text.length())
	var preserved_wrong: Array = stroke.get("wrong", []).filter(func(id): return int(id) < character_offset or int(id) >= character_offset + label.text.length())
	stroke.corrected = preserved_corrected + (_corrected.keys() if wrong.is_empty() else _core_corrected.keys())
	stroke.wrong = preserved_wrong + wrong

func _segment_visible(segment: Dictionary) -> bool:
	return segment.anchor == "desk" or (is_instance_valid(label) and int(segment.character) >= character_offset and int(segment.character) < character_offset + label.text.length())

func _local_point(viewport_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_point

func _label_point(point: Vector2) -> Vector2:
	return label.get_global_transform_with_canvas().affine_inverse() * (get_global_transform_with_canvas() * point)

func _surface_point(body_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * (label.get_global_transform_with_canvas() * body_point)

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
			if _stroke_visible(stroke):
				_draw_segments(stroke.segments, not stroke.has("page_character"))
	_draw_segments(_segments, false)

func _draw_segments(segments: Array, legacy_clipping := true) -> void:
	for segment in segments:
		if not _segment_visible(segment):
			continue
		var points: Array = segment.points
		if points.size() < 2:
			continue
		var color := pencil_color
		color.a *= text_opacity
		if not legacy_clipping:
			# New marks are already clipped when written: one draw call per run.
			var polyline := PackedVector2Array()
			for point in points:
				polyline.append(Vector2(point[0], point[1]) * size)
			draw_polyline(polyline, color, line_width, true)
			continue
		for index in range(1, points.size()):
			var a := _segment_point(segment, points[index - 1])
			var b := _segment_point(segment, points[index])
			for part in _paper_parts(a, b):
				draw_line(part[0], part[1], color, line_width, true)
