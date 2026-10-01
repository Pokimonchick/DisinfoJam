extends Control

signal activated
var available := false
var _motion: Tween
var _liquid_time := 0.0
@onready var _liquid_material: ShaderMaterial = $Cup/Swirl.material as ShaderMaterial

func _ready() -> void:
	$Cup.pivot_offset = $Cup.size * 0.5
	$Cup.pressed.connect(func():
		if available:
			activated.emit()
	)
	# Editor layout shows the cup; the bound session supplies gameplay inventory.
	$Cup.hide()
	set_available(false, false)

func _process(delta: float) -> void:
	if not available or not is_visible_in_tree():
		return
	# Inherited process mode freezes the surface when the desk is paused.
	_liquid_time += delta
	_liquid_material.set_shader_parameter("animation_time", _liquid_time)

func set_available(value: bool, animate := true) -> void:
	$Cup.disabled = not value
	if value == available:
		return
	available = value
	if _motion:
		_motion.kill()
	$Cup/Steam.visible = value
	if value:
		$Cup.show()
		$Cup.modulate.a = 1.0
		$Cup.scale = Vector2.ONE
		$Cup/Steam.play("default")
	elif animate:
		_motion = create_tween().set_parallel(true)
		_motion.tween_property($Cup, "modulate:a", 0.0, 0.25)
		_motion.tween_property($Cup, "scale", Vector2.ONE * 0.85, 0.25)
		_motion.chain().tween_callback($Cup.hide)
	else:
		$Cup.hide()

func set_hint(text: String) -> void:
	$Cup.tooltip_text = text
