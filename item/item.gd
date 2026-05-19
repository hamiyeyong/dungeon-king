class_name Item
extends RefCounted

enum Type {
	POTION_HEAL, POTION_REGEN, POTION_MANA, POTION_POISON, POTION_FIRE, POTION_CLEANSE, POTION_SLEEP, POTION_PARALYZE, POTION_ICE, POTION_EXP,
	FOOD, COOKED_FOOD, FOOD_ROTTEN,
	SCROLL_ENHANCE, SCROLL_BASH, SCROLL_TELEPORT, SCROLL_IDENTIFY, SCROLL_REMOVE_CURSE,
	# ─── 무기/방어구 블록 (is_equipment 범위 판정용으로 반드시 연속) ────────────
	# 단검 (Dagger)
	WEAPON_DAGGER_1, WEAPON_DAGGER_2, WEAPON_DAGGER_3, WEAPON_DAGGER_4, WEAPON_DAGGER_5,
	# 검 (Sword)
	WEAPON_SWORD_1, WEAPON_SWORD_2, WEAPON_SWORD_3, WEAPON_SWORD_4, WEAPON_SWORD_5,
	# 둔기 (Blunt)
	WEAPON_BLUNT_1, WEAPON_BLUNT_2, WEAPON_BLUNT_3, WEAPON_BLUNT_4, WEAPON_BLUNT_5,
	# 양손무기 (Two-handed)
	WEAPON_TWOHND_1, WEAPON_TWOHND_2, WEAPON_TWOHND_3, WEAPON_TWOHND_4, WEAPON_TWOHND_5,
	# 격투무기 (Martial)
	WEAPON_MARTIAL_1, WEAPON_MARTIAL_2, WEAPON_MARTIAL_3, WEAPON_MARTIAL_4, WEAPON_MARTIAL_5,
	# 활 (Bow)
	WEAPON_BOW_1, WEAPON_BOW_2, WEAPON_BOW_3, WEAPON_BOW_4, WEAPON_BOW_5,
	# 경갑 (Light Armor)
	ARMOR_LIGHT_1, ARMOR_LIGHT_2, ARMOR_LIGHT_3, ARMOR_LIGHT_4, ARMOR_LIGHT_5,
	# 중갑 (Heavy Armor) — 티어 3부터 시작
	ARMOR_HEAVY_3, ARMOR_HEAVY_4, ARMOR_HEAVY_5,
	# 방패 (Shield)
	SHIELD_1, SHIELD_2, SHIELD_3, SHIELD_4, SHIELD_5,
	# ─────────────────────────────────────────────────────────────────────────
	MATERIAL_BRANCH, MATERIAL_HERB, MATERIAL_STONE, MATERIAL_CLOTH, MATERIAL_TORCH,
	MATERIAL_ORE, MATERIAL_BOTTLE, MATERIAL_RAW_MEAT,
	MATERIAL_HERB_ICE, MATERIAL_HERB_BLOOD_MOSS, MATERIAL_HERB_GINSENG,
	MATERIAL_HERB_NIGHTSHADE, MATERIAL_HERB_AMBROSIA, MATERIAL_HERB_MUSHROOM,
	MATERIAL_HERB_MANDRAKE, MATERIAL_HERB_FIREWORT, MATERIAL_HERB_DREAMGRASS,
	MATERIAL_HERB_GARLIC,
	MATERIAL_DART, MATERIAL_ARROW_WOOD,
	TOOL_REPAIR,
	ANCIENT_SCROLL_MAGIC_MISSILE,
	ANCIENT_SCROLL_NATURE_LIGHTNING,
	ANCIENT_SCROLL_REGENERATION,
	ANCIENT_SCROLL_BARK_ARMOR,
	ANCIENT_SCROLL_DISPEL,
	MATERIAL_HERO_STONE,
	BURNED_FOOD,
	FROZEN_FOOD,
	ROASTED_HERB,
}

# 포션 색상별 스프라이트 (플레이어가 보는 것)
const COLOR_ATLAS: Array = [
	Vector2i(3, 8),  # 빨강
	Vector2i(4, 8),  # 파랑
	Vector2i(4, 9),  # 초록
	Vector2i(3, 9),  # 노랑
	Vector2i(4, 8),  # 보라 (파랑 베이스 + modulate)
	Vector2i(3, 8),  # 흰색 (빨강 베이스 + modulate)
	Vector2i(3, 8),  # 주황 (빨강 베이스 + modulate)
	Vector2i(3, 8),  # 분홍 (빨강 베이스 + modulate)
	Vector2i(4, 8),  # 하늘 (파랑 베이스 + modulate)
	Vector2i(4, 9),  # 갈색 (초록 베이스 + modulate)
]
const POTION_MODULATE: Array = [
	Color(1.0, 1.0, 1.0),        # 빨강
	Color(1.0, 1.0, 1.0),        # 파랑
	Color(1.0, 1.0, 1.0),        # 초록
	Color(1.0, 1.0, 1.0),        # 노랑
	Color(0.65, 0.2, 0.9),       # 보라
	Color(0.95, 0.95, 0.98),     # 흰색
	Color(1.0, 0.55, 0.1),       # 주황
	Color(1.0, 0.55, 0.75),      # 분홍
	Color(0.35, 0.75, 1.0),      # 하늘
	Color(0.55, 0.35, 0.15),     # 갈색
]
const FOOD_ATLAS        := Vector2i(6, 9)
const COOKED_FOOD_ATLAS := Vector2i(7, 8)
const FOOD_ROTTEN_ATLAS := Vector2i(6, 9)
const SCROLL_ATLAS      := Vector2i(0, 8)
const ANCIENT_SCROLL_ATLAS := Vector2i(0, 8)
const ANCIENT_SCROLL_TYPES: Array = [
	Type.ANCIENT_SCROLL_MAGIC_MISSILE,
	Type.ANCIENT_SCROLL_NATURE_LIGHTNING,
	Type.ANCIENT_SCROLL_REGENERATION,
	Type.ANCIENT_SCROLL_BARK_ARMOR,
	Type.ANCIENT_SCROLL_DISPEL,
]
const RAW_MEAT_ATLAS    := Vector2i(7, 9)
const COLORS := ["빨간색", "파란색", "초록색", "노란색", "보라색", "흰색", "주황색", "분홍색", "하늘색", "갈색"]
const NUM_POTIONS := 10
const SCROLL_NAMES := ["강타 주문서", "순간이동 주문서", "식별 주문서", "저주 해제 주문서"]
const SCROLL_TYPES: Array = [Type.SCROLL_BASH, Type.SCROLL_TELEPORT, Type.SCROLL_IDENTIFY, Type.SCROLL_REMOVE_CURSE]

