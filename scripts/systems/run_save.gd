class_name RunSave
extends RefCounted
## Speichert einen laufenden Run am Shop-Beginn und stellt ihn wieder her ("Fortsetzen" im Hauptmenü).
## Resources werden über ihre IDs referenziert; Items und Charakter werden beim Laden neu angewendet,
## damit auch Trigger-Effekte wieder registriert sind.

const FORMAT_VERSION: int = 1
const DIFFICULTY_PATH: String = "res://data/difficulties/spannung_%d.tres"


## Momentaufnahme des Runs (Aufruf in der Shop-Phase).
static func capture(player: Player) -> Dictionary:
	var weapons: Array = []
	for weapon: Weapon in player.weapon_slots.get_weapons():
		weapons.append([String(weapon.data.id), weapon.tier])
	var pets: Array = []
	for pet: Pet in player.pet_slots.get_pets():
		pets.append([String(pet.data.id), pet.tier])
	var items: Array = []
	for item: ItemData in GameState.items:
		items.append(String(item.id))
	var modifiers: Array = []
	for mod: StatModifier in player.run_modifiers:
		modifiers.append([String(mod.stat), mod.value, mod.kind])
	var specials: Dictionary = {}
	for wave: int in GameState.special_waves:
		specials[str(wave)] = GameState.special_waves[wave]
	var run: RunStats = GameState.run_stats
	return {
		"format": FORMAT_VERSION,
		"character": String(GameState.character.id),
		"starting_weapon": String(GameState.starting_weapon.id) if GameState.starting_weapon != null else "",
		"difficulty": GameState.difficulty.level,
		"seed": GameState.run_seed,
		"run_id": GameState.run_id,
		"rng_state": str(GameState.rng.state),
		"wave": GameState.current_wave,
		"sparks": GameState.sparks,
		"bag": GameState.bag,
		"xp": GameState.xp,
		"level": GameState.level,
		"total_sparks": GameState.total_sparks_collected,
		"max_structures": GameState.max_structures,
		"special_waves": specials,
		"items": items,
		"weapons": weapons,
		"pets": pets,
		"run_modifiers": modifiers,
		"hp": player.current_hp,
		"run_stats": run.to_dict(),
		"admin_used": GameState.admin.used,
		"souls": GameState.souls.souls,
		"shop": GameState.shop.to_dict(),
		"endless": GameState.endless,
		"endless_start_wave": GameState.endless_start_wave,
		"reported": GameState.run_reported,
		"reported_totals": GameState.reported_totals.duplicate(),
	}


## Setzt Charakter, Startwaffe und Spannung (vor dem Szenenwechsel in den Run).
static func apply_setup(data: Dictionary) -> void:
	GameState.set_run_setup(find(Unlocks.CHARACTER_CATEGORY, data["character"]) as CharacterData,
		find("weapons", data["starting_weapon"]) as WeaponData, load(DIFFICULTY_PATH % int(data["difficulty"])))


## Stellt den GameState wieder her (statt start_run).
static func restore_state(data: Dictionary) -> void:
	apply_setup(data)
	GameState.start_run(int(data["seed"]))
	GameState.rng.state = int(data["rng_state"])
	GameState.run_id = String(data.get("run_id", GameState.run_id))
	GameState.current_wave = int(data["wave"])
	GameState.sparks = int(data["sparks"])
	GameState.bag = int(data["bag"])
	GameState.xp = float(data["xp"])
	GameState.level = int(data["level"])
	GameState.total_sparks_collected = int(data["total_sparks"])
	GameState.max_structures = int(data["max_structures"])
	GameState.special_waves.clear()
	for key: String in data["special_waves"]:
		GameState.special_waves[int(key)] = data["special_waves"][key]
	GameState.run_stats = RunStats.from_dict(data["run_stats"])
	GameState.admin.used = bool(data.get("admin_used", false))
	GameState.souls.souls = int(data.get("souls", 0))
	GameState.shop.load_dict(data["shop"])
	GameState.endless = bool(data.get("endless", false))
	GameState.endless_start_wave = int(data.get("endless_start_wave", 0))
	GameState.reported_totals.clear()
	var reported: Variant = data.get("reported", false)
	if reported is Array:
		# Format bis Paket 14c-3: [gemeldet, Funken, Kills]
		GameState.run_reported = bool(reported[0])
		GameState.reported_totals[SaveManager.STAT_TOTAL_SPARKS] = int(reported[1])
		GameState.reported_totals[SaveManager.STAT_KILLS] = int(reported[2])
	else:
		GameState.run_reported = bool(reported)
		var totals: Dictionary = data.get("reported_totals", {})
		for key: String in totals:
			GameState.reported_totals[key] = int(totals[key])


## Baut den Spieler nach: Charakter, Waffen, Begleiter, Items (inkl. Trigger), Run-Modifikatoren, HP.
static func apply_to_player(data: Dictionary, player: Player) -> void:
	player.apply_character(GameState.character)
	for entry: Array in data["weapons"]:
		player.weapon_slots.add_weapon(find("weapons", entry[0]) as WeaponData, int(entry[1]))
	for entry: Array in data.get("pets", []):
		var pet: PetData = find("pets", entry[0]) as PetData
		if pet != null:
			player.pet_slots.add_pet(pet, int(entry[1]))
	for item_id: String in data["items"]:
		var item: ItemData = find("items", item_id) as ItemData
		GameState.items.append(item)
		player.apply_item(item)
	for entry: Array in data["run_modifiers"]:
		player.add_run_modifier(StatModifier.create(StringName(entry[0]), float(entry[1]), int(entry[2]) as StatModifier.Kind))
	player.current_hp = minf(float(data["hp"]), player.get_max_hp())
	player.hp_changed.emit(player.current_hp, player.get_max_hp())
	Events.sparks_changed.emit(GameState.sparks, GameState.bag)
	Events.xp_changed.emit(GameState.xp, GameState.xp_needed(), GameState.level)


static func find(category: String, id: String) -> Resource:
	for res: Resource in DataRegistry.get_all(category):
		if String(res.get("id")) == id:
			return res
	return null
