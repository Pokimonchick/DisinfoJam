class_name NewsroomSaveData
extends RefCounted

# Stable names, not node paths or enum ordinals. Add optional fields here; reset()
# supplies defaults for saves made before the field existed.
const NUMBERS := ["health", "reputation", "loyalty", "qualification", "money", "day", "time_left",
	"shift_length", "article_cursor", "combo_type", "combo_count", "published_today",
	"earned_today", "total_published", "completed_shifts", "campaign_days", "campaign_money"]
const FLAGS := ["coffee_ready", "coffee_used_today", "approval_time_applied", "approval_stamina_applied", "food_stocked", "awaiting_acknowledgement", "campaign_completed", "proofreading_unlocked", "proofreading_started"]
const PHASES := ["idle", "work", "home", "ended"]
const ENDINGS := ["none", "exhaustion", "office_fire", "arrest", "debt", "victory", "goal_missed", "qualification_fired"]

static func capture(session: NewsroomSession) -> Dictionary:
	var run := {"phase": PHASES[session.phase], "ending": ENDINGS[session.ending],
		"mode": session.mode, "id": session.run_id, "option_order": session.option_order.duplicate(),
		"journal": session.journal.duplicate(true), "last_result": session.last_result.duplicate(true),
		"last_shift": session.last_shift.duplicate(true), "finances": session.finances.to_data(),
		"story_choices": session.story_choices.duplicate(), "proofreading": session.proofreading.to_data()}
	for key in NUMBERS + FLAGS:
		run[key] = session.get(key)
	var rows: Array = []
	for article in session.articles:
		rows.append(article.to_row())
	return {
		"profile": {"id": session.player_id, "name": session.player_name, "endless_unlocked": session.endless_unlocked},
		"run": run,
		# Save the actual material, including generated stories, not just catalog indices.
		"content": {"sequence_version": 1, "articles": rows, "rng_seed": str(session._rng.seed), "rng_state": str(session._rng.state)}
	}

static func validate(sections: Dictionary) -> bool:
	for section in ["profile", "run", "content"]:
		if not sections.get(section) is Dictionary:
			return false
	var profile: Dictionary = sections.profile
	var run: Dictionary = sections.run
	var content: Dictionary = sections.content
	if not preload("res://Scripts/finance_ledger.gd").validate_data(run.get("finances", {})):
		return false
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
	for key in ["health", "reputation", "loyalty", "qualification", "day", "time_left", "shift_length", "article_cursor", "combo_count", "published_today", "total_published", "completed_shifts", "campaign_money"]:
		if run.get(key, 0) < 0:
			return false
	if run.get("campaign_days", 5) < 1 or not int(run.get("combo_type", -1)) in [-1, 0, 1, 2]:
		return false
	if run.phase == "work" and (run.get("day", 0) < 1 or run.get("time_left", 0) > run.shift_length):
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
		if entry.has("option_index") and not _choice_index(entry.option_index):
			return false
		# Legacy finance import converts these fields before recording entries.
		if not run.get("finances", {}).has("entries"):
			for key in ["day", "money", "combo_type"]:
				if entry.has(key) and not preload("res://Scripts/finance_ledger.gd")._is_integer(entry[key]):
					return false
			if entry.get("combo_type", -1) < -1 or entry.get("combo_type", -1) > 2:
				return false
	var result: Dictionary = run.get("last_result", {})
	if run.get("awaiting_acknowledgement", false) and result.is_empty():
		return false
	if not result.is_empty():
		if result.has("option_index") and not _choice_index(result.option_index):
			return false
		if result.has("source_text") and not result.source_text is String:
			return false
		if result.has("proofreading"):
			if not result.proofreading is Dictionary:
				return false
			for key in ["corrected", "missed", "wrong", "money", "qualification"]:
				var value: Variant = result.proofreading.get(key)
				if not _number(value) or int(value) != value:
					return false
			for key in ["corrected", "missed", "wrong"]:
				if result.proofreading[key] < 0:
					return false
		for key in ["headline", "explanation"]:
			if not result.get(key) is String:
				return false
		for key in ["combo_type", "combo_count", "multiplier", "money", "reputation", "loyalty"]:
			if not _number(result.get(key)):
				return false
		if result.has("stamina_cost") and (not _number(result.stamina_cost) or result.stamina_cost < 0):
			return false
		if int(result.combo_type) != result.combo_type or not int(result.combo_type) in [0, 1, 2]:
			return false
	if not content.get("articles") is Array or content.articles.is_empty():
		return false
	if content.has("sequence_version") and (not _number(content.sequence_version) or content.sequence_version != 1):
		return false
	if content.has("sequence_version") and run.article_cursor > content.articles.size():
		return false
	var ids: Dictionary = {}
	for row in content.articles:
		if not _article_valid(row) or ids.has(row.id):
			return false
		ids[row.id] = true
	if not run.get("story_choices", {}) is Dictionary:
		return false
	for id in run.get("story_choices", {}):
		var choice: Variant = run.story_choices[id]
		if not id is String or not ids.has(id) or not _number(choice) or int(choice) != choice or not int(choice) in [0, 1, 2]:
			return false
	if run.has("proofreading"):
		if not run.proofreading is Dictionary or not ProofreadingState.validate_data(run.proofreading):
			return false
		var proof_id: String = run.proofreading.article_id
		if not proof_id.is_empty() and not ids.has(proof_id):
			return false
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
	# Old versions required a cash target. A finished week now completes the
	# chapter; resource-loss endings retain their original outcome.
	if session.ending == NewsroomSession.Ending.GOAL_MISSED:
		session.ending = NewsroomSession.Ending.VICTORY
		session.campaign_completed = true
		session.endless_unlocked = true
	session.option_order.assign(run.option_order)
	session.journal.assign(run.get("journal", []).duplicate(true))
	session.last_result = run.get("last_result", {}).duplicate(true)
	session.last_shift = run.get("last_shift", {}).duplicate(true)
	session.finances.restore(run.get("finances", {}), session.journal, session.completed_shifts)
	session.articles.clear()
	for row in sections.content.articles:
		session.articles.append(NewsArticle.from_row(row))
	preload("res://Data/legacy_article_balance.gd").apply(session.articles)
	# JSON numbers cannot represent all 64-bit RNG states exactly. Store as strings.
	session._rng.seed = int(sections.content.get("rng_seed", "0"))
	session._rng.state = int(sections.content.get("rng_state", "0"))
	_restore_story_choices(session, run)
	if not sections.content.has("sequence_version"):
		_migrate_queue(session)
	session._resolved_article = null
	if not run.has("proofreading_unlocked"):
		session.proofreading_unlocked = session.day >= session.balance.proofreading_unlock_day
	if run.has("proofreading"):
		session.proofreading.restore(run.proofreading)
	if not session.awaiting_acknowledgement and session.phase in [NewsroomSession.Phase.WORK, NewsroomSession.Phase.HOME]:
		session.prepare_proofreading()
	session.changed.emit()
	session.phase_changed.emit()
	return true

