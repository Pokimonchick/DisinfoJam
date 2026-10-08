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
	game.session.finish_shift()
	await process_frame
	check(game.view == game.View.HOME and game.session.published_today == 0, "An empty first shift can still end immediately")
	game.session.start_shift()
	await process_frame
	check(game.session.day == 2 and game.view == game.View.WORK, "The archive conversation no longer interrupts the start of shift two")
	var legacy_sections := NewsroomSaveData.capture(game.session)
	legacy_sections["presentation"] = {"screen": "story", "newsroom": {}, "guidance": {}, "story": {"id": "day_2", "page": 1, "seen": []}}
	check(game._validate_save(legacy_sections), "The old WORK placement of the day_2 conversation remains valid")
	game._home_tutorial_done = false
	game.session.finish_shift()
	await process_frame
	check(game.session.phase == NewsroomSession.Phase.HOME and game.view == game.View.STORY and game._story_id == "day_2", "The conversation opens after shift two before the room")
	check(game._save_progress(), "The moved story can be saved")
	var evening_document: Dictionary = state.save_store.load_document()
	check(not evening_document.is_empty() and game._validate_save(evening_document.sections), "The moved HOME story passes save validation")
	game._continue_run()
	await process_frame
	check(game.view == game.View.STORY and game._story_id == "day_2" and game.session.phase == NewsroomSession.Phase.HOME, "Continue retains the moved evening conversation")
	while game.view == game.View.STORY:
		game._advance_story()
	await process_frame
	check(game.view == game.View.HOME and game.tutorial.visible and game._tutorial_stage == "home", "Finishing the moved conversation returns home and preserves unfinished home teaching")
	game._finish_tutorial()
	game._on_phase_changed()
	await process_frame
	check(game.view == game.View.HOME and not game.tutorial.visible and "day_2" in game._seen_stories, "A seen archive conversation does not replay")
	game.session.start_shift()
	await process_frame
	await process_frame
	check(game.session.day == 3 and game.tutorial.visible and game._tutorial_stage == "pencil", "The first third-day working desk opens pencil teaching")
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
	check(state.save_store.write_document(old_document), "A pre-pencil guidance record remains valid")
	game._continue_run()
	await process_frame
	await process_frame
	check(game.tutorial.visible and game._tutorial_stage == "pencil" and game._tutorial_step == 0, "An old save already on day three receives pencil teaching once")
	game._finish_tutorial()
	check(game.session.publish_headline(0), "A pending-result migration fixture can publish its article")
	var pending_sections := NewsroomSaveData.capture(game.session)
	pending_sections["presentation"] = {"screen": "work", "newsroom": {"selected_index": 0}, "guidance": {"stage": "", "step": 0, "work_done": true, "home_done": true}, "story": {"id": "", "page": 0, "seen": ["day_2"]}}
	check(state.save_store.write_document({"sections": pending_sections}), "An old third-day save with pending results remains valid")
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
	check(game.view == game.View.HOME, "Legacy completion does not replay the moved conversation that evening")
	check(game.CHAPTER.episode_for_day(4) == "day_4", "The fourth-day morning episode keeps its original position")
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
