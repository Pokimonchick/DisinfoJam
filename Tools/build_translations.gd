extends SceneTree
## Run after editing the English JSON catalogs:
## godot --headless --path . --script Tools/build_translations.gd

const CATALOGS := ["interface", "articles_base", "articles_bripolis", "story_community"]

func _initialize() -> void:
	var english := Translation.new()
	english.locale = "en"
	var seen: Dictionary = {}
	for catalog in CATALOGS:
		var path := "res://Localization/%s.en.json" % catalog
		if not FileAccess.file_exists(path):
			push_error("Missing translation catalog: " + path)
			quit(1)
			return
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			push_error("Invalid translation catalog: " + path)
			quit(1)
			return
		for source: String in data:
			if not data[source] is String or str(data[source]).is_empty():
				push_error("Empty/invalid translation in " + path + ": " + source)
				quit(1)
				return
			if seen.has(source) and seen[source] != data[source]:
				push_error("Conflicting translation: " + source)
				quit(1)
				return
			seen[source] = data[source]
			english.add_message(source, data[source])
	var home_labels: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Localization/interface.ru.json"))
	# These existing source captions are English. Identity entries prevent the
	# Russian fallback from translating them while the selected locale is English.
	for source: String in home_labels:
		english.add_message(source, source)
	var error := ResourceSaver.save(english, "res://Localization/english.tres")
	print("English catalog: %d messages, save result %d" % [seen.size(), error])
	if error == OK:
		var russian := Translation.new()
		russian.locale = "ru"
		for source: String in home_labels:
			russian.add_message(source, home_labels[source])
		error = ResourceSaver.save(russian, "res://Localization/russian.tres")
	quit(0 if error == OK else 1)
