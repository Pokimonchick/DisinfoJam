extends Control

signal view_changed
signal pause_requested

const CHOICE_OVERLAY: PackedScene = preload("res://Scenes/headline_choice_overlay.tscn")
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

enum DialogKind { NONE, RESULT }

@export_group("Publication result")
@export_range(0.0, 5.0, 0.1) var result_delay_seconds := 0.5
@export_group("Text motion")
@export_range(0.0, 2.0, 0.05) var source_reveal_seconds := 0.45
@export_group("Audio")
@export var headline_appear_sound: AudioStream = preload("res://Assets/Sounds/paper - Part_1.wav")
@export_range(-40.0, 6.0, 0.5) var headline_appear_volume_db: float = 0.0

var session: NewsroomSession
# Selected is the article's draft, not a published headline.
var selected_index := -1
var popup_kind: DialogKind = DialogKind.NONE
var choices_open := false
var _choices_animating := false
var _choice_tween: Tween
var _choice_overlay: Control
var _choice_close_button: Button
var _shown_combo_count := -1
var _shown_combo_type := -1
var _combo_tween: Tween
var _pending_result: Dictionary = {}
var _result_delay: Tween
var _source_reveal: Tween
@onready var cards: Array[Button] = [%Headline1, %Headline2, %Headline3]
@onready var popup: DeskFocus = $Canvas/DeskFocus
@onready var combo_burst: Control = %ComboBurst
@onready var choices: Control = $Canvas/World/Choices
@onready var stamp: DeskStamp = %Stamp
@onready var stamp_area: StampArea = %StampArea

func _ready() -> void:
	visibility_changed.connect(func(): _animate_source(is_visible_in_tree()))
	_choice_overlay = CHOICE_OVERLAY.instantiate() as Control
	choices.add_child(_choice_overlay)
	choices.move_child(_choice_overlay, 0)
	_choice_close_button = _choice_overlay.get_node("Close") as Button
	_choice_close_button.pressed.connect(_hide_choices)
	GameSettings.changed.connect(_on_settings_changed)
	_update_choice_overlay()
	for i in cards.size():
		cards[i].pressed.connect(_select_headline.bind(i))
	%HeadlineField.pressed.connect(_toggle_choices)
	%Coffee.activated.connect(_drink_coffee)
	%FinishShift.pressed.connect(_finish_shift)
	stamp.stamped.connect(_publish_selected)
	stamp.interaction_changed.connect(_refresh_actions)
	stamp.returned_to_rest.connect(_start_result_delay)
	%Drawer.toggled.connect(func(_expanded: bool): view_changed.emit())
	popup.primary_pressed.connect(_on_primary)
	popup.secondary_pressed.connect(_close_focus)
	popup.close_pressed.connect(_close_focus)

func _process(_delta: float) -> void:
	$Canvas.motion_enabled = not popup.visible and _pending_result.is_empty() and not stamp.dragging and not stamp.busy and not (choices.visible and GameSettings.choice_overlay_enabled)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if popup.active:
		if not Rect2(Vector2.ZERO, popup.size).has_point(popup.get_local_mouse_position()):
			_close_focus()
	elif choices_open and GameSettings.choice_overlay_enabled:
		if _pointer_over(_choice_close_button, event.position):
			return
		for card in cards:
			if card.visible and card.get_parent().visible and _pointer_over(card, event.position):
				return
		_hide_choices()
		get_viewport().set_input_as_handled()


func _pointer_over(control: Control, viewport_position: Vector2) -> bool:
	var local_position := control.get_global_transform_with_canvas().affine_inverse() * viewport_position
	return Rect2(Vector2.ZERO, control.size).has_point(local_position)


func _on_settings_changed() -> void:
	var layout_changed := _choice_overlay.visible != GameSettings.choice_overlay_enabled
	_update_choice_overlay()
	if layout_changed and choices_open:
		_open_choices(false)


func _update_choice_overlay() -> void:
	_choice_overlay.visible = GameSettings.choice_overlay_enabled
	choices.z_index = 80 if GameSettings.choice_overlay_enabled else 30
	combo_burst.z_index = 70 if GameSettings.choice_overlay_enabled else 100
	var overlay_blocks := choices.visible and GameSettings.choice_overlay_enabled
	%Drawer.visible = not overlay_blocks
	%FinishShift.visible = not overlay_blocks
	stamp.visible = not overlay_blocks
	if session != null:
		_refresh_actions()

func bind(model: NewsroomSession) -> void:
	session = model
	session.article_changed.connect(show_article)
	session.published.connect(_on_published)
	session.changed.connect(_refresh_desk)
	session.phase_changed.connect(_phase_changed)
	%Drawer.bind(session)
	_refresh_desk()

func _phase_changed() -> void:
	if session.phase != NewsroomSession.Phase.WORK:
		_clear_pending_result()
		stamp_area.reset()
		popup.reset()
		popup_kind = DialogKind.NONE
		_hide_choices(false)
	_refresh_desk()

