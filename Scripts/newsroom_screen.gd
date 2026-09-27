extends Control

signal view_changed
signal pause_requested

const NUMBER_ART: Array[Texture2D] = [
	preload("res://Assets/Assets for new version of game/Untitled (22)/image 10.png"),
	preload("res://Assets/Assets for new version of game/Untitled (22)/IMG_1370 1.png"),
	preload("res://Assets/Assets for new version of game/Untitled (22)/IMG_1371 1.png"),
	preload("res://Assets/Assets for new version of game/Untitled (22)/IMG_1372 1.png"),
	preload("res://Assets/Assets for new version of game/Untitled (22)/IMG_1373 1.png"),
	preload("res://Assets/Assets for new version of game/Untitled (22)/IMG_1374 1.png"),
	preload("res://Assets/Assets for new version of game/Untitled (22)/IMG_1375 1.png"),
	preload("res://Assets/Assets for new version of game/Untitled (22)/IMG_1376 1.png"),
	preload("res://Assets/Assets for new version of game/Untitled (22)/IMG_1377 1.png"),
	preload("res://Assets/Assets for new version of game/Untitled (22)/IMG_1378 1.png"),
]

enum DialogKind { NONE, SOURCE, CONFIRM, RESULT }

var session: NewsroomSession
# Selected is the article's draft; preview is only the note currently enlarged.
var selected_index := -1
var preview_index := -1
var popup_kind: DialogKind = DialogKind.NONE
var choices_open := false
var _choices_animating := false
var _choice_tween: Tween
var _shown_combo_count := -1
var _shown_combo_type := -1
var _combo_tween: Tween
@onready var cards: Array[Button] = [%Headline1, %Headline2, %Headline3]
@onready var popup: DeskFocus = $Canvas/DeskFocus
@onready var combo_burst: Control = %ComboBurst
@onready var choices: Control = $Canvas/World/Choices

func _ready() -> void:
	for i in cards.size():
		cards[i].pressed.connect(_select_headline.bind(i))
	%HeadlineField.pressed.connect(_toggle_choices)
	%Coffee.activated.connect(_drink_coffee)
	%FinishShift.pressed.connect(_finish_shift)
	%Publish.pressed.connect(_publish_selected)
	%Pause.pressed.connect(func(): pause_requested.emit())
	%Drawer.toggled.connect(func(_expanded: bool): view_changed.emit())
	popup.primary_pressed.connect(_on_primary)
	popup.secondary_pressed.connect(_close_focus)
	popup.close_pressed.connect(_close_focus)

func _process(_delta: float) -> void:
	$Canvas.motion_enabled = not popup.visible

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not popup.active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not Rect2(Vector2.ZERO, popup.size).has_point(popup.get_local_mouse_position()):
			_close_focus()

func bind(model: NewsroomSession) -> void:
	session = model
	session.article_changed.connect(show_article)
	session.published.connect(_show_result)
	session.changed.connect(_refresh_desk)
	session.phase_changed.connect(_phase_changed)
	%Drawer.bind(session)
	_refresh_desk()

func _phase_changed() -> void:
	if session.phase != NewsroomSession.Phase.WORK:
		popup.reset()
		popup_kind = DialogKind.NONE
		_hide_choices(false)
	_refresh_desk()

func _refresh_desk() -> void:
	if session == null:
		return
	%Coffee.set_available(session.coffee_ready)
	%Coffee.set_hint("Выпить: +%d сек., −%d выносливости" % [int(session.balance.coffee_bonus_seconds), int(session.balance.coffee_health_cost)])
	var seconds := ceili(session.time_left)
	%Clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	%Clock.add_theme_color_override("font_color", Color("ff6051") if session.time_left <= 10.0 else Color("fff2c5"))
	%ShiftLabel.text = "СМЕНА %02d" % session.day
	_refresh_actions()
	_refresh_combo()

func _refresh_actions() -> void:
	var blocked := session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement or session.publication_limit_reached()
	%HeadlineField.disabled = blocked or _choices_animating
	%Publish.disabled = blocked or selected_index < 0 or choices_open or _choices_animating or popup.visible
	%FinishShift.disabled = blocked

