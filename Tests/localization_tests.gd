extends SceneTree

var checks := 0
var failures := 0
var test_path := "user://localization_tests_%d/campaign.json" % Time.get_ticks_usec()
var _settings_existed := false
var _settings_bytes := PackedByteArray()
var _original_language := "ru"

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _capture(caption: String) -> void:
	if "--captures" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("disinfo-en-" + caption + ".png"))

func _run() -> void:
	var settings := root.get_node("GameSettings")
	_original_language = settings.language
	_settings_existed = FileAccess.file_exists(settings.SETTINGS_PATH)
	if _settings_existed:
		_settings_bytes = FileAccess.get_file_as_bytes(settings.SETTINGS_PATH)
	settings.set_language("ru")
	_check_catalogs()
	var state := root.get_node("GameState")
	state.save_store = SaveRepository.new(test_path)
	state.session = NewsroomSession.new()
	state.session.balance = NewsroomBalance.new()
	state.session.reset(42)
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await create_timer(0.3).timeout
	game._open_settings()
	var selector: OptionButton = game.settings_panel.get_node("%Language")
	check(selector.item_count == 2 and selector.get_item_text(0) == "Русский" and selector.get_item_text(1) == "English", "Language choices remain readable in either locale")
	selector.item_selected.emit(1)
	check(settings.language == "en" and TranslationServer.get_locale() == "en", "Settings selector applies English")
	var config := ConfigFile.new()
	config.load(settings.SETTINGS_PATH)
	check(config.get_value("interface", "language", "") == "en", "Language preference persists independently of the campaign")
	await _capture("settings")
	game.settings_panel.close()
	await _capture("menu")
	game._new_run(false)
	await create_timer(0.25).timeout
	check(game.get_node("%NarrativeTitle").text == "You Have to Start Somewhere", "Story title is translated")
	check(not _has_cyrillic(game._dialogue_body) and game._story_page == 0, "Story body is English and keeps its episode page")
	game.get_node("%NarrativeBody").finish_reveal()
	await _capture("story")
	settings.set_language("ru")
	check(_has_cyrillic(game._dialogue_body) and game._story_page == 0, "Switching back restores Russian story without advancing")
	game._new_run(true)
	await create_timer(0.25).timeout
	var session: NewsroomSession = game.session
	session.combo_count = 3
	session.combo_type = 0
	game.work._refresh_desk()
	settings.set_language("en")
	check(not _has_cyrillic(game.work.source_pager.source_text), "Live desk source is English")
	check(game.work.get_node("%ComboDetail").text == "FACTS · 3 IN A ROW", "Combo cache refreshes for English")
	for card in game.work.cards:
		check(not _has_cyrillic(card.get_node("Content/Headline").text), "Headline options are translated")
	check(_has_cyrillic(session.articles[0].source_text), "Canonical saved content remains Russian")
	await _capture("desk")
	settings.set_language("ru")
	check(_has_cyrillic(game.work.source_pager.source_text) and game.work.get_node("%ComboDetail").text.contains("ПОДРЯД"), "Desk and unchanged combo switch back")
	settings.set_language("en")
	session.publish_headline(0)
	game.work._show_result(session.last_result)
	await create_timer(0.85).timeout
	var result_rect: Rect2 = game.work.popup.get_rect()
	check(Rect2(Vector2.ZERO, game.work.popup.get_parent().size).encloses(result_rect), "English result stays inside the viewport")
	check(not _has_cyrillic(game.work.popup.get_node("%Body").text), "Publication result includes translated explanation and deltas")
	check(not _has_cyrillic(game.work.popup.get_node("%Title").text), "Published headline is translated")
	await _capture("result")
	settings.set_language("ru")
	check(_has_cyrillic(game.work.popup.get_node("%Body").text), "Saved publication result switches back")
	session.acknowledge_publication()
	session.finish_shift()
	await create_timer(0.25).timeout
	settings.set_language("en")
	game.home._open_shop()
	var panels: Control = game.home._panels
	var item: Dictionary = preload("res://Data/home_items.gd").ROWS[0]
	panels._show_item(item)
	check(not _has_cyrillic(panels._detail_title.text) and not _has_cyrillic(panels._detail_description.text), "Shop item and description are translated")
	check(panels._action.text == "Buy" and panels._action.tr(panels._action.text) == "Buy", "English home captions do not fall back to Russian")
	await _capture("shop")
	settings.set_language("ru")
	check(_has_cyrillic(panels._detail_title.text) and _has_cyrillic(panels._detail_description.text), "Open item switches back without losing its selection")
	check(panels._selected.id == item.id, "Language changes retain selected home item")
	var day_label: Label = game.home.get_node("%Day")
	check(day_label.get_theme_font("font").get_string_size(day_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, day_label.get_theme_font_size("font_size")).x <= day_label.size.x, "Russian weekday fits the day card")
	settings.set_language("en")
	panels.hide_all()
	game.home._open_info()
	await _capture("home")
	check(game._save_progress(), "Localized campaign can be saved")
	var saved: Dictionary = state.save_store.load_document()
	check(not saved.is_empty() and NewsroomSaveData.validate(saved.sections), "Localized campaign passes save validation")
	# A legacy clean second-shift draft must receive an English practice typo.
	panels.hide_all()
	game._seen_stories.append("day_2")
	session.start_shift()
	game._pencil_tutorial_done = false
	game.tutorial.hide()
	game._tutorial_stage = ""
	session.proofreading.prepare(session.current_article().id, session.localized_source_text(session.current_article()), 42, false, 0)
	game._begin_tutorial("pencil")
	check(not session.proofreading.targets.is_empty() and not _has_cyrillic(session.proofreading.source_text), "Legacy pencil practice uses the selected language")
	game._tutorial_step = 1
	game._present_tutorial_step()
	settings.set_language("ru")
	check(game.tutorial.visible and _has_cyrillic(game.tutorial.get_node("%Explanation").text), "Active pencil lesson switches to Russian")
	settings.set_language("en")
	check(game.tutorial.visible and not _has_cyrillic(game.tutorial.get_node("%Explanation").text), "Active pencil lesson switches back with its English typo")
	game._run_active = false
	settings.set_language(_original_language)
	game.queue_free()
	await process_frame
	settings.flush_audio_settings()
	if _settings_existed:
		var file := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(_settings_bytes)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.SETTINGS_PATH))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path.get_base_dir()))
	print("LOCALIZATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _has_cyrillic(text: String) -> bool:
	var matcher := RegEx.new()
	matcher.compile("[А-Яа-яЁё]")
	return matcher.search(text) != null

func _check_catalogs() -> void:
	TranslationServer.set_locale("en")
	var articles := preload("res://Data/article_catalog.gd").create_articles()
	check(articles.size() == 52, "All 52 articles remain in the catalog")
	for article in articles:
		for text in [article.source_title, article.source_text]:
			check(not _has_cyrillic(TranslationServer.translate(text)), "Article translation: " + article.id)
		for option in article.headlines:
			check(not _has_cyrillic(TranslationServer.translate(option.text)) and not _has_cyrillic(TranslationServer.translate(option.explanation)), "Headline and explanation: " + article.id)
	var chains = preload("res://Data/story_chains.gd")
	for variants: Dictionary in chains.VARIANTS.values():
		for source: String in variants.values():
			check(not _has_cyrillic(TranslationServer.translate(source)), "Story continuation is translated")
	var chapter = preload("res://Data/chapter_one.gd")
	for episode: Array in chapter.EPISODES.values():
		for page: Dictionary in episode:
			for key in ["tag", "title", "body", "next"]:
				check(not _has_cyrillic(TranslationServer.translate(page[key])), "Story translation: " + key)
	TranslationServer.set_locale("ru")
	check(TranslationServer.translate(articles[0].source_text) == articles[0].source_text, "Russian uses the original source, without English fallback")
