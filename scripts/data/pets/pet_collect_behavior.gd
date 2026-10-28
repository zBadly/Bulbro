class_name PetCollectBehavior
extends PetBehavior
## Funkenspatz: zieht liegende Funken in seinem Umkreis zum Spieler (wie der Aufsammelradius, nur um den Spatz).

const SCAN_KEY: String = "scan"


func tick(pet: Pet, delta: float) -> bool:
	var left: float = float(pet.state.get(SCAN_KEY, 0.0)) - delta
	pet.state[SCAN_KEY] = left
	if left > 0.0:
		return false
	pet.state[SCAN_KEY] = Pet.CONFIG.scan_interval
	var pool: ObjectPool = Pools.get_pool(pet.get_tree(), Pools.PICKUPS)
	if pool == null:
		return false
	var radius_sq: float = pet.get_tier_stats().radius * pet.get_tier_stats().radius
	var center: Vector2 = pet.get_center()
	var collected: int = 0
	for node: Node in pool.get_active():
		var pickup: Pickup = node as Pickup
		if pickup != null and pickup.can_attract() and center.distance_squared_to(pickup.global_position) <= radius_sq:
			pickup.attract()
			collected += 1
	if collected > 0:
		GameState.run_stats.record_pet_event(pet.get_origin(), collected)
		Juice.hop(pet.visual)
	return false


func describe(stats: PetTierStats) -> PackedStringArray:
	return [TextFormat.t("PET_COLLECT_DESC") % TextFormat.number(stats.radius)]


func status_lines(pet: Pet) -> PackedStringArray:
	return [TextFormat.t("TIP_PET_SPARKS") % GameState.run_stats.pet_events_of(pet.get_origin())]
