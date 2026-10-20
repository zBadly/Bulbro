class_name PhasedData
extends BehaviorData
## Elites und Bosse: Abfolge von Phasen mit eigener Bewegung und eigenen Angriffsmustern.

@export var phases: Array[BossPhaseData] = []


func create_behavior() -> EnemyBehavior:
	var behavior: PhasedBehavior = PhasedBehavior.new()
	behavior.config = self
	return behavior
