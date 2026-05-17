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
signal cauldron_material_chosen(inv_idx: int)
signal cauldron_picker_cancelled
signal campfire_action(action: String)       # "camp" | "cook" | "cancel"
signal campfire_cook_selected(item_idx: int) # 선택한 식량의 인벤 인덱스
signal merchant_buy(shop_idx: int)
signal merchant_sell(inv_idx: int)
signal well_item_selected(inv_idx: int)
signal spell_slot_tapped
signal spell_selected(spell_id: String)
signal spell_enhance_selected(spell_id: String)
signal class_skill_tapped

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
var _craft_tab: int = 0  # 0=장비, 1=물약, 2=기타
var _cauldron_picker_visible := false
var _cauldron_is_white := false
var _cauldron_herb_indices: Array[int] = []

var _campfire_popup_visible := false
var _cook_popup_visible := false
var _cook_popup_indices: Array[int] = []

var _merchant_visible := false
var _merchant_sell_mode := false
var _merchant_shop_items: Array[Dictionary] = []   # {item, price, sold}
var _merchant_sell_prices: Array[int] = []

var _well_popup_visible := false
var _well_popup_indices: Array[int] = []   # 우물에 바칠 수 있는 인벤 인덱스

var _spell_popup_visible := false
var _spell_popup_list: Array = []   # [{id, name, mp_cost}] or [{id, name, level}] in enhance mode
var _spell_popup_enhance_mode := false  # true → 강화 선택 팝업

var _class_skill_cooldown: int = 0
var _class_skill_label: String = "스킬"
var _class_skill_mp: int = 30  # 플레이어 현재 MP (그레이아웃 판단용)

var gold: int = 0
var turn_num: int = 0

var _status_poison: int = 0
var _status_fire: int = 0
var _status_sleep: int = 0
var _status_paralyze: int = 0
var _status_frozen: int = 0
var _status_slow: int = 0
var _status_wound: int = 0
var _status_blind: int = 0
var _status_invincible: int = 0

func update_status(p_poison: int, p_fire: int, p_sleep: int,
		p_paralyze: int, p_frozen: int, p_slow: int,
		p_wound: int, p_blind: int, p_invincible: int = 0) -> void:
	_status_poison = p_poison
	_status_fire = p_fire
	_status_sleep = p_sleep
	_status_paralyze = p_paralyze
	_status_frozen = p_frozen
	_status_slow = p_slow
	_status_wound = p_wound
	_status_blind = p_blind
	_status_invincible = p_invincible
	queue_redraw()

func update_stats(p_hp: int, p_max_hp: int, p_mp: int, p_max_mp: int,
		p_hunger: int, p_fatigue: int, p_floor: int,
		p_level: int = 1, p_atk: int = 5, p_def: int = 1, p_gold: int = 0, p_turn: int = 0) -> void:
	hp = p_hp; max_hp = p_max_hp
	mp = p_mp; max_mp = p_max_mp
	hunger = p_hunger; fatigue = p_fatigue
	floor_num = p_floor; level = p_level
	atk = p_atk; def_ = p_def
	gold = p_gold
	turn_num = p_turn
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
		_equip_action_visible or _craft_visible or _cauldron_picker_visible or \
		_campfire_popup_visible or _cook_popup_visible or \
		_merchant_visible or _well_popup_visible or _spell_popup_visible

func show_cauldron_picker(herb_inv_indices: Array[int], is_white: bool) -> void:
	_cauldron_herb_indices = herb_inv_indices
	_cauldron_is_white = is_white
	_cauldron_picker_visible = true
	queue_redraw()

func set_throw_mode(active: bool) -> void:
	_throw_mode = active
	queue_redraw()

func show_spell_popup(spells: Array) -> void:
	_spell_popup_list = spells
	_spell_popup_enhance_mode = false
	_spell_popup_visible = true
	queue_redraw()

func show_spell_enhance_popup(spells: Array) -> void:
	_spell_popup_list = spells
	_spell_popup_enhance_mode = true
	_spell_popup_visible = true
	queue_redraw()

func close_spell_popup() -> void:
	_spell_popup_visible = false
	_spell_popup_list = []
	_spell_popup_enhance_mode = false
	queue_redraw()

func show_well_popup(inv_indices: Array[int]) -> void:
	_well_popup_indices = inv_indices
	_well_popup_visible = true
	queue_redraw()

func show_merchant_popup(shop_items: Array[Dictionary], sell_prices: Array[int]) -> void:
	_merchant_visible = true
	_merchant_sell_mode = false
	_merchant_shop_items = shop_items
	_merchant_sell_prices = sell_prices
	queue_redraw()

