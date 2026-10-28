extends Node
## Balancing-Simulator: Gegner-HP pro Welle gegen die DPS typischer Builds (BalanceModel)
## und Run-Simulation pro Charakter (CharacterSim).
## Aufruf (headless, aus dem Projektordner):
##   godot --headless --path . res://tools/balance_sim.tscn                 -> Wellen-Tabelle und Vorschläge (Spannung 0)
##   godot --headless --path . res://tools/balance_sim.tscn -- 3            -> für Spannung 3
##   godot --headless --path . res://tools/balance_sim.tscn -- 0 --apply    -> Vorschläge in die Wellen-.tres schreiben
##   ... -- 0 --characters [--runs 200] [--ablate]  -> Siegquote, Scheiter-Welle und stärkster Effekt je Charakter
##   ... -- 0 --weapons                            -> DPS aller Waffen (Tier I und IV) im Vergleich zur eigenen Klasse
##   ... -- 3 --items [--runs 200]                 -> Wirkung der Tier-III/IV-Items und Einzigartigen auf Siegquote und Wellen
##   ... -- 3 --items --uniques                    -> nur die Einzigartigen, Ausreißer gegenüber ihrem Schnitt
##   ... -- 3 --pets [--runs 150]                  -> Wirkung der Begleiter (Kauf in Welle 8, Tier wächst wie bei Waffen),
##                                                     Ausreißer gegenüber ihrem Schnitt; ändert nichts an den Daten
##   ... -- 0 --try kerze max_hp:4 armor:2       -> Buff-Varianten (stat:delta[:f|p|g]) auf Spannung 0 und 3 testen
##   ... -- 0 --trace <charakter-id>               -> ein Run Welle für Welle (Schaden, Treffer, Heilung, HP)
##   ... -- 0 --endless [--runs 100] [hp_growth=0.12 ...] -> erreichte Endlos-Welle je Charakter (Median = Ø Build,
##                                                     90. Perzentil = starker Build); key=value setzt EndlessConfig-Werte
##                                                     nur für diesen Lauf (nichts wird gespeichert)

