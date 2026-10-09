class_name ProofreadingEvaluation
extends RefCounted

# Recognition is a publication job. Drawing and erasure only edit geometry.
const CELL_SIZE := 64.0

var done := false
var counts: Dictionary = {}
var processed_segments := 0
var _state: ProofreadingState
var _measure: RichTextLabel
var _surface_size := Vector2.ONE
var _to_label := Transform2D.IDENTITY
var _label_size := Vector2.ONE
var _scroll := 0.0
var _pages: Array[Vector2i] = []
var _source_words: Array = []
var _targets: Dictionary = {}
var _geometry: Dictionary = {}
var _building: Dictionary = {}
var _line_index := 0
var _word_index := 0
var _stroke_index := 0
var _segment_index := 0
var _point_index := 1
var _corrected: Dictionary = {}
var _core_corrected: Dictionary = {}
var _wrong_coverage: Dictionary = {}
var _all_corrected: Dictionary = {}
var _all_wrong: Dictionary = {}

func prepare(state: ProofreadingState, body: RichTextLabel, surface: Control, pages: Array[Vector2i], offset: int) -> void:
	_state = state
	_surface_size = surface.size
	_to_label = body.get_global_transform_with_canvas().affine_inverse() * surface.get_global_transform_with_canvas()
	_label_size = body.size
	_pages = pages.duplicate()
	if _pages.is_empty():
		_pages.append(Vector2i(offset, offset + body.text.length()))
		_scroll = body.get_v_scroll_bar().value
	_source_words = ProofreadingState.words(state.display_text)
	for target in state.targets:
		_targets[int(target.id)] = true
	# Measure other sheets without changing the player's visible text or page.
	_measure = body.duplicate() as RichTextLabel
	_measure.name = "ProofreadingMeasure"
	_measure.hide()
	_measure.material = null
	_measure.threaded = false
	_measure.scroll_active = false
	_measure.text = ""
	_measure.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_measure.position = Vector2.ZERO
	_measure.rotation = 0.0
	_measure.scale = Vector2.ONE
	_measure.size = _label_size
	surface.add_child(_measure)

func advance(budget_usec := 2000) -> bool:
	if done:
		return true
	var deadline := Time.get_ticks_usec() + maxi(1, budget_usec)
	# At least one small operation per frame, including very small test budgets.
	_step()
	while not done and Time.get_ticks_usec() < deadline:
		_step()
	return done

func dispose() -> void:
	if is_instance_valid(_measure):
		_measure.queue_free()
	_measure = null

func _step() -> void:
	if _stroke_index >= _state.strokes.size():
		counts = {"corrected": _all_corrected.size(), "wrong": _all_wrong.size()}
		done = true
		return
	var stroke: Dictionary = _state.strokes[_stroke_index]
	var span := _page_for(ProofreadingState.stroke_page_anchor(stroke))
	if not _geometry.has(span.x):
		_build_page_step(span)
		return
	if _segment_index >= stroke.segments.size():
		_finish_stroke()
		return
	var segment: Dictionary = stroke.segments[_segment_index]
	if _point_index >= segment.points.size() or (segment.anchor == "text" and (int(segment.character) < span.x or int(segment.character) >= span.y)):
		_segment_index += 1
		_point_index = 1
		return
	var geometry: Dictionary = _geometry[span.x]
	var a := _point(segment, segment.points[_point_index - 1], geometry)
	var b := _point(segment, segment.points[_point_index], geometry)
	_score_segment(a, b, geometry)
	_point_index += 1
	processed_segments += 1

func _page_for(anchor: int) -> Vector2i:
	var result := _pages[0]
	for span in _pages:
		if span.x > anchor:
			break
		result = span
	return result

