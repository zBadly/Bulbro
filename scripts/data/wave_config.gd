class_name WaveConfig
extends Resource
## Allgemeine Wellen- und Spawnregeln. Werte stehen in res://data/config/wave_config.tres.

@export var max_enemies: int = 0
@export var spawn_warning_time: float = 0.0
@export var min_player_distance: float = 0.0
## Abstand der Spawnpunkte zum Arenarand.
@export var spawn_margin: float = 0.0
## Radius, in dem die Mitglieder einer Gruppe um den Gruppenmittelpunkt erscheinen.
@export var group_radius: float = 0.0
@export var spawn_position_attempts: int = 0
## Pause zwischen zwei Wellen (bis der Shop existiert).
@export var intermission_time: float = 0.0
## Verzögerung zwischen Tod des Spielers und Game-Over-Bildschirm (Tod-Animation).
@export var game_over_delay: float = 0.0
## Start-Poolgröße pro Gegnertyp.
@export var enemy_pool_size: int = 0
@export var enemy_projectile_pool_size: int = 0
@export var spawn_marker_pool_size: int = 0
