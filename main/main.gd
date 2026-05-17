extends Node2D

@onready var map: GameMap = $Map
@onready var player: Player = $Player
@onready var enemy_manager: EnemyManager = $EnemyManager
@onready var hud: HUD = $HUD/Overlay
@onready var camera: Camera2D = $Camera2D
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect

const MAX_FLOOR := 25
const THROW_RANGE := 5
const MAX_ENHANCE := 5
const HIT_EFFECT_SCENE := preload("res://fx/hit_effect.tscn")
const STATUS_EFFECT_SCENE := preload("res://fx/status_effect.tscn")

# 물약 색상-효과 매핑 (런마다 셔플)
var _potion_map: Array[Item.Type] = []
var _identified: Array[bool] = [false, false, false, false, false, false, false, false, false]

# 던지기 타겟팅
var _throw_mode := false
var _throw_item_idx := -1
var _has_boss_key := false
var floor_items: Array[Dictionary] = []

# 탐험경험치 — 이번 런에서 획득한 XP (종료 시 SaveData에 누적)
var _run_explore_xp: int = 0

var _campfire_tile_pos: Vector2i = Vector2i.ZERO

var _spell_mode := false
var _spell_id := ""

# 상인 상점
var _shop_items: Array[Dictionary] = []   # {item: Item, price: int, sold: bool}

# 함정 종류 사전 배정 (0~9)
var _trap_data: Dictionary = {}

# 우물 위치 (사용 후 비활성화)
var _well_tile_pos: Vector2i = Vector2i(-1, -1)

const PARALYZE_TURNS := 3
const FROZEN_TURNS   := 2
const WOUND_TURNS    := 6
const BLIND_TURNS    := 4

func _ready() -> void:
	_init_run()

func _init_run() -> void:
	_potion_map.assign([
		Item.Type.POTION_HEAL,
		Item.Type.POTION_HUNGER,
		Item.Type.POTION_POISON,
		Item.Type.POTION_FIRE,
		Item.Type.POTION_CLEANSE,
		Item.Type.POTION_SLEEP,
	])
	_potion_map.shuffle()
	_identified.assign([false, false, false, false, false, false, false, false, false])
	floor_items.clear()

	map.generate(player.floor_num)
	_assign_trap_types()
	var start: Vector2i = map.get_start_pos()
	player.init(start, map)
	player.enemy_manager_ref = enemy_manager
	player.hud_ref = hud

	if not player.stats_changed.is_connected(_on_player_stats_changed):
		player.stats_changed.connect(_on_player_stats_changed)
	if not player.log_message.is_connected(_on_log_message):
		player.log_message.connect(_on_log_message)
	if not player.turn_done.is_connected(_on_player_turn_done):
		player.turn_done.connect(_on_player_turn_done)
	if not player.hit_at.is_connected(_on_hit_at):
		player.hit_at.connect(_on_hit_at)
	if not player.attacked_cell.is_connected(_on_player_attacked_cell):
		player.attacked_cell.connect(_on_player_attacked_cell)
	if not enemy_manager.player_attacked.is_connected(_on_enemy_attacked_player):
		enemy_manager.player_attacked.connect(_on_enemy_attacked_player)
	if not enemy_manager.all_cleared.is_connected(_on_all_cleared):
		enemy_manager.all_cleared.connect(_on_all_cleared)
	if not enemy_manager.boss_dropped_key.is_connected(_on_boss_dropped_key):
		enemy_manager.boss_dropped_key.connect(_on_boss_dropped_key)
	if not enemy_manager.trap_triggered_by_enemy.is_connected(_on_enemy_trap):
		enemy_manager.trap_triggered_by_enemy.connect(_on_enemy_trap)
	if not enemy_manager.enemy_dropped_gold.is_connected(_on_enemy_dropped_gold):
		enemy_manager.enemy_dropped_gold.connect(_on_enemy_dropped_gold)
	if not hud.wait_requested.is_connected(_on_wait_requested):
		hud.wait_requested.connect(_on_wait_requested)
	if not hud.home_requested.is_connected(_on_home_requested):
		hud.home_requested.connect(_on_home_requested)
	if not hud.item_action.is_connected(_on_item_action):
		hud.item_action.connect(_on_item_action)
	if not hud.throw_cancelled.is_connected(_on_throw_cancelled):
		hud.throw_cancelled.connect(_on_throw_cancelled)
	if not hud.craft_recipe_selected.is_connected(_on_craft_recipe):
		hud.craft_recipe_selected.connect(_on_craft_recipe)
	if not hud.unequip_requested.is_connected(_on_unequip_requested):
		hud.unequip_requested.connect(_on_unequip_requested)
	if not player.campfire_approached.is_connected(_on_campfire_approached):
		player.campfire_approached.connect(_on_campfire_approached)
	if not player.campfire_out_approached.is_connected(_on_campfire_out_approached):
		player.campfire_out_approached.connect(_on_campfire_out_approached)
	if not hud.campfire_action.is_connected(_on_campfire_action):
		hud.campfire_action.connect(_on_campfire_action)
	if not hud.campfire_cook_selected.is_connected(_on_campfire_cook_selected):
		hud.campfire_cook_selected.connect(_on_campfire_cook_selected)
	if not player.merchant_approached.is_connected(_on_merchant_approached):
		player.merchant_approached.connect(_on_merchant_approached)
	if not hud.merchant_buy.is_connected(_on_merchant_buy):
		hud.merchant_buy.connect(_on_merchant_buy)
	if not hud.merchant_sell.is_connected(_on_merchant_sell):
		hud.merchant_sell.connect(_on_merchant_sell)
	if not player.door_approached.is_connected(_on_door_approached):
		player.door_approached.connect(_on_door_approached)
	if not player.cauldron_approached.is_connected(_on_cauldron_approached):
		player.cauldron_approached.connect(_on_cauldron_approached)
	if not player.well_approached.is_connected(_on_well_approached):
		player.well_approached.connect(_on_well_approached)
	if not hud.well_item_selected.is_connected(_on_well_item_selected):
		hud.well_item_selected.connect(_on_well_item_selected)
	if not player.skull_approached.is_connected(_on_skull_approached):
		player.skull_approached.connect(_on_skull_approached)
	if not player.tablet_approached.is_connected(_on_tablet_approached):
		player.tablet_approached.connect(_on_tablet_approached)
	if not player.statue_approached.is_connected(_on_statue_approached):
		player.statue_approached.connect(_on_statue_approached)
	if not player.bookshelf_approached.is_connected(_on_bookshelf_approached):
		player.bookshelf_approached.connect(_on_bookshelf_approached)
	if not hud.spell_slot_tapped.is_connected(_on_spell_slot_tapped):
		hud.spell_slot_tapped.connect(_on_spell_slot_tapped)
	if not hud.spell_selected.is_connected(_on_spell_selected):
		hud.spell_selected.connect(_on_spell_selected)
	if not hud.class_skill_tapped.is_connected(_on_class_skill_tapped):
		hud.class_skill_tapped.connect(_on_class_skill_tapped)

	# 탐험경험치 마일스톤 보너스 적용
	_run_explore_xp = 0
	player.max_hp += SaveData.get_bonus_max_hp()
	player.hp = player.max_hp
	player.max_mp += SaveData.get_bonus_max_mp()
	player.mp = player.max_mp
	player._save_atk_bonus = SaveData.get_bonus_atk()

	if SaveData.has_identify_potion():
		var rand_idx: int = randi() % 6
		_identified[rand_idx] = true

	if SaveData.has_start_potion_heal():
		var color_idx: int = _potion_map.find(Item.Type.POTION_HEAL)
		var start_potion := Item.new()
		start_potion.item_type = Item.Type.POTION_HEAL
		start_potion.color_idx = color_idx
		player.inventory.append(start_potion)

	player.apply_rune_effects()
	_give_class_starting_gear()
	enemy_manager.spawn(map.rooms, map, player.floor_num)
	camera.position = player.position
	_update_fov()
	_refresh_hud()

func _process(_delta: float) -> void:
	camera.position = camera.position.lerp(player.position, 0.15)

# ── 던지기 타겟팅 입력 ──────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _throw_mode and not _spell_mode:
		return
	var world_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		world_pos = get_viewport().get_canvas_transform().affine_inverse() * event.position
	elif event is InputEventScreenTouch and event.pressed:
		world_pos = get_viewport().get_canvas_transform().affine_inverse() * event.position
	else:
		return
	var tile := Vector2i(int(world_pos.x / 32), int(world_pos.y / 32))
	if _throw_mode:
		_execute_throw(tile)
	else:
		_execute_spell(tile)
	get_viewport().set_input_as_handled()

# ── Turn flow ──────────────────────────────────────────────────────────────

func _update_fov() -> void:
	var has_torch := false
	for inv_item in player.inventory:
		if inv_item.item_type == Item.Type.MATERIAL_TORCH:
			has_torch = true
			break
	var radius: int
	if player.blind_turns > 0:
		radius = 2
	elif has_torch:
		radius = 10
	else:
		radius = 4

	# 맵의 모닥불 위치를 광원으로 수집
	var light_sources: Array[Vector2i] = []
	for cy in map.HEIGHT:
		for cx in map.WIDTH:
			if map.get_cell(cx, cy) == map.Cell.CAMPFIRE:
				light_sources.append(Vector2i(cx, cy))

	map.update_fov(player.tile_pos, radius, light_sources)
	for e in enemy_manager.enemies:
		if is_instance_valid(e):
			e.visible = map.is_tile_visible(e.tile_pos.x, e.tile_pos.y)

func _on_player_turn_done() -> void:
	_update_fov()
	if player.hp <= 0:
		_trigger_game_over()
		return

	var cell: int = map.get_cell(player.tile_pos.x, player.tile_pos.y)

	if cell == map.Cell.CHEST:
		_open_chest(player.tile_pos)

	if cell == map.Cell.TRAP:
		_trigger_trap(player.tile_pos)

	if cell == map.Cell.TAINTED_SPRING or cell == map.Cell.CLEAR_SPRING:
		_trigger_spring(player.tile_pos, cell)

	if cell == map.Cell.ALTAR or cell == map.Cell.ALTAR_BIG:
		_trigger_altar(player.tile_pos, cell)

	if cell in [
		map.Cell.HERB_ICE, map.Cell.HERB_BLOOD_MOSS, map.Cell.HERB_GINSENG,
		map.Cell.HERB_NIGHTSHADE, map.Cell.HERB_AMBROSIA, map.Cell.HERB_MUSHROOM,
		map.Cell.HERB_MANDRAKE, map.Cell.HERB_FIREWORT, map.Cell.HERB_DREAMGRASS,
	]:
		_trigger_herb(player.tile_pos, cell)

	if cell == map.Cell.STAIRS:
		_show_stairs_popup()
		return

	_try_pickup_floor_items()
	_process_enemy_statuses()
	enemy_manager.do_turns(player.tile_pos)

