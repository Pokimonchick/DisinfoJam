class_name NewsArticle
extends Resource

@export var id: String = ""
@export var source_title: String = ""
@export_multiline var source_text: String = ""
@export var high_risk: bool = false
@export var headlines: Array[HeadlineOption] = []

static func from_row(row: Dictionary) -> NewsArticle:
	var article := NewsArticle.new()
	article.id = row.id
	article.source_title = row.source
	article.source_text = row.text
	article.high_risk = row.get("high_risk", false)
	for option_row: Array in row.options:
		article.headlines.append(HeadlineOption.from_row(option_row))
	return article
