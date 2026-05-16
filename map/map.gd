extends Node2D
class_name GameMap

const WIDTH := 20
const HEIGHT := 30
const TILE_SIZE := 32
const ATLAS_TILE := 64  # 타일셋 원본 타일 크기

enum Cell {
	WALL, FLOOR, STAIRS, CHEST, CHEST_OPEN,
	CAMPFIRE, CAMPFIRE_OUT, TRAP, GRASS, JAR, JAR_OPEN,
	DOOR, DOOR_OPEN,
	WHITE_CAULDRON, BLACK_CAULDRON, MAGIC_WELL,
	MERCHANT,
}

# 타일셋 atlas 좌표 (col, row) — tiles-64.png 기준
const TILE_DOOR          := Vector2i(3, 4)
const TILE_DOOR_OPEN     := Vector2i(4, 4)
const TILE_CAULDRON_W    := Vector2i(5, 4)
const TILE_CAULDRON_B    := Vector2i(6, 4)
const TILE_WELL          := Vector2i(7, 4)
const TILE_MERCHANT      := Vector2i(0, 5)

const TILE_WALL_VARIANTS := [
	Vector2i(1, 11),
]
const TILE_FLOOR_VARIANTS := [
	Vector2i(4, 11),
	Vector2i(4, 11),
	Vector2i(4, 11),
	Vector2i(5, 11),
	Vector2i(6, 11),
	Vector2i(7, 11),
]
const TILE_FLOOR      := Vector2i(4, 11)
const TILE_CHEST      := Vector2i(2, 9)
const TILE_CHEST_OPEN := Vector2i(2, 8)
const TILE_CAMPFIRE   := Vector2i(0, 4)
const TILE_TRAP       := Vector2i(0, 9)

const TILESET   = preload("res://assets/sprites/doodle-rogue/tiles-64.png")
const BUSH_TEX  = preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Bush1_0.png")
const JAR_CLOSED: Array = [
	preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Pot1_0.png"),
	preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Pot2_0.png"),
	preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Pot3_0.png"),
]
const JAR_SHARDS: Array = [
	[
		preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Debris/Pot1_Shard_0.png"),
		preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Debris/Pot1_Shard_1.png"),
		preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Debris/Pot1_Shard_2.png"),
	],
	[
		preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Debris/Pot2_Shard_0.png"),
		preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Debris/Pot2_Shard_1.png"),
		preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Debris/Pot2_Shard_2.png"),
	],
	[
		preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Debris/Pot3_Shard_0.png"),
		preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Debris/Pot3_Shard_1.png"),
		preload("res://assets/sprites/doodle-rpg/ALL SPRITES/Debris/Pot3_Shard_2.png"),
	],
]

# 시야 그라디언트 설정
const CAMPFIRE_LIGHT_RADIUS := 12
const CAMPFIRE_INNER        := 4.0
const CAMPFIRE_OUTER        := 12.0
const MAX_FOG_ALPHA         := 0.78

var grid: Array[Array] = []
var rooms: Array[Rect2i] = []
var tile_variant_grid: Array[Array] = []
var throw_highlight_tiles: Array[Vector2i] = []
var fov_visible: Array = []   # Array[Array[bool]] — 현재 시야 내 타일
var fov_explored: Array = []  # Array[Array[bool]] — 탐색된 타일
var floor_item_visuals: Array[Dictionary] = []

var _fov_player_pos: Vector2i = Vector2i.ZERO
var _fov_radius: int = 0
var _fov_light_sources: Array[Vector2i] = []

func generate(floor_num: int = 1) -> void:
	_init_grid()
	_place_rooms()
	_connect_rooms()
	_place_objects(floor_num)
	queue_redraw()

func update_floor_items(visuals: Array[Dictionary]) -> void:
	floor_item_visuals = visuals
	queue_redraw()

func _init_grid() -> void:
	grid.clear()
	rooms.clear()
	tile_variant_grid.clear()
	fov_visible.clear()
	fov_explored.clear()
	floor_item_visuals.clear()
	for _y in HEIGHT:
		var row := []
		row.resize(WIDTH)
		row.fill(Cell.WALL)
		grid.append(row)
		var vrow := []
		vrow.resize(WIDTH)
		for x in WIDTH:
			vrow[x] = randi()
		tile_variant_grid.append(vrow)
		var vis_row := []
		vis_row.resize(WIDTH)
		vis_row.fill(false)
		fov_visible.append(vis_row.duplicate())
		fov_explored.append(vis_row.duplicate())

