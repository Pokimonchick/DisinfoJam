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
	model.balance.starting_health = 80.0
	model.balance.coffee_health_restore = 20.0
	model.balance.publication_health_cost = 4.0
	model.balance.publication_limit = 10
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

func _point_at(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await process_frame

func _click_at(control: Control) -> void:
	_click_point(control.get_global_rect().get_center())

func _click_point(point: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.global_position = click.position
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)

func _run() -> void:
	if not "--untimed" in OS.get_cmdline_user_args():
		_test_catalog()
	_test_day_cycle()
	_test_publication_queue()
	_test_publication_limit()
	_test_coffee_inventory()
	_test_combos()
	_test_benefits()
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
	var catalog_order: Array[String] = []
	for article in preload("res://Data/article_catalog.gd").create_articles():
		catalog_order.append(article.id)
	var shuffled_order: Array[String] = []
	for article in s.articles:
		shuffled_order.append(article.id)
	_check(shuffled_order != catalog_order, "A new campaign shuffles the authored article order")
	var same_seed := _fresh()
	var other_seed := _fresh()
	other_seed.reset(43)
	_check(same_seed.articles.map(func(article: NewsArticle): return article.id) == shuffled_order, "The same seed reproduces the article queue")
	_check(other_seed.articles.map(func(article: NewsArticle): return article.id) != shuffled_order, "Another new run gets a different article queue")
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
	_check(s.time_left == 0.0 and s.shift_length == 0.0 and s.day == 1, "Fresh shifts use inert zero legacy time")
	var article_id := s.current_article().id
	var order := s.option_order.duplicate()
	s.tick_work(200.0)
	_check(s.phase == NewsroomSession.Phase.WORK and s.completed_shifts == 0, "Elapsed time never ends an untimed shift")
	_check(is_equal_approx(s.health, 60.0), "Drain uses the whole elapsed delta")
	s.finish_shift()
	_check(s.money == -10 and s.completed_shifts == 1, "Manual completion charges rent once")
	s.finish_shift()
	_check(s.money == -10, "Repeated completion cannot charge twice")
	_check(s.buy_food(true) and s.health == 95.0 and s.money == -35, "Dinner restores stamina and costs money")
	_check(not s.buy_coffee() and s.money == -35, "The carried first cup blocks another purchase")
	s.start_shift()
	_check(s.day == 2 and s.time_left == 0.0 and s.coffee_ready and s.health == 100.0, "Sleep restores capped stamina and carries unused coffee")
	_check(s.current_article().id == article_id and s.option_order == order, "Unpublished source and choices survive overnight")
	_check(not s.buy_food(true) and not s.buy_coffee(), "Shopping is restricted to home")
	_check(not s.drink_coffee() and s.coffee_ready, "Full stamina cannot consume coffee")
	s.tick_work(20.0)
	_check(s.drink_coffee() and s.health == 100.0 and s.time_left == 0.0 and s.shift_length == 0.0, "Coffee restores capped stamina without changing time")
	_check(not s.coffee_ready and s.coffee_used_today and not s.drink_coffee(), "A cup is consumed once per shift")
	s.tick_work(240.0)
	_check(s.phase == NewsroomSession.Phase.WORK and s.health == 76.0, "Work remains active past the old deadline")
	s.finish_shift()
	s.start_shift()
	_check(s.time_left == 0.0 and not s.coffee_used_today, "New shift clears the stain and keeps time inert")

func _test_publication_queue() -> void:
	var s := _fresh()
	s.start_shift()
	_check(not s.publish_headline(-1) and not s.publish_headline(3), "Invalid choices are rejected")
	var chosen := s.option_at(0)
	var before := s.money
	_check(s.publish_headline(0), "A selected headline can be published")
	_check(s.money == before + roundi(chosen.money * s.balance.publication_income_multiplier) and s.total_published == 1, "Publication rewards are applied once")
	_check(s.last_result.headline == chosen.text, "Feedback describes the actual shuffled choice")
	_check(not s.publish_headline(0) and s.total_published == 1, "Double clicks cannot publish twice")
	var next_article := s.current_article().id
	var time_during_result := s.time_left
	var health_during_result := s.health
	s.tick_work(180.0)
	_check(s.phase == NewsroomSession.Phase.WORK and s.time_left == time_during_result and s.health == health_during_result, "Feedback pauses passive stamina drain")
	s.acknowledge_publication()
	s.tick_work(180.0)
	s.finish_shift()
	s.start_shift()
	_check(s.article_cursor == 1 and s.current_article().id == next_article, "The next day keeps the shuffled queue after a published story")
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
		if s.phase == NewsroomSession.Phase.HOME:
			s.start_shift()
	_check(seen.size() == 32 and s.current_article().id == s.articles[0].id, "All stories appear before the shuffled pool cycles")
	_check(orders.size() > 1, "Headline positions vary between stories")

func _test_publication_limit() -> void:
	for limit in [1, 3, 10]:
		var s := _fresh()
		s.balance.publication_limit = limit
		s.balance.maximum_stat = 10000
		s.reputation = 10000
		s.loyalty = 10000
		s.start_shift()
		for i in range(limit):
			_check(s.publish_headline(0), "Publication within configured capacity succeeds")
			if i < limit - 1:
				s.acknowledge_publication()
		_check(s.publication_limit_reached() and s.awaiting_acknowledgement, "Last publication keeps its feedback at the cap")
		var before := [s.money, s.health, s.reputation, s.loyalty, s.article_cursor, s.total_published, s.combo_count, s.time_left]
		s.coffee_ready = true
		_check(not s.drink_coffee() and s.coffee_ready, "Full issue cannot consume a carried cup")
		# Test the model guard independently of the double-click guard.
		s.awaiting_acknowledgement = false
		_check(not s.publish_headline(0), "Model rejects publication beyond capacity")
		_check(before == [s.money, s.health, s.reputation, s.loyalty, s.article_cursor, s.total_published, s.combo_count, s.time_left], "Rejected publication and coffee have no side effects")
		s.awaiting_acknowledgement = true
		var next_article := s.current_article().id
		s.acknowledge_publication()
		_check(s.phase == NewsroomSession.Phase.HOME and s.last_shift.count == limit, "Acknowledging a full issue goes home")
		_check(s.money == before[0] - s.balance.rent, "Full issue charges rent once")
		s.acknowledge_publication()
		s.finish_shift()
		_check(s.completed_shifts == 1 and s.money == before[0] - s.balance.rent, "Repeated completion does not charge again")
		s.start_shift()
		_check(s.published_today == 0 and not s.publication_limit_reached() and s.current_article().id == next_article, "New day resets capacity and preserves the next story")
		_check(s.publish_headline(0), "New day permits publishing again")
	# Final feedback pauses stamina drain; acknowledging it closes the issue once.
	var timed := _fresh()
	timed.balance.publication_limit = 1
	timed.start_shift()
	timed.publish_headline(0)
	timed.tick_work(180.0)
	_check(timed.phase == NewsroomSession.Phase.WORK and timed.time_left == 0.0, "Full-issue feedback remains active with zero legacy time")
	timed.acknowledge_publication()
	_check(timed.phase == NewsroomSession.Phase.HOME and timed.completed_shifts == 1 and timed.article_cursor == 1, "Acknowledging a full issue completes exactly once")

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
	s.health = 4
	s.coffee_ready = false
	s.buy_coffee()
	_check(s.phase == NewsroomSession.Phase.HOME, "Coffee purchase does not cause exhaustion")
	s.start_shift()
	_check(s.drink_coffee() and s.health == 34.0 and s.ending == NewsroomSession.Ending.NONE, "Coffee safely restores stamina after sleep")
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
	_check(s.coffee_ready and not s.drink_coffee(), "First cup is free but cannot be used before work")
	s.start_shift()
	_check(s.drink_coffee() and s.health == 100.0, "First free cup restores twenty stamina")
	_check(not s.drink_coffee(), "Consumed coffee cannot be used twice")
	s.finish_shift()
	_check(s.buy_coffee() and not s.drink_coffee(), "Replacement is purchased at home but consumed at work")
	s.start_shift()
	s.finish_shift()
	_check(s.coffee_ready and not s.buy_coffee(), "Unused coffee carries and blocks an extra purchase")
	s.start_shift()
	s.tick_work(100.0)
	s.time_left = 0.0
	_check(s.drink_coffee() and s.health == 100.0, "Coffee works with zero legacy time")
	s.tick_work(70.0)
	_check(s.phase == NewsroomSession.Phase.WORK and not s.drink_coffee(), "Elapsed time never replenishes consumed coffee")
	s.finish_shift()
	_check(s.buy_coffee(), "Consumed coffee can be replaced next evening")
	s.start_shift()
	_check(not s.coffee_used_today and s.coffee_ready, "New shift clears stain and keeps inventory")
	s.publish_headline(0)
	_check(not s.drink_coffee() and s.coffee_ready, "Pending feedback blocks coffee without consuming it")
	s.reset(42)
	_check(s.coffee_ready and not s.coffee_used_today and not s.food_stocked, "Restart restores free coffee and clears food and stain")

func _test_combos() -> void:
	var s := _fresh()
	s.balance.maximum_stat = 10000
	s.reputation = 5000
	s.loyalty = 5000
	# Controlled articles let expected deltas be independent of content changes
	# and verify that the shuffled display position is not the combo key.
	s.balance.publication_income_multiplier = 1.0
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
	_check(s.health == start_health - 6 * maxf(0.0, s.balance.publication_health_cost - s.balance.reader_support.amount), "Combo does not multiply stamina costs")
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


func _test_benefits() -> void:
	var s := _fresh()
	s.articles = [NewsArticle.from_row({
		"id": "benefit_fixture", "source": "Fixture", "text": "Known effects.",
		"options": [
			["Support", 20, 2, 0, "Known effects", 0],
			["Criticism", 20, -10, 0, "Known effects", 1],
			["Neutral", 20, 0, 0, "Known effects", 2]
		]
	})]
	s.reputation = 74.0
	s.start_shift()
	var before := s.health
	s.publish_headline(s.option_order.find(0))
	_check(s.reputation == 76.0 and s.last_result.stamina_cost == 4.0 and s.health == before - 4.0, "Crossing the reputation threshold benefits the next article")
	s.acknowledge_publication()
	before = s.health
	s.publish_headline(s.option_order.find(2))
	_check(s.last_result.stamina_cost == 2.0 and s.health == before - 2.0, "Reader support reduces publication stamina cost")
	s.acknowledge_publication()
	s.publish_headline(s.option_order.find(1))
	_check(s.reputation < 75.0 and s.last_result.stamina_cost == 2.0, "An article keeps a benefit earned before its effects")
	s.acknowledge_publication()
	s.publish_headline(s.option_order.find(2))
	_check(s.last_result.stamina_cost == 4.0, "Falling below the threshold removes the next publication benefit")

	s = _fresh()
	s.loyalty = 75.0
	s.start_shift()
	_check(s.approval_stamina_applied and s.health == 90.0 and s.time_left == 0.0, "High loyalty grants ten stamina at shift start")
	s.start_shift()
	_check(s.health == 90.0, "Starting an active shift cannot repeat approval recovery")
	s.loyalty = 10.0
	s.tick_work(5.0)
	_check(s.health == 89.5, "Losing loyalty does not revoke granted stamina")
	s.drink_coffee()
	_check(s.health == 100.0 and s.time_left == 0.0, "Approval and coffee recovery clamp at maximum stamina")
	s.finish_shift()
	s.start_shift()
	_check(not s.approval_stamina_applied, "Low loyalty does not grant approval next shift")
	s = _fresh()
	s.health = 96.0
	s.loyalty = 75.0
	s.start_shift()
	_check(s.health == 100.0 and s.approval_stamina_applied, "Approval recovery is capped")

func _test_scenes() -> void:
	var test_save_path := "user://mvp_test_%d/campaign.json" % Time.get_ticks_usec()
	root.get_node("GameState").save_store = SaveRepository.new(test_save_path)
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.session.balance = game.session.balance.duplicate() as NewsroomBalance
	game.session.balance.starting_health = 80.0
	game.session.balance.shift_seconds = 180.0
	game.session.balance.publication_limit = 10
	game._new_run(true)
	await create_timer(0.3).timeout
	var work: Control = game.work
	var popup: DeskFocus = work.popup
	var drawer: Control = work.get_node("%Drawer")
	_check(work.size == root.get_visible_rect().size and not game.get_node("Padding").visible, "Work desk fills the viewport without the old header")
	_check(work.get_node("%SourceText").text == game.session.current_article().source_text and not popup.active, "Source is readable directly on the desk")
	_check(not work.choices.visible and work.get_node("%Publish").disabled, "A new article waits for a headline")
	_check(drawer.expanded, "Stats are visible when starting the new desk")
	drawer.set_expanded(true)
	game.session.coffee_ready = true
	game.session.changed.emit()
	await create_timer(0.35).timeout
	_check(drawer.get_node("%SlidingPanel").position.x == 0.0, "Stats drawer opens completely")
	await _capture("desk_01_expanded")
	drawer.set_expanded(false)
	work.get_node("%HeadlineField").pressed.emit()
	await create_timer(0.65).timeout
	var count := 0
	for card in work.cards:
		if card.get_parent().visible:
			count += 1
	_check(count == 3 and work.choices_open, "Clicking headline field reveals three animated notes")
	await _capture("desk_02_choices")
	work.cards[0].pressed.emit()
	await create_timer(0.4).timeout
	_check(not popup.active and work.selected_index == 0 and game.session.total_published == 0 and not work.choices.visible, "Clicking a note sets a draft directly without payment")
	_check(work.get_node("%HeadlineField/Text").text == game.session.option_at(0).text and not work.get_node("%Publish").disabled, "Draft appears in the green field and enables publication")
	await _capture("desk_03_draft")
	work.get_node("%HeadlineField").pressed.emit()
	await create_timer(0.65).timeout
	_check(not work.cards[0].get_parent().visible and work.cards[1].get_parent().visible and work.cards[2].get_parent().visible, "Replacement offers only the two other headlines")
	work.cards[1].pressed.emit()
	await create_timer(0.4).timeout
	_check(work.selected_index == 1 and game.session.total_published == 0, "Replacing a draft still does not publish")
	work.get_node("%Publish").pressed.emit()
	_check(game.session.total_published == 1 and popup.active and work.popup_kind == work.DialogKind.RESULT, "Separate publication button applies effects and shows result")
	await create_timer(0.3).timeout
	_check(is_equal_approx(popup.size.x / popup.size.y, work.cards[1].size.x / work.cards[1].size.y), "Printed result zoom preserves the note's aspect ratio")
	var paid: int = game.session.money
	work.get_node("%Publish").pressed.emit()
	_check(game.session.money == paid and game.session.total_published == 1, "Repeated publication cannot award twice")
	await create_timer(0.3).timeout
	await _capture("desk_05_result")
	popup.primary_pressed.emit()
	await create_timer(0.3).timeout
	_check(work.selected_index == -1 and not work.choices.visible, "Next source resets the draft and note tray")
	work._open_choices(false)
	work._select_headline(0)
	# Desk controls become available after the overlay's 0.32-second exit.
	await create_timer(0.4).timeout
	var before: float = game.session.time_left
	var health: float = game.session.health
	_click_at(work.get_node("%Coffee/Cup"))
	await create_timer(0.3).timeout
	_check(not popup.active and game.session.time_left == before, "Coffee remains clickable after choosing a draft without changing time")
	_check(game.session.health == minf(100.0, health + 20.0) and not work.get_node("%Coffee/Cup").visible and work.get_node("%Coffee/Stain").visible, "Drinking hides cup and steam, retaining the coffee ring")
	work._hide_choices(false)
	game.session.combo_count = 3
	game.session.combo_type = 0
	game.session.time_left = 10.0
	game.session.changed.emit()
	await create_timer(0.3).timeout
	_check(work.get_node("%ComboBurst").visible and work.get_node("%ComboBurst").position.x > 410.0, "Combo stays right of the expanded drawer")
	_check(work.get_node_or_null("%Clock") == null, "Desk contains no countdown")
	await _capture("desk_06_combo")
	game.session.combo_count = 1
	game.session.changed.emit()
	await create_timer(0.2).timeout
	_check(not work.get_node("%ComboBurst").visible, "Breaking the combo hides its text")
	game.transitioning = false
	game._toggle_pause()
	_check(game.paused and work.process_mode == Node.PROCESS_MODE_DISABLED, "Desk pause suspends interactions and animation")
	game._toggle_pause()
	work.get_node("%FinishShift").pressed.emit()
	_check(game.view == game.View.HOME and game.get_node("Padding").visible and game.get_node("%HUD").visible, "Finishing the new desk returns to the existing home screen")
	game._run_active = false
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path.get_base_dir()))
