extends Control
## Presentation only: the home controller owns money, inventory and all effects.

signal closed
signal view_changed
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
var _warning_title: Label


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
	_cash.text = "$%d" % _money
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
	_cash.text = "$%d" % _money
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


func show_purchase_result(success: bool, reason: String = "", reason_code: String = "insufficient_funds") -> void:
	if success:
		_detail_notice.text = "Покупка в рюкзаке!"
		_detail_notice.add_theme_color_override("font_color", GREEN)
	else:
		_warning = true
		_warning_title.text = "Insufficient funds" if reason_code == "insufficient_funds" else "Purchase unavailable"
		_warning_text.text = "Keep publishing headlines and earn money" if reason_code == "insufficient_funds" else reason
		_sync_visibility()
		AudioManager.play_cue(AudioManager.Cue.WARNING)


func hide_all() -> void:
	_mode = ""
	_selected = {}
	_warning = false
	visible = false
	view_changed.emit()


func is_modal_open() -> bool:
	return visible and not _mode.is_empty()


func covers_room_hud() -> bool:
	return _mode == "shop" or not _selected.is_empty() or _warning


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
	view_changed.emit()
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
	_shop = Control.new()
	_place(_shop, self, Rect2(0, 0, 1920, 1080))
	_texture(_shop, ART + "Menu assets/Shop background.png", Rect2(170, 120, 1580, 940))
	_texture(_shop, ART + "Menu assets/Shop yellow.png", Rect2(210, 620, 300, 365), true)
	_texture(_shop, ART + "Menu assets/Shop background 2.png", Rect2(186, 132, 1548, 912))
	_texture(_shop, ART + "Menu assets/Shop background 3.png", Rect2(198, 144, 1524, 890))
	_texture(_shop, ART + "Menu assets/MiniMart.png", Rect2(326, 310, 370, 71), true)
	var menu := Control.new()
	menu.clip_contents = true
	_place(menu, _shop, Rect2(1450, 96, 210, 120))
	_texture(menu, ART + "Menu assets/Menu.png", Rect2(0, 0, 210, 298))
	_texture(_shop, ART + "Menu assets/Cash.png", Rect2(46, 45, 173, 58))
	_label(_shop, "Cash", Rect2(46, 45, 173, 58), 38, true, HORIZONTAL_ALIGNMENT_CENTER).add_theme_color_override("font_color", Color("f2d8a2"))
	_texture(_shop, ART + "Menu assets/Cash 2.png", Rect2(46, 103, 198, 63))
	_cash = _label(_shop, "$0", Rect2(46, 103, 198, 58), 38, true, HORIZONTAL_ALIGNMENT_CENTER)
	_close_button(_shop, Rect2(1740, 32, 148, 148), _back)
	_cards = Control.new()
	_place(_cards, _shop, Rect2(346, 410, 1254, 592))
	_rebuild_cards()


func _rebuild_cards() -> void:
	_clear(_cards)
	for index in mini(_items.size(), 6):
		var item: Dictionary = _items[index]
		var card := _button(_cards, "", Rect2((index % 3) * 426, (index / 3) * 312, 402, 280), _show_item.bind(item))
		card.tooltip_text = str(item.get("name", ""))
		_texture(card, ART + "Menu assets/Item background.png", Rect2(0, 0, 402, 280))
		_texture(card, str(item.get("texture_path", "")), Rect2(18, -4, 160, 160), true)
		var category := str(item.get("category", "food"))
		_texture(card, ART + ("Menu assets/Pet ui.png" if category == "pet" else "Menu assets/Health ui.png"), Rect2(337, -26, 78, 78), true)
		_texture(card, ART + "Menu assets/Price backgroumd.png", Rect2(220, 55, 141, 54))
		_label(card, "$%d" % int(item.get("price", 0)), Rect2(220, 55, 141, 50), 34, true, HORIZONTAL_ALIGNMENT_CENTER)
		var category_icon: String = {"drink": "Drink icon.png", "food": "Food icon.png", "pet": "Pet food icon.png"}.get(category, "Food icon.png")
		_texture(card, ART + "Menu assets/" + category_icon, Rect2(162, 137, 31, 28), true)
		_label(card, _category_name(category), Rect2(201, 130, 193, 42), 27, true)
		var description := _label(card, str(item.get("description", "")), Rect2(26, 187, 350, 80), 24)
		description.add_theme_font_override("font", BOLD)
	AudioManager.bind_ui_buttons(self)


