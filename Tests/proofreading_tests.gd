extends SceneTree

var checks := 0
var failures := 0
const SOURCE := "Сегодня редакторы проверяют сообщения жителей. Рабочие обсуждают строительство городской школы. Николай сообщил: 2026 год начался спокойно."

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _stroke(corrected: Array = [], wrong: Array = []) -> Dictionary:
	return {"segments": [{"anchor": "desk", "points": [[0.3, 0.5], [0.4, 0.5]]}], "corrected": corrected, "wrong": wrong}

func _run() -> void:
	var state := ProofreadingState.new()
	state.prepare("article", SOURCE, 74, true)
	check(state.targets.size() == 1 and state.source_text == SOURCE and state.display_text != SOURCE, "First lesson guarantees one visual typo without editing the source")
	var target: Dictionary = state.targets[0]
	check(target.original == target.original.to_lower() and not target.original.contains("Николай"), "Only ordinary lowercase Cyrillic words are corrupted")
	var second := ProofreadingState.new()
	second.prepare("article", SOURCE, 74, true)
	check(second.to_data() == state.to_data(), "Seeded corruption is deterministic")
	var counts: Dictionary = {}
	for random_seed in 40:
		second.prepare("article", SOURCE, random_seed)
		counts[second.targets.size()] = true
		check(second.targets.size() <= 2 and ProofreadingState.validate_data(second.to_data()), "Normal preparation keeps zero to two valid targets")
	check(counts.size() == 3, "Ordinary articles can contain zero, one or two typos")
	check(state.settlement() == {"corrected": 0, "missed": 1, "wrong": 0, "money": -1, "qualification": -3}, "Each missed typo penalizes only at settlement")
	state.add_stroke(_stroke([target.id]))
	check(state.settlement().money == 2 and state.settlement().qualification == 1, "A correction earns two money and one qualification")
	state.add_stroke(_stroke([target.id]))
	check(state.settlement().corrected == 1, "Repeated correction is rewarded once")
	var wrong_start := -1
	for word in ProofreadingState.words(SOURCE):
		if int(word.start) != int(target.id):
			wrong_start = int(word.start)
			break
	state.add_stroke(_stroke([], [wrong_start]))
	state.add_stroke(_stroke([], [wrong_start]))
	check(state.settlement().wrong == 1 and state.settlement().money == 1 and state.settlement().qualification == 0, "Repeated marks on one correct word produce one penalty")
	state.undo_last()
	check(state.settlement().wrong == 1, "Undo restores accounting from all remaining strokes")
	state.undo_last()
	check(state.settlement().wrong == 0, "Undo of the first bad mark removes its penalty")
	state.undo_last()
	check(state.settlement().corrected == 1, "Undo of a repeated correction preserves the original")
	state.undo_last()
	check(state.settlement().missed == 1 and not state.undo_last(), "Undo restores the missing typo and handles an empty history")
	state.add_stroke(_stroke())
	check(state.settlement().wrong == 0, "Blank desk scribbles have no penalty")
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_data()))
	check(ProofreadingState.validate_data(data), "Primitive geometry survives a JSON round trip")
	second.restore(data)
	check(second.to_data() == state.to_data() and second.settlement() == state.settlement(), "Restore preserves generated text, marks and settlement")
	var bad := data.duplicate(true)
	bad.strokes[0].segments[0].points = [["bad", 0], [0, 0]]
	check(not ProofreadingState.validate_data(bad), "Malformed coordinates are rejected")
	_penalty_cap_checks()
	await _surface_checks()
	print("PROOFREADING TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _penalty_cap_checks() -> void:
	var state := ProofreadingState.new()
	state.prepare("penalty_cap", SOURCE.repeat(12), 74, true)
	var wrong: Array = []
	for word in ProofreadingState.words(state.display_text):
		if word.start != state.targets[0].id:
			wrong.append(word.start)
	state.add_stroke(_stroke([], wrong))
	check(state.settlement().money == -20 and state.settlement().qualification == -20, "All deductions of one article share the money and qualification caps")
	var missed_penalties := ProofreadingState.penalty_breakdown(2, 100, 20, 20)
	check(missed_penalties.missed_money + missed_penalties.wrong_money == 20 and missed_penalties.qualification == 20, "Missed typos use the same deduction budget as incorrect marks")
	state.add_stroke(_stroke([state.targets[0].id]))
	check(state.settlement().money == -18 and state.settlement().qualification == -19, "Correction rewards remain separate from the capped deductions")
	check(state.settlement(8, 12).money == -6 and state.settlement(8, 12).qualification == -11, "Configured money and qualification limits are independent")
	state.undo_last()
	var session := NewsroomSession.new()
	session.balance = NewsroomBalance.new()
	session.reset(74)
	var article := NewsArticle.from_row(session.articles[0].to_row())
	article.id = state.article_id
	article.source_text = state.source_text
	article.provenance.clear()
	session.articles.assign([article])
	session._resolved_article = null
	session.phase = NewsroomSession.Phase.WORK
	session.day = 3
	session.proofreading_unlocked = true
	session.proofreading = state
	var initial_money := session.money
	check(session.publish_headline(0) and session.qualification == 50, "Publishing applies the capped qualification penalty")
	var recorded_money := 0
	var deductions := 0
	for entry in session.finances.entries:
		recorded_money += entry.amount
		if entry.kind in ["proofreading_missed", "proofreading_wrong"]:
			deductions -= entry.amount
	check(deductions == 20 and recorded_money == session.money - initial_money, "The ledger records actual capped expenses and reconciles with the balance")
	var money := session.money
	check(not session.publish_headline(0) and session.money == money, "Repeated publication cannot charge the capped deductions twice")

func _surface_checks() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var desk := Control.new()
	desk.size = Vector2(1280, 720)
	root.add_child(desk)
	var paper := ColorRect.new()
	paper.position = Vector2(100, 40)
	paper.size = Vector2(1080, 620)
	paper.color = Color("e8dcc0")
	desk.add_child(paper)
	var label := RichTextLabel.new()
	label.position = Vector2(190, 140)
	label.size = Vector2(700, 200)
	label.rotation = -0.022
	label.add_theme_font_size_override("normal_font_size", 30)
	label.add_theme_color_override("default_color", Color("352b22"))
	desk.add_child(label)
	var surface := ProofreadingSurface.new()
	surface.size = desk.size
	desk.add_child(surface)
	var state := ProofreadingState.new()
	state.prepare("geometry", SOURCE + "\n" + SOURCE + "\n" + SOURCE, 4, true)
	surface.bind(label, state)
	surface.drawing_enabled = true
	await process_frame
	await process_frame
	check(not surface._words.is_empty() and surface._lines.size() == label.get_line_count(), "Native label line ranges build cached word geometry")
	for line in surface._lines:
		check(absf((line.shape as TextLine).get_line_width() - float(line.width)) < 3, "TextLine shape agrees with native source line width")
	var target_rect := Rect2()
	var correct_rect := Rect2()
	for word in surface._words:
		if word.typo:
			target_rect = word.rects[0]
		elif correct_rect.size == Vector2.ZERO and word.rects[0].size.x > 70:
			correct_rect = word.rects[0]
	var bar := label.get_v_scroll_bar()
	bar.value = maxf(0, target_rect.position.y - 40)
	await process_frame
	var target_point := target_rect.get_center() - Vector2(0, bar.value)
	var viewport_point := label.get_global_transform_with_canvas() * target_point
	check(surface.begin_stroke(viewport_point - Vector2(8, 0)), "Held pencil can start a stroke over rotated source text")
	surface.extend_stroke(viewport_point + Vector2(8, 0))
	surface.finish_stroke()
	check(state.strokes[-1].corrected.is_empty() and state.strokes[-1].wrong.is_empty(), "Drawing stores geometry without recognizing words")
	check((await _evaluate(surface)).corrected == 1, "Publication evaluation recognizes an intentional typo correction")
	check(state.strokes[-1].has("page_character"), "The complete source stroke carries one page anchor")
	var segment: Dictionary = state.strokes[-1].segments[0]
	var before := surface._segment_point(segment, segment.points[0])
	var scroll_before := bar.value
	bar.value = bar.value - 20 if bar.value > 20 else bar.value + 20
	var after := surface._segment_point(segment, segment.points[0])
	check(not is_equal_approx(scroll_before, bar.value) and before.is_equal_approx(after), "Page marks keep one physical position instead of shifting only text portions")
	surface.undo_last()
	bar.value = 0
	viewport_point = label.get_global_transform_with_canvas() * correct_rect.get_center()
	surface.begin_stroke(viewport_point)
	surface.extend_stroke(viewport_point + Vector2(3, 0))
	surface.finish_stroke()
	check((await _evaluate(surface)).wrong == 0, "Incidental touches of a few characters are not punished")
	surface.undo_last()
	var a := label.get_global_transform_with_canvas() * Vector2(correct_rect.position.x, correct_rect.get_center().y)
	var b := label.get_global_transform_with_canvas() * Vector2(correct_rect.end.x, correct_rect.get_center().y)
	surface.begin_stroke(a)
	surface.extend_stroke(b)
	surface.finish_stroke()
	check((await _evaluate(surface)).wrong == 1, "Crossing a correct word counts as one incorrect mark")
	surface.undo_last()
	var start := label.get_global_transform_with_canvas() * Vector2(10, 15)
	var finish := label.get_global_transform_with_canvas() * Vector2(-90, 15)
	surface.begin_stroke(start)
	surface.extend_stroke(finish)
	surface.finish_stroke()
	check(state.strokes[-1].segments.size() == 1 and state.strokes[-1].page_character == 0, "A stroke crossing text and blank paper remains one page-bound run")
	check(surface.undo_last() and state.strokes.is_empty(), "One undo removes all portions of the mixed stroke")
	surface.paper = paper
	check(not surface.begin_stroke(Vector2(60, 100)), "Drawing cannot begin outside the article paper")
	surface.begin_stroke(Vector2(150, 90))
	surface.extend_stroke(Vector2(250, 90))
	surface.finish_stroke()
	check(surface.begin_erasure(Vector2(200, 90), 14), "An eraser gesture can start on blank article paper")
	surface.finish_erasure()
	check(state.strokes.size() == 1 and state.strokes[0].segments.size() == 2 and ProofreadingState.validate_data(state.to_data()), "Partial erasure keeps both remaining ends and a valid save")
	surface.set_page_offset(1)
	check(not surface._stroke_visible(state.strokes[0]), "Blank-paper marks also disappear on another page")
	surface.set_page_offset(0)
	check(surface._stroke_visible(state.strokes[0]), "Returning restores the complete page mark")
	await process_frame
	surface.undo_last()
	surface.begin_stroke(Vector2(150, 90))
	surface.extend_stroke(Vector2(20, 90))
	surface.finish_stroke()
	var edge_segment: Dictionary = state.strokes[-1].segments[0]
	check(surface._segment_point(edge_segment, edge_segment.points[-1]).x >= paper.position.x, "A stroke crossing the paper edge is clipped rather than drawing on the desk")
	surface.undo_last()
	var obstacle := ColorRect.new()
	obstacle.position = Vector2(180, 70)
	obstacle.size = Vector2(40, 40)
	desk.add_child(obstacle)
	surface.exclusions.assign([obstacle])
	check(not surface.begin_stroke(Vector2(200, 90)), "Foreground objects block the start of a mark")
	surface.begin_stroke(Vector2(150, 90))
	surface.extend_stroke(Vector2(250, 90))
	surface.finish_stroke()
	check(state.strokes[-1].segments.size() == 2, "Crossing an excluded object leaves a gap without reconnecting across it")
	surface.undo_last()
	surface.exclusions.clear()
	obstacle.queue_free()
	surface.begin_stroke(a)
	surface.extend_stroke(b)
	surface.finish_stroke()
	check((await _evaluate(surface)).wrong == 1, "The eraser fixture has a penalized word")
	surface.begin_erasure(a, 24)
	surface.extend_erasure(b, 24)
	surface.finish_erasure()
	check((await _evaluate(surface)).wrong == 0 and state.strokes.is_empty(), "Erased marks are absent from publication evaluation")
	await _dense_checks(surface, label, state)
	var pencil: DeskPencil = load("res://Scenes/desk_pencil.tscn").instantiate()
	pencil.position = Vector2(390, 440)
	pencil.z_index = 10
	desk.add_child(pencil)
	pencil.set_surface(surface)
	pencil.enabled = true
	await process_frame
	check(pencil.begin_pickup(Vector2(500, 500)) and pencil.held and surface.drawing_enabled, "Pencil pickup enables drawing without holding the button")
	pencil.move_pencil(Vector2(640, 420))
	await create_timer(0.2).timeout
	# A native window may receive a real OS mouse-motion event during the timer.
	pencil.move_pencil(Vector2(640, 420))
	check(pencil.contact_position().distance_to(Vector2(640, 420)) < 2, "Lifted pencil tip follows the cursor")
	var undo := Button.new()
	undo.text = "Отменить"
	undo.position = Vector2(1000, 450)
	undo.size = Vector2(160, 50)
	desk.add_child(undo)
	var clicks := [0]
	undo.pressed.connect(func(): clicks[0] += 1)
	pencil.input_exclusions = [undo, bar]
	await process_frame
	var button_point := undo.get_global_transform_with_canvas() * (undo.size * 0.5)
	await _button_event(button_point, true)
	await _button_event(button_point, false)
	check(clicks[0] == 1 and pencil.held and state.strokes.is_empty(), "Held pencil lets the native Undo button receive clicks without drawing")
	bar.value = 0
	var bar_point := bar.get_global_transform_with_canvas() * Vector2(bar.size.x * 0.5, 15)
	await _button_event(bar_point, true)
	var motion := InputEventMouseMotion.new()
	motion.position = bar_point + Vector2(0, 60)
	motion.global_position = motion.position
	motion.relative = Vector2(0, 60)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame
	await _button_event(motion.position, false)
	check(bar.value > 0 and pencil.held and state.strokes.is_empty(), "Held pencil passes native scrollbar dragging without producing strokes")
	check(not pencil._gui_drag, "Native GUI drag releases cleanly")
	pencil.interaction_enabled = false
	check(not pencil.held and not surface.drawing_enabled and pencil.position == Vector2(390, 440), "A modal immediately disables drawing and returns the pencil")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("disinfo-proofreading.png"))
	desk.queue_free()
	await process_frame

