extends SceneTree

const Ledger = preload("res://Scripts/finance_ledger.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var ledger = Ledger.new()
	ledger.record(1, "publication", 20, "Публикация", 0, "Заголовок")
	ledger.record(1, "rent", -10, "Аренда")
	ledger.record(2, "publication", 30, "Публикация", 1)
	ledger.record(2, "coffee", -5, "Кофе")
	check(ledger.summary(1).balance == 10, "Day filters ledger")
	check(ledger.summary().income == 50 and ledger.summary().expenses == 15, "Signed totals")
	check(ledger.summary().best_types == [1], "Best publication category")
	var saved: Dictionary = ledger.to_data()
	check(Ledger.validate_data(saved), "Valid ledger snapshot")
	check(Ledger.validate_data(JSON.parse_string(JSON.stringify(saved))), "JSON integer representation accepted")
	check(Ledger.validate_data({}), "Empty legacy fallback accepted")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.entries[1].id = invalid.entries[0].id
	check(not Ledger.validate_data(invalid), "Duplicate transaction ID rejected")
	invalid = saved.duplicate(true)
	invalid.entries[0].amount = 1.5
	check(not Ledger.validate_data(invalid), "Fractional amount rejected")
	invalid.entries[0].amount = INF
	check(not Ledger.validate_data(invalid), "Nonfinite amount rejected")
	invalid = saved.duplicate(true)
	invalid.entries[0].kind = "future_kind"
	check(Ledger.validate_data(invalid), "Unknown transaction kind accepted")
	invalid.entries[0].editorial_type = 3
	check(not Ledger.validate_data(invalid), "Unknown editorial type rejected")
	ledger.restore(saved)
	ledger.restore(saved)
	check(ledger.entries.size() == 4, "Repeated restore replaces entries")
	ledger.record(2, "snack", -2, "Перекус")
	check(ledger.entries.back().id == 5, "ID advances after restore")
	ledger.restore({}, [{"day": 1, "money": 7, "combo_type": 2, "headline": "Архив"}], 1)
	check(ledger.history_incomplete and ledger.summary().income == 7, "Legacy journal preserves known money")
	check(ledger.summary().expenses == 0, "Legacy import invents no purchases")
	var migrated: Dictionary = ledger.to_data()
	ledger.restore(migrated, [{"money": 7}], 1)
	check(ledger.entries.size() == 1, "Migrated save does not import journal twice")
	var notebook = load("res://Scenes/finance_notebook.tscn").instantiate()
	notebook.open(ledger, 1)
	root.add_child(notebook)
	await process_frame
	check(notebook._text.get_parsed_text().contains("Архив"), "Notebook renders migrated transactions")
	notebook._select(true)
	check(notebook._text.get_parsed_text().contains("Все дни"), "Notebook switches time range")
	notebook.queue_free()
	print("FINANCE LEDGER TESTS: %d failures" % failures)
	quit(0 if failures == 0 else 1)