const WAVE_DIR: String = "res://data/waves"
const WEAPON_DIR: String = "res://data/weapons"
const DIFFICULTY_PATH: String = "res://data/difficulties/spannung_%d.tres"
const APPLY_FLAG: String = "--apply"
const CHARACTERS_FLAG: String = "--characters"
const WEAPONS_FLAG: String = "--weapons"
const ITEMS_FLAG: String = "--items"
const ABLATE_FLAG: String = "--ablate"
const UNIQUES_FLAG: String = "--uniques"
const PETS_FLAG: String = "--pets"
## Begleiter-Vergleich: weniger Runs als beim Item-Vergleich, damit der Lauf unter 10 Minuten bleibt.
const PET_RUNS: int = 150
## Ausreißer unter den Einzigartigen: Wertung weicht um mehr als so viele Standardabweichungen vom Schnitt ab.
const OUTLIER_SD: float = 1.5
const RUNS_FLAG: String = "--runs"
const TRY_FLAG: String = "--try"
const ENDLESS_FLAG: String = "--endless"
## Perzentile für "durchschnittlicher" und "starker" Build unter den Siegern.
const AVERAGE_PERCENTILE: float = 0.5
const STRONG_PERCENTILE: float = 0.9
const WEAK_PERCENTILE: float = 0.1
## Spannungsstufen, auf denen --try Varianten vergleicht.
const TRY_LEVELS: Array[int] = [0, 3]
const KIND_CODES: Dictionary[String, StatModifier.Kind] = {"f": StatModifier.Kind.FLAT, "p": StatModifier.Kind.PERCENT, "g": StatModifier.Kind.GAIN_PERCENT}
const DEFAULT_RUNS: int = 200
## Charaktere ab dieser Reihenfolge-Nummer gehören zur Ausbaustufe 14c (für die Schnitte alt/neu).
const NEW_CHARACTER_ORDER: int = 12
const ABLATION_RUNS: int = 80
const SEED: int = 4242
## Items werden in dieser Welle gekauft (Vergleich der Items untereinander).
const ITEM_WAVE: int = 8
const ITEM_MIN_TIER: int = 3
## Referenz-Charaktere für den Item-Vergleich (Waffen-Build über die Startwaffen).
const ITEM_TEST_CHARACTERS: Array[StringName] = [&"standardbirne", &"lavalampe", &"led_schuetze", &"gluehfaden_boxer"]
## Waffenvergleich: Stat-Stand wie im BalanceModel zu Welle 3 (Tier I) und Welle 18 (Tier IV).
const WEAPON_EARLY_WAVE: int = 3
const WEAPON_LATE_WAVE: int = 18
const BBCODE: String = "\\[[^\\]]*\\]"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var level: int = int(args[0]) if not args.is_empty() and args[0].is_valid_int() else 0
	var difficulty: DifficultyData = load(DIFFICULTY_PATH % level)
	var runs: int = DEFAULT_RUNS
	var runs_index: int = args.find(RUNS_FLAG)
	if runs_index >= 0 and runs_index + 1 < args.size():
		runs = int(args[runs_index + 1])
	if "--trace" in args:
		var sim: CharacterSim = CharacterSim.new(self)
		var character: CharacterData = load("res://data/characters/%s.tres" % args[args.find("--trace") + 1])
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = SEED
		print(sim.simulate_run(character, difficulty, rng, {"trace": true, "endless": ENDLESS_FLAG in args}))
	elif ENDLESS_FLAG in args:
		await _endless(difficulty, runs, args.slice(args.find(ENDLESS_FLAG) + 1))
	elif TRY_FLAG in args:
		await _try_variant(args.slice(args.find(TRY_FLAG) + 1), runs)
	elif CHARACTERS_FLAG in args:
		await _characters(difficulty, runs, ABLATE_FLAG in args)
	elif WEAPONS_FLAG in args:
		_weapons()
	elif PETS_FLAG in args:
		await _pets(difficulty, runs if runs_index >= 0 else PET_RUNS)
	elif ITEMS_FLAG in args:
		await _items(difficulty, runs, UNIQUES_FLAG in args)
	else:
		_waves(level, difficulty, APPLY_FLAG in args)
	get_tree().quit()


# --- Endlos-Modus ---

## Je Charakter: Siegquote und erreichte Endlos-Stufe der Sieger (10./50./90. Perzentil), Anteil Tod in Bosswellen.
func _endless(difficulty: DifficultyData, runs: int, overrides: PackedStringArray) -> void:
	var config: EndlessConfig = EndlessRules.config
	for pair: String in overrides:
		if "=" in pair:
			config.set(pair.get_slice("=", 0), float(pair.get_slice("=", 1)))
			print("Override: %s" % pair)
	var sim: CharacterSim = CharacterSim.new(self)
	print("BULBRO Endlos-Simulation – Spannung %d, %d Runs je Charakter" % [difficulty.level, runs])
	print("| Charakter | Siegquote | schwach (P10) | Ø Build (Median) | stark (P90) | Tod in Bosswelle |")
	print("|---|---|---|---|---|---|")
	var pooled: Array[int] = []
	for character: CharacterData in Unlocks.all_characters():
		var result: Dictionary = sim.run_many(character, difficulty, runs, SEED, {"endless": true})
		var levels: Array[int] = []
		levels.assign(result["endless"])
		pooled.append_array(levels)
		print("| %s | %d %% | %s | %s | %s | %s |" % [tr(character.name_key), roundi(result["win_rate"] * 100.0),
			_percentile_text(levels, WEAK_PERCENTILE), _percentile_text(levels, AVERAGE_PERCENTILE),
			_percentile_text(levels, STRONG_PERCENTILE), _boss_death_text(levels)])
		await get_tree().process_frame
	pooled.sort()
	print("Alle Sieger (%d Runs): P10 %s, Median %s, P90 %s, Tod in Bosswelle %s" % [pooled.size(),
		_percentile_text(pooled, WEAK_PERCENTILE), _percentile_text(pooled, AVERAGE_PERCENTILE),
		_percentile_text(pooled, STRONG_PERCENTILE), _boss_death_text(pooled)])
	var reached: PackedStringArray = []
	for level: int in [config.boss_cycle_waves, config.boss_cycle_waves * 2, config.boss_cycle_waves * 3]:
		reached.append("Endlos %d: %d %%" % [level, roundi(_share_reaching(pooled, level + 1) * 100.0)])
	print("Bosswelle überlebt: " + ", ".join(reached))
	var deaths: Dictionary[int, int] = {}
	for level: int in pooled:
		deaths[level] = deaths.get(level, 0) + 1
	var common: Array[int] = deaths.keys()
	common.sort_custom(func(a: int, b: int) -> bool: return deaths[a] > deaths[b])
	var common_text: PackedStringArray = []
	for level: int in common.slice(0, 5):
		common_text.append("Endlos %d: %d %%" % [level, roundi(deaths[level] * 100.0 / pooled.size())])
	print("Häufigste Todesstufen: " + ", ".join(common_text))


