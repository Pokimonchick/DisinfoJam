class_name SourcePager
extends Control

signal page_changed(character_offset: int)
signal turning_changed
signal opacity_changed(opacity: float)

@export_range(0.0, 1.0, 0.01) var turn_seconds := 0.24
@export_range(0.0, 60.0, 1.0) var footer_gap := 20.0
@export_range(0.3, 0.9, 0.05) var paragraph_fill_minimum := 0.55

var enabled := true:
	set(value):
		if enabled == value:
			return
		enabled = value
		if is_node_ready():
			_refresh_navigation()
var turning := false
var source_text := ""
var character_offset := 0
var page_index := 0
var body: RichTextLabel
var _measure: RichTextLabel
var _pages: Array[Vector2i] = []
var _motion: Tween
var _target_page := -1
var _layout_queued := false

@onready var previous: Button = $Row/Previous
@onready var next: Button = $Row/Next
@onready var counter: Label = $Row/Counter

func _ready() -> void:
	previous.pressed.connect(func(): turn_to(page_index - 1))
	next.pressed.connect(func(): turn_to(page_index + 1))
	_measure = RichTextLabel.new()
	_measure.name = "Measure"
	_measure.hide()
	_measure.scroll_active = false
	_measure.threaded = false
	add_child(_measure)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			finish_turn()
	)
	_refresh_navigation()

func bind(label: RichTextLabel) -> void:
	body = label
	body.scroll_active = false
	body.focus_mode = Control.FOCUS_NONE
	body.resized.connect(_queue_layout)
	body.theme_changed.connect(_queue_layout)
	set_source(body.text)

func set_source(text: String) -> void:
	_stop_turn()
	source_text = text
	page_index = 0
	_pages.clear()
	_rebuild_pages(0)

func _queue_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	_relayout.call_deferred()

func _relayout() -> void:
	_layout_queued = false
	var anchor := capture_character()
	_stop_turn()
	_rebuild_pages(anchor)

func _rebuild_pages(anchor: int) -> void:
	if not is_instance_valid(body):
		return
	# Shape the full source once. The visible label receives only one page, so
	# a short last page stays at the top without scrollbar padding or overlap.
	_measure.size = body.size
	_measure.autowrap_mode = body.autowrap_mode
	_measure.autowrap_trim_flags = body.autowrap_trim_flags
	_measure.language = body.language
	_measure.text_direction = body.text_direction
	_measure.horizontal_alignment = body.horizontal_alignment
	_measure.add_theme_font_override("normal_font", body.get_theme_font("normal_font"))
	_measure.add_theme_font_size_override("normal_font_size", body.get_theme_font_size("normal_font_size"))
	_measure.add_theme_stylebox_override("normal", body.get_theme_stylebox("normal"))
	for key in ["line_separation", "paragraph_separation"]:
		_measure.add_theme_constant_override(key, body.get_theme_constant(key))
	_measure.text = source_text
	var style := body.get_theme_stylebox("normal")
	var height := maxf(1.0, body.size.y - style.get_margin(SIDE_TOP) - style.get_margin(SIDE_BOTTOM) - 1.0)
	var line_count := _measure.get_line_count()
	_pages.clear()
	var first := 0
	var start := 0
	while first < line_count and start < source_text.length():
		var top := _measure.get_line_offset(first)
		var end := first + 1
		while end < line_count and _measure.get_line_offset(end) + _measure.get_line_height(end) - top <= height:
			end += 1
		# Keep a paragraph intact when its boundary leaves a reasonably full sheet.
		if end < line_count:
			var preferred := end
			for index in range(first + 1, end):
				var previous_start := clampi(_measure.get_line_range(index - 1).x, 0, source_text.length())
				var next_start := clampi(_measure.get_line_range(index).x, 0, source_text.length())
				if "\n" in source_text.substr(previous_start, next_start - previous_start) and _measure.get_line_offset(index) - top >= height * paragraph_fill_minimum:
					preferred = index
			end = preferred
		var stop := source_text.length() if end >= line_count else clampi(_measure.get_line_range(end).x, start, source_text.length())
		if stop > start:
			_pages.append(Vector2i(start, stop))
		start = stop
		first = end
	if start < source_text.length():
		_pages.append(Vector2i(start, source_text.length()))
	if _pages.is_empty():
		_pages.append(Vector2i(0, source_text.length()))
	position = body.get_transform() * Vector2((body.size.x - size.x) * 0.5, body.size.y + footer_gap)
	rotation = body.rotation
	scale = body.scale
	go_to_character(anchor)
	_refresh_navigation()

func go_to_character(anchor: int) -> void:
	_stop_turn()
	var index := 0
	for candidate in _pages.size():
		if anchor >= _pages[candidate].x:
			index = candidate
	_apply_page(index)

func capture_character() -> int:
	if _pages.is_empty():
		return 0
	return _pages[_target_page if _target_page >= 0 else page_index].x

func turn_to(index: int) -> void:
	if not enabled or turning or not can_process() or not is_visible_in_tree() or index < 0 or index >= _pages.size() or index == page_index:
		return
	if turn_seconds <= 0.0:
		_apply_page(index)
		return
	_target_page = index
	turning = true
	_refresh_navigation()
	turning_changed.emit()
	_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_method(_set_opacity, 1.0, 0.0, turn_seconds * 0.5)
	_motion.tween_callback(func(): _apply_page(_target_page))
	_motion.tween_method(_set_opacity, 0.0, 1.0, turn_seconds * 0.5)
	_motion.tween_callback(func():
		_motion = null
		_target_page = -1
		turning = false
		_refresh_navigation()
		turning_changed.emit()
	)

func finish_turn() -> void:
	if not turning:
		return
	var target := _target_page
	_stop_turn()
	_apply_page(target)

func _stop_turn() -> void:
	if _motion and _motion.is_valid():
		_motion.kill()
	_motion = null
	_target_page = -1
	var was_turning := turning
	turning = false
	_set_opacity(1.0)
	if was_turning:
		_refresh_navigation()
		turning_changed.emit()

func _apply_page(index: int) -> void:
	if _pages.is_empty() or not is_instance_valid(body):
		return
	page_index = clampi(index, 0, _pages.size() - 1)
	var span := _pages[page_index]
	# Separators belong to the full source; a new sheet starts at its first ink.
	while span.x < span.y and source_text[span.x] in ["\n", "\r"]:
		span.x += 1
	while span.y > span.x and source_text[span.y - 1] in ["\n", "\r"]:
		span.y -= 1
	character_offset = span.x
	body.text = source_text.substr(span.x, span.y - span.x)
	body.scroll_to_line(0)
	_refresh_navigation()
	page_changed.emit(character_offset)

func _set_opacity(value: float) -> void:
	if is_instance_valid(body):
		body.self_modulate.a = value
	if is_node_ready():
		$Row.modulate.a = value
	opacity_changed.emit(value)

func _refresh_navigation() -> void:
	if not is_node_ready():
		return
	visible = _pages.size() > 1
	counter.text = "%d / %d" % [page_index + 1, maxi(1, _pages.size())]
	previous.disabled = not enabled or turning or page_index <= 0
	next.disabled = not enabled or turning or page_index >= _pages.size() - 1

func _input(event: InputEvent) -> void:
	if not enabled or not is_instance_valid(body) or not body.is_visible_in_tree() or not event is InputEventMouseButton:
		return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var local: Vector2 = body.get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2(Vector2.ZERO, body.size).has_point(local):
			get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		turn_to(page_index + (-1 if event.keycode == KEY_PAGEUP else 1))
		get_viewport().set_input_as_handled()
