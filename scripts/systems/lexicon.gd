class_name Lexicon
extends RefCounted
## Baut die Lexikon-Einträge aller Reiter aus den Resources der DataRegistry (keine handgeschriebenen Listen).
## Effekttexte kommen aus denselben Funktionen wie die Shop-Tooltips (TextFormat, ItemData.get_description).

enum Tab { CHARACTERS, WEAPONS, ITEMS, ENEMIES, CLASSES, MECHANICS }
enum EnemyKind { NORMAL, ELITE, BOSS }

const TAB_KEYS: PackedStringArray = [
	"LEX_TAB_CHARACTERS", "LEX_TAB_WEAPONS", "LEX_TAB_ITEMS", "LEX_TAB_ENEMIES", "LEX_TAB_CLASSES", "LEX_TAB_MECHANICS",
]
const ENEMY_KIND_KEYS: PackedStringArray = ["LEX_ENEMY_NORMAL", "LEX_ENEMY_ELITE", "LEX_ENEMY_BOSS"]
## Welle, für die Gegnerwerte und Item-Preise im Lexikon als Beispiel berechnet werden.
const EXAMPLE_WAVE: int = 20
const LORE_COLOR: String = "#C9B8E8"
const HEADING_COLOR: String = "#FFD43B"
const DASH: String = "–"
const PERCENT: float = 100.0

const DROPS: DropConfig = preload("res://data/config/drop_config.tres")
const PLAYER: PlayerConfig = preload("res://data/config/player_config.tres")
const SHOP: ShopConfig = preload("res://data/config/shop_config.tres")
const RARITY: RarityConfig = preload("res://data/config/rarity_config.tres")
const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const WAVES: WaveConfig = preload("res://data/config/wave_config.tres")


static func tab_count() -> int:
	return TAB_KEYS.size()


static func tab_title(tab: int) -> String:
	return TextFormat.t(TAB_KEYS[tab])


static func entries(tab: int) -> Array[LexiconEntry]:
	match tab:
		Tab.CHARACTERS:
			return character_entries()
		Tab.WEAPONS:
			return weapon_entries()
		Tab.ITEMS:
			return item_entries()
		Tab.ENEMIES:
			return enemy_entries()
		Tab.CLASSES:
			return class_entries()
		Tab.MECHANICS:
			return topic_entries()
	return []


static func strip_bbcode(text: String) -> String:
	return RegEx.create_from_string("\\[[^\\]]*\\]").sub(text, "", true)


## Spruch eines Eintrags als BBCode (kursiv, eigene Farbe).
static func lore_bbcode(text: String) -> String:
	return "[i][color=%s]„%s“[/color][/i]" % [LORE_COLOR, text]


static func t(key: String) -> String:
	return TextFormat.t(key)


static func _or_none(text: String) -> String:
	return text if text.strip_edges() != "" else t("LEX_NONE")


static func _percent(share: float) -> String:
	return TextFormat.number(share * PERCENT)


static func _by_title(a: LexiconEntry, b: LexiconEntry) -> bool:
	return a.title.naturalnocasecmp_to(b.title) < 0


# --- Charaktere ---

static func character_entries() -> Array[LexiconEntry]:
	var result: Array[LexiconEntry] = []
	for character: CharacterData in Unlocks.all_characters():
		result.append(character_entry(character))
	return result


static func character_entry(character: CharacterData) -> LexiconEntry:
	var entry: LexiconEntry = _base(Tab.CHARACTERS, character, character.id, character.name_key, character.get_portrait())
	entry.order = character.order
	entry.locked = not Unlocks.is_unlocked(character)
	var challenge: ChallengeData = Unlocks.challenge_for(character)
	entry.subtitle = t("LEX_START_CHARACTER") if challenge == null else t("LEX_UNLOCKABLE")
	entry.lock_text = _unlock_text(challenge)
	entry.add_text(t("LEX_STATS"), _or_none(TextFormat.describe_character_stats(character)))
	entry.add_text(t("LEX_SPECIAL"), _or_none("\n".join(TextFormat.character_special_lines(character))))
	var weapons: PackedStringArray = []
	for weapon: WeaponData in character.starting_weapons:
		weapons.append(t(weapon.name_key))
	entry.add_text(t("LEX_START_WEAPONS"), ", ".join(weapons))
	entry.add_text(t("LEX_TIP"), t(character.tip_key))
	entry.add_text(t("LEX_UNLOCK"), entry.lock_text)
	var win_item: ItemData = win_item_for(character)
	entry.add_text(t("LEX_WIN_ITEM"), t(win_item.name_key) if win_item != null else t("LEX_NONE"))
	return entry


