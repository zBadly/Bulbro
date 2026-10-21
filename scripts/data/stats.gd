class_name Stats
extends RefCounted
## Namen aller Spieler-Stats (GDD Abschnitt 4). Im Code immer diese Konstanten verwenden, nie String-Literale.

# Primär-Stats
const MAX_HP: StringName = &"max_hp"
const HP_REGEN: StringName = &"hp_regen"
const LIFESTEAL: StringName = &"lifesteal"
const DAMAGE_PCT: StringName = &"damage_pct"
const MELEE_DMG: StringName = &"melee_dmg"
const RANGED_DMG: StringName = &"ranged_dmg"
const ELEMENTAL_DMG: StringName = &"elemental_dmg"
const ATTACK_SPEED: StringName = &"attack_speed"
const CRIT_CHANCE: StringName = &"crit_chance"
const ENGINEERING: StringName = &"engineering"
const RANGE: StringName = &"range"
const ARMOR: StringName = &"armor"
const DODGE: StringName = &"dodge"
const SPEED: StringName = &"speed"
const LUCK: StringName = &"luck"
const HARVESTING: StringName = &"harvesting"

# Sekundär-Stats
const XP_GAIN_PCT: StringName = &"xp_gain_pct"
const PICKUP_RANGE_PCT: StringName = &"pickup_range_pct"
const ITEM_PRICE_PCT: StringName = &"item_price_pct"
const EXPLOSION_DMG_PCT: StringName = &"explosion_dmg_pct"
const EXPLOSION_SIZE_PCT: StringName = &"explosion_size_pct"
const BOUNCES: StringName = &"bounces"
const PIERCING: StringName = &"piercing"
const PIERCING_DMG_PCT: StringName = &"piercing_dmg_pct"
const BOSS_DMG_PCT: StringName = &"boss_dmg_pct"
const STRUCTURE_ATTACK_SPEED_PCT: StringName = &"structure_attack_speed_pct"
const BURN_SPEED_PCT: StringName = &"burn_speed_pct"
const BURN_SPREAD: StringName = &"burn_spread"
const KNOCKBACK: StringName = &"knockback"
const DOUBLE_SPARK_CHANCE: StringName = &"double_spark_chance"
const FREE_REROLLS: StringName = &"free_rerolls"
const CRYSTALS: StringName = &"crystals"
const ENEMIES_PCT: StringName = &"enemies_pct"
const ENEMY_SPEED_PCT: StringName = &"enemy_speed_pct"
const REROLL_PRICE_PCT: StringName = &"reroll_price_pct"
const CONSUMABLE_HEAL: StringName = &"consumable_heal"
## Zusätzliche Funken beim Recyceln in % (Recyclingschild).
const RECYCLE_PCT: StringName = &"recycle_pct"
## Brandschaden in % (Zündkerze).
const BURN_DMG_PCT: StringName = &"burn_dmg_pct"
## Mehr Funken aus Kills in % (Smartbulb).
const KILL_SPARK_PCT: StringName = &"kill_spark_pct"

const PRIMARY: Array[StringName] = [
	MAX_HP, HP_REGEN, LIFESTEAL, DAMAGE_PCT, MELEE_DMG, RANGED_DMG, ELEMENTAL_DMG, ATTACK_SPEED,
	CRIT_CHANCE, ENGINEERING, RANGE, ARMOR, DODGE, SPEED, LUCK, HARVESTING,
]
const SECONDARY: Array[StringName] = [
	XP_GAIN_PCT, PICKUP_RANGE_PCT, ITEM_PRICE_PCT, EXPLOSION_DMG_PCT, EXPLOSION_SIZE_PCT, BOUNCES,
	PIERCING, PIERCING_DMG_PCT, BOSS_DMG_PCT, STRUCTURE_ATTACK_SPEED_PCT, BURN_SPEED_PCT, BURN_SPREAD,
	KNOCKBACK, DOUBLE_SPARK_CHANCE, FREE_REROLLS, CRYSTALS, ENEMIES_PCT, ENEMY_SPEED_PCT,
	REROLL_PRICE_PCT, CONSUMABLE_HEAL, RECYCLE_PCT, BURN_DMG_PCT, KILL_SPARK_PCT,
]


static func all() -> Array[StringName]:
	var result: Array[StringName] = PRIMARY.duplicate()
	result.append_array(SECONDARY)
	return result


static func is_valid(stat: StringName) -> bool:
	return stat in PRIMARY or stat in SECONDARY


## Übersetzungsschlüssel für die Anzeige, z. B. STAT_MAX_HP.
static func label_key(stat: StringName) -> String:
	return "STAT_" + String(stat).to_upper()
