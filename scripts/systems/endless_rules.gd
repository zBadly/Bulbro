class_name EndlessRules
extends RefCounted
## Rechnungen des Endlos-Modus aus EndlessConfig; genutzt von Wellen, Gegnern, Drops, Shop und Simulator.
## `level` ist die Endlos-Stufe (GameState.endless_level(): Welle 21 = 1, 0 = kein Endlos-Modus).

const CONFIG: EndlessConfig = preload("res://data/config/endless_config.tres")


## (1 + Zuwachs)^Stufe, optional gedeckelt (cap = höchster Zuwachs, z. B. 0,6 = höchstens x1,6).
static func growth(rate: float, level: int, cap: float = INF) -> float:
	return minf(pow(1.0 + rate, maxi(0, level)), 1.0 + cap)


static func hp_factor(level: int) -> float:
	return growth(CONFIG.hp_growth, level)


static func damage_factor(level: int) -> float:
	return growth(CONFIG.damage_growth, level)


static func speed_factor(level: int) -> float:
	return growth(CONFIG.speed_growth, level, CONFIG.speed_max)


## Gruppen erscheinen um diesen Faktor häufiger.
static func density_factor(level: int) -> float:
	return growth(CONFIG.density_growth, level, CONFIG.density_max)


## Anteil der Aufladung, der ausgezahlt wird (außerhalb des Endlos-Modus 1).
static func harvest_factor(level: int) -> float:
	if level <= 0:
		return 1.0
	return maxf(CONFIG.harvest_min, CONFIG.harvest_start - CONFIG.harvest_decay * (level - 1))


static func is_boss_level(level: int) -> bool:
	return level > 0 and CONFIG.boss_cycle_waves > 0 and level % CONFIG.boss_cycle_waves == 0


## Nummer des Boss-Zyklus einer Bosswelle (Stufe 10 = 1, 20 = 2 ...).
static func boss_cycle(level: int) -> int:
	return level / CONFIG.boss_cycle_waves if CONFIG.boss_cycle_waves > 0 else 0


static func boss_hp_bonus(cycle: int) -> float:
	return 1.0 + CONFIG.boss_cycle_hp_bonus * cycle


static func boss_damage_bonus(cycle: int) -> float:
	return 1.0 + CONFIG.boss_cycle_damage_bonus * cycle


## Elite-/Hordewelle an Position special_wave_offset jedes Blocks (Stufe 5, 15, 25 ...).
static func is_special_level(level: int) -> bool:
	return level > 0 and CONFIG.boss_cycle_waves > 0 and level % CONFIG.boss_cycle_waves == CONFIG.special_wave_offset
