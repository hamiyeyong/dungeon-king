extends Node2D
class_name EnemyManager

signal player_attacked(atk_value: int, attacker_name: String)
signal all_cleared(pos: Vector2)
signal trap_triggered_by_enemy(tile_pos: Vector2i, enemy_node)

var enemies: Array[Enemy] = []
const ENEMY_SCENE = preload("res://enemy/enemy.tscn")
const EXTRAS_TEX = preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Extras.png")
const SLIME_RECT := Rect2(310, 282, 80, 70)

var _map_ref = null

# 몬스터 타입 정의: [이름, atlas_pos, hp_base, hp_per_floor, atk, def_]
const ENEMY_TYPES := {
	"slime":    ["슬라임",       Vector2i(0, 1), 8,   4,  3, 0],
	"goblin":   ["고블린",       Vector2i(1, 1), 14,  6,  5, 1],
	"skeleton": ["스켈레톤",     Vector2i(2, 1), 18,  7,  7, 2],
	"ghost":    ["유령",         Vector2i(3, 1), 12,  5,  6, 1],
	"slime_king":   ["슬라임 킹",   Vector2i(0, 2), 60, 10, 8,  1],
	"goblin_chief": ["고블린 족장", Vector2i(1, 2), 50,  8, 12, 2],
	"lich":         ["스켈레톤 마법사", Vector2i(2, 2), 55, 9, 10, 3],
	"vampire":      ["뱀파이어 군주", Vector2i(3, 2), 70, 12, 14, 4],
	"dark_dragon":  ["어둠의 드래곤", Vector2i(0, 3), 100, 15, 18, 6],
}

# 보스층마다 등장하는 보스 타입
const BOSS_BY_FLOOR := {
	5:  "slime_king",
	10: "goblin_chief",
	15: "lich",
	20: "vampire",
	25: "dark_dragon",
}

signal boss_dropped_key(pos: Vector2)


# 층별 스폰 테이블: [타입, 비율(weight)]
const FLOOR_TABLES := {
	1: [["slime", 1]],
	2: [["slime", 3], ["goblin", 1]],
	3: [["slime", 2], ["goblin", 2], ["skeleton", 1]],
	4: [["goblin", 2], ["skeleton", 2], ["ghost", 1]],
	5: [["skeleton", 2], ["ghost", 2], ["goblin", 1]],
}

func _pick_type(floor_num: int) -> String:
	var table: Array = FLOOR_TABLES.get(floor_num, FLOOR_TABLES[5])
	var total: int = 0
	for entry in table:
		total += entry[1]
	var roll: int = randi() % total
	var acc: int = 0
	for entry in table:
		acc += entry[1]
		if roll < acc:
			return entry[0]
	return table[0][0]

func _setup_enemy(e: Node, type_key: String, floor_num: int) -> void:
	var t: Array = ENEMY_TYPES[type_key]
	e.display_name = t[0]
	e.atlas_pos = t[1]
	e.hp = (t[2] as int) + (t[3] as int) * floor_num
	e.max_hp = e.hp
	e.atk = t[4] as int
	e.def_ = t[5] as int
	if type_key == "slime":
		e.src_tex = EXTRAS_TEX
		e.src_rect = SLIME_RECT

func is_boss_floor(floor_num: int) -> bool:
	return BOSS_BY_FLOOR.has(floor_num)

func spawn(rooms: Array[Rect2i], map: Node, floor_num: int) -> void:
	_map_ref = map
	for e in enemies:
		e.queue_free()
	enemies.clear()

	var tiles := _collect_floor_tiles(rooms, map)
	tiles.shuffle()

	if is_boss_floor(floor_num):
		# 보스 1마리만 배치 (마지막 방 중앙)
		if not tiles.is_empty():
			var e: Enemy = ENEMY_SCENE.instantiate() as Enemy
			add_child(e)
			_setup_enemy(e, BOSS_BY_FLOOR[floor_num], floor_num)
			e.is_boss = true
			e.init(tiles[0], map)
			enemies.append(e)
		return

	var count := 3 + floor_num * 2
	var guaranteed: String = ""
	if floor_num >= 2:
		var rank := {"goblin": 1, "skeleton": 2, "ghost": 3}
		for btype in rank:
			if floor_num >= rank[btype] + 1:
				guaranteed = btype

	for i in min(count, tiles.size()):
		var e: Enemy = ENEMY_SCENE.instantiate() as Enemy
		add_child(e)
		var type_key: String = guaranteed if (i == 0 and guaranteed != "") else _pick_type(floor_num)
		_setup_enemy(e, type_key, floor_num)
		e.init(tiles[i], map)
		enemies.append(e)

func _collect_floor_tiles(rooms: Array[Rect2i], map: Node) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in range(1, rooms.size()):
		var room: Rect2i = rooms[i]
		for ry in range(room.position.y, room.end.y):
			for rx in range(room.position.x, room.end.x):
				if map.is_walkable(rx, ry):
					result.append(Vector2i(rx, ry))
	return result

func spawn_one_near(tile_pos: Vector2i, map: Node, floor_num: int) -> void:
	var candidates: Array[Vector2i] = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var tx: int = tile_pos.x + dx
			var ty: int = tile_pos.y + dy
			if map.is_walkable(tx, ty) and get_enemy_at(Vector2i(tx, ty)) == null:
				candidates.append(Vector2i(tx, ty))
	if candidates.is_empty():
		return
	candidates.shuffle()
	var e: Enemy = ENEMY_SCENE.instantiate() as Enemy
	add_child(e)
	_setup_enemy(e, _pick_type(floor_num), floor_num)
	e.init(candidates[0], map)
	enemies.append(e)

func get_enemy_at(pos: Vector2i):
	for e in enemies:
		if e.tile_pos == pos:
			return e
	return null

func remove_enemy(e) -> void:
	var last_pos: Vector2 = e.position
	var was_boss: bool = e.get("is_boss") == true
	enemies.erase(e)
	e.queue_free()
	if was_boss:
		boss_dropped_key.emit(last_pos)
	if enemies.is_empty():
		all_cleared.emit(last_pos)

func tick_statuses() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var r: Dictionary = e.tick_status()
		if r.damage > 0:
			r["pos"] = e.position
			r["enemy"] = e
			results.append(r)
	return results

func do_turns(player_pos: Vector2i) -> void:
	var occupied := []
	for e in enemies:
		occupied.append(e.tile_pos)

	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var attacked: bool = e.ai_step(player_pos, occupied)
		if attacked:
			player_attacked.emit(e.atk, e.display_name)
		elif is_instance_valid(e) and _map_ref:
			if _map_ref.get_cell(e.tile_pos.x, e.tile_pos.y) == _map_ref.Cell.TRAP:
				trap_triggered_by_enemy.emit(e.tile_pos, e)
