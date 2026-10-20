class_name Crystal
extends Damageable
## Leuchtkristall (neutral): greift nicht an, zerbricht nach spätestens max_hits Treffern und lässt Beute fallen.

const DROPS: DropConfig = preload("res://data/config/drop_config.tres")

var max_hp: float = 0.0
var hp: float = 0.0

var _alive: bool = false

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite


func activate(wave: int, spawn_position: Vector2) -> void:
	global_position = spawn_position
	max_hp = DROPS.crystal_base_hp + DROPS.crystal_hp_per_wave * maxi(0, wave - 1)
	hp = max_hp
	_alive = true
	Juice.spawn_pop(_visual)


func is_alive() -> bool:
	return _alive


func is_neutral() -> bool:
	return true


func take_damage(info: DamageInfo) -> void:
	if not _alive:
		return
	var damage: float = Economy.crystal_hit_damage(info.amount, max_hp, DROPS.crystal_max_hits)
	hp -= damage
	Juice.hit_flash(_sprite)
	Pools.spawn_damage_number(get_tree(), roundi(damage), info.is_crit, get_hit_position())
	if hp <= 0.0:
		_alive = false
		Events.crystal_destroyed.emit(global_position)
		Juice.squash_pop(_visual).finished.connect(queue_free, CONNECT_ONE_SHOT)


## Am Wellenende ohne Beute entfernen.
func remove() -> void:
	_alive = false
	queue_free()
