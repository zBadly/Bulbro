class_name FleeData
extends BehaviorData
## Flieht vor dem Spieler. Am Arenarand wird zur Seite ausgewichen.

## Ab dieser Entfernung zum Spieler wandert der Gegner nur noch langsam.
@export var calm_distance: float = 0.0
@export_range(0.0, 1.0) var calm_speed_factor: float = 0.0


func create_behavior() -> EnemyBehavior:
	var behavior: FleeBehavior = FleeBehavior.new()
	behavior.config = self
	return behavior
