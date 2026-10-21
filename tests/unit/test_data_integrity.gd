extends GutTest
## Lädt jede .tres unter res://data und prüft die Pflichtfelder je Typ.

const DATA_ROOT: String = "res://data"
const EXPECTED_WEAPONS: int = 17
const EXPECTED_ITEMS: int = 34


func _all_resource_paths(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() == "tres":
			result.append(dir_path.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir_path):
		result.append_array(_all_resource_paths(dir_path.path_join(sub)))
	return result


func _translated(key: String) -> bool:
	return key != "" and tr(key) != key


func test_every_resource_loads_and_is_valid() -> void:
	var paths: PackedStringArray = _all_resource_paths(DATA_ROOT)
	assert_gt(paths.size(), 0)
	var ids: Dictionary[String, String] = {}
	for path: String in paths:
		var res: Resource = load(path)
		assert_not_null(res, "lädt nicht: " + path)
		if res == null:
			continue
		var problems: PackedStringArray = _check(res)
		assert_eq(problems.size(), 0, "%s: %s" % [path, ", ".join(problems)])
		var id: Variant = res.get("id")
		if id != null and String(id) != "":
			var key: String = "%s/%s" % [res.get_class(), id]
			if res.get_script() != null:
				key = "%s/%s" % [(res.get_script() as Script).get_global_name(), id]
			assert_false(ids.has(key), "doppelte ID %s in %s und %s" % [id, path, ids.get(key, "")])
			ids[key] = path


func test_content_counts() -> void:
	assert_eq(DataRegistry.get_all("weapons").size(), EXPECTED_WEAPONS)
	assert_eq(DataRegistry.get_all("items").size(), EXPECTED_ITEMS)


func _check(res: Resource) -> PackedStringArray:
	if res is WeaponData:
		return _check_weapon(res)
	if res is ItemData:
		return _check_item(res)
	if res is EnemyData:
		return _check_enemy(res)
	if res is WaveData:
		return _check_wave(res)
	if res is UpgradeData:
		return _check_upgrade(res)
	if res is SetBonusData:
		return _check_set(res)
	if res is StructureData:
		return _check_structure(res)
	return []


func _check_weapon(w: WeaponData) -> PackedStringArray:
	var p: PackedStringArray = []
	if String(w.id) == "": p.append("id fehlt")
	if not _translated(w.name_key): p.append("Name nicht übersetzt")
	if w.texture == null: p.append("Grafik fehlt")
	if w.classes.is_empty(): p.append("keine Klasse")
	for c: StringName in w.classes:
		if c not in WeaponClasses.ALL: p.append("unbekannte Klasse " + c)
	if w.tiers.size() != WeaponData.MAX_TIER: p.append("nicht 4 Tiers")
	for t: WeaponTierStats in w.tiers:
		if t.base_damage <= 0.0 or t.cooldown <= 0.0 or t.range <= 0.0 or t.price <= 0:
			p.append("Tier-Werte <= 0")
			break
	if w.kind == WeaponData.Kind.RANGED and (w.projectile_texture == null or w.projectile_speed <= 0.0):
		p.append("Projektil fehlt")
	return p


func _check_item(i: ItemData) -> PackedStringArray:
	var p: PackedStringArray = []
	if String(i.id) == "": p.append("id fehlt")
	if not _translated(i.name_key): p.append("Name nicht übersetzt")
	if i.icon == null: p.append("Icon fehlt")
	if i.tier < 1 or i.tier > 4: p.append("Tier ungültig")
	if i.price <= 0: p.append("Preis fehlt")
	if i.effects.is_empty(): p.append("keine Effekte")
	var text: String = i.get_description()
	if text == "" or text.contains("STAT_") or text.contains("ACTION_") or text.contains("TRIGGER_"):
		p.append("Beschreibung leer oder unübersetzt: " + text)
	for mod: StatModifier in i.get_modifiers():
		if not Stats.is_valid(mod.stat): p.append("unbekannter Stat " + mod.stat)
	return p


func _check_enemy(e: EnemyData) -> PackedStringArray:
	var p: PackedStringArray = []
	if String(e.id) == "": p.append("id fehlt")
	if not _translated(e.name_key): p.append("Name nicht übersetzt")
	if e.texture == null: p.append("Grafik fehlt")
	if e.behavior == null: p.append("Verhalten fehlt")
	if e.base_hp <= 0.0 or e.collision_radius <= 0.0: p.append("HP/Radius fehlt")
	if e.speed_max < e.speed_min: p.append("Tempo-Bereich verdreht")
	return p


func _check_wave(w: WaveData) -> PackedStringArray:
	var p: PackedStringArray = []
	if w.wave_number < 1: p.append("Wellennummer fehlt")
	if w.duration <= 0.0: p.append("Dauer fehlt")
	if w.groups.is_empty(): p.append("keine Gruppen")
	for g: SpawnGroupData in w.groups:
		if g.enemy == null or g.interval <= 0.0 or g.group_min < 1 or g.group_max < g.group_min:
			p.append("ungültige Gruppe")
			break
	return p


func _check_upgrade(u: UpgradeData) -> PackedStringArray:
	var p: PackedStringArray = []
	if not Stats.is_valid(u.stat): p.append("unbekannter Stat")
	if u.tier_values.size() != 4: p.append("nicht 4 Tier-Werte")
	for i in range(1, u.tier_values.size()):
		if u.tier_values[i] <= u.tier_values[i - 1]: p.append("Werte steigen nicht")
	return p


func _check_set(s: SetBonusData) -> PackedStringArray:
	var p: PackedStringArray = []
	if s.weapon_class not in WeaponClasses.ALL: p.append("unbekannte Klasse")
	if s.levels.size() != 5: p.append("nicht 5 Stufen")
	return p


func _check_structure(s: StructureData) -> PackedStringArray:
	var p: PackedStringArray = []
	if not _translated(s.name_key): p.append("Name nicht übersetzt")
	if s.texture == null: p.append("Grafik fehlt")
	if s.kind == StructureData.Kind.ROOT:
		if s.root_radius <= 0.0 or s.root_duration <= 0.0: p.append("Ranke ohne Radius/Dauer")
		return p
	if s.projectile_texture == null: p.append("Projektilgrafik fehlt")
	# Lampenturm hängt am Waffen-Tier (4 Stufen), Drohnen haben eine feste Stufe
	if s.tier_cooldowns.is_empty() or s.tier_cooldowns.size() > 4: p.append("1 bis 4 Abklingzeiten erwartet")
	return p
