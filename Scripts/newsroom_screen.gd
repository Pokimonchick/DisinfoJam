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
@export var source_ink_material: ShaderMaterial = preload("res://Data/source_ink.tres")
@export_group("Proofreading")
@export var pencil_rest_position := Vector2(800, 940)
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
var _next_source: NewsArticle
var _source_material: ShaderMaterial
var pencil: DeskPencil
var proofreading_surface: ProofreadingSurface
var undo_stroke: Button
@onready var cards: Array[Button] = [%Headline1, %Headline2, %Headline3]
@onready var popup: DeskFocus = $Canvas/DeskFocus
@onready var combo_burst: Control = %ComboBurst
@onready var choices: Control = $Canvas/World/Choices
@onready var stamp: DeskStamp = %Stamp
@onready var stamp_area: StampArea = %StampArea

func _ready() -> void:
	_source_material = source_ink_material.duplicate(true) as ShaderMaterial
	for label in [%SourceTitle, %SourceText]:
		label.material = _source_material
	_create_proofreading_tools()
	visibility_changed.connect(func(): _animate_source(is_visible_in_tree()))
	stamp_area.absorption_progress_changed.connect(_on_source_absorption)
	stamp_area.ink_time_changed.connect(func(time: float): _source_material.set_shader_parameter("ink_time", time))
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

func _create_proofreading_tools() -> void:
	var world: Control = $Canvas/World
	proofreading_surface = ProofreadingSurface.new()
	proofreading_surface.name = "Proofreading"
	proofreading_surface.size = $Canvas.design_size
	proofreading_surface.z_index = 20
	proofreading_surface.material = _source_material
	world.add_child(proofreading_surface)
	proofreading_surface.changed.connect(func():
		if session != null:
			session.proofreading_changed()
		view_changed.emit()
	)
	pencil = preload("res://Scenes/desk_pencil.tscn").instantiate() as DeskPencil
	pencil.position = pencil_rest_position
	pencil.z_index = 60
	world.add_child(pencil)
	pencil.set_surface(proofreading_surface)
	pencil.interaction_changed.connect(_refresh_actions)
	undo_stroke = Button.new()
	undo_stroke.name = "UndoStroke"
	undo_stroke.text = "Отменить штрих"
	undo_stroke.tooltip_text = "Убрать последнюю пометку карандашом"
	undo_stroke.position = Vector2(1380, 986)
	undo_stroke.size = Vector2(230, 50)
	undo_stroke.z_index = 65
	undo_stroke.add_theme_font_size_override("font_size", 24)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("eee0b8")
	paper.border_color = Color("9b7650")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(2)
	undo_stroke.add_theme_stylebox_override("normal", paper)
	undo_stroke.add_theme_color_override("font_color", Color("544034"))
	world.add_child(undo_stroke)
	undo_stroke.pressed.connect(proofreading_surface.undo_last)
	pencil.input_exclusions.assign([undo_stroke, %SourceText.get_v_scroll_bar()])

func _process(_delta: float) -> void:
	$Canvas.motion_enabled = not popup.visible and _pending_result.is_empty() and not stamp.dragging and not stamp.busy and not pencil.held and not (choices.visible and GameSettings.choice_overlay_enabled)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if popup.active:
		var scrollbar := popup.body_label.get_v_scroll_bar()
		if scrollbar.visible and _pointer_over(scrollbar, event.position):
			return
		_close_focus()
		get_viewport().set_input_as_handled()
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
	pencil.visible = session != null and session.proofreading_unlocked and not overlay_blocks
	undo_stroke.visible = pencil.visible
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
		_next_source = null
		_animate_source(false)
		_clear_pending_result()
		stamp_area.reset()
		popup.reset()
		popup_kind = DialogKind.NONE
		_hide_choices(false)
		pencil.cancel_interaction()
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
	var blocked := session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement or session.publication_limit_reached() or _next_source != null
	var overlay_blocks := choices.visible and GameSettings.choice_overlay_enabled
	%HeadlineField.disabled = blocked or _choices_animating or overlay_blocks or pencil.held
	var can_publish := not (blocked or selected_index < 0 or choices_open or _choices_animating or popup.visible or overlay_blocks or pencil.held)
	stamp.set_enabled(can_publish)
	stamp_area.set_available(can_publish)
	pencil.enabled = session.proofreading_unlocked
	pencil.visible = pencil.enabled and not overlay_blocks
	undo_stroke.visible = pencil.visible
	pencil.interaction_enabled = not (blocked or choices.visible or popup.visible or stamp.dragging or stamp.busy)
	proofreading_surface.input_enabled = pencil.enabled and pencil.interaction_enabled
	undo_stroke.disabled = blocked or choices.visible or popup.visible or stamp.dragging or stamp.busy or session.proofreading.strokes.is_empty()
	%FinishShift.disabled = blocked or overlay_blocks or stamp.dragging or stamp.busy or pencil.held
	%Coffee.get_node("Cup").disabled = blocked or not session.coffee_ready or session.coffee_used_today or session.health >= session.balance.maximum_stat or overlay_blocks or stamp.dragging or stamp.busy or pencil.held

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
	_next_source = null
	if article == null:
		%SourceTitle.text = "ВЫПУСК ГОТОВ"
		%SourceText.text = "Все материалы разобраны. Можно сдать выпуск."
		proofreading_surface.clear()
		_animate_source(false)
		return
	%SourceTitle.text = article.source_title
	%SourceText.text = session.display_source_text(article)
	if session.proofreading_unlocked and session.proofreading.article_id == article.id:
		proofreading_surface.bind(%SourceText, session.proofreading)
	else:
		proofreading_surface.clear()
	%SourceText.scroll_to_line(0)
	_set_issue_number(session.published_today + 1)
	_animate_source(animate)

