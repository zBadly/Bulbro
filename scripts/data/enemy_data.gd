class_name EnemyData
extends Resource
## Definition eines Gegnertyps (GDD Abschnitt 11). HP und Schaden wachsen linear ab Welle 2.

@export var id: StringName
@export var name_key: String = ""
@export var texture: Texture2D
@export var collision_radius: float = 0.0

@export_group("Werte")
@export var base_hp: float = 0.0
@export var hp_per_wave: float = 0.0
@export var base_damage: float = 0.0
@export var damage_per_wave: float = 0.0
## Tempo wird pro Spawn zufällig zwischen min und max gewählt (px/s).
@export var speed_min: float = 0.0
@export var speed_max: float = 0.0
## 0 = voller Rückstoß, 1 = unbeweglich.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0

@export_group("Verhalten")
@export var behavior: BehaviorData

## Projektilschaden (0 = wie Kontaktschaden).
@export var projectile_damage_base: float = 0.0
@export var projectile_damage_per_wave: float = 0.0

@export_group("Beute")
@export var sparks: int = 0
@export var guaranteed_crate: bool = false
## Elites und Bosse lassen einen legendären Karton (garantiert Tier IV) fallen.
@export var legendary_crate: bool = false

@export_group("Regeln")
## Darf beim Überschreiten des Gegnerlimits verschwinden (nur normale Gegner).
@export var despawnable: bool = true
@export var is_elite: bool = false
@export var is_boss: bool = false
## Beim Tod freigesetzte Gegner (Brutsack -> Rußschützen).
@export var death_spawn: EnemyData
@export var death_spawn_count: int = 0


func hp_for_wave(wave: int) -> float:
	return base_hp + hp_per_wave * maxi(0, wave - 1)


func damage_for_wave(wave: int) -> float:
	return base_damage + damage_per_wave * maxi(0, wave - 1)


func projectile_damage_for_wave(wave: int) -> float:
	if projectile_damage_base <= 0.0:
		return damage_for_wave(wave)
	return projectile_damage_base + projectile_damage_per_wave * maxi(0, wave - 1)