func _process_enemy_statuses() -> void:
	for r in enemy_manager.tick_statuses():
		var e = r.enemy
		if not is_instance_valid(e):
			continue
		var src: String = " & ".join(r.sources)
		hud.add_log("%s: %s %d 피해!" % [e.display_name, src, r.damage])
		if "독" in r.sources:
			_spawn_poison(r.pos)
		if "화염" in r.sources:
			_spawn_fire(r.pos)
		if r.dead:
			var reward: int = 5 * player.floor_num
			hud.add_log("%s 처치! EXP +%d" % [e.display_name, reward])
			enemy_manager.remove_enemy(e)
			player.gain_exp(reward)

func _on_enemy_attacked_player(atk_value: int, attacker_name: String) -> void:
	_spawn_hit(player.position)
	player.take_damage(atk_value, attacker_name)
	if player.hp <= 0:
		_trigger_game_over()

func _on_hit_at(world_pos: Vector2) -> void:
	_spawn_hit(world_pos)

func _on_player_attacked_cell(tile_pos: Vector2i) -> void:
	var cell: int = map.get_cell(tile_pos.x, tile_pos.y)
	if cell == map.Cell.GRASS:
		map.set_cell(tile_pos.x, tile_pos.y, map.Cell.FLOOR)
		hud.add_log("수풀을 베었습니다!")
		_pick_or_drop(_pick_bush_drop(), tile_pos)
	elif cell == map.Cell.JAR:
		map.set_cell(tile_pos.x, tile_pos.y, map.Cell.JAR_OPEN)
		hud.add_log("항아리를 부쉈습니다!")
		_resolve_jar(tile_pos)
	_refresh_hud()

func _pick_bush_drop() -> Item:
	var mat := Item.new()
	var roll: int = randi() % 100
	if roll < 30:
		mat.item_type = Item.Type.MATERIAL_BRANCH
	elif roll < 55:
		mat.item_type = Item.Type.MATERIAL_HERB
	elif roll < 75:
		mat.item_type = Item.Type.MATERIAL_STONE
	elif roll < 90:
		mat.item_type = Item.Type.MATERIAL_BOTTLE
	elif roll < 97:
		var cidx: int = randi() % 6
		mat.item_type = _potion_map[cidx]
		mat.color_idx = cidx
	else:
		var sroll: int = randi() % 4
		if sroll == 0:
			mat.item_type = Item.Type.SCROLL_ENHANCE
		else:
			var sidx: int = sroll - 1  # 0=BASH, 1=TELEPORT, 2=IDENTIFY
			mat.item_type = Item.SCROLL_TYPES[sidx]
			mat.color_idx = 6 + sidx   # _identified[6/7/8]
	return mat

func _resolve_jar(tile_pos: Vector2i) -> void:
	var roll: int = randi() % 100
	if roll < 40:
		var mat := Item.new()
		mat.item_type = [Item.Type.MATERIAL_CLOTH, Item.Type.MATERIAL_ORE, Item.Type.FOOD][randi() % 3]
		_pick_or_drop(mat, tile_pos)
	elif roll < 70:
		hud.add_log("항아리는 비어있었습니다.")
	elif roll < 90:
		hud.add_log("항아리에서 몬스터가 튀어나왔습니다!")
		enemy_manager.spawn_one_near(tile_pos, map, player.floor_num)
	else:
		player.curse_atk += 1
		player._recalc_equip_stats()
		player.stats_changed.emit()
		hud.add_log("저주에 걸렸습니다! ATK -1 (정화 물약으로 해제)")

func _pick_or_drop(item: Item, tile_pos: Vector2i) -> void:
	if player.inventory.size() >= player.MAX_INVENTORY:
		_drop_item(item, tile_pos)
		hud.add_log("%s 바닥에 떨어졌습니다." % item.get_display_name(true))
	else:
		# 잡학다식 룬: 9% 확률 자동 식별
		if player.auto_identify_pct > 0 and item.color_idx >= 0 and \
				item.color_idx < _identified.size() and not _identified[item.color_idx]:
			if randi() % 100 < player.auto_identify_pct:
				_identified[item.color_idx] = true
		player.inventory.append(item)
		var ident: bool = item.item_type != Item.Type.FOOD and \
			item.color_idx >= 0 and item.color_idx < _identified.size() and \
			_identified[item.color_idx]
		hud.add_log("%s 획득!" % item.get_display_name(ident))

func _on_all_cleared(pos: Vector2) -> void:
	var fx = HIT_EFFECT_SCENE.instantiate()
	add_child(fx)
	fx.spawn_clear(pos)

func _spawn_hit(world_pos: Vector2) -> void:
	var fx = HIT_EFFECT_SCENE.instantiate()
	add_child(fx)
	fx.spawn(world_pos)

func _spawn_poison(world_pos: Vector2) -> void:
	var fx = STATUS_EFFECT_SCENE.instantiate()
	add_child(fx)
	fx.spawn_poison(world_pos)

func _spawn_fire(world_pos: Vector2) -> void:
	var fx = STATUS_EFFECT_SCENE.instantiate()
	add_child(fx)
	fx.spawn_fire(world_pos)

# ── Stats & HUD ────────────────────────────────────────────────────────────

func _on_player_stats_changed() -> void:
	_refresh_hud()

func _on_log_message(msg: String) -> void:
	hud.add_log(msg)

func _refresh_hud() -> void:
	hud.update_stats(player.hp, player.max_hp, player.mp, player.max_mp,
		player.hunger, player.fatigue, player.floor_num, player.level, player.atk, player.def_, player.gold)
	hud.update_status(player.poison_turns, player.fire_turns, player.sleep_turns,
		player.paralyze_turns, player.frozen_turns, player.slow_turns,
		player.wound_turns, player.blind_turns, player.invincible_turns)
	hud.update_inventory(player.inventory, _identified)
	hud.update_equipped(player.equipped_weapon, player.equipped_shield, player.equipped_armor)
	var skill_labels := ["강타", "회오리", "섬광탄", "난사"]
	var label: String = skill_labels[player.class_type] if player.class_type < skill_labels.size() else "스킬"
	hud.set_class_skill_info(label, player.class_skill_cooldown, player.mp)

# ── Unequip ────────────────────────────────────────────────────────────────

func _on_unequip_requested(slot: String) -> void:
	var msg := player.unequip(slot)
	if msg != "":
		hud.add_log(msg)
	_refresh_hud()

# ── Wait button ────────────────────────────────────────────────────────────

func _on_wait_requested() -> void:
	if _throw_mode:
		_exit_throw_mode()
		hud.add_log("던지기 취소")
		return
	if _spell_mode:
		_exit_spell_mode()
		hud.add_log("마법 시전 취소")
		return
	player.do_wait()

# ── Gold ───────────────────────────────────────────────────────────────────

func _on_enemy_dropped_gold(amount: int) -> void:
	player.gold += amount
	hud.add_log("💰 골드 +%d (총 %dG)" % [amount, player.gold])
	_refresh_hud()

# ── Stairs / Floor transition ──────────────────────────────────────────────

func _on_boss_dropped_key(_pos: Vector2) -> void:
	_has_boss_key = true
	hud.add_log("열쇠를 획득했습니다! 계단을 밟아 다음 층으로 이동하세요.")
	_refresh_hud()

func _show_stairs_popup() -> void:
	if enemy_manager.is_boss_floor(player.floor_num) and not _has_boss_key:
		hud.add_log("보스를 처치해야 계단을 이용할 수 있습니다!")
		enemy_manager.do_turns(player.tile_pos)
		return
	_has_boss_key = false
	var msg := "다음 층으로 올라갈까요?\n(다시 돌아올 수 없습니다)" if player.floor_num < MAX_FLOOR else "탑의 정상으로 올라가시겠습니까?\n(다시 돌아올 수 없습니다)"
	hud.show_confirm(msg, _on_stairs_confirmed, _on_stairs_cancelled)

func _on_stairs_confirmed() -> void:
	_do_floor_transition(1)

func _on_stairs_cancelled() -> void:
	enemy_manager.do_turns(player.tile_pos)

func _do_floor_transition(direction: int) -> void:
	player.input_blocked = true
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.4)
	await tween.finished

	var new_floor: int = player.floor_num + direction
	_run_explore_xp += player.floor_num * 10
	SaveData.update_best_floor(player.floor_num)
	if new_floor > MAX_FLOOR:
		SaveData.award_chest(player.floor_num)
		SaveData.add_explore_xp(_run_explore_xp)
		_run_explore_xp = 0
		_trigger_game_clear()
		return

	player.floor_num = new_floor
	floor_items.clear()
	_shop_items.clear()
	map.generate(player.floor_num)
	if _is_merchant_floor(player.floor_num):
		_generate_shop()
	var start: Vector2i = map.get_start_pos()
	player.tile_pos = start
	player.position = map.tile_to_world(start)
	enemy_manager.spawn(map.rooms, map, player.floor_num)
	camera.position = player.position
	_update_fov()
	_refresh_hud()
	hud.add_log("%d층에 도착했습니다." % player.floor_num)

	tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.4)
	await tween.finished
	player.input_blocked = false

# ── Chest / Items ──────────────────────────────────────────────────────────

func _open_chest(pos: Vector2i) -> void:
	map.set_cell(pos.x, pos.y, map.Cell.CHEST_OPEN)
	# 슬롯 A: 포션 or 음식
	_chest_give_slot_a()
	# 슬롯 B: 장비 or 재료
	_chest_give_slot_b()
	# 보너스 골드: 10~30G
	var chest_gold: int = randi() % 21 + 10
	player.gold += chest_gold
	hud.add_log("💰 골드 +%d (총 %dG)" % [chest_gold, player.gold])
	_refresh_hud()