func update_merchant_data(shop_items: Array[Dictionary], sell_prices: Array[int]) -> void:
	_merchant_shop_items = shop_items
	_merchant_sell_prices = sell_prices
	queue_redraw()

func close_merchant_popup() -> void:
	_merchant_visible = false
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

	if _well_popup_visible:
		var wpr := _well_popup_rect()
		if wpr.has_point(p):
			for i in _well_popup_indices.size():
				if _well_item_rect(i, wpr).has_point(p):
					var inv_idx: int = _well_popup_indices[i]
					_well_popup_visible = false
					queue_redraw()
					well_item_selected.emit(inv_idx)
					get_viewport().set_input_as_handled()
					return
		_well_popup_visible = false
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if _merchant_visible:
		var mp := _merchant_panel_rect()
		if _merchant_close_btn_rect(mp).has_point(p):
			_merchant_visible = false
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if _merchant_toggle_btn_rect(mp).has_point(p):
			_merchant_sell_mode = not _merchant_sell_mode
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if _merchant_sell_mode:
			for i in _inventory_items.size():
				if _merchant_row_rect(mp, i).has_point(p):
					var act_btn := _merchant_action_btn_rect(mp, i)
					if act_btn.has_point(p):
						merchant_sell.emit(i)
					get_viewport().set_input_as_handled()
					return
		else:
			for i in _merchant_shop_items.size():
				if _merchant_row_rect(mp, i).has_point(p):
					var act_btn := _merchant_action_btn_rect(mp, i)
					var d: Dictionary = _merchant_shop_items[i]
					if act_btn.has_point(p) and not d.sold:
						merchant_buy.emit(i)
					get_viewport().set_input_as_handled()
					return
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

	if _spell_popup_visible:
		var spr := _spell_popup_rect()
		if spr.has_point(p):
			for i in _spell_popup_list.size():
				if _spell_item_rect(i, spr).has_point(p):
					var sd: Dictionary = _spell_popup_list[i]
					var is_enhance: bool = _spell_popup_enhance_mode
					_spell_popup_visible = false
					_spell_popup_list = []
					_spell_popup_enhance_mode = false
					queue_redraw()
					if is_enhance:
						spell_enhance_selected.emit(sd.id)
					else:
						spell_selected.emit(sd.id)
					get_viewport().set_input_as_handled()
					return
		var was_enhance: bool = _spell_popup_enhance_mode
		_spell_popup_visible = false
		_spell_popup_list = []
		_spell_popup_enhance_mode = false
		queue_redraw()
		if was_enhance:
			spell_enhance_selected.emit("")
		get_viewport().set_input_as_handled()
		return

	if _cauldron_picker_visible:
		var cpr := _cauldron_picker_rect()
		if cpr.has_point(p):
			for i in _cauldron_herb_indices.size():
				if _cauldron_herb_rect(i, cpr).has_point(p):
					var inv_idx: int = _cauldron_herb_indices[i]
					_cauldron_picker_visible = false
					_cauldron_herb_indices = []
					queue_redraw()
					cauldron_material_chosen.emit(inv_idx)
					get_viewport().set_input_as_handled()
					return
		_cauldron_picker_visible = false
		_cauldron_herb_indices = []
		queue_redraw()
		cauldron_picker_cancelled.emit()
		get_viewport().set_input_as_handled()
		return

	if _craft_visible:
		var pr := _craft_popup_rect()
		if pr.has_point(p):
			for t in 3:
				if _craft_tab_rect(t, pr).has_point(p):
					_craft_tab = t
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
			if _craft_tab != 1:
				var row := 0
				for i in Item.RECIPES.size():
					var recipe: Array = Item.RECIPES[i]
					var in_tab := (_craft_tab == 0 and Item.EQUIPMENT_DATA.has(recipe[0])) or \
						(_craft_tab == 2 and not Item.EQUIPMENT_DATA.has(recipe[0]))
					if in_tab:
						if _craft_content_row_rect(row, pr).has_point(p):
							if _can_craft(i):
								_craft_visible = false
								queue_redraw()
								craft_recipe_selected.emit(i)
							else:
								add_log("재료가 부족합니다.")
							get_viewport().set_input_as_handled()
							return
						row += 1
		else:
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
		elif _is_equip and _action_disassemble_rect().has_point(p):
			_action_popup_visible = false
			_bag_visible = false
			queue_redraw()
			item_action.emit(_action_item_idx, "disassemble")
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

	# 직업 스킬
	if _class_skill_rect().has_point(p):
		class_skill_tapped.emit()
		get_viewport().set_input_as_handled()
		return

	# 마법 슬롯
	if _skill_slot_rect(0).has_point(p):
		spell_slot_tapped.emit()
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
	if _cauldron_picker_visible:
		_draw_cauldron_picker()
	if _bag_visible:
		_draw_bag_popup()
	if _equip_action_visible:
		_draw_equip_action_popup()
	if _action_popup_visible:
		_draw_action_popup()
	if _well_popup_visible:
		_draw_well_popup()
	if _merchant_visible:
		_draw_merchant_popup()
	if _campfire_popup_visible:
		_draw_campfire_popup()
	if _cook_popup_visible:
		_draw_cook_popup()
	if _spell_popup_visible:
		_draw_spell_popup()
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
	var panel_h := pad * 2 + 18 + (bar_h + gap) * 3 + 14 + 16 + 14
	draw_rect(Rect2(0, 0, bar_w + pad * 2 + 4, panel_h), Color(0, 0, 0, 0.55))

	var hx := pad + 4
	var hy := pad

	var cls_name: String = SaveData.CLASS_NAMES[SaveData.selected_class]
	draw_string(font, Vector2(hx, hy + 10),
		"[%s] Lv.%d  ATK:%d  DEF:%d" % [cls_name, level, atk, def_],
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

	hy += 16
	draw_string(font, Vector2(hx, hy + 10), "💰 %d G" % gold,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f0d060"))

	hy += 14
	draw_string(font, Vector2(hx, hy + 10), "T.%d  (AP 20/턴)" % turn_num,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#888888"))

	# 상태이상 표시
	var statuses: Array[Dictionary] = []
	if _status_poison > 0:   statuses.append({"t": "독", "c": Color("#44cc44"), "n": _status_poison})
	if _status_fire > 0:     statuses.append({"t": "화상", "c": Color("#ff6633"), "n": _status_fire})
	if _status_sleep > 0:    statuses.append({"t": "수면", "c": Color("#aaaaff"), "n": _status_sleep})
	if _status_paralyze > 0: statuses.append({"t": "마비", "c": Color("#ffee44"), "n": _status_paralyze})
	if _status_frozen > 0:   statuses.append({"t": "빙결", "c": Color("#88ddff"), "n": _status_frozen})
	if _status_slow > 0:     statuses.append({"t": "느림", "c": Color("#aaddff"), "n": _status_slow})
	if _status_wound > 0:    statuses.append({"t": "부상", "c": Color("#ee4444"), "n": _status_wound})
	if _status_blind > 0:      statuses.append({"t": "실명", "c": Color("#888888"), "n": _status_blind})
	if _status_invincible > 0: statuses.append({"t": "무적", "c": Color("#ffe066"), "n": _status_invincible})
	if not statuses.is_empty():
		hy += 14
		var sx: float = hx
		for st in statuses:
			var label: String = "%s%d" % [st.t, st.n]
			var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_rect(Rect2(sx - 1, hy, tw + 4, 11), Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(sx + 1, hy + 9), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, st.c)
			sx += tw + 7

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

	# 직업 스킬 버튼
	var csr := _class_skill_rect()
	var cs_ready: bool = _class_skill_cooldown <= 0 and _class_skill_mp >= 35
	var cs_bg := Color(0.18, 0.10, 0.24, 0.9) if cs_ready else Color(0.10, 0.08, 0.12, 0.7)
	var cs_border := Color(0.7, 0.4, 0.9, 0.85) if cs_ready else Color(0.35, 0.25, 0.4, 0.6)
	draw_rect(csr, cs_bg)
	draw_rect(csr, cs_border, false)
	draw_string(font, Vector2(csr.position.x, csr.position.y + csr.size.y * 0.5 + 5),
		_class_skill_label, HORIZONTAL_ALIGNMENT_CENTER, csr.size.x, 10, Color(0.85, 0.65, 1.0) if cs_ready else Color(0.5, 0.4, 0.55))
	if _class_skill_cooldown > 0:
		draw_string(font, Vector2(csr.position.x, csr.position.y + csr.size.y - 6),
			str(_class_skill_cooldown), HORIZONTAL_ALIGNMENT_CENTER, csr.size.x, 10, Color(1.0, 0.6, 0.3))

	# 마법 슬롯
	var sk0 := _skill_slot_rect(0)
	draw_rect(sk0, Color(0.08, 0.08, 0.22, 0.85))
	draw_rect(sk0, Color(0.4, 0.4, 0.85, 0.8), false)
	draw_string(font, Vector2(sk0.position.x, sk0.position.y + sk0.size.y * 0.5 + 5),
		"마법", HORIZONTAL_ALIGNMENT_CENTER, sk0.size.x, 11, Color(0.7, 0.7, 1.0))
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
	draw_string(font, Vector2(pr.position.x, pr.position.y + 18),
		"제  작", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 13, Color("#80e880"))
	var tab_names := ["장비", "물약", "기타"]
	for t in 3:
		var tr := _craft_tab_rect(t, pr)
		var active := _craft_tab == t
		draw_rect(tr, Color(0.15, 0.3, 0.15, 0.95) if active else Color(0.07, 0.12, 0.07, 0.8))
		draw_rect(tr, Color(0.5, 0.8, 0.5, 0.8) if active else Color(0.25, 0.4, 0.25, 0.5), false)
		draw_string(font, Vector2(tr.position.x, tr.position.y + tr.size.y * 0.5 + 5),
			tab_names[t], HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 11,
			Color(0.9, 1.0, 0.9) if active else Color(0.55, 0.65, 0.55))
	if _craft_tab == 0:
		var row := 0
		for i in Item.RECIPES.size():
			var recipe: Array = Item.RECIPES[i]
			if not Item.EQUIPMENT_DATA.has(recipe[0]): continue
			var can: bool = _can_craft(i)
			var r := _craft_content_row_rect(row, pr)
			draw_rect(r, Color(0.12, 0.22, 0.12, 0.9) if can else Color(0.10, 0.10, 0.10, 0.7))
			draw_rect(r, Color(0.4, 0.65, 0.4, 0.75) if can else Color(0.25, 0.25, 0.25, 0.4), false)
			var eq: Array = Item.EQUIPMENT_DATA[recipe[0]]
			var stat := "ATK+%d" % eq[1] if eq[1] > 0 else "DEF+%d" % eq[2]
			var label := "%s(%s) ← %s" % [eq[0], stat, _recipe_mat_str(i, can)]
			draw_string(font, Vector2(r.position.x + 8, r.position.y + r.size.y * 0.5 + 5),
				label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 11,
				Color(0.9, 1.0, 0.85) if can else Color(0.5, 0.5, 0.5))
			row += 1
	elif _craft_tab == 1:
		draw_string(font, Vector2(pr.position.x, pr.position.y + 54),
			"연금술 솥에서만 제작 가능합니다", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 10, Color(0.7, 0.8, 0.5))
		var herbs: Array = [
			[Item.Type.MATERIAL_HERB,           "약초",           "랜덤 물약"],
			[Item.Type.MATERIAL_HERB_BLOOD_MOSS,  "말린 피이끼",   "회복 물약"],
			[Item.Type.MATERIAL_HERB_GINSENG,     "산삼 뿌리",     "포만 물약"],
			[Item.Type.MATERIAL_HERB_AMBROSIA,    "암브로시아 꽃", "회복 물약"],
			[Item.Type.MATERIAL_HERB_MUSHROOM,    "말린 영지버섯", "포만 물약"],
			[Item.Type.MATERIAL_HERB_NIGHTSHADE,  "나이트쉐이드",  "독 물약"],
			[Item.Type.MATERIAL_HERB_FIREWORT,    "화염초 꽃잎",   "화염 물약"],
			[Item.Type.MATERIAL_HERB_MANDRAKE,    "만드라고라",    "수면 물약"],
			[Item.Type.MATERIAL_HERB_DREAMGRASS,  "꿈결초 꽃잎",   "수면 물약"],
			[Item.Type.MATERIAL_HERB_ICE,         "식은 얼음송이", "수면 물약"],
			[Item.Type.MATERIAL_HERB_GARLIC,      "생마늘",        "정화 물약"],
		]
		for i in herbs.size():
			var r := _craft_content_row_rect_compact(i, pr)
			var have: int = _count_mat(herbs[i][0])
			draw_rect(r, Color(0.08, 0.14, 0.08, 0.85))
			draw_rect(r, Color(0.3, 0.55, 0.3, 0.5), false)
			var lc := Color(0.85, 1.0, 0.85) if have > 0 else Color(0.45, 0.55, 0.45)
			draw_string(font, Vector2(r.position.x + 6, r.position.y + r.size.y * 0.5 + 5),
				herbs[i][1] + "+빈병", HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.58 - 6, 10, lc)
			draw_string(font, Vector2(r.position.x + r.size.x * 0.58, r.position.y + r.size.y * 0.5 + 5),
				"→ " + herbs[i][2], HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.42 - 6, 10,
				Color(0.7, 0.9, 0.7) if have > 0 else Color(0.4, 0.5, 0.4))
	else:
		var row := 0
		for i in Item.RECIPES.size():
			var recipe: Array = Item.RECIPES[i]
			if Item.EQUIPMENT_DATA.has(recipe[0]): continue
			var can: bool = _can_craft(i)
			var r := _craft_content_row_rect(row, pr)
			draw_rect(r, Color(0.12, 0.22, 0.12, 0.9) if can else Color(0.10, 0.10, 0.10, 0.7))
			draw_rect(r, Color(0.4, 0.65, 0.4, 0.75) if can else Color(0.25, 0.25, 0.25, 0.4), false)
			var label := "%s ← %s" % [Item.get_type_name(recipe[0]), _recipe_mat_str(i, can)]
			draw_string(font, Vector2(r.position.x + 8, r.position.y + r.size.y * 0.5 + 5),
				label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 11,
				Color(0.9, 1.0, 0.85) if can else Color(0.5, 0.5, 0.5))
			row += 1
	draw_string(font, Vector2(pr.position.x, pr.end.y - 7),
		"영역 밖 터치로 닫기", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 8, Color(0.35, 0.35, 0.35))

func _draw_cauldron_picker() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))
	var pr := _cauldron_picker_rect()
	draw_rect(pr, Color(0.04, 0.07, 0.12, 0.97))
	draw_rect(pr, Color(0.35, 0.55, 0.9, 0.75), false, 1.5)
	var title := "흰 솥 — 재료 선택" if _cauldron_is_white else "검은 솥 — 재료 선택"
	draw_string(font, Vector2(pr.position.x, pr.position.y + 20),
		title, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 13, Color("#80c8ff"))
	draw_string(font, Vector2(pr.position.x, pr.position.y + 36),
		"빈병 ×1 + 선택 재료 ×1 소모", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 10, Color(0.55, 0.6, 0.65))
	for i in _cauldron_herb_indices.size():
		var inv_idx: int = _cauldron_herb_indices[i]
		if inv_idx >= _inventory_items.size(): continue
		var herb: Item = _inventory_items[inv_idx]
		var r := _cauldron_herb_rect(i, pr)
		draw_rect(r, Color(0.1, 0.18, 0.28, 0.9))
		draw_rect(r, Color(0.4, 0.55, 0.8, 0.6), false)
		var result_str: String
		if Item.HERB_POTION_MAP.has(herb.item_type):
			result_str = " → " + _potion_type_name(Item.HERB_POTION_MAP[herb.item_type])
		else:
			result_str = " → 랜덤 물약"
		draw_string(font, Vector2(r.position.x + 8, r.position.y + r.size.y * 0.5 + 5),
			Item.get_type_name(herb.item_type) + result_str,
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 11, Color(0.9, 0.95, 1.0))
	draw_string(font, Vector2(pr.position.x, pr.end.y - 7),
		"영역 밖 터치로 취소", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 8, Color(0.35, 0.35, 0.35))

func _potion_type_name(potion_type: int) -> String:
	match potion_type:
		Item.Type.POTION_HEAL:    return "회복 물약"
		Item.Type.POTION_HUNGER:  return "포만 물약"
		Item.Type.POTION_POISON:  return "독 물약"
		Item.Type.POTION_FIRE:    return "화염 물약"
		Item.Type.POTION_CLEANSE: return "정화 물약"
		Item.Type.POTION_SLEEP:   return "수면 물약"
	return "물약"

func _recipe_mat_str(recipe_idx: int, can: bool) -> String:
	var mats: Array = Item.RECIPES[recipe_idx][2]
	var s := ""
	for mat in mats:
		if s != "": s += "+"
		var have: int = _count_mat(mat[0])
		var need: int = mat[1]
		s += "%s×%d" % [Item.get_type_name(mat[0]), need]
		if not can: s += "(%d/%d)" % [have, need]
	return s

func _action_is_equip() -> bool:
	if _action_item_idx < 0 or _action_item_idx >= _inventory_items.size():
		return false
	return _inventory_items[_action_item_idx].is_equipment()

func _draw_action_popup() -> void:
	var font := ThemeDB.fallback_font
	var pw := 180.0; var ph := 160.0 if _action_is_equip() else 130.0
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
	var _is_equip_item: bool = _it != null and _it.is_equipment()
	var _use_label := "장착" if _is_equip_item else "먹기 / 사용"
	_draw_action_btn(_action_use_rect(),     _use_label, Color(0.14, 0.4,  0.14, 0.95))
	_draw_action_btn(_action_throw_rect(),   "던지기",    Color(0.14, 0.25, 0.4,  0.95))
	if _is_equip_item:
		_draw_action_btn(_action_disassemble_rect(), "분해", Color(0.45, 0.28, 0.08, 0.95))
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

func _class_skill_rect() -> Rect2:
	var skill_left := W - 8 - 2 * SLOT_SZ - 6
	var y := H - BAR_H + (BAR_H - SLOT_SZ) / 2
	return Rect2(skill_left - SLOT_SZ - 6, y, SLOT_SZ, SLOT_SZ)

func _skill_slot_rect(i: int) -> Rect2:
	var skill_left := W - 8 - 2 * SLOT_SZ - 6
	var y := H - BAR_H + (BAR_H - SLOT_SZ) / 2
	return Rect2(skill_left + i * (SLOT_SZ + 6), y, SLOT_SZ, SLOT_SZ)

func set_class_skill_info(label: String, cooldown: int, mp: int) -> void:
	_class_skill_label = label
	_class_skill_cooldown = cooldown
	_class_skill_mp = mp
	queue_redraw()

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
	var pw := 180.0; var ph := 160.0 if _action_is_equip() else 130.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	return Rect2(px + 12, py + 34, pw - 24, 26)

func _action_throw_rect() -> Rect2:
	var pw := 180.0; var ph := 160.0 if _action_is_equip() else 130.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	return Rect2(px + 12, py + 64, pw - 24, 26)

func _action_disassemble_rect() -> Rect2:
	var pw := 180.0; var ph := 160.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	return Rect2(px + 12, py + 94, pw - 24, 26)

func _action_discard_rect() -> Rect2:
	var pw := 180.0; var ph := 160.0 if _action_is_equip() else 130.0
	var px := (W - pw) * 0.5; var py := (H - ph) * 0.5
	var btn_y := 124.0 if _action_is_equip() else 94.0
	return Rect2(px + 12, py + btn_y, pw - 24, 26)

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
	var pw := 314.0
	var content_h: float
	if _craft_tab == 0:
		var n := 0
		for r in Item.RECIPES:
			if Item.EQUIPMENT_DATA.has(r[0]): n += 1
		content_h = float(max(1, n)) * 40.0
	elif _craft_tab == 1:
		content_h = 18.0 + 11.0 * 28.0
	else:
		var n := 0
		for r in Item.RECIPES:
			if not Item.EQUIPMENT_DATA.has(r[0]): n += 1
		content_h = float(max(1, n)) * 40.0
	var ph := 50.0 + content_h + 20.0
	return Rect2((W - pw) * 0.5, (H - ph) * 0.5, pw, ph)

func _craft_tab_rect(t: int, pr: Rect2) -> Rect2:
	var tab_w := (pr.size.x - 12.0) / 3.0
	return Rect2(pr.position.x + 6.0 + float(t) * tab_w, pr.position.y + 22.0, tab_w - 2.0, 22.0)

func _craft_content_row_rect(row: int, pr: Rect2) -> Rect2:
	return Rect2(pr.position.x + 8.0, pr.position.y + 50.0 + float(row) * 40.0, pr.size.x - 16.0, 36.0)

func _craft_content_row_rect_compact(row: int, pr: Rect2) -> Rect2:
	return Rect2(pr.position.x + 8.0, pr.position.y + 60.0 + float(row) * 28.0, pr.size.x - 16.0, 24.0)

func _cauldron_picker_rect() -> Rect2:
	var pw := 300.0
	var count: int = max(1, _cauldron_herb_indices.size())
	var ph := 46.0 + float(count) * 40.0 + 20.0
	return Rect2((W - pw) * 0.5, max(10.0, (H - ph) * 0.5), pw, ph)

func _cauldron_herb_rect(i: int, pr: Rect2) -> Rect2:
	return Rect2(pr.position.x + 8.0, pr.position.y + 42.0 + float(i) * 40.0, pr.size.x - 16.0, 36.0)

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

# ── Magic Well Popup ───────────────────────────────────────────────────────

func _well_popup_rect() -> Rect2:
	var count: int = max(1, _well_popup_indices.size())
	var ph := 40.0 + count * 40.0 + 18.0
	var pw := 280.0
	return Rect2((W - pw) * 0.5, (H - ph) * 0.5, pw, ph)

func _well_item_rect(i: int, pr: Rect2) -> Rect2:
	return Rect2(pr.position.x + 10, pr.position.y + 30 + i * 40, pr.size.x - 20, 36)

func _draw_well_popup() -> void:
	var font := ThemeDB.fallback_font
	var pr := _well_popup_rect()
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5))
	draw_rect(pr, Color(0.06, 0.10, 0.18, 0.97))
	draw_rect(pr, Color(0.3, 0.5, 0.8, 0.8), false)
	draw_string(font, Vector2(pr.position.x, pr.position.y + 22),
		"🌀 이상한 우물 — 바칠 아이템",
		HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 12, Color("#80c0ff"))
	for i in _well_popup_indices.size():
		var inv_idx: int = _well_popup_indices[i]
		if inv_idx >= _inventory_items.size():
			continue
		var item: Item = _inventory_items[inv_idx]
		var identified: bool = item.color_idx < _inventory_identified.size() \
			and _inventory_identified[item.color_idx]
		var r := _well_item_rect(i, pr)
		draw_rect(r, Color(0.1, 0.15, 0.25, 0.85))
		draw_rect(r, Color(0.25, 0.4, 0.65, 0.7), false)
		var atlas: Vector2i = item.get_atlas()
		var src := Rect2(atlas.x * ATLAS_TILE, atlas.y * ATLAS_TILE, ATLAS_TILE, ATLAS_TILE)
		draw_texture_rect_region(TILESET, Rect2(r.position + Vector2(4, 7), Vector2(22, 22)), src, item.get_modulate())
		draw_string(font, Vector2(r.position.x + 32, r.position.y + r.size.y * 0.5 + 5),
			item.get_display_name(identified), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, 10, Color.WHITE)
	draw_string(font, Vector2(pr.position.x, pr.end.y - 8),
		"영역 밖 터치로 취소", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 8, Color(0.32, 0.32, 0.35))