## Item, das ein Sieg mit diesem Charakter im Shop freischaltet.
static func win_item_for(character: CharacterData) -> ItemData:
	for challenge: ChallengeData in Unlocks.all_challenges():
		if challenge.condition == ChallengeData.Condition.WIN_WITH_CHARACTER and challenge.character == character:
			return challenge.reward_item
	return null


## Bedingung mit Fortschritt ("Fortschritt: 128/300") oder "Von Beginn an verfügbar".
static func _unlock_text(challenge: ChallengeData) -> String:
	if challenge == null:
		return t("CHALLENGE_START")
	var lines: PackedStringArray = [challenge.condition_text()]
	if SaveManager.is_challenge_completed(challenge.id):
		lines.append(TextFormat.colored(t("LEX_COMPLETED"), true))
	else:
		var progress: String = challenge.progress_text(Unlocks.progress(challenge))
		if progress != "":
			lines.append(t("CHALLENGE_PROGRESS") % progress)
	return "\n".join(lines)


# --- Waffen ---

static func weapon_entries() -> Array[LexiconEntry]:
	var result: Array[LexiconEntry] = []
	for res: Resource in DataRegistry.get_all("weapons"):
		result.append(weapon_entry(res as WeaponData))
	result.sort_custom(_by_title)
	return result


static func weapon_entry(weapon: WeaponData) -> LexiconEntry:
	var entry: LexiconEntry = _base(Tab.WEAPONS, weapon, weapon.id, weapon.name_key, weapon.texture)
	entry.melee = weapon.is_melee()
	entry.classes = weapon.classes
	entry.subtitle = t("LEX_KIND_%d" % weapon.kind)
	var header: PackedStringArray = [""]
	var rows: Dictionary[String, PackedStringArray] = {
		"LEX_ROW_DAMAGE": [t("LEX_ROW_DAMAGE")], "LEX_ROW_COOLDOWN": [t("LEX_ROW_COOLDOWN")],
		"LEX_ROW_RANGE": [t("LEX_ROW_RANGE")], "LEX_ROW_CRIT": [t("LEX_ROW_CRIT")], "LEX_ROW_PRICE": [t("LEX_ROW_PRICE")],
	}
	for tier: int in range(WeaponData.MIN_TIER, WeaponData.MAX_TIER + 1):
		var stats: WeaponTierStats = weapon.get_tier(tier)
		header.append(TextFormat.tier_name(tier))
		var damage: String = TextFormat.number(stats.base_damage)
		if stats.projectile_count > 1:
			damage += " x%d" % stats.projectile_count
		rows["LEX_ROW_DAMAGE"].append(damage)
		rows["LEX_ROW_COOLDOWN"].append(t("LEX_SECONDS") % ("%.2f" % stats.cooldown))
		rows["LEX_ROW_RANGE"].append(TextFormat.number(stats.range))
		rows["LEX_ROW_CRIT"].append("%s %% x%s" % [TextFormat.number(stats.crit_chance * PERCENT), TextFormat.number(stats.crit_multiplier)])
		rows["LEX_ROW_PRICE"].append(str(stats.price))
	var table: Array[PackedStringArray] = [header]
	for key: String in rows:
		table.append(rows[key])
	entry.add_table(t("LEX_TIERS"), table)
	entry.add_text(t("LEX_SCALING"), TextFormat.weapon_scaling_text(weapon.get_tier(WeaponData.MIN_TIER)))
	entry.add_text(t("LEX_CLASSES"), TextFormat.weapon_classes_text(weapon))
	entry.add_text(t("LEX_SPECIAL"), _or_none(_weapon_specials(weapon)))
	return entry


