class_name DeskFocus
extends PanelContainer

signal primary_pressed
signal secondary_pressed
signal close_pressed

const ZOOM_TIME := 0.26

var active := false
var _origin: Control
var _motion: Tween
var _opening := false
var _version := 0

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
	_opening = false
	size = target_size
	pivot_offset = target_size / 2.0
	position = origin.position + (origin.size - target_size) / 2.0
	scale = Vector2.ONE * (origin.size.x / target_size.x) * origin.scale.x
	rotation = origin.rotation
	modulate.a = 1.0
	$Margin.modulate.a = 0.0
	_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, "position", (get_parent().size - target_size) / 2.0, ZOOM_TIME)
	_motion.tween_property(self, "scale", Vector2.ONE, ZOOM_TIME)
	_motion.tween_property(self, "rotation", -0.015, ZOOM_TIME)
	_motion.tween_property($Margin, "modulate:a", 1.0, ZOOM_TIME * 0.75).set_delay(ZOOM_TIME * 0.25)

func close(after_close: Callable = Callable()) -> void:
	if not active:
		return
	active = false
	_version += 1
	if _opening:
		_opening = false
		if is_instance_valid(_origin):
			_origin.show()
		_origin = null
		hide()
		if after_close.is_valid():
			after_close.call()
		return
	if _motion and _motion.is_valid():
		_motion.kill()
	_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_motion.tween_property(self, "position", _origin.position + (_origin.size - size) / 2.0, ZOOM_TIME * 0.75)
	_motion.tween_property(self, "scale", Vector2.ONE * (_origin.size.x / size.x) * _origin.scale.x, ZOOM_TIME * 0.75)
	_motion.tween_property(self, "rotation", _origin.rotation, ZOOM_TIME * 0.75)
	_motion.tween_property($Margin, "modulate:a", 0.0, ZOOM_TIME * 0.5)
	_motion.chain().tween_callback(func():
		if is_instance_valid(_origin):
			_origin.show()
		_origin = null
		hide()
		if after_close.is_valid():
			after_close.call()
	)

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