# ── Merchant Popup ─────────────────────────────────────────────────────────

func _merchant_panel_rect() -> Rect2:
	var pw := 480.0; var ph := 370.0
	return Rect2((W - pw) * 0.5, (H - ph) * 0.5, pw, ph)

func _merchant_row_rect(pr: Rect2, i: int) -> Rect2:
	return Rect2(pr.position.x + 8, pr.position.y + 44 + i * 32, pr.size.x - 16, 30)

func _merchant_action_btn_rect(pr: Rect2, i: int) -> Rect2:
	var row := _merchant_row_rect(pr, i)
	return Rect2(row.end.x - 66, row.position.y + 3, 62, 24)

func _merchant_close_btn_rect(pr: Rect2) -> Rect2:
	return Rect2(pr.end.x - 82, pr.end.y - 36, 76, 28)

func _merchant_toggle_btn_rect(pr: Rect2) -> Rect2:
	return Rect2(pr.position.x + 8, pr.end.y - 36, 110, 28)

func _draw_merchant_popup() -> void:
	var font := ThemeDB.fallback_font
	var pr := _merchant_panel_rect()
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))
	draw_rect(pr, Color(0.06, 0.08, 0.12, 0.97))
	draw_rect(pr, Color(0.6, 0.5, 0.25, 0.9), false)

	# Header
	var title := "상인 상점" if not _merchant_sell_mode else "아이템 판매"
	draw_string(font, Vector2(pr.position.x, pr.position.y + 24),
		title, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 14, Color("#f0d060"))
	draw_string(font, Vector2(pr.end.x - 100, pr.position.y + 16),
		"💰 %dG" % gold, HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color("#f0d060"))

	var item_list: Array
	if _merchant_sell_mode:
		item_list = _inventory_items
	else:
		item_list = _merchant_shop_items

	var max_rows: int = min(item_list.size(), 9)
	for i in max_rows:
		var row := _merchant_row_rect(pr, i)
		draw_rect(row, Color(0.1, 0.12, 0.18, 0.8))

		var item: Item
		var price_text: String
		var sold: bool = false
		if _merchant_sell_mode:
			item = _inventory_items[i]
			var sp: int = _merchant_sell_prices[i] if i < _merchant_sell_prices.size() else 1
			price_text = "%dG" % sp
		else:
			var d: Dictionary = _merchant_shop_items[i]
			item = d.item
			price_text = "%dG" % d.price
			sold = d.sold

		# 아이템 아이콘
		var atlas: Vector2i = item.get_atlas()
		var src := Rect2(atlas.x * ATLAS_TILE, atlas.y * ATLAS_TILE, ATLAS_TILE, ATLAS_TILE)
		var icon_rect := Rect2(row.position.x + 2, row.position.y + 3, 22, 22)
		draw_texture_rect_region(TILESET, icon_rect, src, item.get_modulate())

		# 아이템 이름
		var identified: bool = item.color_idx < _inventory_identified.size() \
			and _inventory_identified[item.color_idx]
		var name_str := item.get_display_name(identified)
		var name_color := Color(0.45, 0.45, 0.5) if sold else Color(0.9, 0.9, 0.9)
		draw_string(font, Vector2(row.position.x + 28, row.position.y + 18),
			name_str, HORIZONTAL_ALIGNMENT_LEFT, 240, 10, name_color)

		# 가격
		draw_string(font, Vector2(row.end.x - 130, row.position.y + 18),
			price_text, HORIZONTAL_ALIGNMENT_LEFT, 60, 10, Color("#f0d060"))

		# 버튼
		var btn := _merchant_action_btn_rect(pr, i)
		var btn_label: String
		var btn_color: Color
		if _merchant_sell_mode:
			btn_label = "판매"
			btn_color = Color(0.38, 0.18, 0.08, 0.95)
		elif sold:
			btn_label = "품절"
			btn_color = Color(0.2, 0.2, 0.22, 0.8)
		else:
			btn_label = "구매"
			btn_color = Color(0.12, 0.32, 0.12, 0.95)
		draw_rect(btn, btn_color)
		draw_rect(btn, Color(0.5, 0.5, 0.5, 0.5), false)
		draw_string(font, Vector2(btn.position.x, btn.position.y + btn.size.y * 0.5 + 5),
			btn_label, HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 10, Color.WHITE)

	# 하단 버튼
	var toggle_btn := _merchant_toggle_btn_rect(pr)
	draw_rect(toggle_btn, Color(0.15, 0.2, 0.3, 0.9))
	draw_rect(toggle_btn, Color(0.5, 0.6, 0.7, 0.7), false)
	var toggle_label := "▶ 판매하기" if not _merchant_sell_mode else "◀ 구매하기"
	draw_string(font, Vector2(toggle_btn.position.x, toggle_btn.position.y + toggle_btn.size.y * 0.5 + 5),
		toggle_label, HORIZONTAL_ALIGNMENT_CENTER, toggle_btn.size.x, 10, Color.WHITE)

	var close_btn := _merchant_close_btn_rect(pr)
	draw_rect(close_btn, Color(0.28, 0.08, 0.08, 0.9))
	draw_rect(close_btn, Color(0.6, 0.3, 0.3, 0.7), false)
	draw_string(font, Vector2(close_btn.position.x, close_btn.position.y + close_btn.size.y * 0.5 + 5),
		"닫기", HORIZONTAL_ALIGNMENT_CENTER, close_btn.size.x, 10, Color.WHITE)

