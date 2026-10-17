extends Control
## Presentation only: the home controller owns money, inventory and all effects.

signal closed
signal purchase_requested(item_id: String)
signal use_requested(item_id: String)
signal fish_feed_requested

const ART := "res://Assets/Assets for new version of game/tamagochi/Shop assets/"
const BODY = preload("res://Assets/Assets for new version of game/tamagochi/Alegreya_Sans,Ysabeau/Alegreya_Sans/AlegreyaSans-Regular.ttf")
const BOLD = preload("res://Assets/Assets for new version of game/tamagochi/Alegreya_Sans,Ysabeau/Alegreya_Sans/AlegreyaSans-Bold.ttf")
const HEADING = preload("res://Assets/Assets for new version of game/tamagochi/Alegreya_Sans,Ysabeau/Ysabeau/static/Ysabeau-Bold.ttf")
const INK := Color("4c281b")
const RED := Color("a23521")
const GREEN := Color("4d6a2b")

var _items: Array[Dictionary] = []
var _inventory: Dictionary = {}
var _stats: Dictionary = {}
var _money := 0
var _mode := ""
var _selected: Dictionary = {}
var _warning := false
var _shade: ColorRect
var _shop: Control
var _cards: Control
var _cash: Label
var _small: Control
var _bag: Control
var _info: Control
var _bag_tab: Button
var _info_tab: Button
var _stat_labels: Dictionary = {}
var _stat_bars: Dictionary = {}
var _detail: Control
var _detail_title: Label
var _detail_restore: Label
var _detail_description: Label
var _detail_image: TextureRect
var _detail_price: Label
var _detail_notice: Label
var _action: Button
var _warning_panel: Control
var _warning_text: Label


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shade = ColorRect.new()
	_shade.color = Color(0.12, 0.07, 0.04, 0.57)
	_place(_shade, self, Rect2(0, 0, 1920, 1080))
	_build_shop()
	_build_small_panel()
	_build_detail()
	_build_warning()
	hide_all()
	AudioManager.bind_ui_buttons(self)


func set_items(items: Array[Dictionary]) -> void:
	_items = items.duplicate(true)
	if is_node_ready():
		_rebuild_cards()
		_rebuild_bag()


func refresh_state(money: int, inventory: Dictionary, stats: Dictionary) -> void:
	_money = money
	_inventory = inventory.duplicate(true)
	_stats = stats.duplicate(true)
	if not is_node_ready():
		return
	_cash.text = "%d $" % _money
	_rebuild_bag()
	for key: String in _stat_labels:
		var label: Label = _stat_labels[key]
		if key == "qualification" and not bool(_stats.get("proofreading_unlocked", false)):
			label.text = "Квалификация: пока недоступна"
		else:
			label.text = "%s: %d / %d" % [_stat_name(key), int(_stats.get(key, 0)), int(_stats.get("maximum_stat", 100))]
		var bar: ProgressBar = _stat_bars[key]
		bar.max_value = float(_stats.get("maximum_stat", 100))
		bar.value = float(_stats.get(key, 0))
		bar.visible = key != "qualification" or bool(_stats.get("proofreading_unlocked", false))
	if not _selected.is_empty():
		_update_detail_action()
	if visible:
		_trap_focus()


func open_shop() -> void:
	_mode = "shop"
	_selected = {}
	_warning = false
	_sync_visibility()
	_cash.text = "%d $" % _money
	AudioManager.play_cue(AudioManager.Cue.PAPER_TURN)


func open_bag() -> void:
	_open_small("bag")


func open_info() -> void:
	_open_small("info")


func _open_small(mode: String) -> void:
	_mode = mode
	_selected = {}
	_warning = false
	_rebuild_bag()
	_sync_visibility()
	AudioManager.play_cue(AudioManager.Cue.PAPER_TURN)


func show_purchase_result(success: bool, reason: String = "") -> void:
	if success:
		_detail_notice.text = "Покупка в рюкзаке!"
		_detail_notice.add_theme_color_override("font_color", GREEN)
	else:
		_warning = true
		_warning_text.text = reason if not reason.is_empty() else "На эту покупку пока не хватает денег.\nЗаработайте ещё и возвращайтесь!"
		_sync_visibility()
		AudioManager.play_cue(AudioManager.Cue.WARNING)


func hide_all() -> void:
	_mode = ""
	_selected = {}
	_warning = false
	visible = false


func is_modal_open() -> bool:
	return visible and not _mode.is_empty()


