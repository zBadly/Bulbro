class_name ShopConfig
extends Resource
## Shop-, Reroll- und Recycle-Werte (GDD 5-7). Werte in res://data/config/shop_config.tres.

@export var offer_count: int = 0
## Wahrscheinlichkeit, dass ein Angebot eine Waffe statt eines Items ist.
@export var weapon_offer_chance: float = 0.0
## Anteil der Waffenangebote, die zu einer Klasse passen, die der Spieler besitzt.
@export var class_bias_chance: float = 0.0
## Reroll-Zuschlag = max(1, Welle x Faktor).
@export var reroll_increment_factor: float = 0.0
## Anteil des Preises beim Recyceln von Items und Waffen.
@export var recycle_share: float = 0.0
## Gewichtungsfaktor für Items mit bevorzugten Tags des Charakters.
@export var preferred_tag_weight: float = 0.0
@export var upgrade_card_count: int = 0
## Einzigartige Items: Chance je neu gezogenem Angebotsplatz, frühestens ab dieser Welle, höchstens eins pro Angebot.
@export var unique_min_wave: int = 0
@export var unique_chance: float = 0.0
## Glück erhöht die Chance leicht: x (1 + Glück / 100 x Faktor), gedeckelt.
@export var unique_luck_factor: float = 0.0
@export var unique_max_chance: float = 0.0
