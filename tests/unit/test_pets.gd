extends GutTest
## Phase 15, Paket 8: Begleiter. Daten mit Tiers I-IV, höchstens 2 gleichzeitig, Kombinieren wie Waffen,
## Ersetzen mit Rückfrage und 25 % Rückgabe, Shop-Angebote und Fortsetzen-Stand, Verbündeten-Ebene (kein Gegnerlimit),
## Verhalten der fünf Begleiter und Herkunft in der Run-Statistik.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/projectile.tscn")
const ENEMY_PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/enemy_projectile.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/pickups/pickup.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const CONFIG: PetConfig = preload("res://data/config/pet_config.tres")
const SHOP_CONFIG: ShopConfig = preload("res://data/config/shop_config.tres")
const PET_IDS: Array[String] = ["leuchtkaefer", "funkenspatz", "schildkroete", "igel", "mini_birne"]
const ALLY_LAYER: int = 1 << 7
const OFFER_DRAWS: int = 4000
const STEP: float = 1.0 / 60.0

var _container: Node2D


func before_each() -> void:
	GameState.start_run(41)
	GameState.phase = GameState.Phase.WAVE
	_container = Node2D.new()
	add_child_autofree(_container)


func after_each() -> void:
	GameState.phase = GameState.Phase.WAVE


func _pet(id: String) -> PetData:
	return load("res://data/pets/%s.tres" % id)


func _player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.rng = RandomNumberGenerator.new()
	_container.add_child(player)
	return player


func _pool(scene: PackedScene, group: StringName) -> ObjectPool:
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = scene
	pool.group_name = group
	add_child_autofree(pool)
	return pool


func _enemy(player: Player, at: Vector2, hp: float = 200.0) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	_container.add_child(enemy)
	var data: EnemyData = SCHATTENLING.duplicate()
	data.base_hp = hp
	enemy.setup(data)
	enemy.activate(1, at, player, Rect2(), player.rng)
	enemy.set_physics_process(false)
	return enemy