# 장비 정의: [이름, min_atk, max_atk, def, 내구도, atlas, 힘요구]
const EQUIPMENT_DATA := {
	# ── 단검 (Dagger) ───────────────────────────────────────────────────────
	Type.WEAPON_DAGGER_1: ["단검",           1, 10, 0, 15, Vector2i(1, 3), 9],
	Type.WEAPON_DAGGER_2: ["시클",           2, 12, 0, 20, Vector2i(1, 3), 11],
	Type.WEAPON_DAGGER_3: ["와카자키",       3, 16, 0, 25, Vector2i(1, 3), 13],
	Type.WEAPON_DAGGER_4: ["쿠크리",         4, 22, 0, 30, Vector2i(1, 3), 15],
	Type.WEAPON_DAGGER_5: ["암살검",         5, 30, 0, 35, Vector2i(1, 3), 17],
	# ── 검 (Sword) ──────────────────────────────────────────────────────────
	Type.WEAPON_SWORD_1:  ["숏소드",         1, 11, 0, 15, Vector2i(2, 3), 10],
	Type.WEAPON_SWORD_2:  ["브로드소드",     2, 14, 0, 20, Vector2i(2, 3), 12],
	Type.WEAPON_SWORD_3:  ["롱소드",         3, 19, 0, 25, Vector2i(2, 3), 14],
	Type.WEAPON_SWORD_4:  ["세이버",         4, 27, 0, 30, Vector2i(2, 3), 16],
	Type.WEAPON_SWORD_5:  ["워소드",         5, 36, 0, 35, Vector2i(2, 3), 18],
	# ── 둔기 (Blunt) ────────────────────────────────────────────────────────
	Type.WEAPON_BLUNT_1:  ["곤봉",           1, 10, 0, 18, Vector2i(0, 3), 10],
	Type.WEAPON_BLUNT_2:  ["도리깨",         2, 13, 0, 22, Vector2i(0, 3), 12],
	Type.WEAPON_BLUNT_3:  ["메이스",         3, 18, 0, 27, Vector2i(0, 3), 14],
	Type.WEAPON_BLUNT_4:  ["배틀액스",       4, 24, 0, 32, Vector2i(0, 3), 16],
	Type.WEAPON_BLUNT_5:  ["워해머",         5, 33, 0, 38, Vector2i(0, 3), 18],
	# ── 양손무기 (Two-handed) ────────────────────────────────────────────────
	Type.WEAPON_TWOHND_1: ["벌목도끼",       2, 13, 0, 20, Vector2i(0, 3), 11],
	Type.WEAPON_TWOHND_2: ["그레이트소드",   3, 18, 0, 25, Vector2i(0, 3), 13],
	Type.WEAPON_TWOHND_3: ["글레이브",       4, 24, 0, 30, Vector2i(0, 3), 15],
	Type.WEAPON_TWOHND_4: ["미늘창",         5, 33, 0, 35, Vector2i(0, 3), 17],
	Type.WEAPON_TWOHND_5: ["클레이모어",     6, 44, 0, 40, Vector2i(0, 3), 19],
	# ── 격투무기 (Martial) ───────────────────────────────────────────────────
	Type.WEAPON_MARTIAL_1: ["지팡이",        1,  5, 0, 15, Vector2i(0, 3), 9],
	Type.WEAPON_MARTIAL_2: ["너클",          2,  7, 0, 18, Vector2i(0, 3), 11],
	Type.WEAPON_MARTIAL_3: ["톤파",          3,  9, 0, 22, Vector2i(0, 3), 13],
	Type.WEAPON_MARTIAL_4: ["배틀클로",      4, 13, 0, 27, Vector2i(0, 3), 15],
	Type.WEAPON_MARTIAL_5: ["철주먹",        5, 18, 0, 32, Vector2i(0, 3), 17],
	# ── 활 (Bow) ────────────────────────────────────────────────────────────
	Type.WEAPON_BOW_1:    ["숏보우",         1, 10, 0, 15, Vector2i(1, 7), 9],
	Type.WEAPON_BOW_2:    ["롱보우",         2, 12, 0, 20, Vector2i(1, 7), 11],
	Type.WEAPON_BOW_3:    ["헌터보우",       3, 16, 0, 25, Vector2i(1, 7), 13],
	Type.WEAPON_BOW_4:    ["컴포지트 보우",  4, 22, 0, 30, Vector2i(1, 7), 15],
	Type.WEAPON_BOW_5:    ["엘븐 보우",      5, 30, 0, 35, Vector2i(1, 7), 17],
	# ── 경갑 (Light Armor) ───────────────────────────────────────────────────
	Type.ARMOR_LIGHT_1:   ["천 옷",          0,  0, 2,  15, Vector2i(5, 3), 9],
	Type.ARMOR_LIGHT_2:   ["가죽 갑옷",      0,  0, 4,  20, Vector2i(5, 3), 11],
	Type.ARMOR_LIGHT_3:   ["튼튼한 가죽 갑옷", 0, 0, 6, 25, Vector2i(5, 3), 13],
	Type.ARMOR_LIGHT_4:   ["금속장식 가죽 갑옷", 0, 0, 8, 30, Vector2i(5, 3), 15],
	Type.ARMOR_LIGHT_5:   ["브리건딘",       0,  0, 10, 35, Vector2i(5, 3), 17],
	# ── 중갑 (Heavy Armor) ───────────────────────────────────────────────────
	Type.ARMOR_HEAVY_3:   ["링메일",         0,  0, 7,  28, Vector2i(6, 3), 14],
	Type.ARMOR_HEAVY_4:   ["아이언메일",     0,  0, 9,  33, Vector2i(6, 3), 16],
	Type.ARMOR_HEAVY_5:   ["플레이트 메일",  0,  0, 11, 40, Vector2i(6, 3), 18],
	# ── 방패 (Shield) ────────────────────────────────────────────────────────
	Type.SHIELD_1:        ["나무 방패",       0,  0, 4,  12, Vector2i(3, 3), 10],
	Type.SHIELD_2:        ["버클러",          0,  0, 6,  18, Vector2i(3, 3), 12],
	Type.SHIELD_3:        ["라운드 방패",     0,  0, 8,  24, Vector2i(4, 3), 14],
	Type.SHIELD_4:        ["배틀 방패",       0,  0, 10, 30, Vector2i(4, 3), 16],
	Type.SHIELD_5:        ["기사의 방패",     0,  0, 12, 36, Vector2i(4, 3), 18],
}

