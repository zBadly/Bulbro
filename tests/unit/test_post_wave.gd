extends GutTest
## Tests für den Ablauf nach der Welle: State Machine, Kartons, Level-ups, Seltenheit, Item-Auswahl.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const RARITY: RarityConfig = preload("res://data/config/rarity_config.tres")

var _phases: Array[int] = []


func before_each() -> void:
	GameState.start_run(5)
	GameState.current_wave = 3
	_phases.clear()
	Events.run_phase_changed.connect(_on_phase)


func after_each() -> void:
	Events.run_phase_changed.disconnect(_on_phase)


func _on_phase(phase: int) -> void:
	_phases.append(phase)


func _player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


func _all_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for res: Resource in DataRegistry.get_all("items"):
		items.append(res as ItemData)
	return items


# State Machine
func test_post_wave_order_crates_then_level_ups_then_shop() -> void:
	GameState.pending_crates = 2
	GameState.pending_level_ups = 1
	GameState.advance_post_wave()
	GameState.finish_crate()
	GameState.finish_crate()
	GameState.finish_level_up()
	assert_eq(_phases, [GameState.Phase.CRATES, GameState.Phase.CRATES, GameState.Phase.LEVEL_UP, GameState.Phase.SHOP])


func test_no_pending_goes_straight_to_shop() -> void:
	GameState.advance_post_wave()
	assert_eq(GameState.phase, GameState.Phase.SHOP)


func test_level_being_upgraded_counts_up() -> void:
	GameState.level = 6
	GameState.pending_level_ups = 2
	assert_eq(GameState.level_being_upgraded(), 5)


# Seltenheit
func test_tier_unlocks_by_wave() -> void:
	assert_eq(Rarity.tier_chance(2, 1, 0.0, RARITY), 0.0, "Tier II erst ab Shop 2")
	assert_gt(Rarity.tier_chance(2, 2, 0.0, RARITY), 0.0)
	assert_eq(Rarity.tier_chance(3, 3, 0.0, RARITY), 0.0, "Tier III erst ab Shop 4")
	assert_gt(Rarity.tier_chance(3, 4, 0.0, RARITY), 0.0)
	assert_eq(Rarity.tier_chance(4, 7, 0.0, RARITY), 0.0, "Tier IV erst ab Shop 8")
	assert_gt(Rarity.tier_chance(4, 8, 0.0, RARITY), 0.0)


func test_tier_caps() -> void:
	assert_almost_eq(Rarity.tier_chance(2, 50, 200.0, RARITY), 0.6, 0.0001)
	assert_almost_eq(Rarity.tier_chance(3, 50, 200.0, RARITY), 0.25, 0.0001)


func test_luck_raises_chances() -> void:
	assert_gt(Rarity.tier_chance(2, 3, 100.0, RARITY), Rarity.tier_chance(2, 3, 0.0, RARITY))


func test_guaranteed_level_up_tiers() -> void:
	assert_eq(Rarity.guaranteed_tier(4, RARITY), 1)
	assert_eq(Rarity.guaranteed_tier(5, RARITY), 2)
	assert_eq(Rarity.guaranteed_tier(10, RARITY), 3)
	assert_eq(Rarity.guaranteed_tier(20, RARITY), 3)
	assert_eq(Rarity.guaranteed_tier(25, RARITY), 4)
	assert_eq(Rarity.guaranteed_tier(27, RARITY), 1)
	assert_eq(Rarity.guaranteed_tier(30, RARITY), 4)


