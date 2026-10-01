extends SceneTree

var failures: Array[String] = []
var checks := 0
var test_path := "user://save_tests_%d/campaign.json" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func fresh() -> NewsroomSession:
	var session := NewsroomSession.new()
	session.balance = NewsroomBalance.new()
	session.reset(42)
	session.player_name = "Лиса"
	session.player_id = "player-test"
	session.run_id = "run-test"
	return session

func _run() -> void:
	_test_snapshots()
	_test_benefit_save()
	_test_files()
	_test_campaign()
	await _test_menu_and_resume()
	print("SAVE TESTS: %d checks, %d failures" % [checks, failures.size()])
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path.get_base_dir()))
	quit(0 if failures.is_empty() else 1)

func _test_snapshots() -> void:
	var session := fresh()
	session.start_shift()
	session.tick_work(8.25)
	session.coffee_ready = true
	session.drink_coffee()
	session.publish_headline(0)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(NewsroomSaveData.capture(session)))
	var restored := fresh()
	check(NewsroomSaveData.restore(restored, snapshot), "Restore a JSON round trip")
	check(restored.time_left == session.time_left and restored.health == session.health, "Exact inert time and stamina")
	check(restored.money == session.money and restored.combo_count == 1, "Effects and combo survive loading")
	check(restored.coffee_used_today and not restored.coffee_ready, "Consumed coffee cannot be used twice")
	check(restored.awaiting_acknowledgement and restored.article_cursor == 1, "Published result and next article cursor survive")
	check(restored.articles[0].id == session.articles[0].id and restored.current_article().id == session.current_article().id, "The shuffled article queue survives loading")
	var health_during_result := restored.health
	restored.tick_work(20.0)
	check(restored.health == health_during_result, "Restored feedback pauses stamina drain")
	var money_before := restored.money
	check(not restored.publish_headline(0) and restored.money == money_before, "Loading a result cannot award it twice")
	restored.acknowledge_publication()
	check(not restored.drink_coffee() and restored.health == health_during_result and not restored.coffee_ready, "Loading never replenishes consumed coffee")
	session.acknowledge_publication()
	restored.publish_headline(0)
	session.publish_headline(0)
	check(restored.option_order == session.option_order and restored.last_result == session.last_result, "RNG resumes deterministically")
	var generated := NewsArticle.from_row(session.articles[0].to_row())
	generated.id = "generated-future-001"
	generated.source_text = "Материал, которого больше нет в каталоге."
	generated.provenance = {"provider": "future", "generation_id": "001"}
	session.articles.append(generated)
	snapshot = NewsroomSaveData.capture(session)
	check(NewsroomSaveData.restore(restored, snapshot) and restored.articles.back().source_text == generated.source_text, "Save contains self-contained generated content")
	check(restored.articles.back().provenance == generated.provenance, "Content provenance survives")
	snapshot.run.erase("food_stocked")
	snapshot.run.erase("campaign_days")
	check(NewsroomSaveData.restore(restored, snapshot) and not restored.food_stocked and restored.campaign_days == 5, "Missing optional fields use defaults")
	var invalid := snapshot.duplicate(true)
	invalid.run.option_order = [0, 0, 2]
	check(not NewsroomSaveData.restore(restored, invalid), "Invalid option order rejected before applying state")
	invalid = snapshot.duplicate(true)
	invalid.content.articles[0].options[0][1] = "bad amount"
	check(not NewsroomSaveData.validate(invalid), "Malformed article effects rejected")
	var extended := SaveRepository.merge_sections({"run": {"future_feature": 17}}, snapshot)
	check(extended.run.future_feature == 17, "Unknown fields survive saving")