static func _restore_story_choices(session: NewsroomSession, run: Dictionary) -> void:
	session.story_choices.clear()
	for id in run.get("story_choices", {}):
		session.story_choices[id] = int(run.story_choices[id])
	for entry in session.journal:
		var id: String = str(entry.get("article_id", ""))
		if id.is_empty() or session.story_choices.has(id):
			continue
		var index: Variant = entry.get("option_index", -1)
		if _number(index) and int(index) == index and int(index) in [0, 1, 2]:
			session.story_choices[id] = int(index)
			continue
		# Old journals store exact headline text. Recover the stable authored index
		# from that run first, then the untouched archive of the eight user sources.
		for article in session.articles:
			if article.id == id:
				for option in article.headlines.size():
					if article.headlines[option].text == entry.get("headline", ""):
						session.story_choices[id] = option
		for row in preload("res://Docs/OriginalArticles/community_articles_original.gd").ROWS:
			if row.id == id and not session.story_choices.has(id):
				for option in row.options.size():
					if row.options[option][0] == entry.get("headline", ""):
						session.story_choices[id] = option

static func _migrate_queue(session: NewsroomSession) -> void:
	# Keep the published prefix and the current draft. Extend the actual saved
	# content with missing catalog IDs; never replace manually edited materials.
	session.article_cursor = mini(session.article_cursor, session.articles.size())
	var published_ids: Dictionary = {}
	for entry in session.journal:
		published_ids[str(entry.get("article_id", ""))] = true
	for index in range(session.articles.size() - 1, session.article_cursor - 1, -1):
		if published_ids.has(session.articles[index].id):
			session.articles.remove_at(index)
	var existing: Dictionary = published_ids.duplicate()
	for article in session.articles:
		existing[article.id] = true
	for article in preload("res://Data/article_catalog.gd").create_articles():
		if not existing.has(article.id):
			session.articles.append(article)
			existing[article.id] = true
	ArticleSequence.order_remaining(session.articles, session.article_cursor + 1)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _choice_index(value: Variant) -> bool:
	return _number(value) and int(value) == value and int(value) in [0, 1, 2]

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
