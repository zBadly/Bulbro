class_name HealerData
extends BehaviorData
## Flackerer: hält Abstand zum Spieler, bleibt bei Verbündeten und heilt Gegner in der Nähe.

@export var keep_distance: float = 0.0
@export var heal_interval: float = 0.0
@export var heal_radius: float = 0.0
## Heilung in % der maximalen HP des Ziels.
@export var heal_pct: float = 0.0


func create_behavior() -> EnemyBehavior:
	var behavior: HealerBehavior = HealerBehavior.new()
	behavior.config = self
	return behavior
