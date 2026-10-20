class_name ChargeData
extends BehaviorData
## Verfolgt und sprintet in Abständen geradeaus auf die letzte Spielerposition.

@export var interval_min: float = 0.0
@export var interval_max: float = 0.0
## Ausholen vor dem Sprint (Stillstand mit Squash als Warnung).
@export var windup_time: float = 0.0
@export var charge_time: float = 0.0
@export var charge_speed: float = 0.0


func create_behavior() -> EnemyBehavior:
	var behavior: ChargeBehavior = ChargeBehavior.new()
	behavior.config = self
	return behavior
