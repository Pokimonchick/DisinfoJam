class_name ProofreadingState
extends RefCounted

const VERSION := 1
const MAX_STROKES := 300
const MAX_POINTS := 6000

var article_id := ""
var source_text := ""
var display_text := ""
var seed := 0
var targets: Array = []
var strokes: Array = []

func prepare(id: String, source: String, random_seed: int, guaranteed: bool = false) -> void:
	article_id = id
	source_text = source
	display_text = source
	seed = random_seed
	targets.clear()
	strokes.clear()
	var random := RandomNumberGenerator.new()
	random.seed = random_seed
	var candidates: Array = []
	for word in words(source):
		var text: String = word.text
		# Uppercase tokens include names, abbreviations and sentence openings.
		if text.length() >= 5 and text == text.to_lower():
			var positions: Array = []
			for index in range(1, text.length() - 1):
				if text[index] != text[index + 1]:
					positions.append(index)
			if not positions.is_empty():
				word["positions"] = positions
				candidates.append(word)
	var count := mini(1 if guaranteed else random.randi_range(0, 2), candidates.size())
	for index in count:
		var chosen: Dictionary = candidates.pop_at(random.randi_range(0, candidates.size() - 1))
		var original: String = chosen.text
		var swap: int = chosen.positions[random.randi_range(0, chosen.positions.size() - 1)]
		var typo := original.substr(0, swap) + original[swap + 1] + original[swap] + original.substr(swap + 2)
		var start: int = chosen.start
		display_text = display_text.substr(0, start) + typo + display_text.substr(start + original.length())
		targets.append({"id": start, "start": start, "length": original.length(), "original": original, "typo": typo})
	targets.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)

static func words(text: String) -> Array:
	var matcher := RegEx.new()
	matcher.compile("[А-Яа-яЁё]+")
	var result: Array = []
	for match_result in matcher.search_all(text):
		result.append({"start": match_result.get_start(), "length": match_result.get_end() - match_result.get_start(), "text": match_result.get_string()})
	return result

func add_stroke(stroke: Dictionary) -> void:
	if strokes.size() >= MAX_STROKES or not _valid_stroke(stroke, display_text.length()):
		return
	strokes.append(stroke.duplicate(true))

func undo_last() -> bool:
	if strokes.is_empty():
		return false
	strokes.pop_back()
	return true

func settlement() -> Dictionary:
	var corrected_ids: Dictionary = {}
	var wrong_words: Dictionary = {}
	var valid_ids: Dictionary = {}
	for target in targets:
		valid_ids[int(target.id)] = true
	for stroke in strokes:
		for target_id in stroke.get("corrected", []):
			if valid_ids.has(int(target_id)):
				corrected_ids[int(target_id)] = true
		for word_start in stroke.get("wrong", []):
			if not valid_ids.has(int(word_start)):
				wrong_words[int(word_start)] = true
	var corrected := corrected_ids.size()
	var missed := targets.size() - corrected
	var wrong := wrong_words.size()
	return {"corrected": corrected, "missed": missed, "wrong": wrong, "money": corrected * 2 - missed - wrong, "qualification": corrected - missed * 3 - wrong}

func to_data() -> Dictionary:
	return {"version": VERSION, "article_id": article_id, "source_text": source_text, "display_text": display_text, "seed": seed, "targets": targets.duplicate(true), "strokes": strokes.duplicate(true)}

func restore(data: Dictionary) -> void:
	if not validate_data(data):
		return
	article_id = data.article_id
	source_text = data.source_text
	display_text = data.display_text
	seed = int(data.seed)
	targets = data.targets.duplicate(true)
	strokes = data.strokes.duplicate(true)
	# JSON decodes integer-valued numbers as floats; keep the in-memory schema stable.
	for target in targets:
		for key in ["id", "start", "length"]:
			target[key] = int(target[key])
	for stroke in strokes:
		if stroke.has("page_character"):
			stroke.page_character = int(stroke.page_character)
		for segment in stroke.segments:
			if segment.anchor == "text":
				segment.character = int(segment.character)
		for key in ["corrected", "wrong"]:
			stroke[key] = stroke.get(key, []).map(func(value): return int(value))

static func validate_data(data: Dictionary) -> bool:
	if not _integer(data.get("version")) or int(data.version) != VERSION:
		return false
	for key in ["article_id", "source_text", "display_text"]:
		if not data.get(key) is String:
			return false
	if not _integer(data.get("seed")) or not data.get("targets") is Array or not data.get("strokes") is Array:
		return false
	if data.targets.size() > 2 or data.strokes.size() > MAX_STROKES or data.source_text.length() != data.display_text.length():
		return false
	var rebuilt: String = data.source_text
	var seen: Dictionary = {}
	var word_starts: Dictionary = {}
	for word in words(data.source_text):
		word_starts[int(word.start)] = word
	for target in data.targets:
		if not target is Dictionary:
			return false
		for key in ["id", "start", "length"]:
			if not _integer(target.get(key)):
				return false
		if not target.get("original") is String or not target.get("typo") is String:
			return false
		var start := int(target.start)
		var length := int(target.length)
		if start < 0 or length < 5 or start + length > rebuilt.length() or int(target.id) != start or seen.has(start):
			return false
		if target.original.length() != length or target.typo.length() != length or data.source_text.substr(start, length) != target.original or target.original == target.typo:
			return false
		if not word_starts.has(start) or int(word_starts[start].length) != length or target.original != target.original.to_lower():
			return false
		seen[start] = true
		rebuilt = rebuilt.substr(0, start) + target.typo + rebuilt.substr(start + length)
	if rebuilt != data.display_text:
		return false
	for stroke in data.strokes:
		if not stroke is Dictionary or not _valid_stroke(stroke, rebuilt.length()):
			return false
		for target_id in stroke.get("corrected", []):
			if not seen.has(int(target_id)):
				return false
		for wrong_start in stroke.get("wrong", []):
			if not word_starts.has(int(wrong_start)) or seen.has(int(wrong_start)):
				return false
	return true

static func _integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))

static func _valid_stroke(stroke: Dictionary, text_length: int) -> bool:
	if stroke.has("page_character") and (not _integer(stroke.page_character) or int(stroke.page_character) < 0 or int(stroke.page_character) >= maxi(1, text_length)):
		return false
	if not stroke.get("segments") is Array or stroke.segments.is_empty() or stroke.segments.size() > MAX_POINTS:
		return false
	var total := 0
	for segment in stroke.segments:
		if not segment is Dictionary or segment.get("anchor") not in ["desk", "text"] or not segment.get("points") is Array:
			return false
		if segment.anchor == "text" and (not _integer(segment.get("character")) or int(segment.character) < 0 or int(segment.character) >= text_length):
			return false
		total += segment.points.size()
		if total > MAX_POINTS or segment.points.size() < 2:
			return false
		for point in segment.points:
			if not point is Array or point.size() != 2:
				return false
			for number in point:
				if not (number is float or number is int) or not is_finite(float(number)) or absf(float(number)) > 100:
					return false
	for key in ["corrected", "wrong"]:
		if not stroke.get(key, []) is Array:
			return false
		for value in stroke.get(key, []):
			if not _integer(value) or int(value) < 0 or int(value) >= text_length:
				return false
	return true
