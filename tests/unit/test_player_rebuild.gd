extends GutTest
## Regression Paket 3 (Admin-Modus): Player.rebuild() muss exakt dieselben Werte ergeben wie der normale Aufbau
## im Run, darf Effekt-Knoten nicht doppelt erzeugen und laufende Run-Werte (Seelen, Trigger-Zustand) behalten.
## Seit Paket 8 auch Begleiter: gleiche Begleiter, keine doppelten Knoten, Mini-Birne mit genau einer Kopie.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ALLY_SCENE: PackedScene = preload("res://scenes/allies/ally.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
## Waffen in dieser Reihenfolge, soweit der Charakter sie tragen darf (Doppelte für Set-Boni).
const WEAPON_POOL: Array[String] = ["glasscherbe", "glasscherbe", "funkenpistole", "prisma", "kabelpeitsche",
	"ast", "loetkolben", "blitzwerfer", "schraubenzieher", "heilstrahl"]
const WEAPON_COUNT: int = 5
## Items mit Stats, X-Modifikationen, Trigger-, Pro-Waffe- und Umwandlungseffekten, dazu Einzigartige
## (Stat pro Stat/Level/Funken, Bonus unter X % HP, tödlichen Treffer überleben, nach N Kills).
const ITEMS: Array[String] = ["ersatzsicherung", "kupferdraht", "schmierfett", "glasfaser", "tesla_spule",
	"werkstattkoffer", "dynamo", "ersatzsicherung", "spiegelscherbe", "ladestation",
	"panzerglas", "leuchtturm", "sparlampe", "thermosicherung", "reservebatterie", "kondensator"]
const COMPARE_TOLERANCE: float = 0.0001
## Begleiter im normalen Aufbau (ID, Tier): Mini-Birne kopiert die erste Waffe, der Igel hat keinen Bezug zu Stats.
const PETS: Array[Array] = [["mini_birne", 2], ["igel", 1]]

## Eigener Elternknoten pro Test: Effekte hängen Drohnen/Spiegelbild an den Elternknoten des Spielers.
var _container: Node2D


func before_each() -> void:
	_container = Node2D.new()
	add_child_autofree(_container)
	GameState.character = null
	GameState.start_run(71)
	GameState.phase = GameState.Phase.SHOP


func after_each() -> void:
	GameState.phase = GameState.Phase.WAVE
	GameState.character = null


func _character(id: String) -> CharacterData:
	return load("res://data/characters/%s.tres" % id)


## Normaler Aufbau wie im Run: Charakter, Startwaffe(n), Items in Kaufreihenfolge, Level-ups.
func _build_normally(character: CharacterData) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.rng = RandomNumberGenerator.new()
	_container.add_child(player)
	GameState.character = character
	player.apply_character(character)
	var added: int = 0
	for id: String in WEAPON_POOL:
		var weapon: WeaponData = load("res://data/weapons/%s.tres" % id)
		if added < WEAPON_COUNT and character.can_use_weapon(weapon) and not player.weapon_slots.is_full():
			player.weapon_slots.add_weapon(weapon, 1 + added % 2)
			added += 1
	for id: String in ITEMS:
		var item: ItemData = load("res://data/items/%s.tres" % id)
		GameState.add_item(item)
		player.apply_item(item)
	for entry: Array in PETS:
		player.pet_slots.add_pet(load("res://data/pets/%s.tres" % entry[0]), entry[1])
	for i in 3:
		player.add_run_modifier(StatModifier.create(Stats.MAX_HP, player.config.max_hp_per_level))
	player.add_run_modifier(StatModifier.create(Stats.ARMOR, 2.0))
	player.add_run_modifier(StatModifier.create(Stats.ATTACK_SPEED, 10.0))
	return player