func _button_event(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _evaluate(surface: ProofreadingSurface) -> Dictionary:
	var evaluation = surface.create_evaluation()
	while not evaluation.advance():
		await process_frame
	var result := surface.state.settlement(20, 20, evaluation.counts)
	evaluation.dispose()
	return result

func _dense_checks(surface: ProofreadingSurface, label: RichTextLabel, state: ProofreadingState) -> void:
	var original_text := state.source_text
	var original_position := label.position
	var original_rotation := label.rotation
	var original_size := label.size
	var original_font_size := label.get_theme_font_size("normal_font_size")
	var original_paper := surface.paper
	state.prepare("dense", "Редакторы проверяют сообщения жителей города. Рабочие обсуждают строительство городской школы. ".repeat(10), 4, true)
	label.position = Vector2(120, 160)
	label.rotation = 0.0
	label.size = Vector2(1040, 440)
	label.add_theme_font_size_override("normal_font_size", 28)
	surface.paper = null
	surface.bind(label, state)
	await process_frame
	await process_frame
	var points: Array = []
	for index in 600:
		var sweep := float(index % 30) / 29.0
		var x := 200.0 + (sweep if (index / 30) % 2 == 0 else 1.0 - sweep) * 860.0
		points.append([x / 1280.0, (220.0 + float(index / 30) * 10.0) / 720.0])
	for count in [1, 4, 12]:
		state.strokes.clear()
		for index in count:
			state.add_stroke({"segments": [{"anchor": "desk", "points": points}], "corrected": [], "wrong": [], "page_character": 0})
		var started := Time.get_ticks_usec()
		surface._erase_at(Vector2(640, 290), 28)
		print("ERASE strokes=%d points=%d elapsed_ms=%.2f" % [count, count * points.size(), (Time.get_ticks_usec() - started) / 1000.0])
		check(state.strokes.size() == count and state.strokes[0].corrected.is_empty() and state.strokes[0].wrong.is_empty(), "Dense erasure preserves geometry without scoring")
	var snapshot := state.to_data()
	var evaluation = surface.create_evaluation()
	check(not evaluation.advance(1) and not evaluation.done, "Dense evaluation yields rather than processing all marks at contact")
	var batches := 1
	var maximum_batch := 0
	var total_usec := 0
	while not evaluation.done:
		var started := Time.get_ticks_usec()
		evaluation.advance(2000)
		var elapsed := Time.get_ticks_usec() - started
		maximum_batch = maxi(maximum_batch, elapsed)
		total_usec += elapsed
		batches += 1
		if not evaluation.done:
			await process_frame
	print("EVALUATE segments=%d batches=%d cpu_ms=%.2f max_batch_ms=%.2f" % [evaluation.processed_segments, batches, total_usec / 1000.0, maximum_batch / 1000.0])
	check(batches > 2 and evaluation.counts.wrong > 0 and state.to_data() == snapshot, "Batched evaluation recognizes dense marks without modifying saved geometry")
	var counts: Dictionary = evaluation.counts.duplicate()
	check(evaluation.advance() and evaluation.counts == counts, "A completed evaluation does not run or accumulate twice")
	var result := state.settlement(20, 20, counts)
	check(result.money >= -20 and result.qualification >= -20, "Deferred recognition preserves article penalty caps")
	evaluation.dispose()
	state.restore(snapshot)
	var erase_started := Time.get_ticks_usec()
	surface.begin_erasure(Vector2(300, 290), 28)
	surface.extend_erasure(Vector2(1000, 290), 28)
	surface.finish_erasure()
	print("ERASE fast_sweep_ms=%.2f" % ((Time.get_ticks_usec() - erase_started) / 1000.0))
	check(ProofreadingState.validate_data(state.to_data()), "Fast dense erasure keeps a valid fragmented drawing")
	var horizontal := ProofreadingSurface._capsule_interval(Vector2(100, 100), Vector2(300, 100), Vector2(150, 100), Vector2(250, 100), 10)
	check(horizontal.is_equal_approx(Vector2(0.2, 0.8)), "One fast sweep includes the round nose at both ends")
	check(ProofreadingSurface._capsule_interval(Vector2(100, 125), Vector2(300, 125), Vector2(150, 100), Vector2(250, 100), 10).x < 0.0, "A swept eraser preserves marks beyond its nose width")
	label.position = original_position
	label.rotation = original_rotation
	label.size = original_size
	label.add_theme_font_size_override("normal_font_size", original_font_size)
	surface.paper = original_paper
	state.prepare("geometry", original_text, 4, true)
	surface.bind(label, state)
	await process_frame
	await process_frame