func _place_rooms() -> void:
	var target := randi_range(5, 8)
	var attempts := 0
	while rooms.size() < target and attempts < 200:
		var w := randi_range(4, 7)
		var h := randi_range(4, 7)
		var x := randi_range(1, WIDTH - w - 1)
		var y := randi_range(1, HEIGHT - h - 1)
		var room := Rect2i(x, y, w, h)
		var overlaps := false
		for r in rooms:
			if r.grow(1).intersects(room):
				overlaps = true
				break
		if not overlaps:
			for ry in range(room.position.y, room.end.y):
				for rx in range(room.position.x, room.end.x):
					grid[ry][rx] = Cell.FLOOR
			rooms.append(room)
		attempts += 1

func _connect_rooms() -> void:
	for i in range(1, rooms.size()):
		var a: Vector2i = rooms[i - 1].get_center()
		var b: Vector2i = rooms[i].get_center()
		var x := a.x
		while x != b.x:
			grid[a.y][x] = Cell.FLOOR
			x += sign(b.x - x)
		var y := a.y
		while y != b.y:
			grid[y][b.x] = Cell.FLOOR
			y += sign(b.y - y)

func _is_merchant_floor(floor_num: int) -> bool:
	return floor_num % 5 == 3  # 3, 8, 13, 18, 23층

func _place_objects(floor_num: int = 1) -> void:
	if rooms.size() < 2:
		return
	var last: Vector2i = rooms.back().get_center()
	grid[last.y][last.x] = Cell.STAIRS

	# 중간 방들에 오브젝트 배치 (첫 방 제외)
	var cauldron_placed := false
	var well_placed := false
	for i in range(1, rooms.size() - 1):
		var c: Vector2i = rooms[i].get_center()
		if not cauldron_placed and i == 1:
			# 첫 번째 중간 방: 연금술 솥
			grid[c.y][c.x] = Cell.WHITE_CAULDRON if randi() % 2 == 0 else Cell.BLACK_CAULDRON
			cauldron_placed = true
		elif not well_placed and randi() % 4 == 0:
			# 25% 확률로 이상한 우물
			grid[c.y][c.x] = Cell.MAGIC_WELL
			well_placed = true
		else:
			match randi() % 3:
				0: grid[c.y][c.x] = Cell.CHEST
				1: grid[c.y][c.x] = Cell.CAMPFIRE
				2: grid[c.y][c.x] = Cell.TRAP

	# 상인: 상인층이면 중간 방 중 하나에 배치
	if _is_merchant_floor(floor_num) and rooms.size() > 2:
		var mid_idx: int = rooms.size() / 2
		var mc: Vector2i = rooms[mid_idx].get_center()
		grid[mc.y][mc.x] = Cell.MERCHANT

	# 문: 방과 방 사이 복도 입구 (각 방 가장자리)에 배치
	_place_doors()

	# 수풀: 바닥 타일의 약 2.5% 배치
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if grid[y][x] == Cell.FLOOR and randi() % 40 == 0:
				grid[y][x] = Cell.GRASS
	# 항아리: 바닥 타일의 약 2% 배치
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if grid[y][x] == Cell.FLOOR and randi() % 50 == 0:
				grid[y][x] = Cell.JAR

func _place_doors() -> void:
	# 각 방의 경계 바닥 타일 중 일부에 문 배치
	for i in range(1, rooms.size()):
		if randi() % 2 == 0:
			continue   # 50% 확률로만 문 생성
		var room: Rect2i = rooms[i]
		# 방 경계의 바닥 타일 수집
		var border_tiles: Array[Vector2i] = []
		for x in range(room.position.x, room.end.x):
			for edge_y in [room.position.y, room.end.y - 1]:
				var v := Vector2i(x, edge_y)
				if grid[v.y][v.x] == Cell.FLOOR:
					border_tiles.append(v)
		for y in range(room.position.y, room.end.y):
			for edge_x in [room.position.x, room.end.x - 1]:
				var v := Vector2i(edge_x, y)
				if grid[v.y][v.x] == Cell.FLOOR:
					border_tiles.append(v)
		if border_tiles.is_empty():
			continue
		border_tiles.shuffle()
		# 방마다 문 1개 배치
		grid[border_tiles[0].y][border_tiles[0].x] = Cell.DOOR

