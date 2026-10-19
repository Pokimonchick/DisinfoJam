extends SceneTree

const RUSSIAN := "Сегодня редакторы проверяют сообщения жителей. Рабочие обсуждают строительство городской школы."
const ENGLISH := "Today editors carefully check residents’ reports. Workers discuss construction of the neighborhood school."
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _stroke() -> Dictionary:
	return {"segments": [{"anchor": "desk", "points": [[0.3, 0.5], [0.4, 0.5]]}], "corrected": [], "wrong": []}

func _session() -> NewsroomSession:
	var session := NewsroomSession.new()
	session.balance = NewsroomBalance.new()
	session.reset(74)
	session.player_id = "localized-player"
	session.run_id = "localized-run"
	var article := NewsArticle.from_row({"id": "localized-proof", "source": "Источник", "text": RUSSIAN,
		"options": [["Заголовок", 20, 5, 0, "Пояснение", 0], ["Сенсация", 30, -5, -5, "Пояснение", 1], ["Поддержка", 20, 0, 5, "Пояснение", 2]]})
	session.articles.assign([article])
	session._resolved_article = null
	session.day = 2
	session.phase = NewsroomSession.Phase.WORK
	session.proofreading_unlocked = true
	session.prepare_proofreading()
	return session

func _run() -> void:
	var previous_locale := TranslationServer.get_locale()
	var russian_translation := Translation.new()
	russian_translation.locale = "ru"
	russian_translation.add_message(RUSSIAN, RUSSIAN)
	TranslationServer.add_translation(russian_translation)
	var translation := Translation.new()
	translation.locale = "en"
	translation.add_message(RUSSIAN, ENGLISH)
	TranslationServer.add_translation(translation)
	_generation_checks()
	_switch_checks()
	_save_checks()
	_publication_result_checks()
	TranslationServer.remove_translation(translation)
	TranslationServer.remove_translation(russian_translation)
	TranslationServer.set_locale(previous_locale)
	print("LOCALIZED PROOFREADING TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _generation_checks() -> void:
	check(ProofreadingState.words("words слова").size() == 2, "Word recognition supports Latin and Cyrillic")
	for source in [RUSSIAN, ENGLISH]:
		var alphabet := ProofreadingState.ENGLISH_LETTERS if source == ENGLISH else ProofreadingState.LETTERS
		for random_seed in 40:
			var state := ProofreadingState.new()
			state.prepare("alphabet", source, random_seed, true)
			check(state.targets.size() == 1 and ProofreadingState.validate_data(state.to_data()), "Both languages generate valid guaranteed typos")
			var matching_alphabet := true
			for letter in state.targets[0].typo:
				matching_alphabet = matching_alphabet and letter in alphabet
			check(matching_alphabet, "Typo letters belong to the original word’s alphabet")
			var bad := state.to_data()
			var start := int(bad.targets[0].start)
			var foreign := "я" if source == ENGLISH else "z"
			bad.targets[0].typo = foreign + bad.targets[0].typo.substr(1)
			bad.display_text = bad.display_text.substr(0, start) + foreign + bad.display_text.substr(start + 1)
			check(not ProofreadingState.validate_data(bad), "Cross-alphabet corruption is rejected even when displayed text matches")
	var requested := ProofreadingState.new()
	requested.prepare("count", ENGLISH, 19, false, 3)
	check(requested.targets.size() == 3, "An alternate language can preserve the previous draft’s target count")
	requested.prepare("count", "Short words.", 19, false, 5)
	check(requested.targets.size() == 1, "Requested target count is limited by suitable words")
	requested.prepare("count", ENGLISH, 19, false, 0)
	check(requested.targets.is_empty(), "A clean article remains clean in another language")

func _switch_checks() -> void:
	TranslationServer.set_locale("ru")
	var session := _session()
	session.proofreading.add_stroke(_stroke())
	var russian := session.proofreading.to_data()
	TranslationServer.set_locale("en")
	session.prepare_proofreading()
	check(session.proofreading.source_text == ENGLISH and session.localized_source_text(session.current_article()) == ENGLISH, "Session uses translated English source for proofreading")
	check(russian.targets.size() == 1 and session.proofreading.targets.size() == 1, "Switching the first pencil lesson preserves its guaranteed typo")
	check(session.current_article().source_text == RUSSIAN and session.current_article().headlines[0].text == "Заголовок", "Canonical article and headline remain Russian")
	session.proofreading.add_stroke(_stroke())
	session.proofreading.add_stroke(_stroke())
	var english := session.proofreading.to_data()
	var rng_state := session._rng.state
	for locale in ["ru", "en", "ru", "en"]:
		TranslationServer.set_locale(locale)
		session.prepare_proofreading()
		check(session.proofreading.to_data() == (russian if locale == "ru" else english), "Revisiting a language restores its exact typo targets and marks")
		check(session._rng.state == rng_state, "Revisiting a language never consumes random state")
	var replacement := NewsArticle.from_row(session.current_article().to_row())
	replacement.id = "replacement"
	session.articles.assign([replacement])
	session._resolved_article = null
	session.prepare_proofreading()
	check(session.proofreading_drafts.is_empty() and session.proofreading.article_id == "replacement" and session.proofreading.strokes.is_empty(), "A new article clears language drafts and old marks")
	var snapshot := NewsroomSaveData.capture(session)
	check(NewsroomSaveData.validate(snapshot) and snapshot.run.proofreading_drafts.keys() == ["en"] and snapshot.run.proofreading_drafts.en.article_id == "replacement", "Capturing after article replacement contains only the new article’s active language")

func _save_checks() -> void:
	for saved_locale in ["ru", "en"]:
		TranslationServer.set_locale("ru")
		var session := _session()
		session.proofreading.add_stroke(_stroke())
		TranslationServer.set_locale("en")
		session.prepare_proofreading()
		session.proofreading.add_stroke(_stroke())
		session.proofreading.add_stroke(_stroke())
		TranslationServer.set_locale(saved_locale)
		session.prepare_proofreading()
		var expected := session.proofreading_draft_data()
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(NewsroomSaveData.capture(session)))
		var drafts: Dictionary = snapshot.run.proofreading_drafts
		check(NewsroomSaveData.validate(snapshot) and drafts.size() == 2, "Both language drafts are saved as validated primitive data")
		check(snapshot.content.articles[0].text == RUSSIAN and snapshot.content.articles[0].options[0][0] == "Заголовок", "Saved canonical article and headline stay Russian")
		var other := "en" if saved_locale == "ru" else "ru"
		TranslationServer.set_locale(other)
		var restored := NewsroomSession.new()
		check(NewsroomSaveData.restore(restored, snapshot), "A bilingual save loads under the other interface language")
		check(restored.proofreading.to_data() == expected[other], "Loading restores the selected language’s cached draft")
		check(restored._rng.state == int(snapshot.content.rng_state), "Loading a cached language preserves the random sequence")
		TranslationServer.set_locale(saved_locale)
		restored.prepare_proofreading()
		check(restored.proofreading.to_data() == expected[saved_locale], "Switching after load preserves the previously active draft")
		var legacy := snapshot.duplicate(true)
		legacy.run.erase("proofreading_drafts")
		TranslationServer.set_locale(other)
		check(NewsroomSaveData.restore(restored, legacy), "Old saves without per-language drafts still load")
		check(restored.proofreading.source_text == (ENGLISH if other == "en" else RUSSIAN), "Old save infers previous language from source before switching")
		TranslationServer.set_locale(saved_locale)
		restored.prepare_proofreading()
		check(restored.proofreading.to_data() == expected[saved_locale], "Old saved active draft survives a load into the opposite language")
		var invalid := snapshot.duplicate(true)
		invalid.run.proofreading_drafts["fr"] = drafts[saved_locale]
		check(not NewsroomSaveData.validate(invalid), "Unsupported cached language is rejected")
		invalid = snapshot.duplicate(true)
		invalid.run.proofreading_drafts[saved_locale].strokes[0].segments[0].points = [["bad", 0], [0, 0]]
		check(not NewsroomSaveData.validate(invalid), "Corrupted inactive or active cached marks are rejected")
		invalid = snapshot.duplicate(true)
		invalid.run.proofreading_drafts[saved_locale].article_id = "missing-article"
		check(not NewsroomSaveData.validate(invalid), "Drafts for a different or missing article are rejected")

