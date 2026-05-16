extends Node

const SAVE_PATH := "user://save_data.cfg"

var explore_xp: int = 0
var best_floor: int = 0
var selected_class: int = 0  # 0=전사 1=마법사 2=도적 3=사냥꾼

# 룬 경제
var rune_coins: int = 0
var rune_fragments: Dictionary = {}   # {rune_id: count}
var rune_equipped: Array = []         # [rune_id, ...] 최대 5슬롯, "" = 빈 슬롯
var pending_chest: Dictionary = {}    # {} = 없음, {"grade":int,"frags":{...},"coins":int}

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

# ── 룬 시스템 상수 ────────────────────────────────────────────────────────────

const RUNE_GRADE_NORMAL  := 0
const RUNE_GRADE_RARE    := 1
const RUNE_GRADE_EPIC    := 2
const RUNE_GRADE_LEGEND  := 3

const RUNE_GRADE_NAMES: Array[String] = ["일반", "희귀", "에픽", "레전드"]
const RUNE_GRADE_COLORS: Array = [
	Color("#aaaaaa"), Color("#4499ff"), Color("#cc44ff"), Color("#ffcc00")
]

# {id: [표시명, grade_int, 효과_설명]}
const RUNE_DEFS: Dictionary = {
	# 공용
	"질긴_생명력":   ["질긴 생명력",   2, "최대 HP +18%"],
	"잡학다식":      ["잡학다식",      2, "아이템 획득 시 9% 자동 식별"],
	"머리_강타":     ["머리 강타",     3, "공격 시 14% 확률 마비"],
	"전투_감각":     ["전투 감각",     1, "크리티컬 확률 +10%"],
	"미식가":        ["미식가",        1, "음식 포만감 +15%, 피로도 -4.5%"],
	"무기_방어술":   ["무기 방어술",   1, "쳐내기 확률 +15%"],
	"방패_숙련":     ["방패 숙련",     0, "방패 방어율 +12%"],
	"경갑_숙련":     ["경갑 숙련",     0, "경갑 방어력 +12%"],
	"수리의_대가":   ["수리의 대가",   0, "수리 효과 +12%"],
	# 전사
	"무기_숙련":     ["무기 숙련",     0, "근거리 데미지 +15%"],
	"광란의_전투":   ["광란의 전투",   1, "적 처치 후 다음 공격 +30%"],
	"강한_완력":     ["강한 완력",     0, "양손·격투 데미지 +12%"],
	"중갑_숙련":     ["중갑 숙련",     0, "중갑 방어력 +12%"],
	"강한_소화력":   ["강한 소화력",   1, "음식 섭취 시 HP 13.2% 회복"],
	"불굴의_의지":   ["불굴의 의지",   2, "피격 시 방어력 +56% (30AP)"],
	"몰아치기":      ["몰아치기",      2, "공격마다 더블어택 확률 +6% 누적"],
	"복수":          ["복수",          3, "피격 시 21% 확률 크리티컬 +50%"],
	"필살의_공격":   ["필살의 공격",   3, "36% 확률 스킬 쿨타임 감소"],
	# 마법사
	"마법_친화":     ["마법 친화",     0, "경갑 착용 시 MP 자연회복 증가"],
	"마법_극대화":   ["마법 극대화",   1, "마법 크리티컬 데미지 +45%"],
	"연금술의_대가": ["연금술의 대가", 1, "물약 제작 시 15% 추가 생성"],
	"정신력_흡수":   ["정신력 흡수",   0, "근접 공격 시 12% MP 회복"],
	"연쇄_마법":     ["연쇄 마법",     2, "마법 사용 시 20% 즉시 시전"],
	"전투_마법":     ["전투 마법",     2, "마법 후 크리티컬 확률 +18%"],
	"마력의_폭풍":   ["마력의 폭풍",   3, "마법 후 다음 마법 +21%"],
	"마음의_양식":   ["마음의 양식",   3, "음식 섭취 시 MP 회복"],
	# 도적
	"기민한_몸놀림": ["기민한 몸놀림", 0, "경갑 착용 시 회피 보너스"],
	"급소_공략":     ["급소 공략",     1, "물리 크리티컬 데미지 +60%"],
	"살인적인_기습": ["살인적인 기습", 1, "기습 데미지 +45%"],
	"검_단검_숙련":  ["검·단검 숙련",  0, "단검·검 데미지 +12%"],
	"검술의_달인":   ["검술의 달인",   2, "더블어택 +10%, 회피율 +4%"],
	"치명적인_반격": ["치명적인 반격", 2, "회피 성공 시 18% 기습 공격"],
	"전술적인_전투": ["전술적인_전투", 3, "쳐내기 후 더블어택·크리티컬 +21%"],
	"맹독_공격":     ["맹독 공격",     3, "공격 시 18% 중독 (기습 36%)"],
	# 사냥꾼
	"사냥꾼의_본능": ["사냥꾼의 본능", 0, "원거리 명중·데미지 보너스"],
	"올가미_사격":   ["올가미 사격",   1, "원거리 12% 이동 불가 (20AP)"],
	"신비의_씨앗":   ["신비의 씨앗",   1, "씨앗 복용 시 HP 20% 방어막"],
	"매복":          ["매복",          1, "수풀 입장 시 원거리 +60%"],
	"야생의_생존력": ["야생의 생존력", 0, "씨앗 회복 효과 +24%"],
	"저격":          ["저격",          2, "원거리 기습 데미지 +36% + 마비"],
	"연계_공격":     ["연계 공격",     2, "원거리 후 더블어택·회피율 +9%"],
	"속사":          ["속사",          3, "원거리 15% 확률 2~3연속 발사"],
	"정신의_화살":   ["정신의 화살",   3, "원거리 기습 시 MP +3% 회복"],
}