## Besonderheiten je Tier; ein Tier wird nur aufgeführt, wenn sich etwas gegenüber dem vorigen ändert.
static func _weapon_specials(weapon: WeaponData) -> String:
	var blocks: PackedStringArray = []
	var previous: PackedStringArray = []
	for tier: int in range(WeaponData.MIN_TIER, WeaponData.MAX_TIER + 1):
		var lines: PackedStringArray = TextFormat.weapon_special_lines(weapon, tier)
		if lines.is_empty() or lines == previous:
			continue
		var text: String = "\n".join(lines)
		blocks.append(text if previous.is_empty() and tier == WeaponData.MIN_TIER else "%s:\n%s" % [TextFormat.tier_name(tier), text])
		previous = lines
	if blocks.size() > 1:
		blocks[0] = "%s:\n%s" % [TextFormat.tier_name(WeaponData.MIN_TIER), blocks[0]]
	return "\n".join(blocks)


# --- Items ---

static func item_entries() -> Array[LexiconEntry]:
	var result: Array[LexiconEntry] = []
	for res: Resource in DataRegistry.get_all("items"):
		result.append(item_entry(res as ItemData))
	result.sort_custom(sort_by_tier)
	return result


static func sort_by_tier(a: LexiconEntry, b: LexiconEntry) -> bool:
	if a.tier != b.tier:
		return a.tier < b.tier
	return _by_title(a, b)


static func sort_by_name(a: LexiconEntry, b: LexiconEntry) -> bool:
	return _by_title(a, b)


static func item_entry(item: ItemData) -> LexiconEntry:
	var entry: LexiconEntry = _base(Tab.ITEMS, item, item.id, item.name_key, item.icon)
	entry.tier = item.tier
	entry.tags = item.tags
	entry.color = UiStyle.tier_color(item.tier)
	entry.subtitle = TextFormat.tier_name(item.tier)
	entry.locked = not Unlocks.is_item_unlocked(item)
	var challenge: ChallengeData = challenge_for_item(item)
	entry.lock_text = _item_unlock_text(challenge)
	entry.add_text(t("LEX_EFFECTS"), item.get_description())
	entry.add_text(t("LEX_PRICE"), t("LEX_PRICE_TEXT") % [item.price, EXAMPLE_WAVE, Economy.inflated_price(item.price, EXAMPLE_WAVE, 0.0)])
	entry.add_text(t("LEX_LIMIT"), str(item.limit) if item.limit > 0 else t("LEX_NO_LIMIT"))
	var tags: PackedStringArray = []
	for tag: StringName in item.tags:
		tags.append(t(tag_key(tag)))
	entry.add_text(t("LEX_TAGS"), _or_none(", ".join(tags)))
	entry.add_text(t("LEX_UNLOCK"), entry.lock_text)
	return entry


static func tag_key(tag: StringName) -> String:
	return "TAG_" + String(tag).to_upper()


static func challenge_for_item(item: ItemData) -> ChallengeData:
	for challenge: ChallengeData in Unlocks.all_challenges():
		if challenge.reward_item == item:
			return challenge
	return null


static func _item_unlock_text(challenge: ChallengeData) -> String:
	if challenge != null and challenge.condition == ChallengeData.Condition.WIN_WITH_CHARACTER:
		var text: String = t("LEX_WIN_UNLOCK") % t(challenge.character.name_key)
		if SaveManager.is_challenge_completed(challenge.id):
			text += "\n" + TextFormat.colored(t("LEX_COMPLETED"), true)
		return text
	return _unlock_text(challenge)


# --- Gegner ---

static func enemy_entries() -> Array[LexiconEntry]:
	var result: Array[LexiconEntry] = []
	for res: Resource in DataRegistry.get_all("enemies"):
		result.append(enemy_entry(res as EnemyData))
	result.sort_custom(func(a: LexiconEntry, b: LexiconEntry) -> bool:
		if a.enemy_kind != b.enemy_kind:
			return a.enemy_kind < b.enemy_kind
		if a.order != b.order:
			return a.order < b.order
		return _by_title(a, b))
	return result