# 제작 레시피: [결과타입, 결과내구도, [[재료타입, 개수], ...]]
const RECIPES: Array = [
	# 무기 (티어 1 제작 가능)
	[Type.WEAPON_DAGGER_1,  15, [[Type.MATERIAL_BRANCH, 2]]],
	[Type.WEAPON_SWORD_1,   15, [[Type.MATERIAL_BRANCH, 1], [Type.MATERIAL_STONE, 1]]],
	[Type.WEAPON_BLUNT_1,   18, [[Type.MATERIAL_STONE, 2]]],
	[Type.WEAPON_TWOHND_1,  20, [[Type.MATERIAL_BRANCH, 3]]],
	[Type.WEAPON_MARTIAL_1, 15, [[Type.MATERIAL_BRANCH, 1]]],
	[Type.WEAPON_BOW_1,     15, [[Type.MATERIAL_BRANCH, 2], [Type.MATERIAL_CLOTH, 1]]],
	# 방어구 (티어 1~2 제작 가능)
	[Type.ARMOR_LIGHT_1,    15, [[Type.MATERIAL_CLOTH,  2]]],
	[Type.ARMOR_LIGHT_2,    20, [[Type.MATERIAL_CLOTH,  1], [Type.MATERIAL_STONE, 1]]],
	[Type.SHIELD_1,         12, [[Type.MATERIAL_BRANCH, 2]]],
	# 투척 아이템
	[Type.MATERIAL_ARROW_WOOD, 0, [[Type.MATERIAL_BRANCH, 1]]],
	# 도구
	[Type.SCROLL_ENHANCE,    0, [[Type.MATERIAL_HERB,   2], [Type.MATERIAL_BRANCH, 1]]],
	[Type.MATERIAL_TORCH,    0, [[Type.MATERIAL_BRANCH, 1], [Type.MATERIAL_CLOTH, 1]]],
	[Type.TOOL_REPAIR,       0, [[Type.MATERIAL_ORE, 1]]],
]

# 약초 재료 → 물약 타입 (솥에서 재료 선택 시 사용) — 1:1 매핑
const HERB_POTION_MAP: Dictionary = {
	Type.MATERIAL_HERB_GINSENG:     Type.POTION_HEAL,
	Type.MATERIAL_HERB_MUSHROOM:    Type.POTION_REGEN,
	Type.MATERIAL_HERB_MANDRAKE:    Type.POTION_MANA,
	Type.MATERIAL_HERB_NIGHTSHADE:  Type.POTION_POISON,
	Type.MATERIAL_HERB_FIREWORT:    Type.POTION_FIRE,
	Type.MATERIAL_HERB_GARLIC:      Type.POTION_CLEANSE,
	Type.MATERIAL_HERB_DREAMGRASS:  Type.POTION_SLEEP,
	Type.MATERIAL_HERB_BLOOD_MOSS:  Type.POTION_PARALYZE,
	Type.MATERIAL_HERB_ICE:         Type.POTION_ICE,
	Type.MATERIAL_HERB_AMBROSIA:    Type.POTION_EXP,
}