func _percentile_text(sorted: Array[int], percentile: float) -> String:
	if sorted.is_empty():
		return "-"
	var level: int = sorted[clampi(floori(percentile * (sorted.size() - 1) + 0.5), 0, sorted.size() - 1)]
	return "%d (W%d)" % [level, CharacterSim.BOSS_WAVE + level]


func _boss_death_text(levels: Array[int]) -> String:
	if levels.is_empty():
		return "-"
	return "%d %%" % roundi(levels.filter(func(l: int) -> bool: return EndlessRules.is_boss_level(l)).size() * 100.0 / levels.size())


func _share_reaching(sorted: Array[int], level: int) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted.filter(func(l: int) -> bool: return l >= level).size() / float(sorted.size())


# --- Charaktere ---

func _characters(difficulty: DifficultyData, runs: int, ablate: bool) -> void:
	var sim: CharacterSim = CharacterSim.new(self)
	print("BULBRO Charakter-Simulation – Spannung %d, %d Runs je Charakter" % [difficulty.level, runs])
	print("| Charakter | Siegquote | Ø Welle | scheitert meist | Schadensanteile | stärkster Effekt |")
	print("|---|---|---|---|---|---|")
	var sums: Dictionary[String, Vector3] = {}
	for character: CharacterData in Unlocks.all_characters():
		var result: Dictionary = sim.run_many(character, difficulty, runs, SEED)
		for group: String in ["alle", "alte 12" if character.order < NEW_CHARACTER_ORDER else "neue 10"]:
			sums[group] = sums.get(group, Vector3.ZERO) + Vector3(result["win_rate"], result["avg_wave"], 1.0)
		await get_tree().process_frame
		var strongest: String = "-"
		if ablate:
			strongest = await _strongest_effect(sim, character, difficulty, result)
		print("| %s | %d %% | %.1f | %s | %s | %s |" % [tr(character.name_key), roundi(result["win_rate"] * 100.0), result["avg_wave"],
			str(result["fail_wave"]) if result["fail_wave"] > 0 else "-", _shares_text(result["shares"]), strongest])
	for group: String in sums:
		var sum: Vector3 = sums[group]
		print("Schnitt %s: Siegquote %d %%, Ø Welle %.1f" % [group, roundi(sum.x / sum.z * 100.0), sum.y / sum.z])


func _shares_text(shares: Dictionary) -> String:
	var keys: Array = shares.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return shares[a] > shares[b])
	var parts: PackedStringArray = []
	for key: String in keys:
		if shares[key] >= 0.05:
			parts.append("%s %d %%" % [key, roundi(shares[key] * 100.0)])
	return ", ".join(parts)


