class_name StatBenefit
extends Resource

@export_range(0.0, 100.0, 1.0) var threshold: float = 75.0
@export_range(0.0, 180.0, 0.5) var amount: float = 1.0
@export var locked_text: String = ""
@export var ready_text: String = ""
@export var applied_text: String = ""
@export_multiline var explanation: String = ""


func formatted(template: String) -> String:
	return template.format({"threshold": int(threshold), "amount": str(roundi(amount))})
