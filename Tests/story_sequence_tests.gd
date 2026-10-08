extends SceneTree

var checks := 0
var failures := 0
const CATALOG = preload("res://Data/article_catalog.gd")
const STORIES = preload("res://Data/story_chains.gd")

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fresh(seed_value := 42) -> NewsroomSession:
	var session := NewsroomSession.new()
	session.balance = NewsroomBalance.new()
	session.balance.starting_health = 100
	session.balance.starting_money = 1000
	session.balance.rent = 0
	session.balance.health_drain_per_second = 0
	session.reset(seed_value)
	session.player_id = "sequence-test"
	session.run_id = "sequence-run"
	return session

func find_article(id: String) -> NewsArticle:
	for article in CATALOG.create_articles():
		if article.id == id:
			return article
	return null

func ids(articles: Array[NewsArticle]) -> Array[String]:
	var result: Array[String] = []
	for article in articles:
		result.append(article.id)
	return result

func roundtrip(session: NewsroomSession) -> Dictionary:
	return JSON.parse_string(JSON.stringify(NewsroomSaveData.capture(session)))

func mark(state: ProofreadingState, corrected: Array, wrong: Array = []) -> void:
	state.add_stroke({"segments": [{"anchor": "desk", "points": [[0.4, 0.7], [0.45, 0.7]]}], "corrected": corrected, "wrong": wrong})

