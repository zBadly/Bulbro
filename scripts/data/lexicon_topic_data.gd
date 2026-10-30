class_name LexiconTopicData
extends Resource
## Thema im Lexikon-Reiter "Spielmechaniken" (data/lexicon). Der Text wird mit Werten aus den Configs
## gefüllt (Lexicon.topic_text); zugeordnete Stats werden einzeln erklärt (Lexicon.stat_info: Wirkung, Formel, Beispiel, Grenze).

## Zusätzliche Tabelle unter dem Text, aus den Daten erzeugt.
enum Table {
	NONE,
	DIFFICULTIES, ## alle Spannungsstufen aus data/difficulties
	UPGRADES, ## Level-up-Werte je Tier aus data/upgrades
	TOWERS, ## alle Türme aus data/structures mit Quelle und Wirkung
}

@export var id: StringName
@export var name_key: String = ""
@export var icon: Texture2D
## Reihenfolge im Raster.
@export var order: int = 0
## Erklärtext (leer bei reinen Stat-Themen).
@export var text_key: String = ""
## Stats, die dieses Thema erklärt (jeder Stat gehört zu genau einem Thema).
@export var stats: Array[StringName] = []
@export var table: Table = Table.NONE
## Lexikon: Übersetzungsschlüssel eines witzigen Satzes (Glühbirnen-Thema).
@export var lore_text: String = ""
