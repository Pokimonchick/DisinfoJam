extends SceneTree

var failures := 0
var checks := 0
const MIGRATION = preload("res://Data/legacy_article_balance.gd")

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var articles := preload("res://Data/article_catalog.gd").create_articles()
	check(articles.size() == 32, "All authored articles remain")
	var archive: NewsArticle
	for article in articles:
		if article.id == "archive":
			archive = article
		for option in article.headlines:
			check(option.reputation >= -12 and option.loyalty >= -10, "Restrained base penalties: " + article.id)
	check(archive.headlines[1].reputation == -12 and archive.headlines[1].loyalty == -10, "Archive false accusation affects trust and state response")
	for article in articles:
		for i in article.headlines.size():
			article.headlines[i].reputation = MIGRATION.ORIGINAL_EFFECTS[article.id][i][0]
			article.headlines[i].loyalty = MIGRATION.ORIGINAL_EFFECTS[article.id][i][1]
	check(MIGRATION.apply(articles) > 0, "Original authored effects migrate")
	check(MIGRATION.apply(articles) == 0, "Migration is idempotent")
	check(archive.headlines[1].reputation == -12, "Archive migrates")
	var custom := NewsArticle.from_row(archive.to_row())
	custom.headlines[1].reputation = -37
	custom.headlines[1].loyalty = -30
	var candidates: Array[NewsArticle] = [custom]
	custom.provenance = {"provider": "custom"}
	check(MIGRATION.apply(candidates) == 0, "Generated provenance preserved")
	custom.provenance = {}
	custom.source_text += " custom"
	check(MIGRATION.apply(candidates) == 0, "Edited source preserved")
	custom.source_text = archive.source_text
	custom.headlines[1].money += 1
	check(MIGRATION.apply(candidates) == 0, "Edited money preserved")
	custom.headlines[1].money = archive.headlines[1].money
	custom.headlines[1].reputation = -36
	check(MIGRATION.apply(candidates) == 0, "Edited effect preserved")
	custom.headlines[1].reputation = -37
	custom.headlines[1].text += " custom"
	check(MIGRATION.apply(candidates) == 0, "Edited headline preserved")
	print("ARTICLE BALANCE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
