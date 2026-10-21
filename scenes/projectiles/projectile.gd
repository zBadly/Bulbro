class_name Projectile
extends Area2D
## Gepooltes Spieler-Projektil: Durchschlag, Abprall, Ketten-Blitz, Explosion, Zielsuche, Rückstoß, Lebensraub.
## Fliegt bis zur Reichweite; jedes Ziel wird höchstens einmal getroffen.

const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")

var pool: ObjectPool

var _spec: ProjectileSpec
var _direction: Vector2 = Vector2.RIGHT
var _travel_left: float = 0.0
var _piercing_left: int = 0
var _bounces_left: int = 0
var _active: bool = false
var _hit_ids: Dictionary[int, bool] = {}
var _homing_target: Damageable
var _retarget_left: float = 0.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(start: Vector2, angle: float, spec: ProjectileSpec) -> void:
	_spec = spec
	global_position = start
	_set_direction(Vector2.from_angle(angle))
	_sprite.texture = spec.texture
	_travel_left = spec.max_range
	_piercing_left = spec.piercing
	_bounces_left = spec.bounces
	_hit_ids.clear()
	_homing_target = null
	_retarget_left = 0.0
	_active = true


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if _spec.homing_turn_deg > 0.0:
		_steer(delta)
	var step: float = _spec.speed * delta
	global_position += _direction * step
	_travel_left -= step
	if _travel_left <= 0.0:
		_finish()


func _steer(delta: float) -> void:
	_retarget_left -= delta
	if _retarget_left <= 0.0 or _homing_target == null or not is_instance_valid(_homing_target) or not _homing_target.is_alive():
		_retarget_left = COMBAT.homing_retarget_interval
		_homing_target = Hits.nearest_target(get_tree(), global_position, _spec.max_range, _hit_ids)
	if _homing_target == null:
		return
	var desired: float = global_position.direction_to(_homing_target.get_hit_position()).angle()
	var max_turn: float = deg_to_rad(_spec.homing_turn_deg) * delta
	_set_direction(Vector2.from_angle(rotate_toward(_direction.angle(), desired, max_turn)))


func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	var target: Damageable = body as Damageable
	if target == null or not target.is_alive() or _hit_ids.has(target.get_instance_id()):
		return
	_hit_ids[target.get_instance_id()] = true
	var info: DamageInfo = _spec.info
	info.knockback_dir = _direction

	if _spec.explosion_radius > 0.0:
		Hits.explode(get_tree(), _spec.player, target.get_hit_position(), _spec.explosion_radius, info)
		_finish()
		return
	Hits.apply_weapon_hit(target, info, _spec.player, _spec.lifesteal)
	if _spec.split_count > 0:
		# Im Kollisions-Callback dürfen keine Physikobjekte entstehen
		_split.call_deferred(target.get_hit_position(), _direction, _spec, target.get_instance_id())
		_finish()
		return
	if _spec.chain_count > 0:
		_chain_from(target)
		_finish()
		return
	if _piercing_left > 0:
		_piercing_left -= 1
		return
	if _bounces_left > 0:
		var next: Damageable = Hits.nearest_target(get_tree(), global_position, _spec.max_range, _hit_ids)
		if next != null:
			_bounces_left -= 1
			_set_direction(global_position.direction_to(next.get_hit_position()))
			_travel_left = _spec.max_range
			return
	_finish()


## Ketten-Blitz: springt vom getroffenen Ziel auf die nächsten Ziele in Reichweite.
func _chain_from(first: Damageable) -> void:
	var current: Damageable = first
	for i in _spec.chain_count:
		var next: Damageable = Hits.nearest_target(get_tree(), current.get_hit_position(), _spec.chain_range, _hit_ids)
		if next == null:
			return
		_hit_ids[next.get_instance_id()] = true
		Fx.lightning(get_tree(), current.get_hit_position(), next.get_hit_position())
		_spec.info.knockback_dir = current.get_hit_position().direction_to(next.get_hit_position())
		Hits.apply_weapon_hit(next, _spec.info, _spec.player, _spec.lifesteal)
		current = next


## Splitter im Fächer um die Flugrichtung; sie treffen das zersplitterte Ziel nicht erneut und splittern nicht weiter.
func _split(origin: Vector2, direction: Vector2, spec: ProjectileSpec, ignore_id: int) -> void:
	var projectile_pool: ObjectPool = Pools.get_pool(get_tree(), Pools.PLAYER_PROJECTILES)
	if projectile_pool == null:
		return
	var amount: int = maxi(CombatMath.MIN_DAMAGE, roundi(spec.info.amount * spec.split_damage_pct / CombatMath.PERCENT))
	var spread: float = deg_to_rad(COMBAT.split_spread_deg)
	for i in spec.split_count:
		var shard: ProjectileSpec = ProjectileSpec.new()
		shard.texture = spec.split_texture if spec.split_texture != null else spec.texture
		shard.speed = spec.speed
		shard.max_range = COMBAT.split_range
		shard.info = DamageInfo.create(amount, spec.info.is_crit, 0.0, spec.info.source)
		shard.player = spec.player
		shard.lifesteal = spec.lifesteal
		var t: float = float(i) / float(maxi(1, spec.split_count - 1)) if spec.split_count > 1 else 0.5
		var angle: float = direction.angle() + lerpf(-spread * 0.5, spread * 0.5, t)
		var projectile: Projectile = projectile_pool.acquire() as Projectile
		projectile.launch(origin, angle, shard)
		projectile.ignore(ignore_id)


## Dieses Ziel wird von diesem Projektil nicht getroffen (Splitter und ihr Ursprungsziel).
func ignore(instance_id: int) -> void:
	_hit_ids[instance_id] = true


func _set_direction(direction: Vector2) -> void:
	_direction = direction
	rotation = direction.angle()


func _finish() -> void:
	_active = false
	if pool != null:
		pool.release.call_deferred(self)
	else:
		queue_free()
