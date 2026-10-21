class_name StatusConfig
extends Resource
## Gemeinsame Werte für Status-Effekte, Verbündete, Spiegelbild und Drohnen.
## Werte stehen in res://data/config/status_config.tres; effektspezifische Zahlen liegen in den Effekt-Resources.

@export_group("Status auf Gegnern")
## Farbtöne nach Priorität: Frost (verlangsamt/eingefroren) vor Brand vor Fluch.
@export var frost_tint: Color = Color.WHITE
@export var curse_tint: Color = Color.WHITE
## Elites und Bosse halten Verlangsamen/Einfrieren/Festhalten nur so lange (Anteil der Dauer).
@export var boss_status_factor: float = 1.0
## Nach dem Festhalten (Lichtranke, Dornenranke) ist ein Gegner so lange davor geschützt.
@export var root_immunity_time: float = 0.0
## Abstand zwischen zwei Fluch-Schadensticks in Sekunden.
@export var curse_tick_interval: float = 1.0
@export var curse_marker_color: Color = Color.WHITE
@export var curse_marker_radius: float = 0.0
@export var curse_marker_gap: float = 0.0

@export_group("Verbündete")
## Höchstzahl aller Verbündeten gleichzeitig (über alle Effekte).
@export var ally_global_max: int = 0
@export var ally_pool_size: int = 0
## Abstand zwischen zwei Kontaktschäden eines Verbündeten am selben Gegner.
@export var ally_contact_interval: float = 0.0
@export var ally_min_speed: float = 0.0
@export var ally_retarget_interval: float = 0.0
@export var ally_outline_color: Color = Color.WHITE
@export var ally_alpha: float = 1.0

@export_group("Spiegelbild")
@export var mirror_tint: Color = Color.WHITE
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
