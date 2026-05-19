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

# UI 상태
var _selected_class: int = 0
var _tab: int = 0           # 0=직업, 1=룬, 2=상점
var _rune_scroll: int = 0

# 기억의 상자 팝업
# _chest_popup: 0=없음, 1=결정(열기/보관), 2=결과
var _chest_popup: int = 0
var _chest_pending_idx: int = -1
var _chest_result: Dictionary = {}

# 룬 상세/강화 팝업
var _selected_rune_id: String = ""

# 상점: 구매 결과 팝업
var _shop_result: Dictionary = {}   # 열린 상자 결과 {"grade", "frags"}

# 직업 카드 레이아웃
const CARD_W    := 170
const CARD_H    := 110
const CARD_Y    := 188
const CARD_GAP  := 12
const CARD_X0   := (W - (4 * CARD_W + 3 * CARD_GAP)) / 2

const CLASS_COLORS: Array = [
	Color("#c0804a"), Color("#6a6aff"), Color("#44cc66"), Color("#ff9944"),
]
const CLASS_DESC: Array[String] = [
	"높은 힘·체력\n무기 숙련 +15%\n초보자 추천",
	"높은 지능·MP\n마법 특화\n고난도",
	"기습·회피·크리티컬\n경갑 착용 필수\n트릭키",
	"원거리 특화\n룬 의존도 높음\n화살 관리 필요",
]

# 탭 레이아웃 (3탭)
const TAB_Y   := 130.0
const TAB_H   := 20.0
const TAB_W   := 88.0
const TAB_GAP := 4.0

# 룬 슬롯 레이아웃
const SLOT_Y   := 180.0
const SLOT_W   := 120.0
const SLOT_H   := 52.0
const SLOT_GAP := 6.0

# 룬 목록 레이아웃
const RUNE_LIST_Y   := 265.0
const RUNE_ROW_H    := 24.0
const RUNE_ROWS_VIS := 7

# 상점 레이아웃
const SHOP_START_Y := 158.0
const SHOP_ROW_H   := 36.0
const SHOP_BOX_LABELS: Array[String] = [
	"랜덤 룬 상자", "일반 룬 상자", "희귀 룬 상자", "에픽 룬 상자", "레전드 룬 상자"
]

var _btn_rect := Rect2(W * 0.5 - 70, H - 72, 140, 42)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_selected_class = SaveData.selected_class
	# 새로 획득한 상자가 있으면 팝업
	for i in SaveData.pending_chests.size():
		var ch: Dictionary = SaveData.pending_chests[i]
		if ch.get("new", false):
			_chest_pending_idx = i
			_chest_popup = 1  # 결정 팝업
			break

func _process(delta: float) -> void:
	_walk_x += WALK_SPEED * _walk_dir * delta
	if _walk_x >= W * 0.72: _walk_x = W * 0.72; _walk_dir = -1
	elif _walk_x <= W * 0.28: _walk_x = W * 0.28; _walk_dir = 1
	_anim_timer += delta
	if _anim_timer >= FRAME_DUR:
		_anim_timer -= FRAME_DUR
		_anim_frame = (_anim_frame + 1) % _walk_frames.size()
	queue_redraw()

# ── 레이아웃 헬퍼 ─────────────────────────────────────────────────────────────

func _tab_rect(i: int) -> Rect2:
	var total_w: float = 3.0 * TAB_W + 2.0 * TAB_GAP
	var x0: float = (W - total_w) * 0.5
	return Rect2(x0 + i * (TAB_W + TAB_GAP), TAB_Y, TAB_W, TAB_H)

func _card_rect(i: int) -> Rect2:
	return Rect2(CARD_X0 + i * (CARD_W + CARD_GAP), CARD_Y, CARD_W, CARD_H)

func _slot_rect(slot: int, slot_count: int) -> Rect2:
	var total_w: float = slot_count * SLOT_W + (slot_count - 1) * SLOT_GAP
	var x0: float = (W - total_w) * 0.5
	return Rect2(x0 + slot * (SLOT_W + SLOT_GAP), SLOT_Y, SLOT_W, SLOT_H)

func _rune_row_rect(visible_idx: int) -> Rect2:
	return Rect2(8.0, RUNE_LIST_Y + visible_idx * RUNE_ROW_H, W - 16.0, RUNE_ROW_H - 2.0)

func _scroll_up_rect() -> Rect2:
	return Rect2(W - 32.0, RUNE_LIST_Y - 18.0, 22.0, 16.0)

