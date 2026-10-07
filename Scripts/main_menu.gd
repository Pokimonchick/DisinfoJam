@tool
extends Control

## Keep the menu composition editable in one reference coordinate system.
@export var design_size := Vector2(1920, 1080)

func _ready() -> void:
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	var factor := minf(size.x / design_size.x, size.y / design_size.y)
	$Canvas.size = design_size
	$Canvas.scale = Vector2.ONE * factor
	$Canvas.position = (size - design_size * factor) * 0.5
