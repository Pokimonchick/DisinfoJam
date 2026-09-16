extends Control

enum Popup { NONE, SOURCE, CONFIRM, RESULT }

var session: NewsroomSession
var selected_index: int = -1
var popup_kind: Popup = Popup.NONE
@onready var cards: Array[Button] = [%Headline1, %Headline2, %Headline3]
@onready var popup: MessagePanel = $MessagePanel

func _ready() -> void:
	for i in cards.size():
		cards[i].pressed.connect(_select_headline.bind(i))
	%ReadSource.pressed.connect(show_source)
	popup.primary_pressed.connect(_on_primary)
	popup.secondary_pressed.connect(_on_secondary)

func bind(model: NewsroomSession) -> void:
	session = model
	session.article_changed.connect(show_article)
	session.published.connect(_show_result)

func show_article() -> void:
	if session.phase != NewsroomSession.Phase.WORK:
		return
	selected_index = -1
	popup.hide()
	%ArticleNumber.text = "МАТЕРИАЛ %02d  /  КРУГ %d" % [session.article_cursor % session.articles.size() + 1, session.article_cursor / session.articles.size() + 1]
	%SourceName.text = session.current_article().source_title
	for i in cards.size():
		cards[i].get_node("Content/Headline").text = session.option_at(i).text
	show_source()

func show_source() -> void:
	if session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement:
		return
	popup_kind = Popup.SOURCE
	var article := session.current_article()
	popup.present("ИСТОЧНИК · ТАЙМЕР ИДЁТ", article.source_title, article.source_text, "Свернуть на стол")

func _select_headline(index: int) -> void:
	if session.phase != NewsroomSession.Phase.WORK or session.awaiting_acknowledgement:
		return
	selected_index = index
	popup_kind = Popup.CONFIRM
	popup.present("ПЕРЕД ОТПРАВКОЙ В ПЕЧАТЬ", session.option_at(index).text, "Именно этот заголовок увидят читатели. Числовые последствия станут известны после публикации.\n\nВы ещё можете вернуться к вариантам или перечитать источник.", "Напечатать", "Вернуться к вариантам")

func _on_primary() -> void:
	if session.phase != NewsroomSession.Phase.WORK:
		return
	match popup_kind:
		Popup.SOURCE:
			popup.hide()
			popup_kind = Popup.NONE
			cards[0].grab_focus()
		Popup.CONFIRM:
			session.publish_headline(selected_index)
		Popup.RESULT:
			session.acknowledge_publication()

func _on_secondary() -> void:
	popup.hide()
	popup_kind = Popup.NONE
	cards[maxi(selected_index, 0)].grab_focus()

func _show_result(result: Dictionary) -> void:
	popup_kind = Popup.RESULT
	var changes := "[color=#e8bd68]Деньги: %+d $[/color]\nРепутация компании: %+d\nЛояльность государству: %+d\nВыносливость: −%.1f\n\n%s" % [result.money, result.reputation, result.loyalty, session.balance.publication_health_cost, result.explanation]
	popup.present("НАПЕЧАТАНО · ТАЙМЕР ИДЁТ", result.headline, changes, "Следующий материал")