func _draw() -> void:
	var has_fov := not fov_visible.is_empty()
	for y in HEIGHT:
		for x in WIDTH:
			var cell: int = grid[y][x]
			var dest := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var vis: bool = has_fov and fov_visible[y][x]
			var exp: bool = has_fov and fov_explored[y][x]
			if not exp and has_fov:
				draw_rect(dest, Color(0, 0, 0, 1.0))
				continue
			if cell == Cell.WALL:
				_blit(dest, TILE_WALL_VARIANTS[tile_variant_grid[y][x] % TILE_WALL_VARIANTS.size()])
			else:
				_blit(dest, TILE_FLOOR_VARIANTS[tile_variant_grid[y][x] % TILE_FLOOR_VARIANTS.size()])
				if cell != Cell.FLOOR:
					if cell == Cell.STAIRS:
						_draw_stairs(dest)
					elif cell == Cell.GRASS:
						draw_texture_rect(BUSH_TEX, dest, false)
					elif cell == Cell.JAR:
						var pot_idx: int = tile_variant_grid[y][x] % 3
						draw_texture_rect(JAR_CLOSED[pot_idx], dest, false)
					elif cell == Cell.JAR_OPEN:
						var pot_idx: int = tile_variant_grid[y][x] % 3
						var shard_idx: int = (tile_variant_grid[y][x] / 3) % 3
						draw_texture_rect(JAR_SHARDS[pot_idx][shard_idx], dest, false)
					elif cell == Cell.CAMPFIRE_OUT:
						var src := Rect2(TILE_CAMPFIRE.x * ATLAS_TILE, TILE_CAMPFIRE.y * ATLAS_TILE, ATLAS_TILE, ATLAS_TILE)
						draw_texture_rect_region(TILESET, dest, src, Color(0.3, 0.3, 0.4, 1.0))
					elif cell == Cell.DOOR:
						_blit_tinted(dest, TILE_DOOR, Color(0.7, 0.5, 0.3))
					elif cell == Cell.DOOR_OPEN:
						_blit_tinted(dest, TILE_DOOR_OPEN, Color(0.8, 0.7, 0.5))
					elif cell == Cell.WHITE_CAULDRON:
						_blit_tinted(dest, TILE_CAULDRON_W, Color(0.9, 0.95, 1.0))
					elif cell == Cell.BLACK_CAULDRON:
						_blit_tinted(dest, TILE_CAULDRON_B, Color(0.4, 0.3, 0.5))
					elif cell == Cell.MAGIC_WELL:
						_blit_tinted(dest, TILE_WELL, Color(0.5, 0.8, 1.0))
					elif cell == Cell.MERCHANT:
						_draw_merchant_marker(dest)
					else:
						_blit(dest, _cell_atlas(cell))
			if has_fov:
				if not vis:
					draw_rect(dest, Color(0, 0, 0, 0.6))
				else:
					var fog_alpha: float = _fog_alpha_at(x, y)
					if fog_alpha > 0.01:
						draw_rect(dest, Color(0, 0, 0, fog_alpha))
	# 바닥 아이템
	var font := ThemeDB.fallback_font
	for fiv in floor_item_visuals:
		var fpos: Vector2i = fiv.pos
		if fpos.x < 0 or fpos.x >= WIDTH or fpos.y < 0 or fpos.y >= HEIGHT:
			continue
		if has_fov and not fov_visible[fpos.y][fpos.x]:
			continue
		var cx: float = fpos.x * TILE_SIZE + TILE_SIZE * 0.5
		var cy: float = fpos.y * TILE_SIZE + TILE_SIZE * 0.5
		draw_circle(Vector2(cx, cy), 8.5, Color(0, 0, 0, 0.55))
		var sz := 13.0
		var idest := Rect2(cx - sz * 0.5, cy - sz * 0.5, sz, sz)
		var iatlas: Vector2i = fiv.atlas
		draw_texture_rect_region(TILESET, idest,
			Rect2(iatlas.x * ATLAS_TILE, iatlas.y * ATLAS_TILE, ATLAS_TILE, ATLAS_TILE), fiv.mod)
		if fiv.count > 1:
			draw_string(font, Vector2(cx + 4, cy + 10), "×%d" % fiv.count,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1.0, 1.0, 0.6))

	for tile in throw_highlight_tiles:
		var dest := Rect2(tile.x * TILE_SIZE, tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(dest, Color(1.0, 0.6, 0.0, 0.32))
		draw_rect(dest, Color(1.0, 0.85, 0.1, 0.75), false, 2.0)

func _draw_stairs(dest: Rect2) -> void:
	var cx: float = dest.position.x + dest.size.x * 0.5
	var top: float = dest.position.y + dest.size.y * 0.18
	var bot: float = dest.position.y + dest.size.y * 0.82
	var left: float = dest.position.x + dest.size.x * 0.18
	var right: float = dest.position.x + dest.size.x * 0.82
	var pts := PackedVector2Array([Vector2(cx, top), Vector2(right, bot), Vector2(left, bot)])
	draw_colored_polygon(pts, Color(0.95, 0.85, 0.15))
	draw_polyline(
		PackedVector2Array([Vector2(cx, top), Vector2(right, bot), Vector2(left, bot), Vector2(cx, top)]),
		Color(1.0, 1.0, 1.0, 0.75), 1.5)

func _blit(dest: Rect2, atlas: Vector2i) -> void:
	var src := Rect2(atlas.x * ATLAS_TILE, atlas.y * ATLAS_TILE, ATLAS_TILE, ATLAS_TILE)
	draw_texture_rect_region(TILESET, dest, src)

func _blit_tinted(dest: Rect2, atlas: Vector2i, tint: Color) -> void:
	var src := Rect2(atlas.x * ATLAS_TILE, atlas.y * ATLAS_TILE, ATLAS_TILE, ATLAS_TILE)
	draw_texture_rect_region(TILESET, dest, src, tint)

func _draw_merchant_marker(dest: Rect2) -> void:
	var cx: float = dest.position.x + dest.size.x * 0.5
	var cy: float = dest.position.y + dest.size.y * 0.5
	draw_circle(Vector2(cx, cy), 10.0, Color(0.9, 0.75, 0.2, 0.85))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(dest.position.x, cy + 5),
		"$", HORIZONTAL_ALIGNMENT_CENTER, dest.size.x, 13, Color(0.1, 0.1, 0.1))

