extends Control

var hp := 20
var max_hp := 20
var hunger := 100
var floor_num := 1

func update_stats(p_hp: int, p_max_hp: int, p_hunger: int, p_floor: int) -> void:
	hp = p_hp
	max_hp = p_max_hp
	hunger = p_hunger
	floor_num = p_floor
	queue_redraw()

func _draw() -> void:
	var bar_w := 160
	var bar_h := 14
	var pad := 12

	draw_rect(Rect2(0, 0, 480, 44), Color(0, 0, 0, 0.6))

	# HP 바
	draw_rect(Rect2(pad, pad, bar_w, bar_h), Color("#400000"))
	draw_rect(Rect2(pad, pad, bar_w * hp / max_hp, bar_h), Color("#e03030"))
	draw_string(ThemeDB.fallback_font, Vector2(pad + 4, pad + bar_h - 2), "HP %d/%d" % [hp, max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

	# 배고픔 바
	var hx := pad + bar_w + 16
	draw_rect(Rect2(hx, pad, bar_w, bar_h), Color("#403000"))
	draw_rect(Rect2(hx, pad, bar_w * hunger / 100.0, bar_h), Color("#e0a030"))
	draw_string(ThemeDB.fallback_font, Vector2(hx + 4, pad + bar_h - 2), "배고픔 %d" % hunger, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

	# 층 표시
	draw_string(ThemeDB.fallback_font, Vector2(480 - pad, pad + bar_h - 2), "%d층" % floor_num, HORIZONTAL_ALIGNMENT_RIGHT, -1, 13, Color.WHITE)
