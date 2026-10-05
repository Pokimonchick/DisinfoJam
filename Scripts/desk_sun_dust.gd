@tool
extends Node2D

const LIGHT_PARAMETERS := [
	"light_color", "speed", "sway", "reach", "source_glow",
	"direction", "ray_width", "ray_spacing", "width_variation", "shimmer",
	"light_position", "rect_size", "animation_time",
]

@export_group("Вид пыли")
## Общее количество пылинок в двух слоях. Ноль полностью убирает пыль.
@export_range(0, 600, 1) var particle_count := 180:
	set(value):
		particle_count = value
		_sync_settings()
## Минимальный и максимальный диаметр ближних пылинок в пикселях макета.
@export var size_range := Vector2(3.0, 7.0):
	set(value):
		size_range = value
		_sync_settings()
@export_range(0.0, 1.0, 0.01) var opacity := 0.85:
	set(value):
		opacity = value
		_sync_settings()
## Яркость свечения пылинок, независимо от яркости солнечных лучей.
@export_range(0.0, 4.0, 0.05) var brightness := 1.6:
	set(value):
		brightness = value
		_sync_settings()
## Мягкость краёв: больше — мягче, меньше — отчётливее светящийся центр.
@export_range(0.05, 1.0, 0.05) var softness := 0.65:
	set(value):
		softness = value
		_sync_settings()
@export var dust_color := Color(1.0, 0.97, 0.88, 1.0):
	set(value):
		dust_color = value
		_sync_settings()

@export_group("Движение")
## Множитель скорости движения и жизненного цикла. Ноль останавливает пыль.
@export_range(0.0, 3.0, 0.05) var drift_speed := 1.0:
	set(value):
		drift_speed = value
		_sync_running()
## Минимальная и максимальная скорость ближнего слоя в пикселях в секунду.
@export var speed_range := Vector2(5.0, 12.0):
	set(value):
		speed_range = value
		_sync_settings()
## Направление дрейфа: -90 — вверх, 0 — вправо, 90 — вниз.
@export_range(-180.0, 180.0, 1.0) var drift_direction_degrees := -80.0:
	set(value):
		drift_direction_degrees = value
		_sync_settings()
## Разброс направлений вокруг заданного дрейфа; 360 — во все стороны.
@export_range(0.0, 360.0, 1.0) var direction_spread_degrees := 150.0:
	set(value):
		direction_spread_degrees = value
		_sync_settings()
## Размах дополнительных воздушных течений в пикселях в секунду.
@export_range(0.0, 10.0, 0.1) var sway := 3.0:
	set(value):
		sway = value
		_sync_settings()
@export_range(10.0, 60.0, 1.0) var lifetime := 28.0:
	set(value):
		lifetime = value
		_sync_settings()

@export_group("Глубина")
## Доля мелких пылинок дальнего слоя; остальные относятся к ближнему.
@export_range(0.0, 1.0, 0.05) var far_fraction := 0.7:
	set(value):
		far_fraction = value
		_sync_settings()
## Размер дальних пылинок относительно ближних.
@export_range(0.1, 1.0, 0.05) var far_size_scale := 0.55:
	set(value):
		far_size_scale = value
		_sync_settings()
## Прозрачность дальнего слоя относительно ближнего.
@export_range(0.0, 1.0, 0.05) var far_opacity := 0.55:
	set(value):
		far_opacity = value
		_sync_settings()

@export_group("Область и свет")
## Область распределения пыли относительно SunDust, в координатах макета стола.
@export var emission_area := Rect2(380.0, 0.0, 1560.0, 1080.0):
	set(value):
		emission_area = value
		_sync_settings()
## Узел существующих лучей. Его параметры только считываются.
@export_node_path("ColorRect") var sunlight_path := NodePath("../Sunlight")
## Чувствительность видимости пыли к свету; яркость самих лучей не меняется.
@export_range(0.0, 40.0, 0.5) var light_gain := 14.0:
	set(value):
		light_gain = value
		_sync_settings()
## Минимальная видимость между лучами, пока источник включён.
## Ноль оставляет пыль видимой только в самих лучах.
@export_range(0.0, 1.0, 0.01) var visibility_floor := 0.12:
	set(value):
		visibility_floor = value
		_sync_settings()
