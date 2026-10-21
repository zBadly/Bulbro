class_name PlayerRuleEffect
extends ItemEffect
## Setzt eine Sonderregel am Spieler (HP-Regen wirkungslos, keine kritischen Treffer).

const RULE_KEYS: Dictionary[Player.Rule, String] = {
	Player.Rule.NO_REGEN: "RULE_NO_REGEN",
	Player.Rule.NO_CRIT: "RULE_NO_CRIT",
}

@export var rule: Player.Rule = Player.Rule.NO_REGEN


func apply(player: Player) -> void:
	player.rules[rule] = true


func describe() -> PackedStringArray:
	return [TextFormat.t(RULE_KEYS[rule])]
