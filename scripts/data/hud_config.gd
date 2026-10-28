class_name HudConfig
extends Resource
## Ingame-Anzeigen (Phase 15, Paket 4): HP-Leisten unter normalen Gegnern und Tier-Kontur der schwebenden Waffen.

## Höhe der HP-Leiste unter normalen Gegnern (px).
@export var enemy_bar_height: float = 5.0
## Breite = Kollisionsdurchmesser x Faktor, begrenzt auf min/max.
@export var enemy_bar_width_factor: float = 1.6
@export var enemy_bar_min_width: float = 28.0
@export var enemy_bar_max_width: float = 72.0
## Abstand unter den Füßen des Gegners (px).
@export var enemy_bar_gap: float = 6.0
@export var enemy_bar_outline: float = 1.0
@export var enemy_bar_fill: Color = Color("#E74C3C")
@export var enemy_bar_background: Color = Color("#0F0F16CC")
@export var enemy_bar_outline_color: Color = Color("#2A1E2E")
## Kontur der schwebenden Waffen in Tier-Farbe (Pixel der Waffentextur).
@export var weapon_outline_width: float = 2.5
## Deckkraft der Kontur (dezent, aber bei 100 Gegnern erkennbar).
@export_range(0.0, 1.0) var weapon_outline_alpha: float = 0.9
## Effekt-Anzeigen im HUD (Reservebatterie, Kondensator): Icongröße und Deckkraft, wenn verbraucht.
@export var effect_icon_size: float = 44.0
@export_range(0.0, 1.0) var effect_used_alpha: float = 0.3
@export var effect_bar_height: float = 10.0
@export var effect_ready_color: Color = Color("#F5A623")
@export var effect_charge_color: Color = Color("#8FE3FF")
## "Gerettet!" (tödlicher Treffer abgefangen): Textfarbe, Schriftgröße, Ring um den Spieler, Screenshake.
@export var rescue_text_color: Color = Color("#F5A623")
@export var rescue_text_size: int = 40
@export var rescue_pulse_radius: float = 180.0
@export var rescue_trauma: float = 0.35
