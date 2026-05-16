extends Control

const W := 854
const H := 480

var _btn_rect := Rect2(W * 0.5 - 90, H - 96, 180, 46)

var _walk_frames: Array[Texture2D] = [
	preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Knight/Walking/Right0.png"),
	preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Knight/Walking/Right1.png"),
	preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Knight/Walking/Right2.png"),
]

const KNIGHT_SIZE := 96
const KNIGHT_Y := 308.0
const WALK_SPEED := 55.0
const FRAME_DUR := 0.18

var _anim_frame: int = 0
var _anim_timer: float = 0.0
var _walk_x: float = W * 0.5
var _walk_dir: int = 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	_walk_x += WALK_SPEED * _walk_dir * delta
	if _walk_x >= W * 0.68:
		_walk_x = W * 0.68
		_walk_dir = -1
	elif _walk_x <= W * 0.32:
		_walk_x = W * 0.32
		_walk_dir = 1

	_anim_timer += delta
	if _anim_timer >= FRAME_DUR:
		_anim_timer -= FRAME_DUR
		_anim_frame = (_anim_frame + 1) % _walk_frames.size()

	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _btn_rect.has_point(event.position):
			get_tree().change_scene_to_file("res://main/main.tscn")
	elif event is InputEventScreenTouch and event.pressed:
		if _btn_rect.has_point(event.position):
			get_tree().change_scene_to_file("res://main/main.tscn")

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color("#0a0a12"))

	# Title
	draw_string(font, Vector2(0, 70), "던전왕이 될 거야",
		HORIZONTAL_ALIGNMENT_CENTER, W, 34, Color("#f0d060"))
	draw_string(font, Vector2(0, 96), "— Dungeon King —",
		HORIZONTAL_ALIGNMENT_CENTER, W, 12, Color(0.55, 0.5, 0.35))

	# XP bar section
	var xp: int = SaveData.explore_xp
	var xp_y := 122.0
	draw_string(font, Vector2(0, xp_y + 12),
		"탐험경험치  %d XP" % xp,
		HORIZONTAL_ALIGNMENT_CENTER, W, 13, Color("#aaddff"))

	var bar_w := 460.0
	var bar_h := 13.0
	var bar_x := (W - bar_w) * 0.5
	var bar_y := xp_y + 22.0
	var next_xp: int = _next_milestone_xp(xp)
	var prev_xp: int = _prev_milestone_xp(xp)
	var progress: float
	if next_xp == prev_xp:
		progress = 1.0
	else:
		progress = float(xp - prev_xp) / float(next_xp - prev_xp)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color("#1a1a2a"))
	draw_rect(Rect2(bar_x, bar_y, bar_w * clamp(progress, 0.0, 1.0), bar_h), Color("#3399ff"))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color("#334466"), false)

	# 다음 보상 표시
	var next_idx: int = _next_milestone_idx(xp)
	var reward_y := bar_y + bar_h + 18.0
	if next_idx < 0:
		draw_string(font, Vector2(0, reward_y + 14),
			"✦  모든 보상 해금 완료!",
			HORIZONTAL_ALIGNMENT_CENTER, W, 13, Color("#f0d060"))
	else:
		var need: int = SaveData.MILESTONE_THRESHOLDS[next_idx] - xp
		draw_string(font, Vector2(0, reward_y + 12),
			"다음 보상까지  %d XP" % need,
			HORIZONTAL_ALIGNMENT_CENTER, W, 10, Color("#7799bb"))
		var reward_box_w := 360.0
		var reward_box_h := 38.0
		var rbx := (W - reward_box_w) * 0.5
		var rby := reward_y + 20.0
		draw_rect(Rect2(rbx, rby, reward_box_w, reward_box_h), Color(0.08, 0.12, 0.18, 0.9))
		draw_rect(Rect2(rbx, rby, reward_box_w, reward_box_h), Color(0.25, 0.45, 0.65, 0.7), false)
		draw_string(font, Vector2(rbx, rby + reward_box_h * 0.5 + 5),
			"🎁  %s" % SaveData.MILESTONE_LABELS[next_idx],
			HORIZONTAL_ALIGNMENT_CENTER, reward_box_w, 13, Color("#aaddff"))

	# Knight walking animation
	var tex: Texture2D = _walk_frames[_anim_frame]
	var half: float = KNIGHT_SIZE * 0.5
	var dest := Rect2(_walk_x - half, KNIGHT_Y - half, KNIGHT_SIZE, KNIGHT_SIZE)
	if _walk_dir < 0:
		# 좌우 반전: x축 대칭 (_walk_x 기준)
		draw_set_transform(Vector2(_walk_x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect(tex, dest, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(tex, dest, false)

	# Start button
	draw_rect(_btn_rect, Color(0.12, 0.38, 0.12, 0.95))
	draw_rect(_btn_rect, Color(0.3, 0.7, 0.3, 0.8), false, 2.0)
	draw_string(font,
		Vector2(_btn_rect.position.x,
				_btn_rect.position.y + _btn_rect.size.y * 0.5 + 8),
		"게임 시작", HORIZONTAL_ALIGNMENT_CENTER, _btn_rect.size.x, 17, Color.WHITE)

func _next_milestone_idx(xp: int) -> int:
	for i in SaveData.MILESTONE_THRESHOLDS.size():
		if xp < SaveData.MILESTONE_THRESHOLDS[i]:
			return i
	return -1

func _next_milestone_xp(xp: int) -> int:
	var idx: int = _next_milestone_idx(xp)
	return SaveData.MILESTONE_THRESHOLDS[idx] if idx >= 0 else 999999

func _prev_milestone_xp(xp: int) -> int:
	var prev: int = 0
	for t: int in SaveData.MILESTONE_THRESHOLDS:
		if xp < t:
			return prev
		prev = t
	return prev
