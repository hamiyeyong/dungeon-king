# 프로젝트 개요

- 엔진: Godot 4.6.2
- 장르: 모바일 로그라이크 (턴제)
- 해상도: 854×480 landscape
- 언어: GDScript

## 씬 구조

```
Main (Node2D)
  ├─ Map
  ├─ Player
  ├─ EnemyManager
  │    └─ Enemy (x N)
  ├─ HUD (CanvasLayer)
  │    └─ Overlay (Control)
  ├─ Camera2D
  └─ FadeLayer (CanvasLayer layer=10)
       └─ FadeRect (ColorRect)
```
