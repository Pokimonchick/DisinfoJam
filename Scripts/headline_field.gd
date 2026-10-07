extends TextureButton

var _hover: Tween

func _ready() -> void:
	pivot_offset = size * 0.5
	mouse_entered.connect(_highlight.bind(true))
	mouse_exited.connect(_highlight.bind(false))

func set_headline(value: String) -> void:
	$Text.text = value if not value.is_empty() else "Выбрать заголовок…"
	var font: Font = $Text.get_theme_font("font")
	var font_size := 32
	while font_size > 22 and font.get_multiline_string_size($Text.text, HORIZONTAL_ALIGNMENT_LEFT, $Text.size.x, font_size).y > 112.0:
		font_size -= 2
	$Text.add_theme_font_size_override("font_size", font_size)
	$Replace.visible = not value.is_empty()
	$Pencil.visible = value.is_empty()
	tooltip_text = "Заменить заголовок" if not value.is_empty() else "Посмотреть варианты заголовка"

func _highlight(hovered: bool) -> void:
	if _hover:
		_hover.kill()
	_hover = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover.tween_property(self, "scale", Vector2.ONE * (1.015 if hovered and not disabled else 1.0), 0.16)
	_hover.tween_property(self, "self_modulate", Color(1.15, 1.15, 1.08) if hovered and not disabled else Color.WHITE, 0.16)
