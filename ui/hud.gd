extends Control
class_name HUD

const W := 854
const H := 480
const ATLAS_TILE := 64
const TILESET = preload("res://assets/sprites/doodle-rogue/tiles-64.png")

const BAR_H    := 70
const SLOT_SZ  := 54   # 스킬 버튼
const WAIT_SZ  := 44
const EQUIP_SZ := 50   # 하단바 장착 슬롯
const BAG_W    := 58   # 가방 버튼 폭
const EQUIP_GAP := 4
const INV_COUNT := 10

# 가방 팝업 내 슬롯 크기
const BAG_EQUIP_SZ := 60
const BAG_INV_SZ   := 50

signal wait_requested
signal home_requested
signal item_action(idx: int, action: String)
signal unequip_requested(slot: String)
signal throw_cancelled
signal craft_recipe_selected(recipe_idx: int)
signal campfire_action(action: String)       # "camp" | "cook" | "cancel"
signal campfire_cook_selected(item_idx: int) # 선택한 식량의 인벤 인덱스

var hp := 20
var max_hp := 20
var mp := 30
var max_mp := 30
var hunger := 0
var fatigue := 0
var floor_num := 1
var level := 1
var atk := 5
var def_ := 1

var log_messages: Array[String] = []
const MAX_LOGS := 3

var _popup_visible := false
var _popup_message := ""
var _popup_confirm_cb: Callable
var _popup_cancel_cb: Callable

var _game_over_visible := false
var _clear_visible := false

var _inventory_items: Array[Item] = []
var _inventory_identified: Array = []

var _equipped_weapon: Item = null
var _equipped_shield: Item = null
var _equipped_armor: Item  = null

var _bag_visible := false

var _action_popup_visible := false
var _action_item_idx := -1

var _equip_action_visible := false
var _equip_action_slot := ""

var _throw_mode := false
var _craft_visible := false

var _campfire_popup_visible := false
var _cook_popup_visible := false
var _cook_popup_indices: Array[int] = []

func update_stats(p_hp: int, p_max_hp: int, p_mp: int, p_max_mp: int,
		p_hunger: int, p_fatigue: int, p_floor: int,
		p_level: int = 1, p_atk: int = 5, p_def: int = 1) -> void:
	hp = p_hp; max_hp = p_max_hp
	mp = p_mp; max_mp = p_max_mp
	hunger = p_hunger; fatigue = p_fatigue
	floor_num = p_floor; level = p_level
	atk = p_atk; def_ = p_def
	queue_redraw()

func update_inventory(items: Array[Item], identified: Array) -> void:
	_inventory_items = items
	_inventory_identified = identified
	queue_redraw()

func update_equipped(weapon: Item, shield: Item, armor: Item) -> void:
	_equipped_weapon = weapon
	_equipped_shield = shield
	_equipped_armor  = armor
	queue_redraw()

func add_log(msg: String) -> void:
	log_messages.append(msg)
	if log_messages.size() > MAX_LOGS:
		log_messages.pop_front()
	queue_redraw()

func show_confirm(msg: String, confirm_cb: Callable, cancel_cb: Callable) -> void:
	_popup_message = msg
	_popup_confirm_cb = confirm_cb
	_popup_cancel_cb = cancel_cb
	_popup_visible = true
	queue_redraw()

func hide_popup() -> void:
	_popup_visible = false
	queue_redraw()

func show_game_over() -> void:
	_game_over_visible = true
	queue_redraw()

func hide_game_over() -> void:
	_game_over_visible = false
	queue_redraw()

func show_game_clear() -> void:
	_clear_visible = true
	queue_redraw()

func close_inventory() -> void:
	_action_popup_visible = false
	_equip_action_visible = false
	_bag_visible = false
	queue_redraw()

func is_any_popup_open() -> bool:
	return _popup_visible or _bag_visible or _action_popup_visible or \
		_equip_action_visible or _craft_visible or \
		_campfire_popup_visible or _cook_popup_visible

func set_throw_mode(active: bool) -> void:
	_throw_mode = active
	queue_redraw()

func show_campfire_popup() -> void:
	_campfire_popup_visible = true
	queue_redraw()

func show_cook_popup(food_indices: Array[int]) -> void:
	_cook_popup_indices = food_indices
	_cook_popup_visible = true
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

