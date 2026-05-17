extends Node2D
class_name Player

signal stats_changed
signal log_message(msg: String)
signal turn_done
signal hit_at(world_pos: Vector2)
signal attacked_cell(tile_pos: Vector2i)
signal campfire_approached(tile_pos: Vector2i)
signal campfire_out_approached(tile_pos: Vector2i)
signal merchant_approached(tile_pos: Vector2i)
signal door_approached(tile_pos: Vector2i)
signal cauldron_approached(tile_pos: Vector2i)
signal well_approached(tile_pos: Vector2i)
signal skull_approached(tile_pos: Vector2i)
signal tablet_approached(tile_pos: Vector2i)
signal statue_approached(tile_pos: Vector2i, statue_type: String)
signal bookshelf_approached(tile_pos: Vector2i)

const TILE_SIZE := 32
const KNIGHT_PATH  = "res://assets/sprites/doodle-rpg/ALL SPRITES/Knight/Walking/"
const SWORD_PATH   = "res://assets/sprites/doodle-rpg/ALL SPRITES/Knight/Sword Swing/"
const HURT_PATH    = "res://assets/sprites/doodle-rpg/ALL SPRITES/Knight/"
const PUSH_PATH    = "res://assets/sprites/doodle-rpg/ALL SPRITES/Knight/Pushing/"
const KNIGHT_SCALE = 0.22

var tile_pos := Vector2i.ZERO
var map_ref = null
var sprite: AnimatedSprite2D

# 직업 시스템
enum ClassType { WARRIOR = 0, MAGE = 1, ROGUE = 2, HUNTER = 3 }
var class_type: int = ClassType.WARRIOR

const SPELL_DATA: Dictionary = {
	"magic_missile":    ["매직 미사일", 8, true],
	"nature_lightning": ["자연의 번개", 10, true],
	"regeneration":     ["재생", 6, false],
	"bark_armor":       ["나무껍질 갑옷", 8, false],
	"dispel":           ["디스펠", 4, false],
}

# 기본 스탯 (힘/민첩/체력/지능/운)
var str_stat: int = 10
var agi_stat: int = 10
var vit_stat: int = 10
var int_stat: int = 10
var luk_stat: int = 10

var hp := 20
var max_hp := 20
var mp := 30
var max_mp := 30
var hunger := 0
var fatigue := 0
var floor_num := 1
var atk := 5
var def_ := 1
var curse_atk: int = 0
var exp := 0
var level := 1
var gold: int = 0
var next_atk_multiplier: int = 1   # 강타 주문서 효과 (사용 후 다음 공격 배수)

var inventory: Array[Item] = []
const MAX_INVENTORY := 10

var equipped_weapon: Item = null
var equipped_shield: Item = null
var equipped_armor: Item  = null

var poison_turns: int = 0
var fire_turns: int = 0
var sleep_turns: int = 0
var paralyze_turns: int = 0
var frozen_turns: int = 0
var slow_turns: int = 0
var wound_turns: int = 0
var blind_turns: int = 0
var invincible_turns: int = 0
var class_skill_cooldown: int = 0
var _slow_skip: bool = false
var _save_atk_bonus: int = 0  # SaveData 마일스톤 ATK 보너스 (recalc 시 반영)
var crit_rune_pct: int = 0    # 장착 룬으로 추가된 크리티컬 확률 %
var learned_spells: Dictionary = {}
var regen_turns: int = 0
var bark_shield: int = 0

var input_blocked := false
var hud_ref: Node = null
var enemy_manager_ref = null

