class_name TriggerEntry
extends RefCounted
## Ein registriertes Exemplar eines Trigger-Effekts mit eigenem Zustand (zwei gleiche Items = zwei Einträge).

var effect: ItemEffect
var timer: float = 0.0
## Weiterer Zustand des Exemplars (z. B. Angriffszähler pro Waffe, erzeugte Knoten).
var state: Dictionary = {}


static func create(p_effect: ItemEffect) -> TriggerEntry:
	var entry: TriggerEntry = TriggerEntry.new()
	entry.effect = p_effect
	return entry
