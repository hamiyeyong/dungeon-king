extends Node2D

const PARTICLES_PATH := "res://assets/sprites/doodle-rpg/ALL SPRITES/Particles/"
const SCALE := 0.32

func spawn_poison(world_pos: Vector2) -> void:
	position = world_pos
	_play(["Particle3_0", "Particle3_1", "Particle3_2", "Particle3_3"], 9.0, Color(0.3, 1.0, 0.35))

func spawn_fire(world_pos: Vector2) -> void:
	position = world_pos
	_play(["Puff_0", "Puff_1", "Puff_2", "Puff_3", "Puff_4", "Puff_5", "Puff_6"], 16.0, Color(1.0, 0.48, 0.1))

func _play(files: Array, speed: float, tint: Color) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.modulate = tint

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fx")
	frames.set_animation_speed("fx", speed)
	frames.set_animation_loop("fx", false)
	for f in files:
		frames.add_frame("fx", load(PARTICLES_PATH + f + ".png"))

	sprite.sprite_frames = frames
	sprite.animation_finished.connect(queue_free)
	add_child(sprite)
	sprite.play("fx")
