@tool
extends Control

@export_enum("Героиня", "Босс", "Истощение", "Пожар", "Арест", "Долги", "Документ") var kind: int = 0:
	set(value):
		kind = value
		queue_redraw()
@export var sprite: Texture2D:
	set(value):
		sprite = value
		queue_redraw()
@export var tint: Color = Color("e8bd68")
var health_ratio: float = 1.0:
	set(value):
		health_ratio = value
		queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if sprite != null:
		var draw_size := sprite.get_size() * minf(size.x / sprite.get_width(), size.y / sprite.get_height())
		draw_texture_rect(sprite, Rect2((size - draw_size) / 2.0, draw_size), false)
		return
	var unit := minf(size.x, size.y) / 260.0
	var center := Vector2(size.x / 2.0, size.y / 2.0)
	draw_circle(center, 114.0 * unit, Color("304a50"))
	if kind == 6:
		draw_rect(Rect2(center + Vector2(-83, -106) * unit, Vector2(166, 212) * unit), Color("f2e7c8"))
		for row in range(7):
			var start := center + Vector2(-60, -72 + row * 23) * unit
			draw_line(start, start + Vector2(115, 0) * unit, Color("81745e"), 3 * unit)
		var mark := center + Vector2(-60, -3) * unit
		draw_arc(mark, 14 * unit, 0.4, TAU - 0.4, 24, Color("ab4840"), 3 * unit)
		draw_line(mark + Vector2(10, 10) * unit, mark + Vector2(23, 19) * unit, Color("ab4840"), 3 * unit)
		return
	if kind == 3:
		for offset in [-45.0, 0.0, 45.0]:
			var base := center + Vector2(offset, 45.0) * unit
			draw_colored_polygon(PackedVector2Array([base + Vector2(-32, 20) * unit, base + Vector2(4, -115) * unit, base + Vector2(36, 20) * unit]), Color("e18c65"))
		return
	if kind == 5:
		draw_rect(Rect2(center + Vector2(-95, 30) * unit, Vector2(190, 55) * unit), Color("b4976f"))
	var face := center + Vector2(0, -25) * unit
	var color := tint if kind != 2 else Color("97a4a0")
	draw_colored_polygon(PackedVector2Array([center + Vector2(-64, 93) * unit, center + Vector2(0, -5) * unit, center + Vector2(64, 93) * unit]), color)
	if kind != 1 and kind != 4:
		draw_circle(face + Vector2(-38, -37) * unit, 24.0 * unit, color)
		draw_circle(face + Vector2(38, -37) * unit, 24.0 * unit, color)
	draw_circle(face, 49.0 * unit, color)
	for side in [-1, 1]:
		var eye := face + Vector2(side * 18, -4) * unit
		if kind == 2 or health_ratio < 0.3:
			draw_line(eye + Vector2(-6, 2) * unit, eye + Vector2(6, 2) * unit, Color("182b30"), 3 * unit)
		else:
			draw_circle(eye, 4.5 * unit, Color("182b30"))
	draw_circle(face + Vector2(0, 13) * unit, 5 * unit, Color("182b30"))
	if kind == 1 or kind == 4:
		draw_rect(Rect2(face + Vector2(-54, -54) * unit, Vector2(108, 28) * unit), Color("12252b"))
	if kind == 4:
		for x in range(-80, 100, 40):
			draw_line(center + Vector2(x, -110) * unit, center + Vector2(x, 110) * unit, Color("849395"), 7 * unit)
