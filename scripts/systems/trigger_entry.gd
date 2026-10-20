class_name TriggerEntry
extends RefCounted
## Ein registriertes Exemplar eines Trigger-Effekts mit eigenem Zustand (zwei gleiche Items = zwei Einträge).

var effect: ItemEffect
var timer: float = 0.0


static func create(p_effect: ItemEffect) -> TriggerEntry:
	var entry: TriggerEntry = TriggerEntry.new()
	entry.effect = p_effect
	return entry