func _refresh_combo() -> void:
	if session.combo_count == _shown_combo_count and session.combo_type == _shown_combo_type:
		return
	_shown_combo_count = session.combo_count
	_shown_combo_type = session.combo_type
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	if session.combo_count < 2:
		if not combo_burst.visible:
			return
		_combo_tween = create_tween().set_parallel(true)
		_combo_tween.tween_property(combo_burst, "modulate:a", 0.0, 0.18)
		_combo_tween.tween_property(combo_burst, "scale", Vector2(0.85, 0.85), 0.18)
		_combo_tween.chain().tween_callback(combo_burst.hide)
		return
	%Combo.text = "КОМБО ×%.2f" % session.combo_multiplier()
	%ComboDetail.text = "%s · %d ПОДРЯД" % [HeadlineOption.TYPE_NAMES[session.combo_type], session.combo_count]
	combo_burst.show()
	combo_burst.modulate.a = 0.0
	combo_burst.scale = Vector2(1.25, 1.25)
	_combo_tween = create_tween().set_parallel(true)
	_combo_tween.tween_property(combo_burst, "modulate:a", 1.0, 0.26)
	_combo_tween.tween_property(combo_burst, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _drink_coffee() -> void:
	session.drink_coffee()

func _display_source(article: NewsArticle) -> void:
	%SourceTitle.text = article.source_title
	%SourceText.text = article.source_text
	%SourceText.scroll_to_line(0)
	_set_issue_number(session.published_today + 1)

func _set_issue_number(number: int) -> void:
	var has_art := number >= 1 and number <= NUMBER_ART.size()
	%ArticleNumber.text = "" if has_art else "%02d" % number
	%ArticleNumber.get_node("NumberArt").visible = has_art
	if has_art:
		%ArticleNumber.get_node("NumberArt").texture = NUMBER_ART[number - 1]

func show_article() -> void:
	if session.phase != NewsroomSession.Phase.WORK:
		return
	selected_index = -1
	preview_index = -1
	popup.reset()
	popup_kind = DialogKind.NONE
	_hide_choices(false)
	_display_source(session.current_article())
	%HeadlineField.set_headline("")
	for i in cards.size():
		cards[i].get_node("Content/Headline").text = session.option_at(i).text
	_refresh_actions()
	view_changed.emit()

func _toggle_choices() -> void:
	if choices_open:
		_close_focus()
		_hide_choices()
	else:
		_open_choices()

func _open_choices(animate := true) -> void:
	if session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement or session.publication_limit_reached():
		return
	if _choice_tween:
		_choice_tween.kill()
	choices_open = true
	choices.show()
	var indices: Array[int] = []
	for i in cards.size():
		cards[i].get_parent().visible = i != selected_index
		if i != selected_index:
			indices.append(i)
	_choices_animating = animate
	_choice_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for order in indices.size():
		var card := cards[indices[order]]
		var slot: Control = card.get_parent()
		var target := Vector2(1125.0 - (indices.size() * 415.0 - 60.0) * 0.5 + order * 415.0, 340.0)
		card.reset_hover()
		card.show()
		card.disabled = animate
		slot.position = target - Vector2(0, 900) if animate else target
		slot.modulate.a = 0.0 if animate else 1.0
		if animate:
			_choice_tween.tween_property(slot, "position", target, 0.45).set_delay(order * 0.055)
			_choice_tween.tween_property(slot, "modulate:a", 1.0, 0.26).set_delay(order * 0.055)
	if animate:
		_choice_tween.chain().tween_callback(func():
			_choices_animating = false
			for card in cards:
				card.disabled = false
			_refresh_actions()
		)
	else:
		_choice_tween.kill()
	_refresh_actions()
	view_changed.emit()

func _hide_choices(animate := true) -> void:
	if _choice_tween:
		_choice_tween.kill()
	choices_open = false
	_choices_animating = animate and choices.visible
	if not _choices_animating:
		choices.hide()
		return
	_choice_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for card in cards:
		card.disabled = true
		card.reset_hover()
		var slot: Control = card.get_parent()
		_choice_tween.tween_property(slot, "position:y", -550.0, 0.32)
		_choice_tween.tween_property(slot, "modulate:a", 0.0, 0.28)
	_choice_tween.chain().tween_callback(func():
		choices.hide()
		_choices_animating = false
		_refresh_actions()
	)
	_refresh_actions()
	view_changed.emit()

func _finish_shift() -> void:
	if session.phase == NewsroomSession.Phase.WORK and not session.awaiting_acknowledgement:
		session.finish_shift()

func _select_headline(index: int) -> void:
	if not choices_open or _choices_animating or index == selected_index or index < 0 or index >= cards.size():
		return
	if session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement:
		return
	preview_index = index
	popup_kind = DialogKind.CONFIRM
	popup.present(cards[index], "ВАРИАНТ ЗАГОЛОВКА", session.option_at(index).text, "", "Выбрать заголовок", "", Vector2(640, 800))
	_refresh_actions()
	view_changed.emit()

func _on_primary() -> void:
	if session.phase != NewsroomSession.Phase.WORK:
		return
	if popup_kind == DialogKind.CONFIRM:
		selected_index = preview_index
		%HeadlineField.set_headline(session.option_at(selected_index).text)
		popup_kind = DialogKind.NONE
		choices_open = false
		_choices_animating = true
		popup.close(func(): _hide_choices())
		_refresh_actions()
		view_changed.emit()
	elif popup_kind == DialogKind.RESULT:
		_close_focus()

func _publish_selected() -> void:
	if selected_index < 0 or choices_open or _choices_animating or popup.visible:
		return
	session.publish_headline(selected_index)

func _close_focus() -> void:
	if not popup.active:
		return
	var was_result := popup_kind == DialogKind.RESULT
	popup_kind = DialogKind.NONE
	preview_index = -1
	popup.close(func():
		if was_result:
			session.acknowledge_publication()
		_refresh_actions()
	)
	view_changed.emit()

func _show_result(result: Dictionary) -> void:
	_hide_choices(false)
	popup_kind = DialogKind.RESULT
	for article in session.articles:
		if article.id == result.get("article_id", ""):
			_display_source(article)
			break
	%HeadlineField.set_headline(result.headline)
	_set_issue_number(session.published_today)
	var changes := "[color=#78512c]%s · серия %d · ×%.2f[/color]\nДеньги: %+d $ · Репутация: %+d · Государство: %+d\nВыносливость: −%.1f\n\n%s" % [HeadlineOption.TYPE_NAMES[result.combo_type], result.combo_count, result.multiplier, result.money, result.reputation, result.loyalty, float(result.get("stamina_cost", session.balance.publication_health_cost)), result.explanation]
	var full_issue := session.publication_limit_reached()
	if full_issue:
		changes += "\n\n[color=#78512c]В текущем выпуске газеты недостаточно места для новых публикаций.[/color]"
	popup.present(cards[maxi(selected_index, 0)], "ВЫПУСК ЗАПОЛНЕН" if full_issue else "НАПЕЧАТАНО · ТАЙМЕР ИДЁТ", result.headline, changes, "Сдать выпуск и пойти домой" if full_issue else "Следующий материал", "", Vector2(640, 800))
	_refresh_actions()
	view_changed.emit()

func capture_presentation() -> Dictionary:
	return {"layout_version": 2, "dialog": ["none", "source", "confirm", "result"][popup_kind],
		"selected_index": selected_index, "preview_index": preview_index,
		"choices_open": choices_open, "drawer_expanded": %Drawer.expanded}

func restore_presentation(data: Dictionary) -> void:
	show_article()
	%Drawer.set_expanded(bool(data.get("drawer_expanded", true)), false)
	selected_index = clampi(int(data.get("selected_index", -1)), -1, 2)
	if session.awaiting_acknowledgement:
		_show_result(session.last_result)
		return
	var dialog := str(data.get("dialog", "none"))
	var legacy := int(data.get("layout_version", 1)) < 2
	var preview := int(data.get("selected_index", -1)) if legacy else int(data.get("preview_index", -1))
	if legacy:
		selected_index = -1
	if selected_index >= 0:
		%HeadlineField.set_headline(session.option_at(selected_index).text)
	if bool(data.get("choices_open", false)) or dialog == "confirm":
		_open_choices(false)
	if dialog == "confirm" and preview >= 0 and preview < cards.size() and preview != selected_index:
		_select_headline(preview)
	_refresh_actions()
