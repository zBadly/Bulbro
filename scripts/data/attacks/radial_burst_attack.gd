class_name RadialBurstAttack
extends AttackPatternData
## Projektile im Kreis oder Fächer. Mit `rotation_step_deg` dreht sich das Muster pro Ausführung (Spirale).

@export var count: int = 1
## 360 = voller Ring, sonst Fächer um die Zielrichtung.
@export var spread_deg: float = 360.0
@export var aim_at_player: bool = true
@export var angle_offset_deg: float = 0.0
@export var rotation_step_deg: float = 0.0
@export var projectile_speed: float = 0.0
@export var projectile_range: float = 0.0
@export var projectile_texture: Texture2D


func execute(enemy: Enemy, cast: int) -> void:
	var base: float = deg_to_rad(angle_offset_deg + rotation_step_deg * cast)
	if aim_at_player:
		base += enemy.direction_to_player().angle()
	fire_from(enemy, enemy.get_hit_position(), base)


## Feuert das Muster an einer beliebigen Position (auch für Zonen).
func fire_from(enemy: Enemy, origin: Vector2, base_angle: float) -> void:
	var spread: float = deg_to_rad(spread_deg)
	var full_ring: bool = spread_deg >= 360.0
	for i in count:
		var angle: float = base_angle
		if full_ring:
			angle += TAU * i / count
		elif count > 1:
			angle += lerpf(-spread * 0.5, spread * 0.5, float(i) / (count - 1))
		enemy.fire_projectile_from(origin, Vector2.from_angle(angle), projectile_speed, projectile_range, projectile_texture)
