class_name ZoneAttack
extends AttackPatternData
## Markiert Zonen um den Spieler; nach der Vorwarnzeit entsteht in jeder Zone ein Projektilring (Finsternis).

@export var zone_count: int = 1
@export var zone_radius: float = 0.0
## Abstand der Zonen um den Spieler.
@export var spread: float = 0.0
@export var warning_time: float = 0.0
@export var burst: RadialBurstAttack


func execute(enemy: Enemy, _cast: int) -> void:
	var rng: RandomNumberGenerator = enemy.rng
	for i in zone_count:
		var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, spread)
		var center: Vector2 = enemy.player.global_position + offset
		if enemy.arena_bounds.has_area():
			center = center.clamp(enemy.arena_bounds.position, enemy.arena_bounds.end)
		Fx.zone_warning(enemy.get_tree(), center, zone_radius, warning_time)
		enemy.get_tree().create_timer(warning_time, false).timeout.connect(_detonate.bind(enemy, center))


func _detonate(enemy: Enemy, center: Vector2) -> void:
	if is_instance_valid(enemy) and enemy.is_alive():
		burst.fire_from(enemy, center, enemy.rng.randf() * TAU)
