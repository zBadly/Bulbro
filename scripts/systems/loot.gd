class_name Loot
extends RefCounted
## Auswahl von Items und Upgrades aus einem Pool (Kartons, Shop, Level-up).


## Wählt ein Item des gewünschten Tiers. Items am Limit sind ausgeschlossen; Items mit bevorzugten Tags
## werden stärker gewichtet. Gibt es im Tier nichts, wird zuerst nach unten, dann nach oben ausgewichen.
static func pick_item(items: Array[ItemData], tier: int, owned: Dictionary[StringName, int],
		preferred_tags: Array[StringName], tag_weight: float, rng: RandomNumberGenerator) -> ItemData:
	for candidate_tier: int in _tier_order(tier):
		var pool: Array[ItemData] = []
		var weights: PackedFloat32Array = []
		for item: ItemData in items:
			if item.tier != candidate_tier or item.is_at_limit(owned.get(item.id, 0)):
				continue
			pool.append(item)
			weights.append(tag_weight if _has_any_tag(item, preferred_tags) else 1.0)
		if not pool.is_empty():
			return pool[rng.rand_weighted(weights)]
	return null


## Zieht `count` verschiedene Upgrades.
static func pick_upgrades(upgrades: Array[UpgradeData], count: int, rng: RandomNumberGenerator) -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = upgrades.duplicate()
	var result: Array[UpgradeData] = []
	while result.size() < count and not pool.is_empty():
		result.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return result


static func _tier_order(tier: int) -> Array[int]:
	var order: Array[int] = []
	for t in range(tier, Rarity.MIN_TIER - 1, -1):
		order.append(t)
	for t in range(tier + 1, Rarity.MAX_TIER + 1):
		order.append(t)
	return order


static func _has_any_tag(item: ItemData, tags: Array[StringName]) -> bool:
	for tag: StringName in item.tags:
		if tag in tags:
			return true
	return false