var _last_walk_anim := "down"
var _acting := false        # 공격 애니 재생 중 — 입력 차단
var _pending_turn_done := false  # 공격 애니 종료 후 turn_done 발행 예약

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.scale = Vector2(KNIGHT_SCALE, KNIGHT_SCALE)
	add_child(sprite)

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_anim(frames, "down",         KNIGHT_PATH, ["Forward0", "Forward1", "Forward2"])
	_add_anim(frames, "up",           KNIGHT_PATH, ["Up0",      "Up1",      "Up2"])
	_add_anim(frames, "left",         KNIGHT_PATH, ["Left0",    "Left1",    "Left2"])
	_add_anim(frames, "right",        KNIGHT_PATH, ["Right0",   "Right1",   "Right2"])
	_add_anim(frames, "hurt",         HURT_PATH,   ["hurt1", "hurt2", "hurt3", "hurt4"], 10.0, false)
	_add_anim(frames, "attack_down",  SWORD_PATH,  ["Forward0", "Forward1", "Forward2"], 12.0, false)
	_add_anim(frames, "attack_up",    SWORD_PATH,  ["Up0",      "Up1",      "Up2"],      12.0, false)
	_add_anim(frames, "attack_left",  SWORD_PATH,  ["Left0",    "Left1",    "Left2"],    12.0, false)
	_add_anim(frames, "attack_right", SWORD_PATH,  ["Right0",   "Right1",   "Right2"],   12.0, false)
	_add_anim(frames, "push_down",   PUSH_PATH,   ["Forward0", "Forward1", "Forward2"], 10.0, false)
	_add_anim(frames, "push_up",     PUSH_PATH,   ["Up0",      "Up1",      "Up2"],      10.0, false)
	_add_anim(frames, "push_left",   PUSH_PATH,   ["Left0",    "Left1",    "Left2"],    10.0, false)
	_add_anim(frames, "push_right",  PUSH_PATH,   ["Right0",   "Right1",   "Right2"],  10.0, false)
	sprite.sprite_frames = frames
	sprite.play("down")

func _add_anim(frames: SpriteFrames, anim: String, path: String, files: Array, speed: float = 8.0, loop: bool = true) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, speed)
	frames.set_animation_loop(anim, loop)
	for f in files:
		frames.add_frame(anim, load(path + f + ".png"))

func init(start_tile: Vector2i, map: Node) -> void:
	tile_pos = start_tile
	map_ref = map
	position = map.tile_to_world(tile_pos)
	poison_turns = 0
	fire_turns = 0
	sleep_turns = 0
	paralyze_turns = 0
	frozen_turns = 0
	slow_turns = 0
	wound_turns = 0
	blind_turns = 0
	invincible_turns = 0
	class_skill_cooldown = 0
	_slow_skip = false
	curse_atk = 0
	hunger = 0
	fatigue = 0
	exp = 0
	level = 1
	floor_num = 1
	gold = 0
	next_atk_multiplier = 1
	crit_rune_pct = 0
	learned_spells.clear()
	regen_turns = 0
	bark_shield = 0
	# 직업별 스탯 초기화
	class_type = SaveData.selected_class
	var cs: Array[int] = _class_stats(class_type)
	str_stat = cs[0]; agi_stat = cs[1]; vit_stat = cs[2]; int_stat = cs[3]; luk_stat = cs[4]
	max_hp = 5 + vit_stat * 2
	max_mp = 5 + int_stat * 2
	hp = max_hp
	mp = max_mp
	inventory.clear()
	equipped_weapon = null
	equipped_shield = null
	equipped_armor = null
	_recalc_equip_stats()

func apply_rune_effects() -> void:
	crit_rune_pct = 0
	for rune_id in SaveData.get_equipped_runes():
		match rune_id:
			"질긴_생명력":
				max_hp = int(max_hp * 1.18)
				hp = max_hp
			"전투_감각":
				crit_rune_pct += 10

func learn_spell(spell_id: String) -> String:
	if not SPELL_DATA.has(spell_id):
		return "알 수 없는 마법입니다."
	if learned_spells.has(spell_id):
		return "%s 마법은 이미 알고 있습니다." % SPELL_DATA[spell_id][0]
	learned_spells[spell_id] = 1
	return "%s 마법을 배웠습니다!" % SPELL_DATA[spell_id][0]

func spend_mp_for_spell(cost: int) -> void:
	if mp >= cost:
		mp -= cost
	else:
		var hp_cost: int = cost - mp
		mp = 0
		hp = max(0, hp - hp_cost)
		log_message.emit("MP 부족! HP %d 소모." % hp_cost)
	stats_changed.emit()

static func _class_stats(ct: int) -> Array[int]:
	match ct:
		0: return [11, 10, 12,  8, 10]  # 전사: STR/AGI/VIT/INT/LUK
		1: return [10, 10,  9, 12, 10]  # 마법사
		2: return [10, 11, 10,  9, 11]  # 도적
		3: return [10, 12,  9, 10, 10]  # 사냥꾼
	return  [10, 10, 10, 10, 10]