func _input(event: InputEvent) -> void:
	if is_modal_open() and event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _back() -> void:
	if _warning:
		_warning = false
		_selected = {}
		_mode = "shop"
		_sync_visibility()
	elif not _selected.is_empty():
		_selected = {}
		_sync_visibility()
	else:
		hide_all()
		closed.emit()


func _sync_visibility() -> void:
	visible = not _mode.is_empty()
	var has_detail := not _selected.is_empty()
	_shade.visible = _mode == "shop" or has_detail or _warning
	_shop.visible = _mode == "shop" and not has_detail and not _warning
	_small.visible = _mode != "shop" and not has_detail and not _warning
	_bag.visible = _mode == "bag"
	_info.visible = _mode == "info"
	_bag_tab.modulate = Color.WHITE if _mode == "bag" else Color(0.77, 0.69, 0.56)
	_info_tab.modulate = Color.WHITE if _mode == "info" else Color(0.77, 0.69, 0.56)
	_detail.visible = has_detail and not _warning
	_warning_panel.visible = _warning
	_trap_focus()


func _trap_focus() -> void:
	var panel: Control = _warning_panel if _warning else (_detail if not _selected.is_empty() else (_shop if _mode == "shop" else _small))
	var buttons: Array[BaseButton] = []
	for node: Node in panel.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.is_visible_in_tree() and not button.disabled:
			buttons.append(button)
	if buttons.is_empty():
		return
	for index in buttons.size():
		var button := buttons[index]
		var next := button.get_path_to(buttons[(index + 1) % buttons.size()])
		var previous := button.get_path_to(buttons[(index - 1 + buttons.size()) % buttons.size()])
		button.focus_next = next
		button.focus_previous = previous
		button.focus_neighbor_left = previous
		button.focus_neighbor_top = previous
		button.focus_neighbor_right = next
		button.focus_neighbor_bottom = next
	if not buttons.has(get_viewport().gui_get_focus_owner()):
		buttons[0].grab_focus()


func _build_shop() -> void:
	_shop = _paper(self, Rect2(170, 120, 1580, 940), "Menu assets/Shop background.png")
	_texture(_shop, ART + "Menu assets/Shop background 2.png", Rect2(16, 12, 1548, 912))
	_texture(_shop, ART + "Menu assets/Shop background 3.png", Rect2(28, 24, 1524, 890))
	_label(_shop, "МИНИ-МАРКЕТ", Rect2(100, 65, 880, 85), 64, true)
	_label(_shop, "Что-нибудь вкусное для хорошего вечера", Rect2(105, 147, 1020, 48), 32)
	_texture(_shop, ART + "Menu assets/Cash 2.png", Rect2(1160, 100, 235, 70))
	_cash = _label(_shop, "0 $", Rect2(1170, 106, 215, 56), 40, true, HORIZONTAL_ALIGNMENT_CENTER)
	_close_button(_shop, Rect2(1450, 65, 65, 65), _back)
	_cards = Control.new()
	_place(_cards, _shop, Rect2(95, 225, 1390, 640))
	_rebuild_cards()


func _rebuild_cards() -> void:
	_clear(_cards)
	for index in mini(_items.size(), 6):
		var item: Dictionary = _items[index]
		var card := _button(_cards, "", Rect2((index % 3) * 470, (index / 3) * 326, 445, 300), _show_item.bind(item))
		card.tooltip_text = str(item.get("name", ""))
		_texture(card, ART + "Menu assets/Item background.png", Rect2(0, 0, 445, 300))
		_texture(card, str(item.get("texture_path", "")), Rect2(20, 38, 150, 160), true)
		_label(card, str(item.get("name", "")), Rect2(182, 28, 240, 58), 28, true)
		_texture(card, ART + ("Menu assets/Pet ui.png" if item.get("category", "") == "pet" else "Menu assets/Health ui.png"), Rect2(383, -8, 60, 60), true)
		_label(card, _category_name(str(item.get("category", "food"))), Rect2(183, 90, 235, 30), 23)
		_label(card, str(item.get("description", "")), Rect2(183, 126, 235, 105), 25)
		_texture(card, ART + "Menu assets/Price backgroumd.png", Rect2(32, 225, 125, 46))
		_label(card, "%d $" % int(item.get("price", 0)), Rect2(32, 226, 125, 42), 29, true, HORIZONTAL_ALIGNMENT_CENTER)
		_label(card, _restore_text(item), Rect2(185, 247, 235, 34), 25)
	AudioManager.bind_ui_buttons(self)


