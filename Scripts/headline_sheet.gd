extends Button

var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE
var _base_z_index := 0
var _hover_tween: Tween
@onready var _selected_note: TextureRect = $SelectedNote
@onready var _shadow: TextureRect = $Shadow
@onready var _selected_shadow: TextureRect = $SelectedShadow

func _ready() -> void:
	pivot_offset = size / 2.0
	_base_position = position
	_base_scale = scale
	_base_z_index = z_index
	_selected_note.modulate.a = 0.0
	_selected_shadow.modulate.a = 0.0
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	visibility_changed.connect(_on_visibility_changed)
	var clear_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, clear_style)
	add_theme_color_override("font_color", Color("182b30"))
	get_node("Content/Headline").add_theme_color_override("font_color", Color("182b30"))
	get_node("Content/Hint").add_theme_color_override("font_color", Color("6e583c"))

func _set_hovered(value: bool) -> void:
	if disabled:
		return
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if value:
		z_index = 12
		_selected_note.show()
		_selected_shadow.show()
		_hover_tween.parallel().tween_property(_selected_note, "modulate:a", 1.0, 0.14)
		_hover_tween.parallel().tween_property(_selected_shadow, "modulate:a", 1.0, 0.14)
		_hover_tween.parallel().tween_property(_shadow, "modulate:a", 0.0, 0.14)
		_hover_tween.parallel().tween_property(self, "position", _base_position + Vector2(0.0, -18.0), 0.14)
		_hover_tween.parallel().tween_property(self, "scale", _base_scale * 1.045, 0.14)
	else:
		_hover_tween.parallel().tween_property(_selected_note, "modulate:a", 0.0, 0.16)
		_hover_tween.parallel().tween_property(_selected_shadow, "modulate:a", 0.0, 0.16)
		_hover_tween.parallel().tween_property(_shadow, "modulate:a", 1.0, 0.16)
		_hover_tween.parallel().tween_property(self, "position", _base_position, 0.16)
		_hover_tween.parallel().tween_property(self, "scale", _base_scale, 0.16)
		_hover_tween.tween_callback(func():
			_selected_note.hide()
			_selected_shadow.hide()
			z_index = _base_z_index
		)

func _on_visibility_changed() -> void:
	if not visible:
		reset_hover()

func reset_hover() -> void:
	if _hover_tween:
		_hover_tween.kill()
	_selected_note.hide()
	_selected_note.modulate.a = 0.0
	_selected_shadow.hide()
	_selected_shadow.modulate.a = 0.0
	_shadow.modulate.a = 1.0
	position = _base_position
	scale = _base_scale
	z_index = _base_z_index
