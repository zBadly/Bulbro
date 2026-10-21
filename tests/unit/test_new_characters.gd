extends GutTest
## Paket 3: die 10 neuen Charaktere, ihre Freischaltbedingungen mit Fortschritt und die Sieg-Items.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const NEW_CHARACTERS: Array[String] = ["irrlicht", "zuendkerze", "kronleuchter", "schwarzlicht", "gewaechshauslampe",
	"smartbulb", "drohnenleuchte", "stroboskop", "vampirbirne", "spiegelkugel"]
const WIN_ITEMS: Dictionary[String, String] = {
	"irrlicht": "geisterkerze", "zuendkerze": "zuendspule", "kronleuchter": "kristallprisma", "schwarzlicht": "uv_roehre",
	"gewaechshauslampe": "pflanzenlicht", "smartbulb": "smart_steckdose", "drohnenleuchte": "wartungsdrohne",
	"stroboskop": "blitzwuerfel", "vampirbirne": "blutrote_fassung", "spiegelkugel": "spiegelscherbe",
}


func before_each() -> void:
	SaveManager.reset()
	GameState.character = null
	GameState.start_run(61)


func after_all() -> void:
	SaveManager.reset()


func _char(id: String) -> CharacterData:
	return load("res://data/characters/%s.tres" % id)


func _challenge(id: String) -> ChallengeData:
	return Unlocks.challenge_for(_char(id))


func _player(id: String) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.rng = RandomNumberGenerator.new()
	add_child_autofree(player)
	player.apply_character(_char(id))
	return player


func _ctx(at_run_end: bool = false, victory: bool = false) -> ChallengeContext:
	return Unlocks.make_context(at_run_end, victory)


# --- Daten ---

func test_new_characters_are_complete_and_locked() -> void:
	for id: String in NEW_CHARACTERS:
		var c: CharacterData = _char(id)
		assert_not_null(c, id)
		assert_false(c.unlocked_by_default, id)
		assert_not_null(_challenge(id), "Freischaltung: " + id)
		assert_false(c.starting_weapons.is_empty(), id)
		for weapon: WeaponData in c.starting_weapons:
			assert_true(c.can_use_weapon(weapon), "%s darf Startwaffe %s tragen" % [id, weapon.id])
		var player: Player = _player(id)
		assert_not_null(player.character, id)


func test_character_specials_are_applied() -> void:
	assert_eq(_player("drohnenleuchte").weapon_slots.max_slots, 4)
	assert_true(_player("schwarzlicht").has_rule(Player.Rule.NO_CRIT))
	var vampire: Player = _player("vampirbirne")
	assert_true(vampire.has_rule(Player.Rule.NO_REGEN))
	assert_almost_eq(vampire.lifesteal_interval_factor, 0.5, 0.001)
	assert_eq(vampire.stats.get_stat(Stats.LIFESTEAL), 10.0)
	var spark_plug: Player = _player("zuendkerze")
	assert_eq(spark_plug.stats.get_stat(Stats.BURN_SPREAD), 2.0)
	assert_false(spark_plug.can_use_weapon(load("res://data/weapons/heilstrahl.tres")), "keine Medizinisch-Waffen")
	var smart: Player = _player("smartbulb")
	assert_eq(smart.stats.get_stat(Stats.KILL_SPARK_PCT), 30.0)
	assert_eq(smart.stats.get_stat(Stats.FREE_REROLLS), 1.0)
	var mirror: Player = _player("spiegelkugel")
	var standard: Player = _player("standardbirne")
	assert_lt(mirror.get_max_hp(), standard.get_max_hp(), "-20 % Max HP")


func test_every_new_character_has_a_tier_three_win_item() -> void:
	for id: String in WIN_ITEMS:
		var item: ItemData = load("res://data/items/%s.tres" % WIN_ITEMS[id])
		assert_eq(item.tier, 3, item.id)
		assert_false(Unlocks.is_item_unlocked(item), "gesperrt bis zum Sieg: " + String(item.id))
		var description: String = item.get_description()
		assert_false(description.contains("EFFECT_") or description.contains("ACTION_") or description.contains("STAT_"), description)
		var found: bool = false
		for challenge: ChallengeData in Unlocks.all_challenges():
			if challenge.reward_item == item:
				found = true
				assert_eq(challenge.condition, ChallengeData.Condition.WIN_WITH_CHARACTER)
				assert_eq(challenge.character, _char(id))
		assert_true(found, "Sieg-Challenge für " + id)


# --- Bedingungen ---