# Items und Upgrades
func test_pick_item_respects_limit_and_falls_back() -> void:
	var items: Array[ItemData] = [
		load("res://data/items/kernreaktor.tres") as ItemData,
		load("res://data/items/ueberspannung.tres") as ItemData,
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var owned: Dictionary[StringName, int] = {&"kernreaktor": 1}
	for i in 50:
		var item: ItemData = Loot.pick_item(items, 4, owned, [], 1.0, rng)
		assert_ne(item.id, &"kernreaktor", "Limit 1 erreicht")
		assert_eq(item.tier, 3, "fällt auf Tier III zurück")


func test_preferred_tags_are_weighted() -> void:
	var items: Array[ItemData] = _all_items()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var hp_count: int = 0
	var draws: int = 2000
	for i in draws:
		if &"hp" in Loot.pick_item(items, 1, {}, [&"hp"], 10.0, rng).tags:
			hp_count += 1
	assert_gt(hp_count, draws / 2, "hp-Item deutlich häufiger als 1 von 4")


func test_upgrade_tier_values_from_gdd() -> void:
	var dmg: UpgradeData = load("res://data/upgrades/damage_pct.tres")
	assert_eq(dmg.value_for_tier(1), 5.0)
	assert_eq(dmg.value_for_tier(4), 16.0)
	var rng_up: UpgradeData = load("res://data/upgrades/range.tres")
	assert_eq(rng_up.value_for_tier(3), 45.0)
	assert_eq(DataRegistry.get_all("upgrades").size(), 16)


func test_pick_upgrades_are_distinct() -> void:
	var upgrades: Array[UpgradeData] = []
	for res: Resource in DataRegistry.get_all("upgrades"):
		upgrades.append(res as UpgradeData)
	var picks: Array[UpgradeData] = Loot.pick_upgrades(upgrades, 4, RandomNumberGenerator.new())
	assert_eq(picks.size(), 4)
	var ids: Dictionary = {}
	for u: UpgradeData in picks:
		ids[u.id] = true
	assert_eq(ids.size(), 4)


# Bildschirme
func test_crate_take_applies_item() -> void:
	var player: Player = _player()
	var screen: CrateScreen = CrateScreen.new()
	screen.player = player
	add_child_autofree(screen)
	GameState.pending_crates = 1
	screen.open()
	var before: int = GameState.items.size()
	screen.call("_on_take")
	await wait_physics_frames(2)
	assert_eq(GameState.items.size(), before + 1)
	assert_eq(GameState.pending_crates, 0)
	assert_eq(GameState.phase, GameState.Phase.SHOP)


func test_crate_recycle_gives_quarter_price() -> void:
	var player: Player = _player()
	var screen: CrateScreen = CrateScreen.new()
	screen.player = player
	add_child_autofree(screen)
	GameState.pending_crates = 1
	screen.open()
	var expected: int = screen.get("_recycle_value")
	screen.call("_on_recycle")
	assert_eq(GameState.sparks, expected)
	assert_eq(GameState.items.size(), 0)


func test_level_up_choice_adds_stat() -> void:
	var player: Player = _player()
	var screen: LevelUpScreen = LevelUpScreen.new()
	screen.player = player
	add_child_autofree(screen)
	GameState.level = 1
	GameState.pending_level_ups = 1
	screen.open()
	screen.call("_on_choose", StatModifier.create(Stats.ARMOR, 2.0))
	await wait_physics_frames(2)
	assert_eq(player.stats.get_stat(Stats.ARMOR), 2.0)
	assert_eq(GameState.pending_level_ups, 0)


func test_level_up_reroll_costs_sparks() -> void:
	var player: Player = _player()
	var screen: LevelUpScreen = LevelUpScreen.new()
	screen.player = player
	add_child_autofree(screen)
	GameState.level = 1
	GameState.pending_level_ups = 1
	GameState.add_sparks(100)
	screen.open()
	var price: int = screen.call("_reroll_price")
	screen.call("_on_reroll")
	assert_eq(GameState.sparks, 100 - price)
	assert_gt(screen.call("_reroll_price"), price, "nächster Reroll teurer")


# Preise
func test_inflation_and_reroll_prices() -> void:
	assert_eq(Economy.inflated_price(20, 0, 0.0), 20)
	assert_eq(Economy.inflated_price(20, 5, 0.0), 20 + 5 * 3)
	assert_eq(Economy.inflated_price(20, 5, -50.0), 18)
	assert_eq(Economy.reroll_price(4, 0, 0.5, 0.0), 6, "Welle 4 + Zuschlag 2")
	assert_eq(Economy.reroll_price(4, 1, 0.5, 0.0), 8)
	assert_eq(Economy.recycle_value(30, 0.25), 7)
