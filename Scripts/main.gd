extends Node2D

var article_pairs = [
	{
		"left": {
			"headline": "МЭР ПРИЗНАЛСЯ: ГОРОДОМ УПРАВЛЯЮТ КОТЫ",
			"body": "По словам очевидцев, заседания администрации сопровождаются подозрительным мяуканьем."
		},
		"right": {
			"headline": "ВЛАСТИ ОПРОВЕРГЛИ СЛУХИ О КОТАХ В МЭРИИ",
			"body": "Представители администрации заявили, что информация не имеет подтверждений."
		}
	},
	{
		"left": {
			"headline": "УЧЁНЫЕ ОБНАРУЖИЛИ ВОДУ, КОТОРАЯ НЕ МОЧИТ",
			"body": "Исследователи обещают представить доказательства позднее."
		},
		"right": {
			"headline": "УЧЁНЫЕ НАЗВАЛИ СЛУХИ О СУХОЙ ВОДЕ ВЫДУМКОЙ",
			"body": "Научное сообщество не обнаружило подтверждений сенсации."
		}
	}
]

var current_pair_index := 0

@onready var left_article = $GameUI/Desk/CenterContainer/HBoxContainer/LeftArticle
@onready var right_article = $GameUI/Desk/CenterContainer/HBoxContainer/RightArticle

func _ready() -> void:
	left_article.selected.connect(_on_left_article_selected)
	right_article.selected.connect(_on_right_article_selected)
	show_current_pair()

func show_current_pair() -> void:
	var pair = article_pairs[current_pair_index]
	
	left_article.setup(
		pair["left"]["headline"],
		pair["left"]["body"]
	)

	right_article.setup(
		pair["right"]["headline"],
		pair["right"]["body"]
	)

func next_pair() -> void:
	current_pair_index += 1
	
	if current_pair_index < article_pairs.size():
		show_current_pair()
	else:
		print("Все пары закончились")

func _on_left_article_selected() -> void:
	print("Выбрана левая статья")
	next_pair()

func _on_right_article_selected() -> void:
	print("Выбрана правая статья")
	next_pair()