# ── Input ──────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position

	if _throw_mode:
		if _throw_cancel_rect().has_point(p):
			_throw_mode = false
			queue_redraw()
			throw_cancelled.emit()
			get_viewport().set_input_as_handled()
		return

	if _game_over_visible or _clear_visible:
		if _overlay_btn_rect().has_point(p):
			home_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if _popup_visible:
		if _popup_confirm_rect().has_point(p):
			_popup_visible = false
			queue_redraw()
			_popup_confirm_cb.call()
		elif _popup_cancel_rect().has_point(p):
			_popup_visible = false
			queue_redraw()
			_popup_cancel_cb.call()
		get_viewport().set_input_as_handled()
		return

	if _cook_popup_visible:
		var cook_pr := _cook_popup_rect()
		if cook_pr.has_point(p):
			for i in _cook_popup_indices.size():
				if _cook_item_rect(i, cook_pr).has_point(p):
					var inv_idx: int = _cook_popup_indices[i]
					_cook_popup_visible = false
					queue_redraw()
					campfire_cook_selected.emit(inv_idx)
					get_viewport().set_input_as_handled()
					return
		_cook_popup_visible = false
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if _campfire_popup_visible:
		if _campfire_btn_camp_rect().has_point(p):
			_campfire_popup_visible = false
			queue_redraw()
			campfire_action.emit("camp")
		elif _campfire_btn_cook_rect().has_point(p):
			_campfire_popup_visible = false
			queue_redraw()
			campfire_action.emit("cook")
		else:
			_campfire_popup_visible = false
			queue_redraw()
			campfire_action.emit("cancel")
		get_viewport().set_input_as_handled()
		return

	if _craft_visible:
		var pr := _craft_popup_rect()
		if pr.has_point(p):
			for i in Item.RECIPES.size():
				if _craft_recipe_rect(i).has_point(p):
					if _can_craft(i):
						_craft_visible = false
						queue_redraw()
						craft_recipe_selected.emit(i)
					else:
						add_log("재료가 부족합니다.")
					get_viewport().set_input_as_handled()
					return
		_craft_visible = false
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if _equip_action_visible:
		if _equip_action_unequip_rect().has_point(p):
			var slot := _equip_action_slot
			_equip_action_visible = false
			_bag_visible = false
			queue_redraw()
			unequip_requested.emit(slot)
		else:
			_equip_action_visible = false
			queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if _action_popup_visible:
		var _cur_item: Item = _inventory_items[_action_item_idx] if _action_item_idx < _inventory_items.size() else null
		var _is_equip: bool = _cur_item != null and _cur_item.is_equipment()
		if _action_use_rect().has_point(p):
			_action_popup_visible = false
			_bag_visible = false
			queue_redraw()
			item_action.emit(_action_item_idx, "equip" if _is_equip else "use")
		elif _action_throw_rect().has_point(p):
			_action_popup_visible = false
			_bag_visible = false
			queue_redraw()
			item_action.emit(_action_item_idx, "throw")
		elif _action_discard_rect().has_point(p):
			_action_popup_visible = false
			_bag_visible = false
			queue_redraw()
			item_action.emit(_action_item_idx, "discard")
		else:
			_action_popup_visible = false
			queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if _bag_visible:
		var pr := _bag_popup_rect()
		if pr.has_point(p):
			# 장착 슬롯 클릭
			var equip_slots: Array[String] = ["weapon", "shield", "armor"]
			var equip_items: Array[Item] = [_equipped_weapon, _equipped_shield, _equipped_armor]
			for i in 3:
				if _bag_equip_slot_rect(i).has_point(p):
					if equip_items[i] != null:
						_equip_action_slot = equip_slots[i]
						_equip_action_visible = true
						queue_redraw()
					get_viewport().set_input_as_handled()
					return
			# 인벤토리 슬롯 클릭
			for i in INV_COUNT:
				if _bag_inv_slot_rect(i).has_point(p) and i < _inventory_items.size():
					_action_item_idx = i
					_action_popup_visible = true
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
		else:
			_bag_visible = false
			queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if _wait_btn_rect().has_point(p):
		wait_requested.emit()
		get_viewport().set_input_as_handled()
		return

	# 하단바 장착 슬롯 클릭 → 가방 팝업
	for i in 3:
		if _equip_bar_slot_rect(i).has_point(p):
			_bag_visible = true
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	# 가방 버튼
	if _bag_btn_rect().has_point(p):
		_bag_visible = true
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	# 제작
	if _skill_slot_rect(1).has_point(p):
		_craft_visible = true
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

