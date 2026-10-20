class_name BufferData
extends BehaviorData
## Verstärker: hält Abstand und verstärkt regelmäßig einen nahen Gegner (rote Kontur).

@export var keep_distance: float = 0.0
@export var buff_interval: float = 0.0
@export var buff_radius: float = 0.0
@export var hp_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0


func create_behavior() -> EnemyBehavior:
	var behavior: BufferBehavior = BufferBehavior.new()
	behavior.config = self
	return behavior
