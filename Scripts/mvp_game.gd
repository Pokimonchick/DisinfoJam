extends Control

enum View { MENU, INTRO, TUTORIAL, WORK, HOME, ENDING, PROFILE }
const VIEW_KEYS := ["menu", "intro", "tutorial", "work", "home", "ending", "profile"]
const AUTOSAVE_SECONDS := 5.0

const LESSONS: Array[Dictionary] = [
	{"title": "Нам нужны читатели. А тебе — зарплата.", "text": "На стол приносят письмо, рапорт или другой источник. Ты выбираешь один из трёх заголовков и подтверждаешь печать. Громкие слова часто приносят больше денег. Искажения бьют по репутации, точные материалы укрепляют доверие.\n\nЗаголовки одного направления подряд дают комбо: факты, сенсации или поддержка власти. Слева на столе видны серия и множитель. Он усиливает деньги и изменения репутации и лояльности — в том числе штрафы! Другое направление или новая смена сбрасывает серию."},
	{"title": "Три шкалы. Три причины быть осторожнее.", "text": "Выносливость убывает во время работы и с каждой публикацией. На нуле — истощение.\n\nРепутация зависит от правдивости заголовка. Если она обнулится, разгневанные читатели сожгут офис.\n\nЛояльность государству — отдельная шкала. Критика может быть правдивой и всё равно не нравиться властям. На нуле за тобой придут сотрудники госбезопасности."},
	{"title": "Три минуты до конца смены.", "text": "Источник сначала откроется сам. Его можно сразу свернуть, а потом перечитать через записку на столе.\n\nЧтение, выбор, подтверждение и разбор результата расходуют время. Цифры влияния видны только после публикации. Иногда цена неудачного заголовка особенно велика.\n\nКогда прозвенит звонок, ты уйдёшь домой. Неподтверждённый материал останется на завтра. Esc — пауза с закрытым рабочим столом."},
	{"title": "Не забудь поесть перед сном.", "text": "После смены спишут аренду. Дома наведи мышь на холодильник: дверца откроется. Нажми, чтобы купить еду и восстановить силы. Цена указана под холодильником. Покупки в долг разрешены до −100 $.\n\nНа кухонном столе можно купить одну чашку кофе с собой. На смене сверни источник и нажми на чашку: только тогда получишь дополнительную минуту ценой 15 выносливости. Кофе исчезнет, оставив след на бумаге. Невыпитая чашка останется с тобой.\n\nКровать слева завершает вечер и восстанавливает 10 выносливости. Если сил мало, сначала поешь, потом ложись спать."}
]

const ENDINGS: Dictionary = {
	NewsroomSession.Ending.EXHAUSTION: ["Последняя смена", "Выносливость закончилась. Ещё один выпуск оказался важнее ужина, и организм не выдержал. Редакция завтра откроется — уже без тебя.", 2],
	NewsroomSession.Ending.OFFICE_FIRE: ["Редакция больше не печатает", "Репутация компании упала до нуля. Люди, которых обманывали ваши заголовки, собрались у офиса. К утру от редакции остались обугленные стены.", 3],
	NewsroomSession.Ending.ARREST: ["За вами уже пришли", "Лояльность государству упала до нуля. В дверь постучали сотрудники госбезопасности. Правдивость отдельных статей не стала для них оправданием.", 4],
	NewsroomSession.Ending.DEBT: ["Ночлег на картонке", "Долг достиг предела. Хозяин комнаты сменил замок, а кредиторы забрали последние вещи. Сегодня вместо кровати — картонка под навесом.", 5],
	NewsroomSession.Ending.VICTORY: ["Теперь у меня есть выбор", "Я выдержала эти смены и собрала нужную сумму. Теперь у меня есть запас на новую жизнь. Впервые за долгое время я могу решить сама, что делать дальше.", 0],
	NewsroomSession.Ending.GOAL_MISSED: ["Денег не хватило", "Отведённые дни закончились. Я удержалась на работе, но накопить нужную сумму не смогла. Пока начать новую жизнь не получится.", 0]
}

