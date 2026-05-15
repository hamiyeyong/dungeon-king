extends Node2D

const WIDTH := 20
const HEIGHT := 30
const TILE_SIZE := 32
const ATLAS_TILE := 64  # 타일셋 원본 타일 크기

enum Cell { WALL, FLOOR, STAIRS, CHEST, CAMPFIRE, TRAP }

# 타일셋 atlas 좌표 (col, row) — tiles-64.png 기준
const TILE_WALL_VARIANTS := [
	Vector2i(4, 11),
	Vector2i(5, 11),
	Vector2i(6, 11),
	Vector2i(7, 11),
]
const TILE_FLOOR    := Vector2i(1, 11)
const TILE_STAIRS   := Vector2i(0, 7)
const TILE_CHEST    := Vector2i(2, 8)
const TILE_CAMPFIRE := Vector2i(0, 4)
const TILE_TRAP     := Vector2i(0, 9)

const TILESET = preload("res://assets/sprites/doodle-rogue/tiles-64.png")

var grid: Array = []
var rooms: Array = []

func generate() -> void:
	_init_grid()
	_place_rooms()
	_connect_rooms()
	_place_objects()
	queue_redraw()

func _init_grid() -> void:
	grid.clear()
	rooms.clear()
	for _y in HEIGHT:
		var row := []
		row.resize(WIDTH)
		row.fill(Cell.WALL)
		grid.append(row)

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
			if (r as Rect2i).grow(1).intersects(room):
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
		var a: Vector2i = (rooms[i - 1] as Rect2i).get_center()
		var b: Vector2i = (rooms[i] as Rect2i).get_center()
		var x := a.x
		while x != b.x:
			grid[a.y][x] = Cell.FLOOR
			x += sign(b.x - x)
		var y := a.y
		while y != b.y:
			grid[y][b.x] = Cell.FLOOR
			y += sign(b.y - y)

func _place_objects() -> void:
	if rooms.size() < 2:
		return
	var last: Vector2i = (rooms.back() as Rect2i).get_center()
	grid[last.y][last.x] = Cell.STAIRS
	for i in range(1, rooms.size() - 1):
		var c: Vector2i = (rooms[i] as Rect2i).get_center()
		match randi() % 3:
			0: grid[c.y][c.x] = Cell.CHEST
			1: grid[c.y][c.x] = Cell.CAMPFIRE
			2: grid[c.y][c.x] = Cell.TRAP

func _draw() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			var cell: int = grid[y][x]
			var dest := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if cell == Cell.WALL:
				_blit(dest, TILE_WALL_VARIANTS[(x * 7 + y * 13) % TILE_WALL_VARIANTS.size()])
			else:
				_blit(dest, TILE_FLOOR)
				if cell != Cell.FLOOR:
					_blit(dest, _cell_atlas(cell))

func _blit(dest: Rect2, atlas: Vector2i) -> void:
	var src := Rect2(atlas.x * ATLAS_TILE, atlas.y * ATLAS_TILE, ATLAS_TILE, ATLAS_TILE)
	draw_texture_rect_region(TILESET, dest, src)

func _cell_atlas(cell: int) -> Vector2i:
	match cell:
		Cell.STAIRS:   return TILE_STAIRS
		Cell.CHEST:    return TILE_CHEST
		Cell.CAMPFIRE: return TILE_CAMPFIRE
		Cell.TRAP:     return TILE_TRAP
	return TILE_FLOOR

func get_start_pos() -> Vector2i:
	if rooms.is_empty():
		return Vector2i(1, 1)
	return (rooms[0] as Rect2i).get_center()

func is_walkable(x: int, y: int) -> bool:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return false
	return grid[y][x] != Cell.WALL

func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x * TILE_SIZE + TILE_SIZE * 0.5, tile_pos.y * TILE_SIZE + TILE_SIZE * 0.5)
