class_name Economy
extends RefCounted
## Reine Formeln für XP, Drops und Aufladung (GDD Abschnitte 5 und 6). Keine Seiteneffekte, kein Zufall.

const PERCENT: float = 100.0
## XP bis zum nächsten Level: (Level + XP_LEVEL_OFFSET)^2 (Startwert)
const XP_LEVEL_OFFSET: int = 3
## Aufladung wächst nach jeder Welle um 5 % (aufgerundet), nur wenn positiv.
const HARVESTING_GROWTH: float = 0.05


## XP, die von `level` auf `level + 1` nötig sind.
static func xp_for_level(level: int) -> float:
	return float((level + XP_LEVEL_OFFSET) * (level + XP_LEVEL_OFFSET))


## XP-Gewinn für einen Funkenwert mit XP-Bonus in %.
static func xp_gain(value: float, xp_gain_pct: float) -> float:
	return maxf(0.0, value * (1.0 + xp_gain_pct / PERCENT))


## Batterie-Dropchance pro Kill: 100 Glück = doppelt, -100 Glück = keine.
static func battery_chance(base_chance: float, luck: float) -> float:
	return clampf(base_chance * (1.0 + luck / PERCENT), 0.0, 1.0)


## Chance, dass ein Verbrauchsgegenstand ein Karton ist:
## Basischance x (100 + Glück) % / (1 + Kartons in dieser Welle).
static func crate_chance(base_chance: float, luck: float, crates_this_wave: int) -> float:
	return clampf(base_chance * (PERCENT + luck) / PERCENT / (1.0 + crates_this_wave), 0.0, 1.0)


## Zuwachs der Aufladung nach einer Welle (+5 %, aufgerundet; 0 wenn nicht positiv).
static func harvesting_growth(harvesting: float) -> int:
	if harvesting <= 0.0:
		return 0
	return ceili(harvesting * HARVESTING_GROWTH)


## Aufsammelradius mit Prozent-Bonus.
static func pickup_radius(base_radius: float, pickup_range_pct: float) -> float:
	return maxf(0.0, base_radius * (1.0 + pickup_range_pct / PERCENT))


## Heilung eines Verbrauchsgegenstands inkl. Bonus-Stat.
static func consumable_heal(base_heal: float, bonus: float) -> float:
	return maxf(0.0, base_heal + bonus)


## Schaden an Leuchtkristallen: mindestens so viel, dass er nach max_hits Treffern zerbricht.
static func crystal_hit_damage(damage: float, max_hp: float, max_hits: int) -> float:
	return maxf(damage, ceilf(max_hp / max_hits))
