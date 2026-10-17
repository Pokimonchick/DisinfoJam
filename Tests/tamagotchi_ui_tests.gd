extends SceneTree
## Run with -- --captures for actual rendered UI evidence, --interactive to inspect.

var checks := 0
var failures: Array[String] = []
var game
var home
var panels
var _capture_dir := OS.get_environment("TEMP").path_join("disinfo-tamagotchi-qa")
var _save_path := "user://tamagotchi_ui_%d/campaign.json" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _settle() -> void:
	await process_frame
	await process_frame

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--captures" in OS.get_cmdline_user_args():
		return
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	_check(root.get_texture().get_image().save_png(_capture_dir.path_join(name + ".png")) == OK, "Capture " + name)

func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func _click(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	_move(point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _settle()

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _settle()

func _button(parent: Node, caption: String) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if node.text == caption:
			return node as Button
	return null

func _check_layout(panel: Control, label: String) -> void:
	var panel_rect := Rect2(panel.get_global_transform_with_canvas() * Vector2.ZERO, panel.size * home.get_node("Canvas").scale)
	_check(root.get_visible_rect().encloses(panel_rect), label + " fits the viewport")
	for node in panel.find_children("*", "Label", true, false):
		var text := node as Label
		if not text.is_visible_in_tree() or text.text.is_empty():
			continue
		_check(text.get_rect().position.x >= 0 and text.get_rect().position.y >= 0 and text.get_rect().end.x <= text.get_parent().size.x + 1 and text.get_rect().end.y <= text.get_parent().size.y + 1, label + " contains text: " + text.text)
		_check(text.get_line_count() * text.get_line_height() <= text.size.y + 2, label + " has enough text height: " + text.text)

func _check_hidden_controls() -> void:
	for path in ["%Bed", "%Meal", "%Bag", "%HeroineInfo", "%Fish"]:
		_check(not home.get_node(path).is_visible_in_tree(), "Modal hides room control " + path)
	_check(home.get_node("%Notebook").disabled, "Modal disables background ledger")

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.title = "DisinfoJam - Tamagotchi QA"
	var state := root.get_node("GameState")
	state.save_store = SaveRepository.new(_save_path)
	state.session = NewsroomSession.new()
	state.session.balance = NewsroomBalance.new()
	state.session.reset(42)
	state.session.player_id = "tamagotchi-ui-test"
	state.session.run_id = "tamagotchi-ui-test-run"
	state.session.start_shift()
	state.session.finish_shift()
	state.session.money = 1500
	state.session.health = 40.0
	game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._work_tutorial_done = true
	game._home_tutorial_done = true
	game._pencil_tutorial_done = true
	game._seen_stories.assign(["day_2", "day_3", "day_4", "day_5"])
	game._run_active = true
	game._show_view(game.View.HOME)
	home = game.home
	panels = home._panels
	home.open_evening()
	await create_timer(0.35).timeout
	await _settle()
	_check(game._save_progress(), "UI fixture writes a valid isolated save")
	if "--interactive" in OS.get_cmdline_user_args():
		game.set_process(true)
		print("TAMAGOTCHI QA INTERACTIVE: isolated save slot; close this window when finished")
		return
	await _capture("01-room")
	_check(home.get_node("%Bed").text == "SLEEP" and home.get_node("%Meal").text == "SHOP", "Supplied home buttons have English captions")
	await _test_glint()
	await _click(home.get_node("%Meal"))
	_check(panels._mode == "shop" and panels._shop.is_visible_in_tree(), "Actual Shop click opens shop")
	_check_hidden_controls()
	_check_layout(panels._shop, "Shop")
	_check(panels._cards.get_child_count() == 6, "Shop displays all six items")
	await _capture("02-shop")
	for index in range(6):
		await _click(panels._cards.get_child(index))
		_check(panels._detail.is_visible_in_tree() and panels._selected.id == preload("res://Data/home_items.gd").ROWS[index].id, "Each actual product click opens its own details")
		_check_layout(panels._detail, "Product " + panels._selected.id)
		await _capture("03-detail-%d" % index)
		var money_before: int = game.session.money
		var id: String = panels._selected.id
		var price: int = panels._selected.price
		await _click(panels._action)
		_check(game.session.money == money_before - price and game.session.inventory.get(id) == 1, "Buy button charges once and adds the selected product")
		await _click(_button(panels._detail, "Close"))
		_check(panels._shop.is_visible_in_tree(), "Close returns from details to shop")
	game.session.money = 0
	home.refresh()
	await _click(panels._cards.get_child(0))
	await _click(panels._action)
	_check(panels._warning_panel.is_visible_in_tree() and not panels._detail.visible and game.session.money == 0, "Insufficient funds open warning without a purchase")
	_check_layout(panels._warning_panel, "Funds warning")
	_check_hidden_controls()
	await _capture("04-insufficient-funds")
	await _click(_button(panels._warning_panel, "Close"))
	_check(panels._shop.visible, "Warning Close returns to shop")
	await _key(KEY_ESCAPE)
	_check(not panels.visible and home.get_node("%Meal").visible and home.get_node("%Bed").visible, "Esc closes shop and restores room controls")
	await _click(home.get_node("%Bag"))
	_check(panels._info.is_visible_in_tree(), "Speech bubble opens Info")
	_check_layout(panels._small, "Info")
	_check_hidden_controls()
	await _capture("05-info")
	await _click(panels._bag_tab)
	_check(panels._bag.is_visible_in_tree() and panels._bag.get_child_count() == 6, "Bag tab shows all six purchased stacks")
	_check_layout(panels._small, "Bag")
	await _capture("06-bag")
	await _click(panels._bag.get_child(0))
	await _click(panels._action)
	_check(game.session.health == 55.0 and not game.session.inventory.has("matcha"), "Drink consumes one drink and restores stamina")
	await _click(_button(panels._detail, "Close"))
	await _click(panels._bag.get_child(panels._bag.get_child_count() - 1))
	await _click(panels._action)
	_check(not panels.visible and not game.session.inventory.has("fish_food") and home.room._fish_seconds > 0, "Feed consumes fish food and shows aquarium feedback")
	await _capture("07-fish-feedback")
	await _click(home.get_node("%Bag"))
	panels.open_bag()
	game.session.health = 100.0
	home.refresh()
	await _settle()
	await _click(panels._bag.get_child(0))
	_check(panels._action.disabled, "Full stamina disables consuming a recovery item")
	await _capture("08-full-stamina")
	panels.hide_all()
	game.session.inventory.clear()
	home.refresh()
	panels.open_bag()
	await _settle()
	_check_layout(panels._small, "Empty bag")
	await _capture("09-empty-bag")
	for dimensions in [Vector2i(1920, 1080), Vector2i(1366, 768), Vector2i(1024, 768)]:
		root.size = dimensions
		panels.hide_all()
		await _settle()
		await _capture("10-room-%dx%d" % [dimensions.x, dimensions.y])
		panels.open_shop()
		await _settle()
		_check_layout(panels._shop, "Shop %s" % dimensions)
		await _capture("11-shop-%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	panels.hide_all()
	await _settle()
	await _key(KEY_ESCAPE)
	_check(game.paused and game.pause_panel.visible and home.room._video.paused, "Esc pauses room and video")
	await _capture("12-pause")
	await _key(KEY_ESCAPE)
	_check(not game.paused and not home.room._video.paused, "Esc resumes room video")
	await _click(home.get_node("%Bed"))
	_check(home._sleep_left > 0.0 and home.room.sleeping, "Sleep button starts night")
	await _capture("13-night")
	await _key(KEY_ESCAPE)
	var seconds: float = home._sleep_left
	game._process(0.5)
	_check(is_equal_approx(home._sleep_left, seconds), "Pause freezes night countdown")
	await _key(KEY_ESCAPE)
	home.tick_home(seconds + 0.1)
	_check(game.session.day == 2 and game.session.phase == NewsroomSession.Phase.WORK, "Night finishes into the next shift")
	game._run_active = false
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path.get_base_dir()))
	print("TAMAGOTCHI UI TESTS: %d checks, %d failures; captures: %s" % [checks, failures.size(), _capture_dir])
	quit(0 if failures.is_empty() else 1)

func _test_glint() -> void:
	var room = home.room
	room.set_process(false)
	_check(not room._glint.visible, "Window glint is absent before hover")
	_move(Vector2(10, 200))
	await _settle()
	_move(room.get_global_transform_with_canvas() * Vector2(1200, 250))
	await _settle()
	_check(room._glint.visible, "Actual window hover starts glint")
	room._process(0.5)
	_check(room._glint_frame == 12, "Glint advances through its atlas")
	await _capture("01-window-glint")
	room._process(1.6)
	_check(not room._glint.visible, "Glint ends once")
	room._process(3.0)
	_check(not room._glint.visible, "Holding cursor does not loop glint")
	_move(Vector2(10, 200))
	await _settle()
	_move(room.get_global_transform_with_canvas() * Vector2(1200, 250))
	await _settle()
	_check(room._glint.visible, "Leaving and re-entering replays glint")
	room.set_playback_paused(true)
	_check(not room.is_processing() and room._video.paused, "Pause freezes room animation and video")
	room.set_playback_paused(false)
	room._stop_glint()
	room.set_process(true)
