extends CanvasLayer

const SHOW_DELAY := 0.45
const CURSOR_OFFSET := Vector2(18.0, 20.0)
const EDGE_MARGIN := 8.0
const MAX_TEXT_WIDTH := 520.0

var _source: Control
var _hover_time := 0.0
var _shown_text := ""
var _paper: Panel
var _label: Label


func _ready() -> void:
	layer = 120
	_paper = Panel.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.theme = preload("res://Scripts/mvp_theme.gd").create()
	_paper.add_theme_stylebox_override("panel", _paper.theme.get_stylebox("panel", "TooltipPanel"))
	add_child(_paper)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", _paper.theme.get_color("font_color", "TooltipLabel"))
	_paper.add_child(_label)
	_paper.hide()


func _process(delta: float) -> void:
	if not GameSettings.tooltips_enabled:
		_source = null
		_hover_time = 0.0
		_paper.hide()
		return
	var hovered := get_viewport().gui_get_hovered_control()
	var target := hovered
	var tooltip := ""
	while target != null:
		if target.is_visible_in_tree():
			tooltip = target.get_tooltip(target.get_local_mouse_position())
			if not tooltip.is_empty():
				break
		target = target.get_parent() as Control
	if target != _source:
		_source = target
		_hover_time = 0.0
		_paper.hide()
	if _source == null:
		return
	_hover_time += delta
	if _hover_time < SHOW_DELAY:
		return
	if tooltip != _shown_text:
		_shown_text = tooltip
		_layout_text(tooltip)
	_paper.show()
	_place_near_mouse()


func _layout_text(tooltip: String) -> void:
	_label.text = tooltip
	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")
	var widest := 0.0
	for line in tooltip.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var text_width := minf(widest + 2.0, MAX_TEXT_WIDTH)
	var text_height := font.get_multiline_string_size(tooltip, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size).y + 2.0
	var paper_style := _paper.get_theme_stylebox("panel")
	var left := paper_style.get_margin(SIDE_LEFT)
	var top := paper_style.get_margin(SIDE_TOP)
	_label.position = Vector2(left, top)
	_label.size = Vector2(text_width, text_height)
	_paper.size = Vector2(left + text_width + paper_style.get_margin(SIDE_RIGHT), top + text_height + paper_style.get_margin(SIDE_BOTTOM))


func _place_near_mouse() -> void:
	var mouse := get_viewport().get_mouse_position()
	var viewport_size := get_viewport().get_visible_rect().size
	var position_on_screen := mouse + CURSOR_OFFSET
	if position_on_screen.x + _paper.size.x > viewport_size.x - EDGE_MARGIN:
		position_on_screen.x = mouse.x - _paper.size.x - CURSOR_OFFSET.x
	if position_on_screen.y + _paper.size.y > viewport_size.y - EDGE_MARGIN:
		position_on_screen.y = mouse.y - _paper.size.y - CURSOR_OFFSET.y
	position_on_screen.x = clampf(position_on_screen.x, EDGE_MARGIN, maxf(EDGE_MARGIN, viewport_size.x - _paper.size.x - EDGE_MARGIN))
	position_on_screen.y = clampf(position_on_screen.y, EDGE_MARGIN, maxf(EDGE_MARGIN, viewport_size.y - _paper.size.y - EDGE_MARGIN))
	_paper.position = position_on_screen
