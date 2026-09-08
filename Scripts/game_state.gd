extends Node


var society_points: int = 0
var day_1_completed: bool = false
var day_2_completed: bool = false

func complete_day_1(score_change: int) -> void:
	if day_1_completed:
		return

	day_1_completed = true
	society_points += score_change

func complete_day_2(score_change: int) -> void:
	if day_2_completed:
		return

	day_2_completed = true
	society_points += score_change
