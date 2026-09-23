class_name NewsArticle
extends Resource

@export var id: String = ""
@export var source_title: String = ""
@export_multiline var source_text: String = ""
@export var high_risk: bool = false
@export var headlines: Array[HeadlineOption] = []
## Optional provenance for future generated material (provider, generation ID, etc.).
@export var provenance: Dictionary = {}

static func from_row(row: Dictionary) -> NewsArticle:
	var article := NewsArticle.new()
	article.id = row.id
	article.source_title = row.source
	article.source_text = row.text
	article.high_risk = row.get("high_risk", false)
	article.provenance = row.get("provenance", {}).duplicate(true)
	for i in row.options.size():
		var option := HeadlineOption.from_row(row.options[i])
		# The original catalog is authored as facts / sensation / state support.
		# New stories specify the type explicitly in the sixth column.
		if row.options[i].size() <= 5:
			option.editorial_type = i
		article.headlines.append(option)
	return article

func to_row() -> Dictionary:
	var options: Array = []
	for option in headlines:
		options.append([option.text, option.money, option.reputation, option.loyalty, option.explanation, option.editorial_type])
	return {"id": id, "source": source_title, "text": source_text, "high_risk": high_risk,
		"options": options, "provenance": provenance.duplicate(true)}
