extends Node2D

const WHAM_PATH := "res://assets/sprites/doodle-rpg/ALL SPRITES/Particles/"
const SCALE := 0.28

func spawn(world_pos: Vector2) -> void:
	position = world_pos
	_play(["Wham0", "Wham1", "Wham2"], 12.0)

func spawn_clear(world_pos: Vector2) -> void:
	position = world_pos
	_play(["Wham4"], 3.0)

func _play(files: Array, speed: float) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.scale = Vector2(SCALE, SCALE)

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("hit")
	frames.set_animation_speed("hit", speed)
	frames.set_animation_loop("hit", false)
	for f in files:
		frames.add_frame("hit", load(WHAM_PATH + f + ".png"))

	sprite.sprite_frames = frames
	sprite.animation_finished.connect(queue_free)
	add_child(sprite)
	sprite.play("hit")
