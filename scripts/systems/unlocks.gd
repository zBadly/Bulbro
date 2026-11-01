class_name Unlocks
extends RefCounted
## Meta-Progression: Charaktere und Items werden über ChallengeData-Resources freigeschaltet (GDD 10).
## check() wird während des Runs regelmäßig und am Run-Ende aufgerufen und meldet neue Freischaltungen.

const CHARACTER_CATEGORY: String = "characters"
const CHALLENGE_CATEGORY: String = "challenges"
const ACHIEVEMENT_CATEGORY: String = "achievements"


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


## Achievements in der Reihenfolge der Liste (Phase 15, Paket 9).
static func all_achievements() -> Array[AchievementData]:
	var result: Array[AchievementData] = []
	for res: Resource in DataRegistry.get_all(ACHIEVEMENT_CATEGORY):
		result.append(res as AchievementData)
	result.sort_custom(func(a: AchievementData, b: AchievementData) -> bool: return a.order < b.order)
	return result


## Freischaltungen und Achievements: alles, was check() prüft.
static func all_checks() -> Array[ChallengeData]:
	var result: Array[ChallengeData] = all_challenges()
	for achievement: AchievementData in all_achievements():
		result.append(achievement)
	return result


static func completed_achievement_count() -> int:
	return count_completed(all_achievements())


static func count_completed(list: Array[AchievementData]) -> int:
	return list.filter(func(a: AchievementData) -> bool: return SaveManager.is_challenge_completed(a.id)).size()


static func unlocked_character_count() -> int:
	return all_characters().filter(is_unlocked).size()


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
	for challenge: ChallengeData in all_checks():
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
	for challenge: ChallengeData in all_checks():
		if SaveManager.is_challenge_completed(challenge.id):
			continue
		if challenge.has_progress() and not challenge.is_total() and not challenge.is_meta() 				and (at_run_end or not challenge.needs_run_end()):
			SaveManager.record_challenge_best(challenge.id, challenge.current_value(ctx))
		if challenge.is_met(ctx):
			_complete(challenge)
			completed.append(challenge)
	if at_run_end or not completed.is_empty():
		SaveManager.save_game()
	return completed


## Fortschritt außerhalb eines Runs: Summe bei Gesamt-Bedingungen, Spielstand bei Meta-Bedingungen, sonst Bestwert.
static func progress(challenge: ChallengeData) -> float:
	if SaveManager.is_challenge_completed(challenge.id):
		return challenge.value
	if challenge.is_total():
		return SaveManager.get_stat(challenge.total_key())
	if challenge.is_meta():
		return challenge.current_value(saved_context())
	return SaveManager.get_challenge_best(challenge.id)


## Kontext nur aus dem Spielstand (kein laufender Run): Fortschrittsanzeige und rückwirkende Gutschrift.
static func saved_context() -> ChallengeContext:
	var ctx: ChallengeContext = ChallengeContext.new()
	for challenge: ChallengeData in all_checks():
		if challenge.is_total():
			ctx.totals[challenge.total_key()] = SaveManager.get_stat(challenge.total_key())
	return ctx


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
	var level: int = GameState.difficulty.level if GameState.difficulty != null else 0
	if victory and GameState.character != null:
		SaveManager.record_win(GameState.character.id, level)
		SaveManager.record_best_time(SaveManager.RECORD_WIN_TIME % level, GameState.run_stats.combat_time())
	_save_run_collections()
	var completed: Array[ChallengeData] = check(true, victory)
	RunHistory.record(victory)
	SaveManager.clear_run()
	return completed


## Sammlungen (Einzigartige, Begleiter, Bosse, Boss-Phasen) und der schnellste Bosskill gehen in den Spielstand.
static func _save_run_collections() -> void:
	var run: RunStats = GameState.run_stats
	for collection: String in run.collections:
		for id: Variant in run.collections[collection]:
			SaveManager.add_to_collection(collection, StringName(id))
	SaveManager.record_best_time(SaveManager.RECORD_BOSS_KILL, run.fastest_boss_kill)


## Einmalig beim ersten Start mit Achievements: was sich aus dem Spielstand ableiten lässt, wird gutgeschrieben
## (Gesamtwerte wie Kills und Funken, Siege, Freischaltungen, Endlos-Bestwert; aus der Run-Historie die Bestwerte
## für Kills und Boss-Zyklen in einem Run, Bestzeiten, Runs und Waffen-Kills je Charakter). Meldet jedes Achievement
## über Events.challenge_completed (Popup im Hauptmenü).
static func backfill_achievements() -> Array[ChallengeData]:
	var completed: Array[ChallengeData] = []
	if SaveManager.is_achievements_backfilled():
		return completed
	var best: RunStats = RunStats.new()
	for entry: Dictionary in SaveManager.get_run_history():
		var character_id: String = String(entry.get("character", ""))
		best.enemies_killed = maxi(best.enemies_killed, int(entry.get("kills", 0)))
		best.boss_cycles = maxi(best.boss_cycles, int(entry.get("boss_cycles", 0)))
		if entry.get("result", "") == RunHistory.RESULT_VICTORY and int(entry.get("endless_wave", 0)) == 0:
			SaveManager.record_best_time(SaveManager.RECORD_WIN_TIME % int(entry.get("difficulty", 0)), float(entry.get("time", 0.0)))
		if character_id == "":
			continue
		SaveManager.add_stat(SaveManager.CHARACTER_RUNS_PREFIX + character_id, 1)
		for top: Variant in entry.get("top_sources", []):
			var origin: StringName = StringName((top as Dictionary).get("source", ""))
			if DamageSource.kind_of(origin) == DamageSource.WEAPON:
				SaveManager.add_stat(SaveManager.character_kills_key(StringName(character_id), DamageSource.id_of(origin)),
					int((top as Dictionary).get("kills", 0)))
	var ctx: ChallengeContext = saved_context()
	ctx.run = best
	for achievement: AchievementData in all_achievements():
		if SaveManager.is_challenge_completed(achievement.id):
			continue
		if achievement.condition in [ChallengeData.Condition.RUN_KILLS, ChallengeData.Condition.RUN_VALUE]:
			SaveManager.record_challenge_best(achievement.id, achievement.current_value(ctx))
		if (achievement.is_total() or achievement.is_meta() or achievement.condition == ChallengeData.Condition.RUN_KILLS
				or achievement.condition == ChallengeData.Condition.RUN_VALUE) and achievement.is_met(ctx):
			_complete(achievement)
			completed.append(achievement)
	SaveManager.set_achievements_backfilled()
	SaveManager.save_game()
	return completed


static func _complete(challenge: ChallengeData) -> void:
	SaveManager.complete_challenge(challenge.id)
	if challenge.reward_character != null:
		SaveManager.unlock_character(challenge.reward_character.id)
	if challenge.reward_item != null:
		SaveManager.unlock_item(challenge.reward_item.id)
	Events.challenge_completed.emit(challenge)
