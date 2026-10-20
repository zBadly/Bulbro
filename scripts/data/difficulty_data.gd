class_name DifficultyData
extends Resource
## Spannungsstufe 0-5 (GDD 2): Gegnerwerte und Sonderwellen.

@export var level: int = 0
@export var name_key: String = ""
@export var description_key: String = ""
## Aufschlag auf HP und Schaden aller Gegner in % (bis +40 %).
@export var enemy_hp_pct: float = 0.0
@export var enemy_damage_pct: float = 0.0
## Wellenpaare, in denen eine Elite- oder Hordewelle kommt (z. B. [11, 12]); je Paar eine zufällige Welle.
@export var special_wave_pairs: Array[Vector2i] = []
## Die letzte Sonderwelle ist immer eine Elite-Welle.
@export var last_special_is_elite: bool = false
@export_range(0.0, 1.0) var horde_chance: float = 0.0
## Ab dieser Spannung tauchen zusätzliche Gegnertypen auf (Flackerer ab 1).
@export var extra_enemy_types: bool = false
## Bei Welle 20 beide Bosse gleichzeitig (mit reduzierten HP).
@export var double_boss: bool = false