func _build_small_panel() -> void:
	_small = _paper(self, Rect2(1090, 465, 590, 315), "Menu assets/Item background.png")
	_info_tab = _button(_small, "Info", Rect2(270, -40, 130, 48), open_info, true)
	_bag_tab = _button(_small, "Bag", Rect2(405, -40, 130, 48), open_bag, true)
	_info_tab.add_theme_font_size_override("font_size", 32)
	_bag_tab.add_theme_font_size_override("font_size", 32)
	_close_button(_small, Rect2(535, 18, 44, 44), _back)
	_bag = Control.new()
	_place(_bag, _small, Rect2(35, 35, 515, 250))
	_info = Control.new()
	_place(_info, _small, Rect2(35, 35, 515, 250))
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
	_detail = _notepaper(Rect2(448, 246, 1023, 648))
	_texture(_detail, ART + "Buy assets/Circle item background.png", Rect2(110, 178, 261, 261), true)
	_detail_image = _texture(_detail, "", Rect2(142, 198, 200, 220), true)
	_detail_title = _label(_detail, "", Rect2(435, 176, 345, 84), 47, true)
	_detail_restore = _label(_detail, "", Rect2(790, 176, 140, 84), 52, true, HORIZONTAL_ALIGNMENT_RIGHT)
	_texture(_detail, ART + "Buy assets/Line.png", Rect2(435, 268, 491, 5))
	_detail_description = _label(_detail, "", Rect2(435, 295, 491, 139), 34)
	_detail_description.add_theme_font_override("font", BOLD)
	_detail_price = _label(_detail, "", Rect2(112, 440, 261, 34), 28, true, HORIZONTAL_ALIGNMENT_CENTER)
	_detail_notice = _label(_detail, "", Rect2(435, 433, 491, 40), 27)
	_texture(_detail, ART + "Buy assets/Line 2.png", Rect2(112, 478, 817, 5))
	_button(_detail, "Close", Rect2(168, 516, 262, 82), _back, true)
	_action = _button(_detail, "Buy", Rect2(574, 516, 262, 82), _on_action, true)


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
		_action.text = "Buy"
		return
	var id := str(_selected.get("id", ""))
	var count := int(_inventory.get(id, 0))
	_detail_price.text = "В рюкзаке: %d" % count
	var category := str(_selected.get("category", "food"))
	_action.text = "Feed" if category == "pet" else ("Drink" if category == "drink" else "Eat")
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
	_warning_panel = _notepaper(Rect2(448, 246, 1023, 648))
	_warning_title = _label(_warning_panel, "Insufficient funds", Rect2(100, 198, 823, 90), 60, true, HORIZONTAL_ALIGNMENT_CENTER)
	_warning_title.add_theme_color_override("font_color", Color("bb252b"))
	_texture(_warning_panel, ART + "Buy assets/Line 2.png", Rect2(112, 294, 817, 5))
	_warning_text = _label(_warning_panel, "", Rect2(112, 325, 817, 90), 38, true, HORIZONTAL_ALIGNMENT_CENTER)
	_button(_warning_panel, "Close", Rect2(380, 516, 262, 82), _back, true)


func _stat_name(key: String) -> String:
	return {"health": "Выносливость", "reputation": "Репутация", "loyalty": "Лояльность", "qualification": "Квалификация"}.get(key, key)


func _category_name(category: String) -> String:
	return {"drink": "Recovery drink", "food": "Recovery food", "pet": "Pet food"}.get(category, "Recovery food")


func _restore_text(item: Dictionary) -> String:
	if str(item.get("category", "")) == "pet":
		return ""
	return "+%d" % int(item.get("restore", 0))


func _place(control: Control, parent: Node, rect: Rect2) -> void:
	parent.add_child(control)
	control.position = rect.position
	control.size = rect.size


func _paper(parent: Node, rect: Rect2, asset: String) -> Control:
	var panel := Control.new()
	_place(panel, parent, rect)
	_texture(panel, ART + asset, Rect2(Vector2.ZERO, rect.size))
	return panel


func _notepaper(rect: Rect2) -> Control:
	var panel := _paper(self, rect, "Buy assets/Buy background.png")
	_texture(panel, ART + "Buy assets/Buy background 2.png", Rect2(30, 17, 965, 614))
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
	label.add_theme_font_override("font", BOLD if heading else BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, parent, rect)
	# Shape only after the label has its final width. At width zero a wrapped
	# label computes a very tall minimum, which otherwise expands the whole rect.
	label.text = text
	return label


func _button(parent: Node, text: String, rect: Rect2, callback: Callable, paper: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", BOLD)
	button.add_theme_font_size_override("font_size", 46 if paper else 33)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("927761"))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		if paper:
			var style := StyleBoxTexture.new()
			style.texture = _load_texture(ART + "Buy assets/Buy button.png")
			style.modulate_color = Color(1.1, 1.1, 1.1) if state == "hover" else (Color(0.9, 0.9, 0.9) if state == "pressed" else Color.WHITE)
			if state == "disabled":
				style.modulate_color = Color(0.65, 0.65, 0.65)
			button.add_theme_stylebox_override(state, style)
		else:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("a7693b")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(7)
	button.add_theme_stylebox_override("focus", focus if not paper else StyleBoxEmpty.new())
	if paper:
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color_name, Color("fff1ce"))
	_place(button, parent, rect)
	button.pressed.connect(callback)
	return button


func _close_button(parent: Node, rect: Rect2, callback: Callable) -> void:
	var button := _button(parent, "", rect, callback)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.tooltip_text = "Закрыть"
	_texture(button, ART + "Menu assets/Close button.png", Rect2(Vector2.ZERO, rect.size), true)


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