func apply_status(type: String, turns: int) -> void:
	if type == "poison":
		poison_turns = max(poison_turns, turns) as int
	elif type == "fire":
		fire_turns = max(fire_turns, turns) as int
	elif type == "sleep":
		sleep_turns = max(sleep_turns, turns) as int
	elif type == "paralyze":
		paralyze_turns = max(paralyze_turns, turns) as int
	elif type == "frozen":
		frozen_turns = max(frozen_turns, turns) as int
	elif type == "slow":
		slow_turns = max(slow_turns, turns) as int
	elif type == "wound":
		wound_turns = max(wound_turns, turns) as int
	elif type == "blind":
		blind_turns = max(blind_turns, turns) as int

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked or _acting:
		return
	if hud_ref and hud_ref.is_any_popup_open():
		return
	if _slow_skip:
		if (event is InputEventKey and event.pressed) or \
		   (event is InputEventMouseButton and event.pressed) or \
		   (event is InputEventScreenTouch and event.pressed):
			_slow_skip = false
			slow_turns = max(0, slow_turns - 1)
			do_wait()
			get_viewport().set_input_as_handled()
		return
	if paralyze_turns > 0:
		if (event is InputEventKey and event.pressed) or \
		   (event is InputEventMouseButton and event.pressed) or \
		   (event is InputEventScreenTouch and event.pressed):
			do_wait()
			get_viewport().set_input_as_handled()
		return
	if sleep_turns > 0:
		if (event is InputEventKey and event.pressed) or \
		   (event is InputEventMouseButton and event.pressed) or \
		   (event is InputEventScreenTouch and event.pressed):
			do_wait()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		var dir := Vector2i.ZERO
		match event.keycode:
			KEY_W, KEY_UP:    dir = Vector2i(0, -1)
			KEY_S, KEY_DOWN:  dir = Vector2i(0, 1)
			KEY_A, KEY_LEFT:  dir = Vector2i(-1, 0)
			KEY_D, KEY_RIGHT: dir = Vector2i(1, 0)
			KEY_SPACE:
				do_wait()
				return
		if dir != Vector2i.ZERO:
			_try_move(dir)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		_handle_tap(world_pos)
	elif event is InputEventScreenTouch and event.pressed:
		var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		_handle_tap(world_pos)

func _handle_tap(world_pos: Vector2) -> void:
	var tap_tile := Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))
	var dx: int = tap_tile.x - tile_pos.x
	var dy: int = tap_tile.y - tile_pos.y
	if dx == 0 and dy == 0:
		do_wait()
	elif dx != 0 and dy != 0:
		if abs(dx) >= abs(dy):
			_try_move(Vector2i(sign(dx), 0))
			if not _acting:
				_try_move(Vector2i(0, sign(dy)))
		else:
			_try_move(Vector2i(0, sign(dy)))
			if not _acting:
				_try_move(Vector2i(sign(dx), 0))
	else:
		_try_move(Vector2i(sign(dx), sign(dy)))

func do_wait() -> void:
	_on_step(false)
	turn_done.emit()

