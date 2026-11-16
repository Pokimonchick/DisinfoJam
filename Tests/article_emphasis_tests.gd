extends SceneTree

const EMPHASIS = preload("res://Scripts/article_emphasis.gd")
const FONTS = preload("res://Scripts/game_fonts.gd")
const CATALOG = preload("res://Data/article_catalog.gd")
const STORIES = preload("res://Data/story_chains.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var desk := Control.new()
	desk.size = Vector2(1280, 720)
	root.add_child(desk)
	var label := RichTextLabel.new()
	label.position = Vector2(80, 60)
	label.size = Vector2(800, 300)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("normal_font", FONTS.BODY)
	label.add_theme_font_size_override("normal_font_size", 28)
	desk.add_child(label)
	var pager = preload("res://Scenes/source_pager.tscn").instantiate()
	desk.add_child(pager)
	pager.bind(label)
	await process_frame

	for article in CATALOG.create_articles():
		var sources: Array = [article.source_text]
		if STORIES.VARIANTS.has(article.id):
			sources.append_array(STORIES.VARIANTS[article.id].values())
		for source: String in sources:
			var ranges := EMPHASIS.ranges_for(article.id, source)
			check(not ranges.is_empty(), article.id + " has relevant emphasis in each source variant")
			pager.set_source(source, article.id, source)
			var reconstructed := ""
			for span: Vector2i in pager._pages:
				reconstructed += source.substr(span.x, span.y - span.x)
				pager.go_to_character(span.x)
				var visible: String = source.substr(span.x, span.y - span.x)
				while visible.begins_with("\n") or visible.begins_with("\r"):
					visible = visible.substr(1)
				while visible.ends_with("\n") or visible.ends_with("\r"):
					visible = visible.substr(0, visible.length() - 1)
				check(label.get_parsed_text() == visible, article.id + " retains plain source characters while paging")
				check(label.get_content_height() <= label.size.y, article.id + " styled page fits without clipped lines")
				for index in label.get_line_count():
					var line := label.get_line_range(index)
					var end := mini(line.y, visible.length())
					while end > line.x and visible[end - 1] in ["\n", "\r"]:
						end -= 1
					var shape := EMPHASIS.shape_line(label, visible, line.x, end)
					check(absf(shape.get_line_width() - label.get_line_width(index)) < 3.0, article.id + " mixed-font geometry matches the visible line")
			check(reconstructed == source, article.id + " pagination never drops source characters")

	# Inserting a letter before and inside a bold fact must move its boundaries,
	# while the scoring geometry still recognises a mark over the displayed typo.
	var source := "письмо. Уже пятый вечер у нашей двери сидит чёрный кот. В полицию не обращалась."
	var typo_at := source.find("пятый")
	var state := ProofreadingState.new()
	state.article_id = "black_cat"
	state.source_text = source
	state.display_text = "писзьмо" + source.substr(6, typo_at - 6) + "пятный" + source.substr(typo_at + 5)
	state.targets = [
		{"id": 0, "start": 0, "source_start": 0, "length": 7, "original": "письмо", "typo": "писзьмо"},
		{"id": typo_at + 1, "start": typo_at + 1, "source_start": typo_at, "length": 6, "original": "пятый", "typo": "пятный"}
	]
	pager.set_source(state.display_text, state.article_id, source, state.targets)
	var ranges: Array = label.get_meta(EMPHASIS.PAGE_RANGES)
	check(state.display_text.substr(ranges[0].start, ranges[0].end - ranges[0].start) == "Уже пятный вечер у нашей двери сидит чёрный кот.", "Emphasis offsets follow inserted typo letters")
	var surface := ProofreadingSurface.new()
	surface.size = desk.size
	desk.add_child(surface)
	surface.bind(label, state, 0)
	surface.drawing_enabled = true
	await process_frame
	await process_frame
	var marked := false
	for word in surface._words:
		if int(word.start) != typo_at + 1:
			continue
		var rect: Rect2 = word.rects[0]
		var a := label.get_global_transform_with_canvas() * (rect.get_center() - Vector2(5, 0))
		var b := label.get_global_transform_with_canvas() * (rect.get_center() + Vector2(5, 0))
		marked = surface.begin_stroke(a)
		surface.extend_stroke(b)
		surface.finish_stroke()
		break
	check(marked, "A pencil stroke can target a typo inside bold text")
	var evaluation = surface.create_evaluation(pager.page_ranges())
	while not evaluation.advance():
		await process_frame
	check(evaluation.counts.corrected == 1 and evaluation.counts.wrong == 0, "Publication recognises the bold typo without false corrections")
	evaluation.dispose()
	EMPHASIS.render(label, "Обычная статья без акцентов.", [])
	check(label.get_parsed_text() == "Обычная статья без акцентов." and label.get_meta(EMPHASIS.PAGE_RANGES).is_empty(), "Changing articles clears previous emphasis")
	_migration_checks()
	desk.queue_free()
	await process_frame
	print("ARTICLE_EMPHASIS_CHECKS: ", checks, " passed: ", checks - failures, " failed: ", failures)
	quit(1 if failures else 0)

func _previous(article: NewsArticle) -> NewsArticle:
	var copy := NewsArticle.from_row(article.to_row())
	copy.source_text = preload("res://Docs/OriginalArticles/authored_prose_before_shortening.gd").TEXTS[article.id]
	return copy

func _migration_checks() -> void:
	var articles: Array[NewsArticle] = []
	for article in CATALOG.create_articles():
		if article.provenance.get("author") == "Codex":
			articles.append(article)
	var session := NewsroomSession.new()
	for index in 5:
		session.articles.append(_previous(articles[index]))
	var pinned := session.articles[0].to_row()
	session.articles[2].source_text += " Ручная правка."
	var custom := session.articles[2].to_row()
	session.articles[3].headlines[0].money += 1
	var custom_balance := session.articles[3].to_row()
	session.journal.append({"article_id": articles[4].id})
	var published := session.articles[4].to_row()
	var legacy := NewsArticle.from_row(preload("res://Docs/OriginalArticles/article_catalog_before_lively.gd").ROWS[5])
	session.articles.append(legacy)
	NewsroomSaveData._migrate_authored_prose(session)
	check(session.articles[0].to_row() == pinned, "Shortening migration preserves the current draft and its offsets")
	check(session.articles[1].source_text == articles[1].source_text, "Untouched future prose receives the shortened source")
	check(session.articles[2].to_row() == custom and session.articles[3].to_row() == custom_balance, "Manual prose and balance edits survive migration")
	check(session.articles[4].to_row() == published, "Published materials are never replaced")
	check(session.articles[5].source_text == articles[5].source_text, "Pre-lively saves also receive the current prose")
