class_name TooltipText
extends RefCounted
## Inhalte der Hover-Tooltips (BBCode) für besessene Waffen, Items, Set-Boni und Stats (Phase 15, Paket 4).
## Waffen zeigen die aktuellen Werte mit allen Stats des Spielers, nicht die Grundwerte aus dem Shop.

const TITLE_SIZE: int = 24
const HEADING_COLOR: String = "#FFD43B"
const MUTED_COLOR: String = "#8A8A8A"
const ACTIVE_COLOR: String = "#FFE066"
const CAP_COLOR: String = "#FFD43B"
const SECTION_GAP: String = ""
const SETS_CATEGORY: String = "sets"


## Titelzeile: Name in Tier-Farbe, darunter das Tier.
static func title(name: String, tier: int) -> String:
	return "[font_size=%d][color=#%s]%s[/color][/font_size]\n[color=%s]%s[/color]" % [
		TITLE_SIZE, UiStyle.tier_color(tier).to_html(false), name, MUTED_COLOR, TextFormat.tier_name(tier)]


# --- Waffen ---

static func weapon(w: Weapon) -> String:
	var t: WeaponTierStats = w.get_tier_stats()
	var player: Player = w.player
	var lines: PackedStringArray = [title(TextFormat.t(w.data.name_key), w.tier)]
	lines.append(weapon_damage_line(w))
	lines.append(TextFormat.t("WEAPON_COOLDOWN") % ("%.2f" % w.get_cooldown()))
	lines.append(TextFormat.t("WEAPON_RANGE") % TextFormat.number(roundf(w.get_range())))
	var crit: float = 0.0
	if not player.has_rule(Player.Rule.NO_CRIT):
		crit = CombatMath.crit_chance(t.crit_chance, player.stats.get_stat(Stats.CRIT_CHANCE))
	lines.append(TextFormat.t("WEAPON_CRIT") % [TextFormat.number(roundf(crit * CombatMath.PERCENT)), TextFormat.number(t.crit_multiplier)])
	lines.append_array(TextFormat.weapon_special_lines(w.data, w.tier))
	lines.append(TextFormat.t("WEAPON_CLASSES") % TextFormat.weapon_classes_text(w.data))
	var counts: Dictionary[StringName, int] = class_counts(player.weapon_slots.get_weapons())
	for weapon_class: StringName in w.data.classes:
		var set_bonus: SetBonusData = set_bonus_for(weapon_class)
		if set_bonus != null:
			lines.append(SECTION_GAP)
			lines.append(set_bonus_text(set_bonus, counts.get(weapon_class, 0), player.set_bonus_multiplier.get(weapon_class, 1.0)))
	lines.append(SECTION_GAP)
	lines.append(run_line(DamageSource.weapon(w.data.id), player.weapon_slots.count_of(w.data.id)))
	return "\n".join(lines)


## "Schaden: 18 = 12 + 50 % von 12 Nah" (aktueller Schaden ohne Krit, mit Skalierung und Schaden-%).
static func weapon_damage_line(w: Weapon) -> String:
	var t: WeaponTierStats = w.get_tier_stats()
	var stats: StatSystem = w.player.stats
	var base: float = w.get_base_damage()
	var damage_pct: float = stats.get_stat(Stats.DAMAGE_PCT)
	var total: int = CombatMath.weapon_damage(base, CombatMath.scaling_bonus(t.scalings, stats), damage_pct, 1.0)
	if w.damage_factor != 1.0:
		total = maxi(CombatMath.MIN_DAMAGE, roundi(total * w.damage_factor))
	var parts: PackedStringArray = [TextFormat.number(base)]
	for stat: StringName in t.scalings:
		parts.append(TextFormat.t("TIP_DAMAGE_SCALING") % [
			roundi(t.scalings[stat] * CombatMath.PERCENT), TextFormat.number(stats.get_stat(stat)), TextFormat.t(Stats.label_key(stat))])
	var text: String = "%d = %s" % [total, " + ".join(parts)]
	if not is_zero_approx(damage_pct):
		text += ", " + TextFormat.colored(TextFormat.t("TIP_DAMAGE_PCT") % TextFormat.signed_number(damage_pct), damage_pct > 0.0)
	return TextFormat.t("TIP_DAMAGE") % text


# --- Set-Boni ---

## Anzahl Waffen je Klasse (eine Waffe mit zwei Klassen zählt für beide).
static func class_counts(weapons: Array[Weapon]) -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for w: Weapon in weapons:
		for weapon_class: StringName in w.data.classes:
			counts[weapon_class] = counts.get(weapon_class, 0) + 1
	return counts


static func set_bonus_for(weapon_class: StringName) -> SetBonusData:
	for res: Resource in DataRegistry.get_all(SETS_CATEGORY):
		var set_bonus: SetBonusData = res as SetBonusData
		if set_bonus != null and set_bonus.weapon_class == weapon_class:
			return set_bonus
	return null


## Höchste Stufe (Waffenzahl) eines Set-Bonus, z. B. 6.
static func max_level(set_bonus: SetBonusData) -> int:
	return SetBonusData.MIN_WEAPONS + set_bonus.levels.size() - 1


