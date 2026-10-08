class_name DeskFocus
extends PanelContainer

signal primary_pressed
signal secondary_pressed
signal close_pressed

@export_range(0.2, 2.0, 0.05) var opening_seconds := 0.7
@export_range(0.2, 2.0, 0.05) var closing_seconds := 0.45

var active := false
var _origin: Control
var _motion: Tween
var _opening := false
var _version := 0
var _target_size := Vector2.ZERO

@onready var body_label: RichTextLabel = %Body
@onready var primary_button: Button = %Primary
@onready var secondary_button: Button = %Secondary

func _ready() -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f2e7c8")
	paper.border_color = Color("b69a72")
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(5)
	paper.shadow_color = Color("1b1513", 0.45)
	paper.shadow_size = 16
	add_theme_stylebox_override("panel", paper)
	primary_button.pressed.connect(func(): primary_pressed.emit())
	secondary_button.pressed.connect(func(): secondary_pressed.emit())
	%Close.pressed.connect(func(): close_pressed.emit())

func present(origin: Control, tag: String, title: String, body: String, primary: String, secondary: String = "", preferred_size: Vector2 = Vector2(760, 400)) -> void:
	_version += 1
	var version := _version
	if _motion and _motion.is_valid():
		_motion.kill()
	if is_instance_valid(_origin):
		_origin.show()
	_origin = origin
	%Tag.text = tag
	%Title.text = title
	body_label.text = body
	body_label.scroll_to_line(0)
	primary_button.text = primary
	secondary_button.text = secondary
	secondary_button.visible = not secondary.is_empty()
	var available_size: Vector2 = (get_parent() as Control).size - Vector2(32.0, 24.0)
	var zoom: float = minf(minf(preferred_size.x / origin.size.x, preferred_size.y / origin.size.y), minf(available_size.x / origin.size.x, available_size.y / origin.size.y))
	var target_size: Vector2 = origin.size * zoom
	_target_size = target_size
	_origin.hide()
	active = true
	_opening = true
	modulate.a = 0.0
	show()
	# Let wrapped text recalculate its minimum size at the new width before
	# exposing the paper; otherwise the first opening can grow off-screen.
	size = target_size
	await get_tree().process_frame
	if version != _version or not active:
		return
	size = target_size
	pivot_offset = target_size / 2.0
	var origin_transform := _origin_transform()
	position = origin_transform * (origin.size * 0.5) - target_size * 0.5
	scale = Vector2.ONE * (origin.size.x / target_size.x) * origin_transform.get_scale().x
	rotation = origin_transform.get_rotation()
	modulate.a = 1.0
	$Margin.modulate.a = 0.0
	_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(self, "position", (get_parent().size - target_size) / 2.0, opening_seconds)
	_motion.tween_property(self, "scale", Vector2.ONE, opening_seconds)
	_motion.tween_property(self, "rotation", -0.015, opening_seconds)
	_motion.tween_property($Margin, "modulate:a", 1.0, opening_seconds * 0.75).set_delay(opening_seconds * 0.25)
	_motion.chain().tween_callback(func():
		if version == _version:
			_opening = false
			_motion = null
	)

func is_opening() -> bool:
	return active and _opening

func finish_opening() -> bool:
	if not is_opening():
		return false
	# Consume this press even during the initial text-layout frame.
	_version += 1
	if _motion and _motion.is_valid():
		_motion.kill()
	_motion = null
	_opening = false
	size = _target_size
	pivot_offset = size * 0.5
	position = ((get_parent() as Control).size - size) * 0.5
	scale = Vector2.ONE
	rotation = -0.015
	modulate.a = 1.0
	$Margin.modulate.a = 1.0
	return true

func close(after_close: Callable = Callable()) -> void:
	if not active:
		return
	active = false
	_version += 1
	if _motion and _motion.is_valid():
		_motion.kill()
	_motion = null
	if _opening:
		_opening = false
		if is_instance_valid(_origin):
			_origin.show()
		_origin = null
		hide()
		if after_close.is_valid():
			after_close.call()
		return
	_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var origin_transform := _origin_transform()
	_motion.tween_property(self, "position", origin_transform * (_origin.size * 0.5) - size * 0.5, closing_seconds)
	_motion.tween_property(self, "scale", Vector2.ONE * (_origin.size.x / size.x) * origin_transform.get_scale().x, closing_seconds)
	_motion.tween_property(self, "rotation", origin_transform.get_rotation(), closing_seconds)
	_motion.tween_property(self, "modulate:a", 0.0, closing_seconds)
	_motion.tween_property($Margin, "modulate:a", 0.0, closing_seconds * 0.75)
	_motion.chain().tween_callback(func():
		if is_instance_valid(_origin):
			_origin.show()
		_origin = null
		hide()
		if after_close.is_valid():
			after_close.call()
	)

func _origin_transform() -> Transform2D:
	# Cards may live under a moving/scaled desk layer, not beside the focus.
	return (get_parent() as Control).get_global_transform().affine_inverse() * _origin.get_global_transform()

func reset() -> void:
	_version += 1
	if _motion and _motion.is_valid():
		_motion.kill()
	if is_instance_valid(_origin):
		_origin.show()
	_origin = null
	active = false
	_opening = false
	hide()