func _chest_give_slot_a() -> void:
	if player.inventory.size() >= player.MAX_INVENTORY:
		hud.add_log("인벤토리가 가득 차 포션/음식을 받을 수 없습니다.")
		return
	var item := Item.new()
	if randi() % 2 == 0:
		item.item_type = Item.Type.FOOD
	else:
		var cidx: int = randi() % 6
		item.item_type = _potion_map[cidx]
		item.color_idx = cidx
	player.inventory.append(item)
	var ident: bool = not item.is_food() and _identified[item.color_idx]
	hud.add_log(item.get_display_name(ident) + " 획득! (상자 A)")

func _chest_give_slot_b() -> void:
	if player.inventory.size() >= player.MAX_INVENTORY:
		hud.add_log("인벤토리가 가득 차 장비/재료를 받을 수 없습니다.")
		return
	var item := Item.new()
	var roll: int = randi() % 12
	if roll < 4:
		# 장비
		var equip_types: Array = [
			Item.Type.WEAPON_WOOD, Item.Type.WEAPON_STONE, Item.Type.WEAPON_IRON,
			Item.Type.SHIELD_WOOD, Item.Type.SHIELD_IRON,
			Item.Type.ARMOR_CLOTH, Item.Type.ARMOR_LEATHER,
		]
		var etype: int = equip_types[randi() % equip_types.size()]
		item.item_type = etype
		if Item.EQUIPMENT_DATA.has(etype):
			item.durability = Item.EQUIPMENT_DATA[etype][3]
			item.max_durability = item.durability
	elif roll < 6:
		# 주문서 (일반 or 고대)
		if randi() % 4 == 0:
			item.item_type = Item.ANCIENT_SCROLL_TYPES[randi() % Item.ANCIENT_SCROLL_TYPES.size()]
		else:
			var sidx: int = randi() % 3
			item.item_type = Item.SCROLL_TYPES[sidx]
			item.color_idx = 6 + sidx
	else:
		# 재료
		var mat_types: Array = [
			Item.Type.MATERIAL_BRANCH, Item.Type.MATERIAL_HERB,
			Item.Type.MATERIAL_STONE, Item.Type.MATERIAL_CLOTH,
			Item.Type.MATERIAL_ORE, Item.Type.MATERIAL_TORCH,
		]
		item.item_type = mat_types[randi() % mat_types.size()]
	player.inventory.append(item)
	var b_ident: bool = not item.is_scroll() or _identified[item.color_idx]
	hud.add_log(item.get_display_name(b_ident) + " 획득! (상자 B)")

func _drop_item(item: Item, pos: Vector2i) -> void:
	floor_items.append({"pos": pos, "item": item})
	_refresh_floor_items()

func _refresh_floor_items() -> void:
	var by_pos: Dictionary = {}
	for fi in floor_items:
		var p: Vector2i = fi.pos
		if not by_pos.has(p):
			by_pos[p] = {"item": fi.item, "count": 0}
		by_pos[p].count += 1
		by_pos[p].item = fi.item  # 마지막 = 가장 최근 (스택 최상단)
	var visuals: Array[Dictionary] = []
	for p in by_pos:
		var d = by_pos[p]
		var it: Item = d.item
		visuals.append({"pos": p, "atlas": it.get_atlas(), "mod": it.get_modulate(), "count": d.count})
	map.update_floor_items(visuals)

func _try_pickup_floor_items() -> void:
	var pos: Vector2i = player.tile_pos
	var picked := false
	var i: int = floor_items.size() - 1
	while i >= 0:
		if floor_items[i].pos == pos:
			if player.inventory.size() >= player.MAX_INVENTORY:
				hud.add_log("인벤토리 가득! 아이템을 주울 수 없습니다.")
				break
			var it: Item = floor_items[i].item
			player.inventory.append(it)
			var ident: bool = it.item_type != Item.Type.FOOD and \
				it.color_idx < _identified.size() and _identified[it.color_idx]
			hud.add_log("%s 획득!" % it.get_display_name(ident))
			floor_items.remove_at(i)
			picked = true
		i -= 1
	if picked:
		_refresh_floor_items()
		_refresh_hud()

func _assign_trap_types() -> void:
	_trap_data.clear()
	for y in map.HEIGHT:
		for x in map.WIDTH:
			if map.get_cell(x, y) == map.Cell.TRAP:
				_trap_data[Vector2i(x, y)] = randi() % 10

func _on_enemy_trap(tile_pos: Vector2i, enemy) -> void:
	var trap_type: int = _trap_data.get(tile_pos, 0)
	if trap_type != 3:  # 스파이크 함정은 비활성화 안 됨
		map.set_cell(tile_pos.x, tile_pos.y, map.Cell.FLOOR)
		_trap_data.erase(tile_pos)
	if not is_instance_valid(enemy):
		return
	_spawn_hit(enemy.position)
	var dmg: int = enemy.take_damage(5)
	hud.add_log("함정! %s에게 %d 피해!" % [enemy.display_name, dmg])
	if enemy.is_dead():
		var reward: int = 5 * player.floor_num
		hud.add_log("%s 처치! EXP +%d" % [enemy.display_name, reward])
		enemy_manager.remove_enemy(enemy)
		player.gain_exp(reward)

func _trigger_trap(pos: Vector2i) -> void:
	var trap_type: int = _trap_data.get(pos, randi() % 10)
	# 스파이크 함정은 계속 활성
	if trap_type != 3:
		map.set_cell(pos.x, pos.y, map.Cell.FLOOR)
		_trap_data.erase(pos)
	_spawn_hit(player.position)
	match trap_type:
		0:  # 독가시
			player.take_damage(5, "독가시 함정")
			player.apply_status("poison", Item.POISON_TURNS)
			_spawn_poison(player.position)
			hud.add_log("독가시 함정! HP -5 + 독")
		1:  # 화염
			player.take_damage(8, "화염 함정")
			player.apply_status("fire", Item.FIRE_TURNS)
			_spawn_fire(player.position)
			hud.add_log("화염 함정! HP -8 + 화상")
		2:  # 텔레포트
			var floor_tiles: Array[Vector2i] = []
			for y in map.HEIGHT:
				for x in map.WIDTH:
					if map.is_walkable(x, y) and map.get_cell(x, y) == map.Cell.FLOOR:
						floor_tiles.append(Vector2i(x, y))
			if not floor_tiles.is_empty():
				floor_tiles.shuffle()
				player.tile_pos = floor_tiles[0]
				player.position = map.tile_to_world(player.tile_pos)
				_update_fov()
			hud.add_log("텔레포트 함정! 랜덤 위치로 이동했습니다.")
		3:  # 스파이크 (비활성화 안 됨, 반복 발동)
			player.take_damage(15, "스파이크 함정")
			hud.add_log("스파이크 함정! HP -15")
		4:  # 부상
			player.take_damage(3, "부상 함정")
			player.apply_status("wound", WOUND_TURNS)
			hud.add_log("부상 함정! HP -3 + 부상 (%d턴)" % WOUND_TURNS)
		5:  # 독구름
			player.apply_status("poison", Item.POISON_TURNS * 2)
			_spawn_poison(player.position)
			hud.add_log("독구름 함정! 강한 독 상태이상")
		6:  # 마비가스
			player.apply_status("paralyze", PARALYZE_TURNS)
			hud.add_log("마비가스 함정! 마비 (%d턴)" % PARALYZE_TURNS)
		7:  # 얼음
			player.apply_status("frozen", FROZEN_TURNS)
			hud.add_log("얼음 함정! 빙결 (%d턴)" % FROZEN_TURNS)
		8:  # 소환: 1~3마리 근처 소환
			var summon_count: int = randi() % 3 + 1
			for _i in summon_count:
				enemy_manager.spawn_one_near(pos, map, player.floor_num)
			hud.add_log("소환 함정! 몬스터 %d마리가 나타났다!" % summon_count)
		9:  # 알람: 층 내 모든 적이 플레이어 위치 인식
			for e in enemy_manager.enemies:
				e.is_alerted = true
			hud.add_log("알람 함정! 요란한 소리에 몬스터들이 몰려온다!")
	_refresh_hud()
	if player.hp <= 0:
		_trigger_game_over()

func _apply_scroll(sidx: int) -> void:
	match sidx:
		0:  # SCROLL_BASH
			player.next_atk_multiplier = 3
			hud.add_log("강타 주문서! 다음 공격 3배 데미지!")
		1:  # SCROLL_TELEPORT
			var floor_tiles: Array[Vector2i] = []
			for fy in map.HEIGHT:
				for fx in map.WIDTH:
					if map.is_walkable(fx, fy) and map.get_cell(fx, fy) == map.Cell.FLOOR:
						floor_tiles.append(Vector2i(fx, fy))
			if not floor_tiles.is_empty():
				floor_tiles.shuffle()
				player.tile_pos = floor_tiles[0]
				player.position = map.tile_to_world(player.tile_pos)
				_update_fov()
			hud.add_log("순간이동 주문서! 랜덤 위치로 이동했습니다.")
		2:  # SCROLL_IDENTIFY
			_identified.fill(true)
			hud.add_log("식별 주문서! 모든 아이템이 식별되었습니다.")

func _try_enhance() -> String:
	var target: Item = player.equipped_weapon
	if target == null:
		return ""
	if target.enhance_level >= MAX_ENHANCE:
		return ""
	target.enhance_level += 1
	var original_max: int = Item.EQUIPMENT_DATA[target.item_type][3]
	target.max_durability = original_max
	target.durability = original_max
	player._recalc_equip_stats()
	player.stats_changed.emit()
	var wname: String = Item.EQUIPMENT_DATA[target.item_type][0]
	return "%s +%d 강화 완료! (내구도 완전 회복)" % [wname, target.enhance_level]

func _create_random_item() -> Item:
	var item := Item.new()
	var roll := randi() % 12
	if roll == 0:
		item.item_type = Item.Type.SCROLL_ENHANCE
	elif roll <= 2:
		item.item_type = Item.Type.FOOD
	elif roll == 3:
		item.item_type = Item.Type.MATERIAL_CLOTH
	else:
		item.color_idx = randi() % 6
		item.item_type = _potion_map[item.color_idx]
	return item