## Ablation: jeden Effekt (bei Stat-Effekten jeden positiven Modifikator) einzeln entfernen;
## der Effekt mit dem größten Verlust an Ø Welle + Siegquote ist der stärkste.
func _strongest_effect(sim: CharacterSim, character: CharacterData, difficulty: DifficultyData, base: Dictionary) -> String:
	var base_score: float = _score(base)
	var best_label: String = "-"
	var best_drop: float = -INF
	for i in character.effects.size():
		var effect: ItemEffect = character.effects[i]
		var variants: Array = []
		if effect is StatEffect:
			for mod: StatModifier in (effect as StatEffect).modifiers:
				var good: bool = TextFormat.is_good(mod.stat, mod.value) if mod.kind != StatModifier.Kind.GAIN_PERCENT else mod.value > 0.0
				if not good:
					continue
				var reduced: StatEffect = StatEffect.new()
				reduced.modifiers.assign((effect as StatEffect).modifiers.filter(func(m: StatModifier) -> bool: return m != mod))
				variants.append([_plain(TextFormat.modifier_line(mod)), reduced])
		else:
			variants.append([_plain(effect.describe()[0]) if not effect.describe().is_empty() else effect.get_script().get_global_name(), null])
		for variant: Array in variants:
			var effects: Array[ItemEffect] = character.effects.duplicate()
			if variant[1] == null:
				effects.remove_at(i)
			else:
				effects[i] = variant[1]
			var result: Dictionary = sim.run_many(character, difficulty, ABLATION_RUNS, SEED, {"effects": effects})
			await get_tree().process_frame
			var drop: float = base_score - _score(result)
			if drop > best_drop:
				best_drop = drop
				best_label = variant[0]
	return "%s (%+.1f)" % [best_label.left(70), -best_drop] if best_drop > -INF else "-"


## Buff-Varianten testen, ohne Daten zu ändern: --try <charakter-id> <stat:delta[:f|p|g]>[,...] [weitere Varianten]
## Jede Variante ergänzt den Charakter um einen Stat-Effekt mit diesen Änderungen (delta = neu - alt).
func _try_variant(spec: PackedStringArray, runs: int) -> void:
	var sim: CharacterSim = CharacterSim.new(self)
	var character: CharacterData = load("res://data/characters/%s.tres" % spec[0])
	var variants: Array = [["unverändert", character.effects]]
	for text: String in spec.slice(1):
		if text.begins_with("--"):
			break
		var extra: StatEffect = StatEffect.new()
		for part: String in text.split(","):
			var bits: PackedStringArray = part.split(":")
			extra.modifiers.append(StatModifier.create(StringName(bits[0]), float(bits[1]), KIND_CODES.get(bits[2] if bits.size() > 2 else "f", StatModifier.Kind.FLAT)))
		var effects: Array[ItemEffect] = character.effects.duplicate()
		effects.append(extra)
		variants.append([text, effects])
	print("| Variante (%s) | %s |" % [tr(character.name_key), " | ".join(TRY_LEVELS.map(func(l: int) -> String: return "Spannung %d" % l))])
	for variant: Array in variants:
		var cells: PackedStringArray = []
		for level: int in TRY_LEVELS:
			var result: Dictionary = sim.run_many(character, load(DIFFICULTY_PATH % level), runs, SEED, {"effects": variant[1]})
			await get_tree().process_frame
			cells.append("%d %%, Ø %.1f, meist %s" % [roundi(result["win_rate"] * 100.0), result["avg_wave"], str(result["fail_wave"]) if result["fail_wave"] > 0 else "-"])
		print("| %s | %s |" % [variant[0], " | ".join(cells)])


func _score(result: Dictionary) -> float:
	return result["avg_wave"] + result["win_rate"] * 10.0


func _plain(text: String) -> String:
	var regex: RegEx = RegEx.create_from_string(BBCODE)
	return regex.sub(text, "", true).replace("\n", " ")


# --- Waffen ---