func _refresh_desk() -> void:
	if session == null:
		return
	%Coffee.set_available(session.coffee_ready)
	%Coffee.set_hint("Выпить: до +%d выносливости" % int(session.balance.coffee_health_restore))
	%ShiftLabel.text = "СМЕНА %02d" % session.day
	_refresh_actions()
	_refresh_combo()

func _refresh_actions() -> void:
	if session == null:
		return
	var blocked := session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement or session.publication_limit_reached()
	var overlay_blocks := choices.visible and GameSettings.choice_overlay_enabled
	%HeadlineField.disabled = blocked or _choices_animating or overlay_blocks
	var can_publish := not (blocked or selected_index < 0 or choices_open or _choices_animating or popup.visible or overlay_blocks)
	stamp.set_enabled(can_publish)
	stamp_area.set_available(can_publish)
	%FinishShift.disabled = blocked or overlay_blocks or stamp.dragging or stamp.busy
	%Coffee.get_node("Cup").disabled = blocked or not session.coffee_ready or session.coffee_used_today or session.health >= session.balance.maximum_stat or overlay_blocks or stamp.dragging or stamp.busy

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
	if not (choices.visible and GameSettings.choice_overlay_enabled):
		session.drink_coffee()

func _display_source(article: NewsArticle, animate := false) -> void:
	%SourceTitle.text = article.source_title
	%SourceText.text = article.source_text
	%SourceText.scroll_to_line(0)
	_set_issue_number(session.published_today + 1)
	_animate_source(animate)

func _animate_source(animate := true) -> void:
	if _source_reveal:
		_source_reveal.kill()
		_source_reveal = null
	var should_animate := animate and is_visible_in_tree() and source_reveal_seconds > 0.0
	for label in [%SourceTitle, %SourceText]:
		label.self_modulate.a = 0.0 if should_animate else 1.0
	if should_animate:
		_source_reveal = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		for label in [%SourceTitle, %SourceText]:
			_source_reveal.tween_property(label, "self_modulate:a", 1.0, source_reveal_seconds)

func _set_issue_number(number: int) -> void:
	var has_art := number >= 1 and number <= NUMBER_ART.size()
	%ArticleNumber.text = "" if has_art else "%02d" % number
	%ArticleNumber.get_node("NumberArt").visible = has_art
	if has_art:
		%ArticleNumber.get_node("NumberArt").texture = NUMBER_ART[number - 1]

func show_article(absorb_ink := true) -> void:
	# Restores and new runs can reach this while the session is still IDLE.
	stamp_area.reset(absorb_ink and session.phase == NewsroomSession.Phase.WORK and session.published_today > 0)
	if session.phase != NewsroomSession.Phase.WORK:
		return
	selected_index = -1
	_clear_pending_result()
	stamp.cancel_interaction()
	popup.reset()
	popup_kind = DialogKind.NONE
	_hide_choices(false)
	_display_source(session.current_article(), absorb_ink)
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
	_update_choice_overlay()
	var indices: Array[int] = []
	for i in cards.size():
		cards[i].get_parent().visible = i != selected_index
		if i != selected_index:
			indices.append(i)
	_choices_animating = animate
	_choice_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var group_center_x: float = $Canvas.design_size.x * 0.5 if GameSettings.choice_overlay_enabled else 1125.0
	for order in indices.size():
		var card := cards[indices[order]]
		var slot: Control = card.get_parent()
		var target := Vector2(group_center_x - (indices.size() * 415.0 - 60.0) * 0.5 + order * 415.0, 340.0)
		card.reset_hover()
		card.show()
		card.disabled = animate
		slot.position = target - Vector2(0, 900) if animate else target
		slot.modulate.a = 0.0 if animate else 1.0
		if animate:
			_choice_tween.tween_property(slot, "position", target, 0.45).set_delay(order * 0.055)
			_choice_tween.tween_property(slot, "modulate:a", 1.0, 0.26).set_delay(order * 0.055)
			_choice_tween.tween_callback(_play_headline_appear_sound).set_delay(order * 0.055)
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

func _play_headline_appear_sound() -> void:
	if choices_open and is_visible_in_tree():
		AudioManager.play_sfx(headline_appear_sound, headline_appear_volume_db)

func _hide_choices(animate := true) -> void:
	if _choice_tween:
		_choice_tween.kill()
	choices_open = false
	_choices_animating = animate and choices.visible
	if not _choices_animating:
		choices.hide()
		_update_choice_overlay()
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
		_update_choice_overlay()
	)
	_refresh_actions()
	view_changed.emit()

func _finish_shift() -> void:
	if session.phase == NewsroomSession.Phase.WORK and not session.awaiting_acknowledgement and not (choices.visible and GameSettings.choice_overlay_enabled):
		session.finish_shift()

func _select_headline(index: int) -> void:
	if not choices_open or _choices_animating or index == selected_index or index < 0 or index >= cards.size():
		return
	if session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement:
		return
	selected_index = index
	%HeadlineField.set_headline(session.option_at(index).text)
	_hide_choices()
	_refresh_actions()
	view_changed.emit()