func _on_item_action(idx: int, action: String) -> void:
	if idx < 0 or idx >= player.inventory.size():
		return

	if action == "throw":
		_throw_item_idx = idx
		hud.close_inventory()
		_enter_throw_mode()
		return

	var item: Item = player.inventory[idx]
	if action == "place":
		var ident_place: bool = item.item_type != Item.Type.FOOD and \
			item.color_idx < _identified.size() and _identified[item.color_idx]
		hud.add_log("%s 바닥에 두었습니다." % item.get_display_name(ident_place))
		player.inventory.remove_at(idx)
		_drop_item(item, player.tile_pos)
		hud.close_inventory()
		_refresh_hud()
		return
	match action:
		"equip":
			player.inventory.remove_at(idx)
			player.equip(item)
			hud.add_log("%s 장착!" % item.get_display_name(true))
			hud.close_inventory()
			_refresh_hud()
			return
		"use":
			if item.item_type == Item.Type.TOOL_REPAIR:
				var msg := item.apply(player)
				hud.add_log(msg)
				player.inventory.remove_at(idx)
				hud.close_inventory()
				_refresh_hud()
				return
			if item.item_type == Item.Type.SCROLL_ENHANCE:
				var msg := _try_enhance()
				if msg == "":
					hud.add_log("장착된 무기가 없거나 최대 강화 상태입니다.")
					hud.close_inventory()
					return
				hud.add_log(msg)
				player.inventory.remove_at(idx)
				hud.close_inventory()
				_refresh_hud()
				return
			if item.is_ancient_scroll():
				var spell_id: String = Item.get_spell_id_for_type(item.item_type)
				var msg: String = player.learn_spell(spell_id)
				hud.add_log(msg)
				player.inventory.remove_at(idx)
				hud.close_inventory()
				_refresh_hud()
				return
			if item.is_scroll():
				var sidx: int = item.color_idx - 6
				if sidx < 0 or sidx > 2:
					hud.add_log("알 수 없는 주문서입니다.")
					hud.close_inventory()
					return
				var was_identified: bool = _identified[item.color_idx]
				_identified[item.color_idx] = true
				if not was_identified:
					hud.add_log("낡은 주문서의 정체가 밝혀졌다! → %s" % item.get_display_name(true))
					_run_explore_xp += 50
				_apply_scroll(sidx)
				player.inventory.remove_at(idx)
				hud.close_inventory()
				_refresh_hud()
				enemy_manager.do_turns(player.tile_pos)
				return
			if item.item_type != Item.Type.FOOD and item.item_type != Item.Type.COOKED_FOOD:
				var was_identified: bool = _identified[item.color_idx]
				_identified[item.color_idx] = true
				if not was_identified:
					_run_explore_xp += 50
				var result := item.apply(player)
				if not was_identified:
					hud.add_log(item.get_reveal_text())
				hud.add_log(result)
				match item.item_type:
					Item.Type.POTION_POISON: _spawn_poison(player.position)
					Item.Type.POTION_FIRE:   _spawn_fire(player.position)
				# 포션 사용 후 빈병 획득
				if player.inventory.size() < player.MAX_INVENTORY - 1:
					var bottle := Item.new()
					bottle.item_type = Item.Type.MATERIAL_BOTTLE
					player.inventory.append(bottle)
					hud.add_log("빈병을 얻었습니다.")
			else:
				hud.add_log(item.apply(player))
		"disassemble":
			var mat_count: int = randi() % 2 + 1
			var mat_type: Item.Type
			if item.is_weapon():
				mat_type = Item.Type.MATERIAL_ORE
			else:
				mat_type = Item.Type.MATERIAL_CLOTH if randi() % 2 == 0 else Item.Type.MATERIAL_ORE
			for _i in mat_count:
				if player.inventory.size() < player.MAX_INVENTORY:
					var mat := Item.new()
					mat.item_type = mat_type
					player.inventory.append(mat)
			hud.add_log("%s 분해! %s ×%d 획득" % [item.get_display_name(true), Item.get_type_name(mat_type), mat_count])
		"discard":
			var ident_discard: bool = item.item_type != Item.Type.FOOD and _identified[item.color_idx]
			hud.add_log(item.get_display_name(ident_discard) + "을 버렸습니다.")

	player.inventory.remove_at(idx)
	hud.close_inventory()
	_refresh_hud()

# ── 던지기 ─────────────────────────────────────────────────────────────────

func _enter_throw_mode() -> void:
	_throw_mode = true
	player.input_blocked = true
	var tiles: Array[Vector2i] = []
	for dy in range(-THROW_RANGE, THROW_RANGE + 1):
		for dx in range(-THROW_RANGE, THROW_RANGE + 1):
			var dist: int = abs(dx) + abs(dy)
			if dist == 0 or dist > THROW_RANGE:
				continue
			var tile: Vector2i = player.tile_pos + Vector2i(dx, dy)
			if map.is_walkable(tile.x, tile.y):
				tiles.append(tile)
	map.throw_highlight_tiles = tiles
	map.queue_redraw()
	hud.set_throw_mode(true)
	hud.add_log("던질 위치를 선택하세요.")

func _exit_throw_mode() -> void:
	_throw_mode = false
	player.input_blocked = false
	map.throw_highlight_tiles = []
	map.queue_redraw()
	hud.set_throw_mode(false)

func _on_throw_cancelled() -> void:
	_exit_throw_mode()
	hud.add_log("던지기 취소")

func _execute_throw(target_tile: Vector2i) -> void:
	var dist: int = abs(target_tile.x - player.tile_pos.x) + abs(target_tile.y - player.tile_pos.y)
	if dist == 0 or dist > THROW_RANGE or not map.is_walkable(target_tile.x, target_tile.y):
		_exit_throw_mode()
		hud.add_log("던지기 취소")
		return

	_exit_throw_mode()

	if _throw_item_idx < 0 or _throw_item_idx >= player.inventory.size():
		return

	var item: Item = player.inventory[_throw_item_idx]

	# 독/불은 던질 때 정체 공개
	if item.item_type != Item.Type.FOOD and item.reveals_on_throw():
		var was_identified: bool = _identified[item.color_idx]
		_identified[item.color_idx] = true
		if not was_identified:
			hud.add_log(item.get_reveal_text())

	match item.item_type:
		Item.Type.POTION_POISON:
			var target = enemy_manager.get_enemy_at(target_tile)
			if target:
				_spawn_hit(target.position)
				_spawn_poison(target.position)
				_apply_throw_damage(target, 8, item.get_display_name(true))
				target.apply_status("poison", Item.POISON_TURNS)
			else:
				_spawn_poison(map.tile_to_world(target_tile))
				hud.add_log(item.get_display_name(true) + "이 허공에 깨졌다.")
		Item.Type.POTION_FIRE:
			_spawn_hit(map.tile_to_world(target_tile))
			_spawn_fire(map.tile_to_world(target_tile))
			var hit_any := false
			var center = enemy_manager.get_enemy_at(target_tile)
			if center:
				_apply_throw_damage(center, 10, item.get_display_name(true))
				center.apply_status("fire", Item.FIRE_TURNS)
				hit_any = true
			for adj in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var e = enemy_manager.get_enemy_at(target_tile + adj)
				if e and is_instance_valid(e):
					_spawn_hit(e.position)
					_spawn_fire(e.position)
					_apply_throw_damage(e, 5, item.get_display_name(true))
					e.apply_status("fire", Item.FIRE_TURNS_ADJ)
					hit_any = true
			if not hit_any:
				hud.add_log(item.get_display_name(true) + "이 타오르며 사라졌다.")
		Item.Type.POTION_SLEEP:
			var target = enemy_manager.get_enemy_at(target_tile)
			if target:
				_spawn_hit(target.position)
				target.apply_status("sleep", Item.SLEEP_TURNS)
				hud.add_log("%s이 잠들었다! (%d턴)" % [target.display_name, Item.SLEEP_TURNS])
			else:
				hud.add_log(item.get_display_name(true) + "이 허공에 깨졌다.")
		Item.Type.POTION_CLEANSE:
			var target = enemy_manager.get_enemy_at(target_tile)
			if target:
				_spawn_hit(target.position)
				target.cleanse()
				hud.add_log("%s의 상태이상이 해제되었다..." % target.display_name)
			else:
				hud.add_log(item.get_display_name(true) + "이 깨졌다.")
		Item.Type.FOOD:
			if map.get_cell(target_tile.x, target_tile.y) == map.Cell.CAMPFIRE:
				var cooked := Item.new()
				cooked.item_type = Item.Type.COOKED_FOOD
				_drop_item(cooked, target_tile)
				hud.add_log("식량이 모닥불에 구워졌다! 익은 식량이 놓였다.")
			else:
				_drop_item(item, target_tile)
				hud.add_log("식량이 바닥에 떨어졌다.")
		_:
			if item.is_equipment() or item.is_material() or item.item_type == Item.Type.COOKED_FOOD:
				_drop_item(item, target_tile)
				hud.add_log(item.get_display_name(true) + "이 바닥에 떨어졌다.")
			else:
				var ident_throw: bool = _identified[item.color_idx]
				hud.add_log(item.get_display_name(ident_throw) + "이 깨졌습니다.")

	player.inventory.remove_at(_throw_item_idx)
	_throw_item_idx = -1
	_refresh_hud()
	enemy_manager.do_turns(player.tile_pos)

func _apply_throw_damage(enemy, dmg: int, source: String) -> void:
	var actual: int = enemy.take_damage(dmg)
	hud.add_log("%s → %s에게 %d 피해!" % [source, enemy.display_name, actual])
	if enemy.is_dead():
		var reward: int = 5 * player.floor_num
		hud.add_log("%s 처치! EXP +%d" % [enemy.display_name, reward])
		enemy_manager.remove_enemy(enemy)
		player.gain_exp(reward)

# ── Game over / Clear ──────────────────────────────────────────────────────

func _trigger_game_over() -> void:
	player.input_blocked = true
	SaveData.update_best_floor(player.floor_num)
	SaveData.award_chest(player.floor_num)
	SaveData.add_explore_xp(_run_explore_xp)
	hud.add_log("탐험경험치 +%d XP 획득!" % _run_explore_xp)
	_run_explore_xp = 0
	hud.show_game_over()

func _trigger_game_clear() -> void:
	hud.show_game_clear()
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.4)
	await tween.finished

