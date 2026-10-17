extends SceneTree
## Regression checks for the cutscene layout restored from c885dde.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var state := root.get_node("GameState")
	var test_path := "user://story_presentation_%d/campaign.json" % Time.get_ticks_usec()
	state.save_store = SaveRepository.new(test_path)
	state.session = NewsroomSession.new()
	state.session.balance = NewsroomBalance.new()
	state.session.reset(42)
	state.session.player_id = "story-presentation-test"
	state.session.run_id = "story-presentation-test-run"
	var game = load("res://Scenes/mvp_game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._work_tutorial_done = true
	game._home_tutorial_done = true
	game._pencil_tutorial_done = true
	var narrative = game.get_node("%Narrative")
	check(narrative is PanelContainer and narrative.get_parent().name == "Stage", "Original large cutscene card lives in the stage")
	for episode in game.CHAPTER.EPISODES:
		for page in game.CHAPTER.EPISODES[episode].size():
			var entry: Dictionary = game.CHAPTER.EPISODES[episode][page]
			game._show_story(episode, page)
			await process_frame
			check(narrative.is_visible_in_tree() and not game.work.visible and not game.home.visible, "Cutscenes use their own screen without the desk or room")
			check(game.get_node("%NarrativeTitle").visible and game.get_node("%NarrativeTitle").text == entry.title, "Original story title is restored")
			check(game.get_node("%NarrativeTag").text == entry.tag, "Original chapter banner is restored")
			check(game.get_node("%NarrativeBody").text == entry.body.replace("{name}", NewsroomSession.CAMPAIGN_HERO_NAME), "A complete page is shown without short fragments")
			check(game.get_node("%NarrativePrimary").visible and game.get_node("%NarrativePrimary").text == entry.next, "Original story action caption is restored")
			var visual = game.get_node("%NarrativeVisual")
			check(visual.get_parent().visible == (entry.visual != 1), "Boss portrait panel is hidden; other illustrations remain")
			if entry.visual == 0:
				check(visual.sprite == game.HEROINE_PORTRAIT, "Nicola portrait is restored on heroine pages")
	for ending in game.ENDINGS:
		game.session.phase = NewsroomSession.Phase.ENDED
		game.session.ending = ending
		game.session.campaign_completed = false
		game._on_phase_changed()
		await process_frame
		check(game.view == game.View.ENDING and narrative.is_visible_in_tree(), "Every ending uses the original story card")
		check(game.get_node("%NarrativeTitle").text == game.ENDINGS[ending][0], "Ending title remains correct")
		check(game.get_node("%NarrativePrimary").visible and game.get_node("%NarrativeSecondary").visible, "Old ending actions are restored")
	game._run_active = false
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path.get_base_dir()))
	print("STORY PRESENTATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
