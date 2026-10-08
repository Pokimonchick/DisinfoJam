extends SceneTree

var checks := 0
var failures := 0
var _test_path := "user://pencil_desk_test_%d/campaign.json" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _button(point: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _move(point: Vector2, down := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event, true)
	await process_frame

func _capture(name: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("disinfo-pencil-desk-" + name + ".png"))

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var global_state := root.get_node("GameState")
	global_state.save_store = SaveRepository.new(_test_path)
	global_state.session = NewsroomSession.new()
	global_state.session.balance = NewsroomBalance.new()
	global_state.session.balance.starting_health = 90
	global_state.session.balance.starting_money = 200
	global_state.session.balance.starting_reputation = 80
	global_state.session.balance.starting_loyalty = 80
	global_state.session.balance.rent = 0
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._new_run(true)
	await create_timer(0.35).timeout
	var work = game.work
	var session: NewsroomSession = game.session
	check(not work.pencil.visible and not session.proofreading_unlocked, "The pencil is absent before the third shift")
	game._pencil_tutorial_done = true
	game._seen_stories.assign(game.CHAPTER.EPISODES.keys())
	work.source_reveal_seconds = 0
	work.result_delay_seconds = 0.05
	work.set_process(false)
	work.get_node("Canvas").set_process(false)
	var article := NewsArticle.from_row(session.articles[0].to_row())
	article.id = "pencil_fixture_first"
	article.source_title = "Проверка редакционного источника"
	article.source_text = ("Сегодня редакторы проверяют сообщения жителей. Рабочие обсуждают строительство городской школы. Николай сообщил: 2026 год начался спокойно.\n").repeat(12)
	article.provenance.clear()
	var next_article := NewsArticle.from_row(article.to_row())
	next_article.id = "pencil_fixture_next"
	session.articles.assign([article, next_article])
	session.article_cursor = 0
	session._resolved_article = null
	session.day = 2
	session.phase = NewsroomSession.Phase.HOME
	session.start_shift()
	await create_timer(0.35).timeout
	await process_frame
	var pencil: DeskPencil = work.pencil
	var surface: ProofreadingSurface = work.proofreading_surface
	var source: RichTextLabel = work.get_node("%SourceText")
	var bar := source.get_v_scroll_bar()
	var proof := session.proofreading
	check(session.day == 3 and work.visible and pencil.visible and pencil.enabled and surface.state == proof, "Third-shift desk binds the active proofreading state and exposes the pencil")
	check(proof.targets.size() == 1 and source.text == proof.display_text and article.source_text == proof.source_text, "First proofreading article displays one guaranteed typo and preserves its source")
	check(pencil.position == work.pencil_rest_position and pencil.position.y >= 930 and pencil.position.x >= 790, "Pencil rests in the bottom paper margin")
	await _capture("rest")
	if DisplayServer.get_name() != "headless":
		var model_image: Image = pencil.get_node("Render").get_texture().get_image()
		var visible := 0
		for y in range(0, model_image.get_height(), 8):
			for x in range(0, model_image.get_width(), 8):
				if model_image.get_pixel(x, y).a > 0.1:
					visible += 1
		check(visible > 30, "Native desk pencil renders visible 3D pixels")
	work._open_choices(false)
	work._select_headline(0)
	await _wait_choices(work)
	check(work.stamp.enabled and pencil.interaction_enabled, "A selected draft permits either desk tool at rest")
	var grip := pencil.get_global_transform_with_canvas() * Vector2(270, 65)
	await _button(grip, true)
	await _button(grip, false)
	check(pencil.held and not work.stamp.enabled and not work.stamp.begin_drag(work.stamp.contact_position()), "Click pickup holds the pencil and excludes the stamp")
	var typo_rect := Rect2()
	for word in surface._words:
		if word.typo:
			typo_rect = word.rects[0]
			break
	bar.value = maxf(0, typo_rect.position.y - 50)
	await process_frame
	var point := source.get_global_transform_with_canvas() * (typo_rect.get_center() - Vector2(0, bar.value))
	await _move(point - Vector2(10, 0))
	await _button(point - Vector2(10, 0), true)
	await _move(point + Vector2(10, 0), true)
	await _button(point + Vector2(10, 0), false)
	check(proof.strokes.size() == 1 and proof.settlement().corrected == 1 and pencil.held, "Held LMB draws a text correction and release preserves the held pencil")
	if proof.strokes.is_empty():
		quit(1)
		return
	check(not work.undo_stroke.disabled and session.qualification == 70, "Finished marks enable Undo and defer qualification settlement")
	var undo_point: Vector2 = work.undo_stroke.get_global_transform_with_canvas() * (work.undo_stroke.size * 0.5)
	await _move(undo_point)
	await _button(undo_point, true)
	await _button(undo_point, false)
	check(proof.strokes.is_empty() and proof.settlement().corrected == 0 and pencil.held, "Actual Undo works while holding the pencil and reverses its correction")
	await _move(point - Vector2(10, 0))
	await _button(point - Vector2(10, 0), true)
	await _move(point + Vector2(10, 0), true)
	await _button(point + Vector2(10, 0), false)
	var original_marks := proof.to_data()
	var anchored: Dictionary = proof.strokes[0].segments[0]
	var before := surface._segment_body_point(anchored, anchored.points[0])
	var old_scroll := bar.value
	bar.value = old_scroll - 25 if old_scroll > 25 else old_scroll + 25
	var after := surface._segment_body_point(anchored, anchored.points[0])
	check(is_equal_approx(before.y - after.y, bar.value - old_scroll) and proof.to_data() == original_marks, "Integrated marks follow source scrolling without changing saved geometry")
	await _move(work.get_node("Canvas/World").get_global_transform_with_canvas() * Vector2(900, 980))
	await _capture("marked")
	await _button(point, true, MOUSE_BUTTON_RIGHT)
	await _button(point, false, MOUSE_BUTTON_RIGHT)
	check(not pencil.held and pencil.position == work.pencil_rest_position and work.stamp.enabled, "Right click returns the pencil and re-enables the stamp")
	var stamp_grip: Vector2 = work.stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	check(work.stamp.begin_drag(stamp_grip) and not pencil.interaction_enabled and not pencil.begin_pickup(grip), "Holding the stamp excludes pencil pickup")
	work.stamp.cancel_interaction()
	check(pencil.interaction_enabled and proof.to_data() == original_marks, "Returning the stamp preserves marks and re-enables the pencil")
	check(pencil.begin_pickup(grip), "Pencil can be lifted before pausing")
	game._toggle_pause()
	check(game.paused and not pencil.held and not pencil.can_process() and proof.to_data() == original_marks, "Pause returns and disables the pencil while retaining completed marks")
	game._toggle_pause()
	check(pencil.can_process() and pencil.interaction_enabled, "Resume restores pencil interaction")
	check(pencil.begin_pickup(grip), "Pencil can be lifted before a chooser modal")
	pencil.cancel_interaction()
	work._open_choices(false)
	check(not pencil.interaction_enabled and not pencil.begin_pickup(grip) and not work.stamp.enabled, "Headline chooser modal disables both tools")
	work._hide_choices(false)
	var unchanged := proof.to_data()
	var unchanged_id := session.current_article().id
	session.finish_shift()
	await create_timer(0.35).timeout
	check(session.phase == NewsroomSession.Phase.HOME and session.proofreading.to_data() == unchanged, "Going home retains the unfinished article's generated text and strokes")
	session.start_shift()
	await create_timer(0.35).timeout
	check(session.day == 4 and session.current_article().id == unchanged_id and session.proofreading.to_data() == unchanged and surface.state == session.proofreading and source.text == unchanged.display_text, "The next shift resumes the same unfinished article and marks")
	work._open_choices(false)
	work._select_headline(0)
	await _wait_choices(work)
	bar.value = bar.max_value * 0.45
	var reading_scroll := bar.value
	var display_before := source.text
	var marks_before := session.proofreading.to_data()
	var money_before := session.money
	var qualification_before := session.qualification
	var contact := source.get_global_transform_with_canvas() * Vector2(120, 170)
	stamp_grip = work.stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	check(work.stamp.begin_drag(stamp_grip), "Resumed article can be picked up for publication")
	work.stamp.move_drag(stamp_grip + contact - work.stamp.contact_position())
	work.stamp.finish_drag()
	await create_timer(0.9).timeout
	check(session.total_published == 1 and session.last_result.proofreading.corrected == 1 and session.qualification == qualification_before + 1, "Actual stamp contact settles the correction once")
	check(session.money == money_before + session.last_result.money, "Stamp settlement records its publication and proofreading money together")
	check(is_equal_approx(bar.value, reading_scroll) and source.text == display_before and session.proofreading.to_data() == marks_before, "Live publication result preserves reading scroll, display text and marks")
	check(work.popup.active and not pencil.interaction_enabled and not work.stamp.enabled, "Publication feedback blocks both tools")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(work.popup.opening_seconds).timeout
	await _capture("publication")
	game._run_active = false
	game.queue_free()
	await process_frame
	print("PENCIL DESK INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _wait_choices(work: Control) -> void:
	for frame in 180:
		if not work._choices_animating:
			return
		await process_frame
