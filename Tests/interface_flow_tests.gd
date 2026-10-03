extends SceneTree

var failures := 0
var checks := 0
var _test_path := "user://interface_flow_%d/campaign.json" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fresh() -> NewsroomSession:
	var session := NewsroomSession.new()
	session.balance = NewsroomBalance.new()
	session.reset(42)
	session.player_id = "interface-test"
	session.run_id = "interface-test-run"
	return session

func _run() -> void:
	if "--compact" in OS.get_cmdline_user_args():
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(960, 640)
	_test_finance_save()
	await _test_interface()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_path.get_base_dir()))
	print("INTERFACE FLOW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_finance_save() -> void:
	var session := fresh()
	var notifications: Array[Dictionary] = []
	session.transaction_recorded.connect(func(entry: Dictionary): notifications.append(entry))
	session.start_shift()
	session.drink_coffee()
	session.publish_headline(0)
	session.acknowledge_publication()
	session.finish_shift()
	session.health = 40
	session.buy_food(false)
	session.buy_food(true)
	session.buy_coffee()
	check(session.finances.entries.size() == 5 and notifications.size() == 5, "Publication, rent and all purchases record exactly once")
	check(session.finances.summary().balance == session.money - session.balance.starting_money, "Journal totals agree with actual balance changes")
	check(session.finances.summary(1).expenses_by_kind.rent == 45, "Rent is assigned to its completed shift")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(NewsroomSaveData.capture(session)))
	var restored := fresh()
	var restore_events: Array = []
	restored.transaction_recorded.connect(func(entry: Dictionary): restore_events.append(entry))
	check(NewsroomSaveData.restore(restored, snapshot), "Finance data survives a JSON save")
	check(restored.finances.summary() == session.finances.summary() and restore_events.is_empty(), "Loading retains history without replaying deductions")
	check(not restored.buy_coffee() and restored.finances.entries.size() == 5, "Rejected purchases add no journal entry")
	var bad := snapshot.duplicate(true)
	bad.run.finances.entries[0].amount = "broken"
	check(not NewsroomSaveData.restore(restored, bad) and restored.money == session.money, "Malformed finance data is rejected before touching the session")
	snapshot.run.erase("finances")
	check(NewsroomSaveData.restore(restored, snapshot) and restored.finances.history_incomplete, "Old saves recover publications and disclose missing spending history")
	check(restored.finances.entries.size() == 1 and restored.money == session.money, "Legacy import never invents deductions or changes money")
	var archive: NewsArticle
	for article in session.articles:
		if article.id == "archive":
			archive = article
	archive.headlines[1].reputation = -37
	archive.headlines[1].loyalty = -30
	snapshot = NewsroomSaveData.capture(session)
	check(NewsroomSaveData.restore(restored, snapshot), "An existing campaign with old authored effects loads")
	for article in restored.articles:
		if article.id == "archive":
			check(article.headlines[1].reputation == -12 and article.headlines[1].loyalty == -10, "Future headlines in old saves receive the rebalanced effects")
	check(restored.journal == session.journal and restored.money == session.money, "Rebalancing does not rewrite past publications")

func _click(control: Control) -> void:
	var position := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func _capture(name: String) -> void:
	if DisplayServer.get_name() != "headless" and "--captures" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var suffix := "-compact" if "--compact" in OS.get_cmdline_user_args() else ""
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("disinfo-ux-" + name + suffix + ".png"))