static func enemy_kind(enemy: EnemyData) -> EnemyKind:
	if enemy.is_boss:
		return EnemyKind.BOSS
	return EnemyKind.ELITE if enemy.is_elite else EnemyKind.NORMAL


static func enemy_entry(enemy: EnemyData) -> LexiconEntry:
	var entry: LexiconEntry = _base(Tab.ENEMIES, enemy, enemy.id, enemy.name_key, enemy.texture)
	entry.enemy_kind = enemy_kind(enemy)
	entry.subtitle = t(ENEMY_KIND_KEYS[entry.enemy_kind])
	entry.color = [UiStyle.TEXT_COLOR, UiStyle.tier_color(3), UiStyle.tier_color(4)][entry.enemy_kind]
	entry.order = first_wave(enemy)
	entry.add_text(t("LEX_BEHAVIOR"), t(enemy.behavior_key))
	# Elites kommen nur in Sonderwellen vor: Beispielwerte für ihre letzte mögliche Welle
	var elite_waves: Array[int] = _elite_waves()
	var wave: int = elite_waves.back() if enemy.is_elite and not elite_waves.is_empty() else EXAMPLE_WAVE
	var table: Array[PackedStringArray] = [
		PackedStringArray(["", t("LEX_BASE"), t("LEX_PER_WAVE"), t("LEX_AT_WAVE") % wave]),
		PackedStringArray([t("LEX_ROW_HP"), TextFormat.number(enemy.base_hp), TextFormat.signed_number(enemy.hp_per_wave),
			TextFormat.number(roundf(enemy.hp_for_wave(wave)))]),
		PackedStringArray([t("LEX_ROW_CONTACT"), TextFormat.number(enemy.base_damage), TextFormat.signed_number(enemy.damage_per_wave),
			TextFormat.number(enemy.damage_for_wave(wave))]),
	]
	if enemy.projectile_damage_base > 0.0:
		table.append(PackedStringArray([t("LEX_ROW_PROJECTILE"), TextFormat.number(enemy.projectile_damage_base),
			TextFormat.signed_number(enemy.projectile_damage_per_wave), TextFormat.number(enemy.projectile_damage_for_wave(wave))]))
	var speed: String = TextFormat.number(enemy.speed_min)
	if enemy.speed_max > enemy.speed_min:
		speed += DASH + TextFormat.number(enemy.speed_max)
	table.append(PackedStringArray([t("LEX_ROW_SPEED"), speed, DASH, speed]))
	entry.add_table(t("LEX_VALUES"), table)
	entry.add_text(t("LEX_FIRST_WAVE"), first_wave_text(enemy))
	entry.add_text(t("LEX_DROPS"), _drops_text(enemy))
	entry.add_text(t("LEX_COUNTER"), t(enemy.counter_key))
	var phased: PhasedData = enemy.behavior as PhasedData
	if phased != null:
		entry.add_text(t("LEX_PHASES"), _phases_text(phased))
	return entry


## Erste Welle, in der der Gegner auftaucht (über Wellen, Funkendieb-Regel, Freisetzung beim Tod und Sonderwellen).
static func first_wave(enemy: EnemyData) -> int:
	var best: int = _first_wave_in_groups(enemy)
	if enemy == DROPS.thief:
		best = mini(best, DROPS.thief_first_wave)
	for res: Resource in DataRegistry.get_all("enemies"):
		var parent: EnemyData = res as EnemyData
		if parent.death_spawn == enemy and parent != enemy:
			best = mini(best, _first_wave_in_groups(parent))
	var elite_waves: Array[int] = _elite_waves()
	if enemy.is_elite and not elite_waves.is_empty():
		best = mini(best, elite_waves[0])
	if enemy.is_boss:
		best = mini(best, _boss_wave())
	return best


