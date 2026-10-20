class_name BehaviorData
extends Resource
## Parameter eines Gegnerverhaltens. Jede Unterklasse erzeugt die passende Verhaltens-Komponente (Node).


func create_behavior() -> EnemyBehavior:
	push_error("BehaviorData.create_behavior() muss überschrieben werden")
	return EnemyBehavior.new()