# ── Draw ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_top_left()
	_draw_bottom_bar()
	if _throw_mode:
		_draw_throw_cancel()
	if _craft_visible:
		_draw_craft_popup()
	if _bag_visible:
		_draw_bag_popup()
	if _equip_action_visible:
		_draw_equip_action_popup()
	if _action_popup_visible:
		_draw_action_popup()
	if _campfire_popup_visible:
		_draw_campfire_popup()
	if _cook_popup_visible:
		_draw_cook_popup()
	if _popup_visible:
		_draw_popup()
	if _game_over_visible:
		_draw_game_over()
	if _clear_visible:
		_draw_game_clear()

func _draw_top_left() -> void:
	var font := ThemeDB.fallback_font
	var pad := 10
	var bar_w := 190
	var bar_h := 11
	var gap := 4
	var panel_h := pad * 2 + 18 + (bar_h + gap) * 3 + 14
	draw_rect(Rect2(0, 0, bar_w + pad * 2 + 4, panel_h), Color(0, 0, 0, 0.55))

	var hx := pad + 4
	var hy := pad

	draw_string(font, Vector2(hx, hy + 10),
		"Lv.%d  ATK:%d  DEF:%d" % [level, atk, def_],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f0c060"))

	hy += 18
	draw_rect(Rect2(hx, hy, bar_w, bar_h), Color("#3a0000"))
	draw_rect(Rect2(hx, hy, bar_w * float(hp) / float(max(1, max_hp)), bar_h), Color("#cc2222"))
	draw_string(font, Vector2(hx + 4, hy + bar_h - 1), "❤ %d / %d" % [hp, max_hp],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)

	hy += bar_h + gap
	draw_rect(Rect2(hx, hy, bar_w, bar_h), Color("#001a3a"))
	draw_rect(Rect2(hx, hy, bar_w * float(mp) / float(max(1, max_mp)), bar_h), Color("#2266cc"))
	draw_string(font, Vector2(hx + 4, hy + bar_h - 1), "✦ %d / %d" % [mp, max_mp],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)

	hy += bar_h + gap
	var satiety := float(max(0, 600 - hunger)) / 600.0
	var h_color := Color("#55aa00") if satiety > 0.4 else (Color("#aaaa00") if satiety > 0.15 else Color("#aa3300"))
	draw_rect(Rect2(hx, hy, bar_w, bar_h), Color("#1a1a00"))
	draw_rect(Rect2(hx, hy, bar_w * satiety, bar_h), h_color)
	draw_string(font, Vector2(hx + 4, hy + bar_h - 1), "🍖 배고픔 %d" % hunger,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)

	hy += bar_h + gap + 2
	var fatigue_color := Color(0.8, 0.8, 0.8) if fatigue < 450 else \
		(Color(1.0, 0.8, 0.3) if fatigue < 600 else Color(1.0, 0.3, 0.3))
	draw_string(font, Vector2(hx, hy + 10), "피로도: %d / 600" % fatigue,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fatigue_color)

func _draw_bottom_bar() -> void:
	var font := ThemeDB.fallback_font
	var y := H - BAR_H

	for i in log_messages.size():
		var alpha := 0.4 + 0.6 * (float(i + 1) / log_messages.size())
		var ly := y - (log_messages.size() - i) * 16
		draw_string(font, Vector2(14, ly),
			log_messages[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(1.0, 0.95, 0.4, alpha))

	draw_rect(Rect2(0, y, W, BAR_H), Color(0, 0, 0, 0.65))
	draw_line(Vector2(0, y), Vector2(W, y), Color(0.4, 0.4, 0.4, 0.6))

	# 대기 버튼
	var r := _wait_btn_rect()
	draw_rect(r, Color(0.2, 0.2, 0.2, 0.9))
	draw_rect(r, Color(0.5, 0.5, 0.5, 0.8), false)
	draw_string(font, Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5 + 5),
		"대기", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)

	# 층 표시
	draw_string(font, Vector2(8 + WAIT_SZ + 6, y + BAR_H * 0.5 + 5),
		"%d층" % floor_num, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#f0d060"))

	# 하단바 장착 슬롯 3개
	var equip_labels := ["무기", "방패", "갑옷"]
	var equip_items: Array[Item] = [_equipped_weapon, _equipped_shield, _equipped_armor]
	for i in 3:
		var sr := _equip_bar_slot_rect(i)
		var item: Item = equip_items[i]
		var has_item: bool = item != null
		draw_rect(sr, Color(0.2, 0.25, 0.2, 0.9) if has_item else Color(0.12, 0.12, 0.15, 0.85))
		draw_rect(sr, Color(0.5, 0.7, 0.5, 0.85) if has_item else Color(0.28, 0.28, 0.3, 0.6), false)
		if has_item:
			var atlas: Vector2i = item.get_atlas()
			var src := Rect2(atlas.x * ATLAS_TILE, atlas.y * ATLAS_TILE, ATLAS_TILE, ATLAS_TILE)
			var img_size := 22.0
			var img_rect := Rect2(
				sr.position.x + (sr.size.x - img_size) * 0.5,
				sr.position.y + 3, img_size, img_size)
			draw_texture_rect_region(TILESET, img_rect, src, item.get_modulate())
			draw_string(font, Vector2(sr.position.x, sr.end.y - 3),
				equip_labels[i], HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 7, Color(0.7, 1.0, 0.7))
		else:
			draw_string(font, Vector2(sr.position.x, sr.position.y + sr.size.y * 0.5 + 5),
				equip_labels[i], HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 8, Color(0.35, 0.35, 0.38))

	# 가방 버튼
	var br := _bag_btn_rect()
	draw_rect(br, Color(0.12, 0.14, 0.22, 0.9))
	draw_rect(br, Color(0.4, 0.5, 0.75, 0.85), false, 1.5)
	draw_string(font, Vector2(br.position.x + br.size.x * 0.5, br.position.y + br.size.y * 0.5 + 5),
		"가방", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.7, 0.85, 1.0))

	# 스킬1 슬롯
	var sk0 := _skill_slot_rect(0)
	draw_rect(sk0, Color(0.15, 0.15, 0.15, 0.8))
	draw_rect(sk0, Color(0.45, 0.4, 0.2, 0.8), false)
	draw_string(font, Vector2(sk0.position.x + sk0.size.x * 0.5, sk0.position.y + sk0.size.y * 0.5 + 5),
		"스킬1", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.7, 0.7, 0.7))
	# 제작 버튼
	var ck := _skill_slot_rect(1)
	draw_rect(ck, Color(0.08, 0.18, 0.10, 0.9))
	draw_rect(ck, Color(0.35, 0.75, 0.35, 0.85), false, 1.5)
	draw_string(font, Vector2(ck.position.x + ck.size.x * 0.5, ck.position.y + ck.size.y * 0.5 + 5),
		"제작", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.6, 1.0, 0.6))

