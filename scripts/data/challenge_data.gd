class_name ChallengeData
extends Resource
## Prüfbare Freischaltbedingung (GDD 10). Belohnung: ein Charakter oder ein Item für den Shop.

enum Condition {
	STRUCTURES, ## so viele Strukturen gleichzeitig besitzen
	TOTAL_SPARKS, ## über alle Runs so viele Funken gesammelt
	DISTINCT_WEAPONS, ## so viele verschiedene Waffen gleichzeitig
	DAMAGE_PCT, ## Schaden-% in einem Run erreicht
	HEALED, ## so viele HP in einem Run geheilt
	SPEED_PCT, ## Tempo-% in einem Run erreicht
	WIN_PRIMITIVE_ONLY, ## Run nur mit Primitiv-Waffen gewinnen
	WIN_WITH_CHARACTER, ## Run mit einem bestimmten Charakter gewinnen
}

@export var id: StringName
@export var condition: Condition = Condition.STRUCTURES
@export var value: float = 0.0
## Für WIN_WITH_CHARACTER.
@export var character: CharacterData
@export var reward_character: CharacterData
@export var reward_item: ItemData


## Nur Siegbedingungen werden ausschließlich am Run-Ende geprüft.
func needs_victory() -> bool:
	return condition == Condition.WIN_PRIMITIVE_ONLY or condition == Condition.WIN_WITH_CHARACTER


func is_met(run: RunStats, max_structures: int, total_sparks: int, victory: bool, character_id: StringName) -> bool:
	match condition:
		Condition.STRUCTURES:
			return max_structures >= value
		Condition.TOTAL_SPARKS:
			return total_sparks >= value
		Condition.DISTINCT_WEAPONS:
			return run.max_distinct_weapons >= value
		Condition.DAMAGE_PCT:
			return run.max_damage_pct >= value
		Condition.HEALED:
			return run.healed >= value
		Condition.SPEED_PCT:
			return run.max_speed_pct >= value
		Condition.WIN_PRIMITIVE_ONLY:
			return victory and run.primitive_only
		Condition.WIN_WITH_CHARACTER:
			return victory and character != null and character.id == character_id
	return false


func condition_text() -> String:
	var text: String = TextFormat.t("CHALLENGE_%d" % condition)
	if condition == Condition.WIN_WITH_CHARACTER:
		return text % TextFormat.t(character.name_key)
	return text % TextFormat.number(value) if text.contains("%s") else text


func reward_name() -> String:
	if reward_character != null:
		return TextFormat.t(reward_character.name_key)
	return TextFormat.t(reward_item.name_key) if reward_item != null else ""


func reward_icon() -> Texture2D:
	if reward_character != null:
		return reward_character.texture
	return reward_item.icon if reward_item != null else null