func _run() -> void:
	_test_catalog_and_order()
	_test_choice_variants()
	_test_promotion()
	_test_short_shift_chains()
	_test_proofreading_save_and_accounting()
	_test_legacy_migration()
	_test_exhaustion_and_validation()
	print("STORY SEQUENCE TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_catalog_and_order() -> void:
	var catalog := CATALOG.create_articles()
	check(catalog.size() == 50 and ids(catalog).size() == 50, "Catalog contains fifty finite materials")
	var unique := {}
	var valid_types := true
	for article in catalog:
		unique[article.id] = true
		var types: Array[int] = []
		for option in article.headlines:
			types.append(option.editorial_type)
		types.sort()
		valid_types = valid_types and types == [0, 1, 2]
	check(unique.size() == 50 and valid_types, "Unique IDs and one headline of each current type")
	for row in preload("res://Docs/OriginalArticles/community_articles_original.gd").ROWS:
		check(find_article(row.id).source_text == row.text, "Original source body preserved: " + row.id)
	var first_order: Array[String] = []
	var varied := false
	for seed_value in 128:
		var queue := fresh(seed_value).articles
		var queue_ids := ids(queue)
		var ordered := true
		var separated := true
		var early := true
		for chain in STORIES.CHAINS.values():
			var last := -2
			for id in chain:
				var slot := queue_ids.find(id)
				ordered = ordered and slot > last
				separated = separated and slot - last >= 2
				early = early and slot < 32
				last = slot
		check(ordered and separated, "Logical chains and intervening material for seed%d" % seed_value)
		check(early, "Chains biased toward first shifts for seed%d" % seed_value)
		if seed_value == 0:
			first_order = queue_ids
		else:
			varied = varied or queue_ids != first_order
	check(varied and ids(fresh(17).articles) == ids(fresh(17).articles), "Randomized positions with reproducible seed")

func _test_choice_variants() -> void:
	for id in STORIES.VARIANTS:
		var source := find_article(id)
		var chain: Array = STORIES.CHAINS[ArticleSequence.chain_for(id)]
		var previous: String = chain[chain.find(id) - 1]
		for index in 3:
			var resolved := ArticleSequence.resolve(source, {previous: index})
			check(resolved.source_text == STORIES.VARIANTS[id][index] and source.source_text != resolved.source_text,
				"Exact choice changes only resolved copy: %s/%d" % [id, index])
		var custom := NewsArticle.from_row(source.to_row())
		custom.source_text = "Ручная правка исходника, которую нельзя подменять."
		check(ArticleSequence.resolve(custom, {previous: 1}).source_text == custom.source_text, "Custom saved source respected: " + id)
	var session := fresh()
	session.articles.assign([find_article("cats_rumor"), find_article("petition"), find_article("cats_denial")])
	session.start_shift()
	session.option_order.assign([2, 0, 1])
	check(session.publish_headline(0) and session.story_choices.cats_rumor == 2 and session.last_result.option_index == 2,
		"Record authored option index rather than shuffled display position")
	session.acknowledge_publication()
	session.health = 100
	session.reputation = 100
	session.loyalty = 100
	session.publish_headline(0)
	session.acknowledge_publication()
	check(session.current_article().source_text == STORIES.VARIANTS.cats_denial[2], "Continuation reads previous exact publication")
	var restored := fresh()
	check(NewsroomSaveData.restore(restored, roundtrip(session)) and restored.current_article().source_text == session.current_article().source_text,
		"Resolved continuation survives JSON load without altering catalog")
	var old_headline := ""
	for row in preload("res://Docs/OriginalArticles/community_articles_original.gd").ROWS:
		if row.id == "rat_chef":
			old_headline = row.options[2][0]
	var continuation := find_article("rat_complaint")
	check(ArticleSequence.resolve(continuation, {"rat_chef": 2}, [{"article_id": "rat_chef", "headline": old_headline}]).source_text == continuation.source_text,
		"An adapted index never misquotes an old differently worded headline")

func _test_promotion() -> void:
	var session := fresh()
	session.articles.assign([find_article("cats_rumor"), find_article("petition"), find_article("rat_chef"),
		find_article("bloom_poem"), find_article("cats_denial"), find_article("rat_complaint"), find_article("cats_taxi"), find_article("rat_resolution"), find_article("bloom_letter")])
	session.article_cursor = 1
	session.story_choices = {"cats_rumor": 1}
	ArticleSequence.promote_continuations(session.articles, 1, session.story_choices, session._rng)
	check(session.articles[0].id == "cats_rumor" and session.articles[1].id == "petition" and session.articles[2].id == "cats_denial",
		"Next shift promotion pins published prefix/current draft and leaves a separator")
	var queue_ids := ids(session.articles)
	check(queue_ids.find("cats_taxi") > queue_ids.find("cats_denial"), "Promotion never leapfrogs a later chain part")
	session = fresh()
	session.start_shift()
	session.finish_shift()
	check(session.phase == NewsroomSession.Phase.HOME and session.published_today == 0, "An empty shift can end with no mandatory minimum")

func _test_proofreading_save_and_accounting() -> void:
	var session := fresh()
	session.day = 2
	session.start_shift()
	check(session.proofreading_unlocked and session.proofreading.targets.size() == 1 and session.qualification == 70,
		"Third shift unlocks qualification and guarantees lesson typo")
	var source_before := session.current_article().source_text
	var target_id: int = session.proofreading.targets[0].id
	mark(session.proofreading, [target_id])
	var snapshot := roundtrip(session)
	var restored := fresh()
	check(NewsroomSaveData.restore(restored, snapshot) and restored.proofreading.to_data() == session.proofreading.to_data(),
		"Typos and mixed-capable strokes round-trip exactly")
	check(restored.current_article().source_text == source_before and restored.display_source_text(restored.current_article()) != source_before,
		"Typos never mutate authored source")
	session.finish_shift()
	var pending_proof := session.proofreading.to_data()
	restored = fresh()
	check(NewsroomSaveData.restore(restored, roundtrip(session)) and restored.proofreading.to_data() == pending_proof, "Home keeps unfinished proofreading")
	restored.start_shift()
	check(restored.proofreading.to_data() == pending_proof, "Next shift carries same unfinished material and strokes")
	var money_before := restored.money
	var ledger_before := restored.finances.entries.size()
	var income := roundi(restored.option_at(0).money * restored.balance.publication_income_multiplier)
	restored.publish_headline(0)
	check(restored.money == money_before + income + 2 and restored.qualification == 71 and restored.last_result.proofreading.money == 2,
		"Correct typo settlement is separate from base payout/combo")
	check(restored.finances.entries.size() == ledger_before + 2 and restored.finances.entries.back().kind == "proofreading_reward",
		"Notebook receives separate proofreading reward")
	var loaded := fresh()
	check(NewsroomSaveData.restore(loaded, roundtrip(restored)) and loaded.proofreading.article_id == restored.last_result.article_id,
		"Unacknowledged result preserves published typo copy/marks")
	var paid := loaded.money
	check(not loaded.publish_headline(0) and loaded.money == paid, "Result reload cannot pay corrections twice")
	loaded.acknowledge_publication()
	check(loaded.proofreading.article_id == loaded.current_article().id and loaded.proofreading.strokes.is_empty(), "Next material receives its own clean proofreading state")
	var missed := fresh()
	missed.day = 2
	missed.start_shift()
	missed.combo_count = 3
	missed.combo_type = missed.option_at(0).editorial_type
	missed.publish_headline(0)
	check(missed.last_result.proofreading.money == -1 and missed.last_result.proofreading.qualification == -3 and missed.qualification == 67,
		"Missed typo charges -1$/-3 qualification once without combo")
	var dismissed := fresh()
	dismissed.day = 2
	dismissed.start_shift()
	dismissed.qualification = 1
	dismissed.publish_headline(0)
	check(dismissed.ending == NewsroomSession.Ending.QUALIFICATION_FIRED and dismissed.qualification == 0,
		"Zero qualification dismisses the employee")

func _test_short_shift_chains() -> void:
	for seed_value in 32:
		var session := fresh(seed_value)
		session.balance.campaign_days = 100
		session.campaign_days = 100
		session.balance.proofreading_unlock_day = 100
		session.balance.maximum_stat = 10000
		session.balance.publication_health_cost = 0
		session.reputation = 10000
		session.loyalty = 10000
		var random := RandomNumberGenerator.new()
		random.seed = seed_value
		var seen: Dictionary = {}
		var valid := true
		var count := 0
		session.start_shift()
		while session.current_article() != null and count < 50:
			var quota := random.randi_range(1, 4)
			for publication in quota:
				var article := session.current_article()
				if article == null:
					break
				valid = valid and not seen.has(article.id)
				seen[article.id] = count
				count += 1
				session.publish_headline(random.randi_range(0, 2))
				session.acknowledge_publication()
			if session.phase == NewsroomSession.Phase.WORK:
				session.finish_shift()
			if session.current_article() != null:
				session.start_shift()
		for chain in STORIES.CHAINS.values():
			var previous := -2
			for id in chain:
				valid = valid and seen.has(id) and int(seen.get(id, -1)) - previous >= 2
				previous = int(seen.get(id, -1))
		check(valid and seen.size() == 50, "Repeated early shift endings keep finite chain order and separators: seed%d" % seed_value)

func _test_legacy_migration() -> void:
	var session := fresh()
	session.articles.clear()
	for row in preload("res://Data/community_articles.gd").ROWS + CATALOG.ROWS:
		session.articles.append(NewsArticle.from_row(row))
	session.day = 3
	session.phase = NewsroomSession.Phase.WORK
	session.article_cursor = 1
	session.articles[1].source_text = "Мой вручную отредактированный исходник: бережно сохраните каждую строку."
	session.journal = [{"article_id": "cats_rumor", "headline": session.articles[0].headlines[1].text, "day": 1, "money": 5, "combo_type": 0}]
	var legacy := roundtrip(session)
	legacy.content.erase("sequence_version")
	for key in ["story_choices", "qualification", "proofreading", "proofreading_started", "proofreading_unlocked"]:
		legacy.run.erase(key)
	var restored := fresh()
	check(NewsroomSaveData.restore(restored, legacy) and restored.articles.size() == 50, "Old thirty-two-material queue extends to fifty without reset")
	check(restored.article_cursor == 1 and restored.current_article().source_text == session.articles[1].source_text,
		"Old current draft and manual body remain pinned")
	check(restored.story_choices.get("cats_rumor") == 1 and restored.proofreading_unlocked and restored.proofreading.targets.size() == 1,
		"Old exact headline journal recovers choices; existing day3 unlocks lesson typo")
	var upgraded := roundtrip(restored)
	var twice := fresh()
	check(NewsroomSaveData.restore(twice, upgraded) and ids(twice.articles) == ids(restored.articles) and twice.proofreading.to_data() == restored.proofreading.to_data(),
		"Migration is one-time; new saves preserve actual order and seeded errors")
	legacy.run.article_cursor = 40
	check(NewsroomSaveData.restore(restored, legacy) and restored.article_cursor == 32 and restored.current_article().id != "cats_rumor",
		"Old wrapped cursor consumes original pool, never repeats it")

func _test_exhaustion_and_validation() -> void:
	var session := fresh()
	session.start_shift()
	session.article_cursor = session.articles.size() - 1
	session._resolved_article = null
	session.publish_headline(0)
	check(session.current_article() == null and session.option_at(0) == null, "Last publication exhausts finite queue")
	var saved := roundtrip(session)
	var restored := fresh()
	check(NewsroomSaveData.restore(restored, saved) and restored.awaiting_acknowledgement and restored.current_article() == null,
		"Final pending result reloads safely at cursor=size")
	restored.acknowledge_publication()
	check(restored.phase == NewsroomSession.Phase.HOME and not restored.publish_headline(0), "Final result acknowledgement goes home without wrapping")
	var before := NewsroomSaveData.capture(restored)
	for value in [3, -1, 1.5, "1", {}]:
		var invalid := saved.duplicate(true)
		invalid.run.story_choices[session.last_result.article_id] = value
		check(not NewsroomSaveData.restore(restored, invalid) and NewsroomSaveData.capture(restored) == before, "Malformed choice rejects atomically: " + str(value))
	var invalid := saved.duplicate(true)
	invalid.run.article_cursor += 1
	check(not NewsroomSaveData.validate(invalid), "New-format cursor cannot exceed the finite queue")
	invalid = saved.duplicate(true)
	invalid.run.proofreading.strokes = [{"segments": "broken"}]
	check(not NewsroomSaveData.restore(restored, invalid) and NewsroomSaveData.capture(restored) == before, "Malformed strokes reject before mutating run")
