@tool
extends ColorRect

@export_group("Источник света")
## Координаты источника в пикселях относительно верхнего левого угла Sunlight.
## Источник можно вынести за границы узла, например выше правого угла.
@export var source_position := Vector2(2067.0, -43.4):
	set(value):
		source_position = value
		_sync_material()
## Общая яркость. Ноль полностью убирает эффект.
@export_range(0.0, 0.8, 0.01) var brightness := 0.30:
	set(value):
		brightness = value
		_sync_material()
@export var light_color := Color(1.0, 0.95, 0.79, 1.0):
	set(value):
		light_color = value
		_sync_material()
## Дальность затухания света в пикселях.
@export_range(500.0, 3000.0, 10.0) var reach := 1700.0:
	set(value):
		reach = value
		_sync_material()
## Сила мягкого свечения возле источника.
@export_range(0.0, 1.0, 0.01) var source_glow := 0.38:
	set(value):
		source_glow = value
		_sync_material()

@export_group("Форма лучей")
## Поворот всего веера в градусах относительно исходного направления.
@export_range(-180.0, 180.0, 0.5) var direction_degrees := 0.0:
	set(value):
		direction_degrees = value
		_sync_material()
## Множитель ширины мягких лучей; 1 — исходная ширина.
@export_range(0.25, 3.0, 0.05) var ray_width := 1.0:
	set(value):
		ray_width = value
		_sync_material()
## Расстояние между осями лучей в веере, независимо от их толщины.
## 1 — исходное расстояние; больше 1 — лучи расходятся шире.
@export_range(0.25, 2.5, 0.05) var ray_spacing := 1.0:
	set(value):
		ray_spacing = value
		_sync_material()

@export_group("Анимация")
## Скорость движения и изменения яркости. Ноль останавливает анимацию.
@export_range(0.0, 2.0, 0.01) var speed := 0.55:
	set(value):
		speed = value
		_sync_material()
## Размах покачивания отдельных лучей в градусах.
@export_range(0.0, 15.0, 0.1) var sway_degrees := 3.5:
	set(value):
		sway_degrees = value
		_sync_material()
## Насколько меняется ширина отдельных лучей во время движения.
@export_range(0.0, 1.0, 0.01) var width_variation := 0.55:
	set(value):
		width_variation = value
		_sync_material()
## Глубина проявления и затухания лучей; 1 — каждый луч полностью затухает.
@export_range(0.0, 1.0, 0.01) var shimmer := 0.70:
	set(value):
		shimmer = value
		_sync_material()
## Проигрывать движение в редакторе без запуска игры.
@export var preview_animation := false

var _animation_time := 0.0

func _ready() -> void:
	resized.connect(_sync_material)
	_sync_material()

func _sync_material() -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null or size.x <= 0.0 or size.y <= 0.0:
		return
	shader_material.set_shader_parameter("rect_size", size)
	shader_material.set_shader_parameter("light_position", source_position / size)
	shader_material.set_shader_parameter("strength", brightness)
	shader_material.set_shader_parameter("light_color", light_color)
	shader_material.set_shader_parameter("reach", reach)
	shader_material.set_shader_parameter("source_glow", source_glow)
	shader_material.set_shader_parameter("direction", deg_to_rad(direction_degrees))
	shader_material.set_shader_parameter("ray_width", ray_width)
	shader_material.set_shader_parameter("ray_spacing", ray_spacing)
	shader_material.set_shader_parameter("speed", speed)
	shader_material.set_shader_parameter("sway", deg_to_rad(sway_degrees))
	shader_material.set_shader_parameter("width_variation", width_variation)
	shader_material.set_shader_parameter("shimmer", shimmer)
	shader_material.set_shader_parameter("animation_time", _animation_time)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or (Engine.is_editor_hint() and not preview_animation):
		return
	# The desk's inherited process mode freezes the rays on pause, like the coffee.
	_animation_time += delta
	(material as ShaderMaterial).set_shader_parameter("animation_time", _animation_time)
