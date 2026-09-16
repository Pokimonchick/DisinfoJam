extends Control

var session: NewsroomSession

func _ready() -> void:
	%Meal.pressed.connect(_eat.bind(true))
	%Snack.pressed.connect(_eat.bind(false))
	%Coffee.pressed.connect(_coffee)
	%Bed.pressed.connect(func(): session.start_shift())

func bind(model: NewsroomSession) -> void:
	session = model
	session.changed.connect(refresh)

func open_evening() -> void:
	%Notice.text = "Можно спокойно подумать: вечером здоровье не убывает."
	refresh()
	%Bed.grab_focus()

func refresh() -> void:
	if session == null or session.phase != NewsroomSession.Phase.HOME:
		return
	var b := session.balance
	%Summary.text = "Смена %d закончена. Напечатано: %d.\nЗаработано: %d $  ·  Аренда списана: %d $." % [session.day, session.published_today, session.earned_today, b.rent]
	%Queue.text = "На завтра: «%s». Очередь продолжается с этого материала." % session.current_article().source_title
	%Meal.text = "ГОРЯЧИЙ УЖИН\n%d $  ·  +%d здоровья" % [b.meal_price, int(b.meal_health)]
	%Snack.text = "ПЕРЕКУС\n%d $  ·  +%d здоровья" % [b.snack_price, int(b.snack_health)]
	%Coffee.text = "КОФЕ НА ЗАВТРА\n%d $  ·  −%d здоровья, +%d сек." % [b.coffee_price, int(b.coffee_health_cost), int(b.coffee_bonus_seconds)]
	%Meal.disabled = session.health >= b.maximum_stat
	%Snack.disabled = session.health >= b.maximum_stat
	%Coffee.disabled = session.coffee_ready
	if session.coffee_ready:
		%Coffee.text = "КОФЕ КУПЛЕН\nСледующая смена — %d минут" % int((b.shift_seconds + b.coffee_bonus_seconds) / 60)
	%Bed.text = "ЛЕЧЬ СПАТЬ → СМЕНА %d" % (session.day + 1)
	%Hero.health_ratio = session.health / b.maximum_stat
	%Condition.text = "Ещё держусь." if session.health >= 40 else "Нужно поесть. До истощения осталось мало сил."
	%DebtHint.text = "Можно покупать в долг. При балансе %d $ или ниже — конец игры. Сон завершает вечер и не восстанавливает здоровье." % b.debt_limit
	if not session.last_result.is_empty():
		%LastResult.text = "Последняя публикация: %+d $ / репутация %+d / государство %+d." % [session.last_result.money, session.last_result.reputation, session.last_result.loyalty]
		%LastResult.tooltip_text = session.last_result.explanation
	else:
		%LastResult.text = "Сегодня ещё ничего не опубликовано. Завтра источники продолжат ждать на столе."

func _eat(full_meal: bool) -> void:
	if session.buy_food(full_meal):
		%Notice.text = "Ужин съеден. Здоровье восстановлено." if full_meal else "Перекус помог. Можно отдохнуть или поесть ещё."

func _coffee() -> void:
	if session.buy_coffee():
		%Notice.text = "Кофе куплен: следующая смена дольше. Здоровье уменьшилось сразу."