func _build_small_panel() -> void:
	_small = _paper(self, Rect2(1020, 430, 590, 400), "Buy assets/Buy background 2.png")
	_info_tab = _button(_small, "Инфо", Rect2(35, 38, 160, 48), open_info, true)
	_bag_tab = _button(_small, "Рюкзак", Rect2(205, 38, 180, 48), open_bag, true)
	_close_button(_small, Rect2(510, 35, 44, 44), _back)
	_texture(_small, ART + "Buy assets/Line 2.png", Rect2(35, 100, 515, 3))
	_bag = Control.new()
	_place(_bag, _small, Rect2(35, 118, 515, 250))
	_info = Control.new()
	_place(_info, _small, Rect2(35, 118, 515, 250))
	_texture(_info, "res://Assets/Characters/Mask group (22).png", Rect2(355, 20, 158, 225), true)
	_label(_info, "Никола Коко", Rect2(0, 0, 340, 46), 32, true)
	var keys := ["health", "reputation", "loyalty", "qualification"]
	var colors := [Color("b9cb76"), Color("c99c97"), Color("8cb5c9"), Color("b19bc6")]
	for index in keys.size():
		var key: String = keys[index]
		_stat_labels[key] = _label(_info, "", Rect2(0, 51 + index * 47, 340, 27), 23)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var backing := StyleBoxFlat.new()
		backing.bg_color = Color("fff7dc")
		backing.border_color = Color("fffdf1")
		backing.set_border_width_all(3)
		bar.add_theme_stylebox_override("background", backing)
		var fill := StyleBoxFlat.new()
		fill.bg_color = colors[index]
		bar.add_theme_stylebox_override("fill", fill)
		_place(bar, _info, Rect2(0, 79 + index * 47, 325, 14))
		_stat_bars[key] = bar
	_rebuild_bag()