# 층수 → 드롭 가능한 무기 풀 (tier-based)
const WEAPON_POOL_BY_TIER: Array = [
	[],  # tier 0 (미사용)
	[Type.WEAPON_DAGGER_1, Type.WEAPON_SWORD_1, Type.WEAPON_BLUNT_1, Type.WEAPON_TWOHND_1, Type.WEAPON_MARTIAL_1, Type.WEAPON_BOW_1],
	[Type.WEAPON_DAGGER_2, Type.WEAPON_SWORD_2, Type.WEAPON_BLUNT_2, Type.WEAPON_TWOHND_2, Type.WEAPON_MARTIAL_2, Type.WEAPON_BOW_2],
	[Type.WEAPON_DAGGER_3, Type.WEAPON_SWORD_3, Type.WEAPON_BLUNT_3, Type.WEAPON_TWOHND_3, Type.WEAPON_MARTIAL_3, Type.WEAPON_BOW_3],
	[Type.WEAPON_DAGGER_4, Type.WEAPON_SWORD_4, Type.WEAPON_BLUNT_4, Type.WEAPON_TWOHND_4, Type.WEAPON_MARTIAL_4, Type.WEAPON_BOW_4],
	[Type.WEAPON_DAGGER_5, Type.WEAPON_SWORD_5, Type.WEAPON_BLUNT_5, Type.WEAPON_TWOHND_5, Type.WEAPON_MARTIAL_5, Type.WEAPON_BOW_5],
]
const ARMOR_POOL_BY_TIER: Array = [
	[],  # tier 0
	[Type.ARMOR_LIGHT_1, Type.SHIELD_1],
	[Type.ARMOR_LIGHT_2, Type.SHIELD_2],
	[Type.ARMOR_LIGHT_3, Type.ARMOR_HEAVY_3, Type.SHIELD_3],
	[Type.ARMOR_LIGHT_4, Type.ARMOR_HEAVY_4, Type.SHIELD_4],
	[Type.ARMOR_LIGHT_5, Type.ARMOR_HEAVY_5, Type.SHIELD_5],
]

static func get_type_name(t: int) -> String:
	if EQUIPMENT_DATA.has(t):
		return EQUIPMENT_DATA[t][0]
	match t:
		Type.SCROLL_ENHANCE:   return "강화 두루마리"
		Type.SCROLL_BASH:         return "강타 주문서"
		Type.SCROLL_TELEPORT:     return "순간이동 주문서"
		Type.SCROLL_IDENTIFY:     return "식별 주문서"
		Type.SCROLL_REMOVE_CURSE: return "저주 해제 주문서"
		Type.MATERIAL_BRANCH:  return "나뭇가지"
		Type.MATERIAL_HERB:    return "약초"
		Type.MATERIAL_STONE:   return "돌"
		Type.MATERIAL_CLOTH:   return "천"
		Type.MATERIAL_TORCH:   return "횃불"
		Type.MATERIAL_ORE:     return "광석"
		Type.MATERIAL_BOTTLE:  return "빈병"
		Type.MATERIAL_RAW_MEAT:          return "생고기"
		Type.MATERIAL_HERB_ICE:          return "식은 얼음송이"
		Type.MATERIAL_HERB_BLOOD_MOSS:   return "말린 피이끼"
		Type.MATERIAL_HERB_GINSENG:      return "산삼 뿌리"
		Type.MATERIAL_HERB_NIGHTSHADE:   return "나이트쉐이드 잎"
		Type.MATERIAL_HERB_AMBROSIA:     return "암브로시아 꽃"
		Type.MATERIAL_HERB_MUSHROOM:     return "말린 영지버섯"
		Type.MATERIAL_HERB_MANDRAKE:     return "만드라고라 뿌리"
		Type.MATERIAL_HERB_FIREWORT:     return "화염초 꽃잎"
		Type.MATERIAL_HERB_DREAMGRASS:   return "꿈결초 꽃잎"
		Type.MATERIAL_HERB_GARLIC:       return "생마늘"
		Type.MATERIAL_DART:              return "다트"
		Type.MATERIAL_ARROW_WOOD:        return "나무 화살"
		Type.TOOL_REPAIR:                return "수리도구"
		Type.FOOD_ROTTEN:                return "상한 식량"
		Type.MATERIAL_HERO_STONE:        return "영웅의 돌"
		Type.ANCIENT_SCROLL_MAGIC_MISSILE:    return "고대 주문서: 매직 미사일"
		Type.ANCIENT_SCROLL_NATURE_LIGHTNING: return "고대 주문서: 자연의 번개"
		Type.ANCIENT_SCROLL_REGENERATION:     return "고대 주문서: 재생"
		Type.ANCIENT_SCROLL_BARK_ARMOR:       return "고대 주문서: 나무껍질 갑옷"
		Type.ANCIENT_SCROLL_DISPEL:           return "고대 주문서: 디스펠"
	return "?"

# 층수에 맞는 장비 타입 반환 (floor 0-base)
static func get_equip_type_for_floor(floor_num: int, want_weapon: bool) -> int:
	var tier: int = clampi(1 + floor_num / 6, 1, 5)
	# 50% 확률로 현재 티어, 50% 확률로 한 단계 낮은 티어
	if tier > 1 and randi() % 2 == 0:
		tier -= 1
	var pool: Array = WEAPON_POOL_BY_TIER[tier] if want_weapon else ARMOR_POOL_BY_TIER[tier]
	return pool[randi() % pool.size()]

const THROWABLE_BUNDLE_SIZES := {
	Type.MATERIAL_DART: 5,
	Type.MATERIAL_ARROW_WOOD: 10,
}

const DART_DMG := 5
const ARROW_DMG := 8

