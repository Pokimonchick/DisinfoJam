extends Control

enum View { MENU, INTRO, TUTORIAL, WORK, HOME, ENDING, PROFILE, STORY }
const VIEW_KEYS := ["menu", "intro", "tutorial", "work", "home", "ending", "profile", "story"]
const CHAPTER := preload("res://Data/chapter_one.gd")
const AUTOSAVE_SECONDS := 5.0
const INTERFACE_LESSONS := preload("res://Data/interface_lessons.gd")
const FINANCE_NOTEBOOK := preload("res://Scenes/finance_notebook.tscn")
const LOW_STAMINA_WARNING := 10.0
const HEROINE_PORTRAIT := preload("res://Assets/Characters/Mask group (22).png")

const ENDINGS: Dictionary = {
	NewsroomSession.Ending.EXHAUSTION: ["Последняя смена", "Выносливость закончилась. Ещё один выпуск оказался важнее ужина, и организм не выдержал. Редакция завтра откроется — уже без тебя.", 2],
	NewsroomSession.Ending.OFFICE_FIRE: ["Редакция больше не печатает", "Репутация компании упала до нуля. Люди, которых обманывали ваши заголовки, собрались у офиса. К утру от редакции остались обугленные стены.", 3],
	NewsroomSession.Ending.ARREST: ["За вами уже пришли", "Лояльность государству упала до нуля. В дверь постучали сотрудники госбезопасности. Правдивость отдельных статей не стала для них оправданием.", 4],
	NewsroomSession.Ending.DEBT: ["Ночлег на картонке", "Долг достиг предела. Хозяин комнаты сменил замок, а кредиторы забрали последние вещи. Сегодня вместо кровати — картонка под навесом.", 5],
	NewsroomSession.Ending.QUALIFICATION_FIRED: ["Последняя корректура", "Квалификация упала до нуля. Начальник возвращает лист с пропущенными ошибками и забирает красный карандаш. «Больше я не могу доверять тебе выпуск». Завтра твоё место займёт другой редактор.", 6],
	NewsroomSession.Ending.VICTORY: ["Первая неделя позади", "Я прошла первую рабочую неделю. Прошлое пока не вернулось, но теперь у меня есть первая зацепка.\n\nСпасибо за прохождение демо «До печати». Первая глава завершена. История героини продолжится за пределами этой версии.", 0]
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
var _story_id: String = ""
var _story_page: int = 0
var _seen_stories: Array[String] = []
var _tutorial_stage := ""
var _tutorial_step := 0
var _work_tutorial_done := false
var _home_tutorial_done := false
var _pencil_tutorial_done := false
var _stamina_warning_day := 0
var _notebook: Control
var _pending_deductions: Array[int] = []
var _combo_demonstration := false

@onready var work: Control = %Work
@onready var home: Control = %Home
@onready var pause_panel: MessagePanel = $PausePanel
@onready var settings_panel: SettingsPanel = $SettingsPanel
@onready var fatigue_overlay: ColorRect = $FatigueOverlay
@onready var tutorial: Control = $Tutorial
@onready var stamina_warning: MessagePanel = $StaminaWarning

func _ready() -> void:
	theme = preload("res://Scripts/mvp_theme.gd").create()
	session = GameState.session
	GameState.save_store.validator = _validate_save
	GameState.save_requested.connect(_queue_save)
	session.phase_changed.connect(_on_phase_changed)
	session.changed.connect(_refresh_goal)
	session.save_requested.connect(_queue_save)
	session.transaction_recorded.connect(_on_transaction)
	%HUD.bind(session)
	work.bind(session)
	home.bind(session)
	home.notebook_requested.connect(_open_notebook)
	work.view_changed.connect(_queue_save)
	work.view_changed.connect(_maybe_begin_pencil_tutorial)
	work.pause_requested.connect(_toggle_pause)
	%NewGame.pressed.connect(_show_profile_setup)
	%MenuSettings.pressed.connect(_open_settings)
	%ContinueGame.pressed.connect(_continue_run)
	%StartStory.pressed.connect(_start_campaign)
	%CancelStory.pressed.connect(_show_menu)
	%Quit.pressed.connect(_quit_game)
	%QuitWithoutSave.confirmed.connect(func(): get_tree().quit())
	%NarrativePrimary.pressed.connect(_advance_dialogue)
	%NarrativeSecondary.pressed.connect(_narrative_secondary)
	%NarrativeBack.pressed.connect(_narrative_back)
	tutorial.next_requested.connect(_tutorial_next)
	tutorial.previous_requested.connect(_tutorial_back)
	tutorial.skip_requested.connect(_finish_tutorial)
	stamina_warning.primary_pressed.connect(_dismiss_stamina_warning)
	stamina_warning.secondary_pressed.connect(_rest_after_warning)
	stamina_warning.get_node("Dim").color.a = 0.75
	stamina_warning.get_node("Center/Paper").add_theme_stylebox_override("panel", theme.get_stylebox("panel", "TooltipPanel"))
	stamina_warning.body_label.custom_minimum_size.y = 128
	%PauseButton.pressed.connect(_toggle_pause)
	pause_panel.primary_pressed.connect(_toggle_pause)
	pause_panel.secondary_pressed.connect(_show_menu)
	pause_panel.settings_pressed.connect(_open_settings)
	settings_panel.closed.connect(_on_settings_closed)
	get_window().min_size = Vector2i(960, 640)
	get_tree().auto_accept_quit = false
	_show_menu()

func _process(delta: float) -> void:
	if view == View.WORK and not paused and not transitioning and not _interface_blocked() and not work.evaluating_publication:
		_check_stamina_warning()
	if view == View.WORK and not paused and not transitioning and not _interface_blocked() and not work.evaluating_publication:
		session.tick_work(delta)
	elif view == View.HOME and not paused and not transitioning and not _interface_blocked():
		home.tick_home(delta)
	if view == View.HOME and not transitioning and not paused and not _pending_deductions.is_empty():
		for amount in _pending_deductions:
			_show_money_delta(amount)
		_pending_deductions.clear()
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
	if paused or transitioning or _interface_blocked():
		fatigue_overlay.hide()
		return
	var threshold := maxf(0.001, session.balance.maximum_stat * session.balance.fatigue_threshold)
	var target := clampf(1.0 - session.health / threshold, 0.0, 1.0) * session.balance.fatigue_strength
	_fatigue_amount = move_toward(_fatigue_amount, target, delta * 0.8)
	_fatigue_time += delta
	fatigue_overlay.visible = _fatigue_amount > 0.001
	if not fatigue_overlay.visible:
		return
	var effect := fatigue_overlay.material as ShaderMaterial
	effect.set_shader_parameter("intensity", _fatigue_amount)
	effect.set_shader_parameter("effect_time", _fatigue_time)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		get_window().mode = Window.MODE_MAXIMIZED if get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and settings_panel.visible:
		settings_panel.close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not paused:
		if is_instance_valid(_notebook):
			_notebook._close()
			get_viewport().set_input_as_handled()
			return
		if stamina_warning.visible:
			_dismiss_stamina_warning()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") and view == View.PROFILE:
		_show_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and view != View.MENU:
		_toggle_pause()
		get_viewport().set_input_as_handled()
	# Editor-only shortcut for checking the evening.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		if not paused and not _interface_blocked() and view == View.WORK:
			session.finish_shift()

func _new_run(skip_story: bool) -> void:
	_run_active = false
	_loaded_document = {}
	_story_id = ""
	_story_page = 0
	_seen_stories.clear()
	_tutorial_stage = ""
	_tutorial_step = 0
	_work_tutorial_done = skip_story
	_home_tutorial_done = skip_story
	_pencil_tutorial_done = false
	_stamina_warning_day = 0
	_pending_deductions.clear()
	$MoneyDelta.clear()
	session.reset()
	session.player_name = NewsroomSession.CAMPAIGN_HERO_NAME
	session.player_id = Crypto.new().generate_random_bytes(16).hex_encode()
	session.run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	GameState.restore_save_sections({})
	work.restore_presentation({})
	_run_active = true
	lesson = 0
	if skip_story:
		session.start_shift()
	else:
		_show_intro()
	_queue_save()

func _show_intro() -> void:
	_show_story("intro")

func _show_story(episode_id: String, page: int = 0) -> void:
	_story_id = episode_id
	_story_page = page
	var entry: Dictionary = CHAPTER.EPISODES[episode_id][page]
	_show_view(View.INTRO if episode_id == "intro" else View.STORY)
	_set_narrative(entry.tag, entry.title, entry.body.replace("{name}", NewsroomSession.CAMPAIGN_HERO_NAME), entry.visual, entry.next, "Сразу к работе" if episode_id == "intro" else "")
	%NarrativeBack.visible = true
	%NarrativeBack.disabled = page == 0
	_queue_save()

func _advance_story() -> void:
	if _story_page + 1 < CHAPTER.EPISODES[_story_id].size():
		_show_story(_story_id, _story_page + 1)
		return
	var finished := _story_id
	if not finished in _seen_stories:
		_seen_stories.append(finished)
	_story_id = ""
	_story_page = 0
	if finished == "intro":
		_show_lesson()
	else:
		_on_phase_changed()
	_queue_save()

func _narrative_next() -> void:
	match view:
		View.INTRO, View.STORY:
			_advance_story()
		View.TUTORIAL:
			_show_lesson()
		View.ENDING:
			_show_profile_setup()

func _advance_dialogue() -> void:
	if not %NarrativeBody.finish_reveal():
		_narrative_next()

func _narrative_secondary() -> void:
	if view == View.ENDING:
		_show_menu()
	else:
		_story_id = ""
		_story_page = 0
		_work_tutorial_done = true
		_home_tutorial_done = true
		session.start_shift()

func _show_lesson() -> void:
	session.start_shift()
	_queue_save()

func _on_phase_changed() -> void:
	if _restoring:
		return
	match session.phase:
		NewsroomSession.Phase.WORK:
			var episode_id: String = CHAPTER.episode_for_day(session.day)
			if not episode_id.is_empty() and not episode_id in _seen_stories:
				_show_story(episode_id)
			else:
				_show_view(View.WORK)
				if session.day == 1 and not _work_tutorial_done:
					_begin_tutorial.call_deferred("work")
				elif session.proofreading_unlocked and not _pencil_tutorial_done:
					_maybe_begin_pencil_tutorial()
		NewsroomSession.Phase.HOME:
			var episode_id: String = CHAPTER.episode_for_evening(session.day)
			if not episode_id.is_empty() and not episode_id in _seen_stories:
				_show_story(episode_id)
				return
			_show_view(View.HOME)
			home.open_evening()
			if not _home_tutorial_done:
				_begin_tutorial.call_deferred("home")
		NewsroomSession.Phase.ENDED:
			if session.campaign_completed and not "finale" in _seen_stories:
				_show_story("finale")
				return
			_show_view(View.ENDING)
			var ending: Array = ENDINGS[session.ending]
			var summary := "%s\n\nЗавершено смен: %d. Напечатано материалов: %d.\nДеньги: %d $ · репутация: %d · государство: %d." % [ending[1], session.completed_shifts, session.total_published, session.money, ceili(session.reputation), ceili(session.loyalty)]
			if not session.last_result.is_empty():
				summary += "\n\nПоследний заголовок: «%s»" % session.last_result.headline
			_set_narrative("КОНЕЦ ПЕРВОЙ ГЛАВЫ" if session.campaign_completed else "КОНЕЦ ИСТОРИИ", ending[0], summary, ending[2], "Новая история", "В главное меню")
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
	match view:
		View.HOME:
			$Audio/HomeMusic.play()
		View.ENDING:
			AudioManager.stop_music()
		_:
			$Audio/WorkMusic.play()
	paused = false
	tutorial.hide()
	stamina_warning.hide()
	_clear_combo_demonstration()
	if is_instance_valid(_notebook):
		_notebook.queue_free()
		_notebook = null
	pause_panel.hide()
	settings_panel.hide()
	_update_interface_lock()
	%Menu.visible = view in [View.MENU, View.PROFILE]
	%ProfileSetup.visible = view == View.PROFILE
	%Narrative.visible = view in [View.INTRO, View.TUTORIAL, View.ENDING, View.STORY]
	work.visible = view == View.WORK
	home.visible = view == View.HOME
	$Padding.visible = view not in [View.WORK, View.MENU, View.PROFILE]
	%HUD.visible = view in [View.HOME, View.ENDING]
	%PauseButton.visible = view in [View.WORK, View.HOME, View.INTRO, View.TUTORIAL, View.STORY]
	%Location.text = {View.MENU: "НЕЗАВИСИМАЯ РЕДАКЦИЯ", View.INTRO: "ГЛАВА I · АМНЕЗИЯ", View.TUTORIAL: "ПЕРЕД ПЕРВОЙ СМЕНОЙ", View.WORK: "РАБОЧИЙ СТОЛ", View.HOME: "СЪЁМНАЯ КОМНАТА", View.ENDING: "ИТОГИ НЕДЕЛИ" if session.campaign_completed else "ПОСЛЕДНИЙ ВЫПУСК", View.PROFILE: "НОВОЕ ПРОХОЖДЕНИЕ", View.STORY: "ГЛАВА I · АМНЕЗИЯ"}[view]
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
	%NarrativeBack.hide()
	%NarrativeBody.stop_reveal()
	%NarrativeTag.text = tag
	%NarrativeTitle.text = title
	if visual in [0, 1] and view in [View.INTRO, View.STORY]:
		%NarrativeBody.reveal(body, DialogueReveal.Speaker.HEROINE if visual == 0 else DialogueReveal.Speaker.BOSS)
	else:
		%NarrativeBody.text = body
		%NarrativeBody.visible_characters = -1
		%NarrativeBody.scroll_to_line(0)
	%NarrativeVisual.kind = visual
	%NarrativeVisual.sprite = HEROINE_PORTRAIT if visual == 0 else null
	%NarrativePrimary.text = primary
	%NarrativeSecondary.text = secondary
	%NarrativeSecondary.visible = not secondary.is_empty()
	%NarrativePrimary.grab_focus()

func _toggle_pause() -> void:
	if view in [View.MENU, View.PROFILE] or transitioning:
		return
	paused = not paused
	_update_interface_lock()
	if paused:
		_save_progress()
		pause_panel.present("ПАУЗА", "Выпуск подождёт.", "Выносливость не расходуется.\n\nПрогресс сохраняется автоматически. После выхода в меню можно продолжить с этого места.", "Продолжить", "Сохранить и в меню", true)
	else:
		pause_panel.hide()
		if tutorial.visible:
			tutorial.get_node("%Next").grab_focus()


func _open_settings() -> void:
	settings_panel.present()
	_pause_dialogue_reveal()


func _on_settings_closed() -> void:
	_pause_dialogue_reveal()
	if paused:
		pause_panel.settings_button.grab_focus()
	else:
		%MenuSettings.grab_focus()


func _narrative_back() -> void:
	if view in [View.INTRO, View.STORY] and _story_page > 0:
		_show_story(_story_id, _story_page - 1)


func _interface_blocked() -> bool:
	return tutorial.visible or stamina_warning.visible or is_instance_valid(_notebook)


func _update_interface_lock() -> void:
	_pause_dialogue_reveal()
	var blocked := paused or _interface_blocked()
	if blocked:
		work.stamp.cancel_interaction()
	work.process_mode = Node.PROCESS_MODE_DISABLED if blocked else Node.PROCESS_MODE_INHERIT
	home.process_mode = Node.PROCESS_MODE_DISABLED if blocked else Node.PROCESS_MODE_INHERIT
	# Freeze desk parallax too; the spotlight must remain on the explained item.
	work.get_node("Canvas").motion_enabled = not blocked

func _pause_dialogue_reveal() -> void:
	var blocked := paused or settings_panel.visible
	%NarrativeBody.set_reveal_paused(blocked)
	tutorial.get_node("%Explanation").set_reveal_paused(blocked)


func _begin_tutorial(stage: String) -> void:
	if (stage in ["work", "pencil"] and view != View.WORK) or (stage == "home" and view != View.HOME):
		return
	if stage == "pencil" and (_pencil_tutorial_done or session.awaiting_acknowledgement or work.popup.visible or work.get("_next_source") != null or tutorial.visible):
		return
	if _tutorial_stage != stage:
		_tutorial_step = 0
	_tutorial_stage = stage
	if stage in ["work", "pencil"]:
		work.get_node("%Drawer").set_expanded(true, false)
		# The desk freezes during lessons; its source must already be readable.
		work._animate_source(false)
	_present_tutorial_step()


func _maybe_begin_pencil_tutorial() -> void:
	if _restoring or view != View.WORK or not session.proofreading_unlocked or _pencil_tutorial_done or session.awaiting_acknowledgement or work.popup.visible or work.get("_next_source") != null or tutorial.visible:
		return
	# The desk emits this again after an acknowledged result shows its next source.
	_begin_tutorial.call_deferred("pencil")


func _present_tutorial_step() -> void:
	var steps := _tutorial_steps()
	_tutorial_step = clampi(_tutorial_step, 0, steps.size() - 1)
	var step: Dictionary = steps[_tutorial_step]
	var targets: Array[Control] = []
	if _tutorial_stage in ["work", "pencil"]:
		_clear_combo_demonstration()
		work._hide_choices(false)
		if step.target == "choices":
			work._open_choices(false)
			targets.assign(work.cards)
		elif step.target in ["health", "reputation", "loyalty", "qualification"]:
			var stat: String = {"health": "Health", "reputation": "Reputation", "loyalty": "Loyalty", "qualification": "Qualification"}[step.target]
			var panel := "Canvas/Drawer/SlidingPanel/"
			for suffix in ["Title", "Value", "Bar", "Help"]:
				targets.append(work.get_node(panel + stat + suffix))
		else:
			var paths := {"source": "%SourceText", "headline": "%HeadlineField", "stamp": "%Stamp", "publish": "%StampArea", "coffee": "%Coffee", "finish": "%FinishShift", "combo": "%ComboBurst", "pencil": "Canvas/World/Pencil", "eraser": "Canvas/World/Eraser"}
			targets.append(work.get_node(paths[step.target]))
			if step.target == "source":
				targets.append(work.get_node("%SourceTitle"))
			if step.target == "combo":
				if work._combo_tween:
					work._combo_tween.kill()
				work.get_node("%Combo").text = "КОМБО ×%.2f" % session.combo_multiplier(2)
				work.get_node("%ComboDetail").text = "ФАКТЫ · 2 ПОДРЯД · ПРИМЕР"
				work.combo_burst.modulate.a = 1.0
				work.combo_burst.scale = Vector2.ONE
				work.combo_burst.show()
				_combo_demonstration = true
	else:
		var paths := {"meal": "%Meal", "coffee": "%Coffee", "notebook": "%Notebook", "bed": "%Bed"}
		targets.append(%HUD.get_node("%Money") if step.target == "money" else home.get_node(paths[step.target]))
	var heroine := _tutorial_stage == "home"
	tutorial.present("НИКОЛА КОКО · ПРО СЕБЯ" if heroine else "БОСС", step.text, targets, _tutorial_step, steps.size(), heroine, "Осмотреть комнату" if heroine else "Начать работу")
	_update_interface_lock()
	_queue_save()


func _tutorial_next() -> void:
	var count := _tutorial_steps().size()
	if _tutorial_step + 1 >= count:
		_finish_tutorial()
	else:
		_tutorial_step += 1
		_present_tutorial_step()


func _tutorial_steps() -> Array[Dictionary]:
	match _tutorial_stage:
		"work":
			return INTERFACE_LESSONS.work(session.balance)
		"pencil":
			return INTERFACE_LESSONS.pencil()
	return INTERFACE_LESSONS.home(session.balance)


func _tutorial_back() -> void:
	if _tutorial_step > 0:
		_tutorial_step -= 1
		_present_tutorial_step()


func _finish_tutorial() -> void:
	if _tutorial_stage == "work":
		_work_tutorial_done = true
		work._hide_choices(false)
	elif _tutorial_stage == "pencil":
		_pencil_tutorial_done = true
	else:
		_home_tutorial_done = true
	_tutorial_stage = ""
	_tutorial_step = 0
	tutorial.hide()
	_clear_combo_demonstration()
	_update_interface_lock()
	_queue_save()


func _clear_combo_demonstration() -> void:
	if _combo_demonstration:
		_combo_demonstration = false
		work.combo_burst.hide()
		work._shown_combo_count = -1
		work._shown_combo_type = -1
		work._refresh_combo()


func _check_stamina_warning() -> void:
	if session.phase != NewsroomSession.Phase.WORK or session.health > LOW_STAMINA_WARNING or _stamina_warning_day == session.day:
		return
	# Publication feedback is its own modal. Warn after it has been read.
	if session.awaiting_acknowledgement or work.popup.visible:
		return
	_stamina_warning_day = session.day
	stamina_warning.present("ПОРА ПЕРЕДОХНУТЬ", "Силы на исходе", "Выносливости осталось мало. Сдай выпуск и вернись домой, чтобы поесть и отдохнуть.\n\nМожно закрыть это предупреждение и продолжить работу. При нуле сил наступит истощение.", "Продолжить работу", "Сдать выпуск")
	_update_interface_lock()
	_queue_save()


func _dismiss_stamina_warning() -> void:
	stamina_warning.hide()
	_update_interface_lock()
	_queue_save()


func _rest_after_warning() -> void:
	_dismiss_stamina_warning()
	session.finish_shift()


func _open_notebook() -> void:
	if view != View.HOME or paused or _interface_blocked():
		return
	_notebook = FINANCE_NOTEBOOK.instantiate()
	_notebook.z_index = 128
	add_child(_notebook)
	_notebook.open(session.finances, session.day)
	_notebook.closed.connect(_on_notebook_closed)
	_update_interface_lock()


func _on_notebook_closed() -> void:
	_notebook = null
	_update_interface_lock()
	home.get_node("%Notebook").grab_focus()


func _on_transaction(entry: Dictionary) -> void:
	if _restoring or entry.amount >= 0:
		return
	if entry.kind == "rent":
		_pending_deductions.append(entry.amount)
	elif view == View.HOME:
		_show_money_delta.call_deferred(entry.amount)


func _show_money_delta(amount: int) -> void:
	if view != View.HOME:
		return
	var money_label: Control = %HUD.get_node("%Money")
	$MoneyDelta.play(amount, money_label.get_global_rect())


func _show_profile_setup() -> void:
	if _run_active and not _save_progress():
		return
	_run_active = false
	_show_view(View.PROFILE)
	%NewRunWarning.text = "Начало новой истории заменит текущее сохранение." if GameState.save_store.exists() else "Прогресс будет сохраняться автоматически."
	%StartStory.grab_focus()

func _start_campaign() -> void:
	_new_run(false)

func _refresh_goal() -> void:
	%CampaignGoal.visible = view in [View.WORK, View.HOME, View.ENDING]
	%CampaignGoal.text = "%s · Первая неделя: %d / %d смен" % [NewsroomSession.CAMPAIGN_HERO_NAME, session.completed_shifts, session.campaign_days]

func _refresh_menu() -> void:
	var document: Dictionary = GameState.save_store.load_document()
	%ContinueGame.disabled = document.is_empty()
	%SaveSummary.text = "Сохранений пока нет."
	if document.is_empty() and GameState.save_store.exists():
		%SaveSummary.text = "Сохранение недоступно."
	if not document.is_empty():
		var data: Dictionary = document.sections
		%SaveSummary.text = "%s · день %d · %d $" % [NewsroomSession.CAMPAIGN_HERO_NAME, data.run.get("day", 0), data.run.get("money", 0)]
		var final_seen: bool = "finale" in data.get("presentation", {}).get("story", {}).get("seen", [])
		%ContinueGame.text = "ПОСМОТРЕТЬ ИТОГ" if data.run.phase == "ended" and (not data.run.get("campaign_completed", false) or final_seen) else "ПРОДОЛЖИТЬ"
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
	lesson = 0
	var guidance: Dictionary = presentation.get("guidance", {})
	_tutorial_stage = guidance.get("stage", "")
	_tutorial_step = int(guidance.get("step", 0))
	_work_tutorial_done = guidance.get("work_done", session.phase != NewsroomSession.Phase.IDLE)
	_home_tutorial_done = guidance.get("home_done", session.completed_shifts > 0)
	_pencil_tutorial_done = guidance.get("pencil_done", false)
	_stamina_warning_day = int(presentation.get("stamina_warning_day", 0))
	_pending_deductions.clear()
	$MoneyDelta.clear()
	var story: Dictionary = presentation.get("story", {})
	_seen_stories.assign(story.get("seen", []))
	_story_id = story.get("id", "")
	_story_page = int(story.get("page", 0))
	# Existing saves may already be in the middle of a shift. Do not insert an
	# unseen morning scene into that shift or reapply its starting bonuses.
	if not presentation.has("story"):
		if session.day >= 2:
			_seen_stories.append("day_2")
		if session.day >= 4:
			_seen_stories.append("day_4")
	_restoring = false
	if not _story_id.is_empty():
		_show_story(_story_id, _story_page)
	elif session.phase == NewsroomSession.Phase.IDLE:
		if presentation.get("screen", "intro") == "tutorial":
			_show_lesson()
		else:
			_show_intro()
	else:
		_on_phase_changed()
	if session.phase == NewsroomSession.Phase.WORK:
		if view == View.STORY:
			work.show_article(false)
		else:
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
	var in_story := view in [View.INTRO, View.STORY]
	sections["presentation"] = {"screen": VIEW_KEYS[view], "lesson": lesson,
		"newsroom": work.capture_presentation(),
		"guidance": {"stage": _tutorial_stage, "step": _tutorial_step, "work_done": _work_tutorial_done, "home_done": _home_tutorial_done, "pencil_done": _pencil_tutorial_done},
		"stamina_warning_day": _stamina_warning_day,
		"story": {"id": _story_id if in_story else "", "page": _story_page if in_story else 0, "seen": _seen_stories.duplicate()}}
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
	var warning_day: Variant = presentation.get("stamina_warning_day", 0)
	if not NewsroomSaveData._number(warning_day) or int(warning_day) != warning_day or warning_day < 0 or warning_day > sections.run.day:
		return false
	var guidance: Variant = presentation.get("guidance", {})
	if not guidance is Dictionary or not guidance.get("stage", "") in ["", "work", "home", "pencil"]:
		return false
	for key in ["work_done", "home_done", "pencil_done"]:
		if guidance.has(key) and not guidance[key] is bool:
			return false
	var step: Variant = guidance.get("step", 0)
	if not NewsroomSaveData._number(step) or int(step) != step or step < 0:
		return false
	if guidance.get("stage", "").is_empty() and step != 0:
		return false
	if guidance.get("stage", "") == "pencil":
		if sections.run.phase != "work" or not sections.run.get("proofreading_unlocked", int(sections.run.day) >= 3) or step >= INTERFACE_LESSONS.pencil().size() or guidance.get("pencil_done", false):
			return false
	var newsroom: Dictionary = presentation.get("newsroom", {})
	var selected_index: Variant = newsroom.get("selected_index", -1)
	if not NewsroomSaveData._number(selected_index) or int(selected_index) != selected_index or selected_index < -1 or selected_index > 2:
		return false
	var layout_version: Variant = newsroom.get("layout_version", 1)
	if not NewsroomSaveData._number(layout_version) or int(layout_version) != layout_version or layout_version < 1:
		return false
	if newsroom.has("preview_index"):
		var preview: Variant = newsroom.preview_index
		if not NewsroomSaveData._number(preview) or int(preview) != preview or preview < -1 or preview > 2:
			return false
	for key in ["choices_open", "drawer_expanded"]:
		if newsroom.has(key) and not newsroom[key] is bool:
			return false
	if presentation.has("story"):
		var story: Variant = presentation.story
		if not story is Dictionary or not story.get("seen", []) is Array:
			return false
		for episode in story.get("seen", []):
			if not episode is String or not CHAPTER.EPISODES.has(episode):
				return false
		var episode: Variant = story.get("id", "")
		var page: Variant = story.get("page", 0)
		if not episode is String or not NewsroomSaveData._number(page):
			return false
		if int(page) != page or page < 0:
			return false
		if episode.is_empty():
			if page != 0 or presentation.get("screen") in ["intro", "story"]:
				return false
		else:
			if not CHAPTER.EPISODES.has(episode) or page >= CHAPTER.EPISODES[episode].size() or episode in story.get("seen", []):
				return false
			var run: Dictionary = sections.run
			if episode == "intro":
				if presentation.get("screen") != "intro" or run.phase != "idle":
					return false
			else:
				if presentation.get("screen") != "story":
					return false
				if episode == "finale":
					if run.phase != "ended" or not run.ending in ["victory", "goal_missed"]:
						return false
				elif episode == "day_2":
					# Existing saves may still contain this conversation before shift 2.
					if int(run.day) != 2 or not run.phase in ["work", "home"]:
						return false
				elif run.phase != "work" or CHAPTER.episode_for_day(int(run.day)) != episode:
					return false
	var extensions: Variant = sections.get("extensions", {})
	if not extensions is Dictionary:
		return false
	for value in extensions.values():
		if not value is Dictionary:
			return false
	return true
