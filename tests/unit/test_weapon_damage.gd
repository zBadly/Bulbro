extends GutTest
## Tests für die Schadensformel aus GDD Abschnitt 8.


func _stats(values: Dictionary[StringName, float]) -> StatSystem:
	var block: StatBlock = StatBlock.new()
	block.values = values
	return StatSystem.new(block)


func test_scaling_bonus_sums_stat_times_factor() -> void:
	var s: StatSystem = _stats({Stats.MELEE_DMG: 10.0, Stats.RANGED_DMG: 4.0})
	var scalings: Dictionary[StringName, float] = {Stats.MELEE_DMG: 0.8, Stats.RANGED_DMG: 0.5}
	assert_almost_eq(CombatMath.scaling_bonus(scalings, s), 10.0, 0.0001)


func test_base_damage_without_stats() -> void:
	assert_eq(CombatMath.weapon_damage(12.0, 0.0, 0.0, 1.0), 12)


func test_damage_pct_multiplies() -> void:
	assert_eq(CombatMath.weapon_damage(10.0, 10.0, 50.0, 1.0), 30)


func test_crit_multiplier() -> void:
	assert_eq(CombatMath.weapon_damage(6.0, 0.0, 0.0, 2.5), 15)


func test_minimum_damage_is_one() -> void:
	assert_eq(CombatMath.weapon_damage(5.0, -20.0, 0.0, 1.0), 1)
	assert_eq(CombatMath.weapon_damage(5.0, 0.0, -200.0, 1.0), 1)


func test_full_formula_example() -> void:
	# Glasscherbe: 6 + 80 % von Nah 5 = 10; +20 % Schaden = 12; Krit x2,5 = 30
	assert_eq(CombatMath.weapon_damage(6.0, 0.8 * 5.0, 20.0, 2.5), 30)
