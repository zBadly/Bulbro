class_name BalanceModel
extends RefCounted
## Grobe Balancing-Rechnung: Gegner-HP pro Welle gegen die DPS typischer Builds.
## Das Modell ist bewusst einfach (keine Bewegung, keine Überlappung); es zeigt Ausreißer zwischen Wellen,
## keine absoluten Wahrheiten. Annahmen zur Build-Entwicklung stehen als Konstanten hier.

const PERCENT: float = 100.0

# Annahmen: so entwickelt sich ein typischer Build über die Wellen
## Waffenanzahl: 1 + eine weitere alle WAVES_PER_WEAPON Wellen (max. 6).
const WAVES_PER_WEAPON: int = 3
const MAX_WEAPONS: int = 6
## Waffen-Tier: steigt alle WAVES_PER_TIER Wellen (T1 Welle 1-5, T4 ab 16).
const WAVES_PER_TIER: int = 5
## Zuwachs pro Welle aus Level-ups und Items.
const SCALING_STAT_PER_WAVE: float = 1.0
const DAMAGE_PCT_PER_WAVE: float = 2.5
const ATTACK_SPEED_PER_WAVE: float = 2.0
const CRIT_PER_WAVE: float = 0.5

# Mehrfachtreffer-Faktoren (wie viele Gegner ein Angriff im Schnitt trifft)
const PIERCE_FACTOR: float = 0.5
const MAX_PIERCE_COUNTED: int = 3
const BOUNCE_FACTOR: float = 0.5
const CHAIN_FACTOR: float = 0.8
const EXPLOSION_FACTOR: float = 2.5
const SWING_FACTOR: float = 1.5

# Bewertung: Build-DPS / benötigte DPS
const TOO_HARD: float = 0.8
const TOO_EASY: float = 2.5
const TARGET_RATIO: float = 1.4
const MIN_INTERVAL_FACTOR: float = 0.75
const MAX_INTERVAL_FACTOR: float = 1.33

## Builds: Name -> Waffen-IDs (reihum belegt) und skalierender Stat.
const BUILDS: Dictionary = {
	"Fern": {"weapons": ["funkenpistole", "prisma", "laserpointer"], "stat": &"ranged_dmg"},
	"Nah": {"weapons": ["glasscherbe", "kabelpeitsche", "lampenhammer"], "stat": &"melee_dmg"},
	"Strom": {"weapons": ["blitzwerfer", "loetkolben", "taschenlampenstrahl"], "stat": &"elemental_dmg"},
}


## Anzahl Gegner und Summe ihrer HP, die in einer Welle erscheinen.
static func wave_load(wave: WaveData, difficulty: DifficultyData) -> Dictionary:
	var level: int = difficulty.level if difficulty != null else 0
	var hp_factor: float = 1.0 + (difficulty.enemy_hp_pct / PERCENT if difficulty != null else 0.0)
	var count: float = 0.0
	var total_hp: float = 0.0
	for group: SpawnGroupData in wave.groups:
		if group.min_difficulty > level:
			continue
		var window_end: float = minf(group.end_time, wave.duration) if group.end_time > 0.0 else wave.duration
		if group.start_time >= window_end:
			continue
		var spawns: float = floorf((window_end - group.start_time) / group.interval) + 1.0
		var enemies: float = spawns * (group.group_min + group.group_max) * 0.5
		count += enemies
		total_hp += enemies * group.enemy.hp_for_wave(wave.wave_number) * hp_factor
	return {"count": count, "hp": total_hp, "required_dps": total_hp / wave.duration}


## Geschätzte DPS eines Builds in einer Welle.
static func build_dps(build: Dictionary, wave_number: int, weapons: Dictionary) -> float:
	var progress: float = wave_number - 1
	var weapon_count: int = mini(MAX_WEAPONS, 1 + int(progress) / WAVES_PER_WEAPON)
	var tier: int = clampi(1 + int(progress) / WAVES_PER_TIER, WeaponData.MIN_TIER, WeaponData.MAX_TIER)
	var block: StatBlock = StatBlock.new()
	block.values = {
		build["stat"]: SCALING_STAT_PER_WAVE * progress,
		Stats.DAMAGE_PCT: DAMAGE_PCT_PER_WAVE * progress,
		Stats.ATTACK_SPEED: ATTACK_SPEED_PER_WAVE * progress,
		Stats.CRIT_CHANCE: CRIT_PER_WAVE * progress,
	}
	var stats: StatSystem = StatSystem.new(block)
	var ids: Array = build["weapons"]
	var total: float = 0.0
	for i in weapon_count:
		total += weapon_dps(weapons[ids[i % ids.size()]], tier, stats)
	return total


static func weapon_dps(weapon: WeaponData, tier: int, stats: StatSystem) -> float:
	var t: WeaponTierStats = weapon.get_tier(tier)
	var hit: float = CombatMath.weapon_damage(t.base_damage, CombatMath.scaling_bonus(t.scalings, stats), stats.get_stat(Stats.DAMAGE_PCT), 1.0)
	var crit: float = CombatMath.crit_chance(t.crit_chance, stats.get_stat(Stats.CRIT_CHANCE))
	var per_hit: float = hit * (1.0 + crit * (t.crit_multiplier - 1.0))
	var cooldown: float = CombatMath.attack_cooldown(t.cooldown, stats.get_stat(Stats.ATTACK_SPEED))
	return per_hit / cooldown * targets_per_attack(weapon, t)


## Wie viele Gegner ein Angriff im Schnitt trifft.
static func targets_per_attack(weapon: WeaponData, t: WeaponTierStats) -> float:
	var factor: float = maxf(1.0, t.projectile_count)
	factor *= 1.0 + PIERCE_FACTOR * mini(t.piercing, MAX_PIERCE_COUNTED)
	factor *= 1.0 + BOUNCE_FACTOR * t.bounces
	factor *= 1.0 + CHAIN_FACTOR * t.chain_count
	if t.explosion_radius > 0.0:
		factor *= EXPLOSION_FACTOR
	if weapon.kind == WeaponData.Kind.SWING:
		factor *= SWING_FACTOR
	return factor


## "zu schwer", "zu leicht" oder "ok" für das Verhältnis Build-DPS / benötigte DPS.
static func rating(ratio: float) -> String:
	if ratio < TOO_HARD:
		return "zu schwer"
	if ratio > TOO_EASY:
		return "zu leicht"
	return "ok"


## Vorschlag: Spawn-Intervalle der Welle mit diesem Faktor multiplizieren (>1 = weniger Gegner).
static func interval_factor(average_ratio: float) -> float:
	return clampf(TARGET_RATIO / maxf(average_ratio, 0.01), MIN_INTERVAL_FACTOR, MAX_INTERVAL_FACTOR)
