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
## Ab diesem Durchschlag gilt eine Waffe als "durchschlägt alle".
const PIERCE_ALL: int = 99
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


## Beschreibung eines Charakters: Stat-Änderungen, Sondereffekte und Sonderregeln (BBCode).
static func describe_character(character: CharacterData) -> String:
	var lines: PackedStringArray = []
	var stats: String = describe_character_stats(character)
	if stats != "":
		lines.append(stats)
	lines.append_array(character_special_lines(character))
	return "\n".join(lines)


## Nur die Stat-Änderungen eines Charakters (BBCode, leer ohne Stats).
static func describe_character_stats(character: CharacterData) -> String:
	var mods: Array[StatModifier] = []
	for effect: ItemEffect in character.effects:
		mods.append_array(effect.get_modifiers())
	return describe_modifiers(mods)


## Sondereffekte und Sonderregeln eines Charakters (ohne reine Stat-Änderungen).
static func character_special_lines(character: CharacterData) -> PackedStringArray:
	var lines: PackedStringArray = []
	for effect: ItemEffect in character.effects:
		lines.append_array(effect.describe())
	if character.weapon_slots != Player.DEFAULT_WEAPON_SLOTS:
		lines.append(t("CHAR_RULE_SLOTS") % character.weapon_slots)
	if character.no_melee:
		lines.append(t("CHAR_RULE_NO_MELEE"))
	for weapon_class: StringName in character.banned_classes:
		lines.append(t("CHAR_RULE_BANNED") % t(WeaponClasses.label_key(weapon_class)))
	for weapon_class: StringName in character.set_bonus_multiplier:
		lines.append(t("CHAR_RULE_SET_MULT") % [t(WeaponClasses.label_key(weapon_class)), number(character.set_bonus_multiplier[weapon_class])])
	return lines


## Übersetzung als String (für den %-Operator auch außerhalb von Nodes).
static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## Kurzbeschreibung einer Waffe in einem Tier (Schaden mit Skalierung, Tempo, Reichweite, Besonderheiten, Klassen).
static func describe_weapon(weapon: WeaponData, tier: int) -> String:
	var tier_stats: WeaponTierStats = weapon.get_tier(tier)
	var lines: PackedStringArray = []
	lines.append(t("WEAPON_DAMAGE") % [number(tier_stats.base_damage), weapon_scaling_text(tier_stats)])
	lines.append(t("WEAPON_COOLDOWN") % ("%.2f" % tier_stats.cooldown))
	lines.append(t("WEAPON_RANGE") % number(tier_stats.range))
	lines.append(t("WEAPON_CRIT") % [number(tier_stats.crit_chance * 100.0), number(tier_stats.crit_multiplier)])
	lines.append_array(weapon_special_lines(weapon, tier))
	lines.append(t("WEAPON_CLASSES") % weapon_classes_text(weapon))
	return "\n".join(lines)


## Skalierung wie "100 % Nah, 50 % Strom".
static func weapon_scaling_text(tier_stats: WeaponTierStats) -> String:
	var scalings: PackedStringArray = []
	for stat: StringName in tier_stats.scalings:
		scalings.append("%d %% %s" % [roundi(tier_stats.scalings[stat] * 100.0), t(Stats.label_key(stat))])
	return ", ".join(scalings)


static func weapon_classes_text(weapon: WeaponData) -> String:
	var classes: PackedStringArray = []
	for weapon_class: StringName in weapon.classes:
		classes.append(t(WeaponClasses.label_key(weapon_class)))
	return ", ".join(classes)


## Besonderheiten einer Waffe in einem Tier (Rückstoß, Durchschlag, Brand, ...); leer bei einfachen Waffen.
static func weapon_special_lines(weapon: WeaponData, tier: int) -> PackedStringArray:
	var tier_stats: WeaponTierStats = weapon.get_tier(tier)
	var lines: PackedStringArray = []
	if tier_stats.knockback > 0.0:
		lines.append(t("WEAPON_KNOCKBACK") % number(tier_stats.knockback))
	if tier_stats.piercing >= PIERCE_ALL:
		lines.append(t("WEAPON_PIERCING_ALL"))
	elif tier_stats.piercing > 0:
		lines.append(t("WEAPON_PIERCING") % tier_stats.piercing)
	if tier_stats.bounces > 0:
		lines.append(t("WEAPON_BOUNCES") % tier_stats.bounces)
	if tier_stats.projectile_count > 1:
		lines.append(t("WEAPON_PROJECTILES") % tier_stats.projectile_count)
	if tier_stats.burn_ticks > 0 and tier_stats.burn_chance < 1.0:
		lines.append(t("WEAPON_BURN_CHANCE") % [roundi(tier_stats.burn_chance * 100.0), number(tier_stats.burn_damage), tier_stats.burn_ticks])
	elif tier_stats.burn_ticks > 0:
		lines.append(t("WEAPON_BURN") % [number(tier_stats.burn_damage), tier_stats.burn_ticks])
	if tier_stats.split_count > 0:
		lines.append(t("WEAPON_SPLIT") % [tier_stats.split_count, roundi(tier_stats.split_damage_pct)])
	if tier_stats.root_chance > 0.0:
		lines.append(t("WEAPON_ROOT") % [roundi(tier_stats.root_chance * 100.0), number(tier_stats.root_duration)])
	if tier_stats.extra_souls > 0:
		lines.append(t("WEAPON_SOULS") % tier_stats.extra_souls)
	if tier_stats.chain_count > 0:
		lines.append(t("WEAPON_CHAIN") % tier_stats.chain_count)
	if tier_stats.explosion_radius > 0.0:
		lines.append(t("WEAPON_EXPLOSION") % number(tier_stats.explosion_radius))
	if tier_stats.homing_turn_deg > 0.0:
		lines.append(t("WEAPON_HOMING"))
	if tier_stats.heal_on_hit_chance > 0.0:
		lines.append(t("WEAPON_HEAL") % roundi(tier_stats.heal_on_hit_chance * 100.0))
	if tier_stats.spark_on_kill_chance > 0.0:
		lines.append(t("WEAPON_SPARK") % roundi(tier_stats.spark_on_kill_chance * 100.0))
	if weapon.damage_per_same_weapon != 0.0:
		lines.append(t("WEAPON_PER_SAME") % number(weapon.damage_per_same_weapon))
	if weapon.structure != null:
		lines.append(t("WEAPON_STRUCTURE") % t(weapon.structure.name_key))
	return lines
