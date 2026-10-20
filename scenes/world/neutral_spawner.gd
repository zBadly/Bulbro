class_name NeutralSpawner
extends Node
## Spawnt während einer Welle Leuchtkristalle und den Funkendieb nach den Regeln aus GDD Abschnitt 6.

const DROPS: DropConfig = preload("res://data/config/drop_config.tres")
const CRYSTAL_SCENE: PackedScene = preload("res://scenes/world/crystal.tscn")

var wave_manager: WaveManager
var player: Player
var container: Node2D

var _time: float = 0.0
var _next_crystal: float = INF
var _next_thief: float = INF
var _crystals: Array[Crystal] = []


func _ready() -> void:
	Events.wave_started.connect(_on_wave_started)
	Events.wave_ended.connect(_on_wave_ended)


func _physics_process(delta: float) -> void:
	if wave_manager == null or wave_manager.state != WaveManager.State.WAVE or player.is_dead:
		return
	_time += delta
	var rng: RandomNumberGenerator = GameState.rng
	if _time >= _next_crystal:
		_next_crystal += DROPS.crystal_spawn_interval
		var chance: float = DROPS.crystal_spawn_chance * (1.0 + player.stats.get_stat(Stats.CRYSTALS) / Economy.PERCENT)
		if _alive_crystals() < DROPS.crystal_max_count and rng.randf() < chance:
			spawn_crystal(wave_manager.pick_spawn_point())
	if _time >= _next_thief:
		_next_thief += DROPS.thief_check_interval
		if rng.randf() < DROPS.thief_chance:
			wave_manager.spawn_enemy(DROPS.thief, wave_manager.pick_spawn_point())


func spawn_crystal(spawn_position: Vector2) -> Crystal:
	var crystal: Crystal = CRYSTAL_SCENE.instantiate() as Crystal
	container.add_child(crystal)
	crystal.activate(wave_manager.get_wave_number(), spawn_position)
	_crystals.append(crystal)
	return crystal


## Entfernt zerbrochene (bereits freigegebene) Kristalle aus der Liste.
func _alive_crystals() -> int:
	var alive: Array[Crystal] = []
	for item: Variant in _crystals:
		if is_instance_valid(item) and (item as Crystal).is_alive():
			alive.append(item)
	_crystals = alive
	return _crystals.size()


func _on_wave_started(wave_number: int) -> void:
	_time = 0.0
	_next_crystal = DROPS.crystal_first_spawn
	_next_thief = DROPS.thief_first_check if wave_number >= DROPS.thief_first_wave else INF


func _on_wave_ended(_wave_number: int) -> void:
	_alive_crystals()
	for crystal: Crystal in _crystals:
		crystal.remove()
	_crystals.clear()
	_next_crystal = INF
	_next_thief = INF
