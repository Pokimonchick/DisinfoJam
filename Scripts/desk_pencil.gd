@tool
class_name DeskPencil
extends Control

signal picked_up
signal returned
signal interaction_changed

@export_group("Perspective")
@export_range(1.5, 16.0, 0.1) var camera_height := 12.0
@export_range(0.0, 3.0, 0.05) var camera_depth := 0.4
@export_range(12.0, 40.0, 0.5) var field_of_view := 20.0
@export_range(0.0, 2.0, 0.05) var perspective_strength := 0.5
@export var perspective_center := Vector2(0.58, 0.48)
@export_group("Interaction")
@export var grab_rect := Rect2(32, 40, 490, 50)
@export_range(0.01, 0.5, 0.01) var lift_height := 0.1
@export var lift_tilt_degrees := Vector3(8, 0, -5)
@export_enum("Pencil", "Eraser") var tool_mode := 0
@export var model_contact := Vector3(-1.985, 0.11, 0)
@export_range(4.0, 60.0, 1.0) var erase_radius := 20.0
var input_exclusions: Array[Control] = []

var enabled := false:
	set(value):
		enabled = value
		_refresh_enabled()
var interaction_enabled := true:
	set(value):
		interaction_enabled = value
		_refresh_enabled()
var held := false
var busy := false
var _surface: ProofreadingSurface
var _rest_position := Vector2.ZERO
var _rest_rotation := 0.0
var _shadow_rest_position := Vector2.ZERO
var _tip_point := Vector2.ZERO
var _motion: Tween
var _lift := 0.0
var _stroke_down := false
var _gui_drag := false

@onready var _render: SubViewport = $Render
@onready var _camera: Camera3D = $Render/Camera
@onready var _model: Node3D = $Render/ModelRoot

func _ready() -> void:
	_rest_position = position
	_rest_rotation = rotation
	_shadow_rest_position = $Shadow.position
	_update_perspective(position + size * 0.5)
	$Render/Sun.rotation_degrees = Vector3(-55, 120, 0)
	_refresh_enabled()
	if not Engine.is_editor_hint():
		get_window().focus_exited.connect(cancel_interaction)
	_render.render_target_update_mode = SubViewport.UPDATE_ONCE

func set_surface(surface: ProofreadingSurface) -> void:
	_surface = surface

func _refresh_enabled() -> void:
	if not is_node_ready():
		return
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled and interaction_enabled else Control.CURSOR_ARROW
	var hint := "Карандаш: нажми, чтобы взять; удерживай левую кнопку для пометок. Правая кнопка возвращает карандаш." if tool_mode == 0 else "Ластик: нажми, чтобы взять; удерживай левую кнопку, чтобы стирать пометки. Правая кнопка возвращает ластик."
	tooltip_text = hint if enabled and interaction_enabled and not held else ""
	if not enabled or not interaction_enabled:
		cancel_interaction()

func _notification(what: int) -> void:
	if is_node_ready() and not Engine.is_editor_hint() and (what == NOTIFICATION_DISABLED or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree())):
		cancel_interaction()

func _has_point(point: Vector2) -> bool:
	# Global input owns the held tool; its image must not obscure native GUI hits.
	return not held and grab_rect.has_point(point)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and begin_pickup(event.global_position):
		accept_event()

