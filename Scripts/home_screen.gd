extends Control

signal pause_requested

const DESIGN_SIZE := Vector2(1920, 1080)
const NIKOLA_POSITION := Vector2(942, 616)

var session: NewsroomSession
var _sleep_left := 0.0
var _idle_clock := 0.0
var _feedback_tween: Tween

@onready var design: Control = $Design
@onready var room: Control = %RoomView


func _process(delta: float) -> void:
	if session != null and session.phase == NewsroomSession.Phase.HOME and _sleep_left <= 0:
		_idle_clock += delta
		%Nikola.position.y = NIKOLA_POSITION.y + sin(_idle_clock * 2.0) * 2.0


func _ready() -> void:
	resized.connect(_fit_design)
	_fit_design()
	%Meal.pressed.connect(_eat.bind(true))
	%Snack.pressed.connect(_eat.bind(false))
	%Coffee.pressed.connect(_coffee)
	%Bed.pressed.connect(_sleep)
	%Pause.pressed.connect(func(): pause_requested.emit())
	for pair in [[%Bed, "bed"], [%Coffee, "coffee"], [%Snack, "snack"], [%Meal, "fridge"]]:
		var button: Button = pair[0]
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.mouse_entered.connect(_hover.bind(pair[1]))
		button.mouse_exited.connect(_hover.bind(""))
		button.focus_entered.connect(_hover.bind(pair[1]))
		button.focus_exited.connect(_hover.bind(""))


func _fit_design() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	design.size = DESIGN_SIZE
	design.scale = Vector2.ONE * factor
	design.position = (size - DESIGN_SIZE * factor) * 0.5


func bind(model: NewsroomSession) -> void:
	session = model
	session.changed.connect(refresh)


func open_evening() -> void:
	_sleep_left = 0.0
	_idle_clock = 0.0
	room.sleeping = false
	room.hovered = ""
	%Nikola.position = NIKOLA_POSITION
	%Nikola.modulate.a = 1.0
	%SleepShade.modulate.a = 0.0
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	%Feedback.hide()
	refresh()


func refresh() -> void:
	if session == null or session.phase != NewsroomSession.Phase.HOME:
		return
	var b := session.balance
	_set_meter(%HealthGroup, session.health, Color("af8d54"))
	_set_meter(%ReputationGroup, session.reputation, Color("927048"))
	_set_meter(%LoyaltyGroup, session.loyalty, Color("75805b"))
	%HealthGroup.tooltip_text = "Выносливость. Во время работы силы убывают; сон восстановит до %d." % int(b.sleep_health)
	var support: StatBenefit = b.reader_support
	%ReputationGroup.tooltip_text = "%s\n%s" % [support.formatted(support.ready_text if session.reputation >= support.threshold else support.locked_text), support.formatted(support.explanation)]
	var approval: StatBenefit = b.state_approval
	%LoyaltyGroup.tooltip_text = "%s\n%s" % [approval.formatted(approval.ready_text if session.loyalty >= approval.threshold else approval.locked_text), approval.formatted(approval.explanation)]
	%MoneyGroup/Value.text = "%d $" % session.money
	%MoneyGroup/Value.add_theme_color_override("font_color", Color("e98f70") if session.money < 0 else Color("e8bd68"))
	%MoneyGroup.tooltip_text = "Баланс после аренды. Покупки в долг разрешены до −%d $." % b.debt_limit
	%Evening.text = "ВЕЧЕР %02d" % session.day
	%Evening.tooltip_text = "Смена %d: напечатано %d · доход %d $ · аренда −%d $." % [session.day, session.published_today, session.earned_today, b.rent]
	%Bed.tooltip_text = "Лечь спать → смена %d. Сон восстановит до %d выносливости." % [session.day + 1, int(b.sleep_health)]
	%Coffee.tooltip_text = "Кофе уже куплен. Невыпитая чашка останется на следующую смену." if session.coffee_ready else "Купить кофе за %d $. На смене: +%d сек., −%d выносливости." % [b.coffee_price, int(b.coffee_bonus_seconds), int(b.coffee_health_cost)]
	%Meal.tooltip_text = "Вы сыты." if session.health >= b.maximum_stat else "Поесть у холодильника за %d $: +%d выносливости." % [b.meal_price, int(b.meal_health)]
	%Snack.tooltip_text = "Вы сыты." if session.health >= b.maximum_stat else "Перекусить за %d $: +%d выносливости." % [b.snack_price, int(b.snack_health)]
	%Meal.disabled = session.health >= b.maximum_stat or _sleep_left > 0
	%Snack.disabled = %Meal.disabled
	%Coffee.disabled = session.coffee_ready or _sleep_left > 0
	%Bed.disabled = _sleep_left > 0
	room.food_stocked = session.food_stocked
	room.coffee_packed = session.coffee_ready
	room.tired = session.health < 40
	%CoffeeArt.visible = not session.coffee_ready
	room.queue_redraw()


func _set_meter(group: Control, value: float, color: Color) -> void:
	var meter := group.get_node("Meter") as PencilMeter
	meter.max_value = session.balance.maximum_stat
	meter.value = value
	meter.ink_color = Color("a5462e") if value < 25.0 else color
	(group.get_node("Value") as Label).text = "%d / %d" % [ceili(value), int(session.balance.maximum_stat)]


func _hover(target: String) -> void:
	room.hovered = target


func _show_feedback(message: String) -> void:
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	%Feedback/Text.text = message
	%Feedback.modulate.a = 1.0
	%Feedback.show()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(2.2)
	_feedback_tween.tween_property(%Feedback, "modulate:a", 0.0, 0.25)
	_feedback_tween.tween_callback(%Feedback.hide)


func _eat(full_meal: bool) -> void:
	if _sleep_left <= 0 and session.buy_food(full_meal):
		_show_feedback("Вы поели и восстановили силы.")


func _coffee() -> void:
	if _sleep_left <= 0 and session.buy_coffee():
		_show_feedback("Кофе взят с собой. Выпейте его на смене.")


func _sleep() -> void:
	if session.phase != NewsroomSession.Phase.HOME or _sleep_left > 0:
		return
	_sleep_left = 0.85
	room.sleeping = true
	room.hovered = ""
	var sleep_tween := create_tween().set_parallel(true)
	sleep_tween.tween_property(%Nikola, "position:x", 730.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	sleep_tween.tween_property(%Nikola, "modulate:a", 0.0, 0.7)
	sleep_tween.tween_property(%SleepShade, "modulate:a", 0.85, 0.85)
	_show_feedback("Спокойной ночи…")
	refresh()


# The controller advances sleep only while home is visible and unpaused.
func tick_home(delta: float) -> void:
	if _sleep_left <= 0 or session.phase != NewsroomSession.Phase.HOME:
		return
	_sleep_left = maxf(0, _sleep_left - delta)
	if _sleep_left <= 0:
		session.start_shift()