func _cell_atlas(cell: int) -> Vector2i:
	match cell:
		Cell.CHEST:          return TILE_CHEST
		Cell.CHEST_OPEN:     return TILE_CHEST_OPEN
		Cell.CAMPFIRE:       return TILE_CAMPFIRE
		Cell.CAMPFIRE_OUT:   return TILE_CAMPFIRE
		Cell.TRAP:           return TILE_TRAP
		Cell.DOOR:           return TILE_DOOR
		Cell.DOOR_OPEN:      return TILE_DOOR_OPEN
		Cell.WHITE_CAULDRON: return TILE_CAULDRON_W
		Cell.BLACK_CAULDRON: return TILE_CAULDRON_B
		Cell.MAGIC_WELL:     return TILE_WELL
		Cell.MERCHANT:       return TILE_MERCHANT
	return TILE_FLOOR

func update_fov(player_pos: Vector2i, radius: int, light_sources: Array[Vector2i] = []) -> void:
	_fov_player_pos = player_pos
	_fov_radius = radius
	_fov_light_sources = light_sources
	for y in HEIGHT:
		for x in WIDTH:
			fov_visible[y][x] = false
	# 플레이어 시야
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var tx: int = player_pos.x + dx
			var ty: int = player_pos.y + dy
			if tx < 0 or tx >= WIDTH or ty < 0 or ty >= HEIGHT:
				continue
			if _has_los(player_pos, Vector2i(tx, ty)):
				fov_visible[ty][tx] = true
				fov_explored[ty][tx] = true
	# 광원(모닥불) 시야 — 큰 반경으로 주변을 밝힘
	for src in light_sources:
		for dy in range(-CAMPFIRE_LIGHT_RADIUS, CAMPFIRE_LIGHT_RADIUS + 1):
			for dx in range(-CAMPFIRE_LIGHT_RADIUS, CAMPFIRE_LIGHT_RADIUS + 1):
				if dx * dx + dy * dy > CAMPFIRE_LIGHT_RADIUS * CAMPFIRE_LIGHT_RADIUS:
					continue
				var tx: int = src.x + dx
				var ty: int = src.y + dy
				if tx < 0 or tx >= WIDTH or ty < 0 or ty >= HEIGHT:
					continue
				if _has_los(src, Vector2i(tx, ty)):
					fov_visible[ty][tx] = true
					fov_explored[ty][tx] = true
	queue_redraw()