## Alle Werte, die den Spieler ausmachen.
func _snapshot(player: Player) -> Dictionary:
	var values: Dictionary = {}
	for stat: StringName in Stats.all():
		values[String(stat)] = player.stats.get_stat(stat)
	values["max_slots"] = player.weapon_slots.max_slots
	values["weapons"] = player.weapon_slots.get_weapons().size()
	values["rules"] = player.rules.keys().duplicate()
	values["lifesteal_factor"] = player.lifesteal_interval_factor
	values["class_bonuses"] = player.class_bonuses.size()
	values["per_weapon"] = player.per_weapon_effects.size()
	values["standing_still"] = player.standing_still_modifiers.size()
	values["set_mult"] = player.set_bonus_multiplier.duplicate()
	values["max_hp"] = player.get_max_hp()
	var effects: Array = []
	for entry: TriggerEntry in player.triggers:
		effects.append(entry.effect)
	values["triggers"] = effects
	var pets: Array = []
	for pet: Pet in player.pet_slots.get_pets():
		pets.append([String(pet.data.id), pet.tier, pet.slot_index])
	values["pets"] = pets
	values["pet_nodes"] = _pet_nodes(player)
	values["pet_copies"] = _pet_copies(player)
	return values


## Begleiter-Knoten dieses Spielers im Baum (ohne solche, die schon freigegeben werden).
func _pet_nodes(player: Player) -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(Pet.GROUP):
		if not node.is_queued_for_deletion() and (node as Pet).player == player:
			count += 1
	return count


## Waffenkopien der Mini-Birnen (genau eine pro Mini-Birne, solange der Spieler Waffen hat).
func _pet_copies(player: Player) -> int:
	var count: int = 0
	for pet: Pet in player.pet_slots.get_pets():
		var slots: WeaponSlots = pet.state.get(PetWeaponCopyBehavior.SLOTS_KEY) as WeaponSlots
		if slots != null:
			count += slots.get_child_count()
	return count


func _assert_same(actual: Dictionary, expected: Dictionary, context: String) -> void:
	for key: String in expected:
		var a: Variant = actual[key]
		var e: Variant = expected[key]
		if a is float:
			assert_almost_eq(a as float, e as float, COMPARE_TOLERANCE, "%s: %s" % [context, key])
		else:
			assert_eq(a, e, "%s: %s" % [context, key])


func test_rebuild_matches_normal_build_for_every_character() -> void:
	var characters: Array[CharacterData] = Unlocks.all_characters()
	assert_eq(characters.size(), 22)
	for character: CharacterData in characters:
		GameState.start_run(72)
		GameState.phase = GameState.Phase.SHOP
		var player: Player = _build_normally(character)
		var expected: Dictionary = _snapshot(player)
		player.rebuild()
		_assert_same(_snapshot(player), expected, "%s nach rebuild" % character.id)
		player.rebuild()
		player.rebuild()
		_assert_same(_snapshot(player), expected, "%s nach 3x rebuild" % character.id)
		player.queue_free()


func test_rebuild_keeps_hp_but_caps_it() -> void:
	var player: Player = _build_normally(_character("standardbirne"))
	player.take_hit(3.0)
	var hp: float = player.current_hp
	player.rebuild()
	assert_eq(player.current_hp, hp, "HP werden nicht aufgefüllt")
	GameState.items.clear()
	player.rebuild()
	assert_lte(player.current_hp, player.get_max_hp())


func test_removing_an_item_removes_its_stats_and_trigger() -> void:
	var player: Player = _build_normally(_character("standardbirne"))
	var tesla: ItemData = load("res://data/items/tesla_spule.tres")
	var before: int = player.triggers.filter(func(e: TriggerEntry) -> bool: return e.effect in tesla.effects).size()
	assert_eq(before, 1)
	GameState.items.erase(tesla)
	GameState.items.erase(load("res://data/items/kupferdraht.tres"))
	var elemental: float = player.stats.get_stat(Stats.ELEMENTAL_DMG)
	player.rebuild()
	assert_eq(player.triggers.filter(func(e: TriggerEntry) -> bool: return e.effect in tesla.effects).size(), 0)
	assert_lt(player.stats.get_stat(Stats.ELEMENTAL_DMG), elemental, "Kupferdraht entfernt")