# 등급별 드롭 풀
const RUNE_DROP_POOL: Dictionary = {
	0: ["방패_숙련", "경갑_숙련", "수리의_대가", "무기_숙련", "강한_완력",
		"중갑_숙련", "마법_친화", "정신력_흡수", "기민한_몸놀림", "검_단검_숙련",
		"사냥꾼의_본능", "야생의_생존력"],
	1: ["전투_감각", "미식가", "무기_방어술", "광란의_전투", "강한_소화력",
		"마법_극대화", "연금술의_대가", "급소_공략", "살인적인_기습",
		"올가미_사격", "신비의_씨앗", "매복"],
	2: ["질긴_생명력", "잡학다식", "불굴의_의지", "몰아치기",
		"연쇄_마법", "전투_마법", "검술의_달인", "치명적인_반격",
		"저격", "연계_공격"],
	3: ["머리_강타", "복수", "필살의_공격", "마력의_폭풍", "마음의_양식",
		"전술적인_전투", "맹독_공격", "속사", "정신의_화살"],
}

# [min_frags, max_frags, min_coins, max_coins, num_rune_types]
const CHEST_REWARDS: Dictionary = {
	0: [1, 3, 10, 20, 2],
	1: [2, 4, 30, 50, 2],
	2: [3, 6, 60, 100, 3],
	3: [8, 15, 150, 250, 4],
}

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

# ── 룬 시스템 ─────────────────────────────────────────────────────────────────

func get_rune_slot_count() -> int:
	if best_floor >= 20: return 5
	if best_floor >= 15: return 4
	if best_floor >= 10: return 3
	if best_floor >= 5:  return 2
	return 1

func has_rune_fragment(rune_id: String) -> bool:
	return (rune_fragments.get(rune_id, 0) as int) > 0

