extends Control

enum View { MENU, INTRO, TUTORIAL, WORK, HOME, ENDING }

const LESSONS: Array[Dictionary] = [
	{"title": "Нам нужны читатели. А тебе — зарплата.", "text": "Я — главный редактор. На стол приносят письмо, рапорт или другой источник. Ты выбираешь один из трёх заголовков и подтверждаешь отправку в печать.\n\nГромкие заголовки часто приносят больше денег. Но искажение фактов бьёт по репутации компании. Точные материалы помогают удерживать доверие."},
	{"title": "Три шкалы. Три причины быть осторожнее.", "text": "Выносливость убывает во время работы и с каждой публикацией. На нуле — истощение.\n\nРепутация зависит от правдивости заголовка. Если она обнулится, разгневанные читатели сожгут офис.\n\nЛояльность государству — отдельная шкала. Критика может быть правдивой и всё равно не нравиться властям. На нуле за тобой придут сотрудники госбезопасности."},
	{"title": "Три минуты до конца смены.", "text": "Источник сначала откроется сам. Его можно сразу свернуть, а потом перечитать через записку на столе.\n\nЧтение, выбор, подтверждение и разбор результата расходуют время. Цифры влияния видны только после публикации. Иногда цена неудачного заголовка особенно велика.\n\nКогда прозвенит звонок, ты уйдёшь домой. Неподтверждённый материал останется на завтра. Esc — пауза с закрытым рабочим столом."},
	{"title": "Не забудь поесть перед сном.", "text": "После смены с тебя спишут аренду. Дома можно купить ужин или перекус, чтобы восстановить здоровье. Покупки в долг разрешены, но баланс −100 $ означает конец игры.\n\nКофе стоит денег и забирает немного здоровья. Зато следующая смена длится четыре минуты вместо трёх. Одной чашки на следующий день достаточно.\n\nКровать завершает вечер без восстановления здоровья. Сначала реши, что купить, потом ложись спать."}
]

const ENDINGS: Dictionary = {
	NewsroomSession.Ending.EXHAUSTION: ["Последняя смена", "Выносливость закончилась. Ещё один выпуск оказался важнее ужина, и организм не выдержал. Редакция завтра откроется — уже без тебя.", 2],
	NewsroomSession.Ending.OFFICE_FIRE: ["Редакция больше не печатает", "Репутация компании упала до нуля. Люди, которых обманывали ваши заголовки, собрались у офиса. К утру от редакции остались обугленные стены.", 3],
	NewsroomSession.Ending.ARREST: ["За вами уже пришли", "Лояльность государству упала до нуля. В дверь постучали сотрудники госбезопасности. Правдивость отдельных статей не стала для них оправданием.", 4],
	NewsroomSession.Ending.DEBT: ["Ночлег на картонке", "Долг достиг предела. Хозяин комнаты сменил замок, а кредиторы забрали последние вещи. Сегодня вместо кровати — картонка под навесом.", 5]
}

var session: NewsroomSession
var view: View = View.MENU
var lesson: int = 0
var paused: bool = false
var transitioning: bool = false
var _fade_tween: Tween

@onready var work: Control = %Work
@onready var home: Control = %Home
@onready var pause_panel: MessagePanel = $PausePanel

func _ready() -> void:
	theme = preload("res://Scripts/mvp_theme.gd").create()
	session = GameState.session
	session.phase_changed.connect(_on_phase_changed)
	%HUD.bind(session)
	work.bind(session)
	home.bind(session)
	%NewGame.pressed.connect(_new_run.bind(false))
	%Quit.pressed.connect(func(): get_tree().quit())
	%NarrativePrimary.pressed.connect(_narrative_next)
	%NarrativeSecondary.pressed.connect(_narrative_secondary)
	%PauseButton.pressed.connect(_toggle_pause)
	pause_panel.primary_pressed.connect(_toggle_pause)
	pause_panel.secondary_pressed.connect(_show_menu)
	get_window().min_size = Vector2i(960, 640)
	_show_menu()

