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
	# Tests use the production defaults even when a developer temporarily
	# shortens mvp_balance.tres to inspect the game more quickly.
	model.balance.shift_seconds = 180.0
	model.balance.coffee_bonus_seconds = 60.0
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
	_test_coffee_inventory()
	_test_combos()
	_test_endings()
	await _test_scenes()
	if failures.is_empty():
		print("MVP TESTS PASSED: %d checks" % checks)
	else:
		print("MVP TESTS FAILED: %d / %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _test_catalog() -> void:
	var s := _fresh()
	_check(s.articles.size() == 32, "The shared pool includes eight community stories")
	_check(s.articles[2].id == "cats_rumor" and s.articles[9].id == "bloom_letter", "Community stories retain sequence after the introduction")
	var ids: Dictionary = {}
	var dangerous := 0
	for article in s.articles:
		_check(not ids.has(article.id), "Article IDs are unique: " + article.id)
		ids[article.id] = true
		_check(not article.source_text.is_empty() and article.headlines.size() == 3, "Source and three headlines: " + article.id)
		var has_harsh_choice := false
		for option in article.headlines:
			_check(not option.text.is_empty() and not option.explanation.is_empty(), "Headline and explanation exist")
			_check(option.editorial_type in [0, 1, 2], "Headline has a valid editorial combo type")
			has_harsh_choice = has_harsh_choice or option.reputation <= -30 or option.loyalty <= -30
		if has_harsh_choice:
			dangerous += 1
		_check(article.high_risk == has_harsh_choice, "Risk marker agrees with actual content")
	_check(dangerous == 8, "The eight original high-risk stories remain in the pool")

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
	_check(s.buy_coffee() and s.health == 97.0 and s.money == -50, "Buying coffee costs money, not health")
	_check(not s.buy_coffee() and s.money == -50, "Coffee cannot stack or charge twice")
	var before_sleep := s.health
	s.start_shift()
	_check(s.day == 2 and s.time_left == 180.0 and s.coffee_ready, "Coffee arrives as inventory without extending the shift")
	_check(s.health == before_sleep, "Mandatory sleep does not restore health")
	_check(s.current_article().id == article_id and s.option_order == order, "Unpublished article and options survive overnight")
	_check(not s.buy_food(true) and not s.buy_coffee(), "Shopping is restricted to the evening")
	s.tick_work(20.0)
	var health_before_cup := s.health
	_check(s.drink_coffee() and s.time_left == 220.0 and s.shift_length == 240.0, "Drinking adds one minute to remaining time")
	_check(s.health == health_before_cup - 8.0 and not s.coffee_ready and s.coffee_used_today, "Drinking spends health and leaves a stain")
	_check(not s.drink_coffee() and s.time_left == 220.0, "Repeated coffee click cannot stack the bonus")
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
	for i in range(s.articles.size()):
		seen[s.current_article().id] = true
		orders[str(s.option_order)] = true
		s.publish_headline(0)
		s.acknowledge_publication()
	_check(seen.size() == 32 and s.current_article().id == "black_cat", "All stories appear before the pool cycles")
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
	_check(s.phase == NewsroomSession.Phase.HOME, "Coffee purchase does not cause exhaustion")
	s.start_shift()
	s.drink_coffee()
	_check(s.ending == NewsroomSession.Ending.EXHAUSTION, "Drinking coffee can cause exhaustion")
	s = _fresh()
	s.start_shift()
	s.finish_shift()
	s.money = -88
	s.buy_food(false)
	_check(s.ending == NewsroomSession.Ending.DEBT, "A purchase can cross the debt boundary")
	s.reset()
	_check(s.phase == NewsroomSession.Phase.IDLE and s.ending == NewsroomSession.Ending.NONE and s.article_cursor == 0 and s.journal.is_empty(), "Restart clears the entire run")

func _test_coffee_inventory() -> void:
	var s := _fresh()
	s.money = 500
	_check(not s.drink_coffee(), "Coffee cannot be used before a shift")
	s.start_shift()
	_check(not s.drink_coffee(), "No free coffee on the first shift")
	s.finish_shift()
	s.buy_coffee()
	_check(not s.drink_coffee(), "Coffee cannot be consumed at home")
	s.start_shift()
	s.finish_shift()
	_check(s.coffee_ready and not s.buy_coffee(), "An unused cup survives a shift and blocks another purchase")
	s.start_shift()
	s.time_left = 0.01
	_check(s.drink_coffee() and is_equal_approx(s.time_left, 60.01), "Coffee works just before the deadline")
	s.tick_work(70.0)
	_check(not s.drink_coffee(), "Coffee cannot revive an expired shift")
	_check(s.buy_coffee(), "A consumed cup can be replaced next evening")
	s.start_shift()
	_check(not s.coffee_used_today and s.coffee_ready, "A new shift clears the stain, not the purchased cup")
	s.reset(42)
	_check(not s.coffee_ready and not s.coffee_used_today and not s.food_stocked, "Restart clears cup and food state")

func _test_combos() -> void:
	var s := _fresh()
	s.balance.maximum_stat = 10000
	s.reputation = 5000
	s.loyalty = 5000
	# Controlled articles let expected deltas be independent of content changes
	# and verify that the shuffled display position is not the combo key.
	s.articles = [NewsArticle.from_row({
		"id": "combo_fixture", "source": "Fixture", "text": "Known effects.",
		"options": [
			["Facts", 20, 8, -4, "Known effects", 0],
			["Sensation", 40, -12, -8, "Known effects", 1],
			["Support", 24, -4, 8, "Known effects", 2]
		]
	})]
	s.start_shift()
	var start_money := s.money
	var start_health := s.health
	for expected in [1.0, 1.25, 1.5, 1.75, 2.0, 2.0]:
		var display_index := s.option_order.find(1)
		var reputation_before := s.reputation
		_check(s.publish_headline(display_index), "Combo publication succeeds")
		_check(s.last_result.multiplier == expected, "Combo reaches and respects its cap")
		_check(s.last_result.money == roundi(40 * expected) and s.last_result.reputation == roundi(-12 * expected), "Combo multiplies both income and penalties")
		_check(s.reputation == reputation_before + s.last_result.reputation, "Feedback matches applied combo effects")
		var count_before := s.combo_count
		_check(not s.publish_headline(display_index) and s.combo_count == count_before, "Double publication cannot grow the combo")
		s.acknowledge_publication()
	_check(s.money == start_money + 380, "Combo income is counted exactly once")
	_check(s.health == start_health - 6 * s.balance.publication_health_cost, "Combo does not multiply stamina costs")
	s.publish_headline(s.option_order.find(0))
	_check(s.combo_count == 1 and s.combo_type == 0 and s.last_result.multiplier == 1.0, "Changing editorial type resets the series")
	s.acknowledge_publication()
	_check(not s.publish_headline(-1) and s.combo_count == 1, "Invalid choice cannot change combo")
	s.finish_shift()
	s.start_shift()
	_check(s.combo_count == 0 and s.combo_type == -1, "New shift resets combo")
	s.balance.combo_max_multiplier = 3.0
	_check(s.combo_multiplier(20) == 3.0, "A designer can raise the cap to three")
	s.reset()
	_check(s.combo_count == 0 and s.combo_type == -1, "New run resets combo")

func _test_scenes() -> void:
	var packed := load("res://Scenes/mvp_game.tscn") as PackedScene
	_check(packed != null, "The playable scene loads")
	if packed == null:
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.session.balance = game.session.balance.duplicate() as NewsroomBalance
	game.session.balance.shift_seconds = 180.0
	game.session.balance.coffee_bonus_seconds = 60.0
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
	work.get_node("%SourceNote").activated.emit()
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
