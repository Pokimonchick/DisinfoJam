extends Button

var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE
var _base_z_index := 0
var _hover_tween: Tween
@onready var _headline: Label = $Content/Headline
@onready var _pencil_mark: Node2D = $PencilMark

func _ready() -> void:
	pivot_offset = size / 2.0
	_base_position = position
	_base_scale = scale
	_base_z_index = z_index
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	button_down.connect(_pencil_mark.clear)
	visibility_changed.connect(_on_visibility_changed)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f2e7c8")
	paper.set_corner_radius_all(5)
	paper.border_color = Color("b69a72")
	paper.set_border_width_all(2)
	paper.set_content_margin_all(22)
	var hover := paper.duplicate() as StyleBoxFlat
	hover.bg_color = Color("fff2cf")
	hover.border_color = Color("e8bd68")
	hover.set_border_width_all(4)
	add_theme_stylebox_override("normal", paper)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_color_override("font_color", Color("182b30"))
	get_node("Content/Headline").add_theme_color_override("font_color", Color("182b30"))
	get_node("Content/Hint").add_theme_color_override("font_color", Color("6e583c"))

func _set_hovered(value: bool) -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if value:
		z_index = 12
		#_pencil_mark.trace(_headline)
		_hover_tween.parallel().tween_property(self, "position", _base_position + Vector2(0.0, -18.0), 0.14)
		_hover_tween.parallel().tween_property(self, "scale", _base_scale * 1.045, 0.14)
	else:
		_pencil_mark.clear()
		_hover_tween.parallel().tween_property(self, "position", _base_position, 0.16)
		_hover_tween.parallel().tween_property(self, "scale", _base_scale, 0.16)
		_hover_tween.tween_callback(func(): z_index = _base_z_index)

func _on_visibility_changed() -> void:
	if not visible:
		_pencil_mark.clear()
