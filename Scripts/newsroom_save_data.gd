class_name NewsroomSaveData
extends RefCounted

# Stable names, not node paths or enum ordinals. Add optional fields here; reset()
# supplies defaults for saves made before the field existed.
const NUMBERS := ["health", "reputation", "loyalty", "money", "day", "time_left",
	"shift_length", "article_cursor", "combo_type", "combo_count", "published_today",
	"earned_today", "total_published", "completed_shifts", "campaign_days", "campaign_money"]
const FLAGS := ["coffee_ready", "coffee_used_today", "food_stocked", "awaiting_acknowledgement", "campaign_completed"]
const PHASES := ["idle", "work", "home", "ended"]
const ENDINGS := ["none", "exhaustion", "office_fire", "arrest", "debt", "victory", "goal_missed"]

static func capture(session: NewsroomSession) -> Dictionary:
	var run := {"phase": PHASES[session.phase], "ending": ENDINGS[session.ending],
		"mode": session.mode, "id": session.run_id, "option_order": session.option_order.duplicate(),
		"journal": session.journal.duplicate(true), "last_result": session.last_result.duplicate(true),
		"last_shift": session.last_shift.duplicate(true)}
	for key in NUMBERS + FLAGS:
		run[key] = session.get(key)
	var rows: Array = []
	for article in session.articles:
		rows.append(article.to_row())
	return {
		"profile": {"id": session.player_id, "name": session.player_name, "endless_unlocked": session.endless_unlocked},
		"run": run,
		# Save the actual material, including generated stories, not just catalog indices.
		"content": {"articles": rows, "rng_seed": str(session._rng.seed), "rng_state": str(session._rng.state)}
	}

static func validate(sections: Dictionary) -> bool:
	for section in ["profile", "run", "content"]:
		if not sections.get(section) is Dictionary:
			return false
	var profile: Dictionary = sections.profile
	var run: Dictionary = sections.run
	var content: Dictionary = sections.content
	for key in ["health", "reputation", "loyalty", "money", "day", "time_left", "shift_length", "article_cursor", "completed_shifts"]:
		if not run.has(key):
			return false
	if not profile.get("name") is String or profile.name.strip_edges().is_empty() or profile.name.length() > 24:
		return false
	if not profile.get("id") is String or not run.get("id") is String:
		return false
	if profile.id.is_empty() or run.id.is_empty():
		return false
	if not profile.get("endless_unlocked", false) is bool:
		return false
	if not run.get("phase") in PHASES or not run.get("ending", "none") in ENDINGS or run.get("mode", "campaign") != "campaign":
		return false
	for key in NUMBERS:
		if run.has(key) and not _number(run[key]):
			return false
	for key in ["money", "day", "article_cursor", "combo_type", "combo_count", "published_today", "earned_today", "total_published", "completed_shifts", "campaign_days", "campaign_money"]:
		if run.has(key) and int(run[key]) != run[key]:
			return false
	for key in FLAGS:
		if run.has(key) and not run[key] is bool:
			return false
	for key in ["health", "reputation", "loyalty", "day", "time_left", "shift_length", "article_cursor", "combo_count", "published_today", "total_published", "completed_shifts", "campaign_money"]:
		if run.get(key, 0) < 0:
			return false
	if run.get("campaign_days", 5) < 1 or not int(run.get("combo_type", -1)) in [-1, 0, 1, 2]:
		return false
	if run.phase == "work" and (run.get("day", 0) < 1 or run.get("shift_length", 0) <= 0 or run.get("time_left", 0) > run.shift_length):
		return false
	if (run.phase == "ended") != (run.get("ending", "none") != "none"):
		return false
	if not run.get("option_order") is Array or run.option_order.size() != 3:
		return false
	var order: Array[int] = []
	for entry in run.option_order:
		if not _number(entry) or int(entry) != entry:
			return false
		order.append(int(entry))
	order.sort()
	if order != [0, 1, 2]:
		return false
	for key in ["last_result", "last_shift"]:
		if not run.get(key, {}) is Dictionary:
			return false
	if not run.get("journal", []) is Array:
		return false
	for entry in run.get("journal", []):
		if not entry is Dictionary:
			return false
	var result: Dictionary = run.get("last_result", {})
	if run.get("awaiting_acknowledgement", false) and result.is_empty():
		return false
	if not result.is_empty():
		for key in ["headline", "explanation"]:
			if not result.get(key) is String:
				return false
		for key in ["combo_type", "combo_count", "multiplier", "money", "reputation", "loyalty"]:
			if not _number(result.get(key)):
				return false
		if int(result.combo_type) != result.combo_type or not int(result.combo_type) in [0, 1, 2]:
			return false
	if not content.get("articles") is Array or content.articles.is_empty():
		return false
	var ids: Dictionary = {}
	for row in content.articles:
		if not _article_valid(row) or ids.has(row.id):
			return false
		ids[row.id] = true
	for key in ["rng_seed", "rng_state"]:
		if not content.get(key, "0") is String or not content.get(key, "0").is_valid_int():
			return false
	return true

static func restore(session: NewsroomSession, sections: Dictionary) -> bool:
	# Validate everything before touching the current session.
	if not validate(sections):
		return false
	session.reset(0)
	var run: Dictionary = sections.run
	for key in NUMBERS + FLAGS:
		if run.has(key):
			session.set(key, run[key])
	session.phase = PHASES.find(run.phase)
	session.ending = ENDINGS.find(run.get("ending", "none"))
	session.mode = run.get("mode", "campaign")
	session.run_id = run.id
	session.player_id = sections.profile.id
	session.player_name = sections.profile.name
	session.endless_unlocked = sections.profile.get("endless_unlocked", false)
	session.option_order.assign(run.option_order)
	session.journal.assign(run.get("journal", []).duplicate(true))
	session.last_result = run.get("last_result", {}).duplicate(true)
	session.last_shift = run.get("last_shift", {}).duplicate(true)
	session.articles.clear()
	for row in sections.content.articles:
		session.articles.append(NewsArticle.from_row(row))
	# JSON numbers cannot represent all 64-bit RNG states exactly. Store as strings.
	session._rng.seed = int(sections.content.get("rng_seed", "0"))
	session._rng.state = int(sections.content.get("rng_state", "0"))
	session.changed.emit()
	session.phase_changed.emit()
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _article_valid(row: Variant) -> bool:
	if not row is Dictionary:
		return false
	for key in ["id", "source", "text"]:
		if not row.get(key) is String or row[key].is_empty():
			return false
	if not row.get("provenance", {}) is Dictionary or not row.get("high_risk", false) is bool:
		return false
	if not row.get("options") is Array or row.options.size() != 3:
		return false
	for option in row.options:
		if not option is Array or option.size() < 6:
			return false
		if not option[0] is String or not option[4] is String or not _number(option[5]):
			return false
		if int(option[5]) != option[5] or not int(option[5]) in [0, 1, 2]:
			return false
		for i in [1, 2, 3]:
			if not _number(option[i]):
				return false
	return true
