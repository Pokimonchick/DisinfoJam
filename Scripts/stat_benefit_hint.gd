class_name StatBenefitHint
extends HBoxContainer

enum State { LOCKED, READY, APPLIED }


func present(benefit: StatBenefit, state: State) -> void:
	var template := benefit.locked_text
	if state == State.READY:
		template = benefit.ready_text
	elif state == State.APPLIED:
		template = benefit.applied_text
	%Caption.text = benefit.formatted(template)
	%Caption.add_theme_color_override("font_color", Color("eee4cc") if state != State.LOCKED else Color("8d9797"))
