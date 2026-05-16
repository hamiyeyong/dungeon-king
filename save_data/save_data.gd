extends Node

const SAVE_PATH := "user://save_data.cfg"

var explore_xp: int = 0

const MILESTONE_THRESHOLDS: Array[int]  = [200, 500, 1000, 2000, 3500, 5000]
const MILESTONE_LABELS: Array[String]   = [
	"최대 HP +2",
	"최대 MP +5",
	"물약 1개 감정된 상태로 시작",
	"최대 HP +3 추가 (누적 +5)",
	"치유 물약 1개 지참 시작",
	"공격력 +1",
]

func _ready() -> void:
	_load()

func add_explore_xp(amount: int) -> void:
	explore_xp += amount
	_save()

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
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	explore_xp = cfg.get_value("progress", "explore_xp", 0)
