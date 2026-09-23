extends Control

enum DialogKind { NONE, SOURCE, CONFIRM, RESULT }

var session: NewsroomSession
var selected_index: int = -1
var popup_kind: DialogKind = DialogKind.NONE
var _shown_combo_count: int = -1
var _shown_combo_type: int = -1
var _combo_tween: Tween
@onready var cards: Array[Button] = [%Headline1, %Headline2, %Headline3]
@onready var popup: MessagePanel = $MessagePanel
@onready var source_note: Control = %SourceNote
@onready var combo_burst: Control = %ComboBurst

func _ready() -> void:
	for i in cards.size():
		cards[i].pressed.connect(_select_headline.bind(i))
	source_note.connect("activated", show_source)
	%Coffee.connect("activated", _drink_coffee)
	%FinishShift.pressed.connect(_finish_shift)
	popup.primary_pressed.connect(_on_primary)
	popup.secondary_pressed.connect(_on_secondary)
	if popup_kind != DialogKind.NONE:
		_set_headline_cards_visible(false)

func bind(model: NewsroomSession) -> void:
	session = model
	session.article_changed.connect(show_article)
	session.published.connect(_show_result)
	session.changed.connect(_refresh_desk)
	session.phase_changed.connect(_refresh_desk)
	_refresh_desk()

func _refresh_desk() -> void:
	if session == null:
		return
	var cup: Control = %Coffee
	# The stained sheet is permanent desk dressing. A purchased cup is drawn
	# over it until the player drinks it.
	cup.visible = true
	cup.set_interactive(session.coffee_ready and session.phase == NewsroomSession.Phase.WORK and not session.publication_limit_reached())
	cup.kind = 2 if session.coffee_ready else 3
	cup.set_content("", "", "Выпить: +%d сек., −%d выносливости" % [int(session.balance.coffee_bonus_seconds), int(session.balance.coffee_health_cost)])
	%CoffeeHint.text = "ВЫПИТЬ КОФЕ\n+%d сек. / −%d сил" % [int(session.balance.coffee_bonus_seconds), int(session.balance.coffee_health_cost)] if session.coffee_ready else ""
	_refresh_combo()

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
	if popup.visible:
		return
	session.drink_coffee()

func show_article() -> void:
	if session.phase != NewsroomSession.Phase.WORK:
		return
	selected_index = -1
	popup.hide()
	source_note.call("set_content",
		session.current_article().source_title,
		"Источник для материала %02d.\nНаведите, чтобы подсветить. Нажмите, чтобы прочитать." % (session.article_cursor % session.articles.size() + 1),
		"Прочитать источник: " + session.current_article().source_title
	)
	for i in cards.size():
		cards[i].get_node("Content/Headline").text = session.option_at(i).text
	show_source()

func show_source() -> void:
	if session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement or session.publication_limit_reached():
		return
	popup_kind = DialogKind.SOURCE
	_set_headline_cards_visible(false)
	var article := session.current_article()
	popup.present("ИСТОЧНИК · ТАЙМЕР ИДЁТ", article.source_title, article.source_text, "Свернуть на стол")

func _finish_shift() -> void:
	if session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement:
		return
	session.finish_shift()

func _select_headline(index: int) -> void:
	if session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement or session.publication_limit_reached():
		return
	selected_index = index
	popup_kind = DialogKind.CONFIRM
	_set_headline_cards_visible(false)
	popup.present("ПЕРЕД ОТПРАВКОЙ В ПЕЧАТЬ", session.option_at(index).text, "", "Напечатать", "Вернуться к вариантам")

func _on_primary() -> void:
	if session.phase != NewsroomSession.Phase.WORK:
		return
	match popup_kind:
		DialogKind.SOURCE:
			popup.hide()
			popup_kind = DialogKind.NONE
			_set_headline_cards_visible(true)
			cards[0].grab_focus()
		DialogKind.CONFIRM:
			session.publish_headline(selected_index)
		DialogKind.RESULT:
			session.acknowledge_publication()

func _on_secondary() -> void:
	popup.hide()
	popup_kind = DialogKind.NONE
	_set_headline_cards_visible(true)
	cards[maxi(selected_index, 0)].grab_focus()

func _show_result(result: Dictionary) -> void:
	popup_kind = DialogKind.RESULT
	_set_headline_cards_visible(false)
	var changes := "[color=#e8bd68]%s · серия %d · ×%.2f[/color]\nДеньги: %+d $ · Репутация: %+d · Государство: %+d\nВыносливость: −%.1f\n\n%s" % [HeadlineOption.TYPE_NAMES[result.combo_type], result.combo_count, result.multiplier, result.money, result.reputation, result.loyalty, session.balance.publication_health_cost, result.explanation]
	var full_issue := session.publication_limit_reached()
	if full_issue:
		changes += "\n\n[color=#e8bd68]В текущем выпуске газеты недостаточно места для новых публикаций.[/color]"
	popup.present("ВЫПУСК ЗАПОЛНЕН" if full_issue else "НАПЕЧАТАНО · ТАЙМЕР ИДЁТ", result.headline, changes, "Сдать выпуск и пойти домой" if full_issue else "Следующий материал")

func _set_headline_cards_visible(value: bool) -> void:
	for card in cards:
		card.visible = value