static func _first_wave_in_groups(enemy: EnemyData) -> int:
	var best: int = 1 << 30
	for res: Resource in DataRegistry.get_all("waves"):
		var wave: WaveData = res as WaveData
		for group: SpawnGroupData in wave.groups:
			if group.enemy == enemy:
				best = mini(best, wave.wave_number)
	return best


## Niedrigste Spannung, ab der der Gegner in seiner ersten Welle erscheint.
static func _min_difficulty(enemy: EnemyData, wave_number: int) -> int:
	var best: int = 1 << 30
	for res: Resource in DataRegistry.get_all("waves"):
		var wave: WaveData = res as WaveData
		if wave.wave_number != wave_number:
			continue
		for group: SpawnGroupData in wave.groups:
			if group.enemy == enemy:
				best = mini(best, group.min_difficulty)
	return 0 if best == 1 << 30 else best


static func _difficulties() -> Array[DifficultyData]:
	var result: Array[DifficultyData] = []
	for res: Resource in DataRegistry.get_all("difficulties"):
		result.append(res as DifficultyData)
	result.sort_custom(func(a: DifficultyData, b: DifficultyData) -> bool: return a.level < b.level)
	return result


## Alle möglichen Elite-Wellen (aus der Spannung mit den meisten Sonderwellen).
static func _elite_waves() -> Array[int]:
	var result: Array[int] = []
	for difficulty: DifficultyData in _difficulties():
		for pair: Vector2i in difficulty.special_wave_pairs:
			for wave: int in [pair.x, pair.y]:
				if wave not in result:
					result.append(wave)
	result.sort()
	return result


static func _elite_min_difficulty() -> int:
	for difficulty: DifficultyData in _difficulties():
		if not difficulty.special_wave_pairs.is_empty():
			return difficulty.level
	return 0


static func _boss_wave() -> int:
	for res: Resource in DataRegistry.get_all("waves"):
		var wave: WaveData = res as WaveData
		if wave.is_boss:
			return wave.wave_number
	return 0


static func first_wave_text(enemy: EnemyData) -> String:
	if enemy.is_boss:
		var text: String = t("LEX_WAVE_BOSS") % _boss_wave()
		for difficulty: DifficultyData in _difficulties():
			if difficulty.double_boss:
				return text + "\n" + t("LEX_WAVE_DOUBLE_BOSS") % difficulty.level
		return text
	if enemy.is_elite:
		var pairs: PackedStringArray = []
		var difficulties: Array[DifficultyData] = _difficulties()
		for pair: Vector2i in difficulties[difficulties.size() - 1].special_wave_pairs:
			pairs.append("%d/%d" % [pair.x, pair.y])
		return t("LEX_WAVE_ELITE") % [_elite_min_difficulty(), ", ".join(pairs)]
	var wave: int = first_wave(enemy)
	var text: String = t("LEX_WAVE_FROM") % wave
	if enemy == DROPS.thief:
		text = t("LEX_WAVE_THIEF") % [wave, roundi(DROPS.thief_chance * PERCENT)]
	var difficulty: int = _min_difficulty(enemy, wave)
	if difficulty > 0:
		text += " " + t("LEX_WAVE_DIFFICULTY") % difficulty
	return text


static func _drops_text(enemy: EnemyData) -> String:
	var lines: PackedStringArray = []
	if enemy.sparks > 0:
		lines.append(t("LEX_DROP_SPARKS") % enemy.sparks)
	if enemy.guaranteed_crate:
		lines.append(t("LEX_DROP_CRATE"))
	if enemy.legendary_crate:
		lines.append(t("LEX_DROP_LEGENDARY"))
	if enemy.death_spawn != null and enemy.death_spawn_count > 0:
		lines.append(t("LEX_DROP_SPAWN") % [enemy.death_spawn_count, t(enemy.death_spawn.name_key)])
	if enemy.is_boss:
		lines.append(t("LEX_DROP_VICTORY"))
	else:
		lines.append(t("LEX_DROP_CONSUMABLE") % _percent(DROPS.consumable_base_chance))
	return "\n".join(lines)


