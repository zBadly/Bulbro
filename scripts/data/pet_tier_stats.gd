class_name PetTierStats
extends Resource
## Werte eines Begleiters in einem Tier (I-IV). Welche Felder zählen, entscheidet das PetBehavior der PetData.

@export var base_damage: float = 0.0
## Stat -> Anteil, z. B. {ranged_dmg: 0.5} für "+50 % Fern".
@export var scalings: Dictionary[StringName, float] = {}
## Abklingzeit zwischen zwei Aktionen (Schuss, Block, Rammstoß) in Sekunden.
@export var cooldown: float = 0.0
## Reichweite: Schussweite oder wie weit der Begleiter sich vom Spieler entfernt.
@export var range: float = 0.0
## Wirkradius (Funken einsammeln, Projektile blocken).
@export var radius: float = 0.0
## Schadensfaktor einer kopierten Waffe (Mini-Birne).
@export var damage_factor: float = 0.0
@export var knockback: float = 0.0
@export var price: int = 0
