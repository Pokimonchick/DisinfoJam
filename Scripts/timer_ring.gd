extends Control

var progress: float = 1.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

var urgent: bool = false:
	set(value):
		urgent = value
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 5.0
	var start := -PI * 0.5
	draw_arc(center, radius, start, start + TAU, 96, Color("77716a"), 6.0, true)
	if progress > 0.0:
		var color := Color("e85b57") if urgent else Color("f6e6c4")
		draw_arc(center, radius, start, start + TAU * progress, maxi(2, ceili(96.0 * progress)), color, 6.0, true)
