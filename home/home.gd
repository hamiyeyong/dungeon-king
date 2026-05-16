extends Control

const W := 854
const H := 480

var _walk_frames: Array[Texture2D] = [
	preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Knight/Walking/Right0.png"),
	preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Knight/Walking/Right1.png"),
	preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Knight/Walking/Right2.png"),
]

const KNIGHT_SIZE := 80
const KNIGHT_Y    := 340.0
const WALK_SPEED  := 55.0
const FRAME_DUR   := 0.18

var _anim_frame: int = 0
var _anim_timer: float = 0.0
var _walk_x: float = W * 0.5
var _walk_dir: int = 1

var _selected_class: int = 0

const CARD_W    := 170
const CARD_H    := 110
const CARD_Y    := 188
const CARD_GAP  := 12
const CARD_X0   := (W - (4 * CARD_W + 3 * CARD_GAP)) / 2

const CLASS_COLORS: Array = [
	Color("#c0804a"),
	Color("#6a6aff"),
	Color("#44cc66"),
	Color("#ff9944"),
]
const CLASS_DESC: Array[String] = [
	"높은 힘·체력\n무기 숙련 +15%\n초보자 추천",
	"높은 지능·MP\n마법 특화\n고난도",
	"기습·회피·크리티컬\n경갑 착용 필수\n트릭키",
	"원거리 특화\n룬 의존도 높음\n화살 관리 필요",
]

var _btn_rect := Rect2(W * 0.5 - 70, H - 72, 140, 42)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_selected_class = SaveData.selected_class

func _process(delta: float) -> void:
	_walk_x += WALK_SPEED * _walk_dir * delta
	if _walk_x >= W * 0.72: _walk_x = W * 0.72; _walk_dir = -1
	elif _walk_x <= W * 0.28: _walk_x = W * 0.28; _walk_dir = 1
	_anim_timer += delta
	if _anim_timer >= FRAME_DUR:
		_anim_timer -= FRAME_DUR
		_anim_frame = (_anim_frame + 1) % _walk_frames.size()
	queue_redraw()

func _card_rect(i: int) -> Rect2:
	return Rect2(CARD_X0 + i * (CARD_W + CARD_GAP), CARD_Y, CARD_W, CARD_H)

func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	else:
		return

	for i in 4:
		if SaveData.is_class_unlocked(i) and _card_rect(i).has_point(pos):
			_selected_class = i
			SaveData.set_selected_class(i)
			queue_redraw()
			return

	if _btn_rect.has_point(pos):
		get_tree().change_scene_to_file("res://main/main.tscn")

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color("#0a0a12"))

	draw_string(font, Vector2(0, 62), "던전왕이 될 거야",
		HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color("#f0d060"))
	draw_string(font, Vector2(0, 82), "— Dungeon King —",
		HORIZONTAL_ALIGNMENT_CENTER, W, 11, Color(0.55, 0.5, 0.35))

	var xp: int = SaveData.explore_xp
	var best: int = SaveData.best_floor
	draw_string(font, Vector2(0, 104),
		"탐험경험치  %d XP      최고 %d층" % [xp, best],
		HORIZONTAL_ALIGNMENT_CENTER, W, 11, Color("#aaddff"))
	var bar_w := 400.0; var bar_h := 10.0
	var bar_x := (W - bar_w) * 0.5; var bar_y := 112.0
	var next_xp: int = _next_milestone_xp(xp)
	var prev_xp: int = _prev_milestone_xp(xp)
	var progress: float = 0.0 if next_xp == prev_xp else float(xp - prev_xp) / float(next_xp - prev_xp)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color("#1a1a2a"))
	draw_rect(Rect2(bar_x, bar_y, bar_w * clampf(progress, 0.0, 1.0), bar_h), Color("#3399ff"))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color("#334466"), false)

	draw_string(font, Vector2(0, 172), "직업 선택",
		HORIZONTAL_ALIGNMENT_CENTER, W, 12, Color("#999999"))

	for i in 4:
		var r := _card_rect(i)
		var unlocked := SaveData.is_class_unlocked(i)
		var selected := (_selected_class == i)
		var col: Color = CLASS_COLORS[i]

		var bg_alpha: float = 0.85 if unlocked else 0.3
		draw_rect(r, Color(col.r * 0.18, col.g * 0.18, col.b * 0.18, bg_alpha))

		if selected and unlocked:
			draw_rect(r, col, false, 2.5)
		else:
			draw_rect(r, Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.7), false, 1.0)

		var name_col: Color = col if unlocked else Color(0.4, 0.4, 0.4)
		draw_string(font, Vector2(r.position.x, r.position.y + 20),
			SaveData.CLASS_NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, name_col)

		if unlocked:
			var lines := CLASS_DESC[i].split("\n")
			var ly: float = r.position.y + 36
			for line in lines:
				draw_string(font, Vector2(r.position.x + 6, ly), line,
					HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 9, Color(0.8, 0.8, 0.8))
				ly += 14
			if selected:
				draw_string(font, Vector2(r.position.x, r.position.y + r.size.y - 8),
					"▶ 선택됨", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, col)
		else:
			draw_rect(r, Color(0, 0, 0, 0.45))
			draw_string(font, Vector2(r.position.x, r.position.y + 52),
				"🔒", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(0.5, 0.5, 0.5))
			draw_string(font, Vector2(r.position.x, r.position.y + 86),
				"%d층 달성 시 해금" % SaveData.CLASS_UNLOCK_FLOOR[i],
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Color(0.45, 0.45, 0.45))

	var tex: Texture2D = _walk_frames[_anim_frame]
	var half: float = KNIGHT_SIZE * 0.5
	var dest := Rect2(_walk_x - half, KNIGHT_Y - half, KNIGHT_SIZE, KNIGHT_SIZE)
	if _walk_dir < 0:
		draw_set_transform(Vector2(_walk_x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect(tex, dest, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(tex, dest, false)

	draw_rect(_btn_rect, Color(0.12, 0.38, 0.12, 0.95))
	draw_rect(_btn_rect, Color(0.3, 0.7, 0.3, 0.8), false, 2.0)
	draw_string(font,
		Vector2(_btn_rect.position.x, _btn_rect.position.y + _btn_rect.size.y * 0.5 + 7),
		"던전 시작", HORIZONTAL_ALIGNMENT_CENTER, _btn_rect.size.x, 16, Color.WHITE)

func _next_milestone_idx(xp: int) -> int:
	for i in SaveData.MILESTONE_THRESHOLDS.size():
		if xp < SaveData.MILESTONE_THRESHOLDS[i]: return i
	return -1

func _next_milestone_xp(xp: int) -> int:
	var idx: int = _next_milestone_idx(xp)
	return SaveData.MILESTONE_THRESHOLDS[idx] if idx >= 0 else 999999

func _prev_milestone_xp(xp: int) -> int:
	var prev: int = 0
	for t: int in SaveData.MILESTONE_THRESHOLDS:
		if xp < t: return prev
		prev = t
	return prev