static func _phases_text(phased: PhasedData) -> String:
	var lines: PackedStringArray = []
	for index: int in phased.phases.size():
		var phase: BossPhaseData = phased.phases[index]
		var line: String = t("LEX_PHASE") % [index + 1, t(phase.description_key)]
		if phase.next_at_hp > 0.0 and phase.max_duration > 0.0:
			line += " " + t("LEX_PHASE_UNTIL_HP_TIME") % [roundi(phase.next_at_hp * PERCENT), TextFormat.number(phase.max_duration)]
		elif phase.next_at_hp > 0.0:
			line += " " + t("LEX_PHASE_UNTIL_HP") % roundi(phase.next_at_hp * PERCENT)
		lines.append(line)
	return "\n".join(lines)


# --- Waffenklassen ---

static func class_entries() -> Array[LexiconEntry]:
	var result: Array[LexiconEntry] = []
	for res: Resource in DataRegistry.get_all("sets"):
		result.append(class_entry(res as SetBonusData))
	result.sort_custom(func(a: LexiconEntry, b: LexiconEntry) -> bool: return a.order < b.order)
	return result


static func weapons_of_class(weapon_class: StringName) -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for res: Resource in DataRegistry.get_all("weapons"):
		var weapon: WeaponData = res as WeaponData
		if weapon_class in weapon.classes:
			result.append(weapon)
	result.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return t(a.name_key).naturalnocasecmp_to(t(b.name_key)) < 0)
	return result


static func class_entry(set_bonus: SetBonusData) -> LexiconEntry:
	var weapons: Array[WeaponData] = weapons_of_class(set_bonus.weapon_class)
	var icon: Texture2D = weapons[0].texture if not weapons.is_empty() else null
	var entry: LexiconEntry = _base(Tab.CLASSES, set_bonus, set_bonus.weapon_class, WeaponClasses.label_key(set_bonus.weapon_class), icon)
	var class_index: int = WeaponClasses.ALL.find(set_bonus.weapon_class)
	entry.order = class_index if class_index >= 0 else WeaponClasses.ALL.size()
	entry.subtitle = t("LEX_WEAPON_COUNT") % weapons.size()
	entry.add_table(t("LEX_SET_BONUS"), set_bonus_table(set_bonus))
	var names: PackedStringArray = []
	for weapon: WeaponData in weapons:
		names.append(t(weapon.name_key))
	entry.add_text(t("LEX_CLASS_WEAPONS"), _or_none(", ".join(names)))
	return entry


## Zeilen = Stats, Spalten = Anzahl Waffen der Klasse (2-6).
static func set_bonus_table(set_bonus: SetBonusData) -> Array[PackedStringArray]:
	var header: PackedStringArray = [t("LEX_WEAPONS_SHORT")]
	var stats: Array[StringName] = []
	for index: int in set_bonus.levels.size():
		header.append(str(SetBonusData.MIN_WEAPONS + index))
		for mod: StatModifier in set_bonus.levels[index].modifiers:
			if mod.stat not in stats:
				stats.append(mod.stat)
	var table: Array[PackedStringArray] = [header]
	for stat: StringName in stats:
		var row: PackedStringArray = [t(Stats.label_key(stat))]
		for level: StatEffect in set_bonus.levels:
			var value: float = 0.0
			var unit: String = ""
			for mod: StatModifier in level.modifiers:
				if mod.stat == stat:
					value += mod.value
					if mod.kind == StatModifier.Kind.PERCENT or stat in TextFormat.PERCENT_SUFFIX_STATS:
						unit = " %"
			row.append(TextFormat.colored(TextFormat.signed_number(value) + unit, TextFormat.is_good(stat, value)) if value != 0.0 else DASH)
		table.append(row)
	return table


# --- Spielmechaniken ---

static func topic_entries() -> Array[LexiconEntry]:
	var result: Array[LexiconEntry] = []
	for res: Resource in DataRegistry.get_all("lexicon"):
		result.append(topic_entry(res as LexiconTopicData))
	result.sort_custom(func(a: LexiconEntry, b: LexiconEntry) -> bool: return a.order < b.order)
	return result


