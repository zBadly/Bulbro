extends GutTest
## Tests für StatSystem: Basis, FLAT, PERCENT, GAIN_PERCENT und stats_changed.

const EPS: float = 0.0001


func _system(base_values: Dictionary[StringName, float]) -> StatSystem:
	var block: StatBlock = StatBlock.new()
	block.values = base_values
	return StatSystem.new(block)


func test_base_value_and_missing_stat_is_zero() -> void:
	var s: StatSystem = _system({Stats.MAX_HP: 10.0})
	assert_eq(s.get_stat(Stats.MAX_HP), 10.0)
	assert_eq(s.get_stat(Stats.ARMOR), 0.0)


func test_flat_modifiers_add() -> void:
	var s: StatSystem = _system({Stats.MAX_HP: 10.0})
	s.add_modifier(StatModifier.create(Stats.MAX_HP, 3.0))
	s.add_modifier(StatModifier.create(Stats.MAX_HP, -1.0))
	assert_eq(s.get_stat(Stats.MAX_HP), 12.0)


func test_percent_modifiers_multiply_total() -> void:
	var s: StatSystem = _system({Stats.MAX_HP: 10.0})
	s.add_modifier(StatModifier.create(Stats.MAX_HP, 10.0))
	s.add_modifier(StatModifier.create(Stats.MAX_HP, 50.0, StatModifier.Kind.PERCENT))
	assert_almost_eq(s.get_stat(Stats.MAX_HP), 30.0, EPS)


func test_gain_percent_scales_flat_but_not_base() -> void:
	var s: StatSystem = _system({Stats.RANGED_DMG: 2.0})
	s.add_modifier(StatModifier.create(Stats.RANGED_DMG, 50.0, StatModifier.Kind.GAIN_PERCENT))
	s.add_modifier(StatModifier.create(Stats.RANGED_DMG, 4.0))
	assert_almost_eq(s.get_stat(Stats.RANGED_DMG), 2.0 + 6.0, EPS)


func test_gain_minus_100_blocks_all_gains() -> void:
	var s: StatSystem = _system({})
	s.add_modifier(StatModifier.create(Stats.MELEE_DMG, -100.0, StatModifier.Kind.GAIN_PERCENT))
	s.add_modifier(StatModifier.create(Stats.MELEE_DMG, 8.0))
	assert_almost_eq(s.get_stat(Stats.MELEE_DMG), 0.0, EPS)


func test_remove_modifier_restores_value() -> void:
	var s: StatSystem = _system({Stats.ARMOR: 1.0})
	var mod: StatModifier = StatModifier.create(Stats.ARMOR, 4.0)
	s.add_modifier(mod)
	assert_true(s.remove_modifier(mod))
	assert_eq(s.get_stat(Stats.ARMOR), 1.0)
	assert_false(s.remove_modifier(mod))


func test_stats_changed_emitted() -> void:
	var s: StatSystem = _system({})
	watch_signals(s)
	s.add_modifier(StatModifier.create(Stats.LUCK, 10.0))
	assert_signal_emitted(s, "stats_changed")


func test_all_stats_have_translation_keys() -> void:
	for stat: StringName in Stats.all():
		var key: String = Stats.label_key(stat)
		assert_ne(TranslationServer.translate(key), StringName(key), "Übersetzung fehlt: " + key)