const POISON_DMG_PER_TURN := 2
const POISON_TURNS        := 5
const FIRE_DMG_PER_TURN   := 3
const FIRE_TURNS          := 4
const FIRE_TURNS_ADJ      := 2
const SLEEP_TURNS         := 3

var item_type: int = Type.FOOD
var color_idx: int = 0      # 포션: 색상 인덱스 / 주문서: SCROLL_TYPES 인덱스
var durability: int = 0
var max_durability: int = 0
var enhance_level: int = 0
var is_blessed: bool = false
var is_cursed: bool = false
var freshness_turns: int = 0

func is_equipment() -> bool:
	return item_type >= Type.WEAPON_DAGGER_1 and item_type <= Type.SHIELD_5

func is_material() -> bool:
	return (item_type >= Type.MATERIAL_BRANCH and item_type <= Type.MATERIAL_HERB_GARLIC) \
		or item_type in [Type.MATERIAL_DART, Type.MATERIAL_ARROW_WOOD, Type.MATERIAL_HERO_STONE]

func is_weapon() -> bool:
	return item_type >= Type.WEAPON_DAGGER_1 and item_type <= Type.WEAPON_BOW_5

func is_shield() -> bool:
	return item_type >= Type.SHIELD_1 and item_type <= Type.SHIELD_5

func is_armor() -> bool:
	return (item_type >= Type.ARMOR_LIGHT_1 and item_type <= Type.ARMOR_LIGHT_5) \
		or (item_type >= Type.ARMOR_HEAVY_3 and item_type <= Type.ARMOR_HEAVY_5)

func is_light_armor() -> bool:
	return item_type >= Type.ARMOR_LIGHT_1 and item_type <= Type.ARMOR_LIGHT_5

func is_heavy_armor() -> bool:
	return item_type >= Type.ARMOR_HEAVY_3 and item_type <= Type.ARMOR_HEAVY_5

func is_bow() -> bool:
	return item_type >= Type.WEAPON_BOW_1 and item_type <= Type.WEAPON_BOW_5

func is_two_handed() -> bool:
	return item_type >= Type.WEAPON_TWOHND_1 and item_type <= Type.WEAPON_TWOHND_5

func get_str_req() -> int:
	if not EQUIPMENT_DATA.has(item_type):
		return 0
	return EQUIPMENT_DATA[item_type][6]

func get_weapon_tier() -> int:
	if not is_weapon():
		return 0
	# 각 카테고리는 5개씩 연속 — 카테고리 내 오프셋이 티어
	var base: int
	if item_type <= Type.WEAPON_DAGGER_5:   base = Type.WEAPON_DAGGER_1
	elif item_type <= Type.WEAPON_SWORD_5:  base = Type.WEAPON_SWORD_1
	elif item_type <= Type.WEAPON_BLUNT_5:  base = Type.WEAPON_BLUNT_1
	elif item_type <= Type.WEAPON_TWOHND_5: base = Type.WEAPON_TWOHND_1
	elif item_type <= Type.WEAPON_MARTIAL_5: base = Type.WEAPON_MARTIAL_1
	else:                                   base = Type.WEAPON_BOW_1
	return (item_type - base) + 1

func is_scroll() -> bool:
	return item_type in [Type.SCROLL_ENHANCE, Type.SCROLL_BASH, Type.SCROLL_TELEPORT, Type.SCROLL_IDENTIFY, Type.SCROLL_REMOVE_CURSE]

func is_ancient_scroll() -> bool:
	return item_type in ANCIENT_SCROLL_TYPES

static func get_spell_id_for_type(t: int) -> String:
	match t:
		Type.ANCIENT_SCROLL_MAGIC_MISSILE:    return "magic_missile"
		Type.ANCIENT_SCROLL_NATURE_LIGHTNING: return "nature_lightning"
		Type.ANCIENT_SCROLL_REGENERATION:     return "regeneration"
		Type.ANCIENT_SCROLL_BARK_ARMOR:       return "bark_armor"
		Type.ANCIENT_SCROLL_DISPEL:           return "dispel"
	return ""

func is_throwable() -> bool:
	return item_type in [Type.MATERIAL_DART, Type.MATERIAL_ARROW_WOOD]

func is_food() -> bool:
	return item_type in [Type.FOOD, Type.COOKED_FOOD, Type.FOOD_ROTTEN, Type.BURNED_FOOD, Type.FROZEN_FOOD, Type.ROASTED_HERB]

func is_potion() -> bool:
	return item_type >= Type.POTION_HEAL and item_type <= Type.POTION_EXP

func is_wood() -> bool:
	return item_type in [Type.MATERIAL_BRANCH, Type.MATERIAL_ARROW_WOOD, Type.SHIELD_1, Type.WEAPON_MARTIAL_1]

func get_equip_atk_min() -> int:
	if not is_weapon() or not EQUIPMENT_DATA.has(item_type):
		return 0
	var ratio: float = float(max(0, durability)) / float(max(1, max_durability))
	var total: int = EQUIPMENT_DATA[item_type][1] + enhance_level
	if is_blessed:
		total += 1
	elif is_cursed:
		total = max(0, total - 1)
	return total if ratio > 0 else (total / 2)

func get_equip_atk_max() -> int:
	if not is_weapon() or not EQUIPMENT_DATA.has(item_type):
		return 0
	var ratio: float = float(max(0, durability)) / float(max(1, max_durability))
	var total: int = EQUIPMENT_DATA[item_type][2] + enhance_level
	if is_blessed:
		total += 1
	elif is_cursed:
		total = max(0, total - 1)
	return total if ratio > 0 else (total / 2)