func test_irrlicht_run_kills() -> void:
	var challenge: ChallengeData = _challenge("irrlicht")
	GameState.run_stats.enemies_killed = 499
	assert_false(challenge.is_met(_ctx()))
	GameState.run_stats.enemies_killed = 500
	assert_true(challenge.is_met(_ctx()))


func test_zuendkerze_total_burn_kills_add_up_over_runs() -> void:
	var challenge: ChallengeData = _challenge("zuendkerze")
	var burn: DamageInfo = DamageInfo.create(1, false, 0.0, null)
	burn.is_burn = true
	for i in 200:
		Events.enemy_killed.emit(SCHATTENLING, Vector2.ZERO, burn)
	assert_eq(GameState.run_stats.burn_kills, 200)
	assert_false(challenge.is_met(_ctx()))
	Unlocks.evaluate_run_end(false)
	assert_eq(SaveManager.get_stat(SaveManager.STAT_BURN_KILLS), 200)
	GameState.start_run(62)
	for i in 100:
		Events.enemy_killed.emit(SCHATTENLING, Vector2.ZERO, burn)
	assert_true(challenge.is_met(_ctx()), "200 gespeichert + 100 in diesem Run")


func test_kronleuchter_needs_victory_with_elemental() -> void:
	var challenge: ChallengeData = _challenge("kronleuchter")
	GameState.run_stats.max_elemental = 30.0
	assert_false(challenge.is_met(_ctx()), "nur am Run-Ende")
	assert_false(challenge.is_met(_ctx(true, false)), "nur bei Sieg")
	assert_true(challenge.is_met(_ctx(true, true)))
	GameState.run_stats.max_elemental = 29.0
	assert_false(challenge.is_met(_ctx(true, true)))


func test_elemental_peak_is_tracked() -> void:
	var player: Player = _player("lavalampe")
	player.stats.add_modifier(StatModifier.create(Stats.ELEMENTAL_DMG, 10.0))
	assert_almost_eq(GameState.run_stats.max_elemental, 5.0 + 10.0 * 1.33, 0.01)


func test_schwarzlicht_voodoo_needle_kills() -> void:
	var challenge: ChallengeData = _challenge("schwarzlicht")
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var needle: Weapon = player.weapon_slots.add_weapon(load("res://data/weapons/voodoo_nadel.tres"))
	var other: Weapon = player.weapon_slots.add_weapon(load("res://data/weapons/funkenpistole.tres"))
	for i in 299:
		Events.enemy_killed.emit(SCHATTENLING, Vector2.ZERO, DamageInfo.create(1, false, 0.0, needle))
	Events.enemy_killed.emit(SCHATTENLING, Vector2.ZERO, DamageInfo.create(1, false, 0.0, other))
	assert_eq(GameState.run_stats.weapon_kills[&"voodoo_nadel"], 299)
	assert_false(challenge.is_met(_ctx()), "Kill mit anderer Waffe zählt nicht")
	Events.enemy_killed.emit(SCHATTENLING, Vector2.ZERO, DamageInfo.create(1, false, 0.0, needle))
	assert_true(challenge.is_met(_ctx()))
	Unlocks.evaluate_run_end(false)
	assert_eq(SaveManager.get_stat(SaveManager.weapon_kills_key(&"voodoo_nadel")), 300)


func test_gewaechshauslampe_total_crystals() -> void:
	var challenge: ChallengeData = _challenge("gewaechshauslampe")
	SaveManager.add_stat(SaveManager.STAT_CRYSTALS, 45)
	for i in 4:
		Events.crystal_destroyed.emit(Vector2.ZERO)
	assert_false(challenge.is_met(_ctx()))
	Events.crystal_destroyed.emit(Vector2.ZERO)
	assert_true(challenge.is_met(_ctx()))


func test_smartbulb_total_sparks() -> void:
	var challenge: ChallengeData = _challenge("smartbulb")
	SaveManager.add_stat(SaveManager.STAT_TOTAL_SPARKS, 4990)
	GameState.total_sparks_collected = 9
	assert_false(challenge.is_met(_ctx()))
	GameState.total_sparks_collected = 10
	assert_true(challenge.is_met(_ctx()))


func test_drohnenleuchte_towers_at_run_end_win_or_lose() -> void:
	var challenge: ChallengeData = _challenge("drohnenleuchte")
	GameState.run_stats.current_turrets = 5
	assert_false(challenge.is_met(_ctx()), "nur am Run-Ende")
	assert_true(challenge.is_met(_ctx(true, false)), "auch bei Niederlage")
	assert_true(challenge.is_met(_ctx(true, true)))
	GameState.run_stats.current_turrets = 4
	assert_false(challenge.is_met(_ctx(true, true)))


