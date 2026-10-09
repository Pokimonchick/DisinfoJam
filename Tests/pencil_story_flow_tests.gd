extends SceneTree

var checks := 0
var failures := 0
var _test_path := "user://pencil_story_%d/campaign.json" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.get_node("AudioManager").crossfade_seconds = 0.0
	var state := root.get_node("GameState")
	state.save_store = SaveRepository.new(_test_path)
	state.session = NewsroomSession.new()
	state.session.balance = NewsroomBalance.new()
	state.session.balance.starting_money = 500
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await create_timer(0.3).timeout
	game._new_run(true)
	await process_frame
	check(not game.session.proofreading_unlocked and not game.work.pencil.visible, "The first shift has no proofreading tool")
	game._home_tutorial_done = false
	game.session.finish_shift()
	await process_frame
	check(game.view == game.View.HOME and game.session.published_today == 0, "An empty first shift can still end immediately")
	check(game.tutorial.visible and game._tutorial_stage == "home" and not "day_2" in game._seen_stories, "The first home evening precedes the pencil conversation")
	game._finish_tutorial()
	game.session.start_shift()
	await process_frame
	check(game.session.day == 2 and game.view == game.View.STORY and game._story_id == "day_2", "The archive conversation opens before the second-shift desk")
	var legacy_sections := NewsroomSaveData.capture(game.session)
	legacy_sections["presentation"] = {"screen": "story", "newsroom": {}, "guidance": {}, "story": {"id": "day_2", "page": 1, "seen": []}}
	check(game._validate_save(legacy_sections), "The WORK placement of the day_2 conversation is valid")
	check(game._save_progress(), "The moved story can be saved")
	var morning_document: Dictionary = state.save_store.load_document()
	check(not morning_document.is_empty() and game._validate_save(morning_document.sections), "The moved WORK story passes save validation")
	game._continue_run()
	await process_frame
	check(game.view == game.View.STORY and game._story_id == "day_2" and game.session.phase == NewsroomSession.Phase.WORK, "Continue retains the second-shift morning conversation")
	while game.view == game.View.STORY:
		game._advance_story()
	await process_frame
	await process_frame
	check(game.view == game.View.WORK and "day_2" in game._seen_stories and game.session.proofreading_unlocked, "Finishing the archive conversation opens the desk with proofreading")
	check(game.session.day == 2 and game.tutorial.visible and game._tutorial_stage == "pencil", "The first second-day working desk opens pencil teaching")
	var before_money: int = game.session.money
	var before_qualification: float = game.session.qualification
	for lesson_index in range(game.INTERFACE_LESSONS.pencil().size()):
		game._tutorial_step = lesson_index
		game._present_tutorial_step()
		await process_frame
		check(game.tutorial._highlight.has_area(), "Pencil lesson %d highlights a visible desk item" % lesson_index)
	check(game.session.money == before_money and game.session.qualification == before_qualification, "Pencil teaching does not apply publication or proofreading rewards")
	game._tutorial_step = 2
	game._present_tutorial_step()
	check(game._save_progress(), "An unfinished pencil lesson can be saved")
	var pencil_document: Dictionary = state.save_store.load_document()
	check(not pencil_document.is_empty() and pencil_document.sections.presentation.guidance.stage == "pencil", "Pencil guidance is stored under its own stage")
	game._continue_run()
	await process_frame
	await process_frame
	check(game.tutorial.visible and game._tutorial_stage == "pencil" and game._tutorial_step == 2, "Continue restores the pencil lesson step")
	game._finish_tutorial()
	game._on_phase_changed()
	await process_frame
	check(game._pencil_tutorial_done and not game.tutorial.visible, "Finished pencil teaching does not repeat")
	var old_document: Dictionary = pencil_document.duplicate(true)
	old_document.sections.presentation.guidance = {"stage": "", "step": 0, "work_done": true, "home_done": true}
	old_document.sections.run.proofreading_unlocked = false
	old_document.sections.run.proofreading_started = false
	old_document.sections.run.erase("proofreading")
	check(state.save_store.write_document(old_document), "A pre-pencil guidance record remains valid")
	game._continue_run()
	await process_frame
	await process_frame
	check(game.session.proofreading_unlocked and game.tutorial.visible and game._tutorial_stage == "pencil" and game._tutorial_step == 0, "An old save with a locked pencil on day two receives the tool and teaching once")
	game._finish_tutorial()
	check(game.session.publish_headline(0), "A pending-result migration fixture can publish its article")
	var pending_sections := NewsroomSaveData.capture(game.session)
	pending_sections["presentation"] = {"screen": "work", "newsroom": {"selected_index": 0}, "guidance": {"stage": "", "step": 0, "work_done": true, "home_done": true}, "story": {"id": "", "page": 0, "seen": ["day_2"]}}
	check(state.save_store.write_document({"sections": pending_sections}), "An old second-day save with pending results remains valid")
	game._continue_run()
	await process_frame
	await process_frame
	check(game.session.awaiting_acknowledgement and game.work.popup.visible and not game.tutorial.visible, "Pencil teaching waits until the restored publication result is closed")
	game.work.popup.finish_opening()
	game.work._close_focus()
	await create_timer(game.work.popup.closing_seconds + game.work.stamp_area.absorption_seconds + 0.15).timeout
	check(not game.session.awaiting_acknowledgement and game.tutorial.visible and game._tutorial_stage == "pencil", "Acknowledging the old result starts pencil teaching on the next article")
	game._finish_tutorial()
	var invalid: Dictionary = pencil_document.sections.duplicate(true)
	invalid.presentation.guidance.step = game.INTERFACE_LESSONS.pencil().size()
	check(not game._validate_save(invalid), "A pencil step beyond the last lesson is rejected")
	invalid = pencil_document.sections.duplicate(true)
	invalid.presentation.guidance.pencil_done = "true"
	check(not game._validate_save(invalid), "The pencil completion flag must be boolean")
	invalid = pencil_document.sections.duplicate(true)
	invalid.presentation.guidance.pencil_done = true
	check(not game._validate_save(invalid), "A completed pencil lesson cannot remain active in a save")
	check(state.save_store.write_document({"sections": legacy_sections}), "The old WORK day_2 save can still be written")
	game._continue_run()
	await process_frame
	check(game.view == game.View.STORY and game._story_page == 1 and game.session.phase == NewsroomSession.Phase.WORK, "Legacy morning dialogue resumes at its existing page")
	game._advance_story()
	await process_frame
	check(game.view == game.View.WORK and "day_2" in game._seen_stories, "Finishing a legacy dialogue continues its existing second shift")
	game.session.finish_shift()
	await process_frame
	check(game.view == game.View.HOME, "The archive conversation does not replay after the second shift")
	var legacy_evening := NewsroomSaveData.capture(game.session)
	legacy_evening["presentation"] = {"screen": "story", "newsroom": {}, "guidance": {}, "story": {"id": "day_2", "page": 1, "seen": []}}
	check(game._validate_save(legacy_evening) and state.save_store.write_document({"sections": legacy_evening}), "An old HOME day_2 conversation remains valid")
	game._continue_run()
	await process_frame
	check(game.view == game.View.STORY and game._story_page == 1 and game.session.phase == NewsroomSession.Phase.HOME, "Legacy evening dialogue resumes at its saved page")
	game._advance_story()
	await process_frame
	check(game.view == game.View.HOME and "day_2" in game._seen_stories, "Finishing a legacy evening dialogue returns to the room")
	check(game.CHAPTER.episode_for_day(4) == "day_4", "The fourth-day morning episode keeps its original position")
	_mur_headline_checks()
	game.session.ending = NewsroomSession.Ending.QUALIFICATION_FIRED
	game.session.phase = NewsroomSession.Phase.ENDED
	game._on_phase_changed()
	check(game.view == game.View.ENDING and game.get_node("%NarrativeTitle").text == "Последняя корректура", "Qualification dismissal has its own localized ending")
	game._run_active = false
	game.queue_free()
	# Let the audio thread release stopped music playbacks before test shutdown.
	await create_timer(0.1).timeout
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_path.get_base_dir()))
	print("PENCIL STORY FLOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _mur_headline_checks() -> void:
	var mur: NewsArticle
	var resolution: NewsArticle
	for row in preload("res://Data/community_articles.gd").ROWS:
		if row.id == "rat_complaint":
			mur = NewsArticle.from_row(row)
		elif row.id == "rat_resolution":
			resolution = NewsArticle.from_row(row)
	for original in preload("res://Docs/OriginalArticles/community_articles_original.gd").ROWS:
		if original.id == mur.id:
			for index in 2:
				check(mur.headlines[index].text == original.options[index][0], "Mr Mur's original headline %d is preserved" % index)
	var refreshed := mur.headlines[2]
	check("коту под хвост" in refreshed.text and [refreshed.money, refreshed.reputation, refreshed.loyalty, refreshed.editorial_type] == [27, 6, 8, 2], "The humorous third headline keeps its existing trust-in-inspection effects")
	check("коту под хвост" in ArticleSequence.resolve(resolution, {"rat_complaint": 2}).source_text, "The next story answers the refreshed headline")
	var source_before := mur.source_text
	mur.headlines[2] = HeadlineOption.from_row(["Не будем отвергать санитарную проверку по непроверенной жалобе", 27, 6, 8, refreshed.explanation, 2])
	var fixture := NewsroomSession.new()
	fixture.balance = NewsroomBalance.new()
	fixture.reset(41)
	fixture.player_id = "mur-headline-test"
	fixture.run_id = "mur-headline-run"
	fixture.articles.assign([mur, resolution])
	fixture.start_shift()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(NewsroomSaveData.capture(fixture)))
	var restored := NewsroomSession.new()
	check(NewsroomSaveData.restore(restored, snapshot) and restored.articles[0].headlines[2].text == refreshed.text and restored.articles[0].source_text == source_before, "An untouched unpublished saved headline upgrades while the current letter stays intact")
	check(restored.money == fixture.money and restored.journal == fixture.journal, "Refreshing a draft never alters cash or publication history")
	var custom: Dictionary = snapshot.duplicate(true)
	custom.content.articles[0].text += "\nМоя ручная правка."
	check(NewsroomSaveData.restore(restored, custom) and restored.articles[0].headlines[2].text == mur.headlines[2].text and restored.articles[0].source_text == custom.content.articles[0].text, "A manually edited letter is not migrated")
	custom = snapshot.duplicate(true)
	custom.content.articles[0].options[2][4] += " Моя правка последствий."
	check(NewsroomSaveData.restore(restored, custom) and restored.articles[0].headlines[2].explanation == custom.content.articles[0].options[2][4] and restored.articles[0].headlines[2].text == mur.headlines[2].text, "A manually edited option is not migrated")
	fixture.option_order.assign([2, 0, 1])
	check(fixture.publish_headline(0), "A legacy published-headline fixture remains playable")
	snapshot = JSON.parse_string(JSON.stringify(NewsroomSaveData.capture(fixture)))
	check(NewsroomSaveData.restore(restored, snapshot) and restored.money == fixture.money and restored.journal == snapshot.run.journal and restored.last_result == snapshot.run.last_result and restored.articles[0].headlines[2].text == mur.headlines[2].text, "Published old headlines, their cash and pending result remain unchanged")
