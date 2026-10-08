@tool
extends PanelContainer

## A cut-paper frame; child layout and input stay with native containers.
@export var paper_color := Color("f4e6bf"):
	set(value):
		paper_color = value
		queue_redraw()
@export var backing_color := Color("a53e35"):
	set(value):
		backing_color = value
		queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 64.0 or size.y < 64.0:
		return
	var w := size.x
	var h := size.y
	var edge := PackedVector2Array([
		Vector2(0, 8), Vector2(w - 22, 0), Vector2(w, 16),
		Vector2(w - 5, h - 20), Vector2(w - 24, h),
		Vector2(12, h - 3), Vector2(0, h - 20)])
	draw_set_transform(Vector2(7, 12))
	draw_colored_polygon(edge, Color(0.02, 0.03, 0.03, 0.4))
	draw_set_transform(Vector2(-7, 7))
	draw_colored_polygon(edge, backing_color)
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(edge, paper_color)
	var outline := edge.duplicate()
	outline.append(edge[0])
	draw_polyline(outline, Color("273533"), 2.0, true)
	# Sparse printed dots and a footer rule keep the text area quiet.
	for row in range(4):
		for column in range(8):
			draw_circle(Vector2(w - 32 - column * 7, 17 + row * 7), 1.0, Color(0.2, 0.17, 0.12, 0.08))
	draw_line(Vector2(32, h - 17), Vector2(w - 36, h - 22), Color(0.2, 0.17, 0.12, 0.16), 1.0, true)