var session: NewsroomSession
var view: View = View.MENU
var lesson: int = 0
var paused: bool = false
var transitioning: bool = false
var _fade_tween: Tween
var _fatigue_amount: float = 0.0
var _fatigue_time: float = 0.0
var _run_active: bool = false
var _restoring: bool = false
var _save_queued: bool = false
var _autosave_elapsed: float = 0.0
var _loaded_document: Dictionary = {}

@onready var work: Control = %Work
@onready var home: Control = %Home
@onready var pause_panel: MessagePanel = $PausePanel
@onready var fatigue_overlay: ColorRect = $FatigueOverlay

func _ready() -> void:
	theme = preload("res://Scripts/mvp_theme.gd").create()
	session = GameState.session
	GameState.save_store.validator = _validate_save
	GameState.save_requested.connect(_queue_save)
	session.phase_changed.connect(_on_phase_changed)
	session.changed.connect(_refresh_goal)
	session.save_requested.connect(_queue_save)
	%HUD.bind(session)
	work.bind(session)
	home.bind(session)
	work.view_changed.connect(_queue_save)
	%NewGame.pressed.connect(_show_profile_setup)
	%ContinueGame.pressed.connect(_continue_run)
	%StartStory.pressed.connect(_start_named_run)
	%CancelStory.pressed.connect(_show_menu)
	%PlayerName.text_submitted.connect(func(_text: String): _start_named_run())
	%PlayerName.text_changed.connect(func(value: String): %StartStory.disabled = value.strip_edges().is_empty())
	%Quit.pressed.connect(_quit_game)
	%QuitWithoutSave.confirmed.connect(func(): get_tree().quit())
	%NarrativePrimary.pressed.connect(_narrative_next)
	%NarrativeSecondary.pressed.connect(_narrative_secondary)
	%PauseButton.pressed.connect(_toggle_pause)
	pause_panel.primary_pressed.connect(_toggle_pause)
	pause_panel.secondary_pressed.connect(_show_menu)
	get_window().min_size = Vector2i(960, 640)
	get_tree().auto_accept_quit = false
	_show_menu()

func _process(delta: float) -> void:
	if view == View.WORK and not paused and not transitioning:
		session.tick_work(delta)
	elif view == View.HOME and not paused and not transitioning:
		home.tick_home(delta)
	_update_fatigue(delta)
	if _run_active and view in [View.WORK, View.HOME] and not paused and not transitioning:
		_autosave_elapsed += delta
		if _autosave_elapsed >= AUTOSAVE_SECONDS:
			_queue_save()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_queue_save()

func _update_fatigue(delta: float) -> void:
	if view != View.WORK:
		_fatigue_amount = 0.0
		_fatigue_time = 0.0
		fatigue_overlay.hide()
		return
	if paused or transitioning:
		fatigue_overlay.hide()
		return
	var threshold := maxf(0.001, session.balance.maximum_stat * session.balance.fatigue_threshold)
	var target := clampf(1.0 - session.health / threshold, 0.0, 1.0) * session.balance.fatigue_strength
	_fatigue_amount = move_toward(_fatigue_amount, target, delta * 0.8)
	_fatigue_time += delta
	fatigue_overlay.visible = _fatigue_amount > 0.001
	var effect := fatigue_overlay.material as ShaderMaterial
	effect.set_shader_parameter("intensity", _fatigue_amount)
	effect.set_shader_parameter("effect_time", _fatigue_time)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and view == View.PROFILE:
		_show_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and view != View.MENU:
		_toggle_pause()
		get_viewport().set_input_as_handled()
	# Editor-only shortcut for checking the evening without a three-minute wait.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		if not paused and view == View.WORK:
			session.finish_shift()

func _new_run(skip_story: bool, entered_name: String = "Редактор") -> void:
	_run_active = false
	_loaded_document = {}
	session.reset()
	session.player_name = entered_name.strip_edges().left(24)
	session.player_id = Crypto.new().generate_random_bytes(16).hex_encode()
	session.run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	GameState.restore_save_sections({})
	_run_active = true
	lesson = 0
	if skip_story:
		session.start_shift()
	else:
		_show_intro()
	_queue_save()

func _show_intro() -> void:
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
			_show_profile_setup()

