extends SceneTree

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
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	var canvas := Control.new()
	canvas.size = Vector2(1920, 1080)
	root.add_child(canvas)
	var origin := Control.new()
	origin.position = Vector2(800, 400)
	origin.size = Vector2(300, 180)
	canvas.add_child(origin)
	var focus: DeskFocus = load("res://Scenes/desk_focus.tscn").instantiate()
	canvas.add_child(focus)
	focus.present(origin, "ИСТОЧНИК", "Заголовок", "Текст статьи", "Закрыть")
	check(focus.is_opening() and focus.finish_opening(), "The layout-frame press finishes and consumes opening")
	await process_frame
	check(focus.active and not focus.is_opening() and focus.scale.is_equal_approx(Vector2.ONE), "Finishing before layout prevents a delayed opening tween")
	check(not focus.finish_opening(), "A later press is not consumed as opening")
	var callback := [false]
	focus.close(func(): callback[0] = true)
	check(focus.visible and not focus.active, "Closing remains animated")
	await create_timer(focus.closing_seconds + 0.1).timeout
	check(not focus.visible and origin.visible and callback[0], "Closing restores the origin and invokes its callback")
	focus.present(origin, "ИСТОЧНИК", "Заголовок", "Текст статьи", "Закрыть")
	await create_timer(0.15).timeout
	check(focus.is_opening() and focus.finish_opening(), "A press during the movement finishes opening")
	await create_timer(focus.opening_seconds + 0.1).timeout
	check(focus.active and focus.modulate.a == 1.0, "The killed opening tween cannot later close or fade the paper")
	focus.reset()

	var area: StampArea = load("res://Scenes/stamp_area.tscn").instantiate()
	canvas.add_child(area)
	await process_frame
	var clock_before := area.ink_time
	await create_timer(0.08).timeout
	check(area.ink_time > clock_before, "The organic mask clock advances with the desk")
	area.process_mode = Node.PROCESS_MODE_DISABLED
	clock_before = area.ink_time
	await create_timer(0.08).timeout
	check(is_equal_approx(area.ink_time, clock_before), "Disabling desk processing also freezes shader motion")
	area.process_mode = Node.PROCESS_MODE_INHERIT
	area.hide()

	var model := NewsroomSession.new()
	model.health = 84.0
	model.reputation = 65.0
	model.loyalty = 50.0
	var drawer: Control = load("res://Scenes/work_status_drawer.tscn").instantiate()
	canvas.add_child(drawer)
	drawer.bind(model)
	var hud: HBoxContainer = load("res://Scenes/newsroom_hud.tscn").instantiate()
	hud.position = Vector2(500, 100)
	hud.size = Vector2(1380, 152)
	canvas.add_child(hud)
	hud.bind(model)
	model.day = 2
	model.changed.emit()
	check(not drawer.get_node("%QualificationBar").visible and not hud.get_node("%QualificationGroup").visible, "Qualification stays hidden before day three")
	model.day = 3
	model.set("qualification", 61.0)
	model.set("proofreading_unlocked", true)
	model.money = 80
	model.changed.emit()
	await process_frame
	check(drawer.get_node("%QualificationBar").visible and hud.get_node("%QualificationGroup").visible, "Day three reveals qualification in both displays")
	check(drawer.get_node("%QualificationValue").text == "61 / 100" and hud.get_node("%QualificationValue").text == "61 / 100", "Both qualification displays use the session value")
	check(drawer.get_node("%QualificationHint").text.contains("ДОСТУПНА") and not drawer.get_node("%QualificationHint").text.contains("НЕДОСТУПНА"), "The drawer reflects unlocked proofreading")
	for stat: String in ["Health", "Reputation", "Loyalty", "Qualification"]:
		var title: Label = drawer.get_node("SlidingPanel/" + stat + "Title")
		var value: Label = drawer.get_node("SlidingPanel/" + stat + "Value")
		check(is_equal_approx(title.position.y + title.size.y * 0.5, value.position.y + value.size.y * 0.5), stat + " title and value share a row center")
	check(not drawer.get_node("SlidingPanel/BalanceCard").visible, "The large dark balance card is removed from presentation")
	check(drawer.get_node("%MoneyValue").get_theme_color("font_color") == Color("587148"), "A positive balance uses green ink")
	model.money = -20
	model.changed.emit()
	check(drawer.get_node("%MoneyValue").get_theme_color("font_color") == Color("a65b50"), "A negative balance uses muted red ink")
	model.money = 0
	model.changed.emit()
	check(drawer.get_node("%MoneyValue").get_theme_color("font_color") == Color("544330"), "Zero balance uses neutral ink")
	model.money = 80
	model.changed.emit()
	var source := Label.new()
	source.position = Vector2(600, 350)
	source.size = Vector2(1000, 180)
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source.add_theme_font_size_override("font_size", 32)
	source.text = "Чернила мягко уходят в бумагу отдельными пятнами. Маска проходит через весь текст статьи и не повторяется в каждой букве."
	var source_material := ShaderMaterial.new()
	source_material.shader = load("res://Shaders/source_ink.gdshader")
	source_material.set_shader_parameter("absorption_progress", 0.45)
	source_material.set_shader_parameter("ink_time", area.ink_time)
	source.material = source_material
	canvas.add_child(source)
	area.position = Vector2(750, 650)
	area.size = Vector2(400, 300)
	area.show()
	area.set_available(true)
	check(area.commit(area.get_global_transform_with_canvas() * Vector2(200, 150)), "The organic stamp shader retains the existing commit API")
	area._set_absorption(0.45)
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("disinfo-ink-focus-hud.png"))
	print("INK FOCUS HUD TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
