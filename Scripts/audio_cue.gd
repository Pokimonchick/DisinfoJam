class_name AudioCue
extends Node

enum Category { SFX, MUSIC }

@export var stream: AudioStream
@export var category: Category = Category.SFX
@export_range(-40.0, 6.0, 0.5) var volume_db: float = 0.0
@export var autoplay := false
@export_group("SFX")
@export_range(0.5, 2.0, 0.01) var pitch_scale: float = 1.0
@export_group("Music")
@export var loop_music := true


func _ready() -> void:
	if autoplay:
		play()


func play() -> void:
	if stream == null:
		return
	if category == Category.MUSIC:
		AudioManager.play_music(stream, volume_db, loop_music)
	else:
		AudioManager.play_sfx(stream, volume_db, pitch_scale)
