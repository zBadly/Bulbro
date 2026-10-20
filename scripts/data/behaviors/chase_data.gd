class_name ChaseData
extends BehaviorData
## Läuft direkt auf den Spieler zu.


func create_behavior() -> EnemyBehavior:
	var behavior: ChaseBehavior = ChaseBehavior.new()
	behavior.config = self
	return behavior
