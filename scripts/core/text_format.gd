class_name TextFormat
extends RefCounted
## Formatiert Stat-Werte und Beschreibungen für die UI (BBCode für RichTextLabel).

const GOOD_COLOR: String = "#7ED957"
const BAD_COLOR: String = "#E74C3C"
## Stats, deren Wert in % angezeigt wird, ohne dass der Name schon "%" enthält.
const PERCENT_SUFFIX_STATS: Array[StringName] = [
	&"lifesteal", &"attack_speed", &"crit_chance", &"dodge", &"speed",
]
## Stats, bei denen ein negativer Wert gut für den Spieler ist.
const GOOD_WHEN_NEGATIVE: Array[StringName] = [
	&"item_price_pct", &"reroll_price_pct", &"enemy_speed_pct",
]


static func number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return "%.1f" % value


static func signed_number(value: float) -> String:
	return ("+" if value > 0.0 else "") + number(value)


static func stat_value(stat: StringName, value: float) -> String:
	return number(value) + (" %" if stat in PERCENT_SUFFIX_STATS else "")


static func is_good(stat: StringName, delta: float) -> bool:
	return delta < 0.0 if stat in GOOD_WHEN_NEGATIVE else delta > 0.0


static func colored(text: String, good: bool) -> String:
	return "[color=%s]%s[/color]" % [GOOD_COLOR if good else BAD_COLOR, text]


## Eine Zeile wie "+3 Max. HP" oder "-2 % Tempo", grün oder rot eingefärbt.
static func modifier_line(mod: StatModifier) -> String:
	var name: String = t(Stats.label_key(mod.stat))
	var amount: String = signed_number(mod.value)
	match mod.kind:
		StatModifier.Kind.PERCENT:
			amount += " %"
		StatModifier.Kind.GAIN_PERCENT:
			return t("MOD_GAIN") % [name, colored(amount + " %", mod.value > 0.0)]
		_:
			if mod.stat in PERCENT_SUFFIX_STATS:
				amount += " %"
	return "%s %s" % [colored(amount, is_good(mod.stat, mod.value)), name]


static func describe_modifiers(mods: Array[StatModifier]) -> String:
	var lines: PackedStringArray = []
	for mod: StatModifier in mods:
		lines.append(modifier_line(mod))
	return "\n".join(lines)


static func tier_name(tier: int) -> String:
	return t("TIER_%d" % tier)


## Übersetzung als String (für den %-Operator auch außerhalb von Nodes).
static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## Kurzbeschreibung einer Waffe in einem Tier (Schaden mit Skalierung, Tempo, Reichweite, Besonderheiten, Klassen).
static func describe_weapon(weapon: WeaponData, tier: int) -> String:
	var tier_stats: WeaponTierStats = weapon.get_tier(tier)
	var scalings: PackedStringArray = []
	for stat: StringName in tier_stats.scalings:
		scalings.append("%d %% %s" % [roundi(tier_stats.scalings[stat] * 100.0), t(Stats.label_key(stat))])
	var lines: PackedStringArray = []
	lines.append(t("WEAPON_DAMAGE") % [number(tier_stats.base_damage), ", ".join(scalings)])
	lines.append(t("WEAPON_COOLDOWN") % ("%.2f" % tier_stats.cooldown))
	lines.append(t("WEAPON_RANGE") % number(tier_stats.range))
	lines.append(t("WEAPON_CRIT") % [number(tier_stats.crit_chance * 100.0), number(tier_stats.crit_multiplier)])
	if tier_stats.knockback > 0.0:
		lines.append(t("WEAPON_KNOCKBACK") % number(tier_stats.knockback))
	if tier_stats.piercing > 0:
		lines.append(t("WEAPON_PIERCING") % tier_stats.piercing)
	if tier_stats.bounces > 0:
		lines.append(t("WEAPON_BOUNCES") % tier_stats.bounces)
	var classes: PackedStringArray = []
	for weapon_class: StringName in weapon.classes:
		classes.append(t(WeaponClasses.label_key(weapon_class)))
	lines.append(t("WEAPON_CLASSES") % ", ".join(classes))
	return "\n".join(lines)
