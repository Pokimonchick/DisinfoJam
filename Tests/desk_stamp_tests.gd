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
	area.imprint_size = Vector2(112, 112)
	area.imprint_angle_degrees = -8.0
	check(area.preview.size == area.imprint_size and area.imprint.size == area.imprint_size and is_equal_approx(area.preview.rotation, deg_to_rad(-8)), "Inspector changes keep seal geometry and drop bounds in sync")
	area.imprint_size = Vector2(160, 160)
	area.imprint_angle_degrees = -2.0
	var source: Control = work.get_node("%SourceText")
	check(area.can_stamp(source.get_global_transform_with_canvas() * (source.size * 0.5)), "Printing directly over the source text is allowed")
	var headline: Control = work.get_node("%HeadlineField")
	check(not area.can_stamp(headline.get_global_transform_with_canvas() * (headline.size * 0.5)), "The headline field is outside the stamp area")
	var cup_overlap := area.get_global_transform_with_canvas() * Vector2(area.size.x - 90, 180)
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
		for y in range(0, image.get_height(), 8):
			for x in range(0, image.get_width(), 8):
				sampled_pixels += 1
				if image.get_pixel(x, y).a > 0.1:
					visible_pixels += 1
		check(visible_pixels > sampled_pixels * 0.01 and visible_pixels < sampled_pixels * 0.85, "The 3D model renders with a transparent background")
	var rest := stamp.position
	var rest_view: Transform3D = stamp.get_node("Render/Camera").transform
	var grip := stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	await _button(grip, true)
	check(stamp.dragging and game.session.total_published == 0, "Pressing the visible handle picks it up without publishing")
	await process_frame
	check(not work.get_node("Canvas").motion_enabled, "Dragging freezes the desk parallax")
	await _button(grip, false)
	await create_timer(0.4).timeout
	check(not stamp.busy and stamp.position.is_equal_approx(rest) and game.session.total_published == 0, "Dropping beside the paper returns the stamp without publishing")

	# Both transforms include the desk's scaling, rotation and parallax.
	var world: Control = work.get_node("Canvas/World")
	world.rotation = 0.018
	world.position = Vector2(21, -9)
	var centre := area.get_global_transform_with_canvas() * (area.size * 0.5)
	check(area.can_stamp(centre) and not area.can_stamp(area.get_global_transform_with_canvas() * Vector2(6, 6)), "The entire rotated seal must fit inside the free paper field")
	grip = stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	await _button(grip, true)
	await _move(grip + centre - stamp.contact_position())
	check(stamp.dragging and area.preview.visible, "Dragging over paper shows the impression in transformed coordinates")
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
	centre = area.get_global_transform_with_canvas() * Vector2(area.size.x * 0.8, 130)
	grip = stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	await _button(grip, true)
	await _move(grip + centre - stamp.contact_position())
	await _button(centre, false)
	check(stamp.busy and game.session.total_published == 0, "Releasing on paper starts the strike before applying consequences")
	await create_timer(0.25).timeout
	check(game.session.total_published == 1 and area.printed and area.imprint.visible and work.popup.active, "Contact leaves an impression and applies the existing publication result once")
	var ink_centre := area.get_global_transform_with_canvas() * (area.imprint.position + area.imprint_size * 0.5)
	check(ink_centre.distance_to(centre) < 0.1, "The new ink stays at the actual contact point over the article text")
	var money: int = game.session.money
	check(not stamp.begin_drag(centre), "The publication result prevents a second stamp")
	work._publish_selected()
	check(game.session.money == money and game.session.total_published == 1, "Repeated publication cannot award twice")
	await create_timer(0.4).timeout
	await _capture("result")
	work.restore_presentation(work.capture_presentation())
	check(area.printed and area.imprint.visible and work.popup.active and game.session.total_published == 1, "Restoring a publication result restores the seal without replaying consequences")
	work.popup.primary_pressed.emit()
	await create_timer(0.35).timeout
	check(not area.printed and not area.imprint.visible and work.selected_index == -1 and stamp.position.is_equal_approx(rest), "The next source clears the old seal and restores the stamp")

	# Cancellation before contact must never charge money or stamina.
	work._open_choices(false)
	work._select_headline(1)
	await create_timer(0.4).timeout
	grip = stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	centre = area.get_global_transform_with_canvas() * (area.size * 0.5)
	await _button(grip, true)
	await _move(grip + centre - stamp.contact_position())
	await _button(centre, false)
	game._toggle_pause()
	await create_timer(0.25).timeout
	check(game.session.total_published == 1 and not area.printed, "Pausing before contact cancels the strike without a second publication")
	game._toggle_pause()
	game._run_active = false
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_path.get_base_dir()))
	print("DESK STAMP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
