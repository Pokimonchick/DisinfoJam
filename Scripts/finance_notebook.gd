extends Control

signal closed

const Ledger = preload("res://Scripts/finance_ledger.gd")
const NotebookTheme = preload("res://Scripts/mvp_theme.gd")
const NotebookFont = preload("res://Assets/Fonts/Neucha/Neucha.ttf")
var _ledger: Ledger
var _day := 1
var _all_days := false
var _text: RichTextLabel
var _today: Button
var _all: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = NotebookTheme.create()
	theme.default_font = NotebookFont
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.06, 0.07, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var panel := PanelContainer.new()
	var paper := NotebookTheme.box(NotebookTheme.PAPER, 8, 22)
	panel.add_theme_stylebox_override("panel", paper)
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Финансовый блокнот"
	title.add_theme_color_override("font_color", NotebookTheme.INK)
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Закрыть"
	close.pressed.connect(_close)
	header.add_child(close)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	_today = Button.new()
	_today.text = "Сегодня"
	_today.toggle_mode = true
	_today.pressed.connect(_select.bind(false))
	tabs.add_child(_today)
	_all = Button.new()
	_all.text = "Все дни"
	_all.toggle_mode = true
	_all.pressed.connect(_select.bind(true))
	tabs.add_child(_all)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("default_color", NotebookTheme.INK)
	_text.add_theme_font_size_override("normal_font_size", 20)
	column.add_child(_text)
	_refresh()
	close.grab_focus()

func open(ledger: Ledger, day: int) -> void:
	_ledger = ledger
	_day = day
	_all_days = false
	if is_node_ready():
		_refresh()

func _select(all_days: bool) -> void:
	_all_days = all_days
	_refresh()

func _refresh() -> void:
	if _text == null:
		return
	_today.button_pressed = not _all_days
	_all.button_pressed = _all_days
	if _ledger == null:
		_text.text = "Записей пока нет."
		return
	var summary := _ledger.summary(-1 if _all_days else _day)
	_text.clear()
	_text.add_text("Все дни\n" if _all_days else "День %d\n" % _day)
	if _ledger.history_incomplete:
		_text.add_text("Старое сохранение: история расходов неполная; сохранены известные публикации.\n\n")
	_text.add_text("Доходы: +%d $     Расходы: −%d $     Итог: %s $\n\n" % [summary.income, summary.expenses, _signed(summary.balance)])
	_text.add_text("РАСХОДЫ\n")
	for kind in Ledger.EXPENSE_KINDS:
		_text.add_text("%s: −%d $\n" % [Ledger.EXPENSE_NAMES[kind], summary.expenses_by_kind[kind]])
	_text.add_text("\nДОХОДЫ ОТ ПУБЛИКАЦИЙ\n")
	for type in range(3):
		_text.add_text("%s: %s $\n" % [Ledger.INCOME_NAMES[type], _signed(summary.publication_by_type[type])])
	_text.add_text("Исправления при вычитке: %s $\n" % _signed(summary.proofreading_income))
	var best_names: Array[String] = []
	for type in summary.best_types:
		best_names.append(Ledger.INCOME_NAMES[type])
	_text.add_text("Больше всего приносит: %s\n\n" % (", ".join(best_names) if not best_names.is_empty() else "пока нет доходов"))
	_text.add_text("ОПЕРАЦИИ — СНАЧАЛА НОВЫЕ\n")
	if summary.transactions.is_empty():
		_text.add_text("Записей пока нет.\n")
	for entry in summary.transactions:
		_text.add_text("День %d · %s · %s $\n" % [entry.day, entry.label, _signed(entry.amount)])
		if not str(entry.headline).is_empty():
			_text.add_text("  %s\n" % entry.headline)
		_text.add_text("\n")

func _signed(amount: int) -> String:
	return "+%d" % amount if amount > 0 else str(amount)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()
