class_name EffectAction
extends Resource
## Was ein Trigger-Effekt auslöst. `origin` ist der Ort des Ereignisses (z. B. Position des getöteten Gegners).


func execute(_ctx: EffectContext, _origin: Vector2) -> void:
	pass


## Beschreibung der Aktion für Item-Karten (BBCode).
func describe() -> String:
	return ""


## "3 (+50 % Strom)" für Schaden mit Skalierung.
static func damage_text(base_damage: float, scalings: Dictionary[StringName, float]) -> String:
	var parts: PackedStringArray = []
	for stat: StringName in scalings:
		parts.append("+%d %% %s" % [roundi(scalings[stat] * 100.0), TextFormat.t(Stats.label_key(stat))])
	var text: String = TextFormat.number(base_damage)
	return text + (" (%s)" % ", ".join(parts) if not parts.is_empty() else "")
