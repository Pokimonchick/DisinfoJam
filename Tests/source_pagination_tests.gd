extends SceneTree

const Brush = preload("res://Scripts/proofreading_brush.gd")
const Pager = preload("res://Scripts/source_pager.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _capture(name: String) -> void:
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("disinfo-page-" + name + ".png"))

func _brush_cache() -> void:
	var points: Array = []
	for index in range(2000):
		points.append([float(index) * 0.5, 100.0 + sin(float(index) * 0.03) * 2.0])
	var brush := Brush.new()
	brush.configure(points, Vector2.ONE, 2.8, 0.45)
	while brush.pending():
		brush.advance(Time.get_ticks_usec() + 100000)
	check(brush.meshes.size() > 10 and brush.tail != null, "A dense vector run is cached in bounded native mesh chunks")
	var first_mesh: ArrayMesh = brush.meshes[0]
	var chunks_before: int = brush.built_chunks
	for index in range(12):
		points.append([1000.0 + float(index) * 0.5, 100.0])
	while brush.pending():
		brush.advance(Time.get_ticks_usec() + 100000)
	check(brush.meshes[0] == first_mesh and brush.built_chunks <= chunks_before + 1, "Extending a long run preserves completed meshes and only updates its tail")
	var reverse := Brush.new()
	reverse.configure([[100.0, 200.0], [400.0, 200.0], [398.0, 200.05], [400.0, 200.1], [600.0, 201.0]], Vector2.ONE, 2.8, 0.45)
	while reverse.pending():
		reverse.advance(Time.get_ticks_usec() + 100000)
	var vertices: PackedVector3Array = reverse.tail.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bounded := true
	for vertex in vertices:
		bounded = bounded and is_finite(vertex.x) and is_finite(vertex.y) and vertex.y > 198.5 and vertex.y < 202.5
	check(bounded, "A near reversal keeps all visual vertices within the brush width without vertical spikes")

func _red_ink_in(image: Image, region: Rect2i) -> bool:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.r > pixel.g * 1.4 and pixel.r > pixel.b * 1.4:
				return true
	return false

func _continuous_erasure(surface: ProofreadingSurface, label: RichTextLabel, model: ProofreadingState) -> void:
	# A distant, untouched piece of a dense mark must stay visible in every frame
	# while the eraser repeatedly edits another piece under a small render budget.
	label.scroll_active = false
	label.get_v_scroll_bar().value = 0
	model.strokes.clear()
	var points: Array = []
	for index in range(2500):
		points.append([(220.0 + float(index) * 0.52) / surface.size.x, 820.0 / surface.size.y])
	model.add_stroke({"segments": [{"anchor": "desk", "points": points}], "page_character": 0, "corrected": [], "wrong": []})
	surface.line_width = 2.8
	surface.render_budget_ms = 3.0
	surface.bind(label, model, 0)
	for frame in range(160):
		await process_frame
		if not surface.is_processing():
			break
	check(not surface.is_processing(), "The dense mark finishes its initial visual cache")
	var native := DisplayServer.get_name() != "headless"
	var untouched := Rect2i(1450, 817, 24, 7)
	if native:
		await RenderingServer.frame_post_draw
		check(_red_ink_in(root.get_texture().get_image(), untouched), "The untouched end of the dense mark is visible before erasing")
	surface.render_budget_ms = 0.1
	check(surface.begin_erasure(Vector2(320, 820), 12.0), "Erasing the dense mark starts on paper")
	var continuously_visible := true
	for index in range(12):
		surface.extend_erasure(Vector2(320.0 + float(index + 1) * 16.0, 820), 12.0)
		await process_frame
		if native:
			await RenderingServer.frame_post_draw
			continuously_visible = _red_ink_in(root.get_texture().get_image(), untouched) and continuously_visible
	if native:
		check(continuously_visible, "Untouched ink never blanks or redraws from the start during continuous erasing")
	surface.finish_erasure()
	for frame in range(400):
		await process_frame
		if not surface.is_processing():
			break
	check(not surface.is_processing(), "Coalesced erasing eventually displays the latest geometry")
	if native:
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(not _red_ink_in(image, Rect2i(330, 817, 170, 7)) and _red_ink_in(image, untouched), "The final frame keeps untouched ink and removes the full latest eraser sweep")
	await _capture("erased-dense")
	# Deleting a mark while its partial rebuild is pending must cancel that rebuild.
	surface.begin_erasure(Vector2(700, 820), 12.0)
	surface.extend_erasure(Vector2(220, 820), 12.0)
	surface.extend_erasure(Vector2(1600, 820), 12.0)
	surface.finish_erasure()
	await process_frame
	await process_frame
	check(model.strokes.is_empty() and surface._render_cache.is_empty() and not surface.is_processing(), "Fully erasing a pending mark cannot resurrect its stale visual cache")