@export var preview_animation := true:
	set(value):
		preview_animation = value
		_sync_running()

var _layers: Array[GPUParticles2D] = []
var _draw_material: ShaderMaterial
var _synced_light_parameters: Dictionary = {}

func _ready() -> void:
	_layers = [$FarDust, $NearDust]
	_draw_material = $FarDust.material as ShaderMaterial
	visibility_changed.connect(_sync_running)
	_sync_settings()
	_sync_light()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		_sync_running()

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		_sync_light()

func _sync_running() -> void:
	var running := is_inside_tree() and is_visible_in_tree() and can_process()
	running = running and (not Engine.is_editor_hint() or preview_animation)
	for layer in _layers:
		layer.speed_scale = drift_speed if running and layer.visible else 0.0

func _sync_settings() -> void:
	if _layers.is_empty():
		return
	var area := emission_area.abs()
	var count := clampi(particle_count, 0, 600)
	var far_count := roundi(count * clampf(far_fraction, 0.0, 1.0))
	var diameters := Vector2(maxf(0.5, size_range.x), maxf(0.5, size_range.y))
	diameters = Vector2(minf(diameters.x, diameters.y), maxf(diameters.x, diameters.y))
	var velocities := Vector2(maxf(0.0, speed_range.x), maxf(0.0, speed_range.y))
	velocities = Vector2(minf(velocities.x, velocities.y), maxf(velocities.x, velocities.y))
	for i in _layers.size():
		var layer := _layers[i]
		var layer_count := far_count if i == 0 else count - far_count
		layer.amount = maxi(1, layer_count)
		layer.visible = layer_count > 0
		layer.lifetime = lifetime * (1.25 if i == 0 else 1.0)
		layer.preprocess = layer.lifetime
		layer.visibility_rect = area.grow(400.0)
		var motion := layer.process_material as ShaderMaterial
		motion.set_shader_parameter("area_origin", area.position)
		motion.set_shader_parameter("area_size", area.size)
		motion.set_shader_parameter("size_range", diameters * (far_size_scale if i == 0 else 1.0))
		motion.set_shader_parameter("speed_range", velocities * (0.6 if i == 0 else 1.0))
		motion.set_shader_parameter("drift_direction", deg_to_rad(drift_direction_degrees))
		motion.set_shader_parameter("direction_spread", deg_to_rad(direction_spread_degrees))
		motion.set_shader_parameter("sway", sway * (0.5 if i == 0 else 1.0))
		motion.set_shader_parameter("layer_opacity", far_opacity if i == 0 else 1.0)
	_draw_material.set_shader_parameter("dust_color", dust_color)
	_draw_material.set_shader_parameter("opacity", opacity)
	_draw_material.set_shader_parameter("brightness", brightness)
	_draw_material.set_shader_parameter("softness", softness)
	_draw_material.set_shader_parameter("light_gain", light_gain)
	_draw_material.set_shader_parameter("visibility_floor", visibility_floor)
	_sync_running()

func _sync_light() -> void:
	if _draw_material == null:
		return
	var sunlight := get_node_or_null(sunlight_path) as ColorRect
	if sunlight == null or not sunlight.is_visible_in_tree() or not sunlight.material is ShaderMaterial:
		_set_light_parameter("strength", 0.0)
		return
	var light_material := sunlight.material as ShaderMaterial
	for parameter in LIGHT_PARAMETERS:
		var value: Variant = light_material.get_shader_parameter(parameter)
		if value != null:
			_set_light_parameter(parameter, value)
	var strength := float(light_material.get_shader_parameter("strength"))
	_set_light_parameter("strength", strength * sunlight.modulate.a * sunlight.self_modulate.a)
	# Particle MODEL_MATRIX uses world coordinates, including the desk's scale/parallax.
	var inverse := sunlight.get_global_transform().affine_inverse()
	_set_light_parameter("light_inverse_x", inverse.x)
	_set_light_parameter("light_inverse_y", inverse.y)
	_set_light_parameter("light_inverse_origin", inverse.origin)

func _set_light_parameter(parameter: String, value: Variant) -> void:
	if _synced_light_parameters.has(parameter) and _synced_light_parameters[parameter] == value:
		return
	_synced_light_parameters[parameter] = value
	_draw_material.set_shader_parameter(parameter, value)