func _build_page_step(span: Vector2i) -> void:
	if _building.is_empty():
		_measure.text = _state.display_text.substr(span.x, span.y - span.x)
		_building = {"lines": [], "grid": {}}
		_line_index = 0
		_word_index = 0
		return
	var style := _measure.get_theme_stylebox("normal")
	var margin := Vector2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP))
	if _line_index < _measure.get_line_count():
		var range := _measure.get_line_range(_line_index)
		var start := mini(range.x, _measure.text.length())
		var end := mini(range.y, _measure.text.length())
		while start < end and _measure.text[start] in ["\n", "\r"]:
			start += 1
		while end > start and _measure.text[end - 1] in ["\n", "\r"]:
			end -= 1
		var shape := TextLine.new()
		shape.add_string(_measure.text.substr(start, end - start), _measure.get_theme_font("normal_font"), _measure.get_theme_font_size("normal_font_size"))
		_building.lines.append({"start": start + span.x, "end": end + span.x, "x": margin.x, "y": margin.y + _measure.get_line_offset(_line_index), "height": float(_measure.get_line_height(_line_index)), "shape": shape})
		_line_index += 1
		return
	if _word_index < _source_words.size():
		var word: Dictionary = _source_words[_word_index]
		_word_index += 1
		if int(word.start + word.length) <= span.x or int(word.start) >= span.y:
			return
		var text_server := TextServerManager.get_primary_interface()
		for line in _building.lines:
			var first := maxi(int(word.start), int(line.start))
			var last := mini(int(word.start + word.length), int(line.end))
			if first >= last:
				continue
			for selection in text_server.shaped_text_get_selection((line.shape as TextLine).get_rid(), first - int(line.start), last - int(line.start)):
				var rect := Rect2(float(line.x) + selection.x, float(line.y), selection.y - selection.x, float(line.height))
				var typo := _targets.has(int(word.start))
				var bounds := Rect2(rect.get_center() - rect.size * 1.05, rect.size * 2.1) if typo else rect.grow_individual(-1, -rect.size.y * 0.2, -1, -rect.size.y * 0.2)
				var entry := {"start": int(word.start), "typo": typo, "rect": rect, "bounds": bounds}
				for cell in _cells(bounds):
					if not _building.grid.has(cell):
						_building.grid[cell] = []
					_building.grid[cell].append(entry)
		return
	_geometry[span.x] = _building
	_building = {}

func _point(segment: Dictionary, point: Array, geometry: Dictionary) -> Vector2:
	if segment.anchor == "desk":
		return _to_label * (Vector2(point[0], point[1]) * _surface_size)
	for line in geometry.lines:
		if int(segment.character) >= int(line.start) and int(segment.character) < int(line.end):
			return Vector2(float(point[0]) * _label_size.x, float(line.y) + float(point[1]) * float(line.height) - _scroll)
	return Vector2(-10000, -10000)

func _score_segment(a: Vector2, b: Vector2, geometry: Dictionary) -> void:
	var clipped := clip_segment(a, b, Rect2(Vector2.ZERO, _label_size))
	if clipped.is_empty():
		return
	var p: Vector2 = clipped[0] + Vector2(0, _scroll)
	var q: Vector2 = clipped[1] + Vector2(0, _scroll)
	var seen: Dictionary = {}
	for cell in _cells(Rect2(p.min(q), (q - p).abs())):
		for word in geometry.grid.get(cell, []):
			# A wrapped word may have several rectangles. Deduplicate each rectangle,
			# rather than the word, when its bounds span neighbouring grid cells.
			var key := Vector3(word.start, word.rect.position.x, word.rect.position.y)
			if seen.has(key):
				continue
			seen[key] = true
			var overlap := clip_segment(p, q, word.bounds)
			if overlap.is_empty():
				continue
			var start: int = word.start
			if word.typo:
				_corrected[start] = true
				if not clip_segment(p, q, word.rect).is_empty():
					_core_corrected[start] = true
			else:
				if not _wrong_coverage.has(start):
					_wrong_coverage[start] = {"length": 0.0, "threshold": maxf(12.0, word.rect.size.x * 0.35)}
				_wrong_coverage[start].length += (overlap[0] as Vector2).distance_to(overlap[1])

func _finish_stroke() -> void:
	var wrong: Dictionary = {}
	for start in _wrong_coverage:
		if float(_wrong_coverage[start].length) >= float(_wrong_coverage[start].threshold):
			wrong[start] = true
	_all_wrong.merge(wrong)
	# Preserve the existing rule for generous typo margins near a crossed word.
	_all_corrected.merge(_corrected if wrong.is_empty() else _core_corrected)
	_corrected.clear()
	_core_corrected.clear()
	_wrong_coverage.clear()
	_stroke_index += 1
	_segment_index = 0
	_point_index = 1

static func _cells(rect: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(floori(rect.position.y / CELL_SIZE), floori(rect.end.y / CELL_SIZE) + 1):
		for x in range(floori(rect.position.x / CELL_SIZE), floori(rect.end.x / CELL_SIZE) + 1):
			cells.append(Vector2i(x, y))
	return cells

static func clip_segment(a: Vector2, b: Vector2, rect: Rect2) -> Array:
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
			if first > last:
				var swap := first
				first = last
				last = swap
			low = maxf(low, first)
			high = minf(high, last)
			if low > high:
				return []
	return [a + delta * low, a + delta * high]
