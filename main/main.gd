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

	map.generate()
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

	# 탐험경험치 마일스톤 보너스 적용
	_run_explore_xp = 0
	player.max_hp += SaveData.get_bonus_max_hp()
	player.hp = player.max_hp
	player.max_mp += SaveData.get_bonus_max_mp()
	player.mp = player.max_mp
	player.atk += SaveData.get_bonus_atk()

	if SaveData.has_identify_potion():
		var rand_idx: int = randi() % 6
		_identified[rand_idx] = true

	if SaveData.has_start_potion_heal():
		var color_idx: int = _potion_map.find(Item.Type.POTION_HEAL)
		var start_potion := Item.new()
		start_potion.item_type = Item.Type.POTION_HEAL
		start_potion.color_idx = color_idx
		player.inventory.append(start_potion)

	enemy_manager.spawn(map.rooms, map, player.floor_num)
	camera.position = player.position
	_update_fov()
	_refresh_hud()

func _process(_delta: float) -> void:
	camera.position = camera.position.lerp(player.position, 0.15)

# ── 던지기 타겟팅 입력 ──────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _throw_mode:
		return
	var world_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		world_pos = get_viewport().get_canvas_transform().affine_inverse() * event.position
	elif event is InputEventScreenTouch and event.pressed:
		world_pos = get_viewport().get_canvas_transform().affine_inverse() * event.position
	else:
		return
	var tile := Vector2i(int(world_pos.x / 32), int(world_pos.y / 32))
	_execute_throw(tile)
	get_viewport().set_input_as_handled()

# ── Turn flow ──────────────────────────────────────────────────────────────

func _update_fov() -> void:
	# 횃불 보유 시 시야 반경 크게 확장
	var has_torch := false
	for inv_item in player.inventory:
		if inv_item.item_type == Item.Type.MATERIAL_TORCH:
			has_torch = true
			break
	var radius: int = 10 if has_torch else 4

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
		player.inventory.append(item)
		hud.add_log("%s 획득!" % item.get_display_name(true))

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
	hud.update_inventory(player.inventory, _identified)
	hud.update_equipped(player.equipped_weapon, player.equipped_shield, player.equipped_armor)

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
	if new_floor > MAX_FLOOR:
		SaveData.add_explore_xp(_run_explore_xp)
		_run_explore_xp = 0
		_trigger_game_clear()
		return

	player.floor_num = new_floor
	floor_items.clear()
	map.generate()
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
		# 주문서
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

func _on_enemy_trap(tile_pos: Vector2i, enemy) -> void:
	map.set_cell(tile_pos.x, tile_pos.y, map.Cell.FLOOR)
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
	map.set_cell(pos.x, pos.y, map.Cell.FLOOR)
	_spawn_hit(player.position)
	match randi() % 3:
		0:  # 독가시 함정
			player.take_damage(5, "독가시 함정")
			player.apply_status("poison", Item.POISON_TURNS)
			_spawn_poison(player.position)
			hud.add_log("독가시 함정! HP -5 + 독 상태이상")
		1:  # 화염 함정
			player.take_damage(8, "화염 함정")
			player.apply_status("fire", Item.FIRE_TURNS)
			_spawn_fire(player.position)
			hud.add_log("화염 함정! HP -8 + 화상 상태이상")
		2:  # 텔레포트 함정
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

func _on_home_requested() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://home/home.tscn")