func begin_pickup(viewport_point: Vector2) -> bool:
	if not enabled or not interaction_enabled or held or busy or not can_process() or not is_visible_in_tree():
		return false
	held = true
	_stroke_down = false
	_gui_drag = false
	_tip_point = viewport_point
	_render.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_motion = create_tween()
	_motion.tween_method(_set_lift, 0.0, lift_height, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if tool_mode == 0 and is_instance_valid(_surface):
		_surface.drawing_enabled = true
	picked_up.emit()
	interaction_changed.emit()
	return true

func _input(event: InputEvent) -> void:
	if not held or not interaction_enabled or not can_process():
		return
	if event is InputEventMouseMotion:
		move_pencil(event.position)
		if not _gui_drag and not _over_input_exclusion(event.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_instance_valid(_surface):
				_finish_action()
			cancel_interaction()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _over_input_exclusion(event.position):
					if _stroke_down and is_instance_valid(_surface):
						_finish_action()
					_stroke_down = false
					_gui_drag = true
					return
				_stroke_down = _begin_action(event.position)
			else:
				if _gui_drag:
					_gui_drag = false
					return
				if _stroke_down and is_instance_valid(_surface):
					_extend_action(event.position)
					_finish_action()
				_stroke_down = false
			get_viewport().set_input_as_handled()
		# Other events continue to the reading controls while the pencil is held.

func _over_input_exclusion(viewport_point: Vector2) -> bool:
	for control in input_exclusions:
		if is_instance_valid(control) and control.is_visible_in_tree():
			var local_point := control.get_global_transform_with_canvas().affine_inverse() * viewport_point
			if Rect2(Vector2.ZERO, control.size).has_point(local_point):
				return true
	return false

func _begin_action(point: Vector2) -> bool:
	if not is_instance_valid(_surface):
		return false
	return _surface.begin_stroke(point) if tool_mode == 0 else _surface.begin_erasure(point, erase_radius)

func _extend_action(point: Vector2) -> void:
	if tool_mode == 0:
		_surface.extend_stroke(point)
	else:
		_surface.extend_erasure(point, erase_radius)

func _finish_action() -> void:
	if tool_mode == 0:
		_surface.finish_stroke()
	else:
		_surface.finish_erasure()

func move_pencil(viewport_point: Vector2) -> void:
	if not held:
		return
	_tip_point = viewport_point
	_place_tip()
	if _stroke_down and is_instance_valid(_surface):
		_extend_action(viewport_point)

func contact_position() -> Vector2:
	return get_global_transform_with_canvas() * _tip_pixel()

func cancel_interaction() -> void:
	if not is_node_ready():
		return
	var was_held := held
	if _motion and _motion.is_valid():
		_motion.kill()
	held = false
	busy = false
	_stroke_down = false
	_gui_drag = false
	if was_held and is_instance_valid(_surface):
		if tool_mode == 0:
			_surface.drawing_enabled = false
		else:
			_surface.finish_erasure()
	position = _rest_position
	rotation = _rest_rotation
	_model.position.y = 0
	_model.rotation_degrees = Vector3.ZERO
	_lift = 0.0
	_update_perspective(position + size * 0.5)
	$Shadow.position = _shadow_rest_position
	$Shadow.modulate.a = 1.0
	_render.render_target_update_mode = SubViewport.UPDATE_ONCE
	if was_held:
		returned.emit()
		interaction_changed.emit()

func _set_lift(value: float) -> void:
	_lift = value
	_model.position.y = value
	_model.rotation_degrees = lift_tilt_degrees * clampf(value / maxf(lift_height, 0.001), 0, 1)
	$Shadow.position = _shadow_rest_position + Vector2(-8, 8) * value / maxf(lift_height, 0.001)
	$Shadow.modulate.a = 1.0 - value * 1.5
	if held:
		_place_tip()

func _place_tip() -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var target := parent_control.get_global_transform_with_canvas().affine_inverse() * _tip_point
	_update_perspective(target)
	position = target - get_transform().basis_xform(_tip_pixel())

func _tip_pixel() -> Vector2:
	var image: TextureRect = $Image
	return image.position + _camera.unproject_position(_model.transform * model_contact) * image.size / Vector2(_render.size)

func _update_perspective(target: Vector2) -> void:
	var parent_control := get_parent() as Control
	var desk_size := parent_control.size if parent_control != null else Vector2(1920, 1080)
	var relative := target / desk_size.max(Vector2.ONE) - perspective_center
	_camera.fov = field_of_view
	_camera.position = Vector3(-relative.x * perspective_strength, camera_height, camera_depth - relative.y * perspective_strength)
	_camera.look_at(Vector3(0, 0.07, 0), Vector3(0, 0, -1))
