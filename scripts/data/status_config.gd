class_name StatusConfig
extends Resource
## Gemeinsame Werte für Status-Effekte, Verbündete, Spiegelbild und Drohnen.
## Werte stehen in res://data/config/status_config.tres; effektspezifische Zahlen liegen in den Effekt-Resources.

@export_group("Status auf Gegnern")
## Farbtöne nach Priorität: Frost (verlangsamt/eingefroren) vor Brand vor Fluch. Alpha = Stärke der Tönung.
@export var frost_tint: Color = Color.WHITE
@export var curse_tint: Color = Color.WHITE
## Elites und Bosse halten Verlangsamen/Einfrieren/Festhalten nur so lange (Anteil der Dauer).
@export var boss_status_factor: float = 1.0
## Nach dem Festhalten (Lichtranke, Dornenranke) ist ein Gegner so lange davor geschützt.
@export var root_immunity_time: float = 0.0
## Abstand zwischen zwei Fluch-Schadensticks in Sekunden.
@export var curse_tick_interval: float = 1.0
## Farbe und Radius des Stapel-Abzeichens am Fluch-Symbol.
@export var curse_marker_color: Color = Color.WHITE
@export var curse_marker_radius: float = 0.0
@export var curse_marker_gap: float = 0.0
@export var curse_marker_scale: float = 1.0

@export_group("Darstellung der Status")
## Breite der Eis-/Rankengrafik relativ zum Körperdurchmesser des Gegners.
@export var status_overlay_scale: float = 1.0
## Verlangsamte Gegner verlieren in diesem Abstand Eiskristall-Partikel (Sekunden).
@export var frost_particle_interval: float = 0.5
## Flammen brennender Gegner: Stärke und Tempo des Flackerns.
@export var burn_flicker_amount: float = 0.0
@export var burn_flicker_speed: float = 0.0

@export_group("Verbündete")
## Höchstzahl aller Verbündeten gleichzeitig (über alle Effekte).
@export var ally_global_max: int = 0
@export var ally_pool_size: int = 0
## Abstand zwischen zwei Kontaktschäden eines Verbündeten am selben Gegner.
@export var ally_contact_interval: float = 0.0
@export var ally_min_speed: float = 0.0
@export var ally_retarget_interval: float = 0.0
@export var ally_outline_color: Color = Color.WHITE
@export var ally_outline_width: float = 3.0
## Farbton der Schattengeister im Shader (Alpha = Stärke) und ihre Deckkraft.
@export var ally_tint: Color = Color.WHITE
@export var ally_alpha: float = 1.0
@export var ally_trail_color: Color = Color.WHITE

@export_group("Spiegelbild")
@export var mirror_tint: Color = Color.WHITE
## Glanz, der über das Spiegelbild wandert: Abstand in Sekunden und Stärke.
@export var mirror_sheen_period: float = 1.0
@export var mirror_sheen_strength: float = 0.0
## Zusätzlicher Abstand zur Körpermitte, bevor das Spiegelbild nachzieht.
@export var mirror_follow_distance: float = 0.0
@export var mirror_follow_speed: float = 0.0

@export_group("Drohnen")
@export var drone_orbit_radius: float = 0.0
## Umlaufgeschwindigkeit in Grad pro Sekunde.
@export var drone_orbit_speed_deg: float = 0.0

@export_group("Strukturen")
## Wie oft Wurzel-Strukturen Gegner in ihrem Radius prüfen (Sekunden).
@export var root_check_interval: float = 0.0

@export_group("Bildschirmblitz")
@export var flash_color: Color = Color.WHITE
@export var flash_time: float = 0.0
## Deckkraft-Faktor des Blitzes mit der Option "Effekte reduzieren".
@export var flash_reduced_factor: float = 1.0
