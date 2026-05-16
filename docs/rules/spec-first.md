# 스펙 우선 원칙

**기능 구현 전 반드시 해당 스펙 문서를 먼저 읽고 업데이트한다.**  
**기능 구현 완료 후에도 구현 현황 체크리스트를 즉시 반영한다.**

- 스펙 문서 위치: `docs/specs/`
- 구현 시작 전 → 관련 스펙 파일을 Read 도구로 반드시 로드할 것 (기억에만 의존 금지)
- 대화 중 기능/동작/수치가 결정되면 → 스펙 문서에 즉시 반영 → 그 다음 코드 작성
- 구현 완료 시 → 해당 스펙의 `## 구현 현황` 체크리스트 `[ ]` → `[x]` 로 업데이트
- 스펙 없이 코드만 짜지 말 것. 스펙 문서가 진실의 원천(source of truth)

스펙 파일 목록:
- `docs/specs/00-input-system.md` — 입력 시스템
- `docs/specs/01-floor-transition.md` — 층 전환
- `docs/specs/01-map-generation.md` — 맵 생성 & 오브젝트 (샘/해골더미/제단/약초밭/함정 확장 포함)
- `docs/specs/02-monster-combat.md` — 몬스터 & 전투
- `docs/specs/03-item-system.md` — 아이템 시스템
- `docs/specs/04-stats-gauges.md` — 스탯 & 게이지 (AP 시스템, 추가 상태이상 포함)
- `docs/specs/05-crafting.md` — 제작 시스템
- `docs/specs/06-gold-merchant.md` — 골드 & 상점
- `docs/specs/07-home-exploration-xp.md` — 홈 탐험 & XP 마일스톤
- `docs/specs/08-memory-rune.md` — 기억의 상자 & 룬 시스템 (메타 진행)
- `docs/specs/09-class-system.md` — 직업 시스템 (전사/마법사/도적/사냥꾼)
- `docs/specs/10-magic-system.md` — 마법 시스템 (고대 주문서 & 무기 스킬)