func _draw_bag_popup() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5))
	var pr := _bag_popup_rect()
	draw_rect(pr, Color(0.06, 0.08, 0.12, 0.97))
	draw_rect(pr, Color(0.45, 0.55, 0.75, 0.75), false, 1.5)

	# 제목
	draw_string(font, Vector2(pr.position.x, pr.position.y + 22),
		"가  방", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 14, Color("#b0ccf0"))

	# 장착 섹션 라벨
	draw_string(font, Vector2(pr.position.x + 10, pr.position.y + 40),
		"◆ 장착 중", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.85, 0.55))

	# 장착 슬롯 3개
	var equip_labels := ["무기", "방패", "갑옷"]
	var equip_items: Array[Item] = [_equipped_weapon, _equipped_shield, _equipped_armor]
	for i in 3:
		var r := _bag_equip_slot_rect(i)
		var item: Item = equip_items[i]
		var has_item: bool = item != null
		draw_rect(r, Color(0.2, 0.26, 0.2, 0.9) if has_item else Color(0.1, 0.1, 0.12, 0.8))
		draw_rect(r, Color(0.5, 0.75, 0.5, 0.85) if has_item else Color(0.22, 0.22, 0.25, 0.5), false)
		draw_string(font, Vector2(r.position.x, r.position.y + 10),
			equip_labels[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Color(0.55, 0.7, 0.55))
		if has_item:
			var atlas: Vector2i = item.get_atlas()
			var src := Rect2(atlas.x * ATLAS_TILE, atlas.y * ATLAS_TILE, ATLAS_TILE, ATLAS_TILE)
			var img_size := 26.0
			var img_rect := Rect2(
				r.position.x + (r.size.x - img_size) * 0.5,
				r.position.y + 16, img_size, img_size)
			draw_texture_rect_region(TILESET, img_rect, src, item.get_modulate())
			draw_string(font, Vector2(r.position.x, r.end.y + 11),
				item.get_display_name(true), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 7,
				Color(0.85, 1.0, 0.85))
			var stat := item.get_stat_label()
			if stat != "":
				draw_string(font, Vector2(r.position.x, r.end.y + 21),
					stat, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 7, Color("#f0c040"))
		else:
			draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 5),
				"없음", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Color(0.28, 0.28, 0.3))

	# 구분선
	var div_y := pr.position.y + 140
	draw_line(Vector2(pr.position.x + 10, div_y), Vector2(pr.end.x - 10, div_y),
		Color(0.3, 0.35, 0.45, 0.7))

	# 인벤토리 섹션 라벨
	draw_string(font, Vector2(pr.position.x + 10, pr.position.y + 154),
		"◆ 가방", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.75, 0.5))

	# 인벤토리 슬롯 5×2
	for i in INV_COUNT:
		var r := _bag_inv_slot_rect(i)
		var has_item: bool = i < _inventory_items.size()
		draw_rect(r, Color(0.15, 0.15, 0.2, 0.9))
		draw_rect(r, Color(0.4, 0.35, 0.2, 0.8) if has_item else Color(0.22, 0.22, 0.25, 0.5), false)
		if has_item:
			var item: Item = _inventory_items[i]
			var identified: bool = item.item_type != Item.Type.FOOD \
				and item.color_idx < _inventory_identified.size() \
				and _inventory_identified[item.color_idx]
			var atlas: Vector2i = item.get_atlas()
			var src := Rect2(atlas.x * ATLAS_TILE, atlas.y * ATLAS_TILE, ATLAS_TILE, ATLAS_TILE)
			var stat_label := item.get_stat_label()
			var img_size := 20.0
			var img_rect := Rect2(
				r.position.x + (r.size.x - img_size) * 0.5,
				r.position.y + 2, img_size, img_size)
			draw_texture_rect_region(TILESET, img_rect, src, item.get_modulate())
			if stat_label != "":
				draw_string(font, Vector2(r.position.x, r.end.y - 11),
					item.get_display_name(identified),
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 6, Color(0.9, 0.9, 0.9))
				draw_string(font, Vector2(r.position.x, r.end.y - 2),
					stat_label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 6, Color("#f0c040"))
			else:
				draw_string(font, Vector2(r.position.x, r.end.y - 3),
					item.get_display_name(identified),
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 6, Color(0.9, 0.9, 0.9))

	# 하단 안내
	draw_string(font, Vector2(pr.position.x, pr.end.y - 8),
		"영역 밖 터치로 닫기", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 8, Color(0.32, 0.32, 0.35))

