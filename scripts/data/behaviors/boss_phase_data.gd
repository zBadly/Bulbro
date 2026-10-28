class_name BossPhaseData
extends Resource
## Eine Phase eines Elites oder Bosses. Die nächste Phase beginnt, sobald die HP auf `next_at_hp` fallen
## oder diese Phase `max_duration` Sekunden läuft (0 = kein Zeitlimit).

enum Movement { CHASE, FLEE, STAND, CHARGE }

## HP-Anteil (0..1), ab dem die nächste Phase beginnt (0 = letzte Phase).
@export_range(0.0, 1.0) var next_at_hp: float = 0.0
@export var max_duration: float = 0.0
@export var movement: Movement = Movement.CHASE
@export var speed_multiplier: float = 1.0
## Name der Phase (Übersetzungsschlüssel), z. B. "Raserei": HP-Leiste, Banner beim Wechsel, Lexikon.
@export var name_key: String = ""
## Lexikon: Beschreibung der Phase (Übersetzungsschlüssel).
@export var description_key: String = ""
## Aura (Kontur) am Gegner in dieser Phase; Alpha 0 = keine Aura. Auch Farbe des Phasennamens im HUD.
@export var aura_color: Color = Color(1.0, 1.0, 1.0, 0.0)

@export_group("Sturmangriff")
@export var charge_interval: float = 0.0
@export var charge_windup: float = 0.0
@export var charge_time: float = 0.0
@export var charge_speed: float = 0.0
## Wird zu Beginn jedes Sturmangriffs ausgelöst (z. B. Seitenprojektile).
@export var charge_attack: AttackPatternData

@export_group("Angriffe")
@export var attacks: Array[AttackPatternData] = []