func _on_primary() -> void:
	if session.phase != NewsroomSession.Phase.WORK:
		return
	if popup_kind == DialogKind.RESULT:
		_close_focus()

func _publish_selected() -> void:
	if not can_process() or not is_visible_in_tree() or selected_index < 0 or choices_open or _choices_animating or popup.visible:
		return
	session.publish_headline(selected_index)

func _close_focus() -> void:
	if not popup.active:
		return
	var was_result := popup_kind == DialogKind.RESULT
	popup_kind = DialogKind.NONE
	popup.close(func():
		if was_result:
			session.acknowledge_publication()
		_refresh_actions()
	)
	view_changed.emit()

func _colored_result_delta(value: int, suffix := "") -> String:
	var color := "#3f6a3d" if value > 0 else ("#9b4033" if value < 0 else "#665945")
	return "[color=%s][b]%+d%s[/b][/color]" % [color, value, suffix]

func _on_published(result: Dictionary) -> void:
	if stamp.busy:
		# Effects apply at contact; the note waits until the stamp is resting.
		_pending_result = result.duplicate(true)
	else:
		_show_result(result)

func _start_result_delay() -> void:
	if _pending_result.is_empty() or (_result_delay and _result_delay.is_valid()):
		return
	# A node-bound tween also pauses while the interface is disabled.
	_result_delay = create_tween()
	_result_delay.tween_interval(result_delay_seconds)
	_result_delay.tween_callback(func():
		var result := _pending_result
		_pending_result = {}
		_result_delay = null
		if is_visible_in_tree() and session.phase == NewsroomSession.Phase.WORK and session.awaiting_acknowledgement:
			_show_result(result)
	)

func _clear_pending_result() -> void:
	_pending_result = {}
	if _result_delay and _result_delay.is_valid():
		_result_delay.kill()
	_result_delay = null

func _show_result(result: Dictionary) -> void:
	_clear_pending_result()
	_hide_choices(false)
	popup_kind = DialogKind.RESULT
	for article in session.articles:
		if article.id == result.get("article_id", ""):
			_display_source(article)
			break
	%HeadlineField.set_headline(result.headline)
	_set_issue_number(session.published_today)
	var changes := "[color=#78512c]%s · серия %d · ×%.2f[/color]\n\n" % [HeadlineOption.TYPE_NAMES[result.combo_type], result.combo_count, result.multiplier]
	changes += "[color=#866025]Деньги:[/color] %s\n" % _colored_result_delta(int(result.money), " $")
	changes += "[color=#2e6770]Репутация:[/color] %s\n" % _colored_result_delta(int(result.reputation))
	changes += "[color=#685078]Лояльность:[/color] %s\n" % _colored_result_delta(int(result.loyalty))
	var stamina_cost := float(result.get("stamina_cost", session.balance.publication_health_cost))
	var stamina_color := "#9b4033" if stamina_cost > 0.0 else "#665945"
	var stamina_change := "−%d" % roundi(stamina_cost) if stamina_cost > 0.0 else "0"
	changes += "[color=#6b7046]Выносливость:[/color] [color=%s][b]%s[/b][/color]\n\n%s" % [stamina_color, stamina_change, result.explanation]
	var full_issue := session.publication_limit_reached()
	if full_issue:
		changes += "\n\n[color=#78512c]В текущем выпуске газеты недостаточно места для новых публикаций.[/color]"
	popup.present(cards[maxi(selected_index, 0)], "ВЫПУСК ЗАПОЛНЕН" if full_issue else "НАПЕЧАТАНО", result.headline, changes, "Сдать выпуск и пойти домой" if full_issue else "Следующий материал", "", Vector2(640, 800))
	_refresh_actions()
	view_changed.emit()

func capture_presentation() -> Dictionary:
	return {"layout_version": 2, "dialog": "result" if popup_kind == DialogKind.RESULT else "none",
		"selected_index": selected_index,
		"choices_open": choices_open, "drawer_expanded": %Drawer.expanded}

func restore_presentation(data: Dictionary) -> void:
	show_article(false)
	%Drawer.set_expanded(bool(data.get("drawer_expanded", true)), false)
	selected_index = clampi(int(data.get("selected_index", -1)), -1, 2)
	if session.awaiting_acknowledgement:
		stamp_area.restore_result()
		_show_result(session.last_result)
		return
	var dialog := str(data.get("dialog", "none"))
	var legacy := int(data.get("layout_version", 1)) < 2
	var preview := int(data.get("selected_index", -1)) if legacy else int(data.get("preview_index", -1))
	if legacy:
		selected_index = -1
	# A save made while inspecting a note now resumes with that draft selected.
	if dialog == "confirm" and preview >= 0 and preview < cards.size():
		selected_index = preview
	if selected_index >= 0:
		%HeadlineField.set_headline(session.option_at(selected_index).text)
	if bool(data.get("choices_open", false)) and dialog != "confirm":
		_open_choices(false)
	_refresh_actions()