# --- Effekt-Knoten und laufende Werte ---

func _start_wave(player: Player) -> EffectContext:
	GameState.phase = GameState.Phase.WAVE
	var ctx: EffectContext = EffectContext.create(player)
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_wave_started(ctx, entry)
	return ctx


func _count_children(script_name: StringName) -> int:
	var count: int = 0
	for child: Node in _container.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion() and child.get_script() != null \
				and (child.get_script() as Script).get_global_name() == script_name:
			count += 1
	return count


func test_repeated_rebuild_does_not_duplicate_drones_or_mirror() -> void:
	var player: Player = _build_normally(_character("drohnenleuchte"))
	var drone_item: ItemData = load("res://data/items/wartungsdrohne.tres")
	GameState.add_item(drone_item)
	player.apply_item(drone_item)
	var ctx: EffectContext = _start_wave(player)
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_wave_tick(ctx, entry, 0.1)
	var drones: int = _count_children(&"Structure")
	var expected_drones: int = 0
	for entry: TriggerEntry in player.triggers:
		if entry.effect is OrbitingDroneEffect:
			expected_drones += (entry.effect as OrbitingDroneEffect).drone_count(GameState.level)
	assert_eq(drones, expected_drones, "Drohnen vom Charakter + Wartungsdrohne")
	for i in 3:
		player.rebuild()
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_wave_tick(ctx, entry, 0.1)
	await wait_physics_frames(1)
	assert_eq(_count_children(&"Structure"), drones, "keine doppelten Drohnen")

	var mirror: Player = _build_normally(_character("spiegelkugel"))
	_start_wave(mirror)
	assert_eq(_count_children(&"MirrorClone"), 1)
	for i in 3:
		mirror.rebuild()
	await wait_physics_frames(1)
	assert_eq(_count_children(&"MirrorClone"), 1, "ein Spiegelbild")


func test_rebuild_keeps_vine_timer_and_souls_and_ghosts() -> void:
	var lamp: Player = _build_normally(_character("gewaechshauslampe"))
	var ctx: EffectContext = _start_wave(lamp)
	var vine: TriggerEntry = null
	for entry: TriggerEntry in lamp.triggers:
		if entry.effect is TimedSpawnEffect and (entry.effect as TimedSpawnEffect).action is BuildStructureAction:
			vine = entry
	vine.effect.on_wave_tick(ctx, vine, 7.0)
	lamp.rebuild()
	var kept: TriggerEntry = null
	for entry: TriggerEntry in lamp.triggers:
		if entry.effect == vine.effect:
			kept = entry
	assert_same(kept, vine, "Ranken-Timer läuft weiter statt neu zu starten")
	assert_almost_eq(kept.timer, 7.0, 0.001)

	var pool: ObjectPool = ObjectPool.new()
	pool.scene = ALLY_SCENE
	pool.group_name = Pools.ALLIES
	_container.add_child(pool)
	var wisp: Player = _build_normally(_character("irrlicht"))
	var wisp_ctx: EffectContext = _start_wave(wisp)
	GameState.souls.add(45, SCHATTENLING, Vector2(200, 0))
	for entry: TriggerEntry in wisp.triggers:
		entry.effect.on_wave_tick(wisp_ctx, entry, 3.0)
	assert_eq(Ally.active_count(get_tree()), 1)
	for i in 3:
		wisp.rebuild()
	assert_eq(GameState.souls.souls, 45, "Seelen bleiben")
	assert_eq(Ally.active_count(get_tree()), 1, "kein zusätzlicher Geist")