func get_equip_atk() -> int:
	return get_equip_atk_max()

func get_equip_def() -> int:
	if not is_equipment() or not EQUIPMENT_DATA.has(item_type):
		return 0
	var ratio: float = float(max(0, durability)) / float(max(1, max_durability))
	var total: int = EQUIPMENT_DATA[item_type][3] + (enhance_level if not is_weapon() else 0)
	if is_blessed:
		total += 1
	elif is_cursed:
		total = max(0, total - 1)
	return total if ratio > 0 else (total / 2)

func get_display_name(identified: bool) -> String:
	if is_equipment() and EQUIPMENT_DATA.has(item_type):
		var d: Array = EQUIPMENT_DATA[item_type]
		var enh := "+%d" % enhance_level if enhance_level > 0 else ""
		var suffix := " [저주]" if is_cursed else (" [축복]" if is_blessed else "")
		var str_r: int = d[6]
		var str_note := " (힘%d)" % str_r if str_r > 0 else ""
		return "%s%s%s [%d/%d]%s" % [d[0], enh, str_note, durability, max_durability, suffix]
	match item_type:
		Type.FOOD:             return "식량"
		Type.COOKED_FOOD:      return "익은 식량"
		Type.FOOD_ROTTEN:      return "상한 식량"
		Type.BURNED_FOOD:      return "탄 식량"
		Type.FROZEN_FOOD:      return "언 식량"
		Type.ROASTED_HERB:     return "구운 약초"
		Type.MATERIAL_BRANCH:  return "나뭇가지"
		Type.MATERIAL_HERB:    return "약초"
		Type.MATERIAL_STONE:   return "돌"
		Type.MATERIAL_CLOTH:   return "천"
		Type.MATERIAL_TORCH:   return "횃불 (보유 시 시야 확장)"
		Type.SCROLL_ENHANCE:   return "강화 두루마리"
		Type.MATERIAL_ORE:     return "광석"
		Type.MATERIAL_BOTTLE:  return "빈병"
		Type.MATERIAL_RAW_MEAT:          return "생고기"
		Type.MATERIAL_HERB_ICE:          return "식은 얼음송이"
		Type.MATERIAL_HERB_BLOOD_MOSS:   return "말린 피이끼"
		Type.MATERIAL_HERB_GINSENG:      return "산삼 뿌리"
		Type.MATERIAL_HERB_NIGHTSHADE:   return "나이트쉐이드 잎"
		Type.MATERIAL_HERB_AMBROSIA:     return "암브로시아 꽃"
		Type.MATERIAL_HERB_MUSHROOM:     return "말린 영지버섯"
		Type.MATERIAL_HERB_MANDRAKE:     return "만드라고라 뿌리"
		Type.MATERIAL_HERB_FIREWORT:     return "화염초 꽃잎"
		Type.MATERIAL_HERB_DREAMGRASS:   return "꿈결초 꽃잎"
		Type.MATERIAL_HERB_GARLIC:       return "생마늘"
		Type.MATERIAL_DART:              return "다트"
		Type.MATERIAL_ARROW_WOOD:        return "나무 화살"
		Type.TOOL_REPAIR:                return "수리도구"
	if is_ancient_scroll():
		return get_type_name(item_type)
	if is_scroll():
		return _scroll_display_name(identified)
	if identified:
		return _true_name()
	return COLORS[color_idx] + " 물약"

func _scroll_display_name(identified: bool) -> String:
	if identified:
		return get_type_name(item_type)
	return "낡은 주문서"

func _true_name() -> String:
	match item_type:
		Type.POTION_HEAL:     return "회복 물약"
		Type.POTION_REGEN:    return "재생 물약"
		Type.POTION_MANA:     return "정신력 물약"
		Type.POTION_POISON:   return "독 물약"
		Type.POTION_FIRE:     return "화염 물약"
		Type.POTION_CLEANSE:  return "정화 물약"
		Type.POTION_SLEEP:    return "수면 물약"
		Type.POTION_PARALYZE: return "마비 물약"
		Type.POTION_ICE:      return "얼음 물약"
		Type.POTION_EXP:      return "경험치 물약"
	return "식량"

func get_reveal_text() -> String:
	if is_scroll():
		return "낡은 주문서의 정체가 밝혀졌다! → %s" % get_display_name(true)
	return "%s 물약은 %s이었다!" % [COLORS[color_idx], _true_name()]

# 해로운 포션(독/불/수면/마비/얼음)은 던질 때 즉시 공개, 주문서(강화 제외)도 던질 때 공개
func reveals_on_throw() -> bool:
	return item_type in [Type.POTION_POISON, Type.POTION_FIRE, Type.POTION_SLEEP, Type.POTION_PARALYZE, Type.POTION_ICE] \
		or item_type in [Type.SCROLL_BASH, Type.SCROLL_TELEPORT, Type.SCROLL_IDENTIFY, Type.SCROLL_REMOVE_CURSE]

func get_stat_label() -> String:
	if not is_equipment() or not EQUIPMENT_DATA.has(item_type):
		return ""
	var str_r: int = EQUIPMENT_DATA[item_type][6]
	var str_note := " (힘 %d 필요)" % str_r if str_r > 0 else ""
	if is_weapon():
		var min_a: int = EQUIPMENT_DATA[item_type][1] + enhance_level
		var max_a: int = EQUIPMENT_DATA[item_type][2] + enhance_level
		return "ATK %d~%d%s" % [min_a, max_a, str_note]
	var def_v: int = EQUIPMENT_DATA[item_type][3] + enhance_level
	return "DEF +%d%s" % [def_v, str_note]

