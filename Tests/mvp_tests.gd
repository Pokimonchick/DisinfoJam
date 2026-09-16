extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _fresh() -> NewsroomSession:
	var model := NewsroomSession.new()
	model.balance = model.balance.duplicate() as NewsroomBalance
	model.reset(42)
	return model

func _capture(name: String) -> void:
	if not "--screenshots" in OS.get_cmdline_user_args():
		return
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://Build/QA")
	var capture := root.get_texture().get_image()
	_check(capture.save_png("res://Build/QA/%s.png" % name) == OK, "Save visual check: " + name)

func _run() -> void:
	_test_catalog()
	_test_day_cycle()
	_test_publication_queue()
	_test_endings()
	await _test_scenes()
	if failures.is_empty():
		print("MVP TESTS PASSED: %d checks" % checks)
	else:
		print("MVP TESTS FAILED: %d / %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _test_catalog() -> void:
	var s := _fresh()
	_check(s.articles.size() == 24, "The shared pool has 24 stories")
	var ids: Dictionary = {}
	var dangerous := 0
	for article in s.articles:
		_check(not ids.has(article.id), "Article IDs are unique: " + article.id)
		ids[article.id] = true
		_check(not article.source_text.is_empty() and article.headlines.size() == 3, "Source and three headlines: " + article.id)
		var has_harsh_choice := false
		for option in article.headlines:
			_check(not option.text.is_empty() and not option.explanation.is_empty(), "Headline and explanation exist")
			has_harsh_choice = has_harsh_choice or option.reputation <= -30 or option.loyalty <= -30
		if has_harsh_choice:
			dangerous += 1
		_check(article.high_risk == has_harsh_choice, "Risk marker agrees with actual content")
	_check(dangerous == 8, "One third of stories have a very costly choice")

func _test_day_cycle() -> void:
	var s := _fresh()
	s.start_shift()
	_check(s.time_left == 180.0 and s.day == 1, "Default shift is three minutes")
	var article_id := s.current_article().id
	var order := s.option_order.duplicate()
	s.tick_work(200.0)
	_check(s.phase == NewsroomSession.Phase.HOME, "Timeout automatically enters the evening")
	_check(is_equal_approx(s.health, 62.0), "Drain stops at the actual shift boundary")
	_check(s.money == -10 and s.completed_shifts == 1, "Rent is charged once and modest debt is allowed")
	s.finish_shift()
	_check(s.money == -10, "Repeated finish cannot charge rent twice")
	_check(s.buy_food(true) and s.health == 97.0 and s.money == -35, "Dinner restores health and costs money")
	_check(s.buy_coffee() and s.health == 89.0 and s.money == -50, "Coffee charges money and health immediately")
	_check(not s.buy_coffee() and s.money == -50, "Coffee cannot stack or charge twice")
	var before_sleep := s.health
	s.start_shift()
	_check(s.day == 2 and s.time_left == 240.0, "Coffee adds exactly one minute to the next shift")
	_check(s.health == before_sleep, "Mandatory sleep does not restore health")
	_check(s.current_article().id == article_id and s.option_order == order, "Unpublished article and options survive overnight")
	_check(not s.buy_food(true) and not s.buy_coffee(), "Shopping is restricted to the evening")
	s.tick_work(240.0)
	s.start_shift()
	_check(s.time_left == 180.0, "Coffee bonus expires after one shift")

func _test_publication_queue() -> void:
	var s := _fresh()
	s.start_shift()
	_check(not s.publish_headline(-1) and not s.publish_headline(3), "Invalid choices are rejected")
	var chosen := s.option_at(0)
	var before := s.money
	_check(s.publish_headline(0), "A selected headline can be published")
	_check(s.money == before + chosen.money and s.total_published == 1, "Publication rewards are applied once")
	_check(s.last_result.headline == chosen.text, "Feedback describes the actual shuffled choice")
	_check(not s.publish_headline(0) and s.total_published == 1, "Double clicks cannot publish twice")
	s.tick_work(180.0)
	s.acknowledge_publication()
	s.start_shift()
	_check(s.article_cursor == 1 and s.current_article().id == "market_gate", "Timeout during feedback cannot repeat a published story")
	# Walk the entire deck through the public publication API without running
	# out of resources. Only the test's balance resource is modified.
	s = _fresh()
	s.balance.maximum_stat = 10000
	s.balance.publication_health_cost = 0
	s.reputation = 10000
	s.loyalty = 10000
	s.start_shift()
	var seen: Dictionary = {}
	var orders: Dictionary = {}
	for i in range(24):
		seen[s.current_article().id] = true
		orders[str(s.option_order)] = true
		s.publish_headline(0)
		s.acknowledge_publication()
	_check(seen.size() == 24 and s.current_article().id == "black_cat", "All stories appear before the pool cycles")
	_check(orders.size() > 1, "Headline positions vary between stories")

func _test_endings() -> void:
	var s := _fresh()
	s.start_shift()
	s.health = 0.1
	s.tick_work(2.0)
	_check(s.ending == NewsroomSession.Ending.EXHAUSTION, "Work can cause exhaustion")
	_check(not s.publish_headline(0), "No publication after death")
	s = _fresh()
	s.start_shift()
	s.reputation = 1
	for i in range(3):
		if s.option_at(i).reputation < 0:
			s.publish_headline(i)
			break
	_check(s.ending == NewsroomSession.Ending.OFFICE_FIRE, "Zero reputation causes an office fire")
	s = _fresh()
	s.start_shift()
	s.loyalty = 1
	for i in range(3):
		if s.option_at(i).loyalty < 0:
			s.publish_headline(i)
			break
	_check(s.ending == NewsroomSession.Ending.ARREST, "Zero loyalty causes an arrest")
	s = _fresh()
	s.start_shift()
	s.money = -55
	s.finish_shift()
	_check(s.money == -100 and s.ending == NewsroomSession.Ending.DEBT, "Debt ending triggers at exactly minus 100 after rent")
	s = _fresh()
	s.start_shift()
	s.finish_shift()
	s.health = 8
	s.buy_coffee()
	_check(s.ending == NewsroomSession.Ending.EXHAUSTION, "Coffee can cause exhaustion immediately")
	s = _fresh()
	s.start_shift()
	s.finish_shift()
	s.money = -88
	s.buy_food(false)
	_check(s.ending == NewsroomSession.Ending.DEBT, "A purchase can cross the debt boundary")
	s.reset()
	_check(s.phase == NewsroomSession.Phase.IDLE and s.ending == NewsroomSession.Ending.NONE and s.article_cursor == 0 and s.journal.is_empty(), "Restart clears the entire run")

func _test_scenes() -> void:
	var packed := load("res://Scenes/mvp_game.tscn") as PackedScene
	_check(packed != null, "The playable scene loads")
	if packed == null:
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await _capture("01_menu")
	game.get_node("%NewGame").pressed.emit()
	_check(game.view == game.View.INTRO, "New game opens the prologue")
	await _capture("02_prologue")
	game.get_node("%NarrativePrimary").pressed.emit()
	_check(game.view == game.View.TUTORIAL, "Prologue leads to the boss tutorial")
	await _capture("03_tutorial")
	for i in range(4):
		game.get_node("%NarrativePrimary").pressed.emit()
	await create_timer(0.3).timeout
	_check(game.view == game.View.WORK, "The complete tutorial starts work")
	var work := game.get_node("%Work")
	var popup := work.get_node("MessagePanel")
	_check(popup.visible and work.popup_kind == work.DialogKind.SOURCE, "Each new source opens automatically")
	await _capture("04_source")
	popup.primary_pressed.emit()
	_check(not popup.visible, "Source can immediately be folded away")
	await _capture("05_headlines")
	work.get_node("%ReadSource").pressed.emit()
	_check(popup.visible, "Desk note reopens the same source")
	popup.primary_pressed.emit()
	work.get_node("%Headline1").pressed.emit()
	_check(work.popup_kind == work.DialogKind.CONFIRM, "A headline requires explicit confirmation")
	await _capture("06_confirmation")
	popup.secondary_pressed.emit()
	_check(game.session.total_published == 0, "Cancelling confirmation does not publish")
	work.get_node("%Headline1").pressed.emit()
	popup.primary_pressed.emit()
	_check(work.popup_kind == work.DialogKind.RESULT and game.session.total_published == 1, "Confirmation displays actual consequences")
	await _capture("07_result")
	game.get_node("%PauseButton").pressed.emit()
	var time_before: float = game.session.time_left
	await create_timer(0.08).timeout
	_check(is_equal_approx(game.session.time_left, time_before), "Pause stops the work clock")
	game.get_node("PausePanel").primary_pressed.emit()
	game.session.time_left = 0.01
	await create_timer(0.08).timeout
	_check(game.view == game.View.HOME, "Timer automatically switches the visible scene to home")
	await create_timer(0.25).timeout
	var home := game.get_node("%Home")
	await _capture("08_home")
	home.get_node("%Meal").pressed.emit()
	home.get_node("%Coffee").pressed.emit()
	var health_before: float = game.session.health
	home.get_node("%Bed").pressed.emit()
	_check(game.session.day == 2 and game.session.shift_length == 240.0, "Home buttons feed, buy coffee and start the next day")
	_check(game.session.health == health_before, "Bed UI does not heal")
	await create_timer(0.25).timeout
	for ending in [NewsroomSession.Ending.EXHAUSTION, NewsroomSession.Ending.OFFICE_FIRE, NewsroomSession.Ending.ARREST, NewsroomSession.Ending.DEBT]:
		game.session.reset(42)
		game.session.start_shift()
		match ending:
			NewsroomSession.Ending.EXHAUSTION: game.session.health = 0
			NewsroomSession.Ending.OFFICE_FIRE: game.session.reputation = 0
			NewsroomSession.Ending.ARREST: game.session.loyalty = 0
			NewsroomSession.Ending.DEBT: game.session.money = -100
		game.session.tick_work(0.01)
		_check(game.view == game.View.ENDING and not game.get_node("%NarrativeTitle").text.is_empty(), "Ending screen loads: %d" % ending)
		await _capture("ending_%d" % ending)
	game.get_node("%NarrativePrimary").pressed.emit()
	_check(game.view == game.View.WORK and game.session.day == 1, "Retry button starts a fresh playable run")
	game.get_node("%PauseButton").pressed.emit()
	game.get_node("PausePanel").secondary_pressed.emit()
	time_before = game.session.time_left
	await create_timer(0.35).timeout
	_check(game.view == game.View.MENU and game.session.time_left == time_before, "Abandoned run cannot tick behind the menu")
	game.queue_free()
	await process_frame
