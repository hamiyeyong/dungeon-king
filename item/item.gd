class_name Item
extends RefCounted

enum Type {
	POTION_HEAL, POTION_HUNGER, POTION_POISON, POTION_FIRE, POTION_CLEANSE, POTION_SLEEP,
	FOOD, COOKED_FOOD, FOOD_ROTTEN,
	SCROLL_ENHANCE, SCROLL_BASH, SCROLL_TELEPORT, SCROLL_IDENTIFY, SCROLL_REMOVE_CURSE,
	WEAPON_WOOD, WEAPON_STONE, WEAPON_IRON,
	WEAPON_SHORTSWORD, WEAPON_STAFF, WEAPON_DAGGER,
	SHIELD_WOOD, SHIELD_IRON,
	ARMOR_CLOTH, ARMOR_LEATHER,
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
}

# 포션 색상별 스프라이트 (플레이어가 보는 것)
const COLOR_ATLAS: Array = [
	Vector2i(3, 8),  # 빨강
	Vector2i(4, 8),  # 파랑
	Vector2i(4, 9),  # 초록
	Vector2i(3, 9),  # 노랑
	Vector2i(4, 8),  # 보라 (파랑 베이스 + modulate)
	Vector2i(3, 8),  # 흰색 (빨강 베이스 + modulate)
]
const POTION_MODULATE: Array = [
	Color(1.0, 1.0, 1.0),        # 빨강
	Color(1.0, 1.0, 1.0),        # 파랑
	Color(1.0, 1.0, 1.0),        # 초록
	Color(1.0, 1.0, 1.0),        # 노랑
	Color(0.65, 0.2, 0.9),       # 보라
	Color(0.95, 0.95, 0.98),     # 흰색
]
const FOOD_ATLAS        := Vector2i(6, 9)
const COOKED_FOOD_ATLAS := Vector2i(7, 8)
const FOOD_ROTTEN_ATLAS := Vector2i(6, 9)   # 상한 식량은 같은 스프라이트에 modulate 적용
const SCROLL_ATLAS      := Vector2i(0, 8)   # 모든 주문서 공통 아이콘
const ANCIENT_SCROLL_ATLAS := Vector2i(0, 8)
const ANCIENT_SCROLL_TYPES: Array = [
	Type.ANCIENT_SCROLL_MAGIC_MISSILE,
	Type.ANCIENT_SCROLL_NATURE_LIGHTNING,
	Type.ANCIENT_SCROLL_REGENERATION,
	Type.ANCIENT_SCROLL_BARK_ARMOR,
	Type.ANCIENT_SCROLL_DISPEL,
]
const RAW_MEAT_ATLAS    := Vector2i(7, 9)
const COLORS := ["빨간색", "파란색", "초록색", "노란색", "보라색", "흰색"]
const SCROLL_NAMES := ["강타 주문서", "순간이동 주문서", "식별 주문서", "저주 해제 주문서"]
# 주문서 타입 → 식별 인덱스 (potions 6개 다음 4개)
const SCROLL_TYPES: Array = [Type.SCROLL_BASH, Type.SCROLL_TELEPORT, Type.SCROLL_IDENTIFY, Type.SCROLL_REMOVE_CURSE]

# 장비 정의: [이름, ATK보너스, DEF보너스, 내구도, atlas]
const EQUIPMENT_DATA := {
	Type.WEAPON_WOOD:    ["목검",     2, 0,  15, Vector2i(0, 3)],
	Type.WEAPON_STONE:   ["돌창",     3, 0,  20, Vector2i(1, 3)],
	Type.WEAPON_IRON:    ["철검",     6, 0,  30, Vector2i(2, 3)],
	Type.SHIELD_WOOD:    ["나무 방패", 0, 1, 12, Vector2i(3, 3)],
	Type.SHIELD_IRON:    ["철 방패",  0, 3,  25, Vector2i(4, 3)],
	Type.ARMOR_CLOTH:       ["천 갑옷",  0, 2,  15, Vector2i(5, 3)],
	Type.ARMOR_LEATHER:     ["가죽 갑옷", 0, 4, 25, Vector2i(6, 3)],
	Type.WEAPON_SHORTSWORD: ["숏소드",  4, 0,  20, Vector2i(2, 3)],
	Type.WEAPON_STAFF:      ["지팡이",  2, 0,  18, Vector2i(0, 3)],
	Type.WEAPON_DAGGER:     ["단검",    3, 0,  15, Vector2i(1, 3)],
}

