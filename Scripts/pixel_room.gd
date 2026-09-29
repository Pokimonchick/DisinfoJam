@tool
extends Control

# Scenery and the scene's normalized hit areas share a 320 x 112 pixel grid.
var hovered := "":
	set(value):
		hovered = value
		queue_redraw()
var food_stocked := false
var coffee_packed := false
var sleeping := false
var tired := false
var _clock := 0.0

const NIGHT := Color("211d35")
const EDGE := Color("302641")
const PINK := Color("ed8cae")
const CYAN := Color("8de0d2")
const CREAM := Color("ffe4be")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_clock += delta
		queue_redraw()

func _block(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(320, 112))
	_block(0, 0, 320, 112, NIGHT)
	_block(3, 3, 314, 83, Color("695074"))
	_block(5, 5, 310, 3, Color("957093"))
	_block(3, 56, 314, 28, Color("60486b"))
	for x in range(8, 314, 14):
		_block(x, 10, 1, 70, Color("72577e"))
	_block(3, 82, 314, 4, Color("b18292"))
	_block(3, 86, 314, 23, Color("443449"))
	for y in range(90, 110, 7):
		_block(3, y, 314, 1, Color("725268"))
		for x in range(12 + (y % 3) * 15, 314, 36):
			_block(x, y - 6, 1, 6, Color("302b40"))
	# Moonlit window and curtains.
	_block(129, 13, 48, 46, EDGE)
	_block(132, 16, 42, 40, Color("9694c4"))
	_block(134, 18, 38, 36, Color("303752"))
	_block(159, 21, 7, 7, CREAM)
	_block(162, 20, 5, 5, Color("303752"))
	for p in [Vector2(140, 23), Vector2(151, 29), Vector2(167, 34)]:
		_block(p.x, p.y, 1, 1, CREAM)
	for i in range(6):
		var height := 6 + (i * 7) % 13
		_block(134 + i * 6, 54 - height, 6, height, Color("212838"))
		_block(136 + i * 6, 56 - height, 1, 2, Color("e6b487"))
	_block(151, 17, 2, 38, Color("b4a0b5"))
	_block(132, 38, 42, 2, Color("b4a0b5"))
	_block(125, 12, 4, 49, PINK)
	_block(177, 12, 5, 49, PINK)
	_block(127, 58, 53, 3, Color("ba8696"))
	# Left-hand bed, blanket and bedside lamp.
	_block(13, 57, 5, 35, EDGE)
	_block(17, 70, 75, 21, EDGE)
	_block(19, 72, 68, 15, Color("a77586"))
	_block(19, 72, 24, 11, CREAM)
	_block(21, 74, 19, 7, Color("ecd1b7"))
	_block(44, 70, 44, 17, Color("75ada9"))
	_block(46, 71, 40, 3, CYAN)
	for x in range(49, 86, 9):
		_block(x, 77, 3, 3, Color("abdad0"))
		_block(x + 3, 82, 2, 2, Color("518c96"))
	_block(18, 90, 5, 6, EDGE)
	_block(84, 87, 6, 9, EDGE)
	_block(89, 69, 4, 23, Color("51334c"))
	_block(96, 75, 14, 4, Color("bb8b80"))
	_block(98, 79, 3, 13, EDGE)
	_block(106, 79, 3, 13, EDGE)
	_block(102, 62, 2, 12, CREAM)
	_block(97, 57, 12, 7, Color("d3a26f"))
	_block(99, 56, 8, 2, CREAM)
	_block(35, 22, 22, 25, EDGE)
	_block(37, 24, 18, 21, Color("bca1b1"))
	_block(39, 26, 14, 17, Color("434759"))
	_block(43, 30, 5, 5, PINK)
	_block(41, 36, 10, 5, Color("9eb1b1"))
	# Shelf, jars, plant and kitchen table.
	_block(198, 27, 47, 4, Color("bd9190"))
	_block(200, 31, 3, 4, EDGE)
	_block(239, 31, 3, 4, EDGE)
	for x in [214, 224, 234]:
		_block(x, 18, 6, 9, Color("d9bcb1"))
		_block(x, 17, 6, 2, PINK)
		_block(x + 1, 22, 4, 3, Color("90697f"))
	_block(201, 20, 9, 7, Color("b77283"))
	_block(205, 11, 2, 10, CYAN)
	_block(201, 13, 4, 4, Color("699f91"))
	_block(207, 10, 4, 4, Color("9dca95"))
	_block(188, 68, 56, 5, EDGE)
	_block(190, 66, 52, 4, Color("d9a08c"))
	_block(194, 73, 4, 19, Color("9c697a"))
	_block(234, 73, 4, 19, Color("9c697a"))
	_block(201, 64, 20, 2, Color("f0c9b6"))
	if coffee_packed:
		_block(204, 52, 14, 12, Color("bc996d"))
		_block(206, 50, 10, 3, CREAM)
		_block(209, 56, 4, 5, Color("715966"))
	else:
		_block(205, 55, 12, 9, CREAM)
		_block(207, 55, 8, 2, Color("794b55"))
		_block(217, 57, 4, 5, CREAM)
		_block(217, 59, 2, 1, Color("695074"))
		var steam := int(_clock * 2.0) % 3
		_block(207, 49 - steam, 1, 3, Color("d4a6bd"))
		_block(212, 48 - steam, 1, 3, Color("d4a6bd"))
	# Opening the fridge is visual only; the click buys and restores stamina.
	_block(265, 31, 37, 61, EDGE)
	_block(267, 33, 33, 56, Color("8ba0ad"))
	if hovered == "fridge":
		_block(269, 35, 28, 51, Color("dedccb"))
		_block(271, 37, 24, 47, Color("717b92"))
		for y in [51, 66, 81]:
			_block(270, y, 26, 2, CREAM)
		if food_stocked:
			for p in [Vector2(274, 43), Vector2(285, 58), Vector2(276, 73)]:
				_block(p.x, p.y, 7, 8, PINK if p.y == 43 else CYAN)
				_block(p.x + 1, p.y - 1, 5, 2, CREAM)
			_block(287, 45, 5, 6, Color("e5ba6e"))
		_block(300, 35, 9, 51, Color("b0bbc5"))
		_block(305, 41, 2, 36, Color("8393a6"))
	else:
		_block(269, 35, 29, 18, Color("b5c6c9"))
		_block(269, 55, 29, 31, Color("abbdc5"))
		_block(271, 36, 2, 15, Color("d4e5dc"))
		_block(271, 56, 2, 27, Color("d4e5dc"))
		_block(290, 44, 2, 6, EDGE)
		_block(290, 59, 2, 9, EDGE)
		_block(278, 61, 7, 7, PINK)
		_block(280, 63, 3, 3, CREAM)
	_block(115, 92, 64, 9, Color("6d5071"))
	_block(118, 94, 58, 5, Color("a36e86"))
	if sleeping:
		_hero(Vector2(28, 65), true)
		var z := int(_clock * 2) % 3
		_block(56 + z * 4, 53 - z * 3, 4, 1, CREAM)
		_block(59 + z * 4, 54 - z * 3, 1, 1, CREAM)
		_block(56 + z * 4, 55 - z * 3, 4, 1, CREAM)
	else:
		_hero(Vector2(143, 60 + int(sin(_clock * 2.0) > 0)), false)
	var areas := {"bed": Rect2(11, 56, 84, 40), "coffee": Rect2(199, 49, 28, 18), "fridge": Rect2(263, 29, 48, 64)}
	if areas.has(hovered):
		draw_rect(areas[hovered], CYAN, false, 1.0)

