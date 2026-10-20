class_name CombatMath
extends RefCounted
## Reine Kampfformeln aus GDD Abschnitt 4 und 8. Keine Seiteneffekte, kein Zufall:
## Würfelergebnisse werden als Parameter übergeben, damit alles testbar bleibt.
## Die Konstanten sind feste Spielregeln aus dem GDD; Balancing-Werte liegen in res://data.

const PERCENT: float = 100.0
const MIN_DAMAGE: int = 1
const MIN_MAX_HP: float = 1.0

## Rüstung: Reduktion = armor / (armor + ARMOR_CONSTANT)
const ARMOR_CONSTANT: float = 15.0
## HP-Regen: erster Punkt und jeder weitere Punkt in HP/s
const REGEN_FIRST_POINT: float = 0.20
const REGEN_PER_EXTRA_POINT: float = 0.089
## Angriffstempo: Obergrenze und Abschwächung negativer Werte (Startwert)
const MAX_ATTACKS_PER_SECOND: float = 12.0
const NEGATIVE_ATTACK_SPEED_FACTOR: float = 0.5
## Lebensraub höchstens einmal pro Intervall (max. 10 HP/s)
const LIFESTEAL_INTERVAL: float = 0.1
## Reichweite: Minimum und Anteil des Reichweiten-Stats bei Nahkampfwaffen
const MIN_RANGE: float = 25.0
const MELEE_RANGE_FACTOR: float = 0.5


## Schadensfaktor durch Rüstung. Positiv: 15/(armor+15). Negativ: jeder Punkt +1/15 mehr Schaden.
static func armor_multiplier(armor: float) -> float:
	if armor >= 0.0:
		return ARMOR_CONSTANT / (armor + ARMOR_CONSTANT)
	return 1.0 + absf(armor) / ARMOR_CONSTANT


## Erlittener Schaden nach Rüstung, gerundet, mindestens 1.
static func damage_after_armor(raw_damage: float, armor: float) -> int:
	return maxi(MIN_DAMAGE, roundi(raw_damage * armor_multiplier(armor)))


## HP pro Sekunde. 1. Punkt = 0,20, jeder weitere +0,089. Werte <= 0 regenerieren nicht.
static func hp_regen_per_second(hp_regen: float) -> float:
	if hp_regen <= 0.0:
		return 0.0
	return maxf(0.0, REGEN_FIRST_POINT + (hp_regen - 1.0) * REGEN_PER_EXTRA_POINT)


## Ausweichwahrscheinlichkeit 0..1. Negative Werte wirken wie 0, Obergrenze dodge_cap (in %).
static func dodge_chance(dodge: float, dodge_cap: float) -> float:
	return clampf(dodge, 0.0, dodge_cap) / PERCENT


## Abklingzeit nach Angriffstempo. Positiv: cd / (1 + AS/100).
## Negativ (Startwert): cd x (1 + |AS|/100 x 0,5). Nie schneller als 12 Angriffe/s.
static func attack_cooldown(base_cooldown: float, attack_speed: float) -> float:
	var cooldown: float
	if attack_speed >= 0.0:
		cooldown = base_cooldown / (1.0 + attack_speed / PERCENT)
	else:
		cooldown = base_cooldown * (1.0 + absf(attack_speed) / PERCENT * NEGATIVE_ATTACK_SPEED_FACTOR)
	return maxf(cooldown, 1.0 / MAX_ATTACKS_PER_SECOND)


## Max HP. Negative Werte wirken wie 1.
static func effective_max_hp(max_hp: float) -> float:
	return maxf(MIN_MAX_HP, max_hp)


## Bewegungstempo in px/s. Bei -100 % Stillstand.
static func move_speed(base_speed: float, speed_pct: float) -> float:
	return base_speed * maxf(0.0, 1.0 + speed_pct / PERCENT)


## Waffenreichweite. Nahkampf bekommt nur die Hälfte des Reichweiten-Stats, Minimum 25.
static func effective_range(weapon_range: float, range_stat: float, is_melee: bool) -> float:
	var bonus: float = range_stat * (MELEE_RANGE_FACTOR if is_melee else 1.0)
	return maxf(MIN_RANGE, weapon_range + bonus)


## Krit-Chance 0..1: Waffen-Krit (0..1) plus Krit-Stat (in %).
static func crit_chance(weapon_crit: float, crit_stat: float) -> float:
	return clampf(weapon_crit + crit_stat / PERCENT, 0.0, 1.0)


## Lebensraub-Chance 0..1 pro Treffer.
static func lifesteal_chance(lifesteal: float) -> float:
	return clampf(lifesteal / PERCENT, 0.0, 1.0)


## Darf jetzt wieder Lebensraub auslösen? (höchstens einmal pro 0,1 s)
static func lifesteal_ready(now: float, last_time: float) -> bool:
	return now - last_time >= LIFESTEAL_INTERVAL


## Trefferablauf für den Spieler: Ausweichwurf -> Rüstung. 0 = ausgewichen.
## roll ist eine Zufallszahl 0..1.
static func resolve_incoming_damage(raw_damage: float, armor: float, dodge: float, dodge_cap: float, roll: float) -> int:
	if roll < dodge_chance(dodge, dodge_cap):
		return 0
	return damage_after_armor(raw_damage, armor)


## Summe aus Skalierung x Stat, z. B. {melee_dmg: 0.8} mit Nah 10 -> 8.
static func scaling_bonus(scalings: Dictionary[StringName, float], stats: StatSystem) -> float:
	var bonus: float = 0.0
	for stat: StringName in scalings:
		bonus += scalings[stat] * stats.get_stat(stat)
	return bonus


## Waffenschaden (GDD 8): (Basis + Skalierung) x (1 + damage_pct/100) x Krit-Multiplikator, gerundet, mindestens 1.
static func weapon_damage(base_damage: float, scaling: float, damage_pct: float, crit_multiplier: float) -> int:
	var damage: float = (base_damage + scaling) * maxf(0.0, 1.0 + damage_pct / PERCENT) * crit_multiplier
	return maxi(MIN_DAMAGE, roundi(damage))
