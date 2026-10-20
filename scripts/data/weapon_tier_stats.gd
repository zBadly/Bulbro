class_name WeaponTierStats
extends Resource
## Werte einer Waffe in einem Tier (I-IV).

@export var base_damage: float = 0.0
## Stat -> Anteil, z. B. {melee_dmg: 1.0} für "100 % Nah".
@export var scalings: Dictionary[StringName, float] = {}
@export var cooldown: float = 0.0
@export var range: float = 0.0
## Krit-Chance der Waffe 0..1; der Krit-Stat wird addiert.
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 0.0
@export var knockback: float = 0.0
@export var piercing: int = 0
@export var bounces: int = 0
@export var projectile_count: int = 1
## Fächer bei mehreren Projektilen, sonst zufällige Streuung (in Grad).
@export var spread_deg: float = 0.0
@export var price: int = 0
