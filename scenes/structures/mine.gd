class_name Mine
extends Node2D
## Mine des Stolperdrahts: wird nach kurzer Zeit scharf und explodiert, sobald ein Gegner nahe kommt.
## Die Explosion nutzt die ExplosionAction des Turms als Strukturschaden (ohne Schaden-%, mit Explosions-Stats).

const TOWERS: TowerConfig = preload("res://data/config/tower_config.tres")
const BLINK_TIME: float = 0.15

var data: StructureData
var player: Player

var _armed_in: float = 0.0
var _check_left: float = 0.0
var _sprite: Sprite2D


func setup(p_data: StructureData, p_player: Player) -> void:
	data = p_data
	player = p_player
	_armed_in = data.mine_arm_time


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = data.mine_texture
	_sprite.modulate.a = 0.6
	add_child(_sprite)
	Juice.spawn_pop(_sprite)


func is_armed() -> bool:
	return _armed_in <= 0.0


func _physics_process(delta: float) -> void:
	if player == null or player.is_dead:
		return
	if _armed_in > 0.0:
		_armed_in -= delta
		_sprite.modulate.a = 1.0 if is_armed() else 0.6 + 0.4 * float(int(_armed_in / BLINK_TIME) % 2)
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = TOWERS.mine_check_interval
	for target: Damageable in Hits.alive_targets(get_tree()):
		if target.get_hit_position().distance_to(global_position) <= data.mine_trigger_radius:
			detonate()
			return


func detonate() -> void:
	var ctx: EffectContext = EffectContext.create(player)
	ctx.origin = DamageSource.structure(data.id)
	ctx.structure_damage = true
	data.mine.execute(ctx, global_position)
	queue_free()