func _on_craft_recipe(recipe_idx: int) -> void:
	var recipe: Array = Item.RECIPES[recipe_idx]
	var mats: Array = recipe[2]
	for mat in mats:
		var have: int = 0
		for item in player.inventory:
			if item.item_type == mat[0]: have += 1
		if have < mat[1]:
			hud.add_log("재료가 부족합니다.")
			return
	for mat in mats:
		var need: int = mat[1]
		var i: int = player.inventory.size() - 1
		while i >= 0 and need > 0:
			if player.inventory[i].item_type == mat[0]:
				player.inventory.remove_at(i)
				need -= 1
			i -= 1
	var result := Item.new()
	result.item_type = recipe[0] as int
	result.durability = recipe[1] as int
	result.max_durability = recipe[1] as int
	player.inventory.append(result)
	hud.add_log("%s 제작 완료!" % Item.get_type_name(recipe[0]))
	_refresh_hud()

# ── 모닥불 상호작용 ─────────────────────────────────────────────────────────────

func _on_campfire_approached(tile_pos: Vector2i) -> void:
	_campfire_tile_pos = tile_pos
	hud.show_campfire_popup()

# ── 상인 상점 ───────────────────────────────────────────────────────────────

func _is_merchant_floor(n: int) -> bool:
	return n % 5 == 3

func _item_buy_price(item: Item) -> int:
	var identified: bool = item.color_idx < _identified.size() and _identified[item.color_idx]
	if item.is_equipment():
		match item.item_type:
			Item.Type.WEAPON_IRON:    return 250
			Item.Type.WEAPON_STONE:   return 120
			Item.Type.WEAPON_WOOD:    return 60
			Item.Type.SHIELD_WOOD:    return 80
			Item.Type.SHIELD_IRON:    return 200
			Item.Type.ARMOR_CLOTH:    return 80
			Item.Type.ARMOR_LEATHER:  return 180
	if item.is_scroll():
		return 120 if identified else 50
	match item.item_type:
		Item.Type.POTION_HEAL:    return 80 if identified else 30
		Item.Type.POTION_HUNGER:  return 60 if identified else 30
		Item.Type.POTION_POISON:  return 50 if identified else 30
		Item.Type.POTION_FIRE:    return 50 if identified else 30
		Item.Type.POTION_CLEANSE: return 50 if identified else 30
		Item.Type.POTION_SLEEP:   return 50 if identified else 30
		Item.Type.FOOD, Item.Type.COOKED_FOOD: return 40
		Item.Type.MATERIAL_BRANCH, Item.Type.MATERIAL_STONE, Item.Type.MATERIAL_CLOTH: return 15
		Item.Type.MATERIAL_HERB:  return 20
		Item.Type.MATERIAL_ORE:   return 25
	return 20

func _item_sell_price(item: Item) -> int:
	return max(1, _item_buy_price(item) / 2)

func _generate_shop() -> void:
	_shop_items.clear()
	var count: int = 6 + randi() % 3   # 6~8개
	for _i in count:
		var item := _create_shop_item()
		_shop_items.append({"item": item, "price": _item_buy_price(item), "sold": false})

func _create_shop_item() -> Item:
	var item := Item.new()
	var roll: int = randi() % 10
	if roll < 3:
		var cidx: int = randi() % 6
		item.item_type = _potion_map[cidx]
		item.color_idx = cidx
	elif roll < 5:
		var equip_types: Array = [
			Item.Type.WEAPON_WOOD, Item.Type.WEAPON_STONE, Item.Type.WEAPON_IRON,
			Item.Type.SHIELD_WOOD, Item.Type.SHIELD_IRON,
			Item.Type.ARMOR_CLOTH, Item.Type.ARMOR_LEATHER,
		]
		var etype: int = equip_types[randi() % equip_types.size()]
		item.item_type = etype
		if Item.EQUIPMENT_DATA.has(etype):
			item.durability = Item.EQUIPMENT_DATA[etype][3]
			item.max_durability = item.durability
	elif roll < 7:
		var sidx: int = randi() % 3
		item.item_type = Item.SCROLL_TYPES[sidx]
		item.color_idx = 6 + sidx
	elif roll < 9:
		item.item_type = Item.Type.FOOD
	else:
		var mats: Array = [Item.Type.MATERIAL_BRANCH, Item.Type.MATERIAL_HERB,
			Item.Type.MATERIAL_STONE, Item.Type.MATERIAL_CLOTH]
		item.item_type = mats[randi() % mats.size()]
	return item

func _sell_prices_for_inventory() -> Array[int]:
	var prices: Array[int] = []
	for item in player.inventory:
		prices.append(_item_sell_price(item))
	return prices

func _on_merchant_approached(_tile_pos: Vector2i) -> void:
	if _shop_items.is_empty():
		_generate_shop()
	hud.show_merchant_popup(_shop_items, _sell_prices_for_inventory())

func _on_merchant_buy(shop_idx: int) -> void:
	if shop_idx < 0 or shop_idx >= _shop_items.size():
		return
	var d: Dictionary = _shop_items[shop_idx]
	if d.sold:
		return
	var price: int = d.price
	if player.gold < price:
		hud.add_log("골드가 부족합니다! (보유: %dG, 필요: %dG)" % [player.gold, price])
		return
	if player.inventory.size() >= player.MAX_INVENTORY:
		hud.add_log("인벤토리가 가득 찼습니다.")
		return
	player.gold -= price
	var bought_item: Item = d.item
	player.inventory.append(bought_item)
	d.sold = true
	_shop_items[shop_idx] = d
	var ident: bool = bought_item.color_idx < _identified.size() and _identified[bought_item.color_idx]
	hud.add_log("%s 구매! -%dG (잔액: %dG)" % [bought_item.get_display_name(ident), price, player.gold])
	hud.update_merchant_data(_shop_items, _sell_prices_for_inventory())
	_refresh_hud()

func _on_merchant_sell(inv_idx: int) -> void:
	if inv_idx < 0 or inv_idx >= player.inventory.size():
		return
	var item: Item = player.inventory[inv_idx]
	var sp: int = _item_sell_price(item)
	var ident: bool = item.color_idx < _identified.size() and _identified[item.color_idx]
	player.inventory.remove_at(inv_idx)
	player.gold += sp
	hud.add_log("%s 판매! +%dG (잔액: %dG)" % [item.get_display_name(ident), sp, player.gold])
	hud.update_merchant_data(_shop_items, _sell_prices_for_inventory())
	_refresh_hud()

func _on_campfire_action(action: String) -> void:
	match action:
		"camp":
			_do_camp(_campfire_tile_pos)
		"cook":
			var food_indices: Array[int] = []
			for i in player.inventory.size():
				var it: Item = player.inventory[i]
				if it.item_type == Item.Type.FOOD or it.item_type == Item.Type.COOKED_FOOD:
					food_indices.append(i)
			if food_indices.is_empty():
				hud.add_log("요리할 식량이 없습니다.")
				enemy_manager.do_turns(player.tile_pos)
			else:
				hud.show_cook_popup(food_indices)
		"cancel":
			enemy_manager.do_turns(player.tile_pos)

func _on_campfire_cook_selected(item_idx: int) -> void:
	if item_idx < 0 or item_idx >= player.inventory.size():
		return
	var item: Item = player.inventory[item_idx]
	if item.item_type != Item.Type.FOOD:
		hud.add_log("이 재료는 구울 수 없습니다.")
		enemy_manager.do_turns(player.tile_pos)
		return
	player.inventory.remove_at(item_idx)
	var cooked := Item.new()
	cooked.item_type = Item.Type.COOKED_FOOD
	player.inventory.append(cooked)
	hud.add_log("식량을 구웠습니다! 익은 식량 획득.")
	_refresh_hud()
	enemy_manager.do_turns(player.tile_pos)

func _do_camp(tile_pos: Vector2i) -> void:
	player.input_blocked = true
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	await tween.finished

	player.fatigue = 0
	player.hp = min(player.max_hp, player.hp + 5)
	map.set_cell(tile_pos.x, tile_pos.y, map.Cell.CAMPFIRE_OUT)
	hud.add_log("야영! 피로도 완전 회복, HP +5")
	hud.add_log("모닥불이 꺼졌습니다.")
	_update_fov()
	_refresh_hud()

	tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)
	await tween.finished
	player.input_blocked = false
	enemy_manager.do_turns(player.tile_pos)

# ── 꺼진 모닥불 재점화 ───────────────────────────────────────────────────────────

func _on_campfire_out_approached(tile_pos: Vector2i) -> void:
	var has_fuel := false
	for inv_item in player.inventory:
		if inv_item.item_type == Item.Type.MATERIAL_BRANCH \
				or inv_item.item_type == Item.Type.MATERIAL_TORCH:
			has_fuel = true
			break
	if not has_fuel:
		hud.add_log("재료가 없습니다. (나뭇가지 또는 횃불 필요)")
		enemy_manager.do_turns(player.tile_pos)
		return
	hud.show_confirm("불을 피울까요?\n(나뭇가지 또는 횃불 소모)",
		_on_relight_confirmed.bind(tile_pos), _on_relight_cancelled)

func _on_relight_confirmed(tile_pos: Vector2i) -> void:
	# 나뭇가지 우선, 없으면 횃불 소모
	var priority := [Item.Type.MATERIAL_BRANCH, Item.Type.MATERIAL_TORCH]
	for fuel_type in priority:
		for i in player.inventory.size():
			var inv_item: Item = player.inventory[i]
			if inv_item.item_type == fuel_type:
				player.inventory.remove_at(i)
				map.set_cell(tile_pos.x, tile_pos.y, map.Cell.CAMPFIRE)
				hud.add_log("불을 피웠습니다!")
				_update_fov()
				_refresh_hud()
				enemy_manager.do_turns(player.tile_pos)
				return

func _on_relight_cancelled() -> void:
	enemy_manager.do_turns(player.tile_pos)

# ── 문 상호작용 ─────────────────────────────────────────────────────────────

func _on_door_approached(tile_pos: Vector2i) -> void:
	map.set_cell(tile_pos.x, tile_pos.y, map.Cell.DOOR_OPEN)
	hud.add_log("문을 열었습니다.")
	_update_fov()
	enemy_manager.do_turns(player.tile_pos)

# ── 연금술 솥 상호작용 ──────────────────────────────────────────────────────

