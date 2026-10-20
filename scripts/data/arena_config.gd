class_name ArenaConfig
extends Resource
## Arena und Kamera (GDD Abschnitt 3). Werte stehen in res://data/config/arena_config.tres.

@export var size: Vector2 = Vector2.ZERO
@export var border_width: float = 0.0
@export var border_color: Color = Color.WHITE
@export var camera_smoothing_speed: float = 0.0
## Wie weit die Kamera über den Arenarand hinaus zeigen darf.
@export var camera_margin: float = 0.0
@export var camera_zoom: float = 1.0
## Abdunklung der Szene (CanvasModulate), wenn Licht in den Optionen aktiv ist.
@export var darkness_color: Color = Color.WHITE


func get_rect() -> Rect2:
	return Rect2(-size * 0.5, size)
