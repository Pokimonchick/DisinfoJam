extends SceneTree

var failures := 0
var checks := 0
var test_path := "user://contextual_tutorial_%d/campaign.json" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	create_timer(25.0).timeout.connect(func(): push_error("Tutorial test timed out"); quit(1))
	AudioServer.set_bus_mute(0, true)
	root.get_node("AudioManager").crossfade_seconds = 0.0
	_demo_order_checks()
	var state := root.get_node("GameState")
	state.save_store = SaveRepository.new(test_path)
	state.session = NewsroomSession.new()
	state.session.balance = NewsroomBalance.new()
	state.session.balance.starting_money = 500
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._new_run(true)
	await create_timer(0.3).timeout
	game._work_tutorial_done = false
	game._begin_tutorial("work")
	check(game.work.can_process() and game.work.tutorial_action == "headline", "The first prompt permits interaction with the headline field")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	game.tutorial.get_node("%Explanation").finish_reveal()
	game.tutorial._on_paper_input(key)
	game._tutorial_next()
	game._update_tutorial_progress()
	check(game._tutorial_step == 0, "Paper clicks, Space and manual Next cannot skip a required action")
	var field: Control = game.work.get_node("%HeadlineField")
	var local_point: Vector2 = game.tutorial.get_global_transform_with_canvas().affine_inverse() * (field.get_global_transform_with_canvas() * (field.size * 0.5))
	check(not game.tutorial._has_point(local_point), "The spotlight passes actual GUI clicks to the target")
	game.work._open_choices(false)
	game._update_tutorial_progress()
	check(game._tutorial_step == 1 and game.work.choices_open, "Opening the headline field reveals only the choice instruction")
	game._update_tutorial_progress()
	check(game._tutorial_step == 1, "The choice step waits for a selected headline")
	game.work._select_headline(0)
	game._update_tutorial_progress()
	check(game._tutorial_step == 2 and game.work.stamp.enabled, "Selecting a headline unlocks the stamp prompt")
	var stamp: DeskStamp = game.work.stamp
	check(stamp.begin_drag(stamp.get_global_transform_with_canvas() * Vector2(144, 105)), "The tutorial permits picking up the stamp")
	game._update_tutorial_progress()
	check(game._tutorial_step == 3 and stamp.dragging, "Picking up the stamp unlocks the publication prompt")
	stamp.cancel_interaction()
	game._update_tutorial_progress()
	check(game._tutorial_step == 3 and stamp.enabled, "Cancelling a carry keeps the publication step retryable")
	check(game.session.publish_headline(0), "The guided publication can complete normally")
	game._update_tutorial_progress()
	check(game._tutorial_step == 4, "Publication advances to results rather than completing all teaching")
	game.work._show_result(game.session.last_result)
	game._update_tutorial_progress()
	check(game.tutorial.visible and game.work.popup.visible, "The results prompt appears alongside the real result")
	game.session.acknowledge_publication()
	game._update_tutorial_progress()
	check(game._work_tutorial_done and game._tutorial_stage.is_empty(), "Acknowledging the result completes the work tutorial")
	game.work.popup.hide()
	game.work.popup.active = false
	game.work.show_article(false)
	game._pencil_tutorial_done = true
	game._seen_stories.append("day_2")
	game.session.finish_shift()
	game.session.start_shift()
	await create_timer(0.3).timeout

	# A legacy clean draft receives exactly one error without replacing marked text.
	game.session.proofreading_unlocked = true
	game.session.prepare_proofreading()
	game.session.proofreading.targets.clear()
	game.session.proofreading.display_text = game.session.proofreading.source_text
	game.session.proofreading.strokes.clear()
	game.work.show_article(false)
	game._pencil_tutorial_done = false
	game._begin_tutorial("pencil")
	await process_frame
	check(game.session.proofreading.targets.size() == 1, "The first pencil lesson guarantees one real typo")
	check(game.work.pencil.begin_pickup(Vector2(500, 500)), "The player can pick up the pencil during teaching")
	game._update_tutorial_progress()
	await process_frame
	game._update_tutorial_progress()
	check(game._tutorial_step == 1 and game._tutorial_word.visible, "The next prompt highlights the exact erroneous word")
	var target: Dictionary = game.session.proofreading.targets[0]
	check(str(target.typo) in game.tutorial.get_node("%Explanation").get_parsed_text(), "The prompt names the displayed error")
	check(game._save_progress(), "An action step can be saved")
	var document: Dictionary = state.save_store.load_document()
	check(not document.is_empty(), "Action guidance reloads: " + state.save_store.error_message)
	if document.is_empty():
		quit(1)
		return
	check(game._validate_save(document.sections) and document.sections.presentation.guidance.version == 2, "Action guidance survives save validation")
	var money: int = game.session.money
	var qualification: float = game.session.qualification
	var surface: ProofreadingSurface = game.work.proofreading_surface
	var label: RichTextLabel = surface.label
	var rect := Rect2()
	for word in surface._words:
		if int(word.start) == int(target.id):
			rect = word.rects[0]
	check(rect.has_area(), "The highlighted typo has actual proofreading geometry")
	var a := label.get_global_transform_with_canvas() * (rect.get_center() - Vector2(6, 0))
	var b := label.get_global_transform_with_canvas() * (rect.get_center() + Vector2(6, 0))
	check(surface.begin_stroke(a), "An underline can begin on the highlighted word")
	surface.extend_stroke(b)
	surface.finish_stroke()
	for frame in 100:
		game._update_tutorial_progress()
		if game._tutorial_step == 2:
			break
		await process_frame
	check(game._tutorial_step == 2, "Only a real correction unlocks returning the pencil")
	check(game.session.money == money and game.session.qualification == qualification, "Tutorial recognition does not apply publication rewards")
	game.work.pencil.return_to_rest()
	await create_timer(0.5).timeout
	game._update_tutorial_progress()
	check(game._pencil_tutorial_done and game.work.tutorial_action.is_empty(), "Returning the pencil completes its action lesson")
	game._home_tutorial_done = false
	game.session.finish_shift()
	await create_timer(0.3).timeout
	check(game._tutorial_stage == "home", "The home tutorial starts at the first useful action")
	game.home._open_shop()
	game._update_tutorial_progress()
	check(not game.tutorial.visible and game.home._panels.visible, "The shop remains fully usable without the prompt covering it")
	game.home._panels.hide_all()
	game._update_tutorial_progress()
	check(game._tutorial_step == 1 and game.tutorial.visible, "Closing the shop reveals the backpack instruction")
	game.home._open_info()
	game._update_tutorial_progress()
	game.home._panels.hide_all()
	game._update_tutorial_progress()
	check(game._tutorial_step == 2, "Closing Info/Bag reveals the sleep instruction")
	game.home._sleep()
	game._update_tutorial_progress()
	check(game._home_tutorial_done and game.home._sleep_left > 0, "Sleep completes teaching and the night can proceed")
	game._run_active = false
	game.queue_free()
	await create_timer(0.15).timeout
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path.get_base_dir()))
	print("CONTEXTUAL TUTORIAL: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func _demo_order_checks() -> void:
	for seed_value in 12:
		var session := NewsroomSession.new()
		session.reset(seed_value)
		session.player_id = "demo-order-test"
		session.run_id = "demo-order-run"
		var first: Array[String] = []
		for index in 10:
			first.append(session.articles[index].id)
		var user_ids: Array[String] = []
		for row in ArticleSequence.USER_SOURCES:
			user_ids.append(row.id)
		var sorted := first.duplicate()
		sorted.sort()
		user_ids.sort()
		check(sorted == user_ids, "All ten user articles precede Codex stories, seed %d" % seed_value)
		var logical := true
		for chain in preload("res://Data/story_chains.gd").CHAINS.values():
			var last := -2
			for id in chain:
				var at := first.find(id)
				logical = logical and at >= last + 2
				last = at
		check(logical, "User stories retain chain order and intervening articles")
		var pinned := session.articles[0]
		session.start_shift()
		var sections: Dictionary = JSON.parse_string(JSON.stringify(NewsroomSaveData.capture(session)))
		var restored := NewsroomSession.new()
		check(NewsroomSaveData.restore(restored, sections) and restored.articles[0].id == pinned.id, "Continue preserves the pinned draft while ordering future sources")