func get_owned_rune_ids() -> Array:
	var ids: Array = []
	for rid in rune_fragments:
		if (rune_fragments[rid] as int) > 0:
			ids.append(rid)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ga: int = (RUNE_DEFS[a] as Array)[1]
		var gb: int = (RUNE_DEFS[b] as Array)[1]
		if ga != gb: return ga > gb
		return a < b
	)
	return ids

func is_rune_equipped(rune_id: String) -> bool:
	return rune_equipped.has(rune_id)

func equip_rune(slot: int, rune_id: String) -> void:
	while rune_equipped.size() <= slot:
		rune_equipped.append("")
	for i in rune_equipped.size():
		if rune_equipped[i] == rune_id:
			rune_equipped[i] = ""
	rune_equipped[slot] = rune_id
	_save()

func unequip_rune(slot: int) -> void:
	if slot < rune_equipped.size():
		rune_equipped[slot] = ""
		_save()

func toggle_rune_equip(rune_id: String) -> void:
	if is_rune_equipped(rune_id):
		for i in rune_equipped.size():
			if rune_equipped[i] == rune_id:
				unequip_rune(i)
				return
	else:
		var max_slots: int = get_rune_slot_count()
		for i in max_slots:
			var cur: String = rune_equipped[i] if i < rune_equipped.size() else ""
			if cur == "":
				equip_rune(i, rune_id)
				return
		equip_rune(0, rune_id)

func get_equipped_runes() -> Array:
	var result: Array = []
	for rid in rune_equipped:
		if rid != "" and has_rune_fragment(rid):
			result.append(rid)
	return result

func award_chest(run_max_floor: int) -> void:
	var grade: int
	if run_max_floor >= 25:   grade = RUNE_GRADE_LEGEND
	elif run_max_floor >= 10: grade = RUNE_GRADE_EPIC
	elif run_max_floor >= 5:  grade = RUNE_GRADE_RARE
	else:                     grade = RUNE_GRADE_NORMAL

	var rewards: Array = CHEST_REWARDS[grade]
	var frags_per: int = randi() % (rewards[1] - rewards[0] + 1) + rewards[0]
	var coins: int = randi() % (rewards[3] - rewards[2] + 1) + rewards[2]
	var num_types: int = rewards[4]

	var pool: Array = (RUNE_DROP_POOL[grade] as Array).duplicate()
	if grade > RUNE_GRADE_NORMAL:
		pool += (RUNE_DROP_POOL[grade - 1] as Array)
	pool.shuffle()

	var frags: Dictionary = {}
	for i in min(num_types, pool.size()):
		frags[pool[i]] = frags_per

	pending_chest = {"grade": grade, "frags": frags, "coins": coins}
	_save()

func open_chest() -> Dictionary:
	if pending_chest.is_empty(): return {}
	var result: Dictionary = pending_chest.duplicate(true)
	var frags: Dictionary = result.get("frags", {})
	for rid in frags:
		rune_fragments[rid] = (rune_fragments.get(rid, 0) as int) + (frags[rid] as int)
	rune_coins += result.get("coins", 0) as int
	pending_chest = {}
	_save()
	return result

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "explore_xp", explore_xp)
	cfg.set_value("progress", "best_floor", best_floor)
	cfg.set_value("progress", "selected_class", selected_class)
	cfg.set_value("runes", "coins", rune_coins)
	cfg.set_value("runes", "fragments", rune_fragments)
	cfg.set_value("runes", "equipped", rune_equipped)
	cfg.set_value("runes", "pending_chest", pending_chest)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	explore_xp = cfg.get_value("progress", "explore_xp", 0)
	best_floor = cfg.get_value("progress", "best_floor", 0)
	selected_class = cfg.get_value("progress", "selected_class", 0)
	rune_coins = cfg.get_value("runes", "coins", 0)
	rune_fragments = cfg.get_value("runes", "fragments", {})
	rune_equipped = cfg.get_value("runes", "equipped", [])
	pending_chest = cfg.get_value("runes", "pending_chest", {})