func _try_move(dir: Vector2i) -> void:
	if _acting:
		return
	var next := tile_pos + dir
	if enemy_manager_ref:
		var enemy = enemy_manager_ref.get_enemy_at(next)
		if enemy:
			_update_face_dir(dir)
			_attack_enemy(enemy)
			# turn_done은 공격 애니 종료 후 _on_action_anim_done에서 발행
			return
	if frozen_turns > 0:
		_update_face_dir(dir)
		log_message.emit("빙결! 이동할 수 없습니다.")
		do_wait()
		return
	if map_ref and map_ref.get_cell(next.x, next.y) == map_ref.Cell.DOOR:
		_update_face_dir(dir)
		door_approached.emit(next)
		return
	if map_ref and map_ref.get_cell(next.x, next.y) == map_ref.Cell.MERCHANT:
		_update_face_dir(dir)
		merchant_approached.emit(next)
		return
	if map_ref and (map_ref.get_cell(next.x, next.y) == map_ref.Cell.WHITE_CAULDRON or
			map_ref.get_cell(next.x, next.y) == map_ref.Cell.BLACK_CAULDRON):
		_update_face_dir(dir)
		cauldron_approached.emit(next)
		return
	if map_ref and map_ref.get_cell(next.x, next.y) == map_ref.Cell.MAGIC_WELL:
		_update_face_dir(dir)
		well_approached.emit(next)
		return
	if map_ref and map_ref.get_cell(next.x, next.y) == map_ref.Cell.CAMPFIRE:
		_update_face_dir(dir)
		campfire_approached.emit(next)
		return
	if map_ref and map_ref.get_cell(next.x, next.y) == map_ref.Cell.CAMPFIRE_OUT:
		_update_face_dir(dir)
		campfire_out_approached.emit(next)
		return
	if map_ref and map_ref.get_cell(next.x, next.y) == map_ref.Cell.SKULL_PILE:
		_update_face_dir(dir)
		skull_approached.emit(next)
		return
	if map_ref and map_ref.get_cell(next.x, next.y) == map_ref.Cell.KNOWLEDGE_TABLET:
		_update_face_dir(dir)
		tablet_approached.emit(next)
		return
	if map_ref:
		var nc: int = map_ref.get_cell(next.x, next.y)
		if nc in [map_ref.Cell.WIZARD_STATUE, map_ref.Cell.WARRIOR_STATUE, map_ref.Cell.ANGEL_STATUE]:
			_update_face_dir(dir)
			var stype := "warrior" if nc == map_ref.Cell.WARRIOR_STATUE else ("angel" if nc == map_ref.Cell.ANGEL_STATUE else "wizard")
			statue_approached.emit(next, stype)
			return
	if map_ref and map_ref.get_cell(next.x, next.y) == map_ref.Cell.BOOKSHELF:
		_update_face_dir(dir)
		bookshelf_approached.emit(next)
		return
	if map_ref and map_ref.is_grass(next.x, next.y):
		_update_face_dir(dir)
		_attack_grass(next)
		return
	if map_ref and map_ref.is_jar(next.x, next.y):
		_update_face_dir(dir)
		_attack_grass(next)
		return
	if map_ref and map_ref.is_walkable(next.x, next.y):
		tile_pos = next
		position = map_ref.tile_to_world(tile_pos)
		_update_anim(dir)
		_on_step()
		turn_done.emit()

func _attack_grass(pos: Vector2i) -> void:
	_acting = true
	_pending_turn_done = true
	_play_action_anim("attack_" + _last_walk_anim)
	hit_at.emit(map_ref.tile_to_world(pos))
	fatigue = min(600, fatigue + 3)
	attacked_cell.emit(pos)

func _attack_enemy(enemy) -> void:
	_acting = true
	_pending_turn_done = true
	_play_action_anim("attack_" + _last_walk_anim)
	hit_at.emit(enemy.position)
	_on_weapon_used()
	fatigue = min(600, fatigue + 3)
	if fatigue >= 600:
		max_hp = max(5, max_hp - 1)
		hp = min(hp, max_hp)
		log_message.emit("탈진 상태! 최대 체력이 줄어들고 있습니다!")
	var effective_atk: int = atk * next_atk_multiplier
	if next_atk_multiplier > 1:
		log_message.emit("강타! %d배 데미지!" % next_atk_multiplier)
		next_atk_multiplier = 1
	var dmg: int = enemy.take_damage(effective_atk)
	log_message.emit("%s에게 %d 피해!" % [enemy.display_name, dmg])
	if enemy.is_dead():
		var reward: int = 5 * floor_num
		log_message.emit("%s 처치! EXP +%d" % [enemy.display_name, reward])
		enemy_manager_ref.remove_enemy(enemy)
		gain_exp(reward)

func equip(item) -> void:
	if item.is_weapon():
		if equipped_weapon:
			inventory.append(equipped_weapon)
		equipped_weapon = item
	elif item.is_shield():
		if equipped_shield:
			inventory.append(equipped_shield)
		equipped_shield = item
	elif item.is_armor():
		if equipped_armor:
			inventory.append(equipped_armor)
		equipped_armor = item
	_recalc_equip_stats()
	stats_changed.emit()

