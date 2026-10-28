class_name BossPhaseConfig
extends Resource
## Sichtbare Boss-/Elite-Phasen (Phase 15, Paket 7): Phasenwechsel, HP-Leisten mit Markierungen, "Immun".
## Werte in res://data/config/boss_phase_config.tres; Namen und Aura-Farben je Phase in BossPhaseData.

@export_group("Phasenwechsel")
## Unverwundbarkeit des Gegners direkt nach dem Wechsel (s).
@export var invulnerable_time: float = 0.0
## Schimmern während der Unverwundbarkeit: so oft blitzt der Gegner auf (pro Sekunde), mit dieser Stärke.
@export var shimmer_rate: float = 0.0
@export_range(0.0, 1.0) var shimmer_strength: float = 0.0
## Screenshake (Trauma 0..1) beim Wechsel; respektiert die Option "Screenshake".
@export var boss_trauma: float = 0.0
@export var elite_trauma: float = 0.0
## Kontur-Breite der Phasen-Aura (px der Textur).
@export var aura_width: float = 0.0

@export_group("Banner")
## Text "Phase 2: Raserei" in der Bildmitte; Elites bekommen eine kleinere, kürzere Variante.
@export var boss_banner_size: int = 0
@export var elite_banner_size: int = 0
@export var boss_banner_time: float = 0.0
@export var elite_banner_time: float = 0.0
## Sprung beim Erscheinen: Startgröße und Dauer.
@export var banner_pop_scale: float = 1.0
@export var banner_pop_time: float = 0.0
## Abstand des Banners über der Bildmitte (damit es die Wellen-Banner nicht überdeckt).
@export var banner_offset_y: float = 0.0

@export_group("Immun-Anzeige")
## Graues "Immun" statt Schadenszahl, höchstens einmal je Intervall und Gegner.
@export var immune_text_interval: float = 0.0
@export var immune_text_color: Color = Color.GRAY

@export_group("HP-Leiste")
## Normal (ein Balken) und kompakt (ab compact_from Balken gleichzeitig, z. B. zwei Bosse).
@export var bar_size: Vector2 = Vector2.ZERO
@export var compact_bar_size: Vector2 = Vector2.ZERO
@export var name_size: int = 0
@export var compact_name_size: int = 0
@export var compact_from: int = 2
## Markierung an jeder HP-Schwelle: Breite, Überstand über den Balken; erreichte Schwellen blasser.
@export var marker_width: float = 0.0
@export var marker_overhang: float = 0.0
@export var marker_color: Color = Color.WHITE
@export var marker_passed_color: Color = Color.WHITE
## Uhr-Symbol vor dem Timer bis zum Zeitwechsel (Höhe relativ zur Schriftgröße).
@export var clock_scale: float = 1.0
## Aufblitzen des Balkens beim Wechsel: Helligkeit (Modulate-Faktor) und Dauer (s).
@export var bar_flash_brightness: float = 1.0
@export var bar_flash_time: float = 0.0