func _weapons() -> void:
	var weapons: Dictionary = {}
	for res: Resource in DataRegistry.get_all("weapons"):
		weapons[String((res as WeaponData).id)] = res
	print("BULBRO Waffen-Vergleich (Stat-Stand wie BalanceModel, Welle %d Tier I / Welle %d Tier IV, inkl. Mehrfachtreffer und Brand)" % [WEAPON_EARLY_WAVE, WEAPON_LATE_WAVE])
	print("| Waffe | Klassen | DPS T1 | DPS T4 | DPS T4 je 100 Funken (T1-Preis) | Klassenschnitt T4 | Abweichung |")
	print("|---|---|---|---|---|---|---|")
	var late: Dictionary = {}
	for id: String in weapons:
		late[id] = _weapon_dps(weapons[id], WeaponData.MAX_TIER, WEAPON_LATE_WAVE)
	var ids: Array = weapons.keys()
	ids.sort()
	for id: String in ids:
		var weapon: WeaponData = weapons[id]
		var peers: Array[float] = []
		for other: String in weapons:
			if other != id and (weapons[other] as WeaponData).classes.any(func(c: StringName) -> bool: return c in weapon.classes):
				peers.append(late[other])
		var peer_avg: float = peers.reduce(func(s: float, v: float) -> float: return s + v, 0.0) / maxf(1.0, peers.size())
		var early: float = _weapon_dps(weapon, WeaponData.MIN_TIER, WEAPON_EARLY_WAVE)
		var classes: PackedStringArray = []
		for c: StringName in weapon.classes:
			classes.append(String(c))
		var peer_text: String = "%.0f" % peer_avg if not peers.is_empty() else "-"
		var deviation: String = "%+d %%" % roundi((late[id] / peer_avg - 1.0) * 100.0) if not peers.is_empty() else "-"
		print("| %s | %s | %.1f | %.0f | %.0f | %s | %s |" % [tr(weapon.name_key), ", ".join(classes), early, late[id],
			late[id] / maxf(1.0, weapon.get_tier(WeaponData.MIN_TIER).price) * 100.0, peer_text, deviation])


func _weapon_dps(weapon: WeaponData, tier: int, wave: int) -> float:
	var progress: float = wave - 1
	var block: StatBlock = StatBlock.new()
	block.values = {
		Stats.MELEE_DMG: BalanceModel.SCALING_STAT_PER_WAVE * progress,
		Stats.RANGED_DMG: BalanceModel.SCALING_STAT_PER_WAVE * progress,
		Stats.ELEMENTAL_DMG: BalanceModel.SCALING_STAT_PER_WAVE * progress,
		Stats.DAMAGE_PCT: BalanceModel.DAMAGE_PCT_PER_WAVE * progress,
		Stats.ATTACK_SPEED: BalanceModel.ATTACK_SPEED_PER_WAVE * progress,
		Stats.CRIT_CHANCE: BalanceModel.CRIT_PER_WAVE * progress,
	}
	var stats: StatSystem = StatSystem.new(block)
	var t: WeaponTierStats = weapon.get_tier(tier)
	var dps: float = BalanceModel.weapon_dps(weapon, tier, stats)
	var rate: float = 1.0 / CombatMath.attack_cooldown(t.cooldown, stats.get_stat(Stats.ATTACK_SPEED))
	var targets: float = BalanceModel.targets_per_attack(weapon, t)
	dps += t.burn_damage * t.burn_ticks * t.burn_chance * rate * targets
	dps += t.split_count * t.split_damage_pct / CombatMath.PERCENT * CharacterSim.SPLIT_HIT_SHARE * dps / targets
	return dps


# --- Items ---

