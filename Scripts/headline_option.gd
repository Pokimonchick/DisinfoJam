class_name HeadlineOption
extends Resource

@export_multiline var text: String = ""
@export var money: int = 0
@export var reputation: int = 0
@export var loyalty: int = 0
@export_multiline var explanation: String = ""

static func from_row(row: Array) -> HeadlineOption:
	var option := HeadlineOption.new()
	option.text = row[0]
	option.money = row[1]
	option.reputation = row[2]
	option.loyalty = row[3]
	option.explanation = row[4]
	return option
