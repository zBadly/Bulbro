class_name TowerItemEffect
extends ItemEffect
## Turm-Item (Paket 8): Jedes Exemplar baut zu Wellenbeginn einen Turm in einem Ring um den Spieler
## (TowerBuilder). Kein Trigger, damit Player.rebuild() unverändert bleibt.

const TOWERS: TowerConfig = preload("res://data/config/tower_config.tres")

@export var structure: StructureData


func describe() -> PackedStringArray:
	var lines: PackedStringArray = [TextFormat.t("EFFECT_BUILDS_TOWER") % TextFormat.t(structure.name_key)]
	lines.append_array(structure.describe())
	lines.append(TextFormat.t("EFFECT_TOWER_STACKS") % TOWERS.max_towers)
	return lines
