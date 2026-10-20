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
	var name: String = TranslationServer.translate(Stats.label_key(mod.stat))
	var amount: String = signed_number(mod.value)
	match mod.kind:
		StatModifier.Kind.PERCENT:
			amount += " %"
		StatModifier.Kind.GAIN_PERCENT:
			return TranslationServer.translate("MOD_GAIN") % [name, colored(amount + " %", mod.value > 0.0)]
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
	return TranslationServer.translate("TIER_%d" % tier)
