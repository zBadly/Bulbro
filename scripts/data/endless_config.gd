class_name EndlessConfig
extends Resource
## Regeln des Endlos-Modus nach dem Sieg (Phase 15, Paket 6). Werte in res://data/config/endless_config.tres.
## "Endlos-Stufe" = Wellen seit dem Sieg (Welle 21 = Stufe 1). Rechnungen in EndlessRules.

@export_group("Wellen")
## Vorlage für normale Endloswellen (Gegnergruppen) und deren Dauer.
@export var template_wave: int = 0
@export var wave_duration: float = 0.0
## Vorlage für die Bosswellen (Begleitgegner und Dauer, in der Gruppen erscheinen).
@export var boss_template_wave: int = 0

@export_group("Wachstum pro Welle")
## Zuwachs pro Endloswelle (mit Zinseszins) auf Gegner-HP, -Schaden und -Tempo.
@export var hp_growth: float = 0.0
@export var damage_growth: float = 0.0
@export var speed_growth: float = 0.0
## Obergrenze für den Tempo-Zuwachs (z. B. 0,6 = höchstens +60 %).
@export var speed_max: float = 0.0
## Dichte: Gruppen erscheinen um diesen Zuwachs pro Welle häufiger (Zinseszins), höchstens density_max mehr.
## Das Gegnerlimit (WaveConfig.max_enemies) bleibt.
@export var density_growth: float = 0.0
@export var density_max: float = 0.0

@export_group("Aufladung")
## Aufladung zahlt in Endlos-Stufe 1 diesen Anteil aus, danach je Welle harvest_decay weniger, mindestens harvest_min.
@export var harvest_start: float = 1.0
@export var harvest_decay: float = 0.0
@export var harvest_min: float = 0.0

@export_group("Boss-Zyklen")
## Alle boss_cycle_waves Endloswellen erscheinen alle Bosse gleichzeitig (Stufe 10, 20 ... = Welle 30, 40 ...).
@export var boss_cycle_waves: int = 0
## Zusätzlich zum Endlos-Faktor: +x HP bzw. Schaden je Zyklus (linear; Zyklus 1 = Welle 30).
@export var boss_cycle_hp_bonus: float = 0.0
@export var boss_cycle_damage_bonus: float = 0.0
## Legendäre Kartons, die jeder Endlos-Boss fallen lässt.
@export var boss_legendary_crates: int = 0
## Dauer des Banners "Bosse besiegt!" (s).
@export var boss_banner_time: float = 0.0

@export_group("Sonderwellen")
## Welle im 10er-Block, die Elite- oder Hordewelle ist (5 = Welle 25, 35, 45 ...).
@export var special_wave_offset: int = 0
## Anteil Hordewellen (sonst Elite).
@export var horde_chance: float = 0.0
