extends Node2D
class_name Enemy

const TILE_SIZE := 32
const ATLAS_TILE := 64
const TILESET = preload("res://assets/sprites/doodle-rogue/tiles-64.png")

var display_name := "슬라임"
var atlas_pos := Vector2i(0, 1)
var src_tex: Texture2D = null   # nil이면 TILESET+atlas_pos 사용
var src_rect: Rect2 = Rect2()
var tile_pos: Vector2i
var map_ref = null
var hp := 6
var max_hp := 6
var atk := 3
var def_ := 0
var poison_turns: int = 0
var fire_turns: int = 0
var sleep_turns: int = 0
var is_boss: bool = false
var is_alerted: bool = false
var _hp_bar_timer: float = 0.0

func init(pos: Vector2i, map: Node) -> void:
	tile_pos = pos
	map_ref = map
	position = map.tile_to_world(tile_pos)

func _process(delta: float) -> void:
	if _hp_bar_timer > 0.0:
		_hp_bar_timer -= delta
		if _hp_bar_timer <= 0.0:
			_hp_bar_timer = 0.0
		queue_redraw()

func _draw() -> void:
	var dest := Rect2(-TILE_SIZE * 0.5, -TILE_SIZE * 0.5, TILE_SIZE, TILE_SIZE)
	var mod := Color(0.55, 0.55, 0.85, 0.9) if sleep_turns > 0 else Color.WHITE
	if src_tex != null:
		draw_texture_rect_region(src_tex, dest, src_rect, mod)
	else:
		var src := Rect2(atlas_pos.x * ATLAS_TILE, atlas_pos.y * ATLAS_TILE, ATLAS_TILE, ATLAS_TILE)
		draw_texture_rect_region(TILESET, dest, src, mod)
	if _hp_bar_timer > 0.0 or is_boss:
		var bw := 30.0 if is_boss else 26.0
		var bh := 5.0 if is_boss else 4.0
		var bx := -bw * 0.5; var by := -TILE_SIZE * 0.5 - 7.0
		draw_rect(Rect2(bx, by, bw, bh), Color(0.1, 0.1, 0.1, 0.85))
		var ratio: float = float(max(0, hp)) / float(max_hp)
		var fill: Color = Color(0.2, 0.8, 0.2) if ratio > 0.5 else \
			(Color(0.9, 0.75, 0.1) if ratio > 0.25 else Color(0.85, 0.15, 0.15))
		draw_rect(Rect2(bx, by, bw * ratio, bh), fill)
		var border: Color = Color(0.9, 0.75, 0.1, 0.9) if is_boss else Color(0.55, 0.55, 0.55, 0.5)
		draw_rect(Rect2(bx, by, bw, bh), border, false, 1.0 if not is_boss else 1.5)

func apply_status(type: String, turns: int) -> void:
	if type == "poison":
		poison_turns = max(poison_turns, turns) as int
	elif type == "fire":
		fire_turns = max(fire_turns, turns) as int
	elif type == "sleep":
		sleep_turns = max(sleep_turns, turns) as int

func cleanse() -> void:
	poison_turns = 0
	fire_turns = 0
	sleep_turns = 0

func tick_status() -> Dictionary:
	var total_dmg: int = 0
	var sources: Array[String] = []
	if poison_turns > 0:
		poison_turns -= 1
		var d: int = Item.POISON_DMG_PER_TURN
		hp = max(0, hp - d)
		total_dmg += d
		sources.append("독")
	if fire_turns > 0:
		fire_turns -= 1
		var d: int = Item.FIRE_DMG_PER_TURN
		hp = max(0, hp - d)
		total_dmg += d
		sources.append("화염")
	return {"damage": total_dmg, "sources": sources, "dead": is_dead()}

func take_damage(amount: int) -> int:
	var dmg: int = max(1, amount - def_)
	hp -= dmg
	sleep_turns = 0
	_hp_bar_timer = 2.0
	queue_redraw()
	return dmg

func is_dead() -> bool:
	return hp <= 0

func ai_step(player_pos: Vector2i, occupied: Array) -> bool:
	if sleep_turns > 0:
		sleep_turns -= 1
		return false
	var dx := tile_pos.x - player_pos.x
	var dy := tile_pos.y - player_pos.y
	var dist: int = abs(dx) + abs(dy)
	if dist == 1:
		return true
	if dist <= 8 or is_alerted:
		_move_toward(player_pos, occupied)
	return false

func _move_toward(target: Vector2i, occupied: Array) -> void:
	var dx: int = sign(target.x - tile_pos.x)
	var dy: int = sign(target.y - tile_pos.y)
	var steps := []
	if dx != 0:
		steps.append(Vector2i(tile_pos.x + dx, tile_pos.y))
	if dy != 0:
		steps.append(Vector2i(tile_pos.x, tile_pos.y + dy))
	for step in steps:
		if map_ref.is_walkable(step.x, step.y) and not (step in occupied):
			occupied.erase(tile_pos)
			tile_pos = step
			occupied.append(tile_pos)
			position = map_ref.tile_to_world(tile_pos)
			return