func _draw_equip_action_popup() -> void:
	var font := ThemeDB.fallback_font
	var pw := 180.0; var ph := 90.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	draw_rect(Rect2(px, py, pw, ph), Color(0.05, 0.07, 0.10, 0.97))
	draw_rect(Rect2(px, py, pw, ph), Color(0.5, 0.65, 0.5, 0.9), false)
	var slot_name: String = {"weapon": "무기", "shield": "방패", "armor": "갑옷"}.get(_equip_action_slot, "?")
	draw_string(font, Vector2(px + 8, py + 22), slot_name + " 해제하기",
		HORIZONTAL_ALIGNMENT_CENTER, pw - 16, 12, Color("#f0d060"))
	var r := _equip_action_unequip_rect()
	draw_rect(r, Color(0.14, 0.38, 0.14, 0.95))
	draw_rect(r, Color(0.3, 0.62, 0.3, 0.7), false)
	draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 5),
		"해제", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color.WHITE)

func _draw_popup() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))

	var pw := 280.0; var ph := 110.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5

	draw_rect(Rect2(px, py, pw, ph), Color(0.06, 0.06, 0.09, 0.97))
	draw_rect(Rect2(px, py, pw, ph), Color(0.5, 0.5, 0.5, 0.6), false)
	draw_string(font, Vector2(px, py + 36), _popup_message,
		HORIZONTAL_ALIGNMENT_CENTER, pw, 12, Color(0.95, 0.95, 0.95))

	var cr := _popup_confirm_rect()
	draw_rect(cr, Color(0.14, 0.4, 0.14, 0.95))
	draw_rect(cr, Color(0.3, 0.62, 0.3, 0.7), false)
	draw_string(font, Vector2(cr.position.x, cr.position.y + cr.size.y * 0.5 + 5),
		"확인", HORIZONTAL_ALIGNMENT_CENTER, cr.size.x, 12, Color.WHITE)

	var ccr := _popup_cancel_rect()
	draw_rect(ccr, Color(0.36, 0.1, 0.1, 0.95))
	draw_rect(ccr, Color(0.58, 0.2, 0.2, 0.7), false)
	draw_string(font, Vector2(ccr.position.x, ccr.position.y + ccr.size.y * 0.5 + 5),
		"취소", HORIZONTAL_ALIGNMENT_CENTER, ccr.size.x, 12, Color.WHITE)