func _rebuild_bag() -> void:
	_clear(_bag)
	var owned: Array[Dictionary] = []
	for item: Dictionary in _items:
		if int(_inventory.get(str(item.get("id", "")), 0)) > 0:
			owned.append(item)
	if owned.is_empty():
		_label(_bag, "Рюкзак пока пуст.\nЗагляните в магазин за вкусным!", Rect2(10, 60, 495, 130), 31, false, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		for index in mini(owned.size(), 6):
			var item: Dictionary = owned[index]
			var slot := _button(_bag, "", Rect2((index % 3) * 174, (index / 3) * 120, 156, 110), _show_item.bind(item))
			slot.tooltip_text = str(item.get("name", ""))
			_texture(slot, ART + "Menu assets/Item background.png", Rect2(0, 0, 156, 110))
			_texture(slot, str(item.get("texture_path", "")), Rect2(24, 4, 105, 90), true)
			_label(slot, "×%d" % int(_inventory.get(str(item.get("id", "")), 0)), Rect2(104, 73, 45, 32), 27, true, HORIZONTAL_ALIGNMENT_RIGHT)
	AudioManager.bind_ui_buttons(self)


func _build_detail() -> void:
	_detail = _paper(self, Rect2(460, 250, 1000, 640), "Buy assets/Buy background 2.png")
	_texture(_detail, ART + "Buy assets/Circle item background.png", Rect2(65, 135, 340, 340), true)
	_detail_image = _texture(_detail, "", Rect2(105, 170, 260, 260), true)
	_detail_title = _label(_detail, "", Rect2(455, 105, 455, 85), 47, true)
	_detail_restore = _label(_detail, "", Rect2(455, 197, 450, 45), 33, true)
	_detail_description = _label(_detail, "", Rect2(455, 264, 450, 145), 31)
	_texture(_detail, ART + "Buy assets/Line.png", Rect2(455, 246, 450, 3))
	_detail_price = _label(_detail, "", Rect2(115, 484, 240, 50), 38, true, HORIZONTAL_ALIGNMENT_CENTER)
	_detail_notice = _label(_detail, "", Rect2(455, 410, 455, 58), 27)
	_action = _button(_detail, "Купить", Rect2(455, 490, 450, 76), _on_action, true)
	for state: String in ["normal", "hover", "pressed"]:
		var style := StyleBoxTexture.new()
		style.texture = _load_texture(ART + "Buy assets/Buy button.png")
		_action.add_theme_stylebox_override(state, style)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_action.add_theme_color_override(color_name, Color("fff1ce"))
	_close_button(_detail, Rect2(900, 60, 54, 54), _back)


func _show_item(item: Dictionary) -> void:
	_selected = item
	_detail_title.text = str(item.get("name", ""))
	_detail_restore.text = _restore_text(item)
	_detail_description.text = str(item.get("description", ""))
	_detail_image.texture = _load_texture(str(item.get("texture_path", "")))
	_detail_price.text = "%d $" % int(item.get("price", 0)) if _mode == "shop" else "В рюкзаке: %d" % int(_inventory.get(str(item.get("id", "")), 0))
	_detail_notice.text = ""
	_detail_notice.add_theme_color_override("font_color", INK)
	_update_detail_action()
	_sync_visibility()
	_action.grab_focus()
	AudioManager.play_cue(AudioManager.Cue.PAPER_TURN)


func _update_detail_action() -> void:
	_action.disabled = false
	if _mode == "shop":
		_action.text = "Купить · %d $" % int(_selected.get("price", 0))
		return
	var id := str(_selected.get("id", ""))
	var count := int(_inventory.get(id, 0))
	_detail_price.text = "В рюкзаке: %d" % count
	var category := str(_selected.get("category", "food"))
	_action.text = "Покормить рыбок" if category == "pet" else ("Выпить" if category == "drink" else "Съесть")
	_action.disabled = count <= 0 or (float(_selected.get("restore", 0)) > 0 and float(_stats.get("health", 0)) >= float(_stats.get("maximum_stat", 100)))
	if count <= 0:
		_detail_notice.text = "Закончилось. Можно купить ещё."
	elif _action.disabled:
		_detail_notice.text = "Силы уже полностью восстановлены."
	else:
		_detail_notice.text = ""


func _on_action() -> void:
	if _selected.is_empty() or _action.disabled:
		return
	var id := str(_selected.get("id", ""))
	if _mode == "shop":
		purchase_requested.emit(id)
	else:
		use_requested.emit(id)


func _build_warning() -> void:
	_warning_panel = _paper(self, Rect2(460, 250, 1000, 640), "Buy assets/Buy background 2.png")
	_label(_warning_panel, "ПОКУПКА НЕДОСТУПНА", Rect2(85, 125, 830, 90), 48, true, HORIZONTAL_ALIGNMENT_CENTER).add_theme_color_override("font_color", RED)
	_warning_text = _label(_warning_panel, "", Rect2(130, 255, 740, 150), 36, false, HORIZONTAL_ALIGNMENT_CENTER)
	_button(_warning_panel, "Вернуться в магазин", Rect2(265, 480, 470, 75), _back, true)
	_close_button(_warning_panel, Rect2(900, 60, 54, 54), _back)


func _stat_name(key: String) -> String:
	return {"health": "Выносливость", "reputation": "Репутация", "loyalty": "Лояльность", "qualification": "Квалификация"}.get(key, key)


func _category_name(category: String) -> String:
	return {"drink": "Напиток", "food": "Еда", "pet": "Корм для рыбок"}.get(category, "Еда")


func _restore_text(item: Dictionary) -> String:
	if str(item.get("category", "")) == "pet":
		return "Забота о рыбках"
	return "+%d к выносливости" % int(item.get("restore", 0))


func _place(control: Control, parent: Node, rect: Rect2) -> void:
	parent.add_child(control)
	control.position = rect.position
	control.size = rect.size


func _paper(parent: Node, rect: Rect2, asset: String) -> Control:
	var panel := Control.new()
	_place(panel, parent, rect)
	_texture(panel, ART + asset, Rect2(Vector2.ZERO, rect.size))
	return panel


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _texture(parent: Node, path: String, rect: Rect2, keep_aspect: bool = false) -> TextureRect:
	var image := TextureRect.new()
	image.texture = _load_texture(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect else TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(image, parent, rect)
	return image


func _label(parent: Node, text: String, rect: Rect2, font_size: int, heading: bool = false, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", HEADING if heading else BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, parent, rect)
	return label


func _button(parent: Node, text: String, rect: Rect2, callback: Callable, paper: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", BOLD)
	button.add_theme_font_size_override("font_size", 33)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("927761"))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		if paper:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("d79954") if state == "normal" else Color("e7b77d")
			if state == "disabled":
				style.bg_color = Color("c8b28a")
			style.border_color = Color("a7693b")
			style.set_border_width_all(2)
			style.set_corner_radius_all(5)
			button.add_theme_stylebox_override(state, style)
		else:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("a7693b")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(7)
	button.add_theme_stylebox_override("focus", focus)
	_place(button, parent, rect)
	button.pressed.connect(callback)
	return button


func _close_button(parent: Node, rect: Rect2, callback: Callable) -> void:
	var button := _button(parent, "", rect, callback)
	button.tooltip_text = "Закрыть"
	_texture(button, ART + "Menu assets/Close button.png", Rect2(Vector2.ZERO, rect.size), true)


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