func _narrative_secondary() -> void:
	if view == View.ENDING:
		_show_menu()
	else:
		session.start_shift()

func _show_lesson() -> void:
	_show_view(View.TUTORIAL)
	var body: String = LESSONS[lesson].text
	if lesson == 2:
		body += "\n\nВ одном выпуске помещается до %d публикаций. Когда места больше нет, сдай выпуск и отправляйся домой. Остальные материалы останутся в очереди." % session.balance.publication_limit
	_set_narrative("ИНСТРУКТАЖ БОССА · %d / %d" % [lesson + 1, LESSONS.size()], LESSONS[lesson].title, body, 1, "Начать смену" if lesson == LESSONS.size() - 1 else "Дальше", "Пропустить инструктаж")
	_queue_save()

func _on_phase_changed() -> void:
	if _restoring:
		return
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
			if session.ending in [NewsroomSession.Ending.VICTORY, NewsroomSession.Ending.GOAL_MISSED]:
				summary += "\n\nЦель: %d смен и %d $ после оплаты аренды." % [session.campaign_days, session.campaign_money]
			_set_narrative("КАМПАНИЯ ПРОЙДЕНА" if session.campaign_completed else "КОНЕЦ ИСТОРИИ", ending[0], summary, ending[2], "Новая история", "В главное меню")
	_refresh_goal()

func _show_menu() -> void:
	if _run_active and not _save_progress():
		return
	_run_active = false
	paused = false
	pause_panel.hide()
	_show_view(View.MENU)
	_refresh_menu()
	if not %ContinueGame.disabled:
		%ContinueGame.grab_focus()
	else:
		%NewGame.grab_focus()

func _show_view(next: View) -> void:
	view = next
	paused = false
	pause_panel.hide()
	%Menu.visible = view == View.MENU
	%ProfileSetup.visible = view == View.PROFILE
	%Narrative.visible = view in [View.INTRO, View.TUTORIAL, View.ENDING]
	work.visible = view == View.WORK
	home.visible = view == View.HOME
	%HUD.visible = view in [View.WORK, View.HOME, View.ENDING]
	%PauseButton.visible = view in [View.WORK, View.HOME]
	%Location.text = {View.MENU: "НЕЗАВИСИМАЯ РЕДАКЦИЯ", View.INTRO: "НОВАЯ РАБОТА", View.TUTORIAL: "ПЕРЕД ПЕРВОЙ СМЕНОЙ", View.WORK: "РАБОЧИЙ СТОЛ", View.HOME: "СЪЁМНАЯ КОМНАТА", View.ENDING: "ПОСЛЕДНИЙ ВЫПУСК", View.PROFILE: "НОВОЕ ПРОХОЖДЕНИЕ"}[view]
	_refresh_goal()
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
	if view in [View.MENU, View.PROFILE] or transitioning:
		return
	paused = not paused
	if paused:
		_save_progress()
		pause_panel.present("ПАУЗА", "Выпуск подождёт.", "Время и выносливость остановлены.\n\nПрогресс сохраняется автоматически. После выхода в меню можно продолжить с этого места.", "Продолжить", "Сохранить и в меню")
	else:
		pause_panel.hide()

func _show_profile_setup() -> void:
	if _run_active and not _save_progress():
		return
	_run_active = false
	_show_view(View.PROFILE)
	%NewRunWarning.text = "Начало новой истории заменит текущее сохранение." if GameState.save_store.exists() else "Прогресс будет сохраняться автоматически."
	%StartStory.disabled = %PlayerName.text.strip_edges().is_empty()
	%PlayerName.grab_focus()

func _start_named_run() -> void:
	var entered_name: String = %PlayerName.text.strip_edges()
	if entered_name.is_empty():
		%PlayerName.grab_focus()
		return
	_new_run(false, entered_name)

func _refresh_goal() -> void:
	%CampaignGoal.visible = view in [View.WORK, View.HOME, View.ENDING]
	%CampaignGoal.text = "%s · Цель: %d смен и %d $" % [session.player_name, session.campaign_days, session.campaign_money]

