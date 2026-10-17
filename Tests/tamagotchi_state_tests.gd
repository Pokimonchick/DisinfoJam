extends SceneTree

const ITEMS = preload("res://Data/home_items.gd")
const EXPECTED := {
	"matcha": [12, 15, "home_drink", "drink"],
	"hot_chocolate": [12, 15, "home_drink", "drink"],
	"coffee_latte": [12, 15, "home_drink", "drink"],
	"ramyun": [24, 30, "home_food", "food"],
	"shin_ramyun": [24, 30, "home_food", "food"],
	"fish_food": [5, 0, "pet_food", "pet"],
}

var checks := 0
var failures: Array[String] = []
var test_path := "user://tamagotchi_state_tests_%d/campaign.json" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _fresh() -> NewsroomSession:
	var model := NewsroomSession.new()
	model.balance = NewsroomBalance.new()
	model.reset(42)
	model.player_id = "tamagotchi-test-player"
	model.run_id = "tamagotchi-test-run"
	return model

func _home() -> NewsroomSession:
	var model := _fresh()
	model.start_shift()
	model.finish_shift()
	model.money = 1000
	model.health = 40.0
	return model

func _run() -> void:
	_test_purchase_and_use()
	_test_rejected_actions()
	_test_inventory_boundaries()
	_test_stamina_costs()
	_test_rent_and_sleep_model()
	_test_save_validation()
	if not "--model-only" in OS.get_cmdline_user_args():
		await _test_controller_save_and_sleep()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path.get_base_dir()))
	print("TAMAGOTCHI STATE TESTS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_purchase_and_use() -> void:
	_check(ITEMS.ROWS.size() == EXPECTED.size(), "The shop exposes the six current products")
	for id in EXPECTED:
		var expected: Array = EXPECTED[id]
		var model := _home()
		var signals := {"changed": 0, "save": 0, "transactions": 0}
		model.changed.connect(func(): signals.changed += 1)
		model.save_requested.connect(func(): signals.save += 1)
		model.transaction_recorded.connect(func(_entry: Dictionary): signals.transactions += 1)
		var ledger_before := model.finances.entries.size()
		var result := model.buy_home_item(id)
		_check(result.ok and model.inventory == {id: 1}, "%s purchase adds exactly one item" % id)
		_check(model.money == 1000 - expected[0] and model.health == 40.0, "%s purchase charges its price without restoring stamina" % id)
		_check(model.finances.entries.size() == ledger_before + 1 and model.finances.entries.back().kind == expected[2] and model.finances.entries.back().amount == -expected[0], "%s purchase records one correctly categorized expense" % id)
		_check(signals == {"changed": 1, "save": 1, "transactions": 1}, "%s purchase emits one state/save/transaction notification" % id)
		var money_before := model.money
		result = model.use_home_item(id)
		_check(result.ok and result.category == expected[3] and result.restore == float(expected[1]), "%s consumption reports its actual effect" % id)
		_check(model.health == 40.0 + expected[1] and model.inventory.is_empty(), "%s consumption restores stamina and removes an exhausted stack" % id)
		_check(model.money == money_before and model.finances.entries.size() == ledger_before + 1, "%s consumption does not charge twice" % id)
		_check(signals == {"changed": 2, "save": 2, "transactions": 1}, "%s consumption requests a save without an extra financial entry" % id)
		model.inventory[id] = 2
		model.health = 95.0
		result = model.use_home_item(id)
		_check(result.ok and result.restore == (0.0 if id == "fish_food" else 5.0) and model.health == (95.0 if id == "fish_food" else 100.0) and model.inventory[id] == 1, "%s use caps recovery and consumes one from a stack" % id)
		model.money = expected[0]
		_check(model.buy_home_item(id).ok and model.money == 0 and model.phase == NewsroomSession.Phase.HOME, "%s can be purchased with exactly its price remaining" % id)
		model.health = 100.0
		model.money = expected[0]
		_check(model.buy_home_item(id).ok and model.inventory[id] == 3, "%s can be stocked for later at full stamina" % id)
	# Carry-over work coffee is independent of drinks in the backpack.
	var model := _home()
	model.coffee_ready = false
	model.coffee_used_today = true
	model.inventory = {"coffee_latte": 1}
	_check(model.use_home_item("coffee_latte").ok and not model.coffee_ready and model.coffee_used_today, "Backpack latte does not replenish or reset the work coffee cup")
	model.inventory = {"fish_food": 1}
	model.health = 100.0
	var before := [model.health, model.reputation, model.loyalty, model.qualification, model.money]
	_check(model.use_home_item("fish_food").ok and model.inventory.is_empty() and before == [model.health, model.reputation, model.loyalty, model.qualification, model.money], "Fish food works at full stamina without changing heroine stats or money")

func _expect_rejection(model: NewsroomSession, id: String, buy: bool, reason: String, label: String) -> void:
	var before := NewsroomSaveData.capture(model)
	var signals := {"changed": 0, "save": 0, "transactions": 0}
	var on_change := func(): signals.changed += 1
	var on_save := func(): signals.save += 1
	var on_transaction := func(_entry: Dictionary): signals.transactions += 1
	model.changed.connect(on_change)
	model.save_requested.connect(on_save)
	model.transaction_recorded.connect(on_transaction)
	var result := model.buy_home_item(id) if buy else model.use_home_item(id)
	_check(not result.ok and result.reason == reason, label + " reports the reason")
	_check(NewsroomSaveData.capture(model) == before and signals == {"changed": 0, "save": 0, "transactions": 0}, label + " leaves all state and notifications untouched")
	model.changed.disconnect(on_change)
	model.save_requested.disconnect(on_save)
	model.transaction_recorded.disconnect(on_transaction)

func _test_rejected_actions() -> void:
	for id in EXPECTED:
		var model := _home()
		model.money = EXPECTED[id][0] - 1
		_check(model.buy_home_item(id).ok and model.money == -1 and model.inventory[id] == 1, "%s can be bought without sufficient cash" % id)
		model.money = -10
		_check(model.buy_home_item(id).ok and model.money == -10 - EXPECTED[id][0] and model.inventory[id] == 2, "%s can be bought while already in debt" % id)
		model.inventory.clear()
		_expect_rejection(model, id, false, "not_owned", "%s empty backpack" % id)
		if id != "fish_food":
			model.inventory[id] = 2
			model.health = 100.0
			_expect_rejection(model, id, false, "health_full", "%s full stamina keeps stock" % id)
	var model := _home()
	_expect_rejection(model, "missing-product", true, "unknown_item", "Unknown purchase")
	_expect_rejection(model, "missing-product", false, "unknown_item", "Unknown consumption")
	for phase in [NewsroomSession.Phase.IDLE, NewsroomSession.Phase.WORK, NewsroomSession.Phase.ENDED]:
		model = _home()
		model.inventory = {"matcha": 1, "fish_food": 1}
		model.phase = phase
		for id in ["matcha", "fish_food"]:
			_expect_rejection(model, id, true, "wrong_phase", "%s purchase in phase %d" % [id, phase])
			_expect_rejection(model, id, false, "wrong_phase", "%s consumption in phase %d" % [id, phase])

func _test_inventory_boundaries() -> void:
	for id in EXPECTED:
		var model := _home()
		model.inventory[id] = 98
		_check(model.buy_home_item(id).ok and model.inventory[id] == 99, "%s stack reaches 99" % id)
		_expect_rejection(model, id, true, "inventory_full", "%s stack rejects item 100" % id)
		_check(model.use_home_item(id).ok and model.inventory[id] == 98 and model.buy_home_item(id).ok and model.inventory[id] == 99, "%s consuming frees space for a subsequent purchase" % id)

func _test_stamina_costs() -> void:
	var model := _fresh()
	model.start_shift()
	_check(is_equal_approx(model.publication_stamina_cost(), 4.0 / 1.5), "Publication stamina cost is reduced by a factor of 1.5")
	model.reputation = model.balance.reader_support.threshold
	_check(is_equal_approx(model.publication_stamina_cost(), 2.0 / 1.5), "Reader support preserves the same factor of reduction")
	model.reputation = 65.0
	model.health = 80.0
	model.tick_work(45.0)
	_check(is_equal_approx(model.health, 78.0), "Passive work drain is reduced from three to two points per 45 seconds")
	model = _home()
	model.money = model.balance.debt_limit + 1
	_check(model.buy_home_item("matcha").ok and model.phase == NewsroomSession.Phase.ENDED and model.ending == NewsroomSession.Ending.DEBT, "Credit purchases preserve the existing debt defeat limit")

func _test_rent_and_sleep_model() -> void:
	var model := _home()
	model.money = 24
	_check(model.buy_home_item("ramyun").ok and model.money == 0, "Purchase may spend all funds before the next rent")
	model.start_shift()
	var ledger_before := model.finances.entries.size()
	model.finish_shift()
	_check(model.money == -45 and model.phase == NewsroomSession.Phase.HOME and model.inventory == {"ramyun": 1}, "Next shift charges normal rent and retains carried supplies")
	model.finish_shift()
	_check(model.money == -45 and model.finances.entries.size() == ledger_before + 1, "Repeated finish cannot charge rent twice")
	model.start_shift()
	model.money = -55
	model.finish_shift()
	_check(model.money == -100 and model.ending == NewsroomSession.Ending.DEBT and model.phase == NewsroomSession.Phase.ENDED, "Normal rent still triggers debt defeat exactly at minus 100")
	model = _home()
	model.health = 25.0
	model.start_shift()
	_check(model.health == 35.0 and model.day == 2, "Sleep restores ten stamina at the next shift boundary")
	model.start_shift()
	_check(model.health == 35.0 and model.day == 2, "Repeated shift start cannot apply sleep twice")
	var restored := _fresh()
	_check(NewsroomSaveData.restore(restored, NewsroomSaveData.capture(model)) and restored.health == 35.0, "Reloading after sleep retains recovery without duplicating it")
	restored.start_shift()
	_check(restored.health == 35.0 and restored.day == 2, "Repeated start after reloading cannot duplicate recovery")
	model = _home()
	model.health = 95.0
	model.start_shift()
	_check(model.health == 100.0, "Sleep recovery caps at maximum stamina")

func _test_save_validation() -> void:
	var model := _home()
	model.inventory = {"matcha": 1, "hot_chocolate": 2, "coffee_latte": 3, "ramyun": 4, "shin_ramyun": 5, "fish_food": 99}
	var saved := NewsroomSaveData.capture(model)
	model.inventory.matcha = 10
	_check(saved.run.inventory.matcha == 1, "Captured inventory does not alias the live backpack")
	var json_save: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var restored := _fresh()
	var notifications := {"transactions": 0, "saves": 0}
	restored.transaction_recorded.connect(func(_entry: Dictionary): notifications.transactions += 1)
	restored.save_requested.connect(func(): notifications.saves += 1)
	_check(NewsroomSaveData.restore(restored, json_save) and restored.inventory == saved.run.inventory, "All six supplies and quantities survive JSON save and restore")
	_check(restored.inventory.fish_food is int and notifications == {"transactions": 0, "saves": 0}, "JSON quantities become integers without replaying expenses or autosaves")
	var legacy := saved.duplicate(true)
	legacy.run.erase("inventory")
	_check(NewsroomSaveData.restore(restored, legacy) and restored.inventory.is_empty(), "Older saves without inventory clear previously loaded supplies")
	restored.inventory = {"ramyun": 2}
	var empty := saved.duplicate(true)
	empty.run.inventory = {}
	_check(NewsroomSaveData.restore(restored, empty) and restored.inventory.is_empty(), "Explicit empty inventory replaces existing supplies")
	for invalid in [null, [], "bad", {"unknown": 1}, {1: 1}, {"matcha": 0}, {"matcha": -1}, {"matcha": 100}, {"matcha": 1.5}, {"matcha": INF}, {"matcha": NAN}, {"matcha": true}, {"matcha": "1"}]:
		var bad := saved.duplicate(true)
		bad.run.inventory = invalid
		var before := NewsroomSaveData.capture(restored)
		_check(not NewsroomSaveData.validate(bad) and not NewsroomSaveData.restore(restored, bad), "Malformed inventory is rejected: %s" % str(invalid))
		_check(NewsroomSaveData.capture(restored) == before, "Malformed inventory never partially mutates the active session")

func _test_controller_save_and_sleep() -> void:
	var state := root.get_node("GameState")
	var previous_store = state.save_store
	var previous_session = state.session
	state.save_store = SaveRepository.new(test_path)
	state.session = _home()
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._work_tutorial_done = true
	game._home_tutorial_done = true
	game._pencil_tutorial_done = true
	game._seen_stories.assign(["day_2"])
	game._run_active = true
	game._show_view(game.View.HOME)
	game.home.open_evening()
	game.session.inventory = {"matcha": 1, "fish_food": 2}
	_check(game._save_progress(), "Controller writes backpack to an isolated test slot")
	_check(state.save_store.exists() and not state.save_store.load_document().is_empty(), "Controller writes a readable document: %s" % state.save_store.error_message)
	var saved := NewsroomSaveData.capture(game.session)
	for part_size in [150, 300]:
		var with_dialogue := saved.duplicate(true)
		with_dialogue.presentation = {"screen": "home", "story": {"id": "", "page": 0, "part_size": part_size}}
		var decoded: Dictionary = JSON.parse_string(JSON.stringify(with_dialogue))
		_check(decoded.presentation.story.part_size is float and game._validate_save(decoded), "Controller accepts JSON-decoded dialogue part size: %d" % part_size)
	for remaining in [0.0, 3.2, 8.0]:
		var valid := saved.duplicate(true)
		valid.presentation = {"screen": "home", "home": {"sleep_left": remaining}}
		_check(game._validate_save(valid), "Valid saved night remainder is accepted: %s" % remaining)
	for remaining in [-0.1, 8.1, INF, NAN, "3.2", true]:
		var invalid := saved.duplicate(true)
		invalid.presentation = {"screen": "home", "home": {"sleep_left": remaining}}
		_check(not game._validate_save(invalid), "Malformed saved night remainder is rejected: %s" % str(remaining))
	_check(game.session.use_home_item("matcha").ok and game.session.use_home_item("fish_food").ok and game._save_progress(), "Controller saves consumed stack deletion and decremented quantity")
	var document: Dictionary = state.save_store.load_document()
	_check(not document.is_empty() and document.sections.run.inventory == {"fish_food": 1.0}, "Recursive save merging cannot resurrect a removed drink stack: %s; error: %s" % [str(document.get("sections", {}).get("run", {}).get("inventory", {})), state.save_store.error_message])
	game.session.inventory = {"matcha": 99}
	game.session.health = 9.0
	game._continue_run()
	_check(game.session.inventory == {"fish_food": 1} and game.session.health == 55.0, "Continue restores the authoritative backpack without restoring consumed drinks")
	_check(game.session.use_home_item("fish_food").ok and game._save_progress(), "Controller saves a completely emptied backpack")
	game.session.inventory = {"fish_food": 99}
	game._continue_run()
	_check(game.session.inventory.is_empty(), "Continue preserves an empty backpack without resurrecting the last item")
	game.session.health = 25.0
	game.home._sleep()
	var seconds: float = game.home.night_seconds
	_check(game.home.capture_presentation().sleep_left == seconds and game.session.health == 25.0 and game.session.phase == NewsroomSession.Phase.HOME, "Starting the night delays recovery until its boundary")
	var before := NewsroomSaveData.capture(game.session)
	game.home._purchase("matcha")
	game.home._consume("fish_food")
	_check(not game.home._can_interact() and NewsroomSaveData.capture(game.session) == before, "Night transition blocks shop and backpack interaction")
	game.home.tick_home(1.0)
	game.home._sleep()
	_check(is_equal_approx(game.home.capture_presentation().sleep_left, seconds - 1.0), "Repeated sleep input cannot restart a night already in progress")
	game.home.tick_home(seconds - 1.1)
	_check(game.session.phase == NewsroomSession.Phase.HOME and game.session.health == 25.0, "Sleep remains at home before its final fraction of a second")
	_check(game._save_progress(), "Controller saves the remaining night transition")
	game.session.health = 9.0
	game.home.restore_presentation({"sleep_left": 0.0})
	game._continue_run()
	_check(game.session.health == 25.0 and is_equal_approx(game.home.capture_presentation().sleep_left, 0.1), "Continue resumes the night without giving recovery early")
	game.home.tick_home(0.2)
	_check(game.session.phase == NewsroomSession.Phase.WORK and game.session.health == 35.0 and game.session.day == 2, "Finishing the restored night advances once and restores ten stamina")
	game.home.tick_home(seconds)
	_check(game.session.health == 35.0 and game.session.day == 2, "Additional home ticks cannot apply sleep recovery again")
	_check(game._save_progress(), "Controller saves the state after waking")
	game.session.health = 9.0
	game._continue_run()
	_check(game.session.health == 35.0 and game.session.day == 2, "Continue after waking does not replay sleep recovery")
	game._run_active = false
	game.queue_free()
	await process_frame
	state.save_store = previous_store
	state.session = previous_session