func _items(difficulty: DifficultyData, runs: int, uniques_only: bool = false) -> void:
	var sim: CharacterSim = CharacterSim.new(self)
	var characters: Array[CharacterData] = []
	for id: StringName in ITEM_TEST_CHARACTERS:
		characters.append(load("res://data/characters/%s.tres" % id))
	var base: Dictionary = await _item_result(sim, characters, difficulty, runs, null)
	var victory_items: Dictionary[ItemData, String] = {}
	for challenge: ChallengeData in Unlocks.all_challenges():
		if challenge.reward_item != null:
			victory_items[challenge.reward_item] = String(challenge.id)
	print("BULBRO Item-Vergleich – Spannung %d, Kauf in Welle %d, Charaktere: %s; ohne Item: Siegquote %d %%, Ø Welle %.1f" % [
		difficulty.level, ITEM_WAVE, ", ".join(ITEM_TEST_CHARACTERS), roundi(base["win_rate"] * 100.0), base["avg_wave"]])
	print("| Item | Tier | Preis | Δ Siegquote | Δ Ø Welle | Δ je 100 Funken | Sieg-Item | Einzigartig |")
	print("|---|---|---|---|---|---|---|---|")
	var items: Array[ItemData] = []
	for res: Resource in DataRegistry.get_all("items"):
		var item: ItemData = res as ItemData
		if item.tier >= ITEM_MIN_TIER and (item.is_unique() or not uniques_only):
			items.append(item)
	# Wertung je Item (Δ Ø Welle + Δ Siegquote / 10) für die Ausreißer unter den Einzigartigen
	var scores: Dictionary[ItemData, Vector2] = {}
	items.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.tier < b.tier or (a.tier == b.tier and String(a.id) < String(b.id)))
	for item: ItemData in items:
		var result: Dictionary = await _item_result(sim, characters, difficulty, runs, item)
		var delta_win: float = (result["win_rate"] - base["win_rate"]) * 100.0
		var delta_wave: float = result["avg_wave"] - base["avg_wave"]
		var score: float = delta_wave + delta_win / 10.0
		scores[item] = Vector2(score, score / maxf(1.0, item.price) * 100.0)
		print("| %s | %s | %d | %+.0f | %+.2f | %+.2f | %s | %s |" % [tr(item.name_key), TextFormat.tier_name(item.tier), item.price, delta_win, delta_wave,
			scores[item].y, "ja" if victory_items.has(item) else "", "ja" if item.is_unique() else ""])
	_print_outliers(scores, victory_items)


## Ausreißer unter den Einzigartigen (Wertung und Wertung je 100 Funken) gegenüber deren Schnitt;
## zum Vergleich der Schnitt der Sieg-Items. Ändert nichts an den Daten.
func _print_outliers(scores: Dictionary[ItemData, Vector2], victory_items: Dictionary[ItemData, String]) -> void:
	var uniques: Array[ItemData] = []
	for item: ItemData in scores:
		if item.is_unique():
			uniques.append(item)
	if uniques.size() < 2:
		return
	for axis: int in 2:
		var values: Array[float] = []
		for item: ItemData in uniques:
			values.append(scores[item][axis])
		var mean: float = values.reduce(func(s: float, v: float) -> float: return s + v, 0.0) / values.size()
		var variance: float = values.reduce(func(s: float, v: float) -> float: return s + (v - mean) * (v - mean), 0.0) / values.size()
		var sd: float = sqrt(variance)
		var label: String = "Wertung" if axis == 0 else "Wertung je 100 Funken"
		var victory: Array[float] = []
		for item: ItemData in victory_items:
			if scores.has(item):
				victory.append(scores[item][axis])
		var victory_text: String = ", Sieg-Items %+.2f" % (victory.reduce(func(s: float, v: float) -> float: return s + v, 0.0) / victory.size()) if not victory.is_empty() else ""
		print("Einzigartige, %s: Schnitt %+.2f, Streuung %.2f%s" % [label, mean, sd, victory_text])
		for item: ItemData in uniques:
			var z: float = (scores[item][axis] - mean) / maxf(sd, 0.0001)
			if absf(z) > OUTLIER_SD:
				print("  Ausreißer %s: %s %+.2f (%+.1f SD)" % ["stark" if z > 0.0 else "schwach", tr(item.name_key), scores[item][axis], z])


