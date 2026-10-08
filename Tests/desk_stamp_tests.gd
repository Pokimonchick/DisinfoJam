extends SceneTree

var checks := 0
var failures := 0
var _test_path := "user://stamp_test_%d/campaign.json" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await process_frame

func _capture(name: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("disinfo-stamp-" + name + ".png"))

func _ink_progress(seal: Control) -> float:
	return float((seal.material as ShaderMaterial).get_shader_parameter("absorption_progress"))

func _source_progress(source: Control) -> float:
	return float((source.material as ShaderMaterial).get_shader_parameter("absorption_progress"))

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var state := root.get_node("GameState")
	state.save_store = SaveRepository.new(_test_path)
	state.session = NewsroomSession.new()
	state.session.balance = NewsroomBalance.new()
	state.session.balance.starting_health = 90.0
	state.session.balance.starting_reputation = 80.0
	state.session.balance.starting_loyalty = 80.0
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._new_run(true)
	await create_timer(0.4).timeout
	var work = game.work
	var stamp: DeskStamp = work.stamp
	var area: StampArea = work.stamp_area
	check(work.get_node_or_null("%Publish") == null and not stamp.enabled, "The stamp replaces the button and waits for a headline")
	check(not stamp.begin_drag(stamp.contact_position()), "The stamp cannot be picked up before selecting a headline")
	work._open_choices(false)
	work._select_headline(0)
	await create_timer(0.4).timeout
	check(stamp.enabled and not work.choices.visible, "Selecting a draft makes the stamp available")
	var default_imprint_size := area.imprint_size
	area.imprint_size = Vector2(112, 112)
	area.imprint_angle_degrees = -8.0
	check(area.preview.size == area.imprint_size and area.imprint.size == area.imprint_size and is_equal_approx(area.preview.rotation, deg_to_rad(-8)), "Inspector changes keep seal geometry and drop bounds in sync")
	area.imprint_size = default_imprint_size
	area.imprint_angle_degrees = -2.0
	var source: RichTextLabel = work.get_node("%SourceText")
	check(area.can_stamp(source.get_global_transform_with_canvas() * (source.size * 0.5)), "Printing directly over the source text is allowed")
	check(area.can_stamp(source.get_global_transform_with_canvas() * Vector2(40, 175)), "The left side of the source text accepts a full-size seal")
	check(area.can_stamp(source.get_global_transform_with_canvas() * Vector2(40, source.size.y + 35)), "The blank paper below the left side of the source accepts a seal")
	var headline: Control = work.get_node("%HeadlineField")
	check(not area.can_stamp(headline.get_global_transform_with_canvas() * (headline.size * 0.5)), "The headline field is outside the stamp area")
	var cup_overlap := area.get_global_transform_with_canvas() * Vector2(area.size.x - area.imprint_size.x * 0.5 - 18, 180)
	var exclusions: Array[NodePath] = area.excluded_controls.duplicate()
	area.excluded_controls = []
	var inside_body := area.can_stamp(cup_overlap)
	area.excluded_controls = exclusions
	check(inside_body and not area.can_stamp(cup_overlap), "A seal touching the coffee cup is rejected even when it fits inside the article body")
	await _capture("desk")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image: Image = stamp.get_node("Render").get_texture().get_image()
		var visible_pixels := 0
		var sampled_pixels := 0
		var last_visible_row := 0
		for y in range(0, image.get_height(), 8):
			for x in range(0, image.get_width(), 8):
				sampled_pixels += 1
				if image.get_pixel(x, y).a > 0.1:
					visible_pixels += 1
					last_visible_row = maxi(last_visible_row, y)
		check(visible_pixels > sampled_pixels * 0.01 and visible_pixels < sampled_pixels * 0.85, "The 3D model renders with a transparent background")
		var bottom := stamp.get_global_transform_with_canvas() * (Vector2(144, last_visible_row + 8) * stamp.size / Vector2(image.get_size()))
		var cup: TextureButton = work.get_node("%Coffee/Cup")
		var cup_image := cup.texture_normal.get_image()
		var first_cup_row := cup_image.get_height()
		# The cup texture has transparent padding above its actual silhouette.
		for y in range(0, cup_image.get_height(), 4):
			for x in range(0, cup_image.get_width(), 4):
				if cup_image.get_pixel(x, y).a > 0.1:
					first_cup_row = y
					break
			if first_cup_row < cup_image.get_height():
				break
		var cup_top := cup.get_global_transform_with_canvas() * Vector2(0, first_cup_row * cup.size.y / cup_image.get_height())
		check(bottom.y + 8 < cup_top.y, "The resting stamp and its shadow leave a gap above the visible coffee")
	var rest := stamp.position
	var rest_view: Transform3D = stamp.get_node("Render/Camera").transform
	var grip := stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	await _button(grip, true)
	check(stamp.dragging and game.session.total_published == 0, "Pressing the visible handle picks it up without publishing")
	await process_frame
	check(not work.get_node("Canvas").motion_enabled, "Dragging freezes the desk parallax")
	await _button(grip, false)
	check(stamp.dragging and game.session.total_published == 0, "Releasing the pickup click keeps the stamp attached to the cursor")
	await _button(grip, true)
	await _button(grip, false)
	await create_timer(0.4).timeout
	check(not stamp.busy and stamp.position.is_equal_approx(rest) and game.session.total_published == 0, "Clicking beside the paper returns the stamp without publishing")

	# Both transforms include the desk's scaling, rotation and parallax.
	var world: Control = work.get_node("Canvas/World")
	world.rotation = 0.018
	world.position = Vector2(21, -9)
	var centre := area.get_global_transform_with_canvas() * (area.size * 0.5)
	check(area.can_stamp(centre) and not area.can_stamp(area.get_global_transform_with_canvas() * Vector2(6, 6)), "The entire rotated seal must fit inside the free paper field")
	grip = stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	await _button(grip, true)
	await _button(grip, false)
	await _move(grip + centre - stamp.contact_position())
	check(stamp.dragging and area.preview.visible, "Moving without holding a button shows the impression in transformed coordinates")
	check(stamp.contact_position().distance_to(centre) < 0.1 and not stamp.get_node("Render/Camera").transform.is_equal_approx(rest_view), "Perspective changes during movement without shifting the intended drop point")
	await _capture("drag")
	game.transitioning = false
	game._toggle_pause()
	check(game.paused and not stamp.dragging and stamp.position.is_equal_approx(rest) and not area.preview.visible, "Pause cancels the held stamp and clears its preview")
	await _button(centre, false)
	game._toggle_pause()
	check(game.session.total_published == 0, "Releasing while paused cannot publish on resume")
	world.rotation = 0
	work._open_choices(false)
	check(not stamp.enabled and not stamp.begin_drag(stamp.contact_position()), "The headline chooser blocks stamp interaction")
	work._hide_choices(false)
	var published_article: NewsArticle = game.session.current_article()
	published_article.source_text = "Строка длинного источника для чтения перед публикацией.\n".repeat(90)
	work._display_source(published_article)
	await process_frame
	await process_frame
	var source_scroll: VScrollBar = source.get_v_scroll_bar()
	source_scroll.value = source_scroll.max_value * 0.55
	var reading_scroll := source_scroll.value
	check(reading_scroll > 0.0, "A long article can be scrolled before stamping")
	centre = source.get_global_transform_with_canvas() * Vector2(40, 175)
	grip = stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	await _button(grip, true)
	await _button(grip, false)
	await _move(grip + centre - stamp.contact_position())
	await _button(centre, true)
	await _button(centre, false)
	check(stamp.busy and game.session.total_published == 0, "The second click starts the strike before applying consequences")
	await create_timer(0.25).timeout
	check(game.session.total_published == 1 and area.printed and area.imprint.visible and not work.popup.active, "Contact applies the publication once while the result note stays hidden")
	check(is_equal_approx(source_scroll.value, reading_scroll), "Stamping a scrolled article does not move its reading position")
	var ink_centre := area.get_global_transform_with_canvas() * (area.imprint.position + area.imprint_size * 0.5)
	check(ink_centre.distance_to(centre) < 0.1, "The new ink stays at the actual contact point over the article text")
	var money: int = game.session.money
	check(not stamp.begin_drag(centre), "The publication result prevents a second stamp")
	work._publish_selected()
	check(game.session.money == money and game.session.total_published == 1, "Repeated publication cannot award twice")
	await stamp.returned_to_rest
	check(stamp.position.is_equal_approx(rest) and not work.popup.active, "Returning the stamp does not open the result note immediately")
	var health: float = game.session.health
	game.session.tick_work(30.0)
	check(game.session.health == health, "Waiting for the result note does not drain stamina")
	await _capture("after-stamp")
	await create_timer(work.result_delay_seconds * 0.5).timeout
	check(not work.popup.active, "The result stays hidden during the configured delay after returning")
	if not work.popup.active:
		await work.view_changed
	await process_frame
	check(work.popup.active and work.popup.scale.x < 0.98, "The result then begins approaching instead of jumping to full size")
	var opening_scale: float = work.popup.scale.x
	await create_timer(0.2).timeout
	check(work.popup.scale.x > opening_scale and work.popup.scale.x < 0.98, "The note is still approaching smoothly after the first part of its entrance")
	await create_timer(0.55).timeout
	check(work.popup.scale.is_equal_approx(Vector2.ONE), "The slower entrance finishes at the correct size")
	check(is_equal_approx(source_scroll.value, reading_scroll), "Opening publication feedback keeps the article at its original scroll position")
	await _capture("result")
	work.restore_presentation(work.capture_presentation())
	check(area.printed and area.imprint.visible and work.popup.active and game.session.total_published == 1, "Restoring a publication result restores the seal without replaying consequences")
	await _button(Vector2(1240, 680), true)
	await _button(Vector2(1240, 680), false)
	check(work.popup.active and not work.popup.is_opening() and work.popup.scale.is_equal_approx(Vector2.ONE) and game.session.awaiting_acknowledgement,
		"A click during result entrance only completes opening and keeps feedback")
	var old_ink_position := area.imprint.position
	work.popup.primary_pressed.emit()
	await create_timer(work.popup.closing_seconds * 0.4).timeout
	check(work.popup.visible and work.popup.modulate.a > 0.0 and work.popup.modulate.a < 1.0 and game.session.awaiting_acknowledgement, "The result note fades while the current publication remains unacknowledged")
	await _capture("result-closing")
	if game.session.awaiting_acknowledgement:
		await game.session.article_changed
	await process_frame
	check(not work.popup.visible and source.text == published_article.source_text and source.self_modulate.a > 0.0, "Closing feedback retains the old source for its fade-out")
	work._open_choices(false)
	check(not work.choices_open and not stamp.enabled, "A fading old article cannot accept choices or another publication")
	await create_timer(area.absorption_seconds * 0.35).timeout
	check(not area.printed and area.imprint.visible and work.selected_index == -1 and stamp.position.is_equal_approx(rest), "The next source unlocks the draft while the old ink remains visible during absorption")
	var absorbing_progress := _ink_progress(area.imprint)
	check(absorbing_progress > 0.0 and absorbing_progress < 1.0 and area.imprint.position.is_equal_approx(old_ink_position), "The old ink absorbs gradually at its original position")
	check(source.text == published_article.source_text and is_equal_approx(_source_progress(source), absorbing_progress) and work.get_node("%SourceTitle").material == source.material, "Old title and source use an organic mask on the exact same clock as the ink")
	check(area.preview.material != area.imprint.material and is_zero_approx(_ink_progress(area.preview)), "The preview has an independent material and never inherits absorption")
	await _capture("ink-absorbing")
	game._toggle_pause()
	absorbing_progress = _ink_progress(area.imprint)
	await create_timer(area.absorption_seconds + 0.1).timeout
	check(game.paused and area.imprint.visible and is_equal_approx(_ink_progress(area.imprint), absorbing_progress) and is_equal_approx(_source_progress(source), absorbing_progress), "Pause freezes the old source and ink together")
	game._toggle_pause()
	await create_timer(area.absorption_seconds * 0.2).timeout
	check(_ink_progress(area.imprint) > absorbing_progress and area.imprint.visible, "Unpausing resumes the remaining ink absorption")
	await create_timer(area.absorption_seconds).timeout
	check(not area.imprint.visible and is_equal_approx(_ink_progress(area.imprint), 1.0), "Absorption finishes with no old ink left on the next article")
	check(source.text == game.session.current_article().source_text and source_scroll.value == 0.0 and not work.get_node("%HeadlineField").disabled, "The next source replaces old text at the top only after absorption, then enables choices")
	await create_timer(work.source_reveal_seconds).timeout
	check(is_equal_approx(float((source.material as ShaderMaterial).get_shader_parameter("reveal_progress")), 1.0), "The next source finishes fully readable")
	await _capture("next-article")

	# Pausing during the committed stroke must retain its pending feedback.
	game.session.reputation = 100.0
	game.session.loyalty = 100.0
	work._open_choices(false)
	work._select_headline(0)
	await create_timer(0.4).timeout
	grip = stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	centre = area.get_global_transform_with_canvas() * (area.size * 0.5)
	await _button(grip, true)
	await _button(grip, false)
	await _move(grip + centre - stamp.contact_position())
	await _button(centre, true)
	await _button(centre, false)
	await create_timer(0.25).timeout
	game._toggle_pause()
	check(game.session.total_published == 2 and stamp.position.is_equal_approx(rest), "Pause after contact returns the stamp without undoing the publication")
	await create_timer(work.result_delay_seconds + 0.15).timeout
	check(not work.popup.active and game.session.total_published == 2, "Paused time cannot consume the pending result delay or replay a publication")
	game._toggle_pause()
	await create_timer(work.result_delay_seconds * 0.5).timeout
	check(not work.popup.active, "The delay resumes after unpausing instead of opening immediately")
	if not work.popup.active:
		await work.view_changed
	await process_frame
	check(work.popup.active and game.session.total_published == 2, "The retained result opens once after its remaining delay")
	work.popup.primary_pressed.emit()
	if work.popup.active:
		work.popup.primary_pressed.emit()
	if game.session.awaiting_acknowledgement:
		await game.session.article_changed
	await create_timer(area.absorption_seconds * 0.2).timeout
	check(area.imprint.visible and _ink_progress(area.imprint) > 0.0, "The next acknowledged result starts ink absorption again")
	work.restore_presentation(work.capture_presentation())
	check(not area.printed and not area.imprint.visible and is_zero_approx(_ink_progress(area.imprint)), "Restoring an unprinted draft clears transient ink immediately")
	check(source.text == game.session.current_article().source_text and is_equal_approx(source.self_modulate.a, 1.0), "Restoring during a handover cancels the old source and displays the current article")
	await create_timer(area.absorption_seconds + 0.1).timeout
	check(not area.imprint.visible, "An interrupted absorption cannot revive old ink after restoring a draft")

	# Cancellation before contact must never charge money or stamina.
	work._open_choices(false)
	work._select_headline(1)
	await create_timer(0.4).timeout
	grip = stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	centre = area.get_global_transform_with_canvas() * (area.size * 0.5)
	await _button(grip, true)
	await _button(grip, false)
	await _move(grip + centre - stamp.contact_position())
	await _button(centre, true)
	await _button(centre, false)
	game._toggle_pause()
	await create_timer(0.25).timeout
	check(game.session.total_published == 2 and not area.printed, "Pausing before contact cancels the strike without another publication")
	game._toggle_pause()

	# A replacement imprint must not be hidden by the old tween's callback.
	area.restore_result()
	area.reset(true)
	await create_timer(area.absorption_seconds * 0.2).timeout
	area.restore_result()
	check(area.printed and area.imprint.visible and is_zero_approx(_ink_progress(area.imprint)), "A restored result cancels absorption and shows fresh ink")
	await create_timer(area.absorption_seconds + 0.1).timeout
	check(area.printed and area.imprint.visible and is_zero_approx(_ink_progress(area.imprint)), "The previous absorption cannot later hide a restored result")
	area.reset(true)
	await create_timer(area.absorption_seconds * 0.2).timeout
	area.show_preview(centre)
	check(area.preview.visible and is_zero_approx(_ink_progress(area.preview)), "A new preview stays intact while the previous ink is absorbing")
	check(area.commit(centre) and area.printed and is_zero_approx(_ink_progress(area.imprint)), "A new stamp replaces absorbing ink at full strength")
	await create_timer(area.absorption_seconds + 0.1).timeout
	check(area.imprint.visible and is_zero_approx(_ink_progress(area.imprint)) and game.session.total_published == 2, "The old absorption cannot hide the replacement ink or replay publication rules")
	area.reset(true)
	await create_timer(area.absorption_seconds * 0.2).timeout
	game._new_run(false)
	check(game.session.phase == NewsroomSession.Phase.IDLE and not area.printed and not area.imprint.visible, "A new run clears absorbing ink before its first shift starts")
	await create_timer(area.absorption_seconds + 0.1).timeout
	check(not area.imprint.visible and is_zero_approx(_ink_progress(area.imprint)), "A new run cancels the old ink tween completely")
	game._run_active = false
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_path.get_base_dir()))
	print("DESK STAMP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
