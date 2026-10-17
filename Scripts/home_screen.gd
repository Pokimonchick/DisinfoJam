extends Control

signal notebook_requested
signal pause_requested

const ITEMS = preload("res://Data/home_items.gd")
const PANELS = preload("res://Scripts/tamagotchi_panels.gd")
const UI_ART := "res://Assets/Assets for new version of game/tamagochi/Тамагочи UIUX/"
const WEEKDAYS := ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
@export_range(2.0, 8.0, 0.1) var night_seconds := 3.2
var session: NewsroomSession
var _sleep_left := 0.0
var _panels: Control
@onready var room: Control = %RoomView
@onready var money_label: Label = %Money

func _ready() -> void:
	resized.connect(_fit)
	_fit()
	_panels = PANELS.new()
	$Canvas.add_child(_panels)
	_panels.set_items(ITEMS.ROWS)
	_panels.purchase_requested.connect(_purchase)
	_panels.use_requested.connect(_consume)
	_panels.closed.connect(refresh)
	_panels.visibility_changed.connect(_refresh_controls)
	_panels.view_changed.connect(_refresh_controls)
	%Meal.pressed.connect(_open_shop)
	%Bag.pressed.connect(_open_info)
	%HeroineInfo.pressed.connect(_open_info)
	%Fish.pressed.connect(_open_bag)
	%Bed.pressed.connect(_sleep)
	%Notebook.pressed.connect(func(): notebook_requested.emit())
	%Pause.pressed.connect(func(): pause_requested.emit())
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			_panels.hide_all()
	)
	_skin_button(%Meal, "Shop button.png", Color("fff8e4"))
	_skin_button(%Bed, "Sleep button.png", Color("4c281b"))
	_skin_button(%Notebook, "budget background.png", Color("4c281b"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		%Bag.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	%Day.add_theme_font_override("font", preload("res://Scripts/game_fonts.gd").BOLD)
	%DaysLeft.add_theme_font_override("font", preload("res://Scripts/game_fonts.gd").BOLD)
	money_label.add_theme_font_override("font", preload("res://Scripts/game_fonts.gd").BOLD)
	refresh()

func _fit() -> void:
	# Keep the entire room and its hit areas on screen, including the outer edges.
	$Canvas.scale = size / Vector2(1920, 1080)
	$Canvas.position = Vector2.ZERO

func bind(model: NewsroomSession) -> void:
	session = model
	session.changed.connect(refresh)

func open_evening() -> void:
	_sleep_left = 0.0
	room.sleeping = false
	_panels.hide_all()
	%Notice.text = ""
	refresh()

func refresh() -> void:
	if session == null or not is_node_ready() or session.phase != NewsroomSession.Phase.HOME:
		return
	money_label.text = "$%d" % session.money
	money_label.add_theme_color_override("font_color", Color("973b28") if session.money < 0 else Color("4c281b"))
	%Day.text = WEEKDAYS[clampi(session.day - 1, 0, WEEKDAYS.size() - 1)]
	%DaysLeft.text = "%02d" % maxi(0, session.campaign_days - session.day)
	var sleeping := _sleep_left > 0.0
	_refresh_controls()
	%Notice.visible = not sleeping and not %Notice.text.is_empty()
	%NightCaption.visible = sleeping
	_panels.refresh_state(session.money, session.inventory, {
		"health": session.health, "reputation": session.reputation,
		"loyalty": session.loyalty, "qualification": session.qualification,
		"maximum_stat": session.balance.maximum_stat,
		"proofreading_unlocked": session.proofreading_unlocked})

func _refresh_controls() -> void:
	var sleeping := _sleep_left > 0.0
	var modal_open := _panels != null and _panels.visible
	var covered_hud: bool = modal_open and _panels.covers_room_hud()
	%DayPanel.visible = not sleeping and not covered_hud
	%MoneyPaper.visible = not sleeping and not covered_hud
	for button in [%Meal, %Bag, %HeroineInfo, %Fish, %Bed]:
		button.visible = not sleeping and not modal_open
		button.disabled = sleeping or modal_open
	%Notebook.visible = not sleeping
	%Notebook.disabled = sleeping or modal_open

func _open_shop() -> void:
	if _can_interact():
		_panels.open_shop()

func _open_bag() -> void:
	if _can_interact():
		_panels.open_bag()

func _open_info() -> void:
	if _can_interact():
		_panels.open_info()

func _can_interact() -> bool:
	return session != null and session.phase == NewsroomSession.Phase.HOME and _sleep_left <= 0.0

func _purchase(item_id: String) -> void:
	if not _can_interact():
		return
	var result := session.buy_home_item(item_id)
	_panels.show_purchase_result(result.ok, _reason_text(result.reason), result.reason)
	if not result.ok:
		AudioManager.play_cue(AudioManager.Cue.WARNING)

func _consume(item_id: String) -> void:
	if not _can_interact():
		return
	var result := session.use_home_item(item_id)
	if not result.ok:
		%Notice.text = _reason_text(result.reason)
		%Notice.show()
		AudioManager.play_cue(AudioManager.Cue.WARNING)
		return
	var item := ITEMS.get_item(item_id)
	if result.category == "pet":
		_panels.hide_all()
		room.play_fish_feedback()
		%Notice.text = "Рыбки получили ужин. Кажется, обе довольны."
	else:
		%Notice.text = "%s: +%d к выносливости." % [item.name, int(result.restore)]
		if result.category == "drink":
			AudioManager.play_cue(AudioManager.Cue.COFFEE)
	%Notice.show()

func _reason_text(reason: String) -> String:
	return {
		"insufficient_funds": "На эту покупку пока не хватает денег. В редакции ещё ждут новые материалы.",
		"inventory_full": "В рюкзаке уже достаточно этого товара. Сначала используйте запас.",
		"not_owned": "Этот запас уже закончился.",
		"health_full": "Силы уже полностью восстановлены. Прибережём на потом.",
		"wrong_phase": "Сейчас не время для покупок.",
		"unknown_item": "Этот товар пока недоступен."
	}.get(reason, "")

func _sleep() -> void:
	if not _can_interact() or _panels.is_modal_open():
		return
	_sleep_left = night_seconds
	_panels.hide_all()
	room.sleeping = true
	refresh()
	# Save before the night starts; loading must not apply sleep twice.
	session.save_requested.emit()

func tick_home(delta: float) -> void:
	if _sleep_left <= 0.0 or session.phase != NewsroomSession.Phase.HOME:
		return
	_sleep_left = maxf(0.0, _sleep_left - delta)
	if _sleep_left <= 0.0:
		session.start_shift()

func set_playback_paused(value: bool) -> void:
	room.set_playback_paused(value)

func capture_presentation() -> Dictionary:
	return {"sleep_left": _sleep_left}

func restore_presentation(data: Dictionary) -> void:
	_sleep_left = clampf(float(data.get("sleep_left", 0.0)), 0.0, night_seconds)
	room.sleeping = _sleep_left > 0.0
	refresh()

func tutorial_target(key: String) -> Control:
	return {"money": %MoneyPaper, "meal": %Meal, "coffee": %Bag,
		"bag": %Bag, "notebook": %Notebook, "bed": %Bed}.get(key, %Bag)

func _skin_button(button: Button, asset: String, ink: Color) -> void:
	button.add_theme_font_override("font", preload("res://Scripts/game_fonts.gd").BOLD)
	button.add_theme_font_size_override("font_size", 56)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = load(UI_ART + asset) as Texture2D
		style.modulate_color = Color(1.05, 1.05, 1.05) if state == "hover" else (Color(0.92, 0.92, 0.92) if state == "pressed" else Color.WHITE)
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