func unequip(slot: String) -> String:
	var item = null
	match slot:
		"weapon": item = equipped_weapon
		"shield": item = equipped_shield
		"armor":  item = equipped_armor
	if item == null:
		return ""
	if inventory.size() >= MAX_INVENTORY:
		return "인벤토리가 가득 찼습니다."
	match slot:
		"weapon": equipped_weapon = null
		"shield": equipped_shield = null
		"armor":  equipped_armor  = null
	inventory.append(item)
	_recalc_equip_stats()
	stats_changed.emit()
	return "%s 해제" % item.get_display_name(true)

func unequip_weapon() -> void:
	if equipped_weapon and inventory.size() < MAX_INVENTORY:
		inventory.append(equipped_weapon)
		equipped_weapon = null
		_recalc_equip_stats()
		stats_changed.emit()

func _recalc_equip_stats() -> void:
	var base_atk: int = 5 + (level - 1) + max(0, str_stat - 10) + _save_atk_bonus
	var base_def: int = 1
	atk = base_atk + (equipped_weapon.get_equip_atk() if equipped_weapon else 0) - curse_atk
	# 전사 패시브: 근거리 무기 데미지 +15%
	if class_type == ClassType.WARRIOR and equipped_weapon:
		atk = int(atk * 1.15)
	def_ = base_def + \
		(equipped_shield.get_equip_def() if equipped_shield else 0) + \
		(equipped_armor.get_equip_def()  if equipped_armor  else 0)

func _on_weapon_used() -> void:
	if equipped_weapon:
		equipped_weapon.durability = max(0, equipped_weapon.durability - 1)
		_recalc_equip_stats()

func _on_armor_hit() -> void:
	if equipped_shield:
		equipped_shield.durability = max(0, equipped_shield.durability - 1)
	if equipped_armor:
		equipped_armor.durability = max(0, equipped_armor.durability - 1)
	_recalc_equip_stats()

func gain_exp(amount: int) -> void:
	exp += amount
	var needed: int = level * 10
	if exp >= needed:
		exp -= needed
		_level_up()

func _level_up() -> void:
	level += 1
	max_hp += 5
	hp = max_hp
	_recalc_equip_stats()
	log_message.emit("레벨이 올랐습니다! (Lv.%d)" % level)
	stats_changed.emit()

func _try_dodge() -> bool:
	var pct: int
	if class_type == ClassType.ROGUE:
		# 도적 패시브: 경갑 착용 시 민첩 수치 = 회피 보너스 %
		var light_armor := equipped_armor != null and equipped_armor.item_type == Item.Type.ARMOR_CLOTH
		pct = agi_stat if light_armor else max(0, agi_stat - 10)
	else:
		pct = max(0, agi_stat - 10)
	return randi() % 100 < pct

func take_damage(amount: int, attacker: String = "적") -> void:
	if invincible_turns > 0:
		log_message.emit("%s의 공격! (무적 상태)" % attacker)
		return
	if _try_dodge():
		log_message.emit("%s의 공격을 회피했습니다!" % attacker)
		return
	var dmg: int = max(1, amount - def_)
	if bark_shield > 0:
		var absorbed: int = min(bark_shield, dmg)
		bark_shield -= absorbed
		dmg -= absorbed
		if absorbed > 0:
			log_message.emit("방어막 %d 흡수! (남은 방어막: %d)" % [absorbed, bark_shield])
		if dmg <= 0:
			_on_armor_hit()
			stats_changed.emit()
			return
	hp = max(0, hp - dmg)
	log_message.emit("%s에게 %d 피해를 입었습니다." % [attacker, dmg])
	if sleep_turns > 0:
		sleep_turns = 0
		log_message.emit("충격에 잠에서 깼습니다!")
	_on_armor_hit()
	_play_action_anim("hurt")
	if hp <= 0:
		log_message.emit("당신은 죽었습니다...")
	stats_changed.emit()

func _play_action_anim(anim: String) -> void:
	if sprite.animation_finished.is_connected(_on_action_anim_done):
		sprite.animation_finished.disconnect(_on_action_anim_done)
	sprite.animation_finished.connect(_on_action_anim_done)
	sprite.play(anim)

func _on_action_anim_done() -> void:
	sprite.animation_finished.disconnect(_on_action_anim_done)
	sprite.play(_last_walk_anim)
	_acting = false
	if _pending_turn_done:
		_pending_turn_done = false
		turn_done.emit()

