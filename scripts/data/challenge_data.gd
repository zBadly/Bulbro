class_name ChallengeData
extends Resource
## Prüfbare Freischaltbedingung (GDD 10). Belohnung: ein Charakter oder ein Item für den Shop.
## Fortschritt: Run-Bedingungen merken sich den Bestwert, Gesamt-Bedingungen lesen die Summe aus der Statistik.

enum Condition {
	STRUCTURES, ## so viele Strukturen gleichzeitig besitzen
	TOTAL_SPARKS, ## über alle Runs so viele Funken gesammelt
	DISTINCT_WEAPONS, ## so viele verschiedene Waffen gleichzeitig
	DAMAGE_PCT, ## Schaden-% in einem Run erreicht
	HEALED, ## so viele HP in einem Run geheilt
	SPEED_PCT, ## Tempo-% in einem Run erreicht
	WIN_PRIMITIVE_ONLY, ## Run nur mit Primitiv-Waffen gewinnen
	WIN_WITH_CHARACTER, ## Run mit einem bestimmten Charakter gewinnen
	RUN_KILLS, ## so viele Kills in einem Run
	TOTAL_BURN_KILLS, ## über alle Runs so viele Kills durch Brand
	WIN_ELEMENTAL, ## Run gewinnen, in dem Strom diesen Wert erreicht hat
	TOTAL_WEAPON_KILLS, ## über alle Runs so viele Kills mit einer bestimmten Waffe
	TOTAL_CRYSTALS, ## über alle Runs so viele Leuchtkristalle zerstört
	TOWERS_AT_RUN_END, ## beim Run-Ende (Sieg oder Niederlage) stehen so viele Lampentürme
	REACH_WAVE_NO_DODGE, ## diese Welle erreichen, ohne ein Item mit Ausweichen zu nehmen
	LIFESTEAL_HEALED, ## so viele HP in einem Run durch Lebensraub geheilt
	WAVE_SAME_WEAPONS, ## eine Welle mit so vielen gleichen Waffen beenden
	# Ab hier für Achievements (Phase 15, Paket 9); `stat_key` und `entry` geben die Einzelheiten an.
	TOTAL_STAT, ## über alle Runs: Statistik-Schlüssel `stat_key` erreicht diesen Wert
	RUN_VALUE, ## Bestwert eines Runs: RunStats-Wert `stat_key` erreicht diesen Wert
	WIN_ON_DIFFICULTY, ## mit irgendeinem Charakter auf Spannung `value` gewonnen
	WON_DIFFICULTIES, ## auf so vielen verschiedenen Spannungsstufen gewonnen
	WON_CHARACTERS, ## mit so vielen verschiedenen Charakteren gewonnen
	UNLOCKED_CHARACTERS, ## so viele Charaktere freigeschaltet (inkl. Startcharaktere)
	COLLECTION, ## Sammlung `stat_key` hat so viele Einträge (oder enthält `entry`)
	WIN_NO_REROLL, ## Run gewinnen ohne einen Reroll
	WIN_MAX_WEAPONS, ## Run gewinnen, nie mehr als `value` Waffen gleichzeitig
	BOSS_KILL_TIME, ## einen Boss höchstens `value` Sekunden nach seinem Erscheinen besiegen
	ENDLESS_WAVE, ## im Endlos-Modus diese Gesamtwelle erreichen (21 = Endlos 1)
}

@export var id: StringName
@export var condition: Condition = Condition.STRUCTURES
@export var value: float = 0.0
## Für WIN_WITH_CHARACTER.
@export var character: CharacterData
## Für TOTAL_WEAPON_KILLS.
@export var weapon: WeaponData
## Für TOTAL_STAT (Statistik-Schlüssel), RUN_VALUE (Feld in RunStats) und COLLECTION (Name der Sammlung).
@export var stat_key: String = ""
## Für COLLECTION: dieser Eintrag muss enthalten sein (z. B. ein Boss); leer = Anzahl zählt.
@export var entry: StringName = &""
@export var reward_character: CharacterData
@export var reward_item: ItemData


## Siegbedingungen werden ausschließlich am Run-Ende geprüft.
func needs_victory() -> bool:
	return condition in [Condition.WIN_PRIMITIVE_ONLY, Condition.WIN_WITH_CHARACTER, Condition.WIN_ELEMENTAL,
		Condition.WIN_NO_REROLL, Condition.WIN_MAX_WEAPONS]


func needs_run_end() -> bool:
	return needs_victory() or condition == Condition.TOWERS_AT_RUN_END


## Summe über alle Runs statt Bestwert eines Runs.
func is_total() -> bool:
	return condition in [Condition.TOTAL_SPARKS, Condition.TOTAL_BURN_KILLS, Condition.TOTAL_WEAPON_KILLS, Condition.TOTAL_CRYSTALS,
		Condition.TOTAL_STAT]


## Wert steht im Spielstand (Siege, Freischaltungen, Sammlungen, Endlos-Bestwert): auch außerhalb eines Runs prüfbar.
func is_meta() -> bool:
	return condition in [Condition.WIN_ON_DIFFICULTY, Condition.WON_DIFFICULTIES, Condition.WON_CHARACTERS,
		Condition.UNLOCKED_CHARACTERS, Condition.COLLECTION, Condition.ENDLESS_WAVE]