func _test_benefit_save() -> void:
	var session := fresh()
	session.loyalty = session.balance.state_approval.threshold
	session.start_shift()
	session.tick_work(5.0)
	var saved_health := session.health
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(NewsroomSaveData.capture(session)))
	var restored := fresh()
	check(NewsroomSaveData.validate(snapshot), "Fresh work with zero legacy time validates")
	check(NewsroomSaveData.restore(restored, snapshot), "Restore a shift with approval recovery")
	check(restored.approval_stamina_applied and restored.health == saved_health and restored.time_left == 0.0, "Restoring does not regrant approval stamina")
	check(NewsroomSaveData.restore(restored, snapshot) and restored.health == saved_health, "Repeated loading never duplicates approval recovery")
	snapshot.run.erase("approval_stamina_applied")
	snapshot.run.erase("approval_time_applied")
	check(NewsroomSaveData.restore(restored, snapshot) and not restored.approval_stamina_applied and not restored.approval_time_applied and restored.health == saved_health, "Old saves default approval flags without recovery")
	restored.tick_work(200.0)
	check(restored.phase == NewsroomSession.Phase.WORK and is_equal_approx(restored.health, saved_health - 20.0), "Old zero-time saves keep draining without automatically finishing")
	check(restored.publish_headline(0), "Old zero-time saves remain publishable")
	snapshot.run.time_left = 195.0
	snapshot.run.shift_length = 200.0
	snapshot.run.approval_time_applied = true
	check(NewsroomSaveData.restore(restored, snapshot) and restored.time_left == 195.0 and restored.shift_length == 200.0 and restored.approval_time_applied, "Old saves preserve legacy time values and flags")
	restored.tick_work(220.0)
	check(restored.phase == NewsroomSession.Phase.WORK and restored.time_left == 195.0 and restored.health == saved_health - 22.0, "Legacy countdown and approval flag never control gameplay")

func _test_files() -> void:
	var repository := SaveRepository.new(test_path)
	repository.validator = NewsroomSaveData.validate
	var document := {"sections": NewsroomSaveData.capture(fresh())}
	check(repository.write_document(document), "Write first save")
	document.sections.run.money = 77
	check(repository.write_document(document), "Atomically replace existing save")
	check(repository.load_document().sections.run.money == 77, "Load latest save")
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var backup := repository.load_document()
	check(repository.recovered_backup and backup.sections.run.money == 35, "Recover previous save from corrupt primary")
	check(repository.write_document(backup), "Repair main without destroying valid backup")
	file = FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format_version": 999, "sections": document.sections}))
	file.close()
	check(repository.load_document().is_empty() and repository.error_message.contains("более новой"), "Future save format is protected from silent rollback")
	# A migration is explicit and runs on a copy before validation.
	repository.migrations[0] = func(old: Dictionary) -> Dictionary:
		old["sections"] = old["legacy_sections"]
		old.erase("legacy_sections")
		return old
	file = FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format_version": 0, "legacy_sections": document.sections}))
	file.close()
	check(repository.load_document().get("format_version", 0) == 1, "Registered format migration runs")

func _test_campaign() -> void:
	var session := fresh()
	session.start_shift()
	session.health = 25.0
	session.finish_shift()
	session.start_shift()
	check(session.health == 35.0, "Sleep recovery is applied once when the next shift begins")
	var after_sleep := fresh()
	check(NewsroomSaveData.restore(after_sleep, NewsroomSaveData.capture(session)) and after_sleep.health == 35.0, "Sleep recovery survives saving without being applied again")
	session = fresh()
	session.start_shift()
	session.completed_shifts = 4
	session.day = 5
	session.money = session.campaign_money + session.balance.rent
	session.finish_shift()
	check(session.ending == NewsroomSession.Ending.VICTORY and session.endless_unlocked, "Fifth shift awards victory after rent")
	var restored := fresh()
	check(NewsroomSaveData.restore(restored, NewsroomSaveData.capture(session)) and restored.campaign_completed and restored.player_id == session.player_id, "Completed campaign retains profile and future unlock")
	session = fresh()
	session.start_shift()
	session.completed_shifts = 4
	session.money = session.campaign_money + session.balance.rent - 1
	session.finish_shift()
	check(session.ending == NewsroomSession.Ending.VICTORY and session.campaign_completed, "A cash target no longer gates completion")