## Kopfzeile "3/6 Klinge: +2 Nah, +2 % Lebensraub, nächste Stufe bei 4", darunter alle Stufen 2..6,
## die aktuelle hervorgehoben. `factor` ist der Set-Multiplikator des Charakters.
static func set_bonus_text(set_bonus: SetBonusData, count: int, factor: float = 1.0) -> String:
	var top: int = max_level(set_bonus)
	var class_name_text: String = TextFormat.t(WeaponClasses.label_key(set_bonus.weapon_class))
	var current: Array[StatModifier] = scaled(set_bonus.modifiers_for(count), factor)
	var summary: String = TextFormat.t("TIP_SET_NONE") if current.is_empty() else mods_inline(current)
	var next: String = TextFormat.t("TIP_SET_MAX") if count >= top else TextFormat.t("TIP_SET_NEXT") % maxi(count + 1, SetBonusData.MIN_WEAPONS)
	var lines: PackedStringArray = ["[color=%s]%s[/color]" % [HEADING_COLOR,
		TextFormat.t("TIP_SET_SUMMARY") % [count, top, class_name_text, summary, next]]]
	var active_level: int = mini(count, top)
	for level: int in range(SetBonusData.MIN_WEAPONS, top + 1):
		var mods: Array[StatModifier] = scaled(set_bonus.modifiers_for(level), factor)
		var line: String = TextFormat.t("TIP_SET_LEVEL") % [level, Lexicon.strip_bbcode(mods_inline(mods))]
		var color: String = ACTIVE_COLOR if level == active_level else MUTED_COLOR
		lines.append("[color=%s]%s%s[/color]" % [color, "» " if level == active_level else "   ", line])
	return "\n".join(lines)


static func scaled(mods: Array[StatModifier], factor: float) -> Array[StatModifier]:
	if is_equal_approx(factor, 1.0):
		return mods
	var result: Array[StatModifier] = []
	for mod: StatModifier in mods:
		result.append(StatModifier.create(mod.stat, mod.value * factor, mod.kind))
	return result


static func mods_inline(mods: Array[StatModifier]) -> String:
	var parts: PackedStringArray = []
	for mod: StatModifier in mods:
		parts.append(TextFormat.modifier_line(mod))
	return ", ".join(parts)


# --- Items ---

static func item(data: ItemData, count: int) -> String:
	var name: String = TextFormat.t(data.name_key)
	if count > 1:
		name += " x%d" % count
	var lines: PackedStringArray = [title(name, data.tier), data.get_description()]
	var origin: StringName = DamageSource.item(data.id)
	if GameState.run_stats.damage_of(origin) > 0 or GameState.run_stats.kills_of(origin) > 0:
		lines.append(SECTION_GAP)
		lines.append(run_line(origin, count))
	return "\n".join(lines)


# --- Run-Werte ---

## "In diesem Run: 34 Kills, 1234 Schaden" (bei mehreren gleichen: Summe aller).
static func run_line(origin: StringName, same_count: int) -> String:
	var kills: int = GameState.run_stats.kills_of(origin)
	var damage: int = GameState.run_stats.damage_of(origin)
	if same_count > 1:
		return "[color=%s]%s[/color]" % [MUTED_COLOR, TextFormat.t("TIP_RUN_ALL") % [same_count, kills, damage]]
	return "[color=%s]%s[/color]" % [MUTED_COLOR, TextFormat.t("TIP_RUN") % [kills, damage]]


# --- Stats ---

## Wert eines Stats für das Stat-Panel: grün/rot/neutral, mit Obergrenze "(max. 60 %)", erreicht = gelb.
static func stat_value(stat: StringName, value: float, cap: float) -> String:
	var text: String = TextFormat.stat_value(stat, value)
	if cap != INF and value >= cap:
		return "[color=%s]%s[/color] [color=%s]%s[/color]" % [CAP_COLOR, text, CAP_COLOR, cap_suffix(stat, cap)]
	if not is_zero_approx(value):
		text = TextFormat.colored(text, TextFormat.is_good(stat, value))
	if cap != INF:
		text += " [color=%s]%s[/color]" % [MUTED_COLOR, cap_suffix(stat, cap)]
	return text


static func cap_suffix(stat: StringName, cap: float) -> String:
	return TextFormat.t("STAT_CAP") % (TextFormat.number(cap) + (" %" if stat in TextFormat.PERCENT_SUFFIX_STATS else ""))


## Tooltip eines Stats: Name, Wirkung und bei Stats mit Obergrenze die Erklärung der Grenze (Lexikon-Texte).
## Mit `stats` zusätzlich die Beiträge aus Umrechnungen ("+12 Schaden % durch Panzerglas").
static func stat(stat_name: StringName, cap: float, stats: StatSystem = null) -> String:
	var values: Dictionary = Lexicon.stat_values()
	var lines: PackedStringArray = ["[font_size=%d]%s[/font_size]" % [TITLE_SIZE, TextFormat.t(Stats.label_key(stat_name))],
		Lexicon.stat_text(stat_name, Lexicon.STAT_INFO_PART, values)]
	if cap != INF:
		lines.append(Lexicon.stat_heading_line(stat_name, Lexicon.STAT_LIMIT_PART, values))
	if stats != null:
		lines.append_array(conversion_lines(stat_name, stats))
	return "\n".join(lines)


## Je Umrechnung eine Zeile "+12 Schaden % durch Panzerglas (aus 12 Rüstung)".
static func conversion_lines(stat_name: StringName, stats: StatSystem) -> PackedStringArray:
	var lines: PackedStringArray = []
	for part: Dictionary in stats.get_conversion_parts(stat_name):
		var from: StringName = part["from"]
		var amount: float = stats.get_source(from) if Stats.is_source(from) else stats.get_stat(from)
		lines.append(TextFormat.t("STAT_SOURCE_LINE") % [TextFormat.modifier_line(StatModifier.create(stat_name, part["value"])),
			RunReport.source_name(part["origin"]), TextFormat.stat_value(from, floorf(maxf(0.0, amount))), TextFormat.t(Stats.label_key(from))])
	return lines