func _scroll_dn_rect() -> Rect2:
	return Rect2(W - 32.0, RUNE_LIST_Y + RUNE_ROWS_VIS * RUNE_ROW_H, 22.0, 16.0)

func _chest_popup_rect() -> Rect2:
	return Rect2((W - 420.0) * 0.5, (H - 240.0) * 0.5, 420.0, 240.0)

func _rune_detail_popup_rect() -> Rect2:
	return Rect2((W - 480.0) * 0.5, (H - 140.0) * 0.5, 480.0, 140.0)

func _rune_detail_btn_y() -> float:
	return _rune_detail_popup_rect().position.y + _rune_detail_popup_rect().size.y - 36.0

func _rune_detail_left_btn_rect() -> Rect2:
	var pr := _rune_detail_popup_rect()
	var bx: float = pr.position.x + (pr.size.x - 340.0) * 0.5
	return Rect2(bx, _rune_detail_btn_y(), 160.0, 26.0)

func _rune_detail_right_btn_rect() -> Rect2:
	var lb := _rune_detail_left_btn_rect()
	return Rect2(lb.end.x + 10.0, _rune_detail_btn_y(), 160.0, 26.0)

func _rune_detail_close_btn_rect() -> Rect2:
	var rb := _rune_detail_right_btn_rect()
	return Rect2(rb.end.x + 10.0, _rune_detail_btn_y(), 60.0, 26.0)

func _shop_row_rect(i: int) -> Rect2:
	return Rect2(60.0, SHOP_START_Y + i * SHOP_ROW_H, W - 120.0, SHOP_ROW_H - 4.0)

func _shop_buy_btn_rect(i: int) -> Rect2:
	var r := _shop_row_rect(i)
	return Rect2(r.end.x - 70.0, r.position.y + 4.0, 64.0, r.size.y - 8.0)

func _shop_result_ok_rect() -> Rect2:
	return Rect2(W * 0.5 - 50.0, H * 0.5 + 88.0, 100.0, 28.0)

# ── 입력 ──────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	else:
		return

	# 상점 결과 팝업
	if not _shop_result.is_empty():
		if _shop_result_ok_rect().has_point(pos):
			_shop_result = {}
			queue_redraw()
		return

	# 상자 팝업
	if _chest_popup > 0:
		_handle_chest_popup_input(pos)
		return

	# 룬 상세 팝업
	if _selected_rune_id != "":
		_handle_rune_detail_input(pos)
		return

	for i in 3:
		if _tab_rect(i).has_point(pos):
			_tab = i; _rune_scroll = 0; queue_redraw(); return

	match _tab:
		0: _handle_class_input(pos)
		1: _handle_rune_input(pos)
		2: _handle_shop_input(pos)

func _handle_chest_popup_input(pos: Vector2) -> void:
	var pr := _chest_popup_rect()
	if _chest_popup == 1:
		# 결정: 열기 / 보관
		var open_btn := Rect2(pr.position.x + 30, pr.end.y - 40, 150, 28)
		var store_btn := Rect2(pr.end.x - 180, pr.end.y - 40, 150, 28)
		if open_btn.has_point(pos):
			if SaveData.can_open_pending_chest(_chest_pending_idx):
				_chest_result = SaveData.open_pending_chest(_chest_pending_idx)
				_chest_pending_idx = -1
				_chest_popup = 2
				queue_redraw()
		elif store_btn.has_point(pos):
			SaveData.mark_chest_seen(_chest_pending_idx)
			_chest_pending_idx = -1
			_chest_popup = 0
			queue_redraw()
	elif _chest_popup == 2:
		# 결과 확인
		var ok_btn := Rect2(pr.position.x + (pr.size.x - 100) * 0.5, pr.end.y - 40, 100, 28)
		if ok_btn.has_point(pos):
			_chest_result = {}
			_chest_popup = 0
			queue_redraw()

func _handle_class_input(pos: Vector2) -> void:
	for i in 4:
		if SaveData.is_class_unlocked(i) and _card_rect(i).has_point(pos):
			_selected_class = i
			SaveData.set_selected_class(i)
			queue_redraw()
			return
	if _btn_rect.has_point(pos):
		get_tree().change_scene_to_file("res://main/main.tscn")

