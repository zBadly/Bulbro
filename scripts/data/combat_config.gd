class_name CombatConfig
extends Resource
## Allgemeine Kampf- und Effektwerte. Werte stehen in res://data/config/combat_config.tres.

@export_group("Rückstoß")
## Umrechnung Rückstoß-Wert der Waffe -> Anfangsgeschwindigkeit in px/s.
@export var knockback_to_speed: float = 0.0
## Abbremsen des Rückstoßes in px/s².
@export var knockback_friction: float = 0.0

@export_group("Waffen")
@export var target_refresh_interval: float = 0.0
@export var melee_hitbox_radius: float = 0.0
@export var melee_attack_time_base: float = 0.0
## Zusätzliche Angriffsdauer pro px Reichweite ("höhere Reichweite verlangsamt leicht").
@export var melee_attack_time_per_range: float = 0.0
## Höchstens dieser Anteil der Abklingzeit darf für die Angriffsanimation verwendet werden.
@export var melee_max_cooldown_share: float = 0.0
@export var swing_arc_deg: float = 0.0
@export var muzzle_offset: float = 0.0
@export var recoil_distance: float = 0.0
@export var recoil_time: float = 0.0

@export_group("Pools")
@export var projectile_pool_size: int = 0
@export var damage_number_pool_size: int = 0

@export_group("Schadenszahlen")
@export var damage_number_color: Color = Color.WHITE
@export var damage_number_crit_color: Color = Color.WHITE
@export var damage_number_outline_color: Color = Color.BLACK
@export var damage_number_font_size: int = 0
@export var damage_number_crit_font_size: int = 0
@export var damage_number_outline_size: int = 0
@export var damage_number_rise: float = 0.0
@export var damage_number_time: float = 0.0
@export var damage_number_jitter: float = 0.0
@export var damage_number_z_index: int = 0

@export_group("Trainings-Dummy")
@export var dummy_return_speed: float = 0.0
@export var dummy_dps_window: float = 0.0
