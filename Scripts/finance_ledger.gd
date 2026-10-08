class_name FinanceLedger
extends RefCounted

const EXPENSE_KINDS := ["rent", "meal", "snack", "coffee", "proofreading_missed", "proofreading_wrong"]
const EXPENSE_NAMES := {"rent": "Аренда", "meal": "Полноценная еда", "snack": "Перекус", "coffee": "Кофе", "proofreading_missed": "Пропущенные опечатки", "proofreading_wrong": "Неверные пометки"}
const INCOME_NAMES := ["Факты", "Сенсация", "Поддержка власти"]

var entries: Array[Dictionary] = []
var history_incomplete := false
var _next_id := 1

static func validate_data(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.is_empty():
		return true
	if not _is_integer(data.get("version")) or data.version != 1:
		return false
	if not data.get("entries") is Array or not data.get("history_incomplete") is bool:
		return false
	var seen := {}
	for entry in data.entries:
		if not entry is Dictionary:
			return false
		for field in ["id", "day", "amount", "editorial_type"]:
			if not _is_integer(entry.get(field)):
				return false
		if entry.id <= 0 or entry.day <= 0 or seen.has(int(entry.id)):
			return false
		seen[int(entry.id)] = true
		if entry.editorial_type < -1 or entry.editorial_type > 2:
			return false
		for field in ["kind", "label", "headline"]:
			if not entry.get(field) is String:
				return false
		if entry.kind.strip_edges().is_empty() or entry.label.strip_edges().is_empty():
			return false
	return true

# JSON decodes integer values as floats, so integral finite floats are accepted.
static func _is_integer(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floor(value) and value >= -9223372036854775808.0 and value < 9223372036854775808.0

func record(day: int, kind: String, amount: int, label: String, editorial_type: int = -1, headline: String = "") -> void:
	entries.append({"id": _next_id, "day": maxi(day, 1), "kind": kind,
		"amount": amount, "label": label, "editorial_type": editorial_type, "headline": headline})
	_next_id += 1

func to_data() -> Dictionary:
	return {"version": 1, "entries": entries.duplicate(true), "history_incomplete": history_incomplete}

# Restore replaces the ledger; importing legacy publications never changes money.
func restore(data: Dictionary, legacy_journal: Array = [], completed_shifts: int = 0) -> void:
	entries.clear()
	_next_id = 1
	history_incomplete = bool(data.get("history_incomplete", false))
	if not data.has("entries"):
		history_incomplete = completed_shifts > 0 or not legacy_journal.is_empty()
		for item in legacy_journal:
			if item is Dictionary:
				record(int(item.get("day", 1)), "publication", int(item.get("money", 0)),
					"Публикация", int(item.get("combo_type", -1)), str(item.get("headline", "")))
		return
	var rows: Variant = data.get("entries", [])
	if not rows is Array:
		return
	var seen := {}
	for item in rows:
		if not item is Dictionary:
			continue
		var entry_id := int(item.get("id", _next_id))
		if entry_id < 1 or seen.has(entry_id):
			continue
		seen[entry_id] = true
		entries.append({"id": entry_id, "day": maxi(int(item.get("day", 1)), 1),
			"kind": str(item.get("kind", "other")), "amount": int(item.get("amount", 0)),
			"label": str(item.get("label", "Операция")), "editorial_type": int(item.get("editorial_type", -1)),
			"headline": str(item.get("headline", ""))})
		_next_id = maxi(_next_id, entry_id + 1)

func summary(day: int = -1) -> Dictionary:
	var result := {"income": 0, "expenses": 0, "balance": 0, "expenses_by_kind": {},
		"publication_by_type": {0: 0, 1: 0, 2: 0}, "proofreading_income": 0, "best_types": [], "transactions": []}
	for kind in EXPENSE_KINDS:
		result.expenses_by_kind[kind] = 0
	for entry in entries:
		if day >= 0 and entry.day != day:
			continue
		result.transactions.append(entry.duplicate(true))
		var amount: int = entry.amount
		result.balance += amount
		if amount > 0:
			result.income += amount
		elif amount < 0:
			result.expenses -= amount
		if result.expenses_by_kind.has(entry.kind) and amount < 0:
			result.expenses_by_kind[entry.kind] -= amount
		if entry.kind == "publication" and result.publication_by_type.has(entry.editorial_type):
			result.publication_by_type[entry.editorial_type] += amount
		if entry.kind == "proofreading_reward":
			result.proofreading_income += amount
	var best := 0
	for type in range(3):
		var earned: int = result.publication_by_type[type]
		if earned > best:
			best = earned
			result.best_types = [type]
		elif earned == best and best > 0:
			result.best_types.append(type)
	result.transactions.reverse()
	return result
