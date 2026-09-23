class_name DeskSurface
extends Control

@export var wood_color := Color("573b2c")
@export var edge_color := Color("241b1a")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var top_edge := 38.0
	var inset := minf(56.0, size.x * 0.08)
	var plane := PackedVector2Array([
		Vector2(inset, top_edge),
		Vector2(size.x - inset, top_edge),
		Vector2(size.x - 16.0, size.y - 18.0),
		Vector2(16.0, size.y - 18.0),
	])
	draw_colored_polygon(plane, wood_color)
	draw_polyline(plane + PackedVector2Array([plane[0]]), edge_color, 7.0, true)
	draw_line(Vector2(inset, top_edge + 20.0), Vector2(size.x - inset, top_edge + 20.0), Color("8c6244"), 2.0)
	for y in [140.0, 280.0, 450.0]:
		var grain := PackedVector2Array([
			Vector2(46.0, y), Vector2(size.x * 0.25, y - 8.0),
			Vector2(size.x * 0.52, y + 10.0), Vector2(size.x - 48.0, y - 5.0)
		])
		draw_polyline(grain, Color("704a35", 0.55), 3.0, true)
	var desk_light := Rect2(size.x * 0.31, 70.0, size.x * 0.42, size.y - 118.0)
	draw_rect(desk_light, Color("c9975a", 0.08), true)
