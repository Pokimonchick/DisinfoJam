class_name SaveRepository
extends RefCounted

const FORMAT_VERSION := 1
const MAX_FILE_BYTES := 32 * 1024 * 1024

var path: String
var error_message: String = ""
var recovered_backup: bool = false
var validator: Callable
# Future incompatible formats register a migration from N to N + 1 here.
var migrations: Dictionary = {}

func _init(save_path: String = "user://saves/campaign.json") -> void:
	path = save_path

func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")

func load_document() -> Dictionary:
	error_message = ""
	recovered_backup = false
	var document := _read(path)
	if not document.is_empty():
		return document
	# Never silently roll a newer game save back to an older backup.
	if error_message.begins_with("Сохранение создано более новой"):
		return {}
	document = _read(path + ".bak")
	if not document.is_empty():
		recovered_backup = true
		error_message = "Основной файл недоступен. Использована резервная копия."
		return document
	if exists() and error_message.is_empty():
		error_message = "Не удалось прочитать сохранение и резервную копию."
	return {}

func write_document(document: Dictionary) -> bool:
	error_message = ""
	var payload := document.duplicate(true)
	payload["format_version"] = FORMAT_VERSION
	payload["saved_at"] = Time.get_datetime_string_from_system(true)
	if not _valid(payload):
		error_message = "Данные прохождения не удалось сохранить."
		return false
	var serialized := JSON.stringify(payload, "\t").to_utf8_buffer()
	if serialized.size() > MAX_FILE_BYTES:
		error_message = "Сохранение превышает допустимый размер файла."
		return false
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		error_message = "Не удалось создать папку сохранений."
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error_message = "Не удалось открыть файл сохранения для записи."
		return false
	file.store_buffer(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		error_message = "Не удалось записать сохранение на диск."
		return false
	# Keep a known-good previous file, never copy a corrupt main over its backup.
	var previous := _read(path)
	error_message = ""
	if not previous.is_empty():
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			error_message = "Не удалось обновить резервную копию."
			return false
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		error_message = "Не удалось заменить файл сохранения. Предыдущее сохранение осталось на диске."
		return false
	return true

func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	var document: Dictionary = parser.data
	var version: Variant = document.get("format_version", 0)
	if not (version is int or version is float) or int(version) != version:
		return {}
	if int(version) > FORMAT_VERSION:
		error_message = "Сохранение создано более новой версией игры."
		return {}
	while int(version) < FORMAT_VERSION:
		if not migrations.has(int(version)):
			return {}
		document = migrations[int(version)].call(document.duplicate(true))
		version = int(version) + 1
		document["format_version"] = version
	return document if _valid(document) else {}

func _valid(document: Dictionary) -> bool:
	if not document.get("sections") is Dictionary:
		return false
	return not validator.is_valid() or validator.call(document.sections)

static func merge_sections(previous: Dictionary, updates: Dictionary) -> Dictionary:
	# Unknown fields survive a load/save cycle, even if a feature is temporarily absent.
	var result := previous.duplicate(true)
	for key in updates:
		if updates[key] is Dictionary and result.get(key) is Dictionary:
			result[key] = merge_sections(result[key], updates[key])
		else:
			result[key] = updates[key]
	return result
