extends GutTest
## Tests für den Trefferablauf, HP und Lebensraub am echten Player.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _player: Player


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.rng = RandomNumberGenerator.new()
	_player.rng.seed = 1
	add_child_autofree(_player)


func test_starts_with_full_hp_from_config() -> void:
	assert_eq(_player.current_hp, 10.0)
	assert_eq(_player.get_max_hp(), 10.0)


func test_hit_reduces_hp_and_grants_invulnerability() -> void:
	assert_eq(_player.take_hit(3.0), 3)
	assert_eq(_player.current_hp, 7.0)
	assert_true(_player.is_invulnerable())
	assert_eq(_player.take_hit(3.0), 0, "während Unverwundbarkeit kein Schaden")
	assert_eq(_player.current_hp, 7.0)


func test_invulnerability_expires() -> void:
	_player.take_hit(1.0)
	await wait_seconds(_player.config.invulnerability_time + 0.1)
	assert_false(_player.is_invulnerable())


func test_armor_reduces_hit() -> void:
	_player.stats.add_modifier(StatModifier.create(Stats.ARMOR, 15.0))
	assert_eq(_player.take_hit(4.0), 2)


func test_max_dodge_avoids_most_hits() -> void:
	_player.stats.add_modifier(StatModifier.create(Stats.DODGE, 1000.0))
	watch_signals(_player)
	var dodges: int = 0
	for i in 200:
		if _player.take_hit(1.0) == 0:
			dodges += 1
		_player._invulnerable_left = 0.0
		_player.current_hp = _player.get_max_hp()
	assert_signal_emitted(_player, "dodged")
	assert_between(dodges, 90, 150, "Cap 60 %% erwartet, war %d / 200" % dodges)


func test_death_signal() -> void:
	watch_signals(_player)
	_player.take_hit(100.0)
	assert_true(_player.is_dead)
	assert_signal_emitted(_player, "died")


func test_max_hp_gain_also_heals() -> void:
	_player.take_hit(5.0)
	_player.stats.add_modifier(StatModifier.create(Stats.MAX_HP, 3.0))
	assert_eq(_player.current_hp, 8.0)
	assert_eq(_player.get_max_hp(), 13.0)


func test_regeneration_heals_over_time() -> void:
	_player.stats.add_modifier(StatModifier.create(Stats.HP_REGEN, 11.0))
	_player.take_hit(5.0)
	await wait_seconds(1.0)
	assert_gt(_player.current_hp, 5.5)


func test_lifesteal_respects_interval() -> void:
	_player.stats.add_modifier(StatModifier.create(Stats.LIFESTEAL, 100.0))
	_player.take_hit(5.0)
	assert_true(_player.try_lifesteal())
	assert_false(_player.try_lifesteal(), "zweiter Versuch im selben Zeitfenster")
	assert_eq(_player.current_hp, 6.0)
