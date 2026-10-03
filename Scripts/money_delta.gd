extends Control

var _labels: Array[Label] = []
var _tweens: Array[Tween] = []

func play(amount: int, anchor_rect: Rect2) -> void:
	if amount == 0:
		return
	var label := Label.new()
	label.text = "%s%d $" % ["−" if amount < 0 else "+", absi(amount)]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", preload("res://Assets/Fonts/Neucha/Neucha.ttf"))
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("ff8b73") if amount < 0 else Color("95c997"))
	label.add_theme_color_override("font_outline_color", Color("30231d"))
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	var origin := anchor_rect.position + Vector2(4, anchor_rect.size.y + 2)
	origin.x = clampf(origin.x, 12, maxf(12, size.x - label.get_minimum_size().x - 12))
	origin.y += _labels.size() * 30
	label.position = origin
	_labels.append(label)
	var tween := create_tween()
	_tweens.append(tween)
	tween.tween_interval(1.1)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", origin.y - 24, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(func():
		_tweens.erase(tween)
		_labels.erase(label)
		label.queue_free()
	)

func clear() -> void:
	for tween in _tweens:
		tween.kill()
	_tweens.clear()
	for label in _labels:
		label.queue_free()
	_labels.clear()
