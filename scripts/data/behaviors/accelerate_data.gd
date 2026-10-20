class_name AccelerateData
extends BehaviorData
## Hetzer: verfolgt und wird jede Sekunde schneller.

@export var start_speed: float = 0.0
@export var max_speed: float = 0.0
## Tempozuwachs in px/s pro Sekunde.
@export var acceleration: float = 0.0


func create_behavior() -> EnemyBehavior:
	var behavior: AccelerateBehavior = AccelerateBehavior.new()
	behavior.config = self
	return behavior