func _draw_campfire_popup() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5))
	var pw := 280.0; var ph := 130.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	draw_rect(Rect2(px, py, pw, ph), Color(0.07, 0.05, 0.03, 0.97))
	draw_rect(Rect2(px, py, pw, ph), Color(0.85, 0.5, 0.1, 0.75), false, 1.5)
	draw_string(font, Vector2(px, py + 36), "모닥불 앞에 있습니다.",
		HORIZONTAL_ALIGNMENT_CENTER, pw, 13, Color(0.95, 0.85, 0.5))
	var rc := _campfire_btn_camp_rect()
	draw_rect(rc, Color(0.1, 0.35, 0.1, 0.95))
	draw_rect(rc, Color(0.3, 0.65, 0.3, 0.7), false)
	draw_string(font, Vector2(rc.position.x, rc.position.y + rc.size.y * 0.5 + 5),
		"야영", HORIZONTAL_ALIGNMENT_CENTER, rc.size.x, 12, Color.WHITE)
	var rk := _campfire_btn_cook_rect()
	draw_rect(rk, Color(0.35, 0.18, 0.05, 0.95))
	draw_rect(rk, Color(0.85, 0.45, 0.1, 0.7), false)
	draw_string(font, Vector2(rk.position.x, rk.position.y + rk.size.y * 0.5 + 5),
		"요리", HORIZONTAL_ALIGNMENT_CENTER, rk.size.x, 12, Color.WHITE)
	var rx := Rect2(px + pw - 76, py + ph - 44, 60, 30)
	draw_rect(rx, Color(0.3, 0.08, 0.08, 0.95))
	draw_rect(rx, Color(0.55, 0.2, 0.2, 0.7), false)
	draw_string(font, Vector2(rx.position.x, rx.position.y + rx.size.y * 0.5 + 5),
		"취소", HORIZONTAL_ALIGNMENT_CENTER, rx.size.x, 12, Color.WHITE)

func _draw_cook_popup() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))
	var pr := _cook_popup_rect()
	draw_rect(pr, Color(0.07, 0.05, 0.03, 0.97))
	draw_rect(pr, Color(0.85, 0.5, 0.1, 0.75), false, 1.5)
	draw_string(font, Vector2(pr.position.x, pr.position.y + 22),
		"요리  (모닥불)", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 13, Color("#f0a030"))
	for i in _cook_popup_indices.size():
		var inv_idx: int = _cook_popup_indices[i]
		var item: Item = _inventory_items[inv_idx]
		var r := _cook_item_rect(i, pr)
		draw_rect(r, Color(0.2, 0.14, 0.06, 0.92))
		draw_rect(r, Color(0.7, 0.42, 0.1, 0.7), false)
		draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 5),
			item.get_display_name(true), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11,
			Color(0.95, 0.85, 0.6))
	draw_string(font, Vector2(pr.position.x, pr.end.y - 7),
		"영역 밖 터치로 취소", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 8, Color(0.32, 0.32, 0.35))

func _draw_craft_popup() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))
	var pr := _craft_popup_rect()
	draw_rect(pr, Color(0.05, 0.09, 0.06, 0.97))
	draw_rect(pr, Color(0.35, 0.7, 0.35, 0.75), false, 1.5)
	draw_string(font, Vector2(pr.position.x, pr.position.y + 22),
		"제  작", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 14, Color("#80e880"))
	for i in Item.RECIPES.size():
		var recipe: Array = Item.RECIPES[i]
		var mats: Array = recipe[2]
		var can: bool = _can_craft(i)
		var r := _craft_recipe_rect(i)
		draw_rect(r, Color(0.12, 0.22, 0.12, 0.9) if can else Color(0.10, 0.10, 0.10, 0.7))
		draw_rect(r, Color(0.4, 0.65, 0.4, 0.75) if can else Color(0.25, 0.25, 0.25, 0.4), false)
		var mat_str := ""
		for mat in mats:
			if mat_str != "": mat_str += " + "
			var have: int = _count_mat(mat[0])
			var need: int = mat[1]
			var cnt_color := "" if can else " (%d/%d)" % [have, need]
			mat_str += "%s×%d%s" % [Item.get_type_name(mat[0]), need, cnt_color]
		var label := "%s  ←  %s" % [Item.get_type_name(recipe[0]), mat_str]
		var lc := Color(0.9, 1.0, 0.85) if can else Color(0.5, 0.5, 0.5)
		draw_string(font, Vector2(r.position.x + 10, r.position.y + r.size.y * 0.5 + 5),
			label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 11, lc)
	draw_string(font, Vector2(pr.position.x, pr.end.y - 7),
		"영역 밖 터치로 닫기", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 8, Color(0.35, 0.35, 0.35))

