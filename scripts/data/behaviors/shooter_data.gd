class_name ShooterData
extends BehaviorData
## Hält Abstand zum Spieler und schießt Projektile.

@export var preferred_distance: float = 0.0
@export var distance_tolerance: float = 0.0
@export var fire_interval_min: float = 0.0
@export var fire_interval_max: float = 0.0
@export var projectile_speed: float = 0.0
@export var projectile_range: float = 0.0
@export var projectile_texture: Texture2D


func create_behavior() -> EnemyBehavior:
	var behavior: ShooterBehavior = ShooterBehavior.new()
	behavior.config = self
	return behavior
