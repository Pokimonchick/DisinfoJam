class_name NewsroomSession
extends RefCounted

signal changed
signal phase_changed
signal article_changed
signal published(result: Dictionary)
signal save_requested

enum Phase { IDLE, WORK, HOME, ENDED }
enum Ending { NONE, EXHAUSTION, OFFICE_FIRE, ARREST, DEBT, VICTORY, GOAL_MISSED }

var balance: NewsroomBalance = preload("res://Data/mvp_balance.tres")
var articles: Array[NewsArticle] = []
var phase: Phase = Phase.IDLE
var ending: Ending = Ending.NONE
var health: float
var reputation: float
var loyalty: float
var money: int
var day: int = 0
var time_left: float = 0.0
var shift_length: float = 0.0
var article_cursor: int = 0
var option_order: Array[int] = []
var coffee_ready: bool = false
var coffee_used_today: bool = false
var food_stocked: bool = false
var combo_type: int = -1
var combo_count: int = 0
var awaiting_acknowledgement: bool = false
var published_today: int = 0
var earned_today: int = 0
var total_published: int = 0
var completed_shifts: int = 0
var journal: Array[Dictionary] = []
var last_shift: Dictionary = {}
var last_result: Dictionary = {}
var player_name: String = "Редактор"
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
	money = balance.starting_money
	day = 0
	time_left = 0.0
	shift_length = 0.0
	article_cursor = 0
	coffee_ready = false
	coffee_used_today = false
	food_stocked = false
	combo_type = -1
	combo_count = 0
	awaiting_acknowledgement = false
	published_today = 0
	earned_today = 0
	total_published = 0
	completed_shifts = 0
	journal.clear()
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
	shift_length = balance.shift_seconds
	coffee_used_today = false
	combo_type = -1
	combo_count = 0
	time_left = shift_length
	published_today = 0
	earned_today = 0
	awaiting_acknowledgement = false
	phase = Phase.WORK
	changed.emit()
	phase_changed.emit()
	article_changed.emit()
	save_requested.emit()


func tick_work(delta: float) -> void:
	if phase != Phase.WORK or delta <= 0.0:
		return
	var elapsed := minf(delta, time_left)
	time_left = maxf(0.0, time_left - elapsed)
	health = maxf(0.0, health - elapsed * balance.health_drain_per_second)
	changed.emit()
	if _check_ending():
		return
	if time_left <= 0.0:
		finish_shift()


func current_article() -> NewsArticle:
	if articles.is_empty():
		return null
	return articles[article_cursor % articles.size()]


func option_at(display_index: int) -> HeadlineOption:
	if display_index < 0 or display_index >= option_order.size():
		return null
	return current_article().headlines[option_order[display_index]]


func publish_headline(display_index: int) -> bool:
	if phase != Phase.WORK or awaiting_acknowledgement or time_left <= 0.0 or publication_limit_reached():
		return false
	var option := option_at(display_index)
	if option == null:
		return false
	awaiting_acknowledgement = true
	combo_count = combo_count + 1 if combo_type == option.editorial_type else 1
	combo_type = option.editorial_type
	var multiplier := combo_multiplier()
	last_result = {
		"article_id": current_article().id,
		"headline": option.text,
		"money": roundi(option.money * multiplier * balance.publication_income_multiplier),
		"reputation": roundi(option.reputation * multiplier),
		"loyalty": roundi(option.loyalty * multiplier),
		"combo_type": combo_type,
		"combo_count": combo_count,
		"multiplier": multiplier,
		"explanation": option.explanation,
		"day": day,
	}
	money += last_result.money
	reputation = clampf(reputation + last_result.reputation, 0.0, balance.maximum_stat)
	loyalty = clampf(loyalty + last_result.loyalty, 0.0, balance.maximum_stat)
	health = maxf(0.0, health - balance.publication_health_cost)
	published_today += 1
	total_published += 1
	earned_today += last_result.money
	journal.append(last_result.duplicate())
	# A published article leaves the queue immediately, even if the shift ends
	# while its feedback is visible. Unconfirmed articles keep their cursor.
	article_cursor += 1
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
	if publication_limit_reached():
		finish_shift()
		return
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
	money -= balance.meal_price if full_meal else balance.snack_price
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
	changed.emit()
	_check_ending()
	save_requested.emit()
	return true


func drink_coffee() -> bool:
	if phase != Phase.WORK or not coffee_ready or coffee_used_today or time_left <= 0.0 or publication_limit_reached():
		return false
	coffee_ready = false
	coffee_used_today = true
	time_left += balance.coffee_bonus_seconds
	shift_length += balance.coffee_bonus_seconds
	health = maxf(0.0, health - balance.coffee_health_cost)
	changed.emit()
	_check_ending()
	save_requested.emit()
	return true


func combo_multiplier(count: int = -1) -> float:
	var length := combo_count if count < 0 else count
	return minf(balance.combo_max_multiplier, 1.0 + maxi(0, length - 1) * balance.combo_step)


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
	else:
		return false
	phase = Phase.ENDED
	awaiting_acknowledgement = false
	phase_changed.emit()
	save_requested.emit()
	return true


func _shuffle_options() -> void:
	option_order.assign([0, 1, 2])
	for i in range(option_order.size() - 1, 0, -1):
		var other := _rng.randi_range(0, i)
		var previous := option_order[i]
		option_order[i] = option_order[other]
		option_order[other] = previous
