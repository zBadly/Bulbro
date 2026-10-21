class_name Unlocks
extends RefCounted
## Meta-Progression: Charaktere und Items werden über ChallengeData-Resources freigeschaltet (GDD 10).
## check() wird während des Runs regelmäßig und am Run-Ende aufgerufen und meldet neue Freischaltungen.

const CHARACTER_CATEGORY: String = "characters"
const CHALLENGE_CATEGORY: String = "challenges"


## Alle Charaktere in der Reihenfolge der GDD-Liste.
static func all_characters() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for res: Resource in DataRegistry.get_all(CHARACTER_CATEGORY):
		result.append(res as CharacterData)
	result.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return a.order < b.order)
	return result


static func all_challenges() -> Array[ChallengeData]:
	var result: Array[ChallengeData] = []
	for res: Resource in DataRegistry.get_all(CHALLENGE_CATEGORY):
		result.append(res as ChallengeData)
	result.sort_custom(func(a: ChallengeData, b: ChallengeData) -> bool: return String(a.id) < String(b.id))
	return result


static func is_unlocked(character: CharacterData) -> bool:
	return character.unlocked_by_default or SaveManager.is_character_unlocked(character.id)


## Challenge, die diesen Charakter freischaltet (null bei Startcharakteren).
static func challenge_for(character: CharacterData) -> ChallengeData:
	for challenge: ChallengeData in all_challenges():
		if challenge.reward_character == character:
			return challenge
	return null


static func condition_text(character: CharacterData) -> String:
	var challenge: ChallengeData = challenge_for(character)
	return challenge.condition_text() if challenge != null else TextFormat.t("CHALLENGE_START")


## Ein Item ist gesperrt, solange eine Challenge es als Belohnung hat und sie noch nicht geschafft ist.
static func is_item_unlocked(item: ItemData) -> bool:
	if SaveManager.is_item_unlocked(item.id):
		return true
	for challenge: ChallengeData in all_challenges():
		if challenge.reward_item == item:
			return false
	return true


static func unlocked_items(items: Array[ItemData]) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in items:
		if is_item_unlocked(item):
			result.append(item)
	return result


## Prüft alle offenen Challenges. Siegbedingungen nur am Run-Ende. Gibt neu geschaffte zurück
## und meldet jede über Events.challenge_completed.
static func check(at_run_end: bool, victory: bool) -> Array[ChallengeData]:
	var completed: Array[ChallengeData] = []
	var unreported: int = GameState.total_sparks_collected - GameState.reported_sparks
	var total_sparks: int = SaveManager.get_total_sparks() + (0 if at_run_end else unreported)
	var character_id: StringName = GameState.character.id if GameState.character != null else &""
	for challenge: ChallengeData in all_challenges():
		if SaveManager.is_challenge_completed(challenge.id) or (challenge.needs_victory() and not at_run_end):
			continue
		if challenge.is_met(GameState.run_stats, GameState.max_structures, total_sparks, victory, character_id):
			_complete(challenge)
			completed.append(challenge)
	if not completed.is_empty():
		SaveManager.save_game()
	return completed


## Am Run-Ende: Statistiken und Sieg speichern, Challenges prüfen, unterbrochenen Run löschen.
static func evaluate_run_end(victory: bool) -> Array[ChallengeData]:
	# Im Endlos-Modus wird ein Run zweimal ausgewertet (Sieg, später Tod): nur Zuwächse zählen.
	SaveManager.add_stat(SaveManager.STAT_TOTAL_SPARKS, GameState.total_sparks_collected - GameState.reported_sparks)
	SaveManager.add_stat(SaveManager.STAT_KILLS, GameState.run_stats.enemies_killed - GameState.reported_kills)
	GameState.reported_sparks = GameState.total_sparks_collected
	GameState.reported_kills = GameState.run_stats.enemies_killed
	if not GameState.run_reported:
		SaveManager.add_stat(SaveManager.STAT_RUNS, 1)
	GameState.run_reported = true
	if victory and GameState.character != null:
		SaveManager.record_win(GameState.character.id, GameState.difficulty.level if GameState.difficulty != null else 0)
	var completed: Array[ChallengeData] = check(true, victory)
	SaveManager.clear_run()
	return completed


static func _complete(challenge: ChallengeData) -> void:
	SaveManager.complete_challenge(challenge.id)
	if challenge.reward_character != null:
		SaveManager.unlock_character(challenge.reward_character.id)
	if challenge.reward_item != null:
		SaveManager.unlock_item(challenge.reward_item.id)
	Events.challenge_completed.emit(challenge)
