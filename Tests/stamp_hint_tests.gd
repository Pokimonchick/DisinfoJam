extends SceneTree

var checks := 0
var failures := 0
var test_path := "user://stamp_hint_tests_%d/campaign.json" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _active(stamp: DeskStamp) -> bool:
	return bool((stamp.get_node("Image").material as ShaderMaterial).get_shader_parameter("hint_active"))

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await _test_headline_lifecycle()
	if DisplayServer.get_name() != "headless":
		await _test_cached_render_pulse()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path.get_base_dir()))
	print("STAMP HINT TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_headline_lifecycle() -> void:
	var state := root.get_node("GameState")
	state.save_store = SaveRepository.new(test_path)
	state.session = NewsroomSession.new()
	state.session.balance = NewsroomBalance.new()
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._new_run(true)
	await create_timer(0.6).timeout
	var work = game.work
	var stamp: DeskStamp = work.stamp
	var material := stamp.get_node("Image").material as ShaderMaterial
	_check(not _active(stamp) and not stamp.enabled, "No selected headline leaves the stamp hint off")
	work._open_choices(false)
	work._select_headline(0)
	await create_timer(0.4).timeout
	_check(stamp.enabled and _active(stamp), "Selecting a headline starts the stationary stamp hint")
	_check(is_equal_approx(material.get_shader_parameter("hint_strength"), 0.9) and is_equal_approx(material.get_shader_parameter("hint_speed"), 0.8), "The hint uses a bright 0.9 strength and faster 0.8 Hz pulse")
	_check(material.shader == load("res://Shaders/stamp_hint.gdshader"), "The hint shader belongs to the 2D stamp image")
	game.transitioning = false
	game._toggle_pause()
	_check(game.paused and not _active(stamp), "Game pause disables the stamp hint")
	game._toggle_pause()
	_check(not game.paused and _active(stamp), "Resuming the game restores the selected headline hint")
	var grip := stamp.get_global_transform_with_canvas() * Vector2(144, 105)
	_check(stamp.begin_drag(grip) and not _active(stamp), "Picking up the stamp stops its hint")
	stamp.finish_drag()
	_check(stamp.busy and not _active(stamp), "Returning from an invalid drop keeps the hint off while busy")
	await create_timer(stamp.return_seconds + 0.1).timeout
	_check(not stamp.busy and _active(stamp), "A returned uncommitted stamp resumes the hint")
	stamp.hide()
	_check(not _active(stamp), "A hidden stamp cannot keep its hint active")
	stamp.show()
	_check(_active(stamp), "Showing a selected stationary stamp restores its hint")
	work.show_article(false)
	_check(work.selected_index == -1 and not _active(stamp), "Clearing the draft stops the hint")
	game._run_active = false
	game.queue_free()
	await process_frame

func _test_cached_render_pulse() -> void:
	var stage := Control.new()
	stage.size = Vector2(1280, 720)
	root.add_child(stage)
	var background := ColorRect.new()
	background.color = Color("302a27")
	background.size = stage.size
	stage.add_child(background)
	var stamp: DeskStamp = load("res://Scenes/desk_stamp.tscn").instantiate()
	stamp.position = Vector2(500, 220)
	stage.add_child(stamp)
	stamp.set_enabled(true)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var rendered := stamp.get_node("Render") as SubViewport
	var cached_model_hash := hash(rendered.get_texture().get_image().get_data())
	_check(rendered.render_target_update_mode in [SubViewport.UPDATE_ONCE, SubViewport.UPDATE_DISABLED], "The resting 3D model uses a one-shot cached render")
	var frame_hashes := {}
	var darkest: Image
	var brightest: Image
	var min_brightness := INF
	var max_brightness := -INF
	for sample in range(9):
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image().get_region(Rect2i(Vector2i(stamp.position), Vector2i(stamp.size)))
		frame_hashes[hash(frame.get_data())] = true
		var brightness := 0.0
		for y in range(0, frame.get_height(), 4):
			for x in range(0, frame.get_width(), 4):
				var pixel := frame.get_pixel(x, y)
				brightness += pixel.r + pixel.g + pixel.b
		if brightness < min_brightness:
			min_brightness = brightness
			darkest = frame
		if brightness > max_brightness:
			max_brightness = brightness
			brightest = frame
	_check(frame_hashes.size() > 4 and max_brightness - min_brightness > 5.0, "Stationary stamp visibly breathes over a complete pulse")
	_check(hash(rendered.get_texture().get_image().get_data()) == cached_model_hash and rendered.render_target_update_mode in [SubViewport.UPDATE_ONCE, SubViewport.UPDATE_DISABLED], "The 2D glow animates while the 3D viewport remains unchanged and cached")
	if "--capture" in OS.get_cmdline_user_args():
		var directory := OS.get_environment("TEMP")
		_check(darkest.save_png(directory.path_join("disinfo-stamp-hint-low.png")) == OK and brightest.save_png(directory.path_join("disinfo-stamp-hint-high.png")) == OK, "Save low and high pulse frames for visual review")
	stage.queue_free()
	await process_frame
