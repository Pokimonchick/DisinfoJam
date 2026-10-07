@tool
class_name DeskStamp
extends Control

signal stamped
signal interaction_changed

@export_group("Model and light")
@export var model_scene: PackedScene:
	set(value):
		model_scene = value
		if is_node_ready():
			_replace_model()
@export var light_direction_degrees := Vector3(-48, 135, 0):
	set(value):
		light_direction_degrees = value
		if is_node_ready():
			$Render/Sun.rotation_degrees = value
			_wake_render()
@export_range(0.1, 3.0, 0.05) var light_energy := 1.0:
	set(value):
		light_energy = value
		if is_node_ready():
			$Render/Sun.light_energy = value
			_wake_render()
@export_group("Perspective")
@export_range(3.0, 8.0, 0.1) var camera_height := 4.5:
	set(value):
		camera_height = value
		if is_node_ready():
			_refresh_perspective()
@export_range(20.0, 55.0, 0.5) var field_of_view := 32.0:
	set(value):
		field_of_view = value
		if is_node_ready():
			_refresh_perspective()
@export_range(0.0, 3.0, 0.05) var perspective_strength := 1.4:
	set(value):
		perspective_strength = value
		if is_node_ready():
			_refresh_perspective()
@export var perspective_center := Vector2(0.58, 0.48):
	set(value):
		perspective_center = value
		if is_node_ready():
			_refresh_perspective()
@export_group("Interaction")
@export_node_path("StampArea") var stamp_area_path: NodePath
@export var grab_rect := Rect2(38, 38, 212, 224)
@export_range(0.05, 0.5, 0.01) var lift_height := 0.27
@export var lift_tilt_degrees := Vector3(-10, 0, 8)
@export_range(0.06, 0.4, 0.01) var strike_seconds := 0.14
@export_range(0.1, 0.8, 0.01) var return_seconds := 0.32
@export_group("Shadow")
@export_range(0.0, 1.0, 0.01) var shadow_strength := 0.28:
	set(value):
		shadow_strength = value
		if is_node_ready():
			_shadow.material.set_shader_parameter("shadow_strength", value)
@export var shadow_offset := Vector2(-8, 5):
	set(value):
		shadow_offset = value
		if is_node_ready():
			_set_lift(_lift)
@export_group("Audio")
@export var impact_sound: AudioStream
@export_range(-40.0, 6.0, 0.5) var impact_volume_db := -8.0

var enabled := false
var dragging := false
var busy := false
var _impact_done := false
var _rest_position := Vector2.ZERO
var _rest_contact := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _motion: Tween
var _lift := 0.0
var _fallback_sound: AudioStreamWAV
var _area: StampArea

@onready var _render: SubViewport = $Render
@onready var _camera: Camera3D = $Render/Camera
@onready var _model_root: Node3D = $Render/ModelRoot
@onready var _shadow: TextureRect = $Shadow

func _ready() -> void:
	_rest_position = position
	_update_perspective(position + get_transform().basis_xform(size * 0.5))
	_rest_contact = _parent_contact()
	$Render/Sun.rotation_degrees = light_direction_degrees
	$Render/Sun.light_energy = light_energy
	_shadow.material.set_shader_parameter("shadow_strength", shadow_strength)
	_replace_model()
	_set_lift(0)
	if not Engine.is_editor_hint():
		_area = get_node_or_null(stamp_area_path) as StampArea
		_fallback_sound = _make_impact_sound()
		get_window().focus_exited.connect(cancel_interaction)
		set_enabled(false)
	set_notify_local_transform(true)
	_wake_render()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if Engine.is_editor_hint():
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			_update_perspective(position + get_transform().basis_xform(size * 0.5))
			_set_lift(_lift)
			_wake_render()
		return
	if what == NOTIFICATION_DISABLED:
		cancel_interaction()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():
			cancel_interaction()
		_render.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _has_point(point: Vector2) -> bool:
	# Ignore the transparent corners around the round base.
	var normalized := (point - grab_rect.get_center()) / (grab_rect.size * 0.5)
	return normalized.length_squared() <= 1.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if begin_drag(event.global_position):
			accept_event()

func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseMotion:
		move_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		finish_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_interaction()
		get_viewport().set_input_as_handled()

func set_enabled(value: bool) -> void:
	enabled = value
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
	tooltip_text = "Зажми штамп и перенеси его на текст статьи или свободное место под ним. Отпусти для печати." if value and not dragging and not busy else ""
	if not value and (dragging or (busy and not _impact_done)):
		cancel_interaction()

func begin_drag(viewport_point: Vector2) -> bool:
	if not enabled or busy or dragging or not can_process() or not is_visible_in_tree() or not is_instance_valid(_area):
		return false
	if _motion and _motion.is_valid():
		_motion.kill()
	dragging = true
	_impact_done = false
	_grab_offset = _parent_point(viewport_point) - _parent_contact()
	_render.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_motion = create_tween().set_parallel(true)
	_motion.tween_method(_set_lift, _lift, lift_height, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_model_root, "rotation_degrees", lift_tilt_degrees, 0.16)
	_area.show_preview(contact_position())
	interaction_changed.emit()
	return true

func move_drag(viewport_point: Vector2) -> void:
	if not dragging:
		return
	var target := _parent_point(viewport_point) - _grab_offset
	var margin := Vector2(90, 90) * scale
	_place_contact(target.clamp(margin, _desk_size() - margin))
	_area.show_preview(contact_position())

