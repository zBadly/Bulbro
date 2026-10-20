class_name OrbitShooterData
extends BehaviorData
## Rußschütze: kreist um den Spieler und schießt Projektile mit kurzer Reichweite.

@export var orbit_radius: float = 0.0
@export var fire_interval_min: float = 0.0
@export var fire_interval_max: float = 0.0
@export var projectile_speed: float = 0.0
@export var projectile_range: float = 0.0
@export var projectile_texture: Texture2D


func create_behavior() -> EnemyBehavior:
	var behavior: OrbitShooterBehavior = OrbitShooterBehavior.new()
	behavior.config = self
	return behavior
