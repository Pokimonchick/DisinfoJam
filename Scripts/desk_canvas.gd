@tool
extends Control

## All desk art shares one coordinate system; fixed HUD controls stay outside World.
@export var design_size := Vector2(1920, 1080)
@export var parallax_travel := Vector2(60, 40)
@export_range(1.0, 15.0) var parallax_response := 4.0
var motion_enabled := true

func _ready() -> void:
	get_parent().resized.connect(_fit)
	_fit()

func _fit() -> void:
	var available: Vector2 = get_parent().size
	var factor := minf(available.x / design_size.x, available.y / design_size.y)
	size = design_size
	scale = Vector2.ONE * factor
	position = (available - design_size * factor) * 0.5

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree() or not motion_enabled:
		return
	var normalized := get_local_mouse_position() / design_size * 2.0 - Vector2.ONE
	normalized = normalized.clamp(-Vector2.ONE, Vector2.ONE)
	$World.position = $World.position.lerp(-normalized * parallax_travel, 1.0 - exp(-parallax_response * delta))
