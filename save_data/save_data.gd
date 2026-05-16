extends Node

const SAVE_PATH := "user://save_data.cfg"

var explore_xp: int = 0
var best_floor: int = 0
var selected_class: int = 0  # 0=전사 1=마법사 2=도적 3=사냥꾼

const MILESTONE_THRESHOLDS: Array[int]  = [200, 500, 1000, 2000, 3500, 5000]
const MILESTONE_LABELS: Array[String]   = [
	"최대 HP +2",
	"최대 MP +5",
	"물약 1개 감정된 상태로 시작",
	"최대 HP +3 추가 (누적 +5)",
	"치유 물약 1개 지참 시작",
	"공격력 +1",
]

# 직업 해금 조건
const CLASS_UNLOCK_FLOOR: Array[int] = [0, 5, 10, 15]  # 전사/마법사/도적/사냥꾼
const CLASS_NAMES: Array[String] = ["전사", "마법사", "도적", "사냥꾼"]

func _ready() -> void:
	_load()

func add_explore_xp(amount: int) -> void:
	explore_xp += amount
	_save()

func update_best_floor(floor_num: int) -> void:
	if floor_num > best_floor:
		best_floor = floor_num
		_save()

func set_selected_class(class_id: int) -> void:
	selected_class = class_id
	_save()

func is_class_unlocked(class_id: int) -> bool:
	if class_id < 0 or class_id >= CLASS_UNLOCK_FLOOR.size():
		return false
	return best_floor >= CLASS_UNLOCK_FLOOR[class_id]

func is_milestone_unlocked(idx: int) -> bool:
	return explore_xp >= MILESTONE_THRESHOLDS[idx]

func get_bonus_max_hp() -> int:
	var bonus: int = 0
	if is_milestone_unlocked(0): bonus += 2
	if is_milestone_unlocked(3): bonus += 3
	return bonus

func get_bonus_max_mp() -> int:
	return 5 if is_milestone_unlocked(1) else 0

func get_bonus_atk() -> int:
	return 1 if is_milestone_unlocked(5) else 0

func has_identify_potion() -> bool:
	return is_milestone_unlocked(2)

func has_start_potion_heal() -> bool:
	return is_milestone_unlocked(4)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "explore_xp", explore_xp)
	cfg.set_value("progress", "best_floor", best_floor)
	cfg.set_value("progress", "selected_class", selected_class)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	explore_xp = cfg.get_value("progress", "explore_xp", 0)
	best_floor = cfg.get_value("progress", "best_floor", 0)
	selected_class = cfg.get_value("progress", "selected_class", 0)
