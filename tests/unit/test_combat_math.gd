extends GutTest
## Tests für jede Formel aus GDD Abschnitt 4 (CombatMath).

const EPS: float = 0.0001


# Rüstung
func test_armor_zero_takes_full_damage() -> void:
	assert_almost_eq(CombatMath.armor_multiplier(0.0), 1.0, EPS)


func test_armor_15_halves_damage() -> void:
	assert_almost_eq(CombatMath.armor_multiplier(15.0), 0.5, EPS)


func test_armor_each_point_adds_about_6_66_percent_effective_hp() -> void:
	var ehp_0: float = 1.0 / CombatMath.armor_multiplier(0.0)
	var ehp_1: float = 1.0 / CombatMath.armor_multiplier(1.0)
	assert_almost_eq(ehp_1 - ehp_0, 1.0 / 15.0, EPS)


func test_negative_armor_increases_damage() -> void:
	assert_almost_eq(CombatMath.armor_multiplier(-15.0), 2.0, EPS)


func test_damage_after_armor_is_at_least_one() -> void:
	assert_eq(CombatMath.damage_after_armor(1.0, 1000.0), 1)


func test_damage_after_armor_rounds() -> void:
	assert_eq(CombatMath.damage_after_armor(10.0, 15.0), 5)


# HP-Regen
func test_regen_zero_and_negative_do_nothing() -> void:
	assert_eq(CombatMath.hp_regen_per_second(0.0), 0.0)
	assert_eq(CombatMath.hp_regen_per_second(-5.0), 0.0)


func test_regen_first_point() -> void:
	assert_almost_eq(CombatMath.hp_regen_per_second(1.0), 0.20, EPS)


func test_regen_each_extra_point() -> void:
	assert_almost_eq(CombatMath.hp_regen_per_second(11.0), 0.20 + 10.0 * 0.089, EPS)


# Ausweichen
func test_dodge_is_capped() -> void:
	assert_almost_eq(CombatMath.dodge_chance(90.0, 60.0), 0.6, EPS)


func test_dodge_cap_can_be_raised() -> void:
	assert_almost_eq(CombatMath.dodge_chance(90.0, 70.0), 0.7, EPS)


func test_negative_dodge_acts_as_zero() -> void:
	assert_eq(CombatMath.dodge_chance(-20.0, 60.0), 0.0)


# Angriffstempo
func test_attack_speed_zero_keeps_cooldown() -> void:
	assert_almost_eq(CombatMath.attack_cooldown(1.2, 0.0), 1.2, EPS)


func test_attack_speed_100_halves_cooldown() -> void:
	assert_almost_eq(CombatMath.attack_cooldown(1.2, 100.0), 0.6, EPS)


func test_negative_attack_speed_is_weaker() -> void:
	var slowed: float = CombatMath.attack_cooldown(1.0, -50.0)
	assert_gt(slowed, 1.0, "negativ verlangsamt")
	assert_lt(slowed, 1.0 / (1.0 - 0.5), "aber schwächer als die gespiegelte Formel")


func test_attack_speed_cap_12_per_second() -> void:
	assert_almost_eq(CombatMath.attack_cooldown(0.35, 10000.0), 1.0 / 12.0, EPS)


# Mindestschaden / Max HP / Tempo / Reichweite / Krit
func test_negative_max_hp_acts_as_one() -> void:
	assert_eq(CombatMath.effective_max_hp(-4.0), 1.0)


func test_speed_minus_100_stands_still() -> void:
	assert_eq(CombatMath.move_speed(450.0, -100.0), 0.0)
	assert_eq(CombatMath.move_speed(450.0, -150.0), 0.0)


func test_speed_percent() -> void:
	assert_almost_eq(CombatMath.move_speed(450.0, 20.0), 540.0, EPS)


func test_melee_gets_half_range_stat() -> void:
	assert_eq(CombatMath.effective_range(150.0, 100.0, true), 200.0)
	assert_eq(CombatMath.effective_range(150.0, 100.0, false), 250.0)


func test_range_minimum_25() -> void:
	assert_eq(CombatMath.effective_range(150.0, -500.0, false), 25.0)


func test_crit_chance_adds_and_clamps() -> void:
	assert_almost_eq(CombatMath.crit_chance(0.2, 10.0), 0.3, EPS)
	assert_eq(CombatMath.crit_chance(0.5, 200.0), 1.0)
	assert_eq(CombatMath.crit_chance(0.0, -50.0), 0.0)


# Lebensraub
func test_lifesteal_chance() -> void:
	assert_almost_eq(CombatMath.lifesteal_chance(25.0), 0.25, EPS)
	assert_eq(CombatMath.lifesteal_chance(150.0), 1.0)


func test_lifesteal_limited_to_once_per_tenth_second() -> void:
	assert_false(CombatMath.lifesteal_ready(1.05, 1.0))
	assert_true(CombatMath.lifesteal_ready(1.1, 1.0))


# Trefferablauf
func test_hit_dodged_when_roll_below_chance() -> void:
	assert_eq(CombatMath.resolve_incoming_damage(10.0, 0.0, 50.0, 60.0, 0.49), 0)


func test_hit_lands_and_applies_armor() -> void:
	assert_eq(CombatMath.resolve_incoming_damage(10.0, 15.0, 50.0, 60.0, 0.5), 5)
