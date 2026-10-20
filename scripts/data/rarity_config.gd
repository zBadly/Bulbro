class_name RarityConfig
extends Resource
## Seltenheit von Shop-Angeboten, Kartons und Level-up-Karten (GDD 5 und 7).
## Index 0..3 = Tier I..IV. Chance(Tier) = (Stufe - Freischaltung + 1) x Zuwachs, mit Glück multipliziert, gedeckelt.
## "Stufe" ist die Wellennummer (Shop, Kartons) bzw. das Level (Level-up).

@export var unlock: Array[int] = []
@export var step: Array[float] = []
@export var max_chance: Array[float] = []
## Garantierte Seltenheit bei Level-ups.
@export var guaranteed_tier_2_level: int = 0
@export var guaranteed_tier_3_levels: Array[int] = []
@export var guaranteed_tier_4_from_level: int = 0
@export var guaranteed_tier_4_every: int = 0
