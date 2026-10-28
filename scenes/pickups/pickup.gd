class_name Pickup
extends Node2D
## Gepooltes Pickup: Funke, Batterie oder Ersatzteil-Karton.
## Funken werden im Aufsammelradius des Spielers angezogen, Verbrauchsgegenstände nur aus der Nähe.

enum Kind { SPARK, BATTERY, CRATE, LEGENDARY_CRATE }

const DROPS: DropConfig = preload("res://data/config/drop_config.tres")

var pool: ObjectPool
var kind: Kind = Kind.SPARK
var value: int = 1

var _player: Player
var _active: bool = false
var _homing: bool = false
var _speed: float = 0.0
var _tween: Tween

@onready var _sprite: Sprite2D = $Sprite


## Lässt das Pickup an `from` erscheinen und zur Ruheposition `to` hüpfen.
func drop(p_kind: Kind, p_value: int, from: Vector2, to: Vector2, player: Player) -> void:
	kind = p_kind
	value = p_value
	_player = player
	_homing = false
	_speed = 0.0
	match kind:
		Kind.SPARK:
			_sprite.texture = DROPS.spark_texture
		Kind.BATTERY:
			_sprite.texture = DROPS.battery_texture
		Kind.CRATE:
			_sprite.texture = DROPS.crate_texture
		Kind.LEGENDARY_CRATE:
			_sprite.texture = DROPS.legendary_crate_texture
	global_position = from
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", to, DROPS.scatter_time)
	_active = true


func _physics_process(delta: float) -> void:
	if not _active or _player == null or _player.is_dead:
		return
	var target: Vector2 = _player.get_center()
	var distance: float = global_position.distance_to(target)
	if not _homing:
		var radius: float = _player.get_pickup_radius() if kind == Kind.SPARK else DROPS.consumable_pickup_radius
		if distance > radius:
			return
		_homing = true
		_speed = DROPS.magnet_start_speed
		if _tween != null and _tween.is_valid():
			_tween.kill()
	_speed = minf(_speed + DROPS.magnet_acceleration * delta, DROPS.magnet_max_speed)
	global_position = global_position.move_toward(target, _speed * delta)
	if global_position.distance_to(target) <= DROPS.collect_distance:
		collect()


## Kann ein Begleiter (Funkenspatz) diesen Funken zum Spieler ziehen?
func can_attract() -> bool:
	return _active and not _homing and kind == Kind.SPARK


## Zieht das Pickup sofort zum Spieler, als wäre es im Aufsammelradius.
func attract() -> void:
	if not _active or _homing:
		return
	_homing = true
	_speed = DROPS.magnet_start_speed
	if _tween != null and _tween.is_valid():
		_tween.kill()


## Wendet den Effekt an und gibt das Pickup an den Pool zurück.
func collect() -> void:
	if not _active:
		return
	match kind:
		Kind.SPARK:
			GameState.collect_spark(value, _player.stats.get_stat(Stats.XP_GAIN_PCT))
			Events.spark_collected.emit()
		Kind.BATTERY:
			_player.heal(Economy.consumable_heal(DROPS.battery_heal, _player.stats.get_stat(Stats.CONSUMABLE_HEAL)))
			AudioManager.play(&"heal")
			Fx.particles(get_tree(), ParticleFx.Kind.HEAL, _player.get_center())
		Kind.CRATE, Kind.LEGENDARY_CRATE:
			_player.heal(Economy.consumable_heal(DROPS.crate_heal, _player.stats.get_stat(Stats.CONSUMABLE_HEAL)))
			GameState.add_crate(kind == Kind.LEGENDARY_CRATE)
	release()


func release() -> void:
	_active = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if pool != null:
		pool.release(self)
	else:
		queue_free()