func _on_cauldron_approached(tile_pos: Vector2i) -> void:
	var bottle_count: int = 0
	var mat_count: int = 0
	for item in player.inventory:
		if item.item_type == Item.Type.MATERIAL_BOTTLE:
			bottle_count += 1
		elif item.is_material():
			mat_count += 1
	if bottle_count == 0 or mat_count < 2:
		hud.add_log("재료가 부족합니다. (빈병 ×1 + 재료 ×2 필요)")
		enemy_manager.do_turns(player.tile_pos)
		return
	var is_white: bool = map.get_cell(tile_pos.x, tile_pos.y) == map.Cell.WHITE_CAULDRON
	var label := "흰 솥 (좋은 물약)" if is_white else "검은 솥 (나쁜 물약)"
	hud.show_confirm("연금술 솥 [%s]\n빈병 ×1 + 재료 ×2 소모하여\n물약을 만드시겠습니까?" % label,
		_on_cauldron_confirmed.bind(is_white), _on_cauldron_cancelled)

func _on_cauldron_confirmed(is_white: bool) -> void:
	# 빈병 1개 제거
	for i in player.inventory.size():
		if player.inventory[i].item_type == Item.Type.MATERIAL_BOTTLE:
			player.inventory.remove_at(i)
			break
	# 재료 2개 제거 (아무거나)
	var removed: int = 0
	var i: int = player.inventory.size() - 1
	while i >= 0 and removed < 2:
		if player.inventory[i].is_material():
			player.inventory.remove_at(i)
			removed += 1
		i -= 1
	# 물약 생성
	var result := Item.new()
	var cidx: int
	if is_white:
		var good: Array = [_potion_map.find(Item.Type.POTION_HEAL),
			_potion_map.find(Item.Type.POTION_HUNGER),
			_potion_map.find(Item.Type.POTION_CLEANSE)]
		good = good.filter(func(x): return x >= 0)
		cidx = good[randi() % good.size()] if not good.is_empty() else randi() % 6
	else:
		var bad: Array = [_potion_map.find(Item.Type.POTION_POISON),
			_potion_map.find(Item.Type.POTION_FIRE),
			_potion_map.find(Item.Type.POTION_SLEEP)]
		bad = bad.filter(func(x): return x >= 0)
		cidx = bad[randi() % bad.size()] if not bad.is_empty() else randi() % 6
	result.item_type = _potion_map[cidx]
	result.color_idx = cidx
	player.inventory.append(result)
	var ident: bool = _identified[cidx]
	hud.add_log("연금술 성공! %s 획득!" % result.get_display_name(ident))
	_refresh_hud()
	enemy_manager.do_turns(player.tile_pos)

func _on_cauldron_cancelled() -> void:
	enemy_manager.do_turns(player.tile_pos)

# ── 이상한 우물 상호작용 ────────────────────────────────────────────────────

func _on_well_approached(tile_pos: Vector2i) -> void:
	_well_tile_pos = tile_pos
	if player.inventory.is_empty():
		hud.add_log("바칠 아이템이 없습니다.")
		enemy_manager.do_turns(player.tile_pos)
		return
	var indices: Array[int] = []
	for i in player.inventory.size():
		indices.append(i)
	hud.show_well_popup(indices)

func _on_well_item_selected(inv_idx: int) -> void:
	if inv_idx < 0 or inv_idx >= player.inventory.size():
		enemy_manager.do_turns(player.tile_pos)
		return
	var item: Item = player.inventory[inv_idx]
	var ident: bool = item.color_idx < _identified.size() and _identified[item.color_idx]
	var item_name: String = item.get_display_name(ident)
	player.inventory.remove_at(inv_idx)

	var roll: int = randi() % 100
	if roll < 50:
		# 같은 종류 다른 아이템
		var new_item := _create_well_transform(item)
		player.inventory.append(new_item)
		var n_ident: bool = new_item.color_idx < _identified.size() and _identified[new_item.color_idx]
		hud.add_log("우물이 %s을(를) %s으로 변환했습니다!" % [item_name, new_item.get_display_name(n_ident)])
	elif roll < 80:
		# 강화 +1 (장비인 경우) or 새 아이템 반환
		if item.is_equipment() and item.enhance_level < MAX_ENHANCE:
			item.enhance_level += 1
			player.inventory.append(item)
			hud.add_log("우물이 %s을(를) 강화했습니다! +%d" % [item_name, item.enhance_level])
		else:
			player.inventory.append(item)
			hud.add_log("우물이 빛났지만... 아무 일도 없었습니다.")
	elif roll < 95:
		# 축복
		item.is_blessed = true
		item.is_cursed = false
		player.inventory.append(item)
		hud.add_log("우물이 %s을(를) 축복했습니다! [축복]" % item_name)
	else:
		# 소멸 or 저주
		if randi() % 2 == 0:
			hud.add_log("우물이 %s을(를) 삼켜버렸습니다!" % item_name)
		else:
			item.is_cursed = true
			item.is_blessed = false
			player.inventory.append(item)
			hud.add_log("우물이 %s에 저주를 걸었습니다! [저주]" % item_name)
	# 우물은 한 번만 사용 가능 — 사용 후 바닥으로 변환
	if _well_tile_pos != Vector2i(-1, -1):
		map.set_cell(_well_tile_pos.x, _well_tile_pos.y, map.Cell.FLOOR)
		_well_tile_pos = Vector2i(-1, -1)
	_refresh_hud()
	enemy_manager.do_turns(player.tile_pos)

func _create_well_transform(original: Item) -> Item:
	var result := Item.new()
	if original.is_equipment():
		var types: Array = [Item.Type.WEAPON_WOOD, Item.Type.WEAPON_STONE, Item.Type.WEAPON_IRON,
			Item.Type.SHIELD_WOOD, Item.Type.SHIELD_IRON, Item.Type.ARMOR_CLOTH, Item.Type.ARMOR_LEATHER]
		var etype: int = types[randi() % types.size()]
		result.item_type = etype
		if Item.EQUIPMENT_DATA.has(etype):
			result.durability = Item.EQUIPMENT_DATA[etype][3]
			result.max_durability = result.durability
	elif original.is_scroll():
		var sidx: int = randi() % 3
		result.item_type = Item.SCROLL_TYPES[sidx]
		result.color_idx = 6 + sidx
	elif original.is_food():
		result.item_type = [Item.Type.FOOD, Item.Type.COOKED_FOOD][randi() % 2]
	else:
		# 물약
		var cidx: int = randi() % 6
		result.item_type = _potion_map[cidx]
		result.color_idx = cidx
	return result

# ── 샘 상호작용 ────────────────────────────────────────────────────────────

func _trigger_spring(pos: Vector2i, cell: int) -> void:
	map.set_cell(pos.x, pos.y, map.Cell.FLOOR)
	if cell == map.Cell.TAINTED_SPRING:
		if randi() % 2 == 0:
			var heal: int = randi() % 6 + 5
			player.hp = min(player.max_hp, player.hp + heal)
			hud.add_log("오염된 샘! HP +%d 회복" % heal)
		else:
			player.apply_status("poison", Item.POISON_TURNS)
			hud.add_log("오염된 샘! 독에 오염되었습니다!")
	else:  # CLEAR_SPRING
		var heal: int = randi() % 11 + 10
		player.hp = min(player.max_hp, player.hp + heal)
		player.mp = min(player.max_mp, player.mp + 10)
		player.hunger = max(0, player.hunger - 250)
		player.fatigue = max(0, player.fatigue - 250)
		player.poison_turns = 0
		player.fire_turns = 0
		player.sleep_turns = 0
		player.paralyze_turns = 0
		player.wound_turns = 0
		hud.add_log("맑은 샘! HP +%d, MP +10, 상태이상 해제, 허기·피로 감소" % heal)
	_refresh_hud()
	if player.hp <= 0:
		_trigger_game_over()

# ── 제단 상호작용 ────────────────────────────────────────────────────────────

func _trigger_altar(pos: Vector2i, cell: int) -> void:
	map.set_cell(pos.x, pos.y, map.Cell.FLOOR)
	if player.inventory.size() >= player.MAX_INVENTORY:
		hud.add_log("인벤토리가 가득 차 제단 아이템을 가져올 수 없습니다.")
		return
	var item := Item.new()
	if cell == map.Cell.ALTAR_BIG:
		# 큰 제단: 더 좋은 아이템 (장비 위주)
		var types: Array = [
			Item.Type.WEAPON_IRON, Item.Type.SHIELD_IRON,
			Item.Type.ARMOR_LEATHER, Item.Type.SCROLL_ENHANCE,
		]
		var t: int = types[randi() % types.size()]
		item.item_type = t
		if Item.EQUIPMENT_DATA.has(t):
			item.durability = Item.EQUIPMENT_DATA[t][3]
			item.max_durability = item.durability
		item.enhance_level = 1
	else:
		# 일반 제단: 장비 or 주문서
		if randi() % 2 == 0:
			var equips: Array = [Item.Type.WEAPON_STONE, Item.Type.WEAPON_IRON,
				Item.Type.SHIELD_WOOD, Item.Type.SHIELD_IRON, Item.Type.ARMOR_CLOTH]
			var t: int = equips[randi() % equips.size()]
			item.item_type = t
			if Item.EQUIPMENT_DATA.has(t):
				item.durability = Item.EQUIPMENT_DATA[t][3]
				item.max_durability = item.durability
		else:
			var sidx: int = randi() % 3
			item.item_type = Item.SCROLL_TYPES[sidx]
			item.color_idx = 6 + sidx
	player.inventory.append(item)
	var label := "대제단" if cell == map.Cell.ALTAR_BIG else "제단"
	hud.add_log("%s에서 %s 획득!" % [label, item.get_display_name(true)])
	_refresh_hud()

# ── 약초밭 상호작용 ──────────────────────────────────────────────────────────