func _fog_alpha_at(x: int, y: int) -> float:
	var tc := Vector2(x + 0.5, y + 0.5)
	# 플레이어 거리 기반 알파
	var pc := Vector2(_fov_player_pos) + Vector2(0.5, 0.5)
	var dist_p: float = tc.distance_to(pc)
	var inner_p: float = float(_fov_radius) * 0.4
	var outer_p: float = float(_fov_radius)
	var t_p: float = clampf((dist_p - inner_p) / maxf(outer_p - inner_p, 0.01), 0.0, 1.0)
	var fog_alpha: float = t_p * t_p * MAX_FOG_ALPHA
	# 광원(모닥불) 거리 기반 알파 — 더 낮으면 더 밝게
	for src in _fov_light_sources:
		var sc: Vector2 = Vector2(src) + Vector2(0.5, 0.5)
		var dist_s: float = tc.distance_to(sc)
		var t_s: float = clampf((dist_s - CAMPFIRE_INNER) / (CAMPFIRE_OUTER - CAMPFIRE_INNER), 0.0, 1.0)
		var a: float = t_s * t_s * MAX_FOG_ALPHA
		if a < fog_alpha:
			fog_alpha = a
	return fog_alpha

func _has_los(from: Vector2i, to: Vector2i) -> bool:
	var dx := to.x - from.x
	var dy := to.y - from.y
	var steps: int = max(abs(dx), abs(dy))
	if steps == 0:
		return true
	for i in range(1, steps):
		var sx: int = int(round(from.x + dx * float(i) / steps))
		var sy: int = int(round(from.y + dy * float(i) / steps))
		if sx >= 0 and sx < WIDTH and sy >= 0 and sy < HEIGHT:
			if grid[sy][sx] == Cell.WALL:
				return false
	return true

func is_tile_visible(x: int, y: int) -> bool:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return false
	if fov_visible.is_empty():
		return true
	return fov_visible[y][x]

func get_start_pos() -> Vector2i:
	if rooms.is_empty():
		return Vector2i(1, 1)
	return rooms[0].get_center()

func is_walkable(x: int, y: int) -> bool:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return false
	var cell: int = grid[y][x]
	return cell not in [
		Cell.WALL, Cell.CAMPFIRE, Cell.CAMPFIRE_OUT,
		Cell.GRASS, Cell.JAR, Cell.DOOR,
		Cell.WHITE_CAULDRON, Cell.BLACK_CAULDRON, Cell.MAGIC_WELL, Cell.MERCHANT,
	]

func is_door(x: int, y: int) -> bool:
	return get_cell(x, y) == Cell.DOOR

func is_cauldron(x: int, y: int) -> bool:
	var c: int = get_cell(x, y)
	return c == Cell.WHITE_CAULDRON or c == Cell.BLACK_CAULDRON

func is_well(x: int, y: int) -> bool:
	return get_cell(x, y) == Cell.MAGIC_WELL

func is_merchant(x: int, y: int) -> bool:
	return get_cell(x, y) == Cell.MERCHANT

func is_grass(x: int, y: int) -> bool:
	return get_cell(x, y) == Cell.GRASS

func is_jar(x: int, y: int) -> bool:
	return get_cell(x, y) == Cell.JAR

func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x * TILE_SIZE + TILE_SIZE * 0.5, tile_pos.y * TILE_SIZE + TILE_SIZE * 0.5)

func get_cell(x: int, y: int) -> int:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return Cell.WALL
	return grid[y][x]

func set_cell(x: int, y: int, cell: int) -> void:
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
		grid[y][x] = cell
		queue_redraw()
