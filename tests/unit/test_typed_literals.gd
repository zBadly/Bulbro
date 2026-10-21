extends GutTest
## Wächter zu Phase 15/1: Leere Literale "{}"/"[]" in einem Ternär bleiben ungetypt.
## Landet der Ausdruck in einer typisierten Variable (Dictionary[K, V], Array[T]), bricht die Zuweisung zur Laufzeit ab.
## Gleiches gilt für ".get(key, [])", das an eine typisierte Variable geht.

const SCAN_DIRS: PackedStringArray = ["res://scripts", "res://scenes", "res://tools", "res://tests"]
const TERNARY_PATTERN: String = "\\belse\\s*(\\{\\}|\\[\\])|(\\{\\}|\\[\\])\\s+if\\b"
const TYPED_GET_PATTERN: String = ":\\s*(Array|Dictionary)\\[[^\\]]*\\]\\s*=\\s*.*\\.get\\([^)]*,\\s*(\\{\\}|\\[\\])\\)"


func _script_paths(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() == "gd":
			result.append(dir_path.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir_path):
		result.append_array(_script_paths(dir_path.path_join(sub)))
	return result


func test_no_untyped_literals_in_ternaries_or_get_defaults() -> void:
	var patterns: Array[RegEx] = [RegEx.create_from_string(TERNARY_PATTERN), RegEx.create_from_string(TYPED_GET_PATTERN)]
	var own_path: String = (get_script() as Script).resource_path
	var findings: PackedStringArray = []
	for dir_path: String in SCAN_DIRS:
		for path: String in _script_paths(dir_path):
			if path == own_path:
				continue
			var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
			for i: int in lines.size():
				var code: String = lines[i].get_slice("#", 0)
				for pattern: RegEx in patterns:
					if pattern.search(code) != null:
						findings.append("%s:%d" % [path, i + 1])
	assert_eq(findings.size(), 0, "ungetypte Literale: " + ", ".join(findings))
