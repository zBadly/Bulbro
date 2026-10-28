class_name EnemyProjectile
extends Area2D
## Gepooltes Gegner-Projektil. Trifft nur den Spieler und verschwindet danach.

var pool: ObjectPool

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _travel_left: float = 0.0
var _damage: float = 0.0
var _active: bool = false

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(start: Vector2, direction: Vector2, speed: float, max_range: float, damage: float, texture: Texture2D) -> void:
	global_position = start
	_direction = direction
	rotation = direction.angle()
	_speed = speed
	_travel_left = max_range
	_damage = damage
	_sprite.texture = texture
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
	var player: Player = body as Player
	if player == null or player.is_dead:
		return
	player.take_hit(_damage)
	_finish()


func is_active() -> bool:
	return _active


## Von einem Begleiter abgefangen (Lampenschirm-Schildkröte): verschwindet ohne Treffer.
func block() -> void:
	if _active:
		_finish()


func _finish() -> void:
	_active = false
	if pool != null:
		pool.release.call_deferred(self)
	else:
		queue_free()