static func topic_entry(topic: LexiconTopicData) -> LexiconEntry:
	var entry: LexiconEntry = _base(Tab.MECHANICS, topic, topic.id, topic.name_key, topic.icon)
	entry.order = topic.order
	entry.subtitle = t("LEX_STAT_COUNT") % topic.stats.size() if not topic.stats.is_empty() else t("LEX_TOPIC")
	if topic.text_key != "":
		entry.add_text(t("LEX_EXPLANATION"), topic_text(topic.text_key))
	match topic.table:
		LexiconTopicData.Table.DIFFICULTIES:
			entry.add_table(t("LEX_DIFFICULTY_TABLE"), difficulty_table())
			var lines: PackedStringArray = []
			for difficulty: DifficultyData in _difficulties():
				lines.append("%s: %s %s" % [t(difficulty.name_key), t(difficulty.description_key), lore_bbcode(t(difficulty.lore_text))])
			entry.add_text(t("LEX_DIFFICULTY_LIST"), "\n".join(lines))
		LexiconTopicData.Table.UPGRADES:
			entry.add_table(t("LEX_UPGRADE_TABLE"), upgrade_table())
	for stat: StringName in topic.stats:
		entry.add_text(t(Stats.label_key(stat)), stat_info(stat))
	return entry


static func difficulty_table() -> Array[PackedStringArray]:
	var table: Array[PackedStringArray] = [
		PackedStringArray(["", t("LEX_ROW_HP"), t("LEX_ROW_DAMAGE"), t("LEX_SPECIAL_WAVES")]),
	]
	for difficulty: DifficultyData in _difficulties():
		var pairs: PackedStringArray = []
		for pair: Vector2i in difficulty.special_wave_pairs:
			pairs.append("%d/%d" % [pair.x, pair.y])
		table.append(PackedStringArray([t(difficulty.name_key), "+%s %%" % TextFormat.number(difficulty.enemy_hp_pct),
			"+%s %%" % TextFormat.number(difficulty.enemy_damage_pct), ", ".join(pairs) if not pairs.is_empty() else DASH]))
	return table


static func upgrade_table() -> Array[PackedStringArray]:
	var header: PackedStringArray = [""]
	for tier: int in range(WeaponData.MIN_TIER, WeaponData.MAX_TIER + 1):
		header.append(TextFormat.tier_name(tier))
	var table: Array[PackedStringArray] = [header]
	var upgrades: Array[UpgradeData] = []
	for res: Resource in DataRegistry.get_all("upgrades"):
		upgrades.append(res as UpgradeData)
	upgrades.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return Stats.PRIMARY.find(a.stat) < Stats.PRIMARY.find(b.stat))
	for upgrade: UpgradeData in upgrades:
		var row: PackedStringArray = [t(Stats.label_key(upgrade.stat))]
		for value: float in upgrade.tier_values:
			row.append(TextFormat.signed_number(value) + (" %" if upgrade.stat in TextFormat.PERCENT_SUFFIX_STATS else ""))
		table.append(row)
	return table