func _update_face_dir(dir: Vector2i) -> void:
	match dir:
		Vector2i(0,  1): _last_walk_anim = "down"
		Vector2i(0, -1): _last_walk_anim = "up"
		Vector2i(-1, 0): _last_walk_anim = "left"
		Vector2i(1,  0): _last_walk_anim = "right"

func _update_anim(dir: Vector2i) -> void:
	_update_face_dir(dir)
	sprite.play(_last_walk_anim)

func _on_step(consume_hunger: bool = true) -> void:
	if consume_hunger:
		hunger = min(600, hunger + 1)
		if hunger >= 600:
			hp = max(0, hp - 1)
			log_message.emit("굶주림! 체력이 줄어들고 있습니다!")
		elif hunger >= 450:
			pass  # 배고픔 상태 — HP 자연 회복 중단 (현재 자연 회복 없음)
	else:
		# 대기(wait) 턴 — 피로도 소량 회복
		fatigue = max(0, fatigue - 3)
		if fatigue < 450 and mp < max_mp:
			mp = min(max_mp, mp + 2)

	# MP 자연 회복 (피로도 정상일 때, 이동 턴에도 적용)
	if consume_hunger and fatigue < 450 and mp < max_mp:
		mp = min(max_mp, mp + 1)
	if regen_turns > 0:
		regen_turns -= 1
		var regen_hp: int = max(1, max_hp / 10)
		hp = min(max_hp, hp + regen_hp)
		var regen_suffix := " (%d턴 남음)" % regen_turns if regen_turns > 0 else " (해제)"
		log_message.emit("재생! HP +%d%s" % [regen_hp, regen_suffix])
	if sleep_turns > 0:
		sleep_turns -= 1
		var suffix := " (%d턴 남음)" % sleep_turns if sleep_turns > 0 else " (해제)"
		log_message.emit("수면! 행동 불가%s" % suffix)
	if paralyze_turns > 0:
		paralyze_turns -= 1
		var suffix := " (%d턴 남음)" % paralyze_turns if paralyze_turns > 0 else " (해제)"
		log_message.emit("마비! 행동 불가%s" % suffix)
	if frozen_turns > 0:
		frozen_turns -= 1
		var suffix := " (%d턴 남음)" % frozen_turns if frozen_turns > 0 else " (해제, 느려짐 부여)"
		log_message.emit("빙결! 이동 불가%s" % suffix)
		if frozen_turns == 0:
			slow_turns = max(slow_turns, 1)
	if slow_turns > 0 and consume_hunger:
		_slow_skip = true
		log_message.emit("느려짐 (%d턴 남음)" % slow_turns)
	if wound_turns > 0:
		wound_turns -= 1
		hp = max(0, hp - 1)
		var suffix := " (%d턴 남음)" % wound_turns if wound_turns > 0 else " (해제)"
		log_message.emit("부상! HP -1%s" % suffix)
	if invincible_turns > 0:
		invincible_turns -= 1
		var suffix := " (%d턴 남음)" % invincible_turns if invincible_turns > 0 else " (해제)"
		log_message.emit("무적%s" % suffix)
	if blind_turns > 0:
		blind_turns -= 1
		var suffix := " (%d턴 남음)" % blind_turns if blind_turns > 0 else " (해제)"
		log_message.emit("실명%s" % suffix)
	if class_skill_cooldown > 0:
		class_skill_cooldown -= 1
	if poison_turns > 0:
		poison_turns -= 1
		hp = max(0, hp - Item.POISON_DMG_PER_TURN)
		var suffix := " (%d턴 남음)" % poison_turns if poison_turns > 0 else " (해제)"
		log_message.emit("독! HP -%d%s" % [Item.POISON_DMG_PER_TURN, suffix])
	if fire_turns > 0:
		fire_turns -= 1
		hp = max(0, hp - Item.FIRE_DMG_PER_TURN)
		var suffix := " (%d턴 남음)" % fire_turns if fire_turns > 0 else " (해제)"
		log_message.emit("화상! HP -%d%s" % [Item.FIRE_DMG_PER_TURN, suffix])
	stats_changed.emit()