func _hero(at: Vector2, in_bed: bool) -> void:
	var hair := Color("29263e")
	_block(at.x - 1, at.y, 15, 15, hair)
	_block(at.x + 1, at.y - 2, 11, 4, hair)
	_block(at.x + 2, at.y + 3, 9, 9, Color("efbb9c"))
	_block(at.x, at.y + 1, 11, 4, hair)
	_block(at.x + 10, at.y + 2, 2, 7, hair)
	_block(at.x + 3, at.y + 7, 2, 1 if in_bed or tired else 2, EDGE)
	_block(at.x + 8, at.y + 7, 2, 1 if in_bed or tired else 2, EDGE)
	_block(at.x + 6, at.y + 10, 2, 1, Color("b87686"))
	if not in_bed:
		_block(at.x + 1, at.y + 14, 12, 11, PINK)
		_block(at.x + 4, at.y + 14, 5, 3, Color("f8b5bd"))
		_block(at.x - 1, at.y + 16, 3, 8, Color("efbb9c"))
		_block(at.x + 12, at.y + 16, 3, 8, Color("efbb9c"))
		_block(at.x + 2, at.y + 25, 4, 7, hair)
		_block(at.x + 8, at.y + 25, 4, 7, hair)
		_block(at.x, at.y + 31, 6, 2, CREAM)
		_block(at.x + 8, at.y + 31, 6, 2, CREAM)
