extends Node
## Lädt alle Spieldaten-Resources aus res://data (Autoload "DataRegistry").
## Jeder Unterordner von DATA_ROOT ist eine Kategorie (weapons, items, ...).

const DATA_ROOT: String = "res://data"
const CATEGORIES: PackedStringArray = [
	"weapons", "items", "characters", "enemies", "waves", "upgrades", "sets", "challenges",
]
## In exportierten Builds werden .tres-Dateien umbenannt und über .remap referenziert.
const REMAP_SUFFIX: String = ".remap"

var _resources: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	_resources.clear()
	for category: String in CATEGORIES:
		_resources[category] = _load_category(category)


## Alle Resources einer Kategorie, z. B. get_all("weapons").
func get_all(category: String) -> Array[Resource]:
	var result: Array[Resource] = []
	result.assign(_resources.get(category, []))
	return result


func _load_category(category: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var dir_path: String = DATA_ROOT.path_join(category)
	for file_name: String in DirAccess.get_files_at(dir_path):
		file_name = file_name.trim_suffix(REMAP_SUFFIX)
		if file_name.get_extension() != "tres":
			continue
		var res: Resource = load(dir_path.path_join(file_name))
		if res != null:
			result.append(res)
	return result
