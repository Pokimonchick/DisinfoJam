class_name TamagotchiRoom
extends Control

## Visual scenery in the same 1920 x 1080 coordinates as the home hit areas.
## The parent owns fitting, interaction, game state and pause/settings decisions.
const DESIGN_SIZE := Vector2(1920, 1080)
const ART_ROOT := "res://Assets/Assets for new version of game/tamagochi/"
const ROOM_ROOT := ART_ROOT + "Тамагочи/"
const DAY_STREAM := "res://Assets/Generated/Tamagotchi/day_room.ogv"
const NIGHT_STREAM := "res://Assets/Generated/Tamagotchi/night_room.ogv"
const HERO_SCALE := 0.95
const HERO_POSITION := Vector2(629, 313)
const HERO_SIZE := Vector2(462, 745) * HERO_SCALE
const SHADOW_POSITION := HERO_POSITION + Vector2(0, 74) * HERO_SCALE
const IDLE_FPS := 6.0
const FISH_FEEDBACK_SECONDS := 1.8
const GLINT_ATLAS := preload("res://Assets/Generated/Tamagotchi/window_glint.png")
const GLINT_FRAME_SIZE := Vector2(232, 308)
const GLINT_FRAME_COUNT := 48
const GLINT_COLUMNS := 8
const GLINT_FPS := 24.0
const GLINT_POSITION := Vector2(1104, 218)
const WINDOW_RECT := Rect2(754, 124, 584, 550)
const ROOM_GRADE := preload("res://Shaders/tamagotchi_room_grade.gdshader")

var show_heroine := true:
	set(value):
		show_heroine = value
		_refresh_layers()
var sleeping := false:
	set(value):
		if sleeping == value:
			return
		sleeping = value
		_refresh_layers()

var _video: VideoStreamPlayer
var _heroine: TextureRect
var _shadow: TextureRect
var _bed: TextureRect
var _shelf: TextureRect
var _fish_feedback: Control
var _window_hotspot: Control
var _glint: TextureRect
var _glint_texture: AtlasTexture
var _hero_frames: Array[Texture2D] = []
var _shadow_frames: Array[Texture2D] = []
var _playback_paused := false
var _active_stream := ""
var _idle_clock := 0.0
var _idle_frame := -1
var _fish_seconds := 0.0
var _built := false
var _glint_clock := -1.0
var _glint_frame := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = DESIGN_SIZE
	_video = VideoStreamPlayer.new()
	_video.name = "RoomVideo"
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.expand = true
	_video.size = DESIGN_SIZE
	_video.loop = true
	_video.volume = 0.0
	_video.material = _room_grade_material()
	add_child(_video)
	_create_window_glint()
	for frame in range(4):
		_hero_frames.append(load(ART_ROOT + "IMG_%d.PNG" % (1944 + frame)) as Texture2D)
		_shadow_frames.append(load(ART_ROOT + "IMG_%d.PNG" % (1952 + frame)) as Texture2D)
	_shadow = _add_texture("HeroineShadow", _shadow_frames[0], SHADOW_POSITION, HERO_SIZE)
	_shadow.modulate.a = 0.5
	_heroine = _add_texture("Heroine", _hero_frames[0], HERO_POSITION, HERO_SIZE)
	_bed = _add_texture("Bed", load(ROOM_ROOT + "Кровать пнг/Comp 1/Кровать_00000.png") as Texture2D)
	_shelf = _add_texture("Shelf", load(ROOM_ROOT + "Кровать пнг/Comp 1/Полка_00000.png") as Texture2D)
	_create_fish_feedback()
	visibility_changed.connect(_update_playback)
	_built = true
	_refresh_layers()


func _process(delta: float) -> void:
	if _glint_clock >= 0.0:
		_glint_clock += delta
		var glint_frame := int(_glint_clock * GLINT_FPS)
		if glint_frame >= GLINT_FRAME_COUNT:
			_stop_glint()
		else:
			_set_glint_frame(glint_frame)
	_idle_clock += delta
	if show_heroine and not sleeping:
		var frame := int(_idle_clock * IDLE_FPS) % _hero_frames.size()
		if frame != _idle_frame:
			_idle_frame = frame
			_heroine.texture = _hero_frames[frame]
			_shadow.texture = _shadow_frames[frame]
	if _fish_seconds > 0.0:
		_fish_seconds = maxf(0.0, _fish_seconds - delta)
		_fish_feedback.position.y = 365.0 - (FISH_FEEDBACK_SECONDS - _fish_seconds) * 12.0
		_fish_feedback.modulate.a = minf(1.0, _fish_seconds / 0.35)
		_fish_feedback.visible = _fish_seconds > 0.0 and not sleeping