## Ja/Nein-Bedingungen haben keine Zahl als Fortschritt.
func has_progress() -> bool:
	if condition == Condition.COLLECTION:
		return entry == &""
	return condition not in [Condition.WIN_PRIMITIVE_ONLY, Condition.WIN_WITH_CHARACTER, Condition.WIN_ON_DIFFICULTY,
		Condition.WIN_NO_REROLL, Condition.WIN_MAX_WEAPONS, Condition.BOSS_KILL_TIME]


## Statistik-Schlüssel der Gesamt-Bedingungen.
func total_key() -> String:
	match condition:
		Condition.TOTAL_SPARKS:
			return SaveManager.STAT_TOTAL_SPARKS
		Condition.TOTAL_BURN_KILLS:
			return SaveManager.STAT_BURN_KILLS
		Condition.TOTAL_CRYSTALS:
			return SaveManager.STAT_CRYSTALS
		Condition.TOTAL_WEAPON_KILLS:
			return SaveManager.weapon_kills_key(weapon.id)
		Condition.TOTAL_STAT:
			return stat_key
	return ""


## Aktueller Wert für Prüfung und Fortschrittsanzeige.
func current_value(ctx: ChallengeContext) -> float:
	var run: RunStats = ctx.run
	match condition:
		Condition.STRUCTURES:
			return ctx.max_structures
		Condition.DISTINCT_WEAPONS:
			return run.max_distinct_weapons
		Condition.DAMAGE_PCT:
			return run.max_damage_pct
		Condition.HEALED:
			return run.healed
		Condition.SPEED_PCT:
			return run.max_speed_pct
		Condition.RUN_KILLS:
			return run.enemies_killed
		Condition.WIN_ELEMENTAL:
			return run.max_elemental
		Condition.TOWERS_AT_RUN_END:
			return run.current_turrets
		Condition.REACH_WAVE_NO_DODGE:
			return 0.0 if run.dodge_item_taken else ctx.current_wave
		Condition.LIFESTEAL_HEALED:
			return run.lifesteal_healed
		Condition.WAVE_SAME_WEAPONS:
			return run.max_same_weapons
		Condition.RUN_VALUE:
			return run.value_of(stat_key)
		Condition.WON_DIFFICULTIES:
			return SaveManager.won_difficulty_levels().size()
		Condition.WON_CHARACTERS:
			return SaveManager.won_character_count()
		Condition.UNLOCKED_CHARACTERS:
			return Unlocks.unlocked_character_count()
		Condition.COLLECTION:
			return collection_size(run)
		Condition.ENDLESS_WAVE:
			var best: int = SaveManager.get_endless_best_overall()
			return Lexicon.endless_wave(best) if best > 0 else 0.0
	if is_total():
		return ctx.totals.get(total_key(), 0)
	return 1.0 if is_met(ctx) else 0.0


func is_met(ctx: ChallengeContext) -> bool:
	if needs_run_end() and not ctx.at_run_end:
		return false
	match condition:
		Condition.WIN_PRIMITIVE_ONLY:
			return ctx.victory and ctx.run.primitive_only
		Condition.WIN_WITH_CHARACTER:
			return ctx.victory and character != null and character.id == ctx.character_id
		Condition.WIN_ELEMENTAL:
			return ctx.victory and ctx.run.max_elemental >= value
		Condition.WIN_ON_DIFFICULTY:
			return int(value) in SaveManager.won_difficulty_levels()
		Condition.WIN_NO_REROLL:
			return ctx.victory and ctx.run.rerolls == 0
		Condition.WIN_MAX_WEAPONS:
			return ctx.victory and ctx.run.max_weapons <= value
		Condition.BOSS_KILL_TIME:
			return ctx.run.fastest_boss_kill > 0.0 and ctx.run.fastest_boss_kill <= value
		Condition.COLLECTION:
			if entry != &"":
				return SaveManager.collection_has(stat_key, entry) or ctx.run.collection_has(stat_key, entry)
	return current_value(ctx) >= value


## Einträge der Sammlung im Spielstand plus die neuen des laufenden Runs.
func collection_size(run: RunStats) -> int:
	var seen: Dictionary[String, bool] = {}
	for id: String in SaveManager.get_collection(stat_key):
		seen[id] = true
	for id: String in run.collections.get(stat_key, []):
		seen[id] = true
	return seen.size()


func condition_text() -> String:
	var text: String = TextFormat.t("CHALLENGE_%d" % condition)
	if condition == Condition.WIN_WITH_CHARACTER:
		return text % TextFormat.t(character.name_key)
	if condition == Condition.TOTAL_WEAPON_KILLS:
		return text % [TextFormat.number(value), TextFormat.t(weapon.name_key)]
	return text % TextFormat.number(value) if text.contains("%s") else text


## "312/500" (leer bei Ja/Nein-Bedingungen).
func progress_text(current: float) -> String:
	if not has_progress():
		return ""
	return "%s/%s" % [TextFormat.number(floorf(minf(current, value))), TextFormat.number(value)]


func reward_name() -> String:
	if reward_character != null:
		return TextFormat.t(reward_character.name_key)
	return TextFormat.t(reward_item.name_key) if reward_item != null else ""


func reward_icon() -> Texture2D:
	if reward_character != null:
		return reward_character.texture
	return reward_item.icon if reward_item != null else null