# ── Spell Popup ────────────────────────────────────────────────────────────

func _spell_popup_rect() -> Rect2:
	var count: int = max(1, _spell_popup_list.size())
	var ph := 40.0 + count * 36.0 + 18.0
	var pw := 240.0
	return Rect2((W - pw) * 0.5, (H - ph) * 0.5, pw, ph)

func _spell_item_rect(i: int, pr: Rect2) -> Rect2:
	return Rect2(pr.position.x + 8, pr.position.y + 32 + i * 36, pr.size.x - 16, 32)

func _draw_spell_popup() -> void:
	var font := ThemeDB.fallback_font
	var pr := _spell_popup_rect()
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))
	draw_rect(pr, Color(0.05, 0.07, 0.20, 0.97))
	draw_rect(pr, Color(0.35, 0.35, 0.85, 0.8), false)
	var title: String = "마법 강화 선택" if _spell_popup_enhance_mode else "마법 선택"
	draw_string(font, Vector2(pr.position.x, pr.position.y + 22),
		title, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 13, Color("#9090ff"))
	if _spell_popup_list.is_empty():
		draw_string(font, Vector2(pr.position.x, pr.position.y + 50),
			"배운 마법이 없습니다.", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 11, Color(0.55, 0.55, 0.55))
	for i in _spell_popup_list.size():
		var d: Dictionary = _spell_popup_list[i]
		var r := _spell_item_rect(i, pr)
		draw_rect(r, Color(0.10, 0.10, 0.28, 0.9))
		draw_rect(r, Color(0.28, 0.28, 0.72, 0.7), false)
		draw_string(font, Vector2(r.position.x + 8, r.position.y + r.size.y * 0.5 + 5),
			d.name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 68, 11, Color.WHITE)
		if _spell_popup_enhance_mode:
			var lv_str: String = "Lv.%d → %d" % [d.level, d.level + 1]
			draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 5),
				lv_str, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8, 10, Color("#ffdd66"))
		else:
			draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 5),
				"MP %d" % d.mp_cost, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8, 10, Color("#66ccff"))
	draw_string(font, Vector2(pr.position.x, pr.end.y - 8),
		"영역 밖 터치로 취소", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 8, Color(0.32, 0.32, 0.35))