func _draw_action_popup() -> void:
	var font := ThemeDB.fallback_font
	var pw := 180.0; var ph := 130.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5

	draw_rect(Rect2(px, py, pw, ph), Color(0.05, 0.05, 0.08, 0.97))
	draw_rect(Rect2(px, py, pw, ph), Color(0.6, 0.5, 0.3, 0.9), false)

	var item_name := ""
	if _action_item_idx >= 0 and _action_item_idx < _inventory_items.size():
		var item: Item = _inventory_items[_action_item_idx]
		var identified := false
		if item.item_type != Item.Type.FOOD and item.color_idx < _inventory_identified.size():
			identified = _inventory_identified[item.color_idx]
		item_name = item.get_display_name(identified)
	draw_string(font, Vector2(px + 8, py + 20), item_name,
		HORIZONTAL_ALIGNMENT_CENTER, pw - 16, 12, Color("#f0d060"))

	var _ai := _action_item_idx
	var _it: Item = _inventory_items[_ai] if _ai < _inventory_items.size() else null
	var _use_label := "장착" if (_it != null and _it.is_equipment()) else "먹기 / 사용"
	_draw_action_btn(_action_use_rect(),     _use_label, Color(0.14, 0.4,  0.14, 0.95))
	_draw_action_btn(_action_throw_rect(),   "던지기",    Color(0.14, 0.25, 0.4,  0.95))
	_draw_action_btn(_action_discard_rect(), "버리기",    Color(0.36, 0.1,  0.1,  0.95))

func _draw_action_btn(r: Rect2, label: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(r, color)
	draw_rect(r, Color(0.6, 0.6, 0.6, 0.5), false)
	draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 5),
		label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color.WHITE)

func _draw_game_over() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.75))
	draw_string(font, Vector2(W * 0.5, H * 0.5 - 20), "게 임 오 버",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color("#cc3333"))
	var r := _overlay_btn_rect()
	draw_rect(r, Color(0.25, 0.25, 0.25, 0.9))
	draw_rect(r, Color(0.6, 0.6, 0.6, 0.8), false)
	draw_string(font, Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5 + 5),
		"홈으로", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)

func _draw_game_clear() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.75))
	draw_string(font, Vector2(W * 0.5, H * 0.5 - 20), "클 리 어 !",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color("#f0d060"))
	var r := _overlay_btn_rect()
	draw_rect(r, Color(0.25, 0.25, 0.25, 0.9))
	draw_rect(r, Color(0.6, 0.6, 0.6, 0.8), false)
	draw_string(font, Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5 + 5),
		"홈으로", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)

func _draw_throw_cancel() -> void:
	var font := ThemeDB.fallback_font
	var r := _throw_cancel_rect()
	draw_rect(r, Color(0.5, 0.1, 0.1, 0.92))
	draw_rect(r, Color(0.9, 0.3, 0.3, 0.9), false, 2.0)
	draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 5),
		"취소", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color.WHITE)

# ── Rects ──────────────────────────────────────────────────────────────────

func _wait_btn_rect() -> Rect2:
	var y := H - BAR_H + (BAR_H - WAIT_SZ) / 2
	return Rect2(8, y, WAIT_SZ, WAIT_SZ)

func _equip_bar_slot_rect(i: int) -> Rect2:
	var y := H - BAR_H + (BAR_H - EQUIP_SZ) / 2
	var start_x := 8 + WAIT_SZ + 38  # 대기(44) + 층수 공간(38) = 90
	return Rect2(start_x + i * (EQUIP_SZ + EQUIP_GAP), y, EQUIP_SZ, EQUIP_SZ)

func _bag_btn_rect() -> Rect2:
	var y := H - BAR_H + (BAR_H - EQUIP_SZ) / 2
	var start_x := 8 + WAIT_SZ + 38
	var after_equips := start_x + 3 * (EQUIP_SZ + EQUIP_GAP)
	return Rect2(after_equips + 4, y, BAG_W, EQUIP_SZ)

