class_name TriggerEntry
extends RefCounted
## Ein registriertes Exemplar eines Trigger-Effekts mit eigenem Zustand (zwei gleiche Items = zwei Einträge).

var effect: ItemEffect
var timer: float = 0.0
## Weiterer Zustand des Exemplars (z. B. Angriffszähler pro Waffe, erzeugte Knoten).
var state: Dictionary = {}
## Herkunft für die Run-Statistik (Item oder Charakter, siehe DamageSource).
var origin: StringName = &""


static func create(p_effect: ItemEffect, p_origin: StringName = &"") -> TriggerEntry:
	var entry: TriggerEntry = TriggerEntry.new()
	entry.effect = p_effect
	entry.origin = p_origin
	return entry