func get_modulate() -> Color:
	if is_equipment():
		return Color(1.0, 0.85, 0.6) if is_blessed else (Color(0.65, 0.5, 0.8) if is_cursed else Color.WHITE)
	if item_type == Type.FOOD or item_type == Type.COOKED_FOOD:
		return Color.WHITE
	if item_type == Type.FOOD_ROTTEN:
		return Color(0.55, 0.75, 0.4)
	if item_type == Type.BURNED_FOOD:
		return Color(0.35, 0.25, 0.15)
	if item_type == Type.FROZEN_FOOD:
		return Color(0.6, 0.85, 1.0)
	if item_type == Type.ROASTED_HERB:
		return Color(0.7, 0.9, 0.5)
	if is_ancient_scroll():
		return Color(1.0, 0.85, 0.4)
	if is_scroll():
		return Color(0.85, 0.95, 1.0)
	return POTION_MODULATE[color_idx]

func get_atlas() -> Vector2i:
	if is_equipment() and EQUIPMENT_DATA.has(item_type):
		return EQUIPMENT_DATA[item_type][5]
	match item_type:
		Type.FOOD:             return FOOD_ATLAS
		Type.COOKED_FOOD:      return COOKED_FOOD_ATLAS
		Type.FOOD_ROTTEN:      return FOOD_ROTTEN_ATLAS
		Type.BURNED_FOOD:      return COOKED_FOOD_ATLAS
		Type.FROZEN_FOOD:      return FOOD_ATLAS
		Type.ROASTED_HERB:     return FOOD_ATLAS
		Type.SCROLL_ENHANCE, Type.SCROLL_BASH, Type.SCROLL_TELEPORT, Type.SCROLL_IDENTIFY, Type.SCROLL_REMOVE_CURSE:
			return SCROLL_ATLAS
		Type.ANCIENT_SCROLL_MAGIC_MISSILE, Type.ANCIENT_SCROLL_NATURE_LIGHTNING, \
		Type.ANCIENT_SCROLL_REGENERATION, Type.ANCIENT_SCROLL_BARK_ARMOR, \
		Type.ANCIENT_SCROLL_DISPEL:
			return ANCIENT_SCROLL_ATLAS
		Type.MATERIAL_BRANCH:  return Vector2i(5, 9)
		Type.MATERIAL_HERB:    return Vector2i(6, 8)
		Type.MATERIAL_STONE:   return Vector2i(7, 9)
		Type.MATERIAL_CLOTH:   return Vector2i(5, 8)
		Type.MATERIAL_TORCH:   return Vector2i(1, 4)
		Type.MATERIAL_ORE:     return Vector2i(7, 9)
		Type.MATERIAL_BOTTLE:  return Vector2i(0, 7)
		Type.MATERIAL_RAW_MEAT:        return Vector2i(7, 9)
		Type.MATERIAL_HERB_ICE, Type.MATERIAL_HERB_BLOOD_MOSS, Type.MATERIAL_HERB_GINSENG, Type.MATERIAL_HERB_NIGHTSHADE, Type.MATERIAL_HERB_AMBROSIA, Type.MATERIAL_HERB_MUSHROOM, Type.MATERIAL_HERB_MANDRAKE, Type.MATERIAL_HERB_FIREWORT, Type.MATERIAL_HERB_DREAMGRASS, Type.MATERIAL_HERB_GARLIC:
			return Vector2i(6, 8)
		Type.MATERIAL_DART:            return Vector2i(1, 7)
		Type.MATERIAL_ARROW_WOOD:      return Vector2i(1, 7)
		Type.TOOL_REPAIR:              return Vector2i(1, 7)
		Type.MATERIAL_HERO_STONE:      return Vector2i(7, 9)
	return COLOR_ATLAS[color_idx]