func test_stroboskop_wave_without_dodge_items() -> void:
	var challenge: ChallengeData = _challenge("stroboskop")
	GameState.current_wave = 15
	GameState.add_item(load("res://data/items/vorschaltgeraet.tres"))
	assert_true(challenge.is_met(_ctx()), "Vorschaltgerät senkt Ausweichen und zählt nicht")
	GameState.add_item(load("res://data/items/staubtuch.tres"))
	assert_true(GameState.run_stats.dodge_item_taken)
	assert_false(challenge.is_met(_ctx()))
	GameState.start_run(63)
	GameState.current_wave = 14
	assert_false(challenge.is_met(_ctx()))


func test_vampirbirne_lifesteal_healing() -> void:
	var challenge: ChallengeData = _challenge("vampirbirne")
	GameState.run_stats.lifesteal_healed = 199.0
	assert_false(challenge.is_met(_ctx()))
	GameState.run_stats.lifesteal_healed = 200.0
	assert_true(challenge.is_met(_ctx()))


func test_spiegelkugel_six_same_weapons_at_wave_end() -> void:
	var challenge: ChallengeData = _challenge("spiegelkugel")
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var shard: WeaponData = load("res://data/weapons/glasscherbe.tres")
	for i in 5:
		player.weapon_slots.add_weapon(shard, 1 + i % 2)
	player.weapon_slots.add_weapon(load("res://data/weapons/ast.tres"))
	Events.wave_ended.emit(1)
	assert_eq(GameState.run_stats.max_same_weapons, 5)
	assert_false(challenge.is_met(_ctx()))
	player.weapon_slots.remove_weapon(player.weapon_slots.get_weapons()[5])
	player.weapon_slots.add_weapon(shard, 3)
	Events.wave_ended.emit(2)
	assert_true(challenge.is_met(_ctx()), "gleiche Waffe in beliebigem Tier")


# --- Fortschritt und Debug ---

func test_progress_best_for_run_and_sum_for_total() -> void:
	GameState.run_stats.enemies_killed = 312
	Unlocks.check(false, false)
	assert_eq(Unlocks.progress_text(_char("irrlicht")), "312/500")
	GameState.start_run(64)
	GameState.run_stats.enemies_killed = 100
	Unlocks.check(false, false)
	assert_eq(Unlocks.progress_text(_char("irrlicht")), "312/500", "Bestwert bleibt")
	SaveManager.add_stat(SaveManager.STAT_CRYSTALS, 12)
	assert_eq(Unlocks.progress_text(_char("gewaechshauslampe")), "12/50")


func test_run_end_progress_only_recorded_at_run_end() -> void:
	GameState.run_stats.current_turrets = 4
	Unlocks.check(false, false)
	assert_eq(Unlocks.progress_text(_char("drohnenleuchte")), "0/5", "Türme während des Runs zählen nicht")
	Unlocks.evaluate_run_end(false)
	assert_eq(Unlocks.progress_text(_char("drohnenleuchte")), "4/5")


func test_completed_challenge_unlocks_character_and_shows_full_progress() -> void:
	GameState.run_stats.lifesteal_healed = 250.0
	var completed: Array[ChallengeData] = Unlocks.check(false, false)
	assert_has(completed, _challenge("vampirbirne"))
	assert_true(Unlocks.is_unlocked(_char("vampirbirne")))
	assert_eq(Unlocks.progress_text(_char("vampirbirne")), "200/200")


func test_debug_unlocks_all_characters() -> void:
	Unlocks.unlock_all_characters()
	for c: CharacterData in Unlocks.all_characters():
		assert_true(Unlocks.is_unlocked(c), String(c.id))
	assert_false(SaveManager.is_challenge_completed(&"unlock_irrlicht"), "Challenges bleiben offen")


func test_run_save_keeps_new_counters() -> void:
	var run: RunStats = GameState.run_stats
	run.weapon_kills[&"voodoo_nadel"] = 42
	run.crystals_destroyed = 7
	run.dodge_item_taken = true
	run.max_same_weapons = 4
	var restored: RunStats = RunStats.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	assert_eq(restored.weapon_kills[&"voodoo_nadel"], 42)
	assert_eq(restored.crystals_destroyed, 7)
	assert_true(restored.dodge_item_taken)
	assert_eq(restored.max_same_weapons, 4)
