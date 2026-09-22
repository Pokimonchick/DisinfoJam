extends Control

enum DialogKind { NONE, SOURCE, CONFIRM, RESULT }

var session: NewsroomSession
var selected_index: int = -1
var popup_kind: DialogKind = DialogKind.NONE
@onready var cards: Array[Button] = [%Headline1, %Headline2, %Headline3]
@onready var popup: MessagePanel = $MessagePanel
@onready var source_note: Control = %SourceNote

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
	%ArticleNumber.text = "ВЫПУСК %02d · ПУБЛИКАЦИИ %d / %d" % [session.day, session.published_today, session.balance.publication_limit]
	var cup: Control = %Coffee
	# The stained sheet is permanent desk dressing. A purchased cup is drawn
	# over it until the player drinks it.
	cup.visible = true
	cup.set_interactive(session.coffee_ready and session.phase == NewsroomSession.Phase.WORK and not session.publication_limit_reached())
	cup.kind = 2 if session.coffee_ready else 3
	cup.set_content("", "", "Выпить: +%d сек., −%d выносливости" % [int(session.balance.coffee_bonus_seconds), int(session.balance.coffee_health_cost)])
	%CoffeeHint.text = "ВЫПИТЬ КОФЕ\n+%d сек. / −%d сил" % [int(session.balance.coffee_bonus_seconds), int(session.balance.coffee_health_cost)] if session.coffee_ready else ""
	if session.combo_count == 0:
		%Combo.text = "КОМБО\nНачните серию\nзаголовков одного типа.\nМаксимум ×%.2f" % session.balance.combo_max_multiplier
	else:
		%Combo.text = "%s\n%d подряд  ·  ×%.2f\nСледующий такой: ×%.2f\nУсиливаются и штрафы!" % [HeadlineOption.TYPE_NAMES[session.combo_type], session.combo_count, session.combo_multiplier(), session.combo_multiplier(session.combo_count + 1)]

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
	popup.present("ПЕРЕД ОТПРАВКОЙ В ПЕЧАТЬ", session.option_at(index).text, "Именно этот заголовок увидят читатели. Числовые последствия станут известны после публикации.\n\nВы ещё можете вернуться к вариантам или перечитать источник.", "Напечатать", "Вернуться к вариантам")

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
