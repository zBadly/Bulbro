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
## Zeit zwischen Wellenende (Banner, Pop der Gegner) und den Bildschirmen für Kartons/Level-ups/Shop.
@export var intermission_time: float = 0.0
## Verzögerung zwischen Tod des Spielers und Game-Over-Bildschirm (Tod-Animation).
@export var game_over_delay: float = 0.0
## Start-Poolgröße pro Gegnertyp.
@export var enemy_pool_size: int = 0
@export var enemy_projectile_pool_size: int = 0
@export var spawn_marker_pool_size: int = 0

@export_group("Endlos-Modus")
## Vorlage für Endloswellen (Gegnergruppen) und deren Dauer.
@export var endless_template_wave: int = 0
@export var endless_wave_duration: float = 0.0
## Zuwachs pro Endloswelle (mit Zinseszins) auf Gegner-HP, -Schaden und -Tempo.
@export var endless_hp_growth: float = 0.0
@export var endless_damage_growth: float = 0.0
@export var endless_speed_growth: float = 0.0
## Obergrenze für den Tempo-Zuwachs (z. B. 0,6 = höchstens +60 %).
@export var endless_speed_max: float = 0.0
## Aufladung zahlt im Endlos-Modus nur diesen Anteil aus.
@export var endless_harvest_factor: float = 1.0
