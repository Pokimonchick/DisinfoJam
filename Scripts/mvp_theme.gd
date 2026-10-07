extends RefCounted

const INK := Color("182b30")
const PAPER := Color("eee4cc")
const GOLD := Color("e8bd68")

static func box(color: Color, radius: int = 10, padding: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style

static func create() -> Theme:
	var result := Theme.new()
	result.default_font = ThemeDB.fallback_font
	result.default_font_size = 20
	result.set_color("font_color", "Label", PAPER)
	result.set_color("default_color", "RichTextLabel", PAPER)
	result.set_stylebox("panel", "PanelContainer", box(Color("253c41")))
	result.set_stylebox("normal", "Button", box(PAPER))
	result.set_stylebox("hover", "Button", box(Color("fff1cd")))
	result.set_stylebox("pressed", "Button", box(GOLD))
	result.set_stylebox("disabled", "Button", box(Color("526166")))
	var focus := box(Color.TRANSPARENT)
	focus.border_color = GOLD
	focus.set_border_width_all(3)
	result.set_stylebox("focus", "Button", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("bdc5c2"))
	# CheckBox is a toggle button: its checked state must keep the same padding
	# as the hovered state, without looking permanently hovered.
	for state in ["normal", "pressed"]:
		result.set_stylebox(state, "CheckBox", box(PAPER))
	for state in ["hover", "hover_pressed"]:
		result.set_stylebox(state, "CheckBox", box(Color("fff1cd")))
	result.set_stylebox("focus", "CheckBox", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		result.set_color(state, "CheckBox", INK)
	result.set_constant("h_separation", "CheckBox", 10)
	result.set_stylebox("background", "ProgressBar", box(Color("15282d"), 5, 0))
	result.set_stylebox("fill", "ProgressBar", box(GOLD, 5, 0))
	result.set_stylebox("slider", "HSlider", box(Color("15282d"), 3, 3))
	result.set_stylebox("grabber_area", "HSlider", box(GOLD, 3, 3))
	result.set_stylebox("grabber_area_highlight", "HSlider", box(PAPER, 3, 3))
	var tooltip_paper := box(Color("34291f"), 5, 14)
	tooltip_paper.border_color = Color("b28a52")
	tooltip_paper.set_border_width_all(2)
	tooltip_paper.shadow_color = Color(0.08, 0.05, 0.02, 0.55)
	tooltip_paper.shadow_size = 5
	result.set_stylebox("panel", "TooltipPanel", tooltip_paper)
	result.set_color("font_color", "TooltipLabel", Color("f8e9c7"))
	return result
