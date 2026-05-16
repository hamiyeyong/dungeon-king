# GDScript 코딩 규칙

## 타입 명시

`max()`, `abs()`, `sign()` 등 내장 함수와 타입 미지정 메서드의 반환값은 Variant — 반드시 `: int`, `: Vector2i`, `: String` 등으로 명시 선언.

```gdscript
# ❌ 오류
var dmg := max(1, amount - def_)

# ✅ 정상
var dmg: int = max(1, amount - def_)
```

비타입 Array(`Array`, `enemies`, `occupied` 등)를 순회할 때 element는 Variant로 추론된다.  
이 경우 element의 메서드 반환값도 추론 불가 — 반드시 명시 타입 선언 사용.

```gdscript
# ❌ 오류 — e 가 Variant 이므로 ai_step 반환값 추론 불가
var attacked := e.ai_step(player_pos, occupied)

# ✅ 정상
var attacked: bool = e.ai_step(player_pos, occupied)
```

근본 해결: `Array[Enemy]` 처럼 타입 파라미터를 지정하면 `:=` 추론이 동작한다.

```gdscript
var enemies: Array[Enemy] = []
# 이후 var attacked := e.ai_step(...) 가능
```

## 노드 참조

항상 `@onready var` 사용. `_ready()` 안에서 `get_node()` 직접 호출 금지.

```gdscript
# ❌
func _ready():
    var hp_bar = get_node("HUD/HPBar")

# ✅
@onready var hp_bar: ProgressBar = $HUD/HPBar
```

## 시그널 연결

코드에서 `connect()` 로 통일. 에디터 Inspector에서 연결 금지 (추적 불가).

```gdscript
# ✅
enemy.died.connect(_on_enemy_died)
```

## 노드 삭제

항상 `queue_free()` 사용. `free()` 직접 호출 금지 (참조 오류 위험).

## await 사용 기준

- `await` 는 애니메이션/트윈/타이머 완료 대기에만 사용
- 로직 흐름 제어 목적 남발 금지 (실행 순서 꼬임)

## draw_string 텍스트 정렬

`draw_string`의 `width` 파라미터 동작이 alignment에 따라 다르다.

**`width = -1` 이면 alignment 가 무시되고 항상 pos.x 에서 시작(LEFT처럼 동작)된다.**  
CENTER 정렬이 필요하면 반드시 양수 width 를 지정하고, pos.x 는 영역의 왼쪽 끝으로 설정한다.

```gdscript
# ❌ 오른쪽으로 쏠림 — width=-1 이면 CENTER 무시, pos.x 에서 시작
draw_string(font, Vector2(W * 0.5, y), text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, color)

# ❌ 오른쪽으로 쏠림 — width는 지정했지만 pos.x 가 영역 중앙
draw_string(font, Vector2(rect.position.x + rect.size.x * 0.5, y),
    text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)

# ✅ 올바른 중앙 정렬 — pos.x 는 영역 왼쪽 끝, width 는 영역 전체 폭
draw_string(font, Vector2(rect.position.x, y),
    text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)

# ✅ 화면 전체 기준 중앙 정렬
draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, W, size, color)
```

패딩을 주려면 `pos.x = rect.position.x + pad`, `width = rect.size.x - pad * 2` 조합을 사용한다.

## match 패턴 멀티라인 금지

`match` 문의 콤마 구분 패턴은 **반드시 한 줄**에 작성한다.  
GDScript 파서는 패턴 목록의 줄바꿈을 구문 종료로 인식하여 다음 줄을 별개 구문으로 파싱 → 파서 오류 발생.  
파서 오류가 생기면 해당 파일의 글로벌 클래스 전체가 무효화되어 이를 참조하는 **모든 파일에 연쇄 오류**가 발생한다.

```gdscript
# ❌ 오류 — 줄바꿈 때문에 파서가 각 줄을 독립 구문으로 인식
match item_type:
    Type.MATERIAL_HERB_ICE, Type.MATERIAL_HERB_BLOOD_MOSS,
    Type.MATERIAL_HERB_GINSENG, Type.MATERIAL_HERB_NIGHTSHADE:
        return Vector2i(6, 8)

# ✅ 한 줄로 나열
match item_type:
    Type.MATERIAL_HERB_ICE, Type.MATERIAL_HERB_BLOOD_MOSS, Type.MATERIAL_HERB_GINSENG, Type.MATERIAL_HERB_NIGHTSHADE:
        return Vector2i(6, 8)
```

항목이 너무 많으면 배열/Set으로 미리 정의해두고 `if item_type in HERB_TYPES:` 패턴을 사용한다.

```gdscript
const HERB_TYPES := [
    Type.MATERIAL_HERB_ICE,
    Type.MATERIAL_HERB_BLOOD_MOSS,
    Type.MATERIAL_HERB_GINSENG,
]

# match 대신 if 분기
if item_type in HERB_TYPES:
    return Vector2i(6, 8)
```