func _handle_rune_input(pos: Vector2) -> void:
	var known: Array = SaveData.get_known_rune_ids()
	var slot_count: int = SaveData.get_rune_slot_count()

	for i in slot_count:
		if _slot_rect(i, slot_count).has_point(pos):
			SaveData.unequip_rune(i)
			queue_redraw()
			return

	if _scroll_up_rect().has_point(pos):
		_rune_scroll = max(0, _rune_scroll - 1)
		queue_redraw(); return
	if _scroll_dn_rect().has_point(pos):
		_rune_scroll = min(_rune_scroll + 1, max(0, known.size() - RUNE_ROWS_VIS))
		queue_redraw(); return

	for vi in min(RUNE_ROWS_VIS, known.size() - _rune_scroll):
		if _rune_row_rect(vi).has_point(pos):
			_selected_rune_id = known[_rune_scroll + vi]
			queue_redraw()
			return

	if _btn_rect.has_point(pos):
		get_tree().change_scene_to_file("res://main/main.tscn")

func _handle_rune_detail_input(pos: Vector2) -> void:
	var rid: String = _selected_rune_id

	if _rune_detail_close_btn_rect().has_point(pos):
		_selected_rune_id = ""
		queue_redraw()
		return

	if not _rune_detail_popup_rect().has_point(pos):
		_selected_rune_id = ""
		queue_redraw()
		return

	if SaveData.is_rune_crafted(rid):
		# 왼쪽: 장착/해제, 오른쪽: 강화
		if _rune_detail_left_btn_rect().has_point(pos):
			SaveData.toggle_rune_equip(rid)
			queue_redraw()
		elif _rune_detail_right_btn_rect().has_point(pos):
			if SaveData.can_upgrade_rune(rid):
				SaveData.upgrade_rune(rid)
				queue_redraw()
	else:
		# 왼쪽: 제작, 오른쪽: (없음 — 닫기로만)
		if _rune_detail_left_btn_rect().has_point(pos):
			if SaveData.can_craft_rune(rid):
				SaveData.craft_rune(rid)
				queue_redraw()

func _handle_shop_input(pos: Vector2) -> void:
	for i in SaveData.SHOP_BOX_COST.size():
		if _shop_buy_btn_rect(i).has_point(pos):
			var result: Dictionary = SaveData.buy_and_open_shop_box(i)
			if not result.is_empty():
				_shop_result = result
				queue_redraw()
			return
	if _btn_rect.has_point(pos):
		get_tree().change_scene_to_file("res://main/main.tscn")

# ── 렌더링 ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color("#0a0a12"))

	_draw_header(font)
	_draw_tabs(font)

	if _tab == 0:
		_draw_class_tab(font)
		_draw_knight()
	elif _tab == 1:
		_draw_rune_tab(font)
	else:
		_draw_shop_tab(font)

	_draw_button(font)

	if not _shop_result.is_empty():
		_draw_chest_result_popup(font, _shop_result)
	elif _selected_rune_id != "":
		_draw_rune_detail_popup(font)
	elif _chest_popup == 1:
		_draw_chest_decision_popup(font)
	elif _chest_popup == 2:
		_draw_chest_result_popup(font, _chest_result)

func _draw_header(font: Font) -> void:
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

func _draw_tabs(font: Font) -> void:
	const LABELS := ["직업 선택", "룬 관리", "상점"]
	for i in 3:
		var r := _tab_rect(i)
		var active := (_tab == i)
		var bg := Color(0.18, 0.18, 0.28, 0.95) if active else Color(0.1, 0.1, 0.16, 0.8)
		var border := Color("#6688cc") if active else Color(0.3, 0.3, 0.45, 0.6)
		draw_rect(r, bg)
		draw_rect(r, border, false, 1.5)
		var tc := Color.WHITE if active else Color(0.6, 0.6, 0.7)
		draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 5.0),
			LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, tc)

func _draw_class_tab(font: Font) -> void:
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

