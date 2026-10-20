class_name DropConfig
extends Resource
## Drops, Pickups, Leuchtkristalle und Funkendieb (GDD Abschnitt 6). Werte in res://data/config/drop_config.tres.

@export_group("Verbrauchsgegenstände")
## Grundchance pro Kill, dass ein Verbrauchsgegenstand fällt (Batterie oder Karton).
@export var consumable_base_chance: float = 0.0
## Grundchance, dass ein gefallener Verbrauchsgegenstand ein Karton ist.
@export var crate_base_chance: float = 0.0
@export var battery_heal: float = 0.0
@export var crate_heal: float = 0.0

@export_group("Pickups")
@export var spark_texture: Texture2D
@export var battery_texture: Texture2D
@export var crate_texture: Texture2D
## Verbrauchsgegenstände werden nur in diesem kleinen Radius angezogen.
@export var consumable_pickup_radius: float = 0.0
@export var collect_distance: float = 0.0
@export var magnet_start_speed: float = 0.0
@export var magnet_acceleration: float = 0.0
@export var magnet_max_speed: float = 0.0
@export var scatter_radius: float = 0.0
@export var scatter_time: float = 0.0
@export var pickup_pool_size: int = 0

@export_group("Leuchtkristall")
@export var crystal_first_spawn: float = 0.0
@export var crystal_spawn_interval: float = 0.0
@export var crystal_spawn_chance: float = 0.0
@export var crystal_max_count: int = 0
@export var crystal_base_hp: float = 0.0
@export var crystal_hp_per_wave: float = 0.0
@export var crystal_max_hits: int = 0
@export var crystal_sparks: int = 0
## Anteil der garantierten Verbrauchsgegenstände, die Kartons sind.
@export var crystal_crate_share: float = 0.0

@export_group("Funkendieb")
@export var thief: EnemyData
@export var thief_first_wave: int = 0
@export var thief_first_check: float = 0.0
@export var thief_check_interval: float = 0.0
@export var thief_chance: float = 0.0
