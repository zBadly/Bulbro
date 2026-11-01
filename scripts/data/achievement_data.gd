class_name AchievementData
extends ChallengeData
## Achievement (Phase 15, Paket 9): eine Challenge ohne Belohnung, mit Name, Beschreibung, Icon, Kategorie und
## Schwierigkeit. Prüfung, Bestwerte, Fortschritt und Admin-Sperre laufen über Unlocks wie bei den Freischaltungen.

enum Category { PROGRESS, ENEMIES, VICTORIES, COMBAT, GEAR, UNIQUES, PETS, TOWERS, ENDLESS, BOSSES, CHARACTERS }
enum Difficulty { EASY, MEDIUM, HARD }

const CATEGORY_KEY: String = "ACH_CAT_%d"
const DIFFICULTY_KEY: String = "ACH_DIFF_%d"
## Rahmenfarben je Schwierigkeit: Bronze, Silber, Gold.
const DIFFICULTY_COLORS: Array[Color] = [Color("#CD8A4B"), Color("#C9CED6"), Color("#F5A623")]

@export var name_key: String = ""
## Beschreibung der Bedingung. Platzhalter: {value} (Zahl mit Tausenderpunkt), {endless} (Endlos-Zahl zur
## Gesamtwelle `value`), {cycle_wave} (Welle, in der der `value`-te Endlos-Boss-Zyklus kommt).
@export var description_key: String = ""
@export var icon: Texture2D
@export var category: Category = Category.PROGRESS
@export var difficulty: Difficulty = Difficulty.EASY
## Reihenfolge in Übersicht und Lexikon (Nummer aus der Achievement-Liste).
@export var order: int = 0


func display_name() -> String:
	return TextFormat.t(name_key)


func condition_text() -> String:
	var boss_wave: int = Lexicon.endless_wave(0)
	return TextFormat.t(description_key).format({
		"value": RunReport.format_int(roundi(value)),
		"endless": roundi(value) - boss_wave,
		"cycle_wave": Lexicon.endless_wave(roundi(value) * EndlessRules.config.boss_cycle_waves),
	})


## Ja/Nein-Bedingungen und Ziele von 1 zeigen keinen Zahlenfortschritt.
func has_progress() -> bool:
	return super() and value > 1.0


## "312/500" mit Tausenderpunkt (leer bei Ja/Nein-Bedingungen).
func progress_text(current: float) -> String:
	if not has_progress():
		return ""
	return "%s/%s" % [RunReport.format_int(floori(minf(current, value))), RunReport.format_int(roundi(value))]


func category_name() -> String:
	return TextFormat.t(CATEGORY_KEY % category)


func difficulty_name() -> String:
	return TextFormat.t(DIFFICULTY_KEY % difficulty)


func difficulty_color() -> Color:
	return DIFFICULTY_COLORS[difficulty]


func reward_name() -> String:
	return display_name()


func reward_icon() -> Texture2D:
	return icon
