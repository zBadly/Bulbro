class_name Unlocks
extends RefCounted
## Freischaltbedingungen der Charaktere (GDD 10) und Auswertung am Run-Ende.

const CHARACTER_CATEGORY: String = "characters"


## Alle Charaktere in der Reihenfolge der GDD-Liste.
static func all_characters() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for res: Resource in DataRegistry.get_all(CHARACTER_CATEGORY):
		result.append(res as CharacterData)
	result.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return a.order < b.order)
	return result


static func is_unlocked(character: CharacterData) -> bool:
	return character.unlock == CharacterData.Unlock.START or SaveManager.is_character_unlocked(character.id)


## Ist die Bedingung mit dem aktuellen Run (plus Gesamtfortschritt) erfüllt?
static func is_met(character: CharacterData, run: RunStats, max_structures: int, total_sparks: int, victory: bool) -> bool:
	var value: float = character.unlock_value
	match character.unlock:
		CharacterData.Unlock.START:
			return true
		CharacterData.Unlock.STRUCTURES:
			return max_structures >= value
		CharacterData.Unlock.TOTAL_SPARKS:
			return total_sparks >= value
		CharacterData.Unlock.DISTINCT_WEAPONS:
			return run.max_distinct_weapons >= value
		CharacterData.Unlock.DAMAGE_PCT:
			return run.max_damage_pct >= value
		CharacterData.Unlock.HEALED:
			return run.healed >= value
		CharacterData.Unlock.SPEED_PCT:
			return run.max_speed_pct >= value
		CharacterData.Unlock.WIN_PRIMITIVE_ONLY:
			return victory and run.primitive_only
	return false


## Am Run-Ende: Fortschritt speichern und neu freigeschaltete Charaktere zurückgeben.
static func evaluate_run_end(victory: bool) -> Array[CharacterData]:
	SaveManager.add_total_sparks(GameState.total_sparks_collected)
	if victory and GameState.character != null:
		SaveManager.record_win(GameState.character.id)
	var unlocked: Array[CharacterData] = []
	for character: CharacterData in all_characters():
		if is_unlocked(character):
			continue
		if is_met(character, GameState.run_stats, GameState.max_structures, SaveManager.get_total_sparks(), victory):
			SaveManager.unlock_character(character.id)
			unlocked.append(character)
	SaveManager.save_game()
	return unlocked


static func condition_text(character: CharacterData) -> String:
	var text: String = TextFormat.t("UNLOCK_%d" % character.unlock)
	return text % TextFormat.number(character.unlock_value) if text.contains("%s") else text
