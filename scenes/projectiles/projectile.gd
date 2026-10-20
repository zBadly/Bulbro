class_name Projectile
extends Area2D
## Gepooltes Spieler-Projektil mit Durchschlag, Abprall, Rückstoß und Lebensraub.
## Fliegt bis zur Reichweite der Waffe; jeder Gegner wird höchstens einmal getroffen.

var pool: ObjectPool

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _range: float = 0.0
var _travel_left: float = 0.0
var _info: DamageInfo
var _piercing_left: int = 0
var _bounces_left: int = 0
var _player: Player
var _active: bool = false
var _hit_ids: Dictionary[int, bool] = {}

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(start: Vector2, angle: float, texture: Texture2D, speed: float, max_range: float,
		info: DamageInfo, piercing: int, bounces: int, player: Player) -> void:
	global_position = start
	_set_direction(Vector2.from_angle(angle))
	_sprite.texture = texture
	_speed = speed
	_range = max_range
	_travel_left = max_range
	_info = info
	_piercing_left = piercing
	_bounces_left = bounces
	_player = player
	_hit_ids.clear()
	_active = true


func _physics_process(delta: float) -> void:
	if not _active:
		return
	var step: float = _speed * delta
	global_position += _direction * step
	_travel_left -= step
	if _travel_left <= 0.0:
		_finish()


func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	var enemy: Damageable = body as Damageable
	if enemy == null or not enemy.is_alive() or _hit_ids.has(enemy.get_instance_id()):
		return
	_hit_ids[enemy.get_instance_id()] = true
	_info.knockback_dir = _direction
	enemy.take_damage(_info)
	if _player != null:
		_player.try_lifesteal()

	if _piercing_left > 0:
		_piercing_left -= 1
		return
	if _bounces_left > 0:
		var next: Damageable = _find_bounce_target()
		if next != null:
			_bounces_left -= 1
			_set_direction((next.get_hit_position() - global_position).normalized())
			_travel_left = _range
			return
	_finish()


func _find_bounce_target() -> Damageable:
	var best: Damageable = null
	var best_dist: float = _range * _range
	for node: Node in get_tree().get_nodes_in_group(Damageable.GROUP):
		var enemy: Damageable = node as Damageable
		if enemy == null or not enemy.is_alive() or _hit_ids.has(enemy.get_instance_id()):
			continue
		var dist: float = global_position.distance_squared_to(enemy.get_hit_position())
		if dist < best_dist:
			best = enemy
			best_dist = dist
	return best


func _set_direction(direction: Vector2) -> void:
	_direction = direction
	rotation = direction.angle()


func _finish() -> void:
	_active = false
	if pool != null:
		pool.release.call_deferred(self)
	else:
		queue_free()
