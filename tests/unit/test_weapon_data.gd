extends GutTest
## Prüft die Startwaffen-Resources gegen GDD Abschnitt 8.

const START_WEAPONS: PackedStringArray = ["funkenpistole", "glasscherbe", "ast", "funkenfaust"]


func _load(id: String) -> WeaponData:
	return load("res://data/weapons/%s.tres" % id) as WeaponData


func test_all_start_weapons_exist_with_four_tiers() -> void:
	for id: String in START_WEAPONS:
		var w: WeaponData = _load(id)
		assert_not_null(w, id)
		assert_eq(w.tiers.size(), WeaponData.MAX_TIER, id)
		assert_not_null(w.texture, id)
		assert_ne(tr(w.name_key), w.name_key, "Übersetzung fehlt: " + w.name_key)


func test_tier_one_values_match_gdd() -> void:
	var pistol: WeaponTierStats = _load("funkenpistole").get_tier(1)
	assert_eq(pistol.base_damage, 12.0)
	assert_eq(pistol.cooldown, 1.2)
	assert_eq(pistol.range, 400.0)
	assert_eq(pistol.piercing, 1)
	var shard: WeaponTierStats = _load("glasscherbe").get_tier(1)
	assert_eq(shard.crit_chance, 0.2)
	assert_eq(shard.crit_multiplier, 2.5)
	assert_eq(shard.scalings[Stats.MELEE_DMG], 0.8)
	assert_eq(_load("funkenfaust").get_tier(1).knockback, 15.0)
	assert_eq(_load("ast").damage_per_same_weapon, 1.0)


func test_tier_rule_of_thumb() -> void:
	var pistol: WeaponData = _load("funkenpistole")
	assert_eq(pistol.get_tier(2).base_damage, 18.0, "T2 x1,5 Schaden")
	assert_almost_eq(pistol.get_tier(4).cooldown, 1.2 * 0.78, 0.01, "T4 x0,78 Abklingzeit")
	assert_eq(pistol.get_tier(3).price, 90, "T3 Preis x3,6")


func test_get_tier_clamps() -> void:
	var w: WeaponData = _load("ast")
	assert_eq(w.get_tier(0), w.tiers[0])
	assert_eq(w.get_tier(9), w.tiers[3])


func test_registry_loads_weapons() -> void:
	assert_eq(DataRegistry.get_all("weapons").size(), 22)