func finish_drag() -> void:
	if not dragging:
		return
	dragging = false
	if not enabled or not _area.can_stamp(contact_position()):
		_return_to_rest()
		return
	busy = true
	if _motion and _motion.is_valid():
		_motion.kill()
	_motion = create_tween()
	_motion.tween_method(_set_lift, _lift, lift_height * 1.3, 0.05)
	_motion.tween_method(_set_lift, lift_height * 1.3, 0.0, strike_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion.parallel().tween_property(_model_root, "rotation_degrees", Vector3.ZERO, strike_seconds)
	_motion.tween_callback(_impact)
	_motion.tween_interval(0.1)
	_motion.tween_callback(_return_to_rest)
	interaction_changed.emit()

func contact_position() -> Vector2:
	return get_global_transform_with_canvas() * _contact_pixel()

func cancel_interaction() -> void:
	if _motion and _motion.is_valid():
		_motion.kill()
	dragging = false
	busy = false
	_impact_done = false
	position = _rest_position
	_update_perspective(position + get_transform().basis_xform(size * 0.5))
	_model_root.rotation_degrees = Vector3.ZERO
	_set_lift(0)
	if is_instance_valid(_area):
		_area.preview.hide()
	_render.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	interaction_changed.emit()

func _impact() -> void:
	if not enabled or not can_process() or not _area.commit(contact_position()):
		return
	_impact_done = true
	get_node("/root/AudioManager").play_sfx(impact_sound if impact_sound != null else _fallback_sound, impact_volume_db)
	stamped.emit()

func _return_to_rest() -> void:
	if _motion and _motion.is_valid():
		_motion.kill()
	dragging = false
	busy = true
	_area.preview.hide()
	_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_method(_place_contact, _parent_contact(), _rest_contact, return_seconds)
	_motion.tween_method(_set_lift, _lift, 0.0, return_seconds)
	_motion.tween_property(_model_root, "rotation_degrees", Vector3.ZERO, return_seconds)
	_motion.chain().tween_callback(func():
		position = _rest_position
		_update_perspective(position + get_transform().basis_xform(size * 0.5))
		_set_lift(0)
		busy = false
		_impact_done = false
		_render.render_target_update_mode = SubViewport.UPDATE_ONCE
		interaction_changed.emit()
	)
	interaction_changed.emit()

func _parent_point(viewport_point: Vector2) -> Vector2:
	return (get_parent() as Control).get_global_transform_with_canvas().affine_inverse() * viewport_point

func _parent_contact() -> Vector2:
	return position + get_transform().basis_xform(_contact_pixel())

func _desk_size() -> Vector2:
	var world := get_parent() as Control
	return world.size if world != null and world.size.x > 0 and world.size.y > 0 else Vector2(1920, 1080)

func _place_contact(target: Vector2) -> void:
	# Changing the camera must not move the base away from the cursor's drop point.
	_update_perspective(target)
	position = target - get_transform().basis_xform(_contact_pixel())
	_set_lift(_lift)

func _update_perspective(target: Vector2) -> void:
	var relative := target / _desk_size() - perspective_center
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = field_of_view
	_camera.position = Vector3(-relative.x * perspective_strength, camera_height, -relative.y * perspective_strength + 0.15)
	_camera.look_at(Vector3(0, 0.20, 0), Vector3(0, 0, -1))

func _refresh_perspective() -> void:
	_update_perspective(position + get_transform().basis_xform(size * 0.5))
	_set_lift(_lift)
	_rest_contact = _parent_contact()
	_wake_render()

func _contact_pixel() -> Vector2:
	return _camera.unproject_position(Vector3.ZERO) * size / Vector2(_render.size)

func _set_lift(value: float) -> void:
	_lift = value
	_model_root.position.y = value
	var raised := clampf(value / lift_height, 0.0, 1.3)
	_shadow.pivot_offset = _contact_pixel()
	_shadow.scale = Vector2(1.0, 0.88) + Vector2(0.13, 0.06) * raised
	_shadow.position = shadow_offset + Vector2(-14, 9) * raised
	_shadow.modulate.a = 1.0 - raised * 0.25

func _replace_model() -> void:
	for child in _model_root.get_children():
		_model_root.remove_child(child)
		child.queue_free()
	if model_scene != null:
		_model_root.add_child(model_scene.instantiate())
	_wake_render()

func _wake_render() -> void:
	_render.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if Engine.is_editor_hint() else (SubViewport.UPDATE_ALWAYS if dragging or busy else SubViewport.UPDATE_ONCE)

func _make_impact_sound() -> AudioStreamWAV:
	# A short wooden thud until an authored stamp sound is assigned in Inspector.
	var rate := 22050
	var samples := int(rate * 0.10)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 71
	for index in samples:
		var time := float(index) / rate
		var thud := sin(TAU * 145.0 * time) * exp(-time * 65.0) * 0.45
		var click := random.randf_range(-1.0, 1.0) * exp(-time * 180.0) * 0.32
		var sample := int(clampf(thud + click, -1.0, 1.0) * 32767.0)
		bytes[index * 2] = sample & 255
		bytes[index * 2 + 1] = (sample >> 8) & 255
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound
