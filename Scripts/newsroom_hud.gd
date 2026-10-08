extends HBoxContainer

var session: NewsroomSession

func bind(model: NewsroomSession) -> void:
	session = model
	session.changed.connect(refresh)
	session.phase_changed.connect(refresh)
	for bar: ProgressBar in [%Health, %Reputation, %Loyalty, %Qualification]:
		bar.add_theme_stylebox_override("fill", preload("res://Scripts/mvp_theme.gd").box(Color.WHITE, 5, 0))
	refresh()

func refresh() -> void:
	if session == null:
		return
	_set_meter(%Health, %HealthValue, session.health, Color("b6c995"))
	_set_meter(%Reputation, %ReputationValue, session.reputation, Color("79bec1"))
	_set_meter(%Loyalty, %LoyaltyValue, session.loyalty, Color("c4a3d3"))
	%QualificationGroup.visible = session.proofreading_unlocked
	if %QualificationGroup.visible:
		_set_meter(%Qualification, %QualificationValue, session.qualification, Color("a6afd0"))
	%QualificationHelp.tooltip_text = preload("res://Scripts/stat_descriptions.gd").text_for("qualification", session.balance)
	%HealthHelp.tooltip_text = preload("res://Scripts/stat_descriptions.gd").text_for("health", session.balance)
	%ReputationHelp.tooltip_text = preload("res://Scripts/stat_descriptions.gd").text_for("reputation", session.balance)
	%LoyaltyHelp.tooltip_text = preload("res://Scripts/stat_descriptions.gd").text_for("loyalty", session.balance)
	%ReputationHint.present(session.balance.reader_support,
		StatBenefitHint.State.READY if session.reputation >= session.balance.reader_support.threshold else StatBenefitHint.State.LOCKED)
	var approval_state := StatBenefitHint.State.LOCKED
	if session.phase == NewsroomSession.Phase.WORK and session.approval_stamina_applied:
		approval_state = StatBenefitHint.State.APPLIED
	elif session.loyalty >= session.balance.state_approval.threshold:
		approval_state = StatBenefitHint.State.READY
	%LoyaltyHint.present(session.balance.state_approval, approval_state)
	%Money.text = "%d $" % session.money
	var money_color := Color("a5c38d") if session.money > 0 else (Color("c58a80") if session.money < 0 else Color("d7cdb8"))
	if %Money.get_theme_color("font_color") != money_color:
		%Money.add_theme_color_override("font_color", money_color)
	%Day.text = "СМЕНА %02d" % session.day
	%Period.text = "РАБОТА" if session.phase == NewsroomSession.Phase.WORK else ("ФИНАЛ" if session.phase == NewsroomSession.Phase.ENDED else "ВЕЧЕР")

func _set_meter(bar: ProgressBar, label: Label, value: float, color: Color) -> void:
	bar.max_value = session.balance.maximum_stat
	bar.value = value
	label.text = "%d / %d" % [ceili(value), int(session.balance.maximum_stat)]
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	var fill_color := Color("e18c65") if value < 25 else color
	if fill.bg_color != fill_color:
		fill.bg_color = fill_color