func _trigger_herb(pos: Vector2i, cell: int) -> void:
	map.set_cell(pos.x, pos.y, map.Cell.FLOOR)
	var drop_type: int = -1
	match cell:
		map.Cell.HERB_ICE:
			player.apply_status("frozen", 2)
			hud.add_log("얼음송이밭! 빙결 상태 (2턴).")
			drop_type = Item.Type.MATERIAL_HERB_ICE
		map.Cell.HERB_BLOOD_MOSS:
			player.hp = max(0, player.hp - 3)
			player.apply_status("paralyze", 3)
			hud.add_log("피이끼밭! HP -3, 마비 (3턴).")
			drop_type = Item.Type.MATERIAL_HERB_BLOOD_MOSS
		map.Cell.HERB_GINSENG:
			var heal: int = randi_range(10, 15)
			player.hp = min(player.max_hp, player.hp + heal)
			hud.add_log("산삼밭! HP +%d 회복." % heal)
			drop_type = Item.Type.MATERIAL_HERB_GINSENG
		map.Cell.HERB_NIGHTSHADE:
			player.hp = max(0, player.hp - 5)
			player.apply_status("poison", Item.POISON_TURNS)
			hud.add_log("나이트쉐이드밭! HP -5, 독 (%d턴)." % Item.POISON_TURNS)
			for adj in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
						Vector2i(2,0), Vector2i(-2,0), Vector2i(0,2), Vector2i(0,-2)]:
				var e = enemy_manager.get_enemy_at(pos + adj)
				if e and is_instance_valid(e):
					e.apply_status("poison", Item.POISON_TURNS)
					hud.add_log("독가스가 %s에게 퍼졌다!" % e.display_name)
			drop_type = Item.Type.MATERIAL_HERB_NIGHTSHADE
		map.Cell.HERB_AMBROSIA:
			player.invincible_turns = 10
			hud.add_log("암브로시아밭! 무적 상태 (10턴).")
			drop_type = Item.Type.MATERIAL_HERB_AMBROSIA
		map.Cell.HERB_MUSHROOM:
			var heal: int = randi_range(6, 10)
			player.hp = min(player.max_hp, player.hp + heal)
			hud.add_log("영지버섯밭! HP +%d 재생." % heal)
			drop_type = Item.Type.MATERIAL_HERB_MUSHROOM
		map.Cell.HERB_MANDRAKE:
			if randi() % 5 == 0:
				player.hp = max(0, player.hp - 5)
				hud.add_log("만드라고라밭! 비명에 HP -5.")
			else:
				var mp_gain: int = randi_range(15, 20)
				player.mp = min(player.max_mp, player.mp + mp_gain)
				hud.add_log("만드라고라밭! MP +%d." % mp_gain)
			drop_type = Item.Type.MATERIAL_HERB_MANDRAKE
		map.Cell.HERB_FIREWORT:
			player.apply_status("fire", Item.FIRE_TURNS)
			hud.add_log("화염초밭! 화염 상태 (%d턴)." % Item.FIRE_TURNS)
			drop_type = Item.Type.MATERIAL_HERB_FIREWORT
		map.Cell.HERB_DREAMGRASS:
			player.hp = max(0, player.hp - 2)
			player.apply_status("sleep", Item.SLEEP_TURNS)
			player.fatigue = max(0, player.fatigue - 150)
			hud.add_log("꿈결초밭! HP -2, 수면 (%d턴), 피로도 -150." % Item.SLEEP_TURNS)
			drop_type = Item.Type.MATERIAL_HERB_DREAMGRASS
	if drop_type >= 0 and player.inventory.size() < player.MAX_INVENTORY:
		var herb_mat := Item.new()
		herb_mat.item_type = drop_type
		player.inventory.append(herb_mat)
		hud.add_log("%s 획득!" % Item.get_type_name(drop_type))
	player.stats_changed.emit()
	_refresh_hud()

# ── 해골더미 상호작용 ────────────────────────────────────────────────────────

func _on_skull_approached(tile_pos: Vector2i) -> void:
	map.set_cell(tile_pos.x, tile_pos.y, map.Cell.FLOOR)
	if player.inventory.size() >= player.MAX_INVENTORY:
		hud.add_log("인벤토리가 가득 차 해골더미를 뒤질 수 없습니다.")
	else:
		var item := Item.new()
		match randi() % 3:
			0:  # 장비
				var equips: Array = [Item.Type.WEAPON_WOOD, Item.Type.WEAPON_STONE,
					Item.Type.SHIELD_WOOD, Item.Type.ARMOR_CLOTH]
				var t: int = equips[randi() % equips.size()]
				item.item_type = t
				if Item.EQUIPMENT_DATA.has(t):
					item.durability = Item.EQUIPMENT_DATA[t][3]
					item.max_durability = item.durability
			1:  # 재료
				var mats: Array = [Item.Type.MATERIAL_BRANCH, Item.Type.MATERIAL_STONE,
					Item.Type.MATERIAL_CLOTH, Item.Type.MATERIAL_ORE]
				item.item_type = mats[randi() % mats.size()]
			2:  # 물약
				var cidx: int = randi() % 6
				item.item_type = _potion_map[cidx]
				item.color_idx = cidx
		player.inventory.append(item)
		hud.add_log("해골더미에서 %s 발견!" % item.get_display_name(item.color_idx < _identified.size() and _identified[item.color_idx]))
	_refresh_hud()
	enemy_manager.do_turns(player.tile_pos)

# ── 지식의 석판 상호작용 ──────────────────────────────────────────────────────

func _on_tablet_approached(tile_pos: Vector2i) -> void:
	map.set_cell(tile_pos.x, tile_pos.y, map.Cell.FLOOR)
	var unidentified: Array[int] = []
	for item in player.inventory:
		if item.color_idx >= 0 and item.color_idx < _identified.size() and not _identified[item.color_idx]:
			if item.color_idx not in unidentified:
				unidentified.append(item.color_idx)
	if unidentified.is_empty():
		hud.add_log("지식의 석판: 식별할 미확인 아이템이 없습니다.")
	else:
		var cidx: int = unidentified[randi() % unidentified.size()]
		_identified[cidx] = true
		hud.add_log("지식의 석판이 빛났다! 아이템이 식별되었습니다.")
	_refresh_hud()
	enemy_manager.do_turns(player.tile_pos)

# ── 석상 상호작용 ──────────────────────────────────────────────────────────

func _on_statue_approached(tile_pos: Vector2i, statue_type: String) -> void:
	map.set_cell(tile_pos.x, tile_pos.y, map.Cell.FLOOR)
	match statue_type:
		"warrior":
			if player.equipped_weapon:
				player.equipped_weapon.enhance_level = min(
					MAX_ENHANCE, player.equipped_weapon.enhance_level + 1)
				player._recalc_equip_stats()
				hud.add_log("전사의 석상! 무기가 +%d로 강화되었습니다." % player.equipped_weapon.enhance_level)
			elif player.equipped_armor:
				player.equipped_armor.enhance_level = min(
					MAX_ENHANCE, player.equipped_armor.enhance_level + 1)
				player._recalc_equip_stats()
				hud.add_log("전사의 석상! 갑옷이 +%d로 강화되었습니다." % player.equipped_armor.enhance_level)
			else:
				hud.add_log("전사의 석상: 강화할 장착 장비가 없습니다.")
		"wizard":
			player.mp = min(player.max_mp, player.mp + 15)
			player.max_mp += 5
			hud.add_log("마법사의 석상! 최대 MP +5, MP +15 회복")
		"angel":
			var roll: int = randi() % 6
			match roll:
				0:
					var heal: int = randi() % 10 + 10
					player.hp = min(player.max_hp, player.hp + heal)
					hud.add_log("천사 석상의 가호! HP +%d" % heal)
				1:
					player.mp = min(player.max_mp, player.mp + 20)
					hud.add_log("천사 석상의 가호! MP +20")
				2:
					player.fatigue = max(0, player.fatigue - 300)
					hud.add_log("천사 석상의 가호! 피로도 -300")
				3:
					player.max_hp += 3
					player.hp = min(player.hp + 3, player.max_hp)
					hud.add_log("천사 석상의 가호! 최대 HP +3")
				4:
					hud.add_log("천사 석상이 조용히 빛났지만... 아무 일도 없었습니다.")
				5:
					player.apply_status("paralyze", 2)
					hud.add_log("천사 석상의 저주! 마비 2턴")
	_refresh_hud()
	enemy_manager.do_turns(player.tile_pos)

# ── 책장 상호작용 ──────────────────────────────────────────────────────────

func _on_bookshelf_approached(tile_pos: Vector2i) -> void:
	map.set_cell(tile_pos.x, tile_pos.y, map.Cell.FLOOR)
	# 미식별 주문서/포션 중 1종 랜덤 식별
	var unidentified: Array[int] = []
	for i in _identified.size():
		if not _identified[i]:
			unidentified.append(i)
	if unidentified.is_empty():
		hud.add_log("책장: 모든 아이템이 이미 식별되어 있습니다.")
	else:
		var cidx: int = unidentified[randi() % unidentified.size()]
		_identified[cidx] = true
		hud.add_log("책장에서 지식을 얻었다! 아이템 1종이 식별되었습니다.")
	_refresh_hud()
	enemy_manager.do_turns(player.tile_pos)

func _give_class_starting_gear() -> void:
	var food := Item.new()
	food.item_type = Item.Type.FOOD
	player.inventory.append(food)

	match player.class_type:
		Player.ClassType.WARRIOR:
			_equip_start_weapon(Item.Type.WEAPON_SHORTSWORD)
			_equip_start_armor(Item.Type.ARMOR_CLOTH)
			for _i in 5:
				var dart := Item.new(); dart.item_type = Item.Type.MATERIAL_DART
				if player.inventory.size() < player.MAX_INVENTORY:
					player.inventory.append(dart)
		Player.ClassType.MAGE:
			_equip_start_weapon(Item.Type.WEAPON_STAFF)
			_equip_start_armor(Item.Type.ARMOR_CLOTH)
			for _i in 5:
				var dart := Item.new(); dart.item_type = Item.Type.MATERIAL_DART
				if player.inventory.size() < player.MAX_INVENTORY:
					player.inventory.append(dart)
		Player.ClassType.ROGUE:
			_equip_start_weapon(Item.Type.WEAPON_DAGGER)
			_equip_start_armor(Item.Type.ARMOR_CLOTH)
			for _i in 5:
				var dart := Item.new(); dart.item_type = Item.Type.MATERIAL_DART
				if player.inventory.size() < player.MAX_INVENTORY:
					player.inventory.append(dart)
		Player.ClassType.HUNTER:
			_equip_start_weapon(Item.Type.WEAPON_DAGGER)
			_equip_start_armor(Item.Type.ARMOR_CLOTH)
			for _i in 5:
				var arrow := Item.new(); arrow.item_type = Item.Type.MATERIAL_ARROW_WOOD
				if player.inventory.size() < player.MAX_INVENTORY:
					player.inventory.append(arrow)

func _equip_start_weapon(wtype: int) -> void:
	var w := Item.new()
	w.item_type = wtype
	if Item.EQUIPMENT_DATA.has(wtype):
		w.durability = Item.EQUIPMENT_DATA[wtype][3]
		w.max_durability = w.durability
	player.equip(w)