func test_rebuild_keeps_pets_without_duplicates() -> void:
	var player: Player = _build_normally(_character("spiegelkugel"))
	_start_wave(player)
	var pets: Array[Pet] = player.pet_slots.get_pets()
	assert_eq(pets.size(), PETS.size())
	assert_eq(_pet_copies(player), 1, "Mini-Birne trägt eine Kopie")
	for i in 3:
		player.rebuild()
	await wait_physics_frames(1)
	assert_eq(player.pet_slots.get_pets(), pets, "dieselben Begleiter-Knoten, nicht neu erzeugt")
	assert_eq(_pet_nodes(player), PETS.size(), "keine doppelten Begleiter")
	assert_eq(_pet_copies(player), 1, "keine doppelte Waffenkopie")
	assert_eq(_count_children(&"MirrorClone"), 1, "Spiegelbild und Begleiter vertragen sich")
	player.switch_character(_character("drohnenleuchte"))
	await wait_physics_frames(1)
	assert_eq(_pet_nodes(player), PETS.size(), "Charakterwechsel behält die Begleiter")


# --- Charakterwechsel (Admin) ---

func test_switch_character_recalculates_and_keeps_weapons() -> void:
	var player: Player = _build_normally(_character("standardbirne"))
	var weapons: int = player.weapon_slots.get_weapons().size()
	player.switch_character(_character("lichterkette"))
	assert_eq(player.weapon_slots.get_weapons().size(), weapons, "Waffen bleiben")
	assert_eq(GameState.character, _character("lichterkette"))
	var reference: Player = _build_normally_with_items_of(player, _character("lichterkette"))
	_assert_same(_snapshot(player), _snapshot(reference), "Wechsel zur Lichterkette")


## Referenz: gleicher Charakter, gleiche Waffen, gleiche Items und Run-Modifikatoren, normal aufgebaut.
func _build_normally_with_items_of(source: Player, character: CharacterData) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.rng = RandomNumberGenerator.new()
	_container.add_child(player)
	player.apply_character(character)
	for weapon: Weapon in source.weapon_slots.get_weapons():
		player.weapon_slots.add_weapon(weapon.data, weapon.tier)
	for pet: Pet in source.pet_slots.get_pets():
		player.pet_slots.add_pet(pet.data, pet.tier)
	for item: ItemData in GameState.items:
		player.apply_item(item)
	for mod: StatModifier in source.run_modifiers:
		player.add_run_modifier(mod)
	return player


func test_switch_keeps_souls_and_ends_old_character_effects() -> void:
	var player: Player = _build_normally(_character("drohnenleuchte"))
	var ctx: EffectContext = _start_wave(player)
	for entry: TriggerEntry in player.triggers:
		entry.effect.on_wave_tick(ctx, entry, 0.1)
	assert_gt(_count_children(&"Structure"), 0, "Drohnen der Drohnenleuchte")
	GameState.souls.max_souls = 100
	GameState.souls.add(30, SCHATTENLING, Vector2.ZERO)
	player.switch_character(_character("spiegelkugel"))
	await wait_physics_frames(1)
	assert_eq(_count_children(&"Structure"), 0, "Drohnen des alten Charakters entfernt")
	assert_eq(_count_children(&"MirrorClone"), 1, "Spiegelbild des neuen Charakters startet sofort")
	assert_eq(GameState.souls.souls, 30, "Seelenglas bleibt erhalten")


func test_switch_to_fewer_slots_keeps_all_weapons() -> void:
	var player: Player = _build_normally(_character("standardbirne"))
	while not player.weapon_slots.is_full():
		player.weapon_slots.add_weapon(load("res://data/weapons/funkenpistole.tres"))
	var drone_light: CharacterData = _character("drohnenleuchte")
	assert_lt(drone_light.weapon_slots, Player.DEFAULT_WEAPON_SLOTS)
	player.switch_character(drone_light)
	assert_eq(player.weapon_slots.max_slots, drone_light.weapon_slots)
	assert_eq(player.weapon_slots.get_weapons().size(), Player.DEFAULT_WEAPON_SLOTS, "vorhandene Waffen bleiben")