func _run(pet: Pet, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		pet._physics_process(STEP)


# --- Daten ---

func test_all_pets_have_four_tiers_texture_and_texts() -> void:
	var pets: Array[Resource] = DataRegistry.get_all("pets")
	assert_eq(pets.size(), PET_IDS.size())
	for id: String in PET_IDS:
		var pet: PetData = _pet(id)
		assert_eq(String(pet.id), id)
		assert_eq(pet.tiers.size(), WeaponData.MAX_TIER, "Tiers I-IV: " + id)
		assert_not_null(pet.texture, id)
		assert_not_null(pet.behavior, id)
		assert_ne(tr(pet.name_key), pet.name_key, "Name übersetzt: " + id)
		assert_ne(tr(pet.lore_text), pet.lore_text, "Spruch übersetzt: " + id)
		for tier: int in range(WeaponData.MIN_TIER, WeaponData.MAX_TIER):
			assert_gt(pet.get_tier(tier + 1).price, pet.get_tier(tier).price, "Preis steigt mit dem Tier: " + id)
		assert_null(RegEx.create_from_string("%[sd]").search(pet.get_description(1)), "Beschreibung ohne offene Platzhalter: " + id)


func test_firefly_and_hedgehog_match_the_spec() -> void:
	var firefly: PetTierStats = _pet("leuchtkaefer").get_tier(1)
	assert_eq(firefly.base_damage, 4.0)
	assert_eq(firefly.scalings.get(Stats.RANGED_DMG, 0.0), 0.5)
	assert_eq(firefly.cooldown, 1.0)
	var hedgehog: PetTierStats = _pet("igel").get_tier(1)
	assert_eq(hedgehog.base_damage, 8.0)
	assert_eq(hedgehog.scalings.get(Stats.MELEE_DMG, 0.0), 0.6)
	assert_eq(_pet("funkenspatz").get_tier(1).radius, 300.0)
	assert_eq(_pet("schildkroete").get_tier(1).cooldown, 3.0)
	assert_eq(_pet("mini_birne").get_tier(1).damage_factor, 0.25)


# --- Plätze, Kombinieren, Ersetzen ---

func test_at_most_two_pets() -> void:
	var player: Player = _player()
	assert_not_null(player.pet_slots.add_pet(_pet("igel")))
	assert_not_null(player.pet_slots.add_pet(_pet("funkenspatz")))
	assert_eq(CONFIG.max_pets, 2)
	assert_true(player.pet_slots.is_full())
	assert_null(player.pet_slots.add_pet(_pet("leuchtkaefer")), "dritter Begleiter passt nicht")
	assert_false(player.pet_slots.can_accept(_pet("leuchtkaefer"), 1))
	assert_eq(get_tree().get_nodes_in_group(Pet.GROUP).size(), 2)


func test_two_equal_pets_combine_to_next_tier() -> void:
	var player: Player = _player()
	var first: Pet = player.pet_slots.add_pet(_pet("igel"), 2)
	player.pet_slots.add_pet(_pet("igel"), 2)
	var combined: Pet = player.pet_slots.combine(first)
	assert_not_null(combined)
	assert_eq(combined.tier, 3)
	assert_eq(player.pet_slots.get_pets().size(), 1)


func test_buying_into_full_slots_combines_automatically() -> void:
	var player: Player = _player()
	player.pet_slots.add_pet(_pet("igel"), 1)
	player.pet_slots.add_pet(_pet("funkenspatz"), 1)
	assert_true(player.pet_slots.can_accept(_pet("igel"), 1), "gleicher Begleiter gleichen Tiers kombiniert")
	var pet: Pet = player.pet_slots.add_or_combine(_pet("igel"), 1)
	assert_eq(pet.tier, 2)
	assert_eq(player.pet_slots.get_pets().size(), 2)


func test_tier_four_does_not_combine() -> void:
	var player: Player = _player()
	var first: Pet = player.pet_slots.add_pet(_pet("igel"), 4)
	player.pet_slots.add_pet(_pet("igel"), 4)
	assert_null(player.pet_slots.combine(first))


func _shop_screen(player: Player) -> ShopScreen:
	var screen: ShopScreen = ShopScreen.new()
	add_child_autofree(screen)
	screen.player = player
	GameState.phase = GameState.Phase.SHOP
	screen.open()
	return screen


func test_shop_asks_which_pet_to_replace_and_refunds() -> void:
	var player: Player = _player()
	var igel: Pet = player.pet_slots.add_pet(_pet("igel"), 1)
	player.pet_slots.add_pet(_pet("funkenspatz"), 1)
	GameState.current_wave = 3
	var screen: ShopScreen = _shop_screen(player)
	var ctx: ShopContext = ShopContext.from_run(player)
	GameState.shop.place_offer(0, null, null, 2, ctx, _pet("leuchtkaefer"))
	var price: int = GameState.shop.offers[0].price
	GameState.sparks = 500
	screen.call("_on_buy", 0)
	assert_true(screen.is_replace_dialog_open(), "dritter Begleiter: Rückfrage statt Kauf")
	assert_eq(GameState.sparks, 500, "noch nichts bezahlt")
	var refund: int = screen.pet_recycle_value(igel)
	var expected: int = Economy.recycle_value(Economy.inflated_price(igel.get_tier_stats().price, 3, 0.0), CONFIG.recycle_share, 0.0)
	assert_eq(refund, expected, "Rückgabe 25 % des aktuellen Preises")
	screen.call("_on_replace", 0, igel)
	assert_false(screen.is_replace_dialog_open())
	assert_eq(GameState.sparks, 500 - price + refund)
	var ids: Array[StringName] = []
	for pet: Pet in player.pet_slots.get_pets():
		ids.append(pet.data.id)
	assert_true(&"leuchtkaefer" in ids)
	assert_false(&"igel" in ids, "der gewählte Begleiter ist ersetzt")
	assert_true(GameState.shop.offers[0].sold)


func test_shop_replace_dialog_can_be_cancelled() -> void:
	var player: Player = _player()
	player.pet_slots.add_pet(_pet("igel"), 1)
	player.pet_slots.add_pet(_pet("funkenspatz"), 1)
	var screen: ShopScreen = _shop_screen(player)
	GameState.shop.place_offer(1, null, null, 1, ShopContext.from_run(player), _pet("mini_birne"))
	GameState.sparks = 300
	screen.call("_on_buy", 1)
	assert_true(screen.is_replace_dialog_open())
	screen.call("_on_replace_cancel", 1)
	assert_false(screen.is_replace_dialog_open())
	assert_eq(GameState.sparks, 300)
	assert_eq(player.pet_slots.get_pets().size(), 2)
	assert_false(GameState.shop.offers[1].sold)


func test_shop_buy_with_free_slot_adds_pet() -> void:
	var player: Player = _player()
	var screen: ShopScreen = _shop_screen(player)
	GameState.shop.place_offer(0, null, null, 1, ShopContext.from_run(player), _pet("schildkroete"))
	GameState.sparks = 300
	screen.call("_on_buy", 0)
	assert_eq(player.pet_slots.get_pets().size(), 1)
	assert_false(screen.is_replace_dialog_open())


# --- Shop-Angebote und Speichern ---

func test_shop_offers_pets_at_configured_share() -> void:
	var shop: Shop = Shop.create_from_registry()
	var ctx: ShopContext = ShopContext.new()
	ctx.wave = 6
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = 9
	var pets: int = 0
	var weapons: int = 0
	for i in OFFER_DRAWS:
		var offer: ShopOffer = shop.generate_offer(ctx, {})
		if offer.is_pet():
			pets += 1
			assert_eq(offer.price, Economy.inflated_price(offer.pet.get_tier(offer.tier).price, ctx.wave, 0.0))
		elif offer.is_weapon():
			weapons += 1
	assert_almost_eq(float(pets) / OFFER_DRAWS, CONFIG.offer_chance, 0.02)
	assert_almost_eq(float(weapons) / OFFER_DRAWS, SHOP_CONFIG.weapon_offer_chance, 0.03, "Waffenanteil bleibt")


func test_shop_save_keeps_pet_offer() -> void:
	var player: Player = _player()
	var ctx: ShopContext = ShopContext.from_run(player)
	GameState.shop.open_shop(ctx)
	GameState.shop.place_offer(3, null, null, 3, ctx, _pet("igel"))
	var restored: Shop = Shop.create_from_registry()
	restored.load_dict(GameState.shop.to_dict())
	assert_eq(restored.offers[3].pet, _pet("igel"))
	assert_eq(restored.offers[3].tier, 3)


func test_run_save_restores_pets() -> void:
	var player: Player = _player()
	GameState.character = load("res://data/characters/standardbirne.tres")
	player.apply_character(GameState.character)
	player.pet_slots.add_pet(_pet("igel"), 3)
	player.pet_slots.add_pet(_pet("mini_birne"), 2)
	var data: Dictionary = RunSave.capture(player)
	var copy: Player = _player()
	RunSave.apply_to_player(data, copy)
	var restored: Array[Pet] = copy.pet_slots.get_pets()
	assert_eq(restored.size(), 2)
	assert_eq(restored[0].data.id, &"igel")
	assert_eq(restored[0].tier, 3)
	assert_eq(restored[1].tier, 2)


# --- Ebene, Folgen, Ausweichen ---

func test_pets_are_allies_not_targets() -> void:
	var player: Player = _player()
	var pet: Pet = player.pet_slots.add_pet(_pet("igel"))
	assert_eq(pet.collision_layer, ALLY_LAYER, "Verbündeten-Ebene")
	assert_false(pet.is_in_group(Damageable.GROUP), "Waffen zielen nicht darauf, kein Gegnerlimit")


func test_pets_follow_with_delay_and_keep_apart() -> void:
	var player: Player = _player()
	var first: Pet = player.pet_slots.add_pet(_pet("funkenspatz"))
	var second: Pet = player.pet_slots.add_pet(_pet("schildkroete"))
	GameState.phase = GameState.Phase.SHOP
	player.global_position = Vector2(1000, 0)
	var start: float = first.global_position.distance_to(first.rest_point())
	first._physics_process(STEP)
	assert_lt(first.global_position.distance_to(first.rest_point()), start - 1.0, "holt auf")
	assert_gt(first.global_position.distance_to(first.rest_point()), start * 0.5, "aber mit Verzögerung")
	for i in 240:
		first._physics_process(STEP)
		second._physics_process(STEP)
	assert_lt(first.global_position.distance_to(first.rest_point()), 20.0, "kommt am Ruheplatz an")
	second.global_position = first.global_position
	second._physics_process(STEP)
	assert_gte(first.global_position.distance_to(second.global_position), CONFIG.separation_distance * 0.5 - 0.01,
		"weichen sich aus")


# --- Verhalten ---

func test_firefly_shoots_with_pet_origin() -> void:
	var player: Player = _player()
	var pool: ObjectPool = _pool(PROJECTILE_SCENE, Pools.PLAYER_PROJECTILES)
	var pet: Pet = player.pet_slots.add_pet(_pet("leuchtkaefer"))
	_enemy(player, pet.global_position + Vector2(200, 0))
	_run(pet, 0.1)
	assert_eq(pool.active_count(), 1, "ein Schuss")
	var projectile: Projectile = pool.get_active()[0] as Projectile
	var info: DamageInfo = projectile.get("_spec").info
	assert_eq(info.origin, DamageSource.pet(&"leuchtkaefer"))
	assert_eq(info.amount, 4, "4 (+50 % Fern) ohne Fern-Stat")
	_run(pet, 0.5)
	assert_eq(pool.active_count(), 1, "Abklingzeit 1 s")
	_run(pet, 0.55)
	assert_eq(pool.active_count(), 2, "nach 1 s der nächste Schuss")


func test_hedgehog_rolls_into_enemy_and_counts_for_pet() -> void:
	var player: Player = _player()
	var pet: Pet = player.pet_slots.add_pet(_pet("igel"))
	var enemy: Enemy = _enemy(player, player.global_position + Vector2(150, 0))
	var hp: float = enemy.hp
	_run(pet, 1.0)
	assert_lt(enemy.hp, hp, "Igel rammt den Gegner")
	assert_gt(GameState.run_stats.damage_of(DamageSource.pet(&"igel")), 0, "Schaden zählt für den Igel")


func test_hedgehog_ignores_enemies_far_from_player() -> void:
	var player: Player = _player()
	var pet: Pet = player.pet_slots.add_pet(_pet("igel"))
	var enemy: Enemy = _enemy(player, player.global_position + Vector2(1500, 0))
	var hp: float = enemy.hp
	_run(pet, 1.0)
	assert_eq(enemy.hp, hp)
	assert_lt(pet.global_position.distance_to(pet.rest_point()), 50.0, "bleibt beim Spieler")


func test_sparrow_pulls_sparks_in_radius() -> void:
	var player: Player = _player()
	var pool: ObjectPool = _pool(PICKUP_SCENE, Pools.PICKUPS)
	var pet: Pet = player.pet_slots.add_pet(_pet("funkenspatz"))
	var near: Vector2 = pet.get_center() + Vector2(250, 0)
	var far: Vector2 = pet.get_center() + Vector2(2000, 0)
	var spark: Pickup = pool.acquire() as Pickup
	spark.drop(Pickup.Kind.SPARK, 1, near, near, player)
	var distant: Pickup = pool.acquire() as Pickup
	distant.drop(Pickup.Kind.SPARK, 1, far, far, player)
	_run(pet, 0.2)
	assert_false(spark.can_attract(), "Funke im Umkreis fliegt zum Spieler")
	assert_true(distant.can_attract(), "Funke außerhalb bleibt liegen")
	assert_eq(GameState.run_stats.pet_events_of(DamageSource.pet(&"funkenspatz")), 1)


func test_turtle_blocks_one_projectile_per_cooldown() -> void:
	var player: Player = _player()
	var pool: ObjectPool = _pool(ENEMY_PROJECTILE_SCENE, Pools.ENEMY_PROJECTILES)
	var pet: Pet = player.pet_slots.add_pet(_pet("schildkroete"))
	var first: EnemyProjectile = pool.acquire() as EnemyProjectile
	first.launch(player.get_center() + Vector2(100, 0), Vector2.LEFT, 0.0, 1000.0, 3.0, null)
	var second: EnemyProjectile = pool.acquire() as EnemyProjectile
	second.launch(player.get_center() + Vector2(0, 120), Vector2.UP, 0.0, 1000.0, 3.0, null)
	_run(pet, 0.1)
	assert_false(first.is_active(), "nächstes Projektil geblockt")
	assert_true(second.is_active(), "nur eins pro Abklingzeit")
	_run(pet, 3.0)
	assert_false(second.is_active(), "nach 3 s das nächste")
	assert_eq(GameState.run_stats.pet_events_of(DamageSource.pet(&"schildkroete")), 2)


func test_mini_bulb_copies_first_weapon_and_follows_changes() -> void:
	var player: Player = _player()
	var pistol: Weapon = player.weapon_slots.add_weapon(load("res://data/weapons/funkenpistole.tres"), 2)
	var pet: Pet = player.pet_slots.add_pet(_pet("mini_birne"))
	var copy: Weapon = PetWeaponCopyBehavior.copy_of(pet)
	assert_not_null(copy)
	assert_eq(copy.data.id, &"funkenpistole")
	assert_eq(copy.tier, 2)
	assert_true(copy.is_clone, "kein Lebensraub, keine Angriffs-Effekte")
	assert_eq(copy.damage_factor, 0.25)
	assert_eq(copy.get_origin(), DamageSource.pet(&"mini_birne"))
	player.weapon_slots.remove_weapon(pistol)
	assert_null(PetWeaponCopyBehavior.copy_of(pet), "ohne Waffen keine Kopie")
	player.weapon_slots.add_weapon(load("res://data/weapons/ast.tres"), 1)
	player.weapon_slots.add_weapon(load("res://data/weapons/prisma.tres"), 3)
	copy = PetWeaponCopyBehavior.copy_of(pet)
	assert_eq(copy.data.id, &"ast", "immer die aktuell erste Waffe")
	var slots: WeaponSlots = pet.state[PetWeaponCopyBehavior.SLOTS_KEY]
	assert_eq(slots.get_child_count(), 1, "keine doppelten Kopien")
	await get_tree().process_frame


func test_mini_bulb_tier_raises_damage_factor() -> void:
	var player: Player = _player()
	player.weapon_slots.add_weapon(load("res://data/weapons/funkenpistole.tres"), 1)
	var pet: Pet = player.pet_slots.add_pet(_pet("mini_birne"), 4)
	assert_eq(PetWeaponCopyBehavior.copy_of(pet).damage_factor, 0.7)


func test_mini_bulb_kills_do_not_count_as_weapon_kills() -> void:
	var player: Player = _player()
	player.weapon_slots.add_weapon(load("res://data/weapons/funkenpistole.tres"), 1)
	var pet: Pet = player.pet_slots.add_pet(_pet("mini_birne"))
	var copy: Weapon = PetWeaponCopyBehavior.copy_of(pet)
	var info: DamageInfo = DamageInfo.create(5, false, 0.0, copy, copy.get_origin())
	Events.enemy_killed.emit(SCHATTENLING, Vector2.ZERO, info)
	assert_eq(GameState.run_stats.kills_of(DamageSource.pet(&"mini_birne")), 1)
	assert_false(GameState.run_stats.weapon_kills.has(&"funkenpistole"), "zählt nicht für Waffen-Freischaltungen")


func test_pets_idle_outside_waves() -> void:
	var player: Player = _player()
	var pool: ObjectPool = _pool(PROJECTILE_SCENE, Pools.PLAYER_PROJECTILES)
	var pet: Pet = player.pet_slots.add_pet(_pet("leuchtkaefer"))
	_enemy(player, pet.global_position + Vector2(200, 0))
	GameState.phase = GameState.Phase.SHOP
	_run(pet, 0.5)
	assert_eq(pool.active_count(), 0, "im Shop schießt kein Begleiter")


# --- Anzeige ---

func test_run_report_and_tooltip_know_pets() -> void:
	var player: Player = _player()
	var pet: Pet = player.pet_slots.add_pet(_pet("igel"), 2)
	var origin: StringName = pet.get_origin()
	GameState.run_stats.record_damage(origin, 120)
	GameState.run_stats.record_kill(origin)
	assert_eq(RunReport.source_name(origin), tr("PET_IGEL"))
	assert_eq(RunReport.source_icon(origin), pet.data.texture)
	assert_eq(RunReport.kind_name(DamageSource.PET), tr("RUN_STATS_KIND_PET"))
	var text: String = TooltipText.pet(pet)
	assert_string_contains(text, tr("PET_IGEL"))
	assert_string_contains(text, TextFormat.t("TIP_RUN") % [1, 120])


func test_build_overview_lists_pets() -> void:
	var player: Player = _player()
	player.pet_slots.add_pet(_pet("igel"))
	var overview: BuildOverview = BuildOverview.new(player)
	add_child_autofree(overview)
	assert_eq(overview.icons.size(), 1, "keine Waffen, keine Items, ein Begleiter")


func test_pets_leave_with_player() -> void:
	var player: Player = _player()
	player.pet_slots.add_pet(_pet("igel"))
	player.pet_slots.add_pet(_pet("funkenspatz"))
	_container.remove_child(player)
	player.free()
	await get_tree().process_frame
	assert_eq(get_tree().get_nodes_in_group(Pet.GROUP).size(), 0)
