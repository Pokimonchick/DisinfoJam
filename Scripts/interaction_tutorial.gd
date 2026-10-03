extends Control

signal next_requested
signal previous_requested
signal skip_requested

@export_group("Портреты")
@export var boss_portrait: Texture2D
@export var heroine_portrait: Texture2D = preload("res://Assets/Characters/Mask group (22).png")
@export_group("Оформление")
@export_range(0.0, 1.0, 0.01) var dim_opacity := 0.76
@export_range(0.0, 30.0, 1.0) var highlight_margin := 10.0

var _targets: Array[Control] = []
var _highlight := Rect2()
@onready var _panel: PanelContainer = $Paper

func _ready() -> void:
	%Next.pressed.connect(func(): next_requested.emit())
	%Back.pressed.connect(func(): previous_requested.emit())
	%Skip.pressed.connect(func(): skip_requested.emit())

func present(speaker: String, body: String, targets: Array[Control], step: int, count: int, heroine: bool, last_caption: String) -> void:
	_targets = targets
	%Speaker.text = "%s · %d / %d" % [speaker, step + 1, count]
	%Explanation.text = body
	%Back.disabled = step == 0
	%Next.text = last_caption if step == count - 1 else "Дальше"
	%Portrait.texture = heroine_portrait if heroine else boss_portrait
	%Portrait.visible = %Portrait.texture != null
	%BossPlaceholder.visible = not %Portrait.visible
	show()
	%Next.grab_focus()
	_position_paper()

func _process(_delta: float) -> void:
	if visible:
		_position_paper()

func _position_paper() -> void:
	var first := true
	var to_local := get_global_transform_with_canvas().affine_inverse()
	for target in _targets:
		if not is_instance_valid(target) or not target.is_visible_in_tree():
			continue
		var transform := to_local * target.get_global_transform_with_canvas()
		var rect := Rect2(transform * Vector2.ZERO, Vector2.ZERO)
		for corner in [Vector2(target.size.x, 0), target.size, Vector2(0, target.size.y)]:
			rect = rect.expand(transform * corner)
		_highlight = rect if first else _highlight.merge(rect)
		first = false
	_highlight = Rect2() if first else _highlight.grow(highlight_margin).intersection(Rect2(Vector2.ZERO, size))
	var width := minf(680.0, size.x - 36.0)
	_panel.size.x = width
	_panel.size.y = _panel.get_combined_minimum_size().y
	var extent := _panel.size
	var center := _highlight.get_center()
	var candidates: Array[Vector2] = [
		Vector2(_highlight.end.x + 20, center.y - extent.y / 2),
		Vector2(_highlight.position.x - extent.x - 20, center.y - extent.y / 2),
		Vector2(center.x - extent.x / 2, _highlight.end.y + 20),
		Vector2(center.x - extent.x / 2, _highlight.position.y - extent.y - 20)]
	var best := Vector2(size.x - extent.x - 18, size.y - extent.y - 18)
	var overlap := INF
	for candidate in candidates:
		candidate.x = clampf(candidate.x, 18, maxf(18, size.x - extent.x - 18))
		candidate.y = clampf(candidate.y, 18, maxf(18, size.y - extent.y - 18))
		var intersection := Rect2(candidate, extent).intersection(_highlight)
		var area := intersection.get_area()
		if area < overlap:
			overlap = area
			best = candidate
	_panel.position = best
	queue_redraw()

func _draw() -> void:
	var shade := Color(0.06, 0.045, 0.025, dim_opacity)
	if _highlight.has_area():
		draw_rect(Rect2(0, 0, size.x, _highlight.position.y), shade)
		draw_rect(Rect2(0, _highlight.end.y, size.x, maxf(0, size.y - _highlight.end.y)), shade)
		draw_rect(Rect2(0, _highlight.position.y, _highlight.position.x, _highlight.size.y), shade)
		draw_rect(Rect2(_highlight.end.x, _highlight.position.y, maxf(0, size.x - _highlight.end.x), _highlight.size.y), shade)
		draw_rect(_highlight, Color("efc777"), false, 2.0)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), shade)
