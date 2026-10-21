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

@export_group("Besonderheiten")
## Brand (Überspannung): Schaden pro Tick und Anzahl Ticks.
@export var burn_damage: float = 0.0
@export var burn_ticks: int = 0
## Chance pro Treffer, dass der Brand zündet (1 = immer).
@export_range(0.0, 1.0) var burn_chance: float = 1.0
## Ketten-Blitz: springt nach dem Treffer auf so viele weitere Ziele.
@export var chain_count: int = 0
@export var chain_range: float = 0.0
## Explosion beim Treffer (Radius in px, 0 = keine).
@export var explosion_radius: float = 0.0
## Zielsuche: maximale Drehung in Grad pro Sekunde (0 = geradeaus).
@export var homing_turn_deg: float = 0.0
@export_range(0.0, 1.0) var heal_on_hit_chance: float = 0.0
@export_range(0.0, 1.0) var spark_on_kill_chance: float = 0.0
## Zusätzliche Seelen für das Seelenglas bei einem Kill mit dieser Waffe (Seelenlaterne).
@export var extra_souls: int = 0
## Festhalten beim Treffer (Dornenranke): Chance und Dauer in Sekunden.
@export_range(0.0, 1.0) var root_chance: float = 0.0
@export var root_duration: float = 0.0
## Zersplittern beim Treffer (Kristallstab): Anzahl Splitter und deren Schaden in % des Treffers.
@export var split_count: int = 0
@export var split_damage_pct: float = 0.0
