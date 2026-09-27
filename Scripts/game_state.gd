extends Node

signal save_requested

var session := NewsroomSession.new()
var save_store := SaveRepository.new()
var _save_sections: Dictionary = {}
var _restored_sections: Dictionary = {}

func request_save() -> void:
	save_requested.emit()

# A scene/mechanic registers a stable ID and JSON-compatible data, not a NodePath.
# Unregistered sections are retained, including scenes instantiated only later.
func register_save_section(id: String, capture: Callable, restore: Callable) -> void:
	_save_sections[id] = {"capture": capture, "restore": restore}
	restore.call(_restored_sections.get(id, {}).duplicate(true))

func unregister_save_section(id: String) -> void:
	if _save_sections.has(id):
		var capture: Callable = _save_sections[id].capture
		if capture.is_valid():
			_restored_sections[id] = capture.call()
		_save_sections.erase(id)

func capture_save_sections() -> Dictionary:
	var data := _restored_sections.duplicate(true)
	for id in _save_sections:
		var capture: Callable = _save_sections[id].capture
		if capture.is_valid():
			data[id] = capture.call()
	_restored_sections = data.duplicate(true)
	return data

func restore_save_sections(data: Dictionary) -> void:
	_restored_sections = data.duplicate(true)
	for id in _save_sections:
		var restore: Callable = _save_sections[id].restore
		if restore.is_valid():
			restore.call(data.get(id, {}).duplicate(true))
