@tool
class_name StampArea
extends Control

signal absorption_progress_changed(progress: float)
signal ink_time_changed(time: float)

@export var imprint_size := Vector2(224, 224):
	set(value):
		imprint_size = value.max(Vector2(8, 8))
		if is_node_ready():
			_configure_imprint()
@export var excluded_controls: Array[NodePath] = []
@export var imprint_angle_degrees := -2.0:
	set(value):
		imprint_angle_degrees = value
		if is_node_ready():
			_configure_imprint()
@export_range(0.0, 3.0, 0.05) var absorption_seconds := 0.8

var printed := false
var ink_time := 0.0
var _ready_to_print := false
var _absorption: Tween

@onready var preview: Control = $Preview
@onready var imprint: Control = $Imprint
@onready var _ink_material: ShaderMaterial = imprint.material as ShaderMaterial

func _ready() -> void:
	_configure_imprint()
	reset()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Shader TIME keeps running while paused; this clock follows the desk.
	ink_time += delta
	_ink_material.set_shader_parameter("ink_time", ink_time)
	ink_time_changed.emit(ink_time)

func _configure_imprint() -> void:
	for seal in [preview, imprint]:
		var centre: Vector2 = seal.position + seal.size * 0.5
		seal.size = imprint_size
		seal.pivot_offset = imprint_size * 0.5
		seal.position = centre - imprint_size * 0.5
		seal.rotation = deg_to_rad(imprint_angle_degrees)
		seal.queue_redraw()
	if preview.visible:
		preview.visible = can_stamp(get_global_transform_with_canvas() * (preview.position + imprint_size * 0.5))
	queue_redraw()

func set_available(value: bool) -> void:
	if _ready_to_print == value:
		return
	_ready_to_print = value
	if not value:
		preview.hide()
	queue_redraw()

func can_stamp(viewport_point: Vector2) -> bool:
	if printed or not _ready_to_print or not is_visible_in_tree():
		return false
	var local := get_global_transform_with_canvas().affine_inverse() * viewport_point
	# Check every rotated corner, not just the cursor or the centre of the seal.
	var seal := Transform2D(deg_to_rad(imprint_angle_degrees), local)
	var footprint := PackedVector2Array()
	for corner in [Vector2.ZERO, Vector2(imprint_size.x, 0), imprint_size, Vector2(0, imprint_size.y)]:
		var point: Vector2 = seal * (corner - imprint_size * 0.5)
		if not Rect2(Vector2.ZERO, size).has_point(point):
			return false
		footprint.append(get_global_transform_with_canvas() * point)
	for path in excluded_controls:
		var control := get_node_or_null(path) as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var obstacle := PackedVector2Array()
		for corner in [Vector2.ZERO, Vector2(control.size.x, 0), control.size, Vector2(0, control.size.y)]:
			obstacle.append(control.get_global_transform_with_canvas() * corner)
		if not Geometry2D.intersect_polygons(footprint, obstacle).is_empty():
			return false
	return true

func show_preview(viewport_point: Vector2) -> void:
	var was_visible := preview.visible
	preview.visible = can_stamp(viewport_point)
	if preview.visible:
		_place(preview, viewport_point)
	if was_visible != preview.visible:
		queue_redraw()

func commit(viewport_point: Vector2) -> bool:
	if not can_stamp(viewport_point):
		return false
	_stop_absorption()
	_set_absorption(0.0)
	_place(imprint, viewport_point)
	imprint.show()
	printed = true
	preview.hide()
	queue_redraw()
	return true

func reset(absorb_ink := false) -> void:
	var should_absorb := absorb_ink and printed and imprint.visible and absorption_seconds > 0.0
	_stop_absorption()
	printed = false
	preview.hide()
	_set_absorption(0.0)
	if should_absorb:
		# Bound to this node so the interface lock also pauses the ink.
		_absorption = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_absorption.tween_method(_set_absorption, 0.0, 1.0, absorption_seconds)
		_absorption.tween_callback(func():
			imprint.hide()
			_absorption = null
		)
	else:
		imprint.hide()
	queue_redraw()

func restore_result() -> void:
	# Old and current saves retain publication data, not transient drag positions.
	_stop_absorption()
	_set_absorption(0.0)
	imprint.position = (size - imprint_size) * 0.5
	imprint.show()
	printed = true
	preview.hide()
	queue_redraw()

func _stop_absorption() -> void:
	if _absorption and _absorption.is_valid():
		_absorption.kill()
	_absorption = null

func _set_absorption(progress: float) -> void:
	_ink_material.set_shader_parameter("absorption_progress", progress)
	absorption_progress_changed.emit(progress)

func _place(seal: Control, viewport_point: Vector2) -> void:
	seal.pivot_offset = imprint_size * 0.5
	seal.position = get_global_transform_with_canvas().affine_inverse() * viewport_point - imprint_size * 0.5

func _draw() -> void:
	if not _ready_to_print or printed:
		return
	var color := Color("48623a", 0.5) if preview.visible else Color("806542", 0.18)
	for corner in [Vector2(8, 8), Vector2(size.x - 8, 8), Vector2(8, size.y - 8), size - Vector2(8, 8)]:
		var direction := Vector2(1 if corner.x < size.x * 0.5 else -1, 1 if corner.y < size.y * 0.5 else -1)
		draw_line(corner, corner + Vector2(direction.x * 16, 0), color, 1.0, true)
		draw_line(corner, corner + Vector2(0, direction.y * 10), color, 1.0, true)
