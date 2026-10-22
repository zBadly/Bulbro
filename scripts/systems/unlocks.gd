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


## Kontext für die Prüfung. Gesamtwerte: gespeichert plus noch nicht gemeldete Zuwächse dieses Runs.
## Nach end_run() ist der Run inaktiv und schon über evaluate_run_end gemeldet: dann zählt nur der Spielstand.
static func make_context(at_run_end: bool, victory: bool) -> ChallengeContext:
	var ctx: ChallengeContext = ChallengeContext.new()
	ctx.run = GameState.run_stats
	ctx.max_structures = GameState.max_structures
	ctx.current_wave = GameState.current_wave
	ctx.victory = victory
	ctx.at_run_end = at_run_end
	ctx.character_id = GameState.character.id if GameState.character != null else &""
	var run_totals: Dictionary[String, int] = GameState.run_totals()
	for challenge: ChallengeData in all_challenges():
		if challenge.is_total():
			var key: String = challenge.total_key()
			var unreported: int = 0
			if GameState.is_run_active:
				unreported = run_totals.get(key, 0) - GameState.reported_totals.get(key, 0)
			ctx.totals[key] = SaveManager.get_stat(key) + unreported
	return ctx


## Prüft alle offenen Challenges und merkt sich Bestwerte. Siegbedingungen nur am Run-Ende.
## Gibt neu geschaffte zurück und meldet jede über Events.challenge_completed.
static func check(at_run_end: bool, victory: bool) -> Array[ChallengeData]:
	var completed: Array[ChallengeData] = []
	if GameState.admin.used:
		return completed
	var ctx: ChallengeContext = make_context(at_run_end, victory)
	for challenge: ChallengeData in all_challenges():
		if SaveManager.is_challenge_completed(challenge.id):
			continue
		if challenge.has_progress() and not challenge.is_total() and (at_run_end or not challenge.needs_run_end()):
			SaveManager.record_challenge_best(challenge.id, challenge.current_value(ctx))
		if challenge.is_met(ctx):
			_complete(challenge)
			completed.append(challenge)
	if at_run_end or not completed.is_empty():
		SaveManager.save_game()
	return completed


## Fortschritt außerhalb eines Runs: Summe bei Gesamt-Bedingungen, sonst Bestwert.
static func progress(challenge: ChallengeData) -> float:
	if SaveManager.is_challenge_completed(challenge.id):
		return challenge.value
	if challenge.is_total():
		return SaveManager.get_stat(challenge.total_key())
	return SaveManager.get_challenge_best(challenge.id)


## "312/500" für einen gesperrten Charakter (leer, wenn es keinen Zahlenfortschritt gibt).
static func progress_text(character: CharacterData) -> String:
	var challenge: ChallengeData = challenge_for(character)
	return challenge.progress_text(progress(challenge)) if challenge != null else ""


## Debug: alle Charaktere freischalten (Challenges bleiben offen).
static func unlock_all_characters() -> void:
	for challenge: ChallengeData in all_challenges():
		if challenge.reward_character != null:
			SaveManager.unlock_character(challenge.reward_character.id)
	SaveManager.save_game()


## Am Run-Ende: Statistiken und Sieg speichern, Challenges prüfen, unterbrochenen Run löschen.
static func evaluate_run_end(victory: bool) -> Array[ChallengeData]:
	if GameState.admin.used:
		# Admin-Run: keine Statistik, kein Sieg, keine Challenges; nur den Fortsetzen-Stand verwerfen.
		SaveManager.clear_run()
		return []
	# Im Endlos-Modus wird ein Run zweimal ausgewertet (Sieg, später Tod): nur Zuwächse zählen.
	var run_totals: Dictionary[String, int] = GameState.run_totals()
	for key: String in run_totals:
		SaveManager.add_stat(key, run_totals[key] - GameState.reported_totals.get(key, 0))
		GameState.reported_totals[key] = run_totals[key]
	if not GameState.run_reported:
		SaveManager.add_stat(SaveManager.STAT_RUNS, 1)
	GameState.run_reported = true
	if victory and GameState.character != null:
		SaveManager.record_win(GameState.character.id, GameState.difficulty.level if GameState.difficulty != null else 0)
	var completed: Array[ChallengeData] = check(true, victory)
	RunHistory.record(victory)
	SaveManager.clear_run()
	return completed


static func _complete(challenge: ChallengeData) -> void:
	SaveManager.complete_challenge(challenge.id)
	if challenge.reward_character != null:
		SaveManager.unlock_character(challenge.reward_character.id)
	if challenge.reward_item != null:
		SaveManager.unlock_item(challenge.reward_item.id)
	Events.challenge_completed.emit(challenge)