func _item_result(sim: CharacterSim, characters: Array[CharacterData], difficulty: DifficultyData, runs: int, item: ItemData,
		pet: PetData = null) -> Dictionary:
	var win: float = 0.0
	var wave: float = 0.0
	for character: CharacterData in characters:
		var options: Dictionary = {}
		if item != null:
			options["items"] = [[item, ITEM_WAVE]]
		if pet != null:
			options["pets"] = [[pet, ITEM_WAVE]]
		var result: Dictionary = sim.run_many(character, difficulty, runs, SEED, options)
		await get_tree().process_frame
		win += result["win_rate"] / characters.size()
		wave += result["avg_wave"] / characters.size()
	return {"win_rate": win, "avg_wave": wave}


# --- Begleiter ---

## Je Begleiter: Kauf in ITEM_WAVE, danach wächst sein Tier wie das Waffen-Tier (Kombinieren eingerechnet).
## Wertung wie bei Items (Δ Ø Welle + Δ Siegquote / 10), je 100 Funken mit dem Preis des Tiers beim Kauf.
## Ausreißer: Wertung weicht um mehr als OUTLIER_SD Standardabweichungen vom Schnitt der Begleiter ab.
func _pets(difficulty: DifficultyData, runs: int) -> void:
	var started: int = Time.get_ticks_msec()
	var sim: CharacterSim = CharacterSim.new(self)
	var characters: Array[CharacterData] = []
	for id: StringName in ITEM_TEST_CHARACTERS:
		characters.append(load("res://data/characters/%s.tres" % id))
	var base: Dictionary = await _item_result(sim, characters, difficulty, runs, null)
	var buy_tier: int = clampi(1 + (ITEM_WAVE - 1) / BalanceModel.WAVES_PER_TIER, WeaponData.MIN_TIER, WeaponData.MAX_TIER)
	print("BULBRO Begleiter-Vergleich – Spannung %d, Kauf in Welle %d (%s), %d Runs je Charakter: %s; ohne Begleiter: Siegquote %d %%, Ø Welle %.1f" % [
		difficulty.level, ITEM_WAVE, TextFormat.tier_name(buy_tier), runs, ", ".join(ITEM_TEST_CHARACTERS), roundi(base["win_rate"] * 100.0), base["avg_wave"]])
	print("| Begleiter | Preis beim Kauf | Δ Siegquote | Δ Ø Welle | Wertung | je 100 Funken |")
	print("|---|---|---|---|---|---|")
	var pets: Array[PetData] = []
	for res: Resource in DataRegistry.get_all("pets"):
		pets.append(res as PetData)
	pets.sort_custom(func(a: PetData, b: PetData) -> bool: return String(a.id) < String(b.id))
	var scores: Dictionary[PetData, Vector2] = {}
	for pet: PetData in pets:
		var result: Dictionary = await _item_result(sim, characters, difficulty, runs, null, pet)
		var delta_win: float = (result["win_rate"] - base["win_rate"]) * 100.0
		var delta_wave: float = result["avg_wave"] - base["avg_wave"]
		var score: float = delta_wave + delta_win / 10.0
		var price: int = pet.get_tier(buy_tier).price
		scores[pet] = Vector2(score, score / maxf(1.0, price) * 100.0)
		print("| %s | %d | %+.0f | %+.2f | %+.2f | %+.2f |" % [tr(pet.name_key), price, delta_win, delta_wave, score, scores[pet].y])
	for axis: int in 2:
		var values: Array[float] = []
		for pet: PetData in pets:
			values.append(scores[pet][axis])
		var mean: float = values.reduce(func(s: float, v: float) -> float: return s + v, 0.0) / values.size()
		var variance: float = values.reduce(func(s: float, v: float) -> float: return s + (v - mean) * (v - mean), 0.0) / values.size()
		var sd: float = sqrt(variance)
		print("Begleiter, %s: Schnitt %+.2f, Streuung %.2f" % ["Wertung" if axis == 0 else "Wertung je 100 Funken", mean, sd])
		for pet: PetData in pets:
			var z: float = (scores[pet][axis] - mean) / maxf(sd, 0.0001)
			if absf(z) > OUTLIER_SD:
				print("  Ausreißer %s: %s %+.2f (%+.1f SD)" % ["stark" if z > 0.0 else "schwach", tr(pet.name_key), scores[pet][axis], z])
	print("Laufzeit: %d s" % ((Time.get_ticks_msec() - started) / 1000))


