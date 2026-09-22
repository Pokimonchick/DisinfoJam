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
	for i in row.options.size():
		var option := HeadlineOption.from_row(row.options[i])
		# The original catalog is authored as facts / sensation / state support.
		# New stories specify the type explicitly in the sixth column.
		if row.options[i].size() <= 5:
			option.editorial_type = i
		article.headlines.append(option)
	return article
