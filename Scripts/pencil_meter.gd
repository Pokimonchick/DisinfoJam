@tool
class_name PencilMeter
extends ProgressBar

@export var ink_color := Color("80653c"):
	set(new_color):
		ink_color = new_color
		queue_redraw()


func _ready() -> void:
	add_theme_stylebox_override("background", StyleBoxEmpty.new())
	add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	value_changed.connect(func(_new_value: float): queue_redraw())
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var length := maxf(size.x - 2.0, 0.0)
	var middle := size.y * 0.5
	if length < 2.0:
		return
	_stroke(length, middle - 2.0, Color("ad9770", 0.55), 2.0, 0.5)
	_stroke(length, middle + 3.0, Color("ad9770", 0.32), 1.0, 2.2)
	var fraction := clampf((value - min_value) / maxf(max_value - min_value, 1.0), 0.0, 1.0)
	var filled := length * fraction
	if filled < 2.0:
		return
	var shade := ink_color
	shade.a = 0.32
	_stroke(filled, middle, shade, 11.0, 0.8)
	shade.a = 0.78
	_stroke(filled, middle - 0.5, shade, 6.0, 1.6)
	shade.a = 0.52
	_stroke(filled, middle - 3.0, shade, 1.0, 3.1)
	_stroke(filled, middle + 3.5, shade, 1.0, 4.4)
	for index in range(int(filled / 9.0)):
		var x := float(index) * 9.0 + 4.0
		var y := middle + sin(x * 0.73) * 3.0
		draw_line(Vector2(x, y), Vector2(minf(x + 2.5, filled), y + 0.5), Color(1.0, 0.94, 0.78, 0.25), 1.0)


func _stroke(length: float, y: float, color: Color, thickness: float, phase: float) -> void:
	var points := PackedVector2Array()
	var x := 0.0
	while x < length:
		points.append(Vector2(x, y + sin(x * 0.12 + phase) * 0.65 + sin(x * 0.047 + phase * 2.0) * 0.7))
		x += 7.0
	points.append(Vector2(length, y + sin(length * 0.12 + phase) * 0.65 + sin(length * 0.047 + phase * 2.0) * 0.7))
	draw_polyline(points, color, thickness, true)
