class_name Arena
extends Node2D
## Rechteckige Arena mit kachelbarem Boden, sichtbarem Rand und Kamera, die dem Spieler folgt.

const LIGHTING_SECTION: String = "options"
const LIGHTING_KEY: String = "lighting"

@export var config: ArenaConfig

@onready var _floor: Sprite2D = $Floor
@onready var _darkness: CanvasModulate = $Darkness
@onready var _camera: Camera2D = $Camera
@onready var player: Player = $Entities/Player


func _ready() -> void:
	GameState.start_run()
	var rect: Rect2 = config.get_rect()
	_floor.region_rect = Rect2(Vector2.ZERO, config.size)
	_floor.position = rect.get_center()
	player.arena_bounds = rect

	var lighting: bool = SaveManager.get_value(LIGHTING_SECTION, LIGHTING_KEY, true)
	_darkness.color = config.darkness_color
	_darkness.visible = lighting

	_camera.zoom = Vector2.ONE * config.camera_zoom
	_camera.position_smoothing_speed = config.camera_smoothing_speed
	_camera.limit_left = floori(rect.position.x - config.camera_margin)
	_camera.limit_top = floori(rect.position.y - config.camera_margin)
	_camera.limit_right = ceili(rect.end.x + config.camera_margin)
	_camera.limit_bottom = ceili(rect.end.y + config.camera_margin)
	_camera.global_position = player.global_position
	_camera.reset_smoothing()
	queue_redraw()


func _process(_delta: float) -> void:
	_camera.global_position = player.global_position


func _draw() -> void:
	draw_rect(config.get_rect(), config.border_color, false, config.border_width)
