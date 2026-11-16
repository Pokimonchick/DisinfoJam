class_name NewsroomSession
extends RefCounted

const CAMPAIGN_HERO_NAME := "Никола Коко"
const HOME_ITEMS = preload("res://Data/home_items.gd")

signal changed
signal phase_changed
signal article_changed
signal published(result: Dictionary)
signal save_requested
signal transaction_recorded(entry: Dictionary)

enum Phase { IDLE, WORK, HOME, ENDED }
enum Ending { NONE, EXHAUSTION, OFFICE_FIRE, ARREST, DEBT, VICTORY, GOAL_MISSED, QUALIFICATION_FIRED }

var balance: NewsroomBalance = preload("res://Data/mvp_balance.tres")
var articles: Array[NewsArticle] = []
var phase: Phase = Phase.IDLE
var ending: Ending = Ending.NONE
var health: float
var reputation: float
var loyalty: float
var qualification: float = 70.0
var proofreading_unlocked := false
var proofreading_started := false
var proofreading := ProofreadingState.new()
var proofreading_drafts: Dictionary = {}
var _proofreading_locale := ""
var story_choices: Dictionary = {}
var _resolved_article: NewsArticle
var money: int
var day: int = 0
# Inert legacy save fields. Work no longer counts down or ends on a deadline.
var time_left: float = 0.0
var shift_length: float = 0.0
var article_cursor: int = 0
var option_order: Array[int] = []
var coffee_ready: bool = false
var coffee_used_today: bool = false
var approval_time_applied: bool = false
var approval_stamina_applied: bool = false
var food_stocked: bool = false
var inventory: Dictionary = {}
var combo_type: int = -1
var combo_count: int = 0
var awaiting_acknowledgement: bool = false
var published_today: int = 0
var earned_today: int = 0
var total_published: int = 0
var completed_shifts: int = 0
var journal: Array[Dictionary] = []
var finances := preload("res://Scripts/finance_ledger.gd").new()
var last_shift: Dictionary = {}
var last_result: Dictionary = {}
var player_name: String = CAMPAIGN_HERO_NAME
var player_id: String = ""
var run_id: String = ""
var mode: String = "campaign"
var campaign_days: int = 5
var campaign_money: int = 200
var campaign_completed: bool = false
var endless_unlocked: bool = false
var _rng := RandomNumberGenerator.new()


