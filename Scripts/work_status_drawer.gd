extends Control

signal toggled(value: bool)

const OPEN_X := 0.0
const CLOSED_X := -352.0
const SLIDE_SECONDS := 0.28

var session: NewsroomSession
var expanded := true
var _slide_tween: Tween


func _ready() -> void:
	%TabButton.pressed.connect(_toggle)
	%SlidingPanel.position.x = OPEN_X if expanded else CLOSED_X
	%Arrow.flip_h = not expanded
	_update_tab_tooltip()
	_refresh()


func bind(model: NewsroomSession) -> void:
	if session != null:
		if session.changed.is_connected(_refresh):
			session.changed.disconnect(_refresh)
		if session.phase_changed.is_connected(_refresh):
			session.phase_changed.disconnect(_refresh)
	session = model
	if session != null:
		session.changed.connect(_refresh)
		session.phase_changed.connect(_refresh)
	if is_node_ready():
		_refresh()


func set_expanded(value: bool, animate: bool = true) -> void:
	if expanded == value:
		return
	expanded = value
	if not is_node_ready():
		return
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	%Arrow.flip_h = not expanded
	_update_tab_tooltip()
	var target := OPEN_X if expanded else CLOSED_X
	if animate and is_inside_tree():
		_slide_tween = create_tween()
		_slide_tween.tween_property(%SlidingPanel, "position:x", target, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		%SlidingPanel.position.x = target
	toggled.emit(expanded)


func _toggle() -> void:
	set_expanded(not expanded)


func _update_tab_tooltip() -> void:
	%TabButton.tooltip_text = "Скрыть показатели" if expanded else "Открыть показатели"


func _refresh() -> void:
	if session == null or not is_node_ready():
		return
	%Shift.text = "СМЕНА %02d" % session.day
	%Player.text = NewsroomSession.CAMPAIGN_HERO_NAME
	_set_meter(%HealthBar, %HealthValue, session.health, Color("6b7046"))
	_set_meter(%ReputationBar, %ReputationValue, session.reputation, Color("916038"))
	_set_meter(%LoyaltyBar, %LoyaltyValue, session.loyalty, Color("626648"))
	var support: StatBenefit = session.balance.reader_support
	var support_text := support.ready_text if session.reputation >= support.threshold else support.locked_text
	%ReputationHint.text = support.formatted(support_text)
	%HealthHelp.tooltip_text = preload("res://Scripts/stat_descriptions.gd").text_for("health", session.balance)
	%ReputationHelp.tooltip_text = preload("res://Scripts/stat_descriptions.gd").text_for("reputation", session.balance)
	var approval: StatBenefit = session.balance.state_approval
	var approval_text := approval.locked_text
	if session.phase == NewsroomSession.Phase.WORK and session.approval_stamina_applied:
		approval_text = approval.applied_text
	elif session.loyalty >= approval.threshold:
		approval_text = approval.ready_text
	%LoyaltyHint.text = approval.formatted(approval_text)
	%LoyaltyHelp.tooltip_text = preload("res://Scripts/stat_descriptions.gd").text_for("loyalty", session.balance)
	%MoneyValue.text = "%d $" % session.money
	var money_color := Color("ff9f82") if session.money < 0 else Color("f8e9c7")
	if %MoneyValue.get_theme_color("font_color") != money_color:
		%MoneyValue.add_theme_color_override("font_color", money_color)


func _set_meter(bar: PencilMeter, label: Label, value: float, color: Color) -> void:
	bar.max_value = session.balance.maximum_stat
	bar.value = value
	label.text = "%d / %d" % [ceili(value), int(session.balance.maximum_stat)]
	bar.ink_color = Color("a5462e") if value < 25.0 else color