# 제작 레시피: [결과타입, 결과내구도, [[재료타입, 개수], ...]]
const RECIPES: Array = [
	[Type.WEAPON_WOOD,    15, [[Type.MATERIAL_BRANCH, 2]]],
	[Type.SHIELD_WOOD,    12, [[Type.MATERIAL_BRANCH, 3]]],
	[Type.WEAPON_STONE,   20, [[Type.MATERIAL_STONE,  2]]],
	[Type.ARMOR_CLOTH,    15, [[Type.MATERIAL_HERB,   2]]],
	[Type.POTION_HEAL,     0, [[Type.MATERIAL_HERB,   1], [Type.MATERIAL_STONE, 1]]],
	[Type.SCROLL_ENHANCE,  0, [[Type.MATERIAL_HERB,   2], [Type.MATERIAL_BRANCH, 1]]],
	[Type.MATERIAL_TORCH,  0, [[Type.MATERIAL_BRANCH, 1], [Type.MATERIAL_CLOTH, 1]]],
	[Type.TOOL_REPAIR,     0, [[Type.MATERIAL_ORE, 1]]],
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
		Type.MATERIAL_HERO_STONE:             return "영웅의 돌"
	return "?"

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
var freshness_turns: int = 0   # 음식 신선도 (0 = 신선, 최대 이후 상함)

func is_equipment() -> bool:
	return item_type >= Type.WEAPON_WOOD and item_type <= Type.ARMOR_LEATHER

func is_material() -> bool:
	return (item_type >= Type.MATERIAL_BRANCH and item_type <= Type.MATERIAL_HERB_GARLIC) \
		or item_type in [Type.MATERIAL_DART, Type.MATERIAL_ARROW_WOOD, Type.MATERIAL_HERO_STONE]

func is_weapon() -> bool:
	return item_type in [Type.WEAPON_WOOD, Type.WEAPON_STONE, Type.WEAPON_IRON,
		Type.WEAPON_SHORTSWORD, Type.WEAPON_STAFF, Type.WEAPON_DAGGER]

func is_shield() -> bool:
	return item_type in [Type.SHIELD_WOOD, Type.SHIELD_IRON]

func is_armor() -> bool:
	return item_type in [Type.ARMOR_CLOTH, Type.ARMOR_LEATHER]

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

func is_food() -> bool:
	return item_type in [Type.FOOD, Type.COOKED_FOOD, Type.FOOD_ROTTEN, Type.BURNED_FOOD]

func get_equip_atk() -> int:
	if not is_equipment() or not EQUIPMENT_DATA.has(item_type):
		return 0
	var ratio: float = float(max(0, durability)) / float(max(1, max_durability))
	var total: int = EQUIPMENT_DATA[item_type][1] + (enhance_level if is_weapon() else 0)
	if is_blessed:
		total += 1
	elif is_cursed:
		total = max(0, total - 1)
	return total if ratio > 0 else (total / 2)

func get_equip_def() -> int:
	if not is_equipment() or not EQUIPMENT_DATA.has(item_type):
		return 0
	var ratio: float = float(max(0, durability)) / float(max(1, max_durability))
	var total: int = EQUIPMENT_DATA[item_type][2] + (enhance_level if not is_weapon() else 0)
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
		return "%s%s [%d/%d]%s" % [d[0], enh, durability, max_durability, suffix]
	match item_type:
		Type.FOOD:             return "식량"
		Type.COOKED_FOOD:      return "익은 식량"
		Type.FOOD_ROTTEN:      return "상한 식량"
		Type.BURNED_FOOD:      return "탄 식량"
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
		Type.POTION_HEAL:   return "회복 물약"
		Type.POTION_HUNGER: return "포만 물약"
		Type.POTION_POISON: return "독 물약"
		Type.POTION_FIRE:   return "화염 물약"
		Type.POTION_CLEANSE: return "정화 물약"
		Type.POTION_SLEEP:   return "수면 물약"
	return "식량"

func get_reveal_text() -> String:
	if is_scroll():
		return "낡은 주문서의 정체가 밝혀졌다! → %s" % get_display_name(true)
	return "%s 물약은 %s이었다!" % [COLORS[color_idx], _true_name()]

# 독/불/수면은 던질 때 즉시 공개, 주문서(강화 제외)도 던질 때 공개
func reveals_on_throw() -> bool:
	return item_type in [Type.POTION_POISON, Type.POTION_FIRE, Type.POTION_SLEEP] \
		or item_type in [Type.SCROLL_BASH, Type.SCROLL_TELEPORT, Type.SCROLL_IDENTIFY, Type.SCROLL_REMOVE_CURSE]

func get_stat_label() -> String:
	if not is_equipment() or not EQUIPMENT_DATA.has(item_type):
		return ""
	var atk_bonus: int = EQUIPMENT_DATA[item_type][1] + (enhance_level if is_weapon() else 0)
	var def_bonus: int = EQUIPMENT_DATA[item_type][2] + (enhance_level if not is_weapon() else 0)
	if atk_bonus > 0:
		return "ATK +%d" % atk_bonus
	if def_bonus > 0:
		return "DEF +%d" % def_bonus
	return ""

func get_modulate() -> Color:
	if is_equipment():
		return Color(1.0, 0.85, 0.6) if is_blessed else (Color(0.65, 0.5, 0.8) if is_cursed else Color.WHITE)
	if item_type == Type.FOOD or item_type == Type.COOKED_FOOD:
		return Color.WHITE
	if item_type == Type.FOOD_ROTTEN:
		return Color(0.55, 0.75, 0.4)
	if item_type == Type.BURNED_FOOD:
		return Color(0.35, 0.25, 0.15)
	if is_ancient_scroll():
		return Color(1.0, 0.85, 0.4)
	if is_scroll():
		return Color(0.85, 0.95, 1.0)
	return POTION_MODULATE[color_idx]

func get_atlas() -> Vector2i:
	if is_equipment() and EQUIPMENT_DATA.has(item_type):
		return EQUIPMENT_DATA[item_type][4]
	match item_type:
		Type.FOOD:             return FOOD_ATLAS
		Type.COOKED_FOOD:      return COOKED_FOOD_ATLAS
		Type.FOOD_ROTTEN:      return FOOD_ROTTEN_ATLAS
		Type.BURNED_FOOD:      return COOKED_FOOD_ATLAS
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
			var heal: int = 15 if is_blessed else 10
			player.hp = min(player.max_hp, player.hp + heal) as int
			if is_blessed:
				player.regen_turns = max(player.regen_turns, 5)
			player.stats_changed.emit()
			return "HP +%d 회복%s" % [heal, " + 재생 [축복]" if is_blessed else ""]
		Type.POTION_HUNGER:
			var reduce: int = 80 if is_blessed else 50
			player.hunger = max(0, player.hunger - reduce) as int
			player.stats_changed.emit()
			return "배고픔 -%d%s" % [reduce, " [축복]" if is_blessed else ""]
		Type.POTION_POISON:
			if is_blessed:
				var heal: int = 10
				player.hp = min(player.max_hp, player.hp + heal) as int
				player.stats_changed.emit()
				return "축복 독 물약! 독 대신 HP +%d [축복]" % heal
			player.apply_status("poison", POISON_TURNS)
			player.stats_changed.emit()
			return "독 상태이상! (%d턴)" % POISON_TURNS
		Type.POTION_FIRE:
			if is_blessed:
				var mp_gain: int = 20
				player.mp = min(player.max_mp, player.mp + mp_gain) as int
				player.stats_changed.emit()
				return "축복 화염 물약! 화염 대신 MP +%d [축복]" % mp_gain
			player.apply_status("fire", FIRE_TURNS)
			player.stats_changed.emit()
			return "화상 상태이상! (%d턴)" % FIRE_TURNS
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
			player.stats_changed.emit()
			return "수면 상태이상! (%d턴)" % SLEEP_TURNS
		Type.FOOD:
			var reduce: int = 75 if is_blessed else 50
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
			player.hunger = max(0, player.hunger - 40)
			player.stats_changed.emit()
			return "익은 식량 섭취! 배고픔 -40"
		Type.FOOD_ROTTEN:
			player.hunger = max(0, player.hunger - 15)
			player.apply_status("poison", POISON_TURNS)
			player.stats_changed.emit()
			return "상한 식량 섭취! 배고픔 -15, 독 상태이상!"
		Type.BURNED_FOOD:
			player.hunger = max(0, player.hunger - 25)
			player.stats_changed.emit()
			return "탄 식량 섭취! 배고픔 -25"
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