func _run() -> void:
	_brush_cache()
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	var canvas := Control.new()
	canvas.size = Vector2(1920, 1080)
	root.add_child(canvas)
	var paper := ColorRect.new()
	paper.position = Vector2(70, 60)
	paper.size = Vector2(1780, 960)
	paper.color = Color("f4e6bf")
	canvas.add_child(paper)
	var label := RichTextLabel.new()
	label.position = Vector2(140, 100)
	label.size = Vector2(1640, 540)
	label.add_theme_color_override("default_color", Color("403629"))
	label.add_theme_font_size_override("normal_font_size", 34)
	canvas.add_child(label)
	var page_material: ShaderMaterial = load("res://Data/source_ink.tres").duplicate()
	page_material.set_shader_parameter("ink_origin", label.position)
	label.material = page_material
	var pager: Pager = load("res://Scenes/source_pager.tscn").instantiate()
	canvas.add_child(pager)
	pager.bind(label)
	for ink_control in [pager.previous, pager.counter, pager.next]:
		ink_control.material = page_material
	var model := ProofreadingState.new()
	var paragraph := "Бумага сохраняет лёгкое зерно, а карандаш оставляет мягкую красную линию. При перелистывании весь текст и пометки впитываются вместе, затем появляется следующая страница.\n\n"
	model.prepare("page-brush", paragraph.repeat(20), 17)
	pager.set_source(model.display_text)
	var surface := ProofreadingSurface.new()
	surface.size = canvas.size
	surface.paper = paper
	surface.set_ink_material(page_material)
	canvas.add_child(surface)
	surface.bind(label, model, pager.character_offset)
	surface.drawing_enabled = true
	pager.page_changed.connect(surface.set_page_offset)
	pager.turning_changed.connect(func():
		surface.finish_stroke()
		surface.input_enabled = not pager.turning
	)
	pager.ink_progress_changed.connect(func(absorption: float, reveal: float):
		for ink in [page_material, surface.material]:
			ink.set_shader_parameter("page_absorption_progress", absorption)
			ink.set_shader_parameter("page_reveal_progress", reveal)
	)
	await process_frame
	await process_frame
	check(pager.page_ranges().size() > 1, "The source retains native multi-page layout")
	check(surface.begin_stroke(Vector2(200, 780)), "A slow stroke starts on the blank paper area")
	for index in range(1, 45):
		surface.extend_stroke(Vector2(200.0 + float(index) * 1.7, 780.0 + sin(float(index) * 0.1) * 0.3))
		await process_frame
	surface.finish_stroke()
	check(model.strokes.size() == 1 and model.strokes[0].page_character == pager.character_offset, "Slow input still saves one normalized stroke owned by the current sheet")
	surface.begin_stroke(Vector2(420, 810))
	for point in [Vector2(1000, 810), Vector2(995, 810.1), Vector2(1000, 810.2), Vector2(1360, 810)]:
		surface.extend_stroke(point)
	surface.finish_stroke()
	for index in range(6):
		await process_frame
	var saved: Dictionary = model.to_data()
	check(surface._render_cache.size() == 2 and surface._render_cache[0].brushes[0].tail != null, "Both completed marks have native cached visual geometry")
	var slow_mesh: ArrayMesh = surface._render_cache[0].brushes[0].tail
	await _capture("brush")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		label.hide()
		pager.hide()
		surface.scale = Vector2(6, 6)
		surface.position = Vector2(-1000, -4200)
		await _capture("brush-slow-detail")
		surface.position = Vector2(-5000, -4200)
		await _capture("brush-turn-detail")
		surface.scale = Vector2.ONE
		surface.position = Vector2.ZERO
		label.show()
		pager.show()
	# Page one has its own mark; returning to page zero must restore both others.
	pager.go_to_character(pager.page_ranges()[1].x)
	await process_frame
	await process_frame
	surface.begin_stroke(Vector2(220, 780))
	surface.extend_stroke(Vector2(620, 785))
	surface.finish_stroke()
	pager.go_to_character(0)
	for index in range(4):
		await process_frame
	check(surface._render_cache[0].brushes[0].tail == slow_mesh, "Returning to a sheet reuses its completed visual meshes")
	saved = model.to_data()
	pager.turn_seconds = 0.8
	pager.turn_to(1)
	await create_timer(0.15).timeout
	var absorption := float(page_material.get_shader_parameter("page_absorption_progress"))
	check(pager.turning and pager.page_index == 0 and absorption > 0.0 and absorption < 1.0, "The outgoing sheet absorbs before its content changes")
	check(label.self_modulate.a == 1.0 and pager.get_node("Row").modulate.a == 1.0 and surface.text_opacity == 1.0, "Page ink uses a shared spatial mask without a second plain alpha fade")
	check(surface.material.get_shader_parameter("page_absorption_progress") == absorption, "Text and every mark share the outgoing ink progress")
	await _capture("absorbing")
	await create_timer(0.4).timeout
	var reveal := float(page_material.get_shader_parameter("page_reveal_progress"))
	check(pager.page_index == 1 and surface.character_offset == pager.character_offset and reveal > 0.0 and reveal < 1.0, "The incoming sheet and its marks reveal only after the hidden page switch")
	check(pager.counter.text.begins_with("2 /") and pager.counter.material == page_material and surface.material.get_shader_parameter("page_reveal_progress") == reveal, "The paginator and incoming marks use the same material clock")
	await _capture("revealing")
	await create_timer(0.4).timeout
	check(not pager.turning and page_material.get_shader_parameter("page_absorption_progress") == 0.0 and page_material.get_shader_parameter("page_reveal_progress") == 1.0, "A completed page turn leaves readable ink and enables navigation")
	check(model.to_data() == saved, "Ink rendering and page turns do not change saved marks or typo data")
	pager.turn_to(0)
	await create_timer(0.05).timeout
	pager.finish_turn()
	check(pager.page_index == 0 and not pager.turning and page_material.get_shader_parameter("page_reveal_progress") == 1.0, "Interrupting a page turn settles its target and clears the transient mask")
	check(model.to_data() == saved, "An interrupted transition also preserves all vector marks")
	await process_frame
	await process_frame
	var untouched_mesh: ArrayMesh = surface._render_cache[1].brushes[0].tail
	check(surface.begin_erasure(Vector2(220, 780), 12.0), "The existing vector eraser accepts a cached mark")
	surface.finish_erasure()
	for index in range(4):
		await process_frame
	check(surface._render_cache[0].brushes[0].tail != slow_mesh and surface._render_cache[1].brushes[0].tail == untouched_mesh, "Erasure rebuilds only changed marks and preserves unrelated mesh caches")
	var before_restore: ArrayMesh = surface._render_cache[1].brushes[0].tail
	model.restore(model.to_data())
	surface.queue_redraw()
	for index in range(4):
		await process_frame
	check(is_same(surface._render_cache[1].stroke, model.strokes[1]) and surface._render_cache[1].brushes[0].tail != before_restore, "Restoring the same number of strokes replaces stale visual owners without geometry hashing")
	model.strokes.clear()
	for index in range(3):
		model.add_stroke({"segments": [{"anchor": "desk", "points": [[0.1, 0.5], [0.3, 0.5]]}], "page_character": 0, "corrected": [], "wrong": []})
	surface.queue_redraw()
	for index in range(4):
		await process_frame
	check(is_same(surface._render_cache[0].stroke, model.strokes[0]) and surface._render_cache[1].brushes[0].tail != before_restore, "Clearing and replacing marks at the same count cannot draw another stroke's cached mesh")
	var before_width: ArrayMesh = surface._render_cache[0].brushes[0].tail
	var before_width_data: Dictionary = model.to_data()
	surface.line_width = 4.0
	for index in range(4):
		await process_frame
	check(surface._render_cache[0].brushes[0].tail != before_width and model.to_data() == before_width_data, "Changing the brush width rebuilds its visual cache without changing saved strokes")
	# Old text-anchored marks still follow a native scroll after cache conversion.
	label.scroll_active = true
	label.text = model.display_text
	model.strokes.clear()
	model.add_stroke({"segments": [{"anchor": "text", "character": 0, "points": [[0.1, 0.5], [0.2, 0.5]]}], "corrected": [], "wrong": []})
	surface.bind(label, model, 0)
	for index in range(4):
		await process_frame
	var legacy_mesh: ArrayMesh = surface._render_cache[0].brushes[0].tail
	label.scroll_to_line(3)
	for index in range(4):
		await process_frame
	var legacy_moved: bool = surface._render_cache[0].brushes.is_empty() or surface._render_cache[0].brushes[0].tail != legacy_mesh
	check(label.get_v_scroll_bar().value > 0.0 and legacy_moved, "Legacy text-anchored marks invalidate their visual positions on native scrolling")
	await _continuous_erasure(surface, label, model)
	print("SOURCE PAGINATION TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