func _process(delta: float) -> void:
	if view == View.WORK and not paused and not transitioning:
		session.tick_work(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and view != View.MENU:
		_toggle_pause()
		get_viewport().set_input_as_handled()
	# Editor-only shortcut for checking the evening without a three-minute wait.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		if not paused and view == View.WORK:
			session.finish_shift()

func _new_run(skip_story: bool) -> void:
	session.reset()
	lesson = 0
	if skip_story:
		session.start_shift()
	else:
		_show_view(View.INTRO)
		_set_narrative("ПРОЛОГ · ГЕРОИНЯ", "Мне нужна эта работа.", "Ещё вчера я ночевала в подворотне. Сегодня меня отмыли, посадили за стол в редакции и дали шанс заработать.\n\nНужны деньги на комнату, еду и кофе. Обратно на улицу я не хочу. Значит, придётся разобраться, какие слова здесь оплачивают — и чего эти слова стоят.", 0, "Познакомиться с боссом", "Сразу к работе")

func _narrative_next() -> void:
	match view:
		View.INTRO:
			_show_lesson()
		View.TUTORIAL:
			lesson += 1
			if lesson >= LESSONS.size():
				session.start_shift()
			else:
				_show_lesson()
		View.ENDING:
			_new_run(true)

func _narrative_secondary() -> void:
	if view == View.ENDING:
		_show_menu()
	else:
		session.start_shift()

func _show_lesson() -> void:
	_show_view(View.TUTORIAL)
	_set_narrative("ИНСТРУКТАЖ БОССА · %d / %d" % [lesson + 1, LESSONS.size()], LESSONS[lesson].title, LESSONS[lesson].text, 1, "Начать смену" if lesson == LESSONS.size() - 1 else "Дальше", "Пропустить инструктаж")

func _on_phase_changed() -> void:
	match session.phase:
		NewsroomSession.Phase.WORK:
			_show_view(View.WORK)
		NewsroomSession.Phase.HOME:
			_show_view(View.HOME)
			home.open_evening()
		NewsroomSession.Phase.ENDED:
			_show_view(View.ENDING)
			var ending: Array = ENDINGS[session.ending]
			var summary := "%s\n\nЗавершено смен: %d. Напечатано материалов: %d.\nДеньги: %d $ · репутация: %d · государство: %d." % [ending[1], session.completed_shifts, session.total_published, session.money, ceili(session.reputation), ceili(session.loyalty)]
			if not session.last_result.is_empty():
				summary += "\n\nПоследний заголовок: «%s»" % session.last_result.headline
			_set_narrative("КОНЕЦ ИСТОРИИ", ending[0], summary, ending[2], "Попробовать снова", "В главное меню")

func _show_menu() -> void:
	paused = false
	pause_panel.hide()
	_show_view(View.MENU)
	%NewGame.grab_focus()

func _show_view(next: View) -> void:
	view = next
	paused = false
	pause_panel.hide()
	%Menu.visible = view == View.MENU
	%Narrative.visible = view in [View.INTRO, View.TUTORIAL, View.ENDING]
	work.visible = view == View.WORK
	home.visible = view == View.HOME
	%HUD.visible = view in [View.WORK, View.HOME, View.ENDING]
	%PauseButton.visible = view in [View.WORK, View.HOME]
	%Location.text = {View.MENU: "НЕЗАВИСИМАЯ РЕДАКЦИЯ", View.INTRO: "НОВАЯ РАБОТА", View.TUTORIAL: "ПЕРЕД ПЕРВОЙ СМЕНОЙ", View.WORK: "РАБОЧИЙ СТОЛ", View.HOME: "СЪЁМНАЯ КОМНАТА", View.ENDING: "ПОСЛЕДНИЙ ВЫПУСК"}[view]
	if _fade_tween:
		_fade_tween.kill()
	transitioning = true
	$Fade.show()
	$Fade.modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.tween_property($Fade, "modulate:a", 0.0, 0.22)
	_fade_tween.tween_callback(func():
		$Fade.hide()
		transitioning = false
	)

func _set_narrative(tag: String, title: String, body: String, visual: int, primary: String, secondary: String) -> void:
	%NarrativeTag.text = tag
	%NarrativeTitle.text = title
	%NarrativeBody.text = body
	%NarrativeBody.scroll_to_line(0)
	%NarrativeVisual.kind = visual
	%NarrativePrimary.text = primary
	%NarrativeSecondary.text = secondary
	%NarrativePrimary.grab_focus()

func _toggle_pause() -> void:
	if view == View.MENU or transitioning:
		return
	paused = not paused
	if paused:
		pause_panel.present("ПАУЗА", "Выпуск подождёт.", "Время и выносливость остановлены.\n\nВозвращение в главное меню завершит текущую попытку. Новая игра начнётся с первой смены.", "Продолжить", "В главное меню")
	else:
		pause_panel.hide()