## Erklärtext eines Themas, gefüllt mit den aktuellen Werten aus Configs und Formeln (Text immer mit %% für Prozent).
static func topic_text(key: String) -> String:
	var args: Array = []
	match key:
		"LEX_TOPIC_SHOP_TEXT":
			args = [SHOP.offer_count, RARITY.unlock[1], RARITY.unlock[2], RARITY.unlock[3],
				_percent(Economy.INFLATION_SHARE), TextFormat.number(Economy.INFLATION_FLAT), _percent(SHOP.recycle_share)]
		"LEX_TOPIC_LEVELS_TEXT":
			var tier_3: PackedStringArray = []
			for level: int in RARITY.guaranteed_tier_3_levels:
				tier_3.append(str(level))
			args = [Economy.XP_LEVEL_OFFSET, TextFormat.number(PLAYER.max_hp_per_level), SHOP.upgrade_card_count,
				RARITY.guaranteed_tier_2_level, "/".join(tier_3), RARITY.guaranteed_tier_4_from_level, RARITY.guaranteed_tier_4_every]
		"LEX_TOPIC_HARVEST_TEXT":
			args = [_percent(Economy.HARVESTING_GROWTH), _percent(WAVES.endless_harvest_factor)]
		"LEX_TOPIC_CRATES_TEXT":
			args = [_percent(DROPS.consumable_base_chance), TextFormat.number(DROPS.battery_heal), _percent(DROPS.crate_base_chance),
				TextFormat.number(DROPS.crate_heal), _percent(SHOP.recycle_share), TextFormat.number(DROPS.crystal_first_spawn),
				DROPS.crystal_max_hits, DROPS.crystal_sparks, _percent(DROPS.crystal_crate_share)]
		"LEX_TOPIC_BURN_TEXT":
			args = [TextFormat.number(COMBAT.burn_interval), TextFormat.number(COMBAT.burn_spread_radius)]
		"LEX_TOPIC_CURSE_TEXT":
			args = [TextFormat.number(STATUS.curse_tick_interval)]
		"LEX_TOPIC_SLOW_TEXT":
			args = [TextFormat.number(STATUS.root_immunity_time), _percent(STATUS.boss_status_factor)]
		"LEX_TOPIC_ALLIES_TEXT":
			args = [TextFormat.number(STATUS.ally_contact_interval), STATUS.ally_global_max]
	return t(key) % args


## Alltagssprachliche Erklärung eines Stats mit den Zahlen aus den Formeln (CombatMath, Economy, Configs).
static func stat_info(stat: StringName) -> String:
	var args: Array = []
	match stat:
		Stats.MAX_HP:
			args = [TextFormat.number(PLAYER.max_hp_per_level)]
		Stats.HP_REGEN:
			args = [TextFormat.number(CombatMath.REGEN_FIRST_POINT), TextFormat.number(CombatMath.REGEN_PER_EXTRA_POINT),
				"%.1f" % CombatMath.hp_regen_per_second(10.0)]
		Stats.LIFESTEAL:
			args = [TextFormat.number(1.0 / CombatMath.LIFESTEAL_INTERVAL)]
		Stats.DAMAGE_PCT:
			args = [CombatMath.MIN_DAMAGE]
		Stats.ATTACK_SPEED:
			args = ["%.2f" % CombatMath.attack_cooldown(1.0, 50.0), _percent(CombatMath.NEGATIVE_ATTACK_SPEED_FACTOR),
				TextFormat.number(CombatMath.MAX_ATTACKS_PER_SECOND)]
		Stats.RANGE:
			args = [_percent(CombatMath.MELEE_RANGE_FACTOR), TextFormat.number(CombatMath.MIN_RANGE)]
		Stats.ARMOR:
			args = [roundi((1.0 - CombatMath.armor_multiplier(5.0)) * PERCENT), roundi((1.0 - CombatMath.armor_multiplier(15.0)) * PERCENT),
				TextFormat.number(CombatMath.ARMOR_CONSTANT)]
		Stats.DODGE:
			args = [TextFormat.number(PLAYER.dodge_cap)]
		Stats.SPEED:
			args = [TextFormat.number(PLAYER.base_move_speed)]
		Stats.HARVESTING:
			args = [_percent(Economy.HARVESTING_GROWTH)]
		Stats.PICKUP_RANGE_PCT:
			args = [TextFormat.number(PLAYER.pickup_radius)]
		Stats.CONSUMABLE_HEAL:
			args = [TextFormat.number(DROPS.battery_heal)]
	return t("STAT_INFO_" + String(stat).to_upper()) % args


# --- Gemeinsam ---

static func _base(tab: int, source: Resource, id: StringName, name_key: String, icon: Texture2D) -> LexiconEntry:
	var entry: LexiconEntry = LexiconEntry.new()
	entry.tab = tab
	entry.source = source
	entry.id = id
	entry.title = t(name_key)
	entry.icon = icon
	var lore_key: String = source.get("lore_text")
	entry.lore = t(lore_key) if lore_key != "" else ""
	return entry