func apply(player) -> String:
	match item_type:
		Type.POTION_HEAL:
			var heal: int = int(player.max_hp * (0.9 if is_blessed else 0.8))
			player.hp = min(player.max_hp, player.hp + heal) as int
			if is_blessed:
				player.regen_turns = max(player.regen_turns, 5)
			player.stats_changed.emit()
			return "회복 물약! HP +%d%s" % [heal, " + 재생 [축복]" if is_blessed else ""]
		Type.POTION_REGEN:
			var turns: int = 10 if is_blessed else 5
			player.regen_turns = max(player.regen_turns, turns) as int
			player.stats_changed.emit()
			return "재생 물약! %d턴간 HP 재생%s" % [turns, " [축복]" if is_blessed else ""]
		Type.POTION_MANA:
			var gain: int = player.max_mp - player.mp if is_blessed else int(player.max_mp * 0.8)
			player.mp = min(player.max_mp, player.mp + gain) as int
			player.stats_changed.emit()
			return "정신력 물약! MP +%d%s" % [gain, " [축복]" if is_blessed else ""]
		Type.POTION_POISON:
			if is_blessed:
				var heal: int = 10
				player.hp = min(player.max_hp, player.hp + heal) as int
				player.stats_changed.emit()
				return "축복 독 물약! 독 대신 HP +%d [축복]" % heal
			player.hp = max(1, player.hp - 5) as int
			player.apply_status("poison", POISON_TURNS)
			player.stats_changed.emit()
			return "독 물약 마심! HP -5 + 독 상태이상! (%d턴)" % POISON_TURNS
		Type.POTION_FIRE:
			if is_blessed:
				var mp_gain: int = 20
				player.mp = min(player.max_mp, player.mp + mp_gain) as int
				player.stats_changed.emit()
				return "축복 화염 물약! 화염 대신 MP +%d [축복]" % mp_gain
			player.hp = max(1, player.hp - 8) as int
			player.apply_status("fire", FIRE_TURNS)
			player.stats_changed.emit()
			return "화염 물약 마심! HP -8 + 화상 상태이상! (%d턴)" % FIRE_TURNS
		Type.POTION_CLEANSE:
			player.poison_turns = 0
			player.fire_turns = 0
			player.sleep_turns = 0
			player.paralyze_turns = 0
			player.frozen_turns = 0
			player.slow_turns = 0
			player.wound_turns = 0
			player.blind_turns = 0
			player.curse_atk = 0
			player.curse_def = 0
			player._recalc_equip_stats()
			player.stats_changed.emit()
			return "모든 상태이상 & 저주 해제!"
		Type.POTION_SLEEP:
			if is_blessed:
				player.fatigue = max(0, player.fatigue - 300) as int
				player.stats_changed.emit()
				return "축복 수면 물약! 수면 대신 피로도 -300 [축복]"
			player.apply_status("sleep", SLEEP_TURNS)
			player.fatigue = max(0, player.fatigue - 100) as int
			player.stats_changed.emit()
			return "수면 상태이상! (%d턴) 피로도 -100" % SLEEP_TURNS
		Type.POTION_PARALYZE:
			if is_blessed:
				var heal: int = int(player.max_hp * 0.15)
				player.hp = min(player.max_hp, player.hp + heal) as int
				player.stats_changed.emit()
				return "축복 마비 물약! 마비 대신 HP +%d [축복]" % heal
			player.apply_status("paralyze", 3)
			player.stats_changed.emit()
			return "마비 물약! 마비 상태이상 (3턴)"
		Type.POTION_ICE:
			if is_blessed:
				var heal: int = int(player.max_hp * 0.1)
				player.hp = min(player.max_hp, player.hp + heal) as int
				player.stats_changed.emit()
				return "축복 얼음 물약! 빙결 대신 HP +%d [축복]" % heal
			player.apply_status("slow", 3)
			player.stats_changed.emit()
			return "얼음 물약! 느려짐 상태이상 (3턴)"
		Type.POTION_EXP:
			var xp: int = 250 if is_blessed else 150
			player.gain_exp(xp)
			return "경험치 물약! 경험치 +%d%s" % [xp, " [축복]" if is_blessed else ""]
		Type.FOOD:
			var reduce: int = 45 if is_blessed else 30
			player.hunger = max(0, player.hunger - reduce) as int
			if is_blessed and randf() < 0.15:
				if randi() % 2 == 0:
					player.max_hp += 1
					player.hp = min(player.hp + 1, player.max_hp)
					player.stats_changed.emit()
					return "식량 섭취! 배고픔 -%d + 최대 HP +1 [축복]" % reduce
				else:
					player.max_mp += 5
					player.stats_changed.emit()
					return "식량 섭취! 배고픔 -%d + 최대 MP +5 [축복]" % reduce
			player.stats_changed.emit()
			return "식량 섭취! 배고픔 -%d%s" % [reduce, " [축복]" if is_blessed else ""]
		Type.COOKED_FOOD:
			player.hunger = max(0, player.hunger - 60)
			player.stats_changed.emit()
			return "익은 식량 섭취! 배고픔 -60"
		Type.FOOD_ROTTEN:
			player.hunger = max(0, player.hunger - 15)
			player.apply_status("poison", POISON_TURNS)
			player.stats_changed.emit()
			return "상한 식량 섭취! 배고픔 -15, 독 상태이상!"
		Type.BURNED_FOOD:
			player.hunger = max(0, player.hunger - 25)
			player.stats_changed.emit()
			return "탄 식량 섭취! 배고픔 -25"
		Type.FROZEN_FOOD:
			player.hunger = max(0, player.hunger - 35) as int
			player.stats_changed.emit()
			return "언 식량 섭취! 배고픔 -35"
		Type.ROASTED_HERB:
			player.hunger = max(0, player.hunger - 20) as int
			player.stats_changed.emit()
			return "구운 약초 섭취! 배고픔 -20"
		Type.MATERIAL_RAW_MEAT:
			player.hunger = max(0, player.hunger - 15) as int
			player.stats_changed.emit()
			if randf() < 0.3:
				player.apply_status("poison", POISON_TURNS)
				return "생고기 섭취! 배고픔 -15, 독 상태이상!"
			return "생고기 섭취! 배고픔 -15"
		Type.TOOL_REPAIR:
			var target: Item = null
			var lowest: float = 1.0
			for eq in [player.equipped_weapon, player.equipped_shield, player.equipped_armor]:
				if eq == null:
					continue
				var ratio: float = float(eq.durability) / float(max(1, eq.max_durability))
				if ratio < lowest:
					lowest = ratio
					target = eq
			if target == null:
				return "장착된 장비가 없습니다."
			var heal: int = target.max_durability / 2
			target.durability = min(target.max_durability, target.durability + heal)
			target.max_durability = max(1, target.max_durability - 1)
			player._recalc_equip_stats()
			player.stats_changed.emit()
			return "%s 수리! (+%d 내구도, 최대 내구도 -1)" % [EQUIPMENT_DATA[target.item_type][0], heal]
	return ""
