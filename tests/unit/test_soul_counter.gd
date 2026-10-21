extends GutTest
## Seelenglas des Irrlichts (SoulCounter, ReanimateEffect sammelt Seelen).

const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")


func before_each() -> void:
	GameState.start_run(11)


func _counter(max_souls: int) -> SoulCounter:
	var counter: SoulCounter = SoulCounter.new()
	counter.max_souls = max_souls
	return counter


func test_souls_are_capped() -> void:
	var counter: SoulCounter = _counter(100)
	for i in 120:
		counter.add(1, SCHATTENLING, Vector2.ZERO)
	assert_eq(counter.souls, 100)


func test_bonus_damage_per_full_step() -> void:
	var counter: SoulCounter = _counter(100)
	assert_eq(counter.bonus_damage(20, 1.0), 0.0)
	counter.add(39, SCHATTENLING, Vector2.ZERO)
	assert_eq(counter.bonus_damage(20, 1.0), 1.0, "39 Seelen = ein voller Schritt")
	counter.add(61, SCHATTENLING, Vector2.ZERO)
	assert_eq(counter.bonus_damage(20, 1.0), 5.0)
	assert_eq(counter.bonus_damage(0, 1.0), 0.0, "Schritt 0 = kein Bonus")


func test_summon_needs_threshold_and_type() -> void:
	var counter: SoulCounter = _counter(100)
	counter.add(10, null, Vector2.ZERO)
	assert_false(counter.can_summon(5), "ohne bekannten Gegnertyp")
	counter.reset()
	counter.add(4, SCHATTENLING, Vector2(10, 20))
	assert_false(counter.can_summon(5))
	counter.add(1, SCHATTENLING, Vector2(30, 40))
	assert_true(counter.can_summon(5))
	assert_eq(counter.last_type, SCHATTENLING)
	assert_eq(counter.last_position, Vector2(30, 40), "der Geist erscheint am letzten Kill")


func test_souls_are_not_consumed_by_summoning() -> void:
	var counter: SoulCounter = _counter(100)
	counter.add(6, SCHATTENLING, Vector2.ZERO)
	assert_true(counter.can_summon(5))
	assert_true(counter.can_summon(5))
	assert_eq(counter.souls, 6)


func test_reanimate_effect_collects_souls_from_kills() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var effect: ReanimateEffect = ReanimateEffect.new()
	effect.max_souls = 100
	effect.souls_per_kill = 1
	effect.apply(player)
	assert_eq(GameState.souls.max_souls, 100)
	var ctx: EffectContext = EffectContext.create(player)
	effect.on_enemy_killed(ctx, player.triggers[0], Vector2.ZERO, SCHATTENLING, null)
	var info: DamageInfo = DamageInfo.create(1, false, 0.0, null)
	info.extra_souls = 1
	effect.on_enemy_killed(ctx, player.triggers[0], Vector2.ZERO, SCHATTENLING, info)
	assert_eq(GameState.souls.souls, 3, "1 + (1 + 1 Bonus-Seele)")


func test_new_run_resets_souls() -> void:
	GameState.souls.max_souls = 100
	GameState.souls.add(50, SCHATTENLING, Vector2.ZERO)
	GameState.start_run(12)
	assert_eq(GameState.souls.souls, 0)
