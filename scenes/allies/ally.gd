class_name Ally
extends CharacterBody2D
## Schattengeist auf Seiten des Spielers (Irrlicht): Aussehen eines besiegten Gegnertyps mit blauer Kontur.
## Läuft zum nächsten Gegner und macht Kontaktschaden. Unverwundbar, verschwindet nach Ablauf der Lebenszeit.
## Gehört nicht zur Gruppe Damageable.GROUP: Spielerwaffen zielen nicht darauf, und er zählt nicht zum Gegnerlimit.

const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const OUTLINE_SHADER: Shader = preload("res://art/shaders/outline.gdshader")
const OUTLINE_PARAM: StringName = &"outline_color"
## Gruppe aller gerade aktiven Verbündeten (globales Limit).
const ACTIVE_GROUP: StringName = &"active_allies"

var pool: ObjectPool
var data: EnemyData
var damage: int = 0
var arena_bounds: Rect2 = Rect2()

var _active: bool = false
var _life_left: float = 0.0
var _speed: float = 0.0
var _target: Damageable
var _retarget_left: float = 0.0
var _contact_cooldown: float = 0.0
var _material: ShaderMaterial

@onready var visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite
@onready var _shape: CollisionShape2D = $CollisionShape


static func active_count(tree: SceneTree) -> int:
	return tree.get_node_count_in_group(ACTIVE_GROUP)


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = OUTLINE_SHADER
	_material.set_shader_parameter(OUTLINE_PARAM, STATUS.ally_outline_color)
	_sprite.material = _material


func is_active() -> bool:
	return _active


## Aus dem Pool geholt: übernimmt Aussehen und Tempo des Gegnertyps.
func summon(p_data: EnemyData, spawn_position: Vector2, p_damage: int, lifetime: float, bounds: Rect2) -> void:
	data = p_data
	damage = p_damage
	arena_bounds = bounds
	global_position = spawn_position
	_sprite.texture = data.texture
	var half_height: float = data.texture.get_height() * 0.5
	_sprite.offset = Vector2(0.0, -half_height)
	_shape.position = Vector2(0.0, -half_height)
	(_shape.shape as CircleShape2D).radius = data.collision_radius
	_sprite.modulate = Color(1.0, 1.0, 1.0, STATUS.ally_alpha)
	_sprite.flip_h = false
	_speed = maxf(data.speed_max, STATUS.ally_min_speed)
	_life_left = lifetime
	_target = null
	_retarget_left = 0.0
	_contact_cooldown = 0.0
	_active = true
	add_to_group(ACTIVE_GROUP)
	Juice.spawn_pop(visual).finished.connect(_on_spawned, CONNECT_ONE_SHOT)


## Sofort entfernen (Wellenende).
func dismiss() -> void:
	if not _active:
		return
	_deactivate()
	_release()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_life_left -= delta
	if _life_left <= 0.0:
		_deactivate()
		Juice.squash_pop(visual).finished.connect(_release, CONNECT_ONE_SHOT)
		return
	_contact_cooldown -= delta
	_retarget_left -= delta
	if _retarget_left <= 0.0 or _target == null or not is_instance_valid(_target) or not _target.is_alive():
		_retarget_left = STATUS.ally_retarget_interval
		_target = _nearest_enemy()
	if _target == null:
		return
	var to_target: Vector2 = _target.global_position - global_position
	var reach: float = data.collision_radius * 2.0
	if to_target.length() > reach:
		var move: Vector2 = to_target.normalized() * _speed
		global_position += move * delta
		if arena_bounds.has_area():
			global_position = global_position.clamp(arena_bounds.position, arena_bounds.end)
		_sprite.flip_h = move.x < 0.0
		Juice.walk_tilt(visual, move)
	elif _contact_cooldown <= 0.0:
		_contact_cooldown = STATUS.ally_contact_interval
		_target.take_damage(DamageInfo.create(damage, false, 0.0, self))


## Nächster lebender Gegner (keine neutralen Objekte).
func _nearest_enemy() -> Damageable:
	var best: Damageable = null
	var best_dist: float = INF
	for target: Damageable in Hits.alive_targets(get_tree()):
		var dist: float = global_position.distance_squared_to(target.global_position)
		if dist < best_dist:
			best = target
			best_dist = dist
	return best


func _deactivate() -> void:
	_active = false
	if is_in_group(ACTIVE_GROUP):
		remove_from_group(ACTIVE_GROUP)


func _on_spawned() -> void:
	if _active:
		Juice.idle_bob(visual)


func _release() -> void:
	if pool != null:
		pool.release(self)
	else:
		queue_free()
