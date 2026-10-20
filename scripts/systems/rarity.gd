class_name Rarity
extends RefCounted
## Reine Seltenheitsformeln. Würfelergebnisse werden übergeben, damit alles testbar bleibt.

const MIN_TIER: int = 1
const MAX_TIER: int = 4
const PERCENT: float = 100.0


## Chance für genau dieses Tier (2..4) auf Stufe `level` (Welle oder Level).
static func tier_chance(tier: int, level: int, luck: float, config: RarityConfig) -> float:
	var i: int = tier - 1
	if level < config.unlock[i]:
		return 0.0
	var base: float = (level - config.unlock[i] + 1) * config.step[i]
	return clampf(base * (1.0 + luck / PERCENT), 0.0, config.max_chance[i])


## Würfelt ein Tier: roll 0..1, höhere Tiers werden zuerst geprüft.
static func roll_tier(level: int, luck: float, config: RarityConfig, roll: float) -> int:
	var cumulative: float = 0.0
	for tier in range(MAX_TIER, MIN_TIER, -1):
		cumulative += tier_chance(tier, level, luck, config)
		if roll < cumulative:
			return tier
	return MIN_TIER


## Garantierte Mindestseltenheit für Level-up-Karten.
static func guaranteed_tier(level: int, config: RarityConfig) -> int:
	if level >= config.guaranteed_tier_4_from_level and level % config.guaranteed_tier_4_every == 0:
		return 4
	if level in config.guaranteed_tier_3_levels:
		return 3
	if level == config.guaranteed_tier_2_level:
		return 2
	return MIN_TIER