func _animate_source(animate := true) -> void:
	if _next_source != null:
		# Leaving/restoring the desk completes the transient handover immediately.
		var article := _next_source
		_next_source = null
		stamp_area.reset()
		_display_source(article, animate)
		_refresh_actions()
		return
	if _source_reveal:
		_source_reveal.kill()
		_source_reveal = null
	var should_animate := animate and is_visible_in_tree() and source_reveal_seconds > 0.0
	for label in [%SourceTitle, %SourceText]:
		label.self_modulate.a = 1.0
	_source_material.set_shader_parameter("absorption_progress", 0.0)
	_source_material.set_shader_parameter("ink_origin", %SourceText.get_global_transform_with_canvas().origin)
	_set_source_reveal(0.0 if should_animate else 1.0)
	if should_animate:
		_source_reveal = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_source_reveal.tween_method(_set_source_reveal, 0.0, 1.0, source_reveal_seconds)

func _set_source_reveal(progress: float) -> void:
	_source_material.set_shader_parameter("reveal_progress", progress)

func _on_source_absorption(progress: float) -> void:
	if _next_source == null:
		return
	# One clock fades the old source and the actual stamped ink together.
	_source_material.set_shader_parameter("absorption_progress", progress)
	if progress >= 1.0:
		_display_source(_next_source, true)
		_refresh_actions()
		view_changed.emit()

func _set_issue_number(number: int) -> void:
	var has_art := number >= 1 and number <= NUMBER_ART.size()
	%ArticleNumber.text = "" if has_art else "%02d" % number
	%ArticleNumber.get_node("NumberArt").visible = has_art
	if has_art:
		%ArticleNumber.get_node("NumberArt").texture = NUMBER_ART[number - 1]

func show_article(absorb_ink := true) -> void:
	# Restores and new runs can reach this while the session is still IDLE.
	var fade_previous := absorb_ink and session.phase == NewsroomSession.Phase.WORK and is_visible_in_tree() and stamp_area.printed and stamp_area.imprint.visible and stamp_area.absorption_seconds > 0.0
	_next_source = null
	_animate_source(false)
	if fade_previous:
		_next_source = session.current_article()
	stamp_area.reset(fade_previous)
	if session.phase != NewsroomSession.Phase.WORK:
		return
	selected_index = -1
	_clear_pending_result()
	stamp.cancel_interaction()
	pencil.cancel_interaction()
	popup.reset()
	popup_kind = DialogKind.NONE
	_hide_choices(false)
	if not fade_previous:
		_display_source(session.current_article(), absorb_ink)
	%HeadlineField.set_headline("")
	for i in cards.size():
		var option := session.option_at(i)
		cards[i].get_node("Content/Headline").text = option.text if option != null else ""
	_refresh_actions()
	view_changed.emit()

func _toggle_choices() -> void:
	if choices_open:
		_close_focus()
		_hide_choices()
	else:
		_open_choices()

func _open_choices(animate := true) -> void:
	if session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement or session.publication_limit_reached() or _next_source != null or session.current_article() == null or pencil.held:
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
	if popup.finish_opening():
		get_viewport().set_input_as_handled()
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
			var resolved := ArticleSequence.resolve(article, session.story_choices, session.journal)
			# Reloads need the published source; a live result keeps its scroll position.
			if %SourceTitle.text != resolved.source_title or %SourceText.text != result.get("source_text", session.display_source_text(resolved)):
				_display_source(resolved)
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
	if result.has("proofreading"):
		var corrections: Dictionary = result.proofreading
		changes += "\n\n[color=#78512c]Вычитка: исправлено %d · пропущено %d · неверно %d[/color]\n" % [corrections.corrected, corrections.missed, corrections.wrong]
		changes += "Из них за вычитку: %s · Квалификация: %s" % [_colored_result_delta(int(corrections.money), " $"), _colored_result_delta(int(corrections.qualification))]
	var full_issue := session.publication_limit_reached() or session.current_article() == null
	if full_issue:
		changes += "\n\n[color=#78512c]%s[/color]" % ("Все материалы разобраны." if session.current_article() == null else "В текущем выпуске газеты недостаточно места для новых публикаций.")
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