func _skill_slot_rect(i: int) -> Rect2:
	var skill_left := W - 8 - 2 * SLOT_SZ - 6
	var y := H - BAR_H + (BAR_H - SLOT_SZ) / 2
	return Rect2(skill_left + i * (SLOT_SZ + 6), y, SLOT_SZ, SLOT_SZ)

func _throw_cancel_rect() -> Rect2:
	return Rect2(W - SLOT_SZ - 6, 6, SLOT_SZ, SLOT_SZ)

func _popup_confirm_rect() -> Rect2:
	var pw := 280.0; var ph := 110.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	return Rect2(px + pw - 116, py + ph - 44, 100, 30)

func _popup_cancel_rect() -> Rect2:
	var pw := 280.0; var ph := 110.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	return Rect2(px + 16, py + ph - 44, 100, 30)

func _overlay_btn_rect() -> Rect2:
	return Rect2(W * 0.5 - 70, H * 0.5 + 20, 140, 34)

func _action_use_rect() -> Rect2:
	var pw := 180.0; var ph := 130.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	return Rect2(px + 12, py + 34, pw - 24, 26)

func _action_throw_rect() -> Rect2:
	var pw := 180.0; var ph := 130.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	return Rect2(px + 12, py + 64, pw - 24, 26)

func _action_discard_rect() -> Rect2:
	var pw := 180.0; var ph := 130.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	return Rect2(px + 12, py + 94, pw - 24, 26)

func _equip_action_unequip_rect() -> Rect2:
	var pw := 180.0; var ph := 90.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	return Rect2(px + 12, py + 38, pw - 24, 26)

func _bag_popup_rect() -> Rect2:
	var pw := 360.0
	var ph := 290.0
	return Rect2((W - pw) * 0.5, (H - ph) * 0.5, pw, ph)

func _bag_equip_slot_rect(i: int) -> Rect2:
	var pr := _bag_popup_rect()
	var total_w: float = 3.0 * BAG_EQUIP_SZ + 2.0 * 10.0
	var start_x := pr.position.x + (pr.size.x - total_w) * 0.5
	var start_y := pr.position.y + 46
	return Rect2(start_x + i * (BAG_EQUIP_SZ + 10), start_y, BAG_EQUIP_SZ, BAG_EQUIP_SZ)

func _bag_inv_slot_rect(i: int) -> Rect2:
	var pr := _bag_popup_rect()
	var col := i % 5
	var row := i / 5
	var total_w: float = 5.0 * BAG_INV_SZ + 4.0 * 4.0
	var start_x := pr.position.x + (pr.size.x - total_w) * 0.5
	var start_y := pr.position.y + 162
	return Rect2(start_x + col * (BAG_INV_SZ + 4), start_y + row * (BAG_INV_SZ + 4), BAG_INV_SZ, BAG_INV_SZ)

func _craft_popup_rect() -> Rect2:
	var pw := 310.0
	var ph := 36.0 + float(Item.RECIPES.size()) * 42.0 + 22.0
	return Rect2((W - pw) * 0.5, (H - ph) * 0.5, pw, ph)

func _craft_recipe_rect(i: int) -> Rect2:
	var pr := _craft_popup_rect()
	return Rect2(pr.position.x + 8, pr.position.y + 30 + i * 42, pr.size.x - 16, 36)

func _campfire_btn_camp_rect() -> Rect2:
	var pw := 280.0; var ph := 130.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	return Rect2(px + 14, py + ph - 44, 80, 30)

func _campfire_btn_cook_rect() -> Rect2:
	var pw := 280.0; var ph := 130.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	return Rect2(px + pw * 0.5 - 40, py + ph - 44, 80, 30)

func _cook_popup_rect() -> Rect2:
	var pw := 260.0
	var count: int = max(1, _cook_popup_indices.size())
	var ph := 38.0 + count * 40.0 + 18.0
	return Rect2((W - pw) * 0.5, (H - ph) * 0.5, pw, ph)

func _cook_item_rect(i: int, pr: Rect2) -> Rect2:
	return Rect2(pr.position.x + 10, pr.position.y + 30 + i * 40, pr.size.x - 20, 36)

func _count_mat(mat_type: int) -> int:
	var n := 0
	for item in _inventory_items:
		if item.item_type == mat_type:
			n += 1
	return n

func _can_craft(recipe_idx: int) -> bool:
	var mats: Array = Item.RECIPES[recipe_idx][2]
	for mat in mats:
		if _count_mat(mat[0]) < mat[1]:
			return false
	return true
