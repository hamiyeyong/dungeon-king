extends Node2D

signal stats_changed

const TILE_SIZE := 32
const KNIGHT_PATH = "res://assets/sprites/doodle-rpg/ALL SPRITES/Knight/Walking/"
const KNIGHT_SCALE = 0.22  # 192px 원본 → ~42px

var tile_pos := Vector2i.ZERO
var map_ref = null
var sprite: AnimatedSprite2D

var hp := 20
var max_hp := 20
var hunger := 100
var floor_num := 1

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.scale = Vector2(KNIGHT_SCALE, KNIGHT_SCALE)
	add_child(sprite)

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_anim(frames, "down",  ["Forward0", "Forward1", "Forward2"])
	_add_anim(frames, "up",    ["Up0",      "Up1",      "Up2"])
	_add_anim(frames, "left",  ["Left0",    "Left1",    "Left2"])
	_add_anim(frames, "right", ["Right0",   "Right1",   "Right2"])
	sprite.sprite_frames = frames
	sprite.play("down")

func _add_anim(frames: SpriteFrames, anim: String, files: Array) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, 8)
	frames.set_animation_loop(anim, true)
	for f in files:
		frames.add_frame(anim, load(KNIGHT_PATH + f + ".png"))

func init(start_tile: Vector2i, map: Node) -> void:
	tile_pos = start_tile
	map_ref = map
	position = map.tile_to_world(tile_pos)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	var dir := Vector2i.ZERO
	match event.keycode:
		KEY_W, KEY_UP:    dir = Vector2i(0, -1)
		KEY_S, KEY_DOWN:  dir = Vector2i(0, 1)
		KEY_A, KEY_LEFT:  dir = Vector2i(-1, 0)
		KEY_D, KEY_RIGHT: dir = Vector2i(1, 0)
	if dir != Vector2i.ZERO:
		_try_move(dir)

func _try_move(dir: Vector2i) -> void:
	var next := tile_pos + dir
	if map_ref and map_ref.is_walkable(next.x, next.y):
		tile_pos = next
		position = map_ref.tile_to_world(tile_pos)
		_update_anim(dir)
		_on_step()

func _update_anim(dir: Vector2i) -> void:
	match dir:
		Vector2i(0,  1): sprite.play("down")
		Vector2i(0, -1): sprite.play("up")
		Vector2i(-1, 0): sprite.play("left")
		Vector2i(1,  0): sprite.play("right")

func _on_step() -> void:
	hunger = max(0, hunger - 1)
	if hunger == 0:
		hp = max(0, hp - 1)
	stats_changed.emit()