func reset(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	articles = preload("res://Data/article_catalog.gd").create_articles()
	_shuffle_articles()
	mode = "campaign"
	campaign_days = balance.campaign_days
	campaign_money = balance.campaign_money
	campaign_completed = false
	endless_unlocked = false
	phase = Phase.IDLE
	ending = Ending.NONE
	health = balance.starting_health
	reputation = balance.starting_reputation
	loyalty = balance.starting_loyalty
	qualification = balance.starting_qualification
	proofreading_unlocked = false
	proofreading_started = false
	proofreading = ProofreadingState.new()
	proofreading_drafts.clear()
	_proofreading_locale = ""
	story_choices.clear()
	_resolved_article = null
	money = balance.starting_money
	day = 0
	time_left = 0.0
	shift_length = 0.0
	article_cursor = 0
	coffee_ready = true
	coffee_used_today = false
	approval_time_applied = false
	approval_stamina_applied = false
	food_stocked = false
	inventory.clear()
	combo_type = -1
	combo_count = 0
	awaiting_acknowledgement = false
	published_today = 0
	earned_today = 0
	total_published = 0
	completed_shifts = 0
	journal.clear()
	finances.restore({})
	last_shift.clear()
	last_result.clear()
	_shuffle_options()
	changed.emit()
	phase_changed.emit()


func start_shift() -> void:
	if phase != Phase.IDLE and phase != Phase.HOME:
		return
	if articles.is_empty() or _check_ending():
		return
	if phase == Phase.HOME:
		health = minf(balance.maximum_stat, health + balance.sleep_health)
	day += 1
	if day > 1:
		ArticleSequence.promote_continuations(articles, article_cursor, story_choices, _rng)
		_resolved_article = null
	proofreading_unlocked = day >= balance.proofreading_unlock_day
	prepare_proofreading()
	approval_stamina_applied = loyalty >= balance.state_approval.threshold
	if approval_stamina_applied:
		health = minf(balance.maximum_stat, health + balance.state_approval.amount)
	approval_time_applied = false
	shift_length = 0.0
	coffee_used_today = false
	combo_type = -1
	combo_count = 0
	time_left = 0.0
	published_today = 0
	earned_today = 0
	awaiting_acknowledgement = false
	phase = Phase.WORK
	changed.emit()
	phase_changed.emit()
	article_changed.emit()
	save_requested.emit()


func tick_work(delta: float) -> void:
	if phase != Phase.WORK or awaiting_acknowledgement or delta <= 0.0:
		return
	health = maxf(0.0, health - delta * balance.health_drain_per_second)
	changed.emit()
	_check_ending()


func current_article() -> NewsArticle:
	if article_cursor >= articles.size():
		return null
	if _resolved_article == null or _resolved_article.id != articles[article_cursor].id:
		_resolved_article = ArticleSequence.resolve(articles[article_cursor], story_choices, journal)
	return _resolved_article


func localized_source_text(article: NewsArticle) -> String:
	return TranslationServer.translate(article.source_text)


func _proofreading_article() -> NewsArticle:
	# Publication advances the queue before the result leaves the desk. Language
	# changes must keep the displayed publication's marks until acknowledgement.
	if awaiting_acknowledgement and not last_result.is_empty():
		for article in articles:
			if article.id == last_result.get("article_id", ""):
				return ArticleSequence.resolve(article, story_choices, journal)
	return current_article()


func display_source_text(article: NewsArticle) -> String:
	var source := localized_source_text(article)
	if proofreading_unlocked and proofreading.article_id == article.id and proofreading.source_text == source:
		return proofreading.display_text
	return source


func _active_proofreading_locale(article: NewsArticle) -> String:
	if not _proofreading_locale.is_empty():
		return _proofreading_locale
	# Old saves have no locale field. Infer the saved text's language, which may
	# differ from the interface language selected before loading the run.
	return "ru" if proofreading.source_text == article.source_text else "en"


func proofreading_draft_data() -> Dictionary:
	var drafts := proofreading_drafts.duplicate(true)
	var article := _proofreading_article()
	if article != null and proofreading.article_id == article.id:
		drafts[_active_proofreading_locale(article)] = proofreading.to_data()
	return drafts


func prepare_proofreading() -> void:
	var article := _proofreading_article()
	if article == null:
		proofreading_drafts.clear()
		_proofreading_locale = ""
		return
	if proofreading.article_id != article.id:
		proofreading_drafts.clear()
		_proofreading_locale = ""
	if not proofreading_unlocked:
		return
	var source := localized_source_text(article)
	var locale := "en" if TranslationServer.get_locale().begins_with("en") else "ru"
	if proofreading.article_id == article.id and proofreading.source_text == source:
		_proofreading_locale = locale
		return
	if proofreading.article_id == article.id:
		proofreading_drafts[_active_proofreading_locale(article)] = proofreading.to_data()
	if proofreading_drafts.has(locale) and proofreading_drafts[locale].source_text == source:
		proofreading.restore(proofreading_drafts[locale])
	else:
		# A language change must not change the number of rewards or penalties
		# available on this article, including the first guaranteed pencil lesson.
		var target_count := proofreading.targets.size() if proofreading.article_id == article.id else -1
		proofreading.prepare(article.id, source, _rng.randi(), not proofreading_started, target_count)
	_proofreading_locale = locale
	proofreading_started = true


func proofreading_changed() -> void:
	changed.emit()
	save_requested.emit()


func option_at(display_index: int) -> HeadlineOption:
	if display_index < 0 or display_index >= option_order.size() or current_article() == null:
		return null
	return current_article().headlines[option_order[display_index]]


func publish_headline(display_index: int, proofreading_counts: Dictionary = {}) -> bool:
	if phase != Phase.WORK or awaiting_acknowledgement or publication_limit_reached():
		return false
	var option := option_at(display_index)
	if option == null:
		return false
	awaiting_acknowledgement = true
	combo_count = combo_count + 1 if combo_type == option.editorial_type else 1
	combo_type = option.editorial_type
	var multiplier := combo_multiplier()
	var stamina_cost := publication_stamina_cost()
	var article := current_article()
	last_result = {
		"article_id": article.id,
		"option_index": option_order[display_index],
		"source_text": display_source_text(article),
		"headline": option.text,
		"money": roundi(option.money * multiplier * balance.publication_income_multiplier),
		"reputation": roundi(option.reputation * multiplier),
		"loyalty": roundi(option.loyalty * multiplier),
		"combo_type": combo_type,
		"combo_count": combo_count,
		"multiplier": multiplier,
		"stamina_cost": stamina_cost,
		"explanation": option.explanation,
		"day": day,
	}
	money += last_result.money
	_record_transaction("publication", last_result.money, "Публикация", combo_type, option.text)
	if proofreading_unlocked and proofreading.article_id == article.id:
		var corrections := proofreading.settlement(balance.proofreading_money_penalty_limit, balance.proofreading_qualification_penalty_limit, proofreading_counts)
		var penalties := ProofreadingState.penalty_breakdown(corrections.missed, corrections.wrong, balance.proofreading_money_penalty_limit, balance.proofreading_qualification_penalty_limit)
		last_result["proofreading"] = corrections
		last_result["publication_money"] = last_result.money
		last_result.money += corrections.money
		money += corrections.money
		qualification = clampf(qualification + corrections.qualification, 0.0, balance.maximum_stat)
		for transaction in [["proofreading_reward", corrections.corrected * 2, "Вычитка: исправления"],
			["proofreading_missed", -penalties.missed_money, "Вычитка: пропущенные опечатки"],
			["proofreading_wrong", -penalties.wrong_money, "Вычитка: неверные пометки"]]:
			if transaction[1] != 0:
				_record_transaction(transaction[0], transaction[1], transaction[2], -1, option.text)
	reputation = clampf(reputation + last_result.reputation, 0.0, balance.maximum_stat)
	loyalty = clampf(loyalty + last_result.loyalty, 0.0, balance.maximum_stat)
	health = maxf(0.0, health - stamina_cost)
	published_today += 1
	total_published += 1
	earned_today += last_result.money
	journal.append(last_result.duplicate())
	story_choices[article.id] = option_order[display_index]
	# A published article leaves the queue immediately, even if the shift ends
	# while its feedback is visible. Unconfirmed articles keep their cursor.
	article_cursor += 1
	_resolved_article = null
	_shuffle_options()
	changed.emit()
	if not _check_ending():
		published.emit(last_result)
	save_requested.emit()
	return true


func acknowledge_publication() -> void:
	if phase != Phase.WORK or not awaiting_acknowledgement:
		return
	awaiting_acknowledgement = false
	if publication_limit_reached() or current_article() == null:
		finish_shift()
		return
	prepare_proofreading()
	article_changed.emit()
	save_requested.emit()


func publication_limit_reached() -> bool:
	return published_today >= maxi(1, balance.publication_limit)


func finish_shift() -> void:
	if phase != Phase.WORK:
		return
	time_left = 0.0
	awaiting_acknowledgement = false
	money -= balance.rent
	_record_transaction("rent", -balance.rent, "Аренда комнаты")
	completed_shifts += 1
	food_stocked = false
	last_shift = {"count": published_today, "earnings": earned_today, "rent": balance.rent}
	changed.emit()
	if _check_ending():
		return
	if mode == "campaign" and completed_shifts >= campaign_days:
		campaign_completed = true
		endless_unlocked = campaign_completed
		ending = Ending.VICTORY
		phase = Phase.ENDED
		phase_changed.emit()
		save_requested.emit()
		return
	phase = Phase.HOME
	phase_changed.emit()
	save_requested.emit()


func buy_food(full_meal: bool) -> bool:
	if phase != Phase.HOME or health >= balance.maximum_stat:
		return false
	var price := balance.meal_price if full_meal else balance.snack_price
	money -= price
	_record_transaction("meal" if full_meal else "snack", -price, "Еда" if full_meal else "Перекус")
	food_stocked = true
	health = minf(balance.maximum_stat, health + (balance.meal_health if full_meal else balance.snack_health))
	changed.emit()
	_check_ending()
	save_requested.emit()
	return true


func buy_coffee() -> bool:
	if phase != Phase.HOME or coffee_ready:
		return false
	coffee_ready = true
	money -= balance.coffee_price
	_record_transaction("coffee", -balance.coffee_price, "Кофе с собой")
	changed.emit()
	_check_ending()
	save_requested.emit()
	return true


func buy_home_item(id: String) -> Dictionary:
	if phase != Phase.HOME:
		return {"ok": false, "reason": "wrong_phase"}
	var item: Dictionary = HOME_ITEMS.get_item(id)
	if item.is_empty():
		return {"ok": false, "reason": "unknown_item"}
	if int(inventory.get(id, 0)) >= HOME_ITEMS.MAX_COUNT:
		return {"ok": false, "reason": "inventory_full"}
	money -= int(item.price)
	inventory[id] = int(inventory.get(id, 0)) + 1
	var kind: String = {"drink": "home_drink", "food": "home_food", "pet": "pet_food"}[item.category]
	_record_transaction(kind, -int(item.price), item.name)
	changed.emit()
	_check_ending()
	save_requested.emit()
	return {"ok": true, "reason": ""}


func use_home_item(id: String) -> Dictionary:
	if phase != Phase.HOME:
		return {"ok": false, "reason": "wrong_phase", "category": "", "restore": 0}
	var item: Dictionary = HOME_ITEMS.get_item(id)
	if item.is_empty():
		return {"ok": false, "reason": "unknown_item", "category": "", "restore": 0}
	if int(inventory.get(id, 0)) < 1:
		return {"ok": false, "reason": "not_owned", "category": item.category, "restore": 0}
	if int(item.restore) > 0 and health >= balance.maximum_stat:
		return {"ok": false, "reason": "health_full", "category": item.category, "restore": 0}
	var previous_health := health
	if int(item.restore) > 0:
		health = minf(balance.maximum_stat, health + int(item.restore))
	inventory[id] = int(inventory[id]) - 1
	if inventory[id] == 0:
		inventory.erase(id)
	changed.emit()
	save_requested.emit()
	return {"ok": true, "reason": "", "category": item.category, "restore": health - previous_health}


func drink_coffee() -> bool:
	if phase != Phase.WORK or awaiting_acknowledgement or not coffee_ready or coffee_used_today or publication_limit_reached() or health >= balance.maximum_stat:
		return false
	coffee_ready = false
	coffee_used_today = true
	health = minf(balance.maximum_stat, health + balance.coffee_health_restore)
	changed.emit()
	_check_ending()
	save_requested.emit()
	return true


func combo_multiplier(count: int = -1) -> float:
	var length := combo_count if count < 0 else count
	return minf(balance.combo_max_multiplier, 1.0 + maxi(0, length - 1) * balance.combo_step)


func _record_transaction(kind: String, amount: int, label: String, editorial_type: int = -1, headline: String = "") -> void:
	finances.record(day, kind, amount, label, editorial_type, headline)
	transaction_recorded.emit(finances.entries.back().duplicate())


func publication_stamina_cost() -> float:
	var reduction := balance.reader_support.amount if reputation >= balance.reader_support.threshold else 0.0
	return maxf(0.0, balance.publication_health_cost - reduction)


func _check_ending() -> bool:
	if phase == Phase.ENDED:
		return true
	# Fixed priority for simultaneous losses: health, reputation, loyalty, debt.
	if health <= 0.0:
		ending = Ending.EXHAUSTION
	elif reputation <= 0.0:
		ending = Ending.OFFICE_FIRE
	elif loyalty <= 0.0:
		ending = Ending.ARREST
	elif money <= balance.debt_limit:
		ending = Ending.DEBT
	elif proofreading_unlocked and qualification <= 0.0:
		ending = Ending.QUALIFICATION_FIRED
	else:
		return false
	phase = Phase.ENDED
	awaiting_acknowledgement = false
	phase_changed.emit()
	save_requested.emit()
	return true


func _shuffle_articles() -> void:
	ArticleSequence.shuffle(articles, _rng)


func _shuffle_options() -> void:
	option_order.assign([0, 1, 2])
	for i in range(option_order.size() - 1, 0, -1):
		var other := _rng.randi_range(0, i)
		var previous := option_order[i]
		option_order[i] = option_order[other]
		option_order[other] = previous
