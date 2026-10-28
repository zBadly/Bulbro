class_name PetConfig
extends Resource
## Gemeinsame Werte der Begleiter (Phase 15, Paket 8). Werte in res://data/config/pet_config.tres.

## Höchstzahl gleichzeitig; beim Kauf eines weiteren fragt der Shop, welcher ersetzt wird.
@export var max_pets: int = 0
## Anteil der Shop-Angebote, die Begleiter sind (wird vom Item-Anteil abgezogen).
@export var offer_chance: float = 0.0
## Rückgabe beim Ersetzen oder Recyceln (Anteil des Preises, wie bei Waffen plus Recycling-Stat).
@export var recycle_share: float = 0.0
## Ruheplätze relativ zum Spieler, je Begleiter einer (Index = Platz).
@export var follow_offsets: Array[Vector2] = []
## Folgeverzögerung: je größer, desto schneller holt der Begleiter auf (1 - e^(-Wert x Zeit) pro Frame).
@export var follow_sharpness: float = 0.0
## Mindestabstand zwischen zwei Begleitern; näher schieben sie sich auseinander.
@export var separation_distance: float = 0.0
## Abstand, ab dem ein Treffer oder Rammstoß das Ziel erreicht.
@export var contact_distance: float = 0.0
## Wie oft Begleiter nach Funken oder Projektilen suchen (Sekunden).
@export var scan_interval: float = 0.0
