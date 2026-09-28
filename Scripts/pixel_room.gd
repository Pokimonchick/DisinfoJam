@tool
extends Control

# Interaction marks sit above the replaceable room art; no furniture is drawn here.
var hovered := "":
	set(value):
		hovered = value
		queue_redraw()
var food_stocked := false:
	set(value):
		food_stocked = value
		queue_redraw()
var coffee_packed := false
var sleeping := false:
	set(value):
		sleeping = value
		queue_redraw()
var tired := false
var _clock := 0.0

const GOLD := Color("f3c777")
const AREAS := {
	"bed": Rect2(55, 350, 475, 465),
	"coffee": Rect2(1240, 405, 130, 160),
	"snack": Rect2(1350, 380, 125, 125),
	"fridge": Rect2(1610, 300, 165, 490),
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_clock += delta
		queue_redraw()


func _draw() -> void:
	if sleeping:
		_draw_sleep_marks()
		return
	if hovered == "":
		var pulse := 0.48 + 0.2 * sin(_clock * 2.2)
		_draw_corners(AREAS.bed, Color(GOLD, pulse), 22.0, 5.0)
		_draw_bed_glint(Color(GOLD, pulse))
	else:
		var area: Rect2 = AREAS.get(hovered, Rect2())
		if area.has_area():
			_draw_corners(area, GOLD, 23.0, 5.0)
	if food_stocked:
		draw_rect(Rect2(1717, 461, 5, 5), Color(GOLD, 0.7))


func _draw_corners(area: Rect2, color: Color, length: float, width: float) -> void:
	var x := area.position.x
	var y := area.position.y
	var right := area.end.x
	var bottom := area.end.y
	for corner in [Vector2(x, y), Vector2(right - length, y), Vector2(x, bottom), Vector2(right - length, bottom)]:
		draw_rect(Rect2(corner, Vector2(length, width)), color)
	for corner in [Vector2(x, y), Vector2(right - width, y), Vector2(x, bottom - length), Vector2(right - width, bottom - length)]:
		draw_rect(Rect2(corner, Vector2(width, length)), color)


func _draw_bed_glint(color: Color) -> void:
	draw_rect(Rect2(297, 370, 5, 28), color)
	draw_rect(Rect2(285, 382, 29, 5), color)
	draw_rect(Rect2(293, 378, 13, 13), color)


func _draw_sleep_marks() -> void:
	var drift := int(_clock * 2.0) % 3
	for i in range(3):
		var x := 300.0 + i * 27.0 + drift * 5.0
		var y := 395.0 - i * 29.0 - drift * 8.0
		draw_rect(Rect2(x, y, 15, 4), GOLD)
		draw_rect(Rect2(x + 11, y + 3, 4, 9), GOLD)
		draw_rect(Rect2(x, y + 12, 15, 4), GOLD)