# --- Wellen ---

func _waves(level: int, difficulty: DifficultyData, apply: bool) -> void:
	var weapons: Dictionary = {}
	for file: String in DirAccess.get_files_at(WEAPON_DIR):
		if file.get_extension() == "tres":
			var weapon: WeaponData = load(WEAPON_DIR.path_join(file))
			weapons[String(weapon.id)] = weapon
	var waves: Array[WaveData] = []
	for file: String in DirAccess.get_files_at(WAVE_DIR):
		if file.get_extension() == "tres":
			waves.append(load(WAVE_DIR.path_join(file)))
	waves.sort_custom(func(a: WaveData, b: WaveData) -> bool: return a.wave_number < b.wave_number)

	print("BULBRO Balancing-Simulation – Spannung %d (Build-DPS / benötigte DPS; ok = %.1f bis %.1f)" % [
		level, BalanceModel.TOO_HARD, BalanceModel.TOO_EASY])
	var header: String = "%5s | %5s | %6s | %9s | %8s" % ["Welle", "Dauer", "Gegner", "HP gesamt", "DPS nötig"]
	for build: String in BalanceModel.BUILDS:
		header += " | %11s" % build
	header += " | %-10s | %s" % ["Bewertung", "Vorschlag"]
	print(header)
	print("-".repeat(header.length()))
	var suggestions: Dictionary = {}
	for wave: WaveData in waves:
		if wave.is_boss:
			print("%5d | Bosswelle (endet mit dem Boss) – nicht simuliert" % wave.wave_number)
			continue
		var load_info: Dictionary = BalanceModel.wave_load(wave, difficulty)
		var line: String = "%5d | %5.0f | %6.0f | %9.0f | %8.1f" % [wave.wave_number, wave.duration, load_info["count"], load_info["hp"], load_info["required_dps"]]
		var ratios: Array[float] = []
		for build: String in BalanceModel.BUILDS:
			var dps: float = BalanceModel.build_dps(BalanceModel.BUILDS[build], wave.wave_number, weapons)
			var ratio: float = dps / maxf(load_info["required_dps"], 0.01)
			ratios.append(ratio)
			line += " | %5.0f x%4.2f" % [dps, ratio]
		var average: float = ratios.reduce(func(s: float, r: float) -> float: return s + r, 0.0) / ratios.size()
		var verdict: String = BalanceModel.rating(average)
		var proposal: String = ""
		if verdict != "ok":
			var factor: float = BalanceModel.interval_factor(average)
			suggestions[wave] = factor
			proposal = "Spawn-Intervalle x%.2f (%s Gegner)" % [factor, "weniger" if factor > 1.0 else "mehr"]
		print(line + " | %-10s | %s" % [verdict, proposal])

	print("")
	if suggestions.is_empty():
		print("Keine Auffälligkeiten.")
	elif apply:
		for wave: WaveData in suggestions:
			for group: SpawnGroupData in wave.groups:
				group.interval = snappedf(group.interval * suggestions[wave], 0.05)
			print("Welle %d: %s" % [wave.wave_number, error_string(ResourceSaver.save(wave, wave.resource_path))])
		print("%d Wellen angepasst." % suggestions.size())
	else:
		print("%d Wellen auffällig. Mit '%s' werden die Vorschläge in die .tres geschrieben." % [suggestions.size(), APPLY_FLAG])