func _test_menu_and_resume() -> void:
	var state := root.get_node("GameState")
	state.save_store = SaveRepository.new(test_path)
	state.session = fresh()
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game.get_node("%NewGame").pressed.emit()
	check(game.view == game.View.PROFILE and game.get_node("%NewRunWarning").text.contains("заменит"), "New campaign warns about replacing the slot")
	game.get_node("%StartStory").pressed.emit()
	await process_frame
	check(game.view == game.View.INTRO and game.session.player_name == NewsroomSession.CAMPAIGN_HERO_NAME, "Campaign starts the chapter with the fixed heroine name")
	game._show_menu()
	game._continue_run()
	check(game.view == game.View.INTRO, "Continue restores the prologue")
	game.lesson = 2
	game._show_lesson()
	game._show_menu()
	game._continue_run()
	check(game.view == game.View.TUTORIAL and game.lesson == 2, "Continue restores the tutorial page")
	game.session.start_shift()
	game.session.shift_length = 180.0
	game.session.time_left = 42.5
	game.work._open_choices(false)
	game.work._select_headline(1)
	game.work.get_node("%Drawer").set_expanded(false)
	var name_id: String = game.session.player_id
	game._show_menu()
	game._continue_run()
	check(game.session.time_left == 42.5 and game.work.selected_index == 1 and not game.work.popup.active and game.session.total_published == 0, "Continue preserves legacy time and draft without publishing")
	check(not game.work.get_node("%Drawer").expanded, "Continue preserves the collapsed stats drawer")
	game.transitioning = false
	game._autosave_elapsed = game.AUTOSAVE_SECONDS
	game._process(0.1)
	await process_frame
	check(is_equal_approx(state.save_store.load_document().sections.run.time_left, game.session.time_left), "Periodic autosave records time without a player action")
	game._show_menu()
	game._continue_run()
	check(game.work.selected_index == 1 and not game.work.choices_open and not game.work.popup.active and game.session.total_published == 0, "A saved draft restores on the article without being published")
	game.work.restore_presentation({"layout_version": 2, "dialog": "confirm", "selected_index": 1, "preview_index": 2, "choices_open": true})
	check(game.work.selected_index == 2 and not game.work.popup.active and game.session.total_published == 0, "An old preview save becomes a draft without publishing")
	game.work.restore_presentation({"layout_version": 2, "selected_index": 1})
	game.work._publish_selected()
	var money_before: int = game.session.money
	game._show_menu()
	game._continue_run()
	check(game.work.popup_kind == game.work.DialogKind.RESULT and game.session.money == money_before, "Result restores without repeating payment")
	game.session.money = 200
	game.session.finish_shift()
	game.session.buy_food(true)
	game.session.buy_coffee()
	game._show_menu()
	game._continue_run()
	check(game.view == game.View.HOME and game.session.coffee_ready and game.session.food_stocked, "Home inventory and purchases restore")
	# Restore an extension before its scene exists, then register the scene later.
	state.restore_save_sections({"future_inventory": {"items": ["key"]}, "absent_scene": {"done": true}})
	var inventory := {"items": []}
	state.register_save_section("future_inventory", func(): return inventory.duplicate(true), func(data: Dictionary): inventory.items = data.get("items", []))
	check(inventory.items == ["key"], "Late scene registration receives its saved data")
	inventory.items.clear()
	game._save_progress()
	check(state.save_store.load_document().sections.extensions.future_inventory.items.is_empty(), "Removed extension items are not resurrected by merging")
	check(state.save_store.load_document().sections.extensions.absent_scene.done, "An unloaded scene keeps its saved section")
	state.unregister_save_section("future_inventory")
	game._show_menu()
	game.queue_free()
	await process_frame
	state.session = fresh()
	game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._continue_run()
	check(game.session.player_id == name_id and game.view == game.View.HOME, "Disk save works in a fresh game controller")
	game.session.start_shift()
	game.session.day = 5
	game.session.completed_shifts = 4
	game.session.money = 245
	game.session.finish_shift()
	game._show_menu()
	game._continue_run()
	check(game.view == game.View.STORY and game._story_id == "finale", "Completed week resumes the unfinished finale")
	check(not game.get_node("%NarrativeSecondary").visible, "Campaign cutscenes have no redundant menu button")
	game._narrative_next()
	game._narrative_next()
	game._show_menu()
	game._continue_run()
	check(game.view == game.View.ENDING and game.session.campaign_completed, "Campaign victory can be reopened from menu")
	game.work.restore_presentation({"layout_version": 2, "selected_index": 1, "choices_open": true, "drawer_expanded": false})
	game._new_run(true)
	check(game.work.get_node("%Drawer").expanded and game.work.selected_index == -1 and not game.work.choices_open and not game.work.popup.active, "New campaign resets a collapsed drawer and old draft/options")
	game._run_active = false
	game.queue_free()
	await process_frame
