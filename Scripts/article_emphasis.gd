extends RefCounted
## Native font spans keep source characters and proofreading offsets unchanged.
const CATALOG = preload("res://Data/article_highlights.gd")
const FONTS = preload("res://Scripts/game_fonts.gd")
const ALL_RANGES := &"article_emphasis_all"
const PAGE_RANGES := &"article_emphasis_page"

static func ranges_for(id: String, source: String, targets: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in CATALOG.ENTRIES.get(id, []):
		var start := source.find(str(entry.text))
		if start < 0:
			continue
		var end := start + str(entry.text).length()
		result.append({"start": _display_offset(start, targets), "end": _display_offset(end, targets), "italic": bool(entry.get("italic", false))})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	return result

static func _display_offset(offset: int, targets: Array) -> int:
	var result := offset
	for target: Dictionary in targets:
		if int(target.get("source_start", target.start)) < offset:
			result += int(target.length) - str(target.original).length()
	return result

static func render(label: RichTextLabel, text: String, ranges: Array, offset: int = 0) -> void:
	var local_ranges: Array[Dictionary] = []
	for span: Dictionary in ranges:
		var start := clampi(int(span.start) - offset, 0, text.length())
		var end := clampi(int(span.end) - offset, 0, text.length())
		if end > start:
			local_ranges.append({"start": start, "end": end, "italic": bool(span.italic)})
	label.set_meta(ALL_RANGES, ranges)
	label.set_meta(PAGE_RANGES, local_ranges)
	label.bbcode_enabled = false
	if local_ranges.is_empty():
		label.text = text
		return
	label.clear()
	for run: Dictionary in _runs(0, text.length(), local_ranges):
		label.push_font(_font(label, int(run.kind)))
		label.add_text(text.substr(int(run.start), int(run.end) - int(run.start)))
		label.pop()

static func shape_line(label: RichTextLabel, text: String, start: int, end: int) -> TextLine:
	var line := TextLine.new()
	var ranges: Array = label.get_meta(PAGE_RANGES, [])
	for run: Dictionary in _runs(start, end, ranges):
		line.add_string(text.substr(int(run.start), int(run.end) - int(run.start)), _font(label, int(run.kind)), label.get_theme_font_size("normal_font_size"))
	return line

static func _font(label: RichTextLabel, kind: int) -> Font:
	if kind == 1:
		return FONTS.BOLD
	if kind == 2:
		return FONTS.ITALIC
	return label.get_theme_font("normal_font")

static func _runs(start: int, end: int, ranges: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cursor := start
	for span: Dictionary in ranges:
		var first := maxi(cursor, int(span.start))
		var last := mini(end, int(span.end))
		if first >= last:
			continue
		if first > cursor:
			result.append({"start": cursor, "end": first, "kind": 0})
		result.append({"start": first, "end": last, "kind": 2 if bool(span.italic) else 1})
		cursor = last
	if cursor < end:
		result.append({"start": cursor, "end": end, "kind": 0})
	return result
