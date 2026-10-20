class_name DropManager
extends Node
## Erzeugt Drops bei Kills und Kristallen und rechnet das Wellenende ab:
## liegengebliebene Funken in den Beutel, Kartons einsammeln, Batterien entfernen, Aufladung auszahlen.

const DROPS: DropConfig = preload("res://data/config/drop_config.tres")
const DOUBLE_SPARK_VALUE: int = 2

var player: Player


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.crystal_destroyed.connect(_on_crystal_destroyed)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_ended.connect(_on_wave_ended)


func _on_enemy_killed(data: EnemyData, position: Vector2) -> void:
	var rng: RandomNumberGenerator = GameState.rng
	_spawn_sparks(data.sparks, position)
	if data.guaranteed_crate:
		_spawn_crate(position)
	elif rng.randf() < Economy.battery_chance(DROPS.consumable_base_chance, _luck()):
		_spawn_consumable(position)


func _on_crystal_destroyed(position: Vector2) -> void:
	_spawn_sparks(DROPS.crystal_sparks, position)
	if GameState.rng.randf() < DROPS.crystal_crate_share:
		_spawn_crate(position)
	else:
		_spawn_pickup(Pickup.Kind.BATTERY, 1, position)


## Ein Verbrauchsgegenstand ist mit der Kartonchance ein Karton, sonst eine Batterie.
func _spawn_consumable(position: Vector2) -> void:
	if GameState.rng.randf() < Economy.crate_chance(DROPS.crate_base_chance, _luck(), GameState.crates_this_wave):
		_spawn_crate(position)
	else:
		_spawn_pickup(Pickup.Kind.BATTERY, 1, position)


func _spawn_crate(position: Vector2) -> void:
	GameState.crates_this_wave += 1
	_spawn_pickup(Pickup.Kind.CRATE, 1, position)


func _spawn_sparks(count: int, position: Vector2) -> void:
	var double_chance: float = player.stats.get_stat(Stats.DOUBLE_SPARK_CHANCE) / Economy.PERCENT
	for i in count:
		var value: int = DOUBLE_SPARK_VALUE if GameState.rng.randf() < double_chance else 1
		_spawn_pickup(Pickup.Kind.SPARK, value, position)


func _spawn_pickup(kind: Pickup.Kind, value: int, position: Vector2) -> void:
	var pool: ObjectPool = Pools.get_pool(get_tree(), Pools.PICKUPS)
	if pool == null:
		return
	var rng: RandomNumberGenerator = GameState.rng
	var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf() * DROPS.scatter_radius
	(pool.acquire() as Pickup).drop(kind, value, position, position + offset, player)


func _on_wave_started(_wave_number: int) -> void:
	GameState.crates_this_wave = 0


func _on_wave_ended(_wave_number: int) -> void:
	_sweep_pickups()
	_harvest()


func _sweep_pickups() -> void:
	var pool: ObjectPool = Pools.get_pool(get_tree(), Pools.PICKUPS)
	if pool == null:
		return
	var leftover: int = 0
	for node: Node in pool.get_active():
		var pickup: Pickup = node as Pickup
		match pickup.kind:
			Pickup.Kind.SPARK:
				leftover += pickup.value
			Pickup.Kind.CRATE:
				GameState.add_crate()
		pickup.release()
	if leftover > 0:
		GameState.add_to_bag(leftover)


## Aufladung: +x Funken und XP, danach wächst sie um 5 % (aufgerundet), nur wenn positiv.
func _harvest() -> void:
	var harvesting: float = player.stats.get_stat(Stats.HARVESTING)
	if harvesting == 0.0:
		return
	var amount: int = roundi(harvesting)
	GameState.add_sparks(amount)
	if amount > 0:
		GameState.add_xp(Economy.xp_gain(amount, player.stats.get_stat(Stats.XP_GAIN_PCT)))
	var growth: int = Economy.harvesting_growth(harvesting)
	if growth > 0:
		player.stats.add_modifier(StatModifier.create(Stats.HARVESTING, growth))


func _luck() -> float:
	return player.stats.get_stat(Stats.LUCK)
