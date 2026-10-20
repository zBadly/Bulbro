class_name TrainingDummy
extends Damageable
## Trainings-Dummy zum Testen der Waffen: stirbt nie, zeigt Schadenszahlen und DPS, federt nach Rückstoß zurück.

const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const DPS_REFRESH: float = 0.25

## 0 = voller Rückstoß, 1 = unbeweglich.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0

var total_damage: int = 0

var _anchor: Vector2
var _elapsed: float = 0.0
var _dps_refresh_left: float = 0.0
## Paare aus (Zeitpunkt, Schaden) innerhalb des DPS-Fensters.
var _recent_hits: Array[Vector2] = []

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite
@onready var _dps_label: Label = $DpsLabel


func _ready() -> void:
	super()
	_anchor = global_position
	Juice.idle_bob(_visual)
	_dps_label.text = ""


func take_damage(info: DamageInfo) -> void:
	total_damage += info.amount
	_recent_hits.append(Vector2(_elapsed, info.amount))
	Juice.hit_flash(_sprite)
	Pools.spawn_damage_number(get_tree(), info.amount, info.is_crit, get_hit_position())
	apply_knockback(info.knockback_dir * info.knockback * COMBAT.knockback_to_speed * (1.0 - knockback_resistance))


func _physics_process(delta: float) -> void:
	_elapsed += delta
	global_position += knockback_velocity * delta
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, COMBAT.knockback_friction * delta)
	if knockback_velocity.is_zero_approx():
		global_position = global_position.move_toward(_anchor, COMBAT.dummy_return_speed * delta)

	_dps_refresh_left -= delta
	if _dps_refresh_left <= 0.0:
		_dps_refresh_left = DPS_REFRESH
		_update_dps()


func _update_dps() -> void:
	var window: float = COMBAT.dummy_dps_window
	while not _recent_hits.is_empty() and _recent_hits[0].x < _elapsed - window:
		_recent_hits.pop_front()
	var sum: float = 0.0
	for hit: Vector2 in _recent_hits:
		sum += hit.y
	_dps_label.text = tr("DEBUG_DPS") % roundi(sum / window) if sum > 0.0 else ""
