extends SceneTree

const Pager = preload("res://Scripts/source_pager.gd")

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
	var eraser: DeskPencil = work.eraser
	var surface: ProofreadingSurface = work.proofreading_surface
	var source: RichTextLabel = work.get_node("%SourceText")
	var bar := source.get_v_scroll_bar()
	var pager: Pager = work.source_pager
	var proof := session.proofreading
	var brush_material := surface.material as ShaderMaterial
	var source_material := source.material as ShaderMaterial
	check(brush_material != source_material and float(brush_material.get_shader_parameter("pencil_grain_strength")) > 0.0 and float(source_material.get_shader_parameter("pencil_grain_strength")) == 0.0, "Pencil texture is isolated from source glyphs")
	work._set_source_reveal(0.4)
	check(is_equal_approx(float(brush_material.get_shader_parameter("reveal_progress")), 0.4) and is_equal_approx(float(source_material.get_shader_parameter("reveal_progress")), 0.4), "Source and textured marks reveal together")
	work._set_source_reveal(1.0)
	work._set_source_ink_parameter("absorption_progress", 0.35)
	check(is_equal_approx(float(brush_material.get_shader_parameter("absorption_progress")), 0.35) and is_equal_approx(float(source_material.get_shader_parameter("absorption_progress")), 0.35), "Source and textured marks absorb together")
	work._set_source_ink_parameter("absorption_progress", 0.0)
	check(session.day == 3 and work.visible and pencil.visible and pencil.enabled and surface.state == proof, "Third-shift desk binds the active proofreading state and exposes the pencil")
	check(proof.targets.size() == 1 and pager.source_text == proof.display_text and article.source_text == proof.source_text, "First proofreading article contains one guaranteed typo across its sheets and preserves its source")
	pager.go_to_character(int(proof.targets[0].start))
	await process_frame
	await process_frame
	check(pencil.position == work.pencil_rest_position and pencil.position.y >= 930 and pencil.position.x >= 790, "Pencil rests in the bottom paper margin")
	var pencil_model: Node3D = pencil.get_node("Render/ModelRoot")
	var pencil_camera: Camera3D = pencil.get_node("Render/Camera")
	var lacquer := (pencil_model.get_node("Barrel").mesh.material as ShaderMaterial).get_shader_parameter("lacquer_texture") as Texture2D
	check(lacquer != null and lacquer.get_image().has_mipmaps(), "Lacquer texture supplies mipmaps for the small desk projection")
	var rear_projection := pencil_camera.unproject_position(pencil_model.transform * Vector3(1.63, 0.127, 0))
	var tip_projection := pencil_camera.unproject_position(pencil_model.transform * pencil.model_contact)
	check(rear_projection.y > tip_projection.y and pencil.position == work.pencil_rest_position, "Rest rotation brings the rear eraser toward the player without moving the desk anchor")
	check(eraser.position.x + eraser.size.x < pencil.position.x, "Separate eraser rests to the left of the pencil without overlapping its grip")
	check(pencil.z_index < work.get_node("Canvas/World/Shadows").z_index, "Desk shadows overlay the pencil at rest and while held")
	await _capture("rest")
	if DisplayServer.get_name() != "headless":
		var model_image: Image = pencil.get_node("Render").get_texture().get_image()
		if "--capture" in OS.get_cmdline_user_args():
			model_image.save_png(OS.get_environment("TEMP").path_join("disinfo-pencil-desk-model.png"))
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
	var point := source.get_global_transform_with_canvas() * (typo_rect.get_center() - Vector2(0, bar.value))
	await _move(point - Vector2(10, 0))
	await create_timer(0.25).timeout
	check(pencil.contact_position().distance_to(point - Vector2(10, 0)) < 2, "Red-core model retains its contact point at the pointer after pickup rotation")
	await _button(point - Vector2(10, 0), true)
	await _move(point + Vector2(10, 0), true)
	await _button(point + Vector2(10, 0), false)
	check(proof.strokes.size() == 1 and proof.settlement().corrected == 1 and pencil.held, "Held LMB draws a text correction and release preserves the held pencil")
	if proof.strokes.is_empty():
		quit(1)
		return
	check(eraser.visible and session.qualification == 70 and work.get_node_or_null("Canvas/World/UndoStroke") == null, "Physical eraser replaces Undo and qualification settles only at publication")
	await _button(point, true, MOUSE_BUTTON_RIGHT)
	await _button(point, false, MOUSE_BUTTON_RIGHT)
	var eraser_point := eraser.get_global_transform_with_canvas() * eraser.grab_rect.get_center()
	await _button(eraser_point, true)
	await _button(eraser_point, false)
	check(eraser.held and not pencil.interaction_enabled and not work.stamp.enabled, "Holding the eraser excludes pencil and stamp pickup")
	await _move(point)
	await create_timer(0.25).timeout
	check(eraser.contact_position().distance_to(point) < 2, "Lifted eraser nose stays aligned with the erasing pointer")
	var eraser_image: TextureRect = eraser.get_node("Image")
	var eraser_camera: Camera3D = eraser.get_node("Render/Camera")
	var eraser_model: Node3D = eraser.get_node("Render/ModelRoot")
	var model_center := eraser_image.position + eraser_camera.unproject_position(eraser_model.position) * eraser_image.size / Vector2(eraser.get_node("Render").size)
	var visual_center := eraser.get_global_transform_with_canvas() * model_center
	check(visual_center.distance_to(point) > eraser.erase_radius, "Eraser grip is outside the brush; only its nose erases")
	check(eraser.z_index < work.get_node("Canvas/World/Shadows").z_index, "Desk shadows overlay the eraser")
	await _capture("eraser-held")
	await _button(point, true)
	await _button(point, false)
	check(proof.strokes.is_empty() and proof.settlement().corrected == 0 and eraser.held, "Physical eraser removes the correction and its reward")
	await _button(point, true, MOUSE_BUTTON_RIGHT)
	await _button(point, false, MOUSE_BUTTON_RIGHT)
	await _button(grip, true)
	await _button(grip, false)
	await _move(point - Vector2(10, 0))
	await _button(point - Vector2(10, 0), true)
	await _move(point + Vector2(10, 0), true)
	await _button(point + Vector2(10, 0), false)
	# A blank-paper gesture exposes the brush texture without marking another word.
	var desk_transform: Transform2D = work.get_node("Canvas/World").get_global_transform_with_canvas()
	var brush_start := desk_transform * Vector2(1100, 980)
	await _move(brush_start)
	await _button(brush_start, true)
	for index in range(1, 25):
		await _move(desk_transform * Vector2(1100 + index * 6, 980 + sin(index * 0.45) * 12), true)
	await _button(desk_transform * Vector2(1244, 980 + sin(24 * 0.45) * 12), false)
	check(proof.strokes.size() == 2 and proof.settlement().corrected == 1 and proof.settlement().wrong == 0, "Textured blank-paper strokes preserve the correction reward and cause no penalty")
	await _move(desk_transform * Vector2(1470, 570))
	await create_timer(0.25).timeout
	await _capture("brush")
	var original_marks := proof.to_data()
	var anchored: Dictionary = proof.strokes[0].segments[0]
	var before := surface._segment_point(anchored, anchored.points[0])
	var corrected_page := pager.capture_character()
	pager.go_to_character(0 if corrected_page > 0 else proof.display_text.length() - 1)
	await process_frame
	await process_frame
	check(not surface._stroke_visible(proof.strokes[0]) and proof.to_data() == original_marks, "The complete mark, including blank-paper portions, stays on its original sheet")
	pager.go_to_character(corrected_page)
	await process_frame
	await process_frame
	check(surface._stroke_visible(proof.strokes[0]) and surface._segment_point(anchored, anchored.points[0]).is_equal_approx(before), "Returning to the marked sheet restores its original position")
	var reading_page := pager.page_index
	var page_button := pager.previous if reading_page > 0 else pager.next
	var page_point := page_button.get_global_transform_with_canvas() * (page_button.size * 0.5)
	await _move(page_point)
	await _button(page_point, true)
	await _button(page_point, false)
	await create_timer(pager.turn_seconds + 0.1).timeout
	check(pencil.held and pager.page_index != reading_page and proof.to_data() == original_marks, "Native page buttons work with the pencil held and do not draw or alter corrections")
	pager.go_to_character(corrected_page)
	await process_frame
	await process_frame
	await _move(work.get_node("Canvas/World").get_global_transform_with_canvas() * Vector2(900, 980))
	await create_timer(0.25).timeout
	await _capture("marked")
	await _button(point, true, MOUSE_BUTTON_RIGHT)
	await _button(point, false, MOUSE_BUTTON_RIGHT)
	check(not pencil.held and pencil.position == work.pencil_rest_position and work.stamp.enabled, "Right click returns the pencil and re-enables the stamp")
	check(pencil_model.rotation_degrees.is_equal_approx(pencil.rest_tilt_degrees), "Returning the pencil restores its angled resting pose")
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
	check(session.day == 4 and session.current_article().id == unchanged_id and session.proofreading.to_data() == unchanged and surface.state == session.proofreading and pager.source_text == unchanged.display_text, "The next shift resumes the same unfinished article and marks")
	work._open_choices(false)
	work._select_headline(0)
	await _wait_choices(work)
	pager.go_to_character(int(pager.source_text.length() * 0.45))
	var reading_character := pager.capture_character()
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
	check(pager.capture_character() == reading_character and source.text == display_before and session.proofreading.to_data() == marks_before, "Live publication result preserves the reading sheet, display text and marks")
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
