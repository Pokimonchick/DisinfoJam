extends HBoxContainer

var session: NewsroomSession

func bind(model: NewsroomSession) -> void:
	session = model
	session.changed.connect(refresh)
	session.phase_changed.connect(refresh)
	for bar: ProgressBar in [%Health, %Reputation, %Loyalty]:
		bar.add_theme_stylebox_override("fill", preload("res://Scripts/mvp_theme.gd").box(Color.WHITE, 5, 0))
	refresh()

func refresh() -> void:
	if session == null:
		return
	_set_meter(%Health, %HealthValue, session.health, Color("b6c995"))
	_set_meter(%Reputation, %ReputationValue, session.reputation, Color("79bec1"))
	_set_meter(%Loyalty, %LoyaltyValue, session.loyalty, Color("c4a3d3"))
	%Money.text = "%d $" % session.money
	%Money.add_theme_color_override("font_color", Color("ed987e") if session.money < 0 else Color("e8bd68"))
	%Day.text = "СМЕНА %02d" % session.day
	var seconds := ceili(session.time_left)
	var working := session.phase == NewsroomSession.Phase.WORK
	%Clock.text = "%02d:%02d" % [seconds / 60, seconds % 60] if working else ("ФИНАЛ" if session.phase == NewsroomSession.Phase.ENDED else "ВЕЧЕР")
	%Clock.add_theme_color_override("font_color", Color("e85b57") if working and session.time_left <= 10.0 else Color("eee4cc"))
	%TimerRing.progress = session.time_left / session.shift_length if working and session.shift_length > 0.0 else 0.0
	%TimerRing.urgent = working and session.time_left <= 10.0

func _set_meter(bar: ProgressBar, label: Label, value: float, color: Color) -> void:
	bar.max_value = session.balance.maximum_stat
	bar.value = value
	label.text = "%d / %d" % [ceili(value), int(session.balance.maximum_stat)]
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color("e18c65") if value < 25 else color