func _equip_start_armor(atype: int) -> void:
	var a := Item.new()
	a.item_type = atype
	if Item.EQUIPMENT_DATA.has(atype):
		a.durability = Item.EQUIPMENT_DATA[atype][3]
		a.max_durability = a.durability
	player.equip(a)

# ── 마법 시스템 ────────────────────────────────────────────────────────────────

func _on_spell_slot_tapped() -> void:
	if player.learned_spells.is_empty():
		hud.add_log("배운 마법이 없습니다. 고대 주문서를 사용해 마법을 배우세요.")
		return
	var list: Array = []
	for spell_id in player.learned_spells.keys():
		if not Player.SPELL_DATA.has(spell_id):
			continue
		var data: Array = Player.SPELL_DATA[spell_id]
		list.append({"id": spell_id, "name": data[0], "mp_cost": data[1]})
	hud.show_spell_popup(list)

func _on_spell_selected(spell_id: String) -> void:
	if not Player.SPELL_DATA.has(spell_id):
		return
	var data: Array = Player.SPELL_DATA[spell_id]
	var is_targeted: bool = data[2]
	if is_targeted:
		_enter_spell_mode(spell_id)
	else:
		_cast_self_spell(spell_id)

func _enter_spell_mode(spell_id: String) -> void:
	_spell_mode = true
	_spell_id = spell_id
	player.input_blocked = true
	var tiles: Array[Vector2i] = []
	for dy in range(-THROW_RANGE, THROW_RANGE + 1):
		for dx in range(-THROW_RANGE, THROW_RANGE + 1):
			var dist: int = abs(dx) + abs(dy)
			if dist == 0 or dist > THROW_RANGE:
				continue
			var tile: Vector2i = player.tile_pos + Vector2i(dx, dy)
			if map.is_walkable(tile.x, tile.y):
				tiles.append(tile)
	map.throw_highlight_tiles = tiles
	map.queue_redraw()
	hud.set_throw_mode(true)
	hud.add_log("마법 타겟을 선택하세요.")

func _exit_spell_mode() -> void:
	_spell_mode = false
	_spell_id = ""
	player.input_blocked = false
	map.throw_highlight_tiles = []
	map.queue_redraw()
	hud.set_throw_mode(false)

func _execute_spell(target_tile: Vector2i) -> void:
	var dist: int = abs(target_tile.x - player.tile_pos.x) + abs(target_tile.y - player.tile_pos.y)
	if dist == 0 or dist > THROW_RANGE or not map.is_walkable(target_tile.x, target_tile.y):
		_exit_spell_mode()
		hud.add_log("마법 시전 취소")
		return
	var sid: String = _spell_id
	_exit_spell_mode()
	match sid:
		"magic_missile":    _cast_magic_missile(target_tile)
		"nature_lightning": _cast_nature_lightning(target_tile)
	if player.hp <= 0:
		_trigger_game_over()
		return
	enemy_manager.do_turns(player.tile_pos)

func _cast_magic_missile(target_tile: Vector2i) -> void:
	player.spend_mp_for_spell(Player.SPELL_DATA["magic_missile"][1])
	if player.hp <= 0:
		return
	var dmg: int = 5 + player.int_stat
	var target = enemy_manager.get_enemy_at(target_tile)
	if target:
		_spawn_hit(target.position)
		var actual: int = target.take_damage(dmg)
		hud.add_log("매직 미사일! %s에게 %d 피해!" % [target.display_name, actual])
		if target.is_dead():
			var reward: int = 5 * player.floor_num
			hud.add_log("%s 처치! EXP +%d" % [target.display_name, reward])
			enemy_manager.remove_enemy(target)
			player.gain_exp(reward)
	else:
		hud.add_log("매직 미사일이 빗나갔다!")
	_refresh_hud()

func _cast_nature_lightning(target_tile: Vector2i) -> void:
	player.spend_mp_for_spell(Player.SPELL_DATA["nature_lightning"][1])
	if player.hp <= 0:
		return
	var dmg: int = 7 + player.int_stat
	var target = enemy_manager.get_enemy_at(target_tile)
	if target:
		_spawn_hit(target.position)
		var actual: int = target.take_damage(dmg)
		hud.add_log("자연의 번개! %s에게 %d 피해!" % [target.display_name, actual])
		if randi() % 100 < 20:
			target.apply_status("paralyze", 2)
			hud.add_log("번개에 기절! (2턴)")
		if target.is_dead():
			var reward: int = 5 * player.floor_num
			hud.add_log("%s 처치! EXP +%d" % [target.display_name, reward])
			enemy_manager.remove_enemy(target)
			player.gain_exp(reward)
	else:
		hud.add_log("번개가 허공에 떨어졌다!")
	_refresh_hud()

func _cast_self_spell(spell_id: String) -> void:
	match spell_id:
		"regeneration":
			player.spend_mp_for_spell(Player.SPELL_DATA["regeneration"][1])
			player.regen_turns = 5
			hud.add_log("재생 마법! 5턴간 HP가 서서히 회복됩니다.")
		"bark_armor":
			player.spend_mp_for_spell(Player.SPELL_DATA["bark_armor"][1])
			player.bark_shield = player.max_hp / 5
			hud.add_log("나무껍질 갑옷! 방어막 %d 생성!" % player.bark_shield)
		"dispel":
			player.spend_mp_for_spell(Player.SPELL_DATA["dispel"][1])
			player.poison_turns = 0
			player.fire_turns = 0
			player.sleep_turns = 0
			player.paralyze_turns = 0
			player.frozen_turns = 0
			player.slow_turns = 0
			player.wound_turns = 0
			player.blind_turns = 0
			player.curse_atk = 0
			player._recalc_equip_stats()
			hud.add_log("디스펠! 모든 상태이상 & 저주 해제!")
	player.stats_changed.emit()
	_refresh_hud()
	if player.hp <= 0:
		_trigger_game_over()
		return
	enemy_manager.do_turns(player.tile_pos)

func _on_class_skill_tapped() -> void:
	const SKILL_MP_COST := 35
	const SKILL_COOLDOWN := 5
	if player.class_skill_cooldown > 0:
		hud.add_log("직업 스킬 쿨다운 중 (%d턴 남음)" % player.class_skill_cooldown)
		return
	if player.mp < SKILL_MP_COST:
		hud.add_log("MP 부족! (필요 %d, 현재 %d)" % [SKILL_MP_COST, player.mp])
		return
	player.mp -= SKILL_MP_COST
	player.class_skill_cooldown = SKILL_COOLDOWN
	match player.class_type:
		Player.ClassType.WARRIOR:
			_class_skill_warrior()
		Player.ClassType.MAGE:
			_class_skill_mage()
		Player.ClassType.ROGUE:
			_class_skill_rogue()
		Player.ClassType.HUNTER:
			_class_skill_hunter()
	_refresh_hud()
	if player.hp <= 0:
		_trigger_game_over()
		return
	enemy_manager.do_turns(player.tile_pos)

func _class_skill_warrior() -> void:
	var hit_count := 0
	for e in enemy_manager.enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var dx: int = abs(e.tile_pos.x - player.tile_pos.x)
		var dy: int = abs(e.tile_pos.y - player.tile_pos.y)
		if dx <= 1 and dy <= 1:
			for _hit in 2:
				_spawn_hit(e.position)
				var dmg: int = e.take_damage(player.atk)
				if e.is_dead():
					hud.add_log("지면강타! %s 처치!" % e.display_name)
					player.gain_exp(5 * player.floor_num)
					enemy_manager.remove_enemy(e)
					break
			hit_count += 1
	if hit_count == 0:
		hud.add_log("지면강타! (범위 내 적 없음)")
	else:
		hud.add_log("지면강타! 주변 %d마리에게 2연타!" % hit_count)

func _class_skill_mage() -> void:
	var hit_count := 0
	for e in enemy_manager.enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var dx: int = abs(e.tile_pos.x - player.tile_pos.x)
		var dy: int = abs(e.tile_pos.y - player.tile_pos.y)
		if dx <= 2 and dy <= 2:
			_spawn_hit(e.position)
			var dmg: int = e.take_damage(player.atk)
			e.apply_status("frozen", FROZEN_TURNS + 1)
			if e.is_dead():
				hud.add_log("얼음회오리! %s 처치!" % e.display_name)
				player.gain_exp(5 * player.floor_num)
				enemy_manager.remove_enemy(e)
			hit_count += 1
	if hit_count == 0:
		hud.add_log("얼음회오리! (범위 내 적 없음)")
	else:
		hud.add_log("얼음회오리! 범위 내 %d마리 피해 + 빙결!" % hit_count)

func _class_skill_rogue() -> void:
	const BLIND_TURNS_SKILL := 4
	const FLASH_DMG := 5
	var hit_count := 0
	for e in enemy_manager.enemies.duplicate():
		if not is_instance_valid(e):
			continue
		_spawn_hit(e.position)
		e.take_damage(FLASH_DMG)
		e.apply_status("blind", BLIND_TURNS_SKILL)
		if e.is_dead():
			player.gain_exp(5 * player.floor_num)
			enemy_manager.remove_enemy(e)
		hit_count += 1
	if hit_count == 0:
		hud.add_log("섬광탄! (층 내 적 없음)")
	else:
		hud.add_log("섬광탄! 층 내 모든 적 피해 + 실명 %d턴!" % BLIND_TURNS_SKILL)

func _class_skill_hunter() -> void:
	var nearest: Enemy = null
	var nearest_dist: int = 999
	for e in enemy_manager.enemies:
		if not is_instance_valid(e):
			continue
		var d: int = abs(e.tile_pos.x - player.tile_pos.x) + abs(e.tile_pos.y - player.tile_pos.y)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	if nearest == null:
		hud.add_log("난사! (층 내 적 없음)")
		return
	var target_name: String = nearest.display_name
	var hit_count: int = randi() % 4 + 3  # 3~6
	var total_dmg: int = 0
	for _i in hit_count:
		if not is_instance_valid(nearest):
			break
		_spawn_hit(nearest.position)
		var dmg: int = nearest.take_damage(player.atk)
		total_dmg += dmg
		if nearest.is_dead():
			player.gain_exp(5 * player.floor_num)
			enemy_manager.remove_enemy(nearest)
			break
	hud.add_log("난사! %s에게 %d연타, 총 %d 피해!" % [target_name, hit_count, total_dmg])

func _on_home_requested() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://home/home.tscn")
