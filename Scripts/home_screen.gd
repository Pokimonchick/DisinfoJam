extends Control

var session: NewsroomSession
var _sleep_left := 0.0
@onready var room: Control = %RoomView

func _ready() -> void:
	%Meal.pressed.connect(_eat.bind(true))
	%Snack.pressed.connect(_eat.bind(false))
	%Coffee.pressed.connect(_coffee)
	%Bed.pressed.connect(_sleep)
	for pair in [[%Bed, "bed"], [%Coffee, "coffee"], [%Meal, "fridge"]]:
		var button: Button = pair[0]
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.mouse_entered.connect(_hover.bind(pair[1]))
		button.mouse_exited.connect(_hover.bind(""))
		button.focus_entered.connect(_hover.bind(pair[1]))
		button.focus_exited.connect(_hover.bind(""))

func bind(model: NewsroomSession) -> void:
	session = model
	session.changed.connect(refresh)

func open_evening() -> void:
	_sleep_left = 0.0
	room.sleeping = false
	room.hovered = ""
	%Notice.text = "Наконец-то дома. Наведите на холодильник, чашку или кровать."
	refresh()

func refresh() -> void:
	if session == null or session.phase != NewsroomSession.Phase.HOME:
		return
	var b := session.balance
	%Summary.text = "ДОМА  /  СМЕНА %02d     Напечатано: %d  ·  Доход: %d $  ·  Аренда: −%d $" % [session.day, session.published_today, session.earned_today, b.rent]
	%BedCaption.text = "КРОВАТЬ\nСон → смена %d" % (session.day + 1)
	%CoffeeCaption.text = "КОФЕ · %d $\nВзять с собой: +%d сек. на смене" % [b.coffee_price, int(b.coffee_bonus_seconds)]
	if session.coffee_ready:
		%CoffeeCaption.text = "КОФЕ УПАКОВАН\nЧашка ждёт на рабочем столе"
	%MealCaption.text = "ХОЛОДИЛЬНИК · %d $\nПоесть: +%d выносливости" % [b.meal_price, int(b.meal_health)]
	if session.health >= b.maximum_stat:
		%MealCaption.text = "ХОЛОДИЛЬНИК\nВы сыты"
	%Snack.text = "Перекус: %d $ / +%d сил" % [b.snack_price, int(b.snack_health)]
	%Meal.tooltip_text = "Купить еду и поесть: %d $, +%d выносливости" % [b.meal_price, int(b.meal_health)]
	%Coffee.tooltip_text = "Одна чашка с собой. Выпить на работе: +%d сек., −%d выносливости." % [int(b.coffee_bonus_seconds), int(b.coffee_health_cost)]
	%Meal.disabled = session.health >= b.maximum_stat or _sleep_left > 0
	%Snack.disabled = %Meal.disabled
	%Coffee.disabled = session.coffee_ready or _sleep_left > 0
	%Bed.disabled = _sleep_left > 0
	room.food_stocked = session.food_stocked
	room.coffee_packed = session.coffee_ready
	room.tired = session.health < 40
	%DebtHint.text = "Покупки в долг разрешены до %d $. Сон завершает вечер и не восстанавливает силы.\nНепотраченный кофе остаётся с вами до следующей смены." % b.debt_limit
	room.queue_redraw()

func _hover(target: String) -> void:
	room.hovered = target

func _eat(full_meal: bool) -> void:
	if _sleep_left <= 0 and session.buy_food(full_meal):
		%Notice.text = "В холодильнике появились продукты. Вы поели и восстановили силы."

func _coffee() -> void:
	if _sleep_left <= 0 and session.buy_coffee():
		%Notice.text = "Чашка упакована. На смене нажмите на кофе, когда понадобится ещё минута."

func _sleep() -> void:
	if session.phase != NewsroomSession.Phase.HOME or _sleep_left > 0:
		return
	_sleep_left = 0.85
	room.sleeping = true
	room.hovered = ""
	%Notice.text = "Тихой ночи. Завтра снова в редакцию…"
	refresh()

# The controller advances sleep only while home is visible and unpaused.
func tick_home(delta: float) -> void:
	if _sleep_left <= 0 or session.phase != NewsroomSession.Phase.HOME:
		return
	_sleep_left = maxf(0, _sleep_left - delta)
	if _sleep_left <= 0:
		session.start_shift()
