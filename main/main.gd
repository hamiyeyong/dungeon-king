extends Node2D

@onready var map = $Map
@onready var player = $Player
@onready var hud = $HUD/Overlay
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	map.generate()
	var start: Vector2i = map.get_start_pos()
	player.init(start, map)
	player.stats_changed.connect(_on_player_stats_changed)
	camera.position = player.position
	_refresh_hud()

func _process(_delta: float) -> void:
	camera.position = camera.position.lerp(player.position, 0.15)

func _on_player_stats_changed() -> void:
	_refresh_hud()

func _refresh_hud() -> void:
	hud.update_stats(player.hp, player.max_hp, player.hunger, player.floor_num)