func _refresh_menu() -> void:
	var document: Dictionary = GameState.save_store.load_document()
	%ContinueGame.disabled = document.is_empty()
	%Description.text = "Продержись %d смен и накопи %d $.\nРепутация, государство и собственная жизнь.\nЗа каждое слово кто-нибудь заплатит." % [session.balance.campaign_days, session.balance.campaign_money]
	%SaveSummary.text = "Сохранений пока нет."
	if document.is_empty() and GameState.save_store.exists():
		%SaveSummary.text = "Сохранение недоступно."
	if not document.is_empty():
		var data: Dictionary = document.sections
		%SaveSummary.text = "%s · день %d · %d $" % [data.profile.name, data.run.get("day", 0), data.run.get("money", 0)]
		%ContinueGame.text = "ПОСМОТРЕТЬ ИТОГ" if data.run.phase == "ended" else "ПРОДОЛЖИТЬ"
		%PlayerName.text = data.profile.name
	else:
		%ContinueGame.text = "ПРОДОЛЖИТЬ"
	if not GameState.save_store.error_message.is_empty():
		%SaveSummary.text += "\n" + GameState.save_store.error_message

func _continue_run() -> void:
	var document: Dictionary = GameState.save_store.load_document()
	if document.is_empty():
		_refresh_menu()
		return
	_restoring = true
	_run_active = false
	if not NewsroomSaveData.restore(session, document.sections):
		_restoring = false
		return
	_loaded_document = document
	GameState.restore_save_sections(document.sections.get("extensions", {}))
	var presentation: Dictionary = document.sections.get("presentation", {})
	lesson = clampi(int(presentation.get("lesson", 0)), 0, LESSONS.size() - 1)
	_restoring = false
	if session.phase == NewsroomSession.Phase.IDLE:
		if presentation.get("screen", "intro") == "tutorial":
			_show_lesson()
		else:
			_show_intro()
	else:
		_on_phase_changed()
		if session.phase == NewsroomSession.Phase.WORK:
			work.restore_presentation(presentation.get("newsroom", {}))
	_run_active = true
	_autosave_elapsed = 0.0
	%SaveNotice.text = GameState.save_store.error_message
	%SaveNotice.visible = not %SaveNotice.text.is_empty()

func _queue_save() -> void:
	if not _run_active or _restoring or _save_queued:
		return
	_save_queued = true
	_flush_save.call_deferred()

func _flush_save() -> void:
	_save_queued = false
	if _run_active and not _restoring:
		_save_progress()

func _save_progress() -> bool:
	if not _run_active or _restoring:
		return true
	var sections := NewsroomSaveData.capture(session)
	sections["presentation"] = {"screen": VIEW_KEYS[view], "lesson": lesson, "newsroom": work.capture_presentation()}
	sections["extensions"] = GameState.capture_save_sections()
	var document := _loaded_document.duplicate(true)
	document["sections"] = SaveRepository.merge_sections(document.get("sections", {}), sections)
	# Registered extensions return complete snapshots; removed items must stay removed.
	document.sections["extensions"] = sections.extensions
	var success: bool = GameState.save_store.write_document(document)
	_autosave_elapsed = 0.0
	%SaveNotice.text = GameState.save_store.error_message
	%SaveNotice.visible = not success
	if success:
		_loaded_document = document
	return success

func _quit_game() -> void:
	if _save_progress():
		get_tree().quit()
	else:
		%QuitWithoutSave.popup_centered()

static func _validate_save(sections: Dictionary) -> bool:
	if not NewsroomSaveData.validate(sections):
		return false
	var presentation: Variant = sections.get("presentation", {})
	if not presentation is Dictionary or not presentation.get("newsroom", {}) is Dictionary:
		return false
	if not presentation.get("lesson", 0) is int and not presentation.get("lesson", 0) is float:
		return false
	var newsroom: Dictionary = presentation.get("newsroom", {})
	if not newsroom.get("selected_index", -1) is int and not newsroom.get("selected_index", -1) is float:
		return false
	var extensions: Variant = sections.get("extensions", {})
	if not extensions is Dictionary:
		return false
	for value in extensions.values():
		if not value is Dictionary:
			return false
	return true
