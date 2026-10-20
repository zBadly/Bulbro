class_name AudioConfig
extends Resource
## Lautstärken und Regeln für Soundeffekte und Musik. Werte in res://data/config/audio_config.tres.

@export var sfx_folder: String = ""
## Lautstärke pro Effekt in dB (fehlende Einträge: 0 dB).
@export var sfx_volume_db: Dictionary[StringName, float] = {}
## Höchstzahl gleichzeitiger Instanzen pro Effekt (fehlende Einträge: default_max_instances).
@export var max_instances: Dictionary[StringName, int] = {}
@export var default_max_instances: int = 0
@export var player_pool_size: int = 0
## Zufällige Tonhöhen-Abweichung (+-), damit Wiederholungen nicht gleich klingen.
@export var pitch_variation: float = 0.0

@export_group("Funken-Serie")
## Funken innerhalb dieses Zeitfensters gelten als Serie und klingen jeweils etwas höher.
@export var spark_series_window: float = 0.0
@export var spark_pitch_step: float = 0.0
@export var spark_pitch_max: float = 1.0

@export_group("Musik")
@export var music: AudioStream
@export var music_volume_db: float = 0.0