func set_playback_paused(value: bool) -> void:
	_playback_paused = value
	_update_playback()


func play_fish_feedback() -> void:
	if not _built or sleeping:
		return
	_fish_seconds = FISH_FEEDBACK_SECONDS
	_fish_feedback.position = Vector2(1595, 365)
	_fish_feedback.modulate.a = 1.0
	_fish_feedback.show()


func _refresh_layers() -> void:
	if not _built:
		return
	var desired_stream := NIGHT_STREAM if sleeping else DAY_STREAM
	if desired_stream != _active_stream:
		_video.stop()
		_video.stream = load(desired_stream) as VideoStream
		_video.material = null if sleeping else _room_grade_material()
		_active_stream = desired_stream
	_heroine.visible = show_heroine and not sleeping
	_shadow.visible = _heroine.visible
	_bed.visible = not sleeping
	_shelf.visible = not sleeping
	if sleeping:
		_stop_glint()
		_fish_seconds = 0.0
		_fish_feedback.hide()
	_update_playback()


func _update_playback() -> void:
	if not _built:
		return
	var active := is_visible_in_tree() and not _playback_paused
	if not is_visible_in_tree():
		_stop_glint()
	set_process(active)
	_video.paused = not active
	if active and not _video.is_playing():
		_video.play()


func _create_window_glint() -> void:
	_glint_texture = AtlasTexture.new()
	_glint_texture.atlas = GLINT_ATLAS
	_glint = _add_texture("WindowGlint", _glint_texture, GLINT_POSITION, GLINT_FRAME_SIZE)
	var glint_material := ShaderMaterial.new()
	glint_material.shader = preload("res://Shaders/tamagotchi_window_glint.gdshader")
	_glint.material = glint_material
	_glint.modulate.a = 0.22
	_glint.hide()
	_window_hotspot = Control.new()
	_window_hotspot.name = "WindowHover"
	_window_hotspot.position = WINDOW_RECT.position
	_window_hotspot.size = WINDOW_RECT.size
	_window_hotspot.mouse_filter = Control.MOUSE_FILTER_PASS
	_window_hotspot.mouse_entered.connect(_play_window_glint)
	add_child(_window_hotspot)


func _play_window_glint() -> void:
	if sleeping or _playback_paused or not is_visible_in_tree():
		return
	_glint_clock = 0.0
	_set_glint_frame(0)
	_glint.show()


func _set_glint_frame(frame: int) -> void:
	if frame == _glint_frame:
		return
	_glint_frame = frame
	_glint_texture.region = Rect2(Vector2(frame % GLINT_COLUMNS, frame / GLINT_COLUMNS) * GLINT_FRAME_SIZE, GLINT_FRAME_SIZE)


func _stop_glint() -> void:
	_glint_clock = -1.0
	_glint.hide()


func _room_grade_material() -> ShaderMaterial:
	var grade_material := ShaderMaterial.new()
	grade_material.shader = ROOM_GRADE
	return grade_material


func _add_texture(layer_name: String, texture: Texture2D, layer_position := Vector2.ZERO, layer_size := DESIGN_SIZE) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.position = layer_position
	layer.size = layer_size
	layer.material = _room_grade_material()
	add_child(layer)
	return layer


func _create_fish_feedback() -> void:
	_fish_feedback = Control.new()
	_fish_feedback.name = "FishFeedback"
	_fish_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fish_feedback.position = Vector2(1595, 365)
	_fish_feedback.hide()
	add_child(_fish_feedback)
	var tail := Polygon2D.new()
	tail.color = Color("fff5df")
	tail.polygon = PackedVector2Array([Vector2(140, 53), Vector2(170, 53), Vector2(177, 82)])
	_fish_feedback.add_child(tail)
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(210, 60)
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = Color("fff5df")
	bubble.border_color = Color("54382d")
	bubble.set_border_width_all(3)
	bubble.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", bubble)
	_fish_feedback.add_child(panel)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "Буль!"
	label.size = panel.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("54382d"))
	panel.add_child(label)
