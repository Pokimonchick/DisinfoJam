@tool
extends Button

const NORMAL = preload("res://Assets/UI/finish_shift_normal.png")
const HOVER = preload("res://Assets/UI/finish_shift_hover.png")
const Fonts = preload("res://Scripts/game_fonts.gd")

func _ready() -> void:
	add_theme_font_override("font", Fonts.HEADING)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var paper := StyleBoxTexture.new()
		paper.texture = HOVER if state in ["hover", "pressed"] else NORMAL
		paper.content_margin_left = 10.0
		paper.content_margin_right = 30.0
		paper.content_margin_top = 6.0
		paper.content_margin_bottom = 6.0
		if state == "pressed":
			paper.modulate_color = Color(0.92, 0.92, 0.92)
		elif state == "disabled":
			paper.modulate_color = Color(0.75, 0.75, 0.75)
		add_theme_stylebox_override(state, paper)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(state, Color("35291f"))