func _draw_rune_tab(font: Font) -> void:
	var slot_count: int = SaveData.get_rune_slot_count()

	draw_string(font, Vector2(8, 158),
		"고대의 주화: %d개" % SaveData.rune_coins,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffcc00"))

	# 보관 중인 상자 수 표시
	var stored: int = SaveData.pending_chests.size()
	if stored > 0:
		draw_string(font, Vector2(W - 8, 158),
			"보관 상자: %d개" % stored,
			HORIZONTAL_ALIGNMENT_RIGHT, 200, 10, Color("#aaaaff"))

	draw_string(font, Vector2(0, 172),
		"장착 슬롯 (%d/%d)" % [slot_count, 5],
		HORIZONTAL_ALIGNMENT_CENTER, W, 10, Color("#aaaaaa"))

	for i in slot_count:
		var r := _slot_rect(i, slot_count)
		var equipped_id: String = SaveData.rune_equipped[i] if i < SaveData.rune_equipped.size() else ""
		var is_filled: bool = equipped_id != "" and SaveData.is_rune_crafted(equipped_id)

		if is_filled:
			var def: Array = SaveData.RUNE_DEFS[equipped_id]
			var grade: int = def[1]
			var gc: Color = SaveData.RUNE_GRADE_COLORS[grade]
			draw_rect(r, Color(gc.r * 0.15, gc.g * 0.15, gc.b * 0.15, 0.9))
			draw_rect(r, gc, false, 1.5)
			draw_string(font, Vector2(r.position.x, r.position.y + 18),
				def[0], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, gc)
			draw_string(font, Vector2(r.position.x, r.position.y + 32),
				SaveData.RUNE_GRADE_NAMES[grade],
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Color(0.6, 0.6, 0.6))
			draw_string(font, Vector2(r.position.x, r.position.y + 46),
				"[탭: 해제]", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 7, Color(0.4, 0.4, 0.5))
		else:
			draw_rect(r, Color(0.08, 0.08, 0.14, 0.8))
			draw_rect(r, Color(0.25, 0.25, 0.4, 0.5), false, 1.0)
			draw_string(font, Vector2(r.position.x, r.position.y + 30),
				"빈 슬롯", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color(0.35, 0.35, 0.45))

	draw_line(Vector2(8, RUNE_LIST_Y - 6), Vector2(W - 8, RUNE_LIST_Y - 6),
		Color(0.25, 0.25, 0.4, 0.6), 1.0)
	draw_string(font, Vector2(8, RUNE_LIST_Y - 16),
		"보유 룬", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#888888"))

	var known: Array = SaveData.get_known_rune_ids()
	var total: int = known.size()

	if total == 0:
		draw_string(font, Vector2(0, RUNE_LIST_Y + 40),
			"아직 보유한 룬이 없습니다.",
			HORIZONTAL_ALIGNMENT_CENTER, W, 10, Color(0.4, 0.4, 0.5))
		draw_string(font, Vector2(0, RUNE_LIST_Y + 58),
			"던전을 탐험하면 기억의 상자를 획득합니다.",
			HORIZONTAL_ALIGNMENT_CENTER, W, 9, Color(0.35, 0.35, 0.45))
	else:
		var visible: int = min(RUNE_ROWS_VIS, total - _rune_scroll)
		for vi in visible:
			var actual: int = _rune_scroll + vi
			var rid: String = known[actual]
			var def: Array = SaveData.RUNE_DEFS[rid]
			var grade: int = def[1]
			var gc: Color = SaveData.RUNE_GRADE_COLORS[grade]
			var frags: int = SaveData.rune_fragments.get(rid, 0) as int
			var crafted: bool = SaveData.is_rune_crafted(rid)
			var equipped: bool = SaveData.is_rune_equipped(rid)

			var r := _rune_row_rect(vi)
			var row_bg: Color
			if equipped:
				row_bg = Color(gc.r * 0.12, gc.g * 0.12, gc.b * 0.12, 0.85)
			elif crafted:
				row_bg = Color(0.07, 0.09, 0.07, 0.7)
			else:
				row_bg = Color(0.06, 0.06, 0.1, 0.7)
			draw_rect(r, row_bg)
			if equipped:
				draw_rect(r, Color(gc.r * 0.6, gc.g * 0.6, gc.b * 0.6, 0.6), false, 1.0)
			elif crafted:
				draw_rect(r, Color(0.2, 0.35, 0.2, 0.4), false, 1.0)

			draw_rect(Rect2(r.position.x + 4, r.position.y + 7, 6, 6),
				gc if crafted else Color(gc.r * 0.5, gc.g * 0.5, gc.b * 0.5))

			var name_col: Color
			if equipped:
				name_col = gc
			elif crafted:
				name_col = Color(0.85, 0.85, 0.85)
			else:
				name_col = Color(0.55, 0.55, 0.6)
			draw_string(font, Vector2(r.position.x + 14, r.position.y + 15),
				def[0], HORIZONTAL_ALIGNMENT_LEFT, 110, 10, name_col)

			draw_string(font, Vector2(r.position.x + 128, r.position.y + 14),
				"[%s]" % SaveData.RUNE_GRADE_NAMES[grade],
				HORIZONTAL_ALIGNMENT_LEFT, 50, 8,
				Color(gc.r * 0.8, gc.g * 0.8, gc.b * 0.8) if crafted else Color(gc.r * 0.4, gc.g * 0.4, gc.b * 0.4))

			draw_string(font, Vector2(r.position.x + 182, r.position.y + 14),
				def[2], HORIZONTAL_ALIGNMENT_LEFT, W - 320, 8, Color(0.6, 0.6, 0.65) if crafted else Color(0.4, 0.4, 0.45))

			var right_x: float = r.position.x + r.size.x - 110
			if crafted:
				var lv: int = SaveData.get_rune_level(rid)
				var max_lv: int = SaveData.get_rune_max_level(rid)
				draw_string(font, Vector2(right_x, r.position.y + 13),
					"Lv.%d/%d  파편%d" % [lv, max_lv, frags],
					HORIZONTAL_ALIGNMENT_LEFT, 108, 8, Color(0.7, 0.8, 0.9))
				var status: String
				var sc: Color
				if equipped:
					status = "장착중"; sc = gc
				elif SaveData.can_upgrade_rune(rid):
					status = "▲ 강화 가능"; sc = Color("#aaee66")
				else:
					status = "탭으로 상세"; sc = Color(0.45, 0.45, 0.55)
				draw_string(font, Vector2(right_x, r.position.y + 22),
					status, HORIZONTAL_ALIGNMENT_LEFT, 108, 7, sc)
			else:
				var craft_cost: int = SaveData.get_craft_cost(rid)
				draw_string(font, Vector2(right_x, r.position.y + 13),
					"파편 %d / %d" % [frags, craft_cost],
					HORIZONTAL_ALIGNMENT_LEFT, 108, 8, Color(0.7, 0.7, 0.5))
				var can_craft: bool = SaveData.can_craft_rune(rid)
				draw_string(font, Vector2(right_x, r.position.y + 22),
					"제작 가능!" if can_craft else "수집중",
					HORIZONTAL_ALIGNMENT_LEFT, 108, 7,
					Color("#aaee66") if can_craft else Color(0.45, 0.45, 0.55))

		if _rune_scroll > 0:
			var sr := _scroll_up_rect()
			draw_rect(sr, Color(0.15, 0.15, 0.25, 0.8))
			draw_string(font, Vector2(sr.position.x, sr.position.y + 13),
				"▲", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 11, Color(0.7, 0.7, 0.9))
		if _rune_scroll + RUNE_ROWS_VIS < total:
			var dr := _scroll_dn_rect()
			draw_rect(dr, Color(0.15, 0.15, 0.25, 0.8))
			draw_string(font, Vector2(dr.position.x, dr.position.y + 13),
				"▼", HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, 11, Color(0.7, 0.7, 0.9))

func _draw_shop_tab(font: Font) -> void:
	draw_string(font, Vector2(8, 150),
		"고대의 주화: %d개" % SaveData.rune_coins,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffcc00"))
	draw_string(font, Vector2(0, 150),
		"상점", HORIZONTAL_ALIGNMENT_CENTER, W, 11, Color("#aaaaaa"))

	# 등급 색상: 랜덤은 무지개 대신 흰색
	const BOX_COLORS: Array = [
		Color("#dddddd"),  # 랜덤
		Color("#aaaaaa"),  # 일반
		Color("#4499ff"),  # 희귀
		Color("#cc44ff"),  # 에픽
		Color("#ffcc00"),  # 레전드
	]

	for i in SaveData.SHOP_BOX_COST.size():
		var r := _shop_row_rect(i)
		var cost: int = SaveData.SHOP_BOX_COST[i]
		var can_buy: bool = SaveData.rune_coins >= cost
		var bc: Color = BOX_COLORS[i]

		draw_rect(r, Color(bc.r * 0.06, bc.g * 0.06, bc.b * 0.06, 0.8))
		draw_rect(r, Color(bc.r * 0.4, bc.g * 0.4, bc.b * 0.4, 0.5), false, 1.0)

		draw_string(font, Vector2(r.position.x + 10, r.position.y + r.size.y * 0.5 + 5),
			SHOP_BOX_LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, 200, 11,
			bc if can_buy else Color(bc.r * 0.5, bc.g * 0.5, bc.b * 0.5))

		var cost_col: Color = Color("#ffcc00") if can_buy else Color("#666633")
		draw_string(font, Vector2(r.position.x + 220, r.position.y + r.size.y * 0.5 + 5),
			"%d 주화" % cost, HORIZONTAL_ALIGNMENT_LEFT, 120, 10, cost_col)

		var btn := _shop_buy_btn_rect(i)
		var btn_bg: Color = Color(0.15, 0.35, 0.15, 0.9) if can_buy else Color(0.1, 0.1, 0.1, 0.6)
		var btn_border: Color = Color(0.3, 0.7, 0.3, 0.8) if can_buy else Color(0.3, 0.3, 0.3, 0.4)
		draw_rect(btn, btn_bg)
		draw_rect(btn, btn_border, false, 1.5)
		draw_string(font, Vector2(btn.position.x, btn.position.y + btn.size.y * 0.5 + 5),
			"구매", HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 11,
			Color.WHITE if can_buy else Color(0.4, 0.4, 0.4))

func _draw_knight() -> void:
	var tex: Texture2D = _walk_frames[_anim_frame]
	var half: float = KNIGHT_SIZE * 0.5
	var dest := Rect2(_walk_x - half, KNIGHT_Y - half, KNIGHT_SIZE, KNIGHT_SIZE)
	if _walk_dir < 0:
		draw_set_transform(Vector2(_walk_x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect(tex, dest, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(tex, dest, false)

func _draw_button(font: Font) -> void:
	draw_rect(_btn_rect, Color(0.12, 0.38, 0.12, 0.95))
	draw_rect(_btn_rect, Color(0.3, 0.7, 0.3, 0.8), false, 2.0)
	draw_string(font,
		Vector2(_btn_rect.position.x, _btn_rect.position.y + _btn_rect.size.y * 0.5 + 7),
		"던전 시작", HORIZONTAL_ALIGNMENT_CENTER, _btn_rect.size.x, 16, Color.WHITE)

func _draw_rune_detail_popup(font: Font) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))

	var rid: String = _selected_rune_id
	if not SaveData.RUNE_DEFS.has(rid): return

	var pr := _rune_detail_popup_rect()
	var def: Array = SaveData.RUNE_DEFS[rid]
	var grade: int = def[1]
	var gc: Color = SaveData.RUNE_GRADE_COLORS[grade]
	var frags: int = SaveData.rune_fragments.get(rid, 0) as int
	var crafted: bool = SaveData.is_rune_crafted(rid)

	draw_rect(pr, Color(0.06, 0.06, 0.11, 0.97))
	draw_rect(pr, gc, false, 2.0)

	draw_string(font, Vector2(pr.position.x + 12, pr.position.y + 22),
		"[%s]" % SaveData.RUNE_GRADE_NAMES[grade],
		HORIZONTAL_ALIGNMENT_LEFT, 60, 9, gc)
	draw_string(font, Vector2(pr.position.x + 72, pr.position.y + 22),
		def[0], HORIZONTAL_ALIGNMENT_LEFT, 180, 13, gc)

	if crafted:
		var lv: int = SaveData.get_rune_level(rid)
		var max_lv: int = SaveData.get_rune_max_level(rid)
		draw_string(font, Vector2(pr.position.x + pr.size.x - 12, pr.position.y + 22),
			"Lv.%d / %d" % [lv, max_lv],
			HORIZONTAL_ALIGNMENT_RIGHT, 120, 11, Color(0.85, 0.85, 0.6))

	draw_string(font, Vector2(pr.position.x + 12, pr.position.y + 42),
		def[2], HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 24, 10, Color(0.75, 0.75, 0.8))

	if crafted:
		var lv: int = SaveData.get_rune_level(rid)
		var max_lv: int = SaveData.get_rune_max_level(rid)
		var upgrade_cost: int = SaveData.get_upgrade_cost(rid)
		var can_up: bool = SaveData.can_upgrade_rune(rid)
		var cost_text: String
		if lv >= max_lv:
			cost_text = "최대 레벨 달성"
		else:
			cost_text = "강화 비용: 파편 %d개" % upgrade_cost
		var cost_col: Color = Color(0.5, 0.5, 0.55) if lv >= max_lv \
			else (Color("#aaee66") if can_up else Color(0.6, 0.4, 0.4))
		draw_string(font, Vector2(pr.position.x + 12, pr.position.y + 60),
			"보유 파편: %d   %s" % [frags, cost_text],
			HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 24, 9, cost_col)

		# 버튼: 장착/해제
		var eq_r := _rune_detail_left_btn_rect()
		var equipped: bool = SaveData.is_rune_equipped(rid)
		var eq_label: String = "해제" if equipped else "장착"
		var eq_bg: Color = Color(0.3, 0.15, 0.15, 0.9) if equipped else Color(0.12, 0.35, 0.12, 0.9)
		var eq_border: Color = Color(0.7, 0.3, 0.3, 0.8) if equipped else Color(0.3, 0.7, 0.3, 0.8)
		draw_rect(eq_r, eq_bg)
		draw_rect(eq_r, eq_border, false, 1.5)
		draw_string(font, Vector2(eq_r.position.x, eq_r.position.y + eq_r.size.y * 0.5 + 5),
			eq_label, HORIZONTAL_ALIGNMENT_CENTER, eq_r.size.x, 11, Color.WHITE)

		# 버튼: 강화
		var up_r := _rune_detail_right_btn_rect()
		var up_bg: Color = Color(0.2, 0.3, 0.1, 0.9) if can_up else Color(0.1, 0.1, 0.1, 0.6)
		var up_border: Color = Color(0.5, 0.8, 0.2, 0.8) if can_up else Color(0.3, 0.3, 0.3, 0.5)
		draw_rect(up_r, up_bg)
		draw_rect(up_r, up_border, false, 1.5)
		var up_label: String = "▲ 강화 +1" if lv < max_lv else "최대 레벨"
		draw_string(font, Vector2(up_r.position.x, up_r.position.y + up_r.size.y * 0.5 + 5),
			up_label, HORIZONTAL_ALIGNMENT_CENTER, up_r.size.x, 11,
			Color.WHITE if can_up else Color(0.4, 0.4, 0.4))
	else:
		# 미제작 룬
		var craft_cost: int = SaveData.get_craft_cost(rid)
		var can_craft: bool = SaveData.can_craft_rune(rid)
		var craft_text: String = "파편 %d / %d" % [frags, craft_cost]
		var craft_col: Color = Color("#aaee66") if can_craft else Color(0.6, 0.4, 0.4)
		draw_string(font, Vector2(pr.position.x + 12, pr.position.y + 60),
			craft_text, HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 24, 9, craft_col)

		# 버튼: 제작
		var craft_r := _rune_detail_left_btn_rect()
		var craft_bg: Color = Color(0.2, 0.2, 0.08, 0.9) if can_craft else Color(0.1, 0.1, 0.1, 0.6)
		var craft_border: Color = Color(0.7, 0.7, 0.2, 0.8) if can_craft else Color(0.3, 0.3, 0.3, 0.5)
		draw_rect(craft_r, craft_bg)
		draw_rect(craft_r, craft_border, false, 1.5)
		draw_string(font, Vector2(craft_r.position.x, craft_r.position.y + craft_r.size.y * 0.5 + 5),
			"✦ 제작 (파편 %d개)" % craft_cost, HORIZONTAL_ALIGNMENT_CENTER, craft_r.size.x, 11,
			Color("#ffee44") if can_craft else Color(0.4, 0.4, 0.4))

	# 닫기
	var cl_r := _rune_detail_close_btn_rect()
	draw_rect(cl_r, Color(0.15, 0.15, 0.2, 0.9))
	draw_rect(cl_r, Color(0.4, 0.4, 0.5, 0.7), false, 1.5)
	draw_string(font, Vector2(cl_r.position.x, cl_r.position.y + cl_r.size.y * 0.5 + 5),
		"닫기", HORIZONTAL_ALIGNMENT_CENTER, cl_r.size.x, 11, Color(0.7, 0.7, 0.75))

func _draw_chest_decision_popup(font: Font) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.65))

	var idx: int = _chest_pending_idx
	if idx < 0 or idx >= SaveData.pending_chests.size(): return

	var ch: Dictionary = SaveData.pending_chests[idx]
	var grade: int = ch.get("grade", 0) as int
	var grade_col: Color = SaveData.RUNE_GRADE_COLORS[grade]
	var grade_name: String = SaveData.RUNE_GRADE_NAMES[grade]
	var open_cost: int = SaveData.CHEST_OPEN_COST[grade]
	var can_open: bool = SaveData.rune_coins >= open_cost

	var pr := _chest_popup_rect()
	draw_rect(pr, Color(0.06, 0.06, 0.1, 0.97))
	draw_rect(pr, grade_col, false, 2.0)

	draw_string(font, Vector2(pr.position.x, pr.position.y + 24),
		"✦  기억의 상자 획득!  ✦",
		HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 14, Color("#f0d060"))
	draw_string(font, Vector2(pr.position.x, pr.position.y + 44),
		"[%s 등급]" % grade_name,
		HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 11, grade_col)

	var frags: Dictionary = ch.get("frags", {}) as Dictionary
	draw_string(font, Vector2(pr.position.x + 20, pr.position.y + 66),
		"내용물:", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.8, 0.9))
	var fy: float = pr.position.y + 82
	for rid in frags:
		if SaveData.RUNE_DEFS.has(rid):
			var def: Array = SaveData.RUNE_DEFS[rid]
			var rc: Color = SaveData.RUNE_GRADE_COLORS[def[1] as int]
			draw_string(font, Vector2(pr.position.x + 28, fy),
				"• %s  ×%d" % [def[0], frags[rid]],
				HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 40, 10, rc)
			fy += 16

	var coin_text: String = "오픈 비용: 주화 %d개" % open_cost
	var coin_col: Color = Color("#ffcc00") if can_open else Color("#885500")
	draw_string(font, Vector2(pr.position.x + 20, pr.position.y + pr.size.y - 56),
		coin_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, coin_col)
	if not can_open:
		draw_string(font, Vector2(pr.position.x + 20, pr.position.y + pr.size.y - 44),
			"주화 부족 — 보관 후 나중에 열 수 있습니다.",
			HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - 40, 9, Color(0.6, 0.5, 0.4))

	var open_btn := Rect2(pr.position.x + 30, pr.end.y - 40, 150, 28)
	var store_btn := Rect2(pr.end.x - 180, pr.end.y - 40, 150, 28)

	var ob_bg: Color = Color(0.15, 0.35, 0.1, 0.9) if can_open else Color(0.1, 0.1, 0.1, 0.6)
	var ob_border: Color = Color(0.3, 0.7, 0.2, 0.8) if can_open else Color(0.3, 0.3, 0.3, 0.4)
	draw_rect(open_btn, ob_bg)
	draw_rect(open_btn, ob_border, false, 1.5)
	draw_string(font, Vector2(open_btn.position.x, open_btn.position.y + open_btn.size.y * 0.5 + 5),
		"열기 (주화 %d)" % open_cost, HORIZONTAL_ALIGNMENT_CENTER, open_btn.size.x, 11,
		Color.WHITE if can_open else Color(0.4, 0.4, 0.4))

	draw_rect(store_btn, Color(0.1, 0.15, 0.25, 0.9))
	draw_rect(store_btn, Color(0.3, 0.4, 0.6, 0.7), false, 1.5)
	draw_string(font, Vector2(store_btn.position.x, store_btn.position.y + store_btn.size.y * 0.5 + 5),
		"보관", HORIZONTAL_ALIGNMENT_CENTER, store_btn.size.x, 11, Color(0.8, 0.85, 1.0))

func _draw_chest_result_popup(font: Font, result: Dictionary) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.65))

	var pw: float = 420.0; var ph: float = 220.0
	var px: float = (W - pw) * 0.5; var py: float = (H - ph) * 0.5

	var grade: int = result.get("grade", 0) as int
	var grade_col: Color = SaveData.RUNE_GRADE_COLORS[grade]
	var grade_name: String = SaveData.RUNE_GRADE_NAMES[grade]

	draw_rect(Rect2(px, py, pw, ph), Color(0.06, 0.06, 0.1, 0.97))
	draw_rect(Rect2(px, py, pw, ph), grade_col, false, 2.0)

	draw_string(font, Vector2(px, py + 22),
		"✦  상자 오픈!  ✦",
		HORIZONTAL_ALIGNMENT_CENTER, pw, 14, Color("#f0d060"))
	draw_string(font, Vector2(px, py + 40),
		"[%s 등급]" % grade_name,
		HORIZONTAL_ALIGNMENT_CENTER, pw, 11, grade_col)

	var frags: Dictionary = result.get("frags", {}) as Dictionary
	draw_string(font, Vector2(px + 20, py + 58),
		"룬 파편 획득:", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.8, 0.9))
	var fy: float = py + 74
	for rid in frags:
		if SaveData.RUNE_DEFS.has(rid):
			var def: Array = SaveData.RUNE_DEFS[rid]
			var rc: Color = SaveData.RUNE_GRADE_COLORS[def[1] as int]
			draw_string(font, Vector2(px + 28, fy),
				"• %s  ×%d" % [def[0], frags[rid]],
				HORIZONTAL_ALIGNMENT_LEFT, pw - 40, 10, rc)
			fy += 16

	# 확인 버튼 (상점 결과 vs 상자 오픈 결과 공용)
	var ok_btn: Rect2
	if not _shop_result.is_empty():
		ok_btn = _shop_result_ok_rect()
	else:
		ok_btn = Rect2(px + (pw - 100) * 0.5, py + ph - 40, 100, 28)
	draw_rect(ok_btn, Color(0.15, 0.4, 0.15, 0.9))
	draw_rect(ok_btn, Color(0.4, 0.7, 0.4, 0.8), false, 1.5)
	draw_string(font, Vector2(ok_btn.position.x, ok_btn.position.y + ok_btn.size.y * 0.5 + 5),
		"확인", HORIZONTAL_ALIGNMENT_CENTER, ok_btn.size.x, 12, Color.WHITE)

# ── XP 마일스톤 헬퍼 ─────────────────────────────────────────────────────────

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