func _publication_result_checks() -> void:
	for saved_locale in ["ru", "en"]:
		TranslationServer.set_locale("ru")
		var session := _session()
		var second := NewsArticle.from_row(session.current_article().to_row())
		second.id = "second-proof"
		session.articles.append(second)
		var correction := _stroke()
		correction.corrected = [session.proofreading.targets[0].id]
		session.proofreading.add_stroke(correction)
		TranslationServer.set_locale("en")
		session.prepare_proofreading()
		session.proofreading.add_stroke(_stroke())
		session.proofreading.add_stroke(_stroke())
		TranslationServer.set_locale(saved_locale)
		session.prepare_proofreading()
		var expected := session.proofreading_draft_data()
		check(session.publish_headline(0), "Publish the first of two articles while retaining its displayed proof")
		var settled_result := session.last_result.duplicate(true)
		var settled_money := session.money
		var settled_qualification := session.qualification
		var journal := session.journal.duplicate(true)
		check(session.current_article().id == second.id and session.article_cursor == 1, "Publication still advances the canonical queue immediately")
		for locale in ["en", "ru", "en", saved_locale]:
			TranslationServer.set_locale(locale)
			session.prepare_proofreading()
			check(session.proofreading.to_data() == expected[locale], "Switching language on a publication result preserves its exact proof and marks")
			check(session.current_article().id == second.id and session._proofreading_article().id == "localized-proof", "Displayed publication proof remains separate from the next queued article")
			check(session.last_result == settled_result and session.money == settled_money and session.qualification == settled_qualification and session.journal == journal, "Changing result language never resettles rewards, penalties or journal entries")
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(NewsroomSaveData.capture(session)))
		check(NewsroomSaveData.validate(snapshot) and snapshot.run.proofreading_drafts.size() == 2, "Result snapshots capture both published proof languages after the queue advances")
		var other := "en" if saved_locale == "ru" else "ru"
		TranslationServer.set_locale(other)
		var restored := NewsroomSession.new()
		check(NewsroomSaveData.restore(restored, snapshot), "A pending publication result loads under the opposite language")
		restored.prepare_proofreading()
		check(restored.proofreading.to_data() == expected[other] and restored.proofreading.article_id == "localized-proof", "Preparing the loaded result restores the published article rather than the next draft")
		TranslationServer.set_locale(saved_locale)
		restored.prepare_proofreading()
		check(restored.proofreading.to_data() == expected[saved_locale] and restored.last_result == snapshot.run.last_result, "Both result languages survive loading without altering the settled result")
		restored.acknowledge_publication()
		check(not restored.awaiting_acknowledgement and restored.current_article().id == second.id and restored.proofreading.article_id == second.id and restored.proofreading.strokes.is_empty() and restored.proofreading_drafts.is_empty(), "Acknowledgement moves to the next article and clears published language drafts")
		var next_snapshot := NewsroomSaveData.capture(restored)
		check(NewsroomSaveData.validate(next_snapshot) and next_snapshot.run.proofreading_drafts.size() == 1 and next_snapshot.run.proofreading_drafts[saved_locale].article_id == second.id, "The next snapshot contains only the new article’s active proof")
