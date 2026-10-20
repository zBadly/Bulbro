class_name PlayerConfig
extends Resource
## Basiswerte des Spielers (GDD Abschnitt 4). Werte stehen in res://data/config/player_config.tres.

@export var base_stats: StatBlock
@export var base_move_speed: float = 0.0
@export var weapon_slots: int = 0
## Startwaffen, bis die Charakterauswahl existiert.
@export var starting_weapons: Array[WeaponData] = []
@export var weapon_orbit_radius: float = 0.0
@export var pickup_radius: float = 0.0
@export var invulnerability_time: float = 0.0
## Obergrenze für Ausweichen in %. Charaktere können sie später anheben.
@export var dodge_cap: float = 0.0
@export var max_hp_per_level: float = 0.0
@export var collision_radius: float = 0.0

@export_group("Licht")
@export var light_color: Color = Color.WHITE
@export var light_energy: float = 0.0
@export var light_texture_scale: float = 0.0