func _test_interface() -> void:
	var state := root.get_node("GameState")
	state.save_store = SaveRepository.new(_test_path)
	state.session = fresh()
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._new_run(false)
	game._narrative_next()
	check(game._story_page == 1 and not game.get_node("%NarrativeBack").disabled, "Dialogue back is available after the first page")
	var money: int = game.session.money
	game.get_node("%NarrativeBack").pressed.emit()
	check(game._story_page == 0 and game.session.money == money and game.get_node("%NarrativeBack").disabled, "Rereading dialogue does not replay game effects")
	while game.view == game.View.INTRO:
		game._narrative_next()
	await process_frame
	await create_timer(0.3).timeout
	check(game.view == game.View.WORK and game.tutorial.visible and game.session.day == 1, "Boss teaches directly on the first working desk")
	var health: float = game.session.health
	game._process(60)
	check(game.session.health == health, "Guided lessons pause passive stamina drain")
	_click(game.work.get_node("Canvas/Drawer/SlidingPanel/TabButton"))
	check(game.work.get_node("%Drawer").expanded and game._tutorial_step == 0, "Spotlight blocks interactions with the underlying drawer")
	await _capture("boss")
	game._tutorial_next()
	game._tutorial_next()
	await process_frame
	check(game.work.choices_open and game.tutorial._highlight.has_area(), "The choice lesson demonstrates the actual notes")
	await _capture("choices")
	game._show_menu()
	game._continue_run()
	await process_frame
	check(game.view == game.View.WORK and game.tutorial.visible and game._tutorial_step == 2, "Continue restores the current spotlight step")
	for step in range(3, _work_step_count()):
		game._tutorial_next()
		await process_frame
		await process_frame
		check(game.tutorial._highlight.has_area() and Rect2(Vector2.ZERO, game.tutorial.size).encloses(game.tutorial._panel.get_rect()), "Tutorial spotlight and dialogue fit step %d" % step)
		if step in [4, 7, 9]:
			await _capture("work-step-%d" % step)
	check(game.tutorial.get_node("%Explanation").text.contains("Сдать выпуск") and game.session.combo_count == 0 and game.session.total_published == 0, "Final boss instruction names finish shift; demonstrations never publish or change combo")
	game._tutorial_next()
	check(not game.tutorial.visible and game._work_tutorial_done, "Completing the boss lesson returns control to the player")
	game.transitioning = false
	game.session.health = 9.5
	game.session.changed.emit()
	game._process(0)
	check(game.stamina_warning.visible, "Low stamina opens a warning")
	game._process(20)
	check(game.session.health == 9.5, "Warning pauses stamina while it is read")
	await _capture("warning")
	game.stamina_warning.primary_button.pressed.emit()
	game._process(15)
	check(not game.stamina_warning.visible and is_equal_approx(game.session.health, 8.5), "After closing, play and drain resume without repeating the warning")
	game._show_menu()
	game._continue_run()
	await process_frame
	game.transitioning = false
	game._process(0)
	check(not game.stamina_warning.visible, "A dismissed warning stays dismissed when a shift is resumed")
	game.session.money = 200
	game.session.finish_shift()
	await process_frame
	await create_timer(0.3).timeout
	game._process(0)
	check(game.view == game.View.HOME and game.tutorial.visible and game._tutorial_stage == "home", "First home evening starts the heroine's own tutorial")
	check(not is_instance_valid(game._notebook) and game.get_node("MoneyDelta")._labels.size() == 1, "Rent is animated near balance; notebook does not open automatically")
	_click(game.home.get_node("%Meal"))
	check(game.session.money == 155, "Home tutorial blocks purchases behind it")
	await _capture("heroine")
	for step in range(1, 5):
		game._tutorial_next()
		await process_frame
		await process_frame
		check(game.tutorial._highlight.has_area() and Rect2(Vector2.ZERO, game.tutorial.size).encloses(game.tutorial._panel.get_rect()), "Home spotlight and dialogue fit step %d" % step)
		if step == 4:
			await _capture("bed")
	game._tutorial_next()
	_click(game.home.get_node("%Notebook"))
	await process_frame
	check(is_instance_valid(game._notebook), "Clicking the notebook on the coffee table opens its journal")
	await _capture("notebook")
	game._process(2)
	check(game.session.phase == NewsroomSession.Phase.HOME, "Reading the journal cannot start the next shift")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	check(not is_instance_valid(game._notebook) and not game.paused, "Escape closes the notebook without opening pause")
	_click(game.home.get_node("%Meal"))
	await process_frame
	check(game.session.money == 130 and game.get_node("MoneyDelta")._labels.size() >= 1, "Food purchase deducts cash and animates its amount")
	var paid_money: int = game.session.money
	var entry_count: int = game.session.finances.entries.size()
	game._show_menu()
	game._continue_run()
	await process_frame
	check(game.session.money == paid_money and game.session.finances.entries.size() == entry_count and not game.tutorial.visible and not is_instance_valid(game._notebook), "Resume does not replay purchases or completed home teaching")
	game._new_run(true)
	await process_frame
	check(game.session.finances.entries.is_empty() and game._stamina_warning_day == 0 and game.work.get_node("%Drawer").expanded, "New campaigns clear finances, warnings and collapsed drawer state")
	game.transitioning = false
	game.session.health = 11
	game.session.changed.emit()
	game.session.publish_headline(0)
	game._process(30)
	check(game.session.health == 7 and not game.stamina_warning.visible, "Low stamina waits while publication feedback is being read")
	game.work._close_focus()
	await create_timer(0.35).timeout
	game._process(0)
	check(game.stamina_warning.visible, "Warning appears after publication feedback closes")
	game._rest_after_warning()
	check(game.session.phase == NewsroomSession.Phase.HOME and not game.stamina_warning.visible, "Warning can send the player home while preserving the run")
	game.session.start_shift()
	while game.view == game.View.STORY:
		game._narrative_next()
	game.transitioning = false
	game.session.health = 9
	game.session.changed.emit()
	game._process(0)
	check(game.stamina_warning.visible, "The next shift gets its own low stamina warning")
	game._run_active = false
	game.queue_free()
	await process_frame

func _work_step_count() -> int:
	return preload("res://Data/interface_lessons.gd").work(NewsroomBalance.new()).size()
