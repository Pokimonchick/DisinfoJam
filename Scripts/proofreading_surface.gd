class_name ProofreadingSurface
extends Control

signal changed

const Evaluation = preload("res://Scripts/proofreading_evaluation.gd")

@export var pencil_color := Color("b62918", 0.98)
@export_range(1.0, 6.0, 0.2) var line_width := 2.8
@export_range(0.0, 1.0, 0.05) var grain_strength := 0.75:
	set(value):
		grain_strength = value
		_refresh_brush_material()
@export_range(0.4, 3.0, 0.05) var grain_scale := 0.85:
	set(value):
		grain_scale = value
		_refresh_brush_material()

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
var _geometry_dirty := false
var _point_count := 0
var _erasing := false
var _erasure_changed := false
var _erase_point := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if material == null:
		set_ink_material(preload("res://Data/source_ink.tres"))

func set_ink_material(ink: ShaderMaterial) -> void:
	# The brush has its own grain; source glyphs retain their unchanged material.
	material = ink.duplicate() as ShaderMaterial
	_refresh_brush_material()

func _refresh_brush_material() -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("pencil_grain_strength", grain_strength)
		material.set_shader_parameter("pencil_grain_scale", grain_scale)

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

func create_evaluation(pages: Array[Vector2i] = []) -> Evaluation:
	finish_stroke()
	finish_erasure()
	var evaluation := Evaluation.new()
	evaluation.prepare(state, label, self, pages, character_offset)
	return evaluation

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
	if not segments.is_empty():
		state.add_stroke({"segments": segments, "corrected": [], "wrong": [], "page_character": character_offset})
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
	var anchor := ProofreadingState.stroke_page_anchor(stroke)
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
	# A swept circular nose is one capsule. Sampling many overlapping circles
	# rescanned and split the same dense marks repeatedly on a fast mouse move.
	for part in _paper_parts(origin, point):
		_erase_between(part[0], part[1], radius)
	_erase_point = point

func finish_erasure() -> void:
	_erasing = false
	if _erasure_changed:
		_erasure_changed = false
		changed.emit()

func _erase_at(centre: Vector2, radius: float) -> void:
	_erase_between(centre, centre, radius)

func _erase_between(origin: Vector2, finish: Vector2, radius: float) -> void:
	var motion := finish - origin
	var length := motion.length()
	var along := motion / length if length > 0.001 else Vector2.ZERO
	var bounds := Rect2(origin.min(finish) - Vector2.ONE * radius, motion.abs() + Vector2.ONE * radius * 2.0)
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
			var previous := _segment_point(segment, segment.points[0])
			for point_index in range(1, segment.points.size()):
				var a := previous
				var b := _segment_point(segment, segment.points[point_index])
				previous = b
				var cut := _sweep_interval(a, b, origin, finish, radius, bounds, along, length)
				if cut.x < 0.0:
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
			# Legacy cached classifications are no longer valid after an edit.
			stroke.corrected = []
			stroke.wrong = []
	queue_redraw()

static func _capsule_interval(a: Vector2, b: Vector2, origin: Vector2, finish: Vector2, radius: float) -> Vector2:
	var motion := finish - origin
	var length := motion.length()
	var along := motion / length if length > 0.001 else Vector2.ZERO
	var bounds := Rect2(origin.min(finish) - Vector2.ONE * radius, motion.abs() + Vector2.ONE * radius * 2.0)
	return _sweep_interval(a, b, origin, finish, radius, bounds, along, length)

static func _sweep_interval(a: Vector2, b: Vector2, origin: Vector2, finish: Vector2, radius: float, bounds: Rect2, along: Vector2, length: float) -> Vector2:
	if length <= 0.001:
		return _circle_interval(a, b, origin, radius)
	if maxf(a.x, b.x) < bounds.position.x or minf(a.x, b.x) > bounds.end.x or maxf(a.y, b.y) < bounds.position.y or minf(a.y, b.y) > bounds.end.y:
		return Vector2(-1, -1)
	var across := Vector2(-along.y, along.x)
	var p := Vector2((a - origin).dot(along), (a - origin).dot(across))
	var q := Vector2((b - origin).dot(along), (b - origin).dot(across))
	var low := 1.0
	var high := 0.0
	var middle := _clip_segment(p, q, Rect2(0, -radius, length, radius * 2.0))
	if not middle.is_empty():
		var delta := q - p
		var squared := delta.length_squared()
		low = (middle[0] - p).dot(delta) / squared if squared > 0.000001 else 0.0
		high = (middle[1] - p).dot(delta) / squared if squared > 0.000001 else 1.0
	for centre in [origin, finish]:
		var cap := _circle_interval(a, b, centre, radius)
		if cap.x >= 0.0:
			low = minf(low, cap.x)
			high = maxf(high, cap.y)
	return Vector2(clampf(low, 0.0, 1.0), clampf(high, 0.0, 1.0)) if high > low else Vector2(-1, -1)

static func _circle_interval(a: Vector2, b: Vector2, centre: Vector2, radius: float) -> Vector2:
	# Reject distant pairs before quadratic work; Vector2 avoids allocating an
	# empty Array for every missed pair in a densely marked page.
	if maxf(a.x, b.x) < centre.x - radius or minf(a.x, b.x) > centre.x + radius or maxf(a.y, b.y) < centre.y - radius or minf(a.y, b.y) > centre.y + radius:
		return Vector2(-1, -1)
	var delta := b - a
	var offset := a - centre
	var length_squared := delta.length_squared()
	if length_squared < 0.000001:
		return Vector2(0, 1) if offset.length_squared() < radius * radius else Vector2(-1, -1)
	var projection := offset.dot(delta)
	var discriminant := projection * projection - length_squared * (offset.length_squared() - radius * radius)
	if discriminant <= 0.0:
		return Vector2(-1, -1)
	var low := maxf(0.0, (-projection - sqrt(discriminant)) / length_squared)
	var high := minf(1.0, (-projection + sqrt(discriminant)) / length_squared)
	return Vector2(low, high) if high > low else Vector2(-1, -1)
func _segment_visible(segment: Dictionary) -> bool:
	return segment.anchor == "desk" or (is_instance_valid(label) and int(segment.character) >= character_offset and int(segment.character) < character_offset + label.text.length())

func _local_point(viewport_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_point

func _surface_point(body_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * (label.get_global_transform_with_canvas() * body_point)

static func _clip_segment(a: Vector2, b: Vector2, rect: Rect2) -> Array:
	return Evaluation.clip_segment(a, b, rect)

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
