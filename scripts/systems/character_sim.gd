class_name CharacterSim
extends RefCounted
## Grobe Run-Simulation pro Charakter (Balancing, Paket 5). Spielt viele Runs Welle für Welle durch:
## Ausgeteilter Schaden (Waffen und Sondereffekte aus den Daten) gegen benötigten Schaden der Welle,
## eingesteckter Schaden (abhängig davon, wie gut der Build die Welle wegräumt) gegen Heilung.
## HP werden wie im Spiel zwischen den Wellen nicht aufgefüllt.
##
## Vereinfachungen (bewusst, für Vergleiche zwischen Charakteren gedacht, nicht als absolute Siegquote):
## - Kein Raum: Gegner, Treffer, Flächen- und Mehrfachtreffer werden über feste Faktoren geschätzt.
## - Der Build wächst nach einem festen Plan (Waffenzahl, Tier, Stat-Zuwachs pro Welle) mit Zufallsstreuung;
##   die Wirtschaft (Funken, Preise, XP) skaliert diesen Zuwachs. Konkrete Items werden nicht gekauft.
## - Weitere Waffen teilen eine Klasse mit der Startwaffe (halb Kopien zum Kombinieren).
## - Spieler-Können steckt in einer Streuung pro Run und pro Welle (Trefferspitzen).
## Alle Annahmen stehen als Konstanten unten.

const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const DROPS: DropConfig = preload("res://data/config/drop_config.tres")
const PERCENT: float = 100.0
const RUN_WAVES: int = 19
const BOSS_WAVE: int = 20
## Endlos-Modus (Option "endless"): höchstens so viele Endloswellen simulieren.
const MAX_ENDLESS: int = 100

# --- Build-Entwicklung ---
## Waffenzahl wächst wie im BalanceModel (bei 6 Slots: +1 alle 3 Wellen), bei mehr/weniger Slots anteilig.
const BASE_SLOTS: float = 6.0
## Anteil Kopien der Startwaffe unter den weiteren Waffen.
const DUPLICATE_SHARE: float = 0.5
## Zuwachs pro Welle aus Level-ups und Items (vor Wirtschafts- und Glücksfaktor).
const GROWTH_PER_WAVE: Dictionary[StringName, float] = {
	&"damage_pct": 2.5, &"attack_speed": 2.0, &"crit_chance": 0.5, &"max_hp": 1.0, &"armor": 0.3,
	&"hp_regen": 0.3, &"dodge": 0.5, &"lifesteal": 0.2, &"speed": 0.5,
}
## Zuwachs des Skalierungs-Stats der Startwaffe pro Welle (und Technik bei Struktur-Builds).
const MAIN_STAT_PER_WAVE: float = 1.0
## Anteil des Zuwachses aus Items (Wirtschaft) bzw. Level-ups (XP).
const ITEM_SHARE: float = 0.6
## Glück pro Run (Shop, Drops, Können): Normalverteilung um 1.
const RUN_LUCK_SD: float = 0.18
const RUN_LUCK_MIN: float = 0.5
## Aufladung: so viele Funken bringt ein durchschnittlicher Shop-Besuch ohne Aufladung.
const SPARKS_PER_WAVE_REF: float = 70.0
const SPARKS_PER_KILL: float = 1.1
## Glück verbessert Shop- und Level-up-Seltenheit: Item-Zuwachs +x je 100 Glück.
const LUCK_ITEM_PER_100: float = 0.2

# --- Mehrfachtreffer und Status (ohne Raum geschätzt) ---
const ALIVE_BASE: float = 25.0
const SPLIT_HIT_SHARE: float = 0.5
## Jeder Punkt Brandausbreitung erhöht die Zahl brennender Gegner um diesen Anteil.
const BURN_SPREAD_FACTOR: float = 0.5
const EXPLOSION_TARGETS: float = 2.5
const NOVA_TARGETS: float = 3.0
const CHAIN_HIT_SHARE: float = 0.8
const GHOST_UPTIME: float = 0.5
const ROOT_STOP_SHARE: float = 0.03
const ROOT_HIT_STOP_SHARE: float = 0.5
const SLOW_DEFENSE_SHARE: float = 0.5
## Lebensraub: höchstens eine Heilung pro 0,1 s (wie CombatMath.lifesteal_ready).
const LIFESTEAL_MAX_PER_SECOND: float = 10.0
const CRYSTAL_SPAWNS_PER_SECOND: float = 0.025
const BATTERY_SHARE: float = 0.65

# --- Eingesteckter Schaden ---
## Versuchte Gegnertreffer pro Sekunde bei ausgeglichenem Kampf (Build-DPS = benötigte DPS).
const HIT_COEF: float = 0.12
## Überforderung wirkt progressiv: Druck = (1 / Verhältnis) ^ Exponent.
const PRESSURE_EXPONENT: float = 1.5
const PRESSURE_MIN: float = 0.35
const PRESSURE_MAX: float = 4.0
## Nahkämpfer stehen näher an den Gegnern.
const MELEE_HIT_FACTOR: float = 1.3
## Tempo hilft beim Ausweichen: -1 % Treffer pro 2 % Tempo (höchstens -40 %).
const SPEED_HIT_DIVISOR: float = 200.0
const SPEED_HIT_MAX_REDUCTION: float = 0.4
## Streuung der Trefferzahl pro Welle (log-normal), erzeugt Pechwellen.
const WAVE_NOISE_SD: float = 0.45
const MAX_HITS_PER_SECOND: float = 2.5

# --- Elite und Boss ---
const ELITE_HP_FACTOR: float = 0.75
const BOSS_ADD_TIME: float = 90.0
const BOSS_HIT_RATE: float = 0.05
const BOSS_ADD_PRESSURE: float = 0.5
const BOSS_MAX_TIME: float = 240.0

# --- Einzigartige Items (Paket 15-8) ---
## Funken im Besitz während einer Welle (Sparlampe); die meisten Funken werden im Shop ausgegeben.
const SPARKS_HELD: float = 60.0
## Anteil der Kampfzeit unter der HP-Schwelle (Thermosicherung), als Bruchteil der Boni gerechnet.
const LOW_HP_UPTIME: float = 0.2

# --- Begleiter (Paket 15-8) ---
## Der Igel rollt erst zum Ziel und nur auf Gegner nahe dem Spieler: Anteil der Zeit, in der er rammt.
const PET_ROLL_UPTIME: float = 0.6
## Funkenspatz: Funken gehen ohne ihn nicht verloren (Beutel), er spart Laufwege in die Gegner.
## Weniger Treffer je 100 px Sammelradius.
const PET_COLLECT_HIT_RELIEF_PER_100: float = 0.015
## Schildkröte: so viele der Bosstreffer sind Projektile (Rest Kontakt).
const BOSS_PROJECTILE_SHARE: float = 0.7
## Schildkröte: Sie blockt das nächste Projektil im Umkreis, nicht unbedingt eins, das getroffen hätte (Salven,
## Vorbeiflieger). Anteil der Blocks, die wirklich einen Treffer verhindern.
const PET_BLOCK_HIT_SHARE: float = 0.35

# --- Türme aus Items (Paket 15-8) ---
## Flammenstrahl: getroffene Gegner pro Strahl (Linie bis zur Reichweite, im Gedränge mehrere).
const FLAME_TARGETS: float = 2.0
## Anteil aller Gegner in einer Frost-Aura bei Referenzradius (wächst mit der Fläche).
const FROST_ENEMY_SHARE: float = 0.12
const FROST_REFERENCE_RADIUS: float = 150.0
## Heilturm: Anteil der Kampfzeit, in der der Spieler im Radius steht (Türme stehen fest, der Spieler läuft).
const HEAL_UPTIME: float = 0.35
## Minen: Anteil, der wirklich einen Gegner erwischt, bevor die Welle endet oder die älteste ersetzt wird.
const MINE_HIT_SHARE: float = 0.8
const TOWERS: TowerConfig = preload("res://data/config/tower_config.tres")

var host: Node
var waves: Array[WaveData] = []
var weapons: Array[WeaponData] = []
var bosses: Array[EnemyData] = []
var elite: EnemyData


func _init(p_host: Node) -> void:
	host = p_host
	for res: Resource in DataRegistry.get_all("waves"):
		waves.append(res as WaveData)
	waves.sort_custom(func(a: WaveData, b: WaveData) -> bool: return a.wave_number < b.wave_number)
	for res: Resource in DataRegistry.get_all("weapons"):
		weapons.append(res as WeaponData)
	for res: Resource in DataRegistry.get_all("enemies"):
		var data: EnemyData = res as EnemyData
		if data.is_boss:
			bosses.append(data)
		elif data.is_elite and elite == null:
			elite = data


## Viele Runs: Siegquote, typische Scheiter-Welle, Durchschnittswelle und Schadensanteile.
## options: "items" = Array von [ItemData, Welle] (Turm-Items: jedes Exemplar ein Turm), "pets" = Array von [PetData, Welle] (Tier wächst danach wie das
## Waffen-Tier), "weapon" = feste Startwaffe, "effects" = Effektliste statt der des Charakters.
func run_many(character: CharacterData, difficulty: DifficultyData, runs: int, seed_value: int, options: Dictionary = {}) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var wins: int = 0
	var fail_counts: Dictionary[int, int] = {}
	var wave_sum: float = 0.0
	var shares: Dictionary[String, float] = {}
	var endless: Array[int] = []
	var endless_deaths: Dictionary[int, int] = {}
	for i in runs:
		rng.seed = seed_value + i * 7919
		var result: Dictionary = simulate_run(character, difficulty, rng, options)
		if result["won"]:
			wins += 1
			if options.get("endless", false):
				endless.append(result["endless"])
				endless_deaths[result["endless"]] = endless_deaths.get(result["endless"], 0) + 1
		else:
			fail_counts[result["wave"]] = fail_counts.get(result["wave"], 0) + 1
		wave_sum += result["wave"] + (1.0 if result["won"] else 0.0)
		for key: String in result["shares"]:
			shares[key] = shares.get(key, 0.0) + result["shares"][key] / runs
	var typical_fail: int = 0
	for wave: int in fail_counts:
		if typical_fail == 0 or fail_counts[wave] > fail_counts[typical_fail]:
			typical_fail = wave
	endless.sort()
	return {"win_rate": float(wins) / runs, "fail_wave": typical_fail, "avg_wave": wave_sum / runs, "shares": shares,
		"endless": endless, "endless_deaths": endless_deaths}


func simulate_run(character: CharacterData, difficulty: DifficultyData, rng: RandomNumberGenerator, options: Dictionary = {}) -> Dictionary:
	var data: CharacterData = character
	if options.has("effects"):
		data = character.duplicate()
		# duplicate() teilt Arrays: eigene Liste, damit der Original-Charakter unverändert bleibt
		var effects: Array[ItemEffect] = []
		effects.assign(options["effects"])
		data.effects = effects
	var player: Player = PLAYER_SCENE.instantiate()
	player.rng = rng
	host.add_child(player)
	player.apply_character(data)
	var start: WeaponData = options.get("weapon", null)
	if start == null:
		start = character.starting_weapons[rng.randi_range(0, character.starting_weapons.size() - 1)]
	var pool: Array[WeaponData] = _weapon_pool(player, start)
	var luck: float = maxf(RUN_LUCK_MIN, 1.0 + rng.randfn(0.0, RUN_LUCK_SD))
	var state: Dictionary = {"hp": player.get_max_hp(), "xp": 0.0, "level": 0, "kills": 0.0, "overheal_dps": 0.0,
		"weapon_ids": [start], "shares": {}, "trace": options.get("trace", false)}
	var elite_wave: int = _elite_wave(difficulty, rng)
	var result: Dictionary = {"won": false, "wave": BOSS_WAVE, "shares": {}, "endless": 0}
	for wave: WaveData in waves:
		if wave.wave_number > RUN_WAVES:
			break
		_grow(player, wave.wave_number, start, luck, state)
		_apply_items(player, wave.wave_number, options, state)
		_update_weapons(player, wave.wave_number, start, pool, rng, state)
		_update_pets(wave.wave_number, options, state)
		if not _play_wave(player, wave, difficulty, rng, state, wave.wave_number == elite_wave):
			result["wave"] = wave.wave_number
			_finish(player, state, result)
			return result
	result["won"] = _play_boss(player, difficulty, rng, state)
	if result["won"] and options.get("endless", false):
		result["endless"] = _play_endless(player, difficulty, rng, state, start, pool, luck, options)
	_finish(player, state, result)
	return result


## Endloswellen nach dem Sieg bis zum Tod; Rückgabe = erreichte Endlos-Stufe (wie "Endlos-Welle n erreicht").
## Skalierung wie im Spiel über EndlessRules; die Aufladung wird schwächer (weniger Items).
func _play_endless(player: Player, difficulty: DifficultyData, rng: RandomNumberGenerator, state: Dictionary,
		start: WeaponData, pool: Array[WeaponData], luck: float, options: Dictionary = {}) -> int:
	var config: EndlessConfig = EndlessRules.config
	var template: WaveData = waves[clampi(config.template_wave, 1, waves.size()) - 1]
	for level: int in range(1, MAX_ENDLESS + 1):
		var number: int = BOSS_WAVE + level
		_grow(player, number, start, luck, state, EndlessRules.harvest_factor(level))
		_update_weapons(player, number, start, pool, rng, state)
		_update_pets(number, options, state)
		var scale: Dictionary = {"hp": EndlessRules.hp_factor(level), "damage": EndlessRules.damage_factor(level),
			"speed": EndlessRules.speed_factor(level), "density": EndlessRules.density_factor(level)}
		var alive: bool = true
		if EndlessRules.is_boss_level(level):
			var cycle: int = EndlessRules.boss_cycle(level)
			scale["boss_hp"] = EndlessRules.boss_hp_bonus(cycle)
			scale["boss_damage"] = EndlessRules.boss_damage_bonus(cycle)
			alive = _play_boss(player, difficulty, rng, state, number, scale)
		else:
			var wave: WaveData = template.duplicate()
			wave.wave_number = number
			wave.duration = config.wave_duration
			var with_elite: bool = false
			if EndlessRules.is_special_level(level):
				if rng.randf() < config.horde_chance:
					scale["horde"] = config.horde_factor
				else:
					with_elite = true
					scale["elite_hp"] = config.elite_hp_factor
			alive = _play_wave(player, wave, difficulty, rng, state, with_elite, scale)
		if not alive:
			return level
	return MAX_ENDLESS


func _finish(player: Player, state: Dictionary, result: Dictionary) -> void:
	var shares: Dictionary = state["shares"]
	var total: float = 0.0
	for key: String in shares:
		total += shares[key]
	for key: String in shares:
		result["shares"][key] = shares[key] / maxf(total, 0.001)
	host.remove_child(player)
	player.free()


# --- Build ---

func _weapon_pool(player: Player, start: WeaponData) -> Array[WeaponData]:
	var pool: Array[WeaponData] = []
	for weapon: WeaponData in weapons:
		if weapon == start or not player.can_use_weapon(weapon):
			continue
		for weapon_class: StringName in weapon.classes:
			if weapon_class in start.classes:
				pool.append(weapon)
				break
	return pool


func _update_weapons(player: Player, wave_number: int, start: WeaponData, pool: Array[WeaponData], rng: RandomNumberGenerator, state: Dictionary) -> void:
	var slots: int = player.weapon_slots.max_slots
	var progress: float = wave_number - 1
	var count: int = mini(slots, 1 + floori(progress * slots / (BASE_SLOTS * BalanceModel.WAVES_PER_WEAPON)))
	var tier: int = clampi(1 + int(progress) / BalanceModel.WAVES_PER_TIER - (1 if slots > int(BASE_SLOTS) else 0), WeaponData.MIN_TIER, WeaponData.MAX_TIER)
	var ids: Array = state["weapon_ids"]
	while ids.size() < count:
		ids.append(start if pool.is_empty() or rng.randf() < DUPLICATE_SHARE else pool[rng.randi_range(0, pool.size() - 1)])
	for weapon: Weapon in player.weapon_slots.get_weapons():
		player.weapon_slots.remove_weapon(weapon)
		weapon.free()
	for weapon_data: WeaponData in ids:
		player.weapon_slots.add_weapon(weapon_data, tier)


## Stat-Zuwachs der Welle als Run-Modifikatoren (damit "X-Modifikationen" wirken).
func _grow(player: Player, wave_number: int, start: WeaponData, luck: float, state: Dictionary, harvest_factor: float = 1.0) -> void:
	if wave_number <= 1:
		return
	var stats: StatSystem = player.stats
	var items: float = (1.0 + stats.get_stat(Stats.KILL_SPARK_PCT) / PERCENT + maxf(0.0, stats.get_stat(Stats.HARVESTING)) * harvest_factor / SPARKS_PER_WAVE_REF) \
		/ maxf(0.3, 1.0 + stats.get_stat(Stats.ITEM_PRICE_PCT) / PERCENT) * (1.0 + LUCK_ITEM_PER_100 * stats.get_stat(Stats.LUCK) / PERCENT)
	var levels: float = maxf(0.0, 1.0 + stats.get_stat(Stats.XP_GAIN_PCT) / PERCENT)
	var factor: float = luck * (ITEM_SHARE * items + (1.0 - ITEM_SHARE) * levels)
	var growth: Dictionary[StringName, float] = GROWTH_PER_WAVE.duplicate()
	growth[_main_stat(start)] = growth.get(_main_stat(start), 0.0) + MAIN_STAT_PER_WAVE
	if start.structure != null or _has_effect(player, "OrbitingDroneEffect"):
		growth[Stats.ENGINEERING] = growth.get(Stats.ENGINEERING, 0.0) + MAIN_STAT_PER_WAVE
	for stat: StringName in growth:
		player.add_run_modifier(StatModifier.create(stat, growth[stat] * factor))
	# Level-ups: +1 Max HP pro Level (wie Player._on_level_up)
	var level: int = _level_for_xp(state["xp"])
	for i in level - int(state["level"]):
		player.add_run_modifier(StatModifier.create(Stats.MAX_HP, player.config.max_hp_per_level))
	state["level"] = level
	# Quellen für Umrechnungen (Leuchtturm: Level, Sparlampe: Funken im Besitz)
	player.stats.set_source(Stats.SOURCE_LEVEL, level)
	player.stats.set_source(Stats.SOURCE_SPARKS, SPARKS_HELD)


## Gekaufte Items; Turm-Items merkt sich der Zustand (jedes Exemplar ein Turm, siehe _tower_value).
func _apply_items(player: Player, wave_number: int, options: Dictionary, state: Dictionary) -> void:
	for entry: Array in options.get("items", []):
		if entry[1] == wave_number:
			var item: ItemData = entry[0]
			player.apply_item(item)
			for effect: ItemEffect in item.effects:
				if effect is TowerItemEffect:
					var towers: Array = state.get("towers", [])
					towers.append((effect as TowerItemEffect).structure)
					state["towers"] = towers


## Gekaufte Begleiter mit ihrem Tier in dieser Welle (wächst wie das Waffen-Tier, Kombinieren eingerechnet).
func _update_pets(wave_number: int, options: Dictionary, state: Dictionary) -> void:
	var active: Array = []
	var tier: int = clampi(1 + (wave_number - 1) / BalanceModel.WAVES_PER_TIER, WeaponData.MIN_TIER, WeaponData.MAX_TIER)
	for entry: Array in options.get("pets", []):
		if wave_number >= int(entry[1]):
			active.append([entry[0], tier])
	state["pets"] = active


func _main_stat(weapon: WeaponData) -> StringName:
	var best: StringName = Stats.RANGED_DMG
	var best_value: float = -1.0
	var scalings: Dictionary[StringName, float] = weapon.get_tier(WeaponData.MIN_TIER).scalings
	for stat: StringName in scalings:
		if scalings[stat] > best_value:
			best = stat
			best_value = scalings[stat]
	return best


func _level_for_xp(xp: float) -> int:
	var level: int = 0
	var needed: float = 0.0
	while true:
		needed += pow(level + 1 + 3, 2)
		if needed > xp:
			return level
		level += 1
	return level


func _elite_wave(difficulty: DifficultyData, rng: RandomNumberGenerator) -> int:
	if difficulty == null or difficulty.special_wave_pairs.is_empty() or elite == null:
		return -1
	var pair: Vector2i = difficulty.special_wave_pairs[0]
	return pair.x if rng.randf() < 0.5 else pair.y


func _has_effect(player: Player, class_name_text: String) -> bool:
	for entry: TriggerEntry in player.triggers:
		if entry.effect.get_script().get_global_name() == class_name_text:
			return true
	return false


# --- Welle ---

## `scale` (Endlos-Modus): "hp", "damage", "speed", "density", "horde" (Faktor auf die Anzahl), "elite_hp".
func _play_wave(player: Player, wave: WaveData, difficulty: DifficultyData, rng: RandomNumberGenerator, state: Dictionary, with_elite: bool,
		scale: Dictionary = {}) -> bool:
	var stats: StatSystem = player.stats
	var load_info: Dictionary = BalanceModel.wave_load(wave, difficulty)
	var enemy_factor: float = maxf(0.0, 1.0 + stats.get_stat(Stats.ENEMIES_PCT) / PERCENT) * scale.get("density", 1.0) * scale.get("horde", 1.0)
	var hp_scale: float = scale.get("hp", 1.0)
	var duration: float = wave.duration
	var required: float = load_info["required_dps"] * enemy_factor * hp_scale
	if with_elite:
		required += elite.hp_for_wave(wave.wave_number) * scale.get("elite_hp", ELITE_HP_FACTOR) * hp_scale * _hp_factor(difficulty) / duration
	var count: float = load_info["count"] * enemy_factor
	var spawn_rate: float = count / duration
	var low_hp: Array[StatModifier] = _add_low_hp_bonus(player)
	var offense: Dictionary = _offense(player, state, spawn_rate)
	var total: float = offense["total"] + state["overheal_dps"]
	var ratio: float = total / maxf(required, 0.01)
	var kills: float = spawn_rate * minf(1.0, ratio)
	state["kills"] = float(state["kills"]) + kills * duration
	state["xp"] = float(state["xp"]) + kills * duration * SPARKS_PER_KILL * maxf(0.0, 1.0 + stats.get_stat(Stats.XP_GAIN_PCT) / PERCENT)
	for key: String in offense["parts"]:
		state["shares"][key] = state["shares"].get(key, 0.0) + offense["parts"][key] * duration

	var pressure: float = clampf(pow(1.0 / maxf(ratio, 0.01), PRESSURE_EXPONENT), PRESSURE_MIN, PRESSURE_MAX) * scale.get("speed", 1.0)
	var hit_damage: float = _average_enemy_damage(wave, difficulty) * scale.get("damage", 1.0)
	state["projectile_share"] = _projectile_share(wave, difficulty)
	var noise: float = exp(rng.randfn(0.0, WAVE_NOISE_SD))
	var flows: Dictionary = _defense(player, offense, kills, pressure * noise, hit_damage, state)
	state["landed"] = flows["landed"]
	player.stats.remove_modifiers(low_hp)
	var alive: bool = _apply_hp(player, state, flows, duration)
	if state.get("trace", false):
		print("W%2d dps %6.1f nötig %6.1f R %.2f | Treffer %.2f/s x %.1f -> %.2f HP/s, Heilung %.2f HP/s | HP %.1f / %.1f" % [
			wave.wave_number, total, required, ratio, flows["attempts"], flows["per_hit"], flows["damage"], flows["heal"], state["hp"], player.get_max_hp()])
	return alive


## HP über die Welle: Treffer gegen Heilung; HP-Verlust (Vampirbirne) tötet nie. Überschuss bei vollen HP
## wird bei Überheilungs-Effekten zu Schaden in der nächsten Welle.
func _apply_hp(player: Player, state: Dictionary, flows: Dictionary, duration: float) -> bool:
	var hp: float = _survive_lethal(player, float(state["hp"]) + (flows["heal"] - flows["damage"]) * duration, flows["per_hit"])
	if hp <= 0.0:
		state["hp"] = 0.0
		return false
	if flows["drain"] > 0.0:
		hp = maxf(hp - flows["drain"] * duration, minf(flows["min_hp"], hp))
	var max_hp: float = player.get_max_hp()
	state["overheal_dps"] = 0.0
	if hp > max_hp:
		state["overheal_dps"] = maxf(0.0, flows["heal"] - flows["damage"] - flows["drain"]) * _overheal_damage(player)
		hp = max_hp
	state["hp"] = hp
	return true


## Ohne `scale`: Welle 20 (ein Boss, bei Spannung 5 beide mit reduzierten HP).
## Mit `scale` (Endlos-Bosswelle): alle Bosse mit vollen HP, Endlos-Faktor und Zyklus-Bonus ("boss_hp", "boss_damage").
func _play_boss(player: Player, difficulty: DifficultyData, rng: RandomNumberGenerator, state: Dictionary,
		wave_number: int = BOSS_WAVE, scale: Dictionary = {}) -> bool:
	var boss_hp: float = 0.0
	for boss: EnemyData in bosses:
		boss_hp += boss.hp_for_wave(wave_number)
	if scale.is_empty():
		boss_hp = boss_hp / bosses.size() * _hp_factor(difficulty)
		if difficulty != null and difficulty.level >= 5:
			boss_hp *= 2.0 * ELITE_HP_FACTOR
	else:
		boss_hp *= _hp_factor(difficulty) * scale["hp"] * scale["boss_hp"]
	var damage_scale: float = scale.get("damage", 1.0)
	var low_hp: Array[StatModifier] = _add_low_hp_bonus(player)
	var offense: Dictionary = _offense(player, state, 1.0)
	var time: float = boss_hp / maxf(offense["single"] + state["overheal_dps"], 0.01)
	if time > BOSS_MAX_TIME:
		return false
	var damage_factor: float = _damage_factor(difficulty)
	var boss: EnemyData = bosses[0]
	var noise: float = exp(rng.randfn(0.0, WAVE_NOISE_SD))
	var add_time: float = minf(time, BOSS_ADD_TIME)
	state["projectile_share"] = _projectile_share(waves[RUN_WAVES - 1], difficulty)
	var add_flows: Dictionary = _defense(player, offense, 1.0, BOSS_ADD_PRESSURE * noise * scale.get("speed", 1.0),
		_average_enemy_damage(waves[RUN_WAVES - 1], difficulty) * damage_scale, state)
	var boss_damage: float = boss.damage_for_wave(wave_number) * damage_factor * damage_scale * scale.get("boss_damage", 1.0)
	# Endlos: alle Bosse greifen gleichzeitig an.
	var boss_count: float = float(bosses.size()) if not scale.is_empty() else 1.0
	state["projectile_share"] = BOSS_PROJECTILE_SHARE
	var boss_flows: Dictionary = _defense(player, offense, 0.0, BOSS_HIT_RATE / HIT_COEF * noise * boss_count, boss_damage, state)
	player.stats.remove_modifiers(low_hp)
	var hp: float = float(state["hp"]) + (add_flows["heal"] - add_flows["damage"]) * add_time - boss_flows["damage"] * time
	hp += boss_flows["heal"] * (time - add_time)
	hp = _survive_lethal(player, hp, boss_flows["per_hit"])
	state["hp"] = clampf(hp, 0.0, player.get_max_hp())
	if state.get("trace", false):
		print("Boss: %.0f HP, Einzelziel %.1f DPS -> %.0f s; Adds %.2f HP/s, Boss %.2f HP/s, Heilung %.2f -> HP %.1f" % [
			boss_hp, offense["single"], time, add_flows["damage"], boss_flows["damage"], boss_flows["heal"], hp])
	return hp > 0.0


## Reservebatterie: jede Ladung fängt einen tödlichen Treffer ab, wirkt also wie ein Treffer mehr Puffer.
func _survive_lethal(player: Player, hp: float, per_hit: float) -> float:
	if hp > 0.0:
		return hp
	for entry: TriggerEntry in player.triggers:
		if entry.effect is SurviveLethalEffect:
			var survive: SurviveLethalEffect = entry.effect
			hp += survive.charges_per_wave * (per_hit + survive.survive_hp)
	return hp


## Thermosicherung: Boni unter der HP-Schwelle anteilig (LOW_HP_UPTIME) für die Welle; Rückgabe zum Entfernen.
func _add_low_hp_bonus(player: Player) -> Array[StatModifier]:
	var mods: Array[StatModifier] = []
	for effect: LowHpStatEffect in player.low_hp_effects:
		for mod: StatModifier in effect.modifiers:
			mods.append(StatModifier.create(mod.stat, mod.value * LOW_HP_UPTIME, mod.kind))
	player.stats.add_modifiers(mods)
	return mods


func _hp_factor(difficulty: DifficultyData) -> float:
	return 1.0 + (difficulty.enemy_hp_pct / PERCENT if difficulty != null else 0.0)


func _damage_factor(difficulty: DifficultyData) -> float:
	return 1.0 + (difficulty.enemy_damage_pct / PERCENT if difficulty != null else 0.0)


## Durchschnittlicher Treffer eines Gegners der Welle (Kontakt oder Projektil, je nach Gegner), nach Anzahl gewichtet.
func _average_enemy_damage(wave: WaveData, difficulty: DifficultyData) -> float:
	var level: int = difficulty.level if difficulty != null else 0
	var total: float = 0.0
	var weight: float = 0.0
	for group: SpawnGroupData in wave.groups:
		if group.min_difficulty > level:
			continue
		var n: float = (group.group_min + group.group_max) * 0.5 / maxf(group.interval, 0.1)
		total += n * maxf(group.enemy.damage_for_wave(wave.wave_number), group.enemy.projectile_damage_for_wave(wave.wave_number))
		weight += n
	return total / maxf(weight, 0.001) * _damage_factor(difficulty)


## Anteil der Gegner der Welle, die Projektile schießen (nach Anzahl gewichtet; Schildkröte).
func _projectile_share(wave: WaveData, difficulty: DifficultyData) -> float:
	var level: int = difficulty.level if difficulty != null else 0
	var shooters: float = 0.0
	var weight: float = 0.0
	for group: SpawnGroupData in wave.groups:
		if group.min_difficulty > level:
			continue
		var n: float = (group.group_min + group.group_max) * 0.5 / maxf(group.interval, 0.1)
		if group.enemy.projectile_damage_for_wave(wave.wave_number) > 0.0:
			shooters += n
		weight += n
	return shooters / maxf(weight, 0.001)


# --- Schaden ---

## Gesamt-DPS (mit Mehrfachtreffern), Einzelziel-DPS (Boss) und Anteile je Quelle.
func _offense(player: Player, state: Dictionary, spawn_rate: float) -> Dictionary:
	var stats: StatSystem = player.stats
	var parts: Dictionary[String, float] = {}
	var single: float = 0.0
	var hits_per_second: float = 0.0
	var attacks_per_second: float = 0.0
	var weapon_dps: float = 0.0
	var burn_mult: float = maxf(0.0, 1.0 + stats.get_stat(Stats.BURN_DMG_PCT) / PERCENT)
	# Brand stapelt nicht (stärkerer/längerer ersetzt): Quellen sammeln, unten auf brennende Gegner begrenzen
	var burn_sources: Array[Vector3] = []
	var root_stop: float = 0.0
	var mirror_factor: float = 0.0
	for entry: TriggerEntry in player.triggers:
		if entry.effect is MirrorCloneEffect:
			mirror_factor += (entry.effect as MirrorCloneEffect).damage_factor
	var structures: float = 0.0
	var weapon_towers: int = 0
	# Schaden eines Angriffs aller Waffen zusammen (Kondensator verstärkt je einen Angriff pro Waffe)
	var volley: float = 0.0
	var volley_single: float = 0.0
	# Erste Waffe (Mini-Birne kopiert sie): Gesamt- und Einzelziel-DPS
	var first_dps: float = -1.0
	var first_single: float = 0.0
	for weapon: Weapon in player.weapon_slots.get_weapons():
		var t: WeaponTierStats = weapon.get_tier_stats()
		var base: float = t.base_damage + weapon.data.damage_per_same_weapon * (player.weapon_slots.count_of(weapon.data.id) - 1)
		var hit: float = CombatMath.weapon_damage(base, CombatMath.scaling_bonus(t.scalings, stats), stats.get_stat(Stats.DAMAGE_PCT), 1.0)
		var crit: float = 0.0 if player.has_rule(Player.Rule.NO_CRIT) else CombatMath.crit_chance(t.crit_chance, stats.get_stat(Stats.CRIT_CHANCE))
		var per_hit: float = hit * (1.0 + crit * (t.crit_multiplier - 1.0))
		var rate: float = 1.0 / weapon.get_cooldown()
		var targets: float = BalanceModel.targets_per_attack(weapon.data, t) + t.split_count * t.split_damage_pct / PERCENT * SPLIT_HIT_SHARE
		if t.burn_damage > 0.0 and t.burn_ticks > 0:
			burn_sources.append(Vector3(rate * targets * t.burn_chance, t.burn_damage * burn_mult, t.burn_ticks))
		weapon_dps += per_hit * rate * targets
		if first_dps < 0.0:
			first_dps = per_hit * rate * targets
			first_single = per_hit * rate
		single += per_hit * rate
		volley += per_hit * targets
		volley_single += per_hit
		hits_per_second += rate * targets
		attacks_per_second += rate
		root_stop += rate * targets * t.root_chance * t.root_duration
		if weapon.data.structure != null and weapon_towers < TOWERS.max_towers:
			structures += _structure_dps(player, weapon.data.structure, weapon.tier)
			weapon_towers += 1
	parts["Waffen"] = weapon_dps
	if mirror_factor > 0.0:
		parts["Spiegelbild"] = weapon_dps * mirror_factor
		single += single * mirror_factor
	if structures > 0.0:
		parts["Türme"] = structures
		single += structures
	for entry: Array in state.get("pets", []):
		var pet: PetData = entry[0]
		var stats_tier: PetTierStats = pet.get_tier(entry[1])
		var pet_dps: float = 0.0
		var pet_single: float = 0.0
		if pet.behavior is PetShootBehavior:
			pet_dps = PetBehavior.damage(stats_tier, stats) / maxf(stats_tier.cooldown, 0.1)
			pet_single = pet_dps
		elif pet.behavior is PetRollBehavior:
			pet_dps = PetBehavior.damage(stats_tier, stats) / maxf(stats_tier.cooldown, 0.1) * PET_ROLL_UPTIME
			pet_single = pet_dps
		elif pet.behavior is PetWeaponCopyBehavior and first_dps > 0.0:
			pet_dps = first_dps * stats_tier.damage_factor
			pet_single = first_single * stats_tier.damage_factor
		if pet_dps > 0.0:
			_add(parts, "Begleiter", pet_dps)
			single += pet_single

	var alive: float = ALIVE_BASE
	var curse_amp: float = 1.0
	var freeze_share: float = 0.0
	var slow_share: float = 0.0
	var heal_rate: float = 0.0
	# Türme aus Items, bis zur Obergrenze nach den Lampentürmen der Waffen
	var item_towers: Array = state.get("towers", [])
	for structure: StructureData in item_towers.slice(0, maxi(0, TOWERS.max_towers - weapon_towers)):
		var tower: Dictionary = _tower_value(player, structure, burn_mult)
		if tower["damage"] > 0.0:
			_add(parts, "Turm-Items", tower["damage"])
			single += tower["single"]
		if tower["burn"] != Vector3.ZERO:
			burn_sources.append(tower["burn"])
		slow_share += tower["slow"]
		heal_rate += tower["heal"]
	var burning_share: float = 0.0
	var kills: float = spawn_rate
	var ctx: EffectContext = EffectContext.create(player)
	for entry: TriggerEntry in player.triggers:
		if entry.effect is BurnOnHitEffect:
			var burn_effect: BurnOnHitEffect = entry.effect
			burn_sources.append(Vector3(hits_per_second * burn_effect.chance, ctx.effect_damage(burn_effect.base_damage, burn_effect.scalings) * burn_mult, burn_effect.ticks))
	if not burn_sources.is_empty():
		var applications: float = 0.0
		var tick_sum: float = 0.0
		var ticks_sum: float = 0.0
		for source: Vector3 in burn_sources:
			applications += source.x
			tick_sum += source.x * source.y
			ticks_sum += source.x * source.z
		var tick: float = tick_sum / maxf(applications, 0.001)
		var ticks: float = ticks_sum / maxf(applications, 0.001)
		var spread: float = 1.0 + BURN_SPREAD_FACTOR * maxf(0.0, stats.get_stat(Stats.BURN_SPREAD))
		burning_share = minf(1.0, applications * ticks * COMBAT.burn_interval * spread / alive)
		_add(parts, "Brand", alive * burning_share * tick / COMBAT.burn_interval)
		single += tick / COMBAT.burn_interval * minf(1.0, attacks_per_second * ticks * COMBAT.burn_interval)
	for entry: TriggerEntry in player.triggers:
		var effect: ItemEffect = entry.effect
		if effect is ReanimateEffect:
			var re: ReanimateEffect = effect
			var souls: float = minf(re.max_souls, float(state["kills"]) * re.souls_per_kill)
			if souls >= re.min_souls:
				var ghosts: float = minf(re.max_allies, re.lifetime / re.interval)
				var dmg: float = ctx.effect_damage(re.base_damage, re.scalings) + floorf(souls / maxf(1.0, re.souls_per_step)) * re.bonus_per_step
				_add(parts, "Geister", ghosts * dmg / STATUS.ally_contact_interval * GHOST_UPTIME)
				single += ghosts * dmg / STATUS.ally_contact_interval * GHOST_UPTIME
		elif effect is CurseOnHitEffect:
			var curse: CurseOnHitEffect = effect
			var applications: float = hits_per_second * curse.chance
			var stacks: float = clampf(applications * curse.duration / alive, 1.0, curse.max_stacks)
			var cursed: float = minf(alive, applications * curse.duration / stacks)
			_add(parts, "Fluch", cursed * curse.damage_per_second * stacks)
			single += curse.damage_per_second * stacks
			curse_amp *= 1.0 + curse.damage_taken_pct * stacks / PERCENT * cursed / alive
		elif effect is SpellCycleEffect:
			var cycle: SpellCycleEffect = effect
			var casts: float = attacks_per_second / maxf(1.0, cycle.every_nth)
			for spell: EffectAction in cycle.spells:
				var value: Dictionary = _action_value(spell, ctx)
				_add(parts, "Zauber", casts / cycle.spells.size() * value["damage"])
				single += casts / cycle.spells.size() * value["single"]
				slow_share += casts / cycle.spells.size() * value["slow"] / alive
		elif effect is TimedSpawnEffect:
			var timed: TimedSpawnEffect = effect
			var value: Dictionary = _action_value(timed.action, ctx)
			var rate: float = 1.0 / maxf(timed.interval, 0.1)
			if value["damage"] > 0.0:
				_add(parts, _action_name(timed.action), rate * value["damage"])
				single += rate * value["single"]
			freeze_share += rate * value["freeze"]
			heal_rate += rate * value["heal"]
			if value["root"] > 0.0:
				root_stop += value["root"] * alive * ROOT_STOP_SHARE / ROOT_HIT_STOP_SHARE
		elif effect is OnKillEffect:
			var on_kill: OnKillEffect = effect
			var rate: float = kills * on_kill.chance * (burning_share if on_kill.only_burning else 1.0)
			var value: Dictionary = _action_value(on_kill.action, ctx)
			_add(parts, "Bei Kill", rate * value["damage"])
			heal_rate += rate * value["heal"]
		elif effect is OnSparkCollectedEffect:
			var on_spark: OnSparkCollectedEffect = effect
			var value: Dictionary = _action_value(on_spark.action, ctx)
			_add(parts, "Funken-Treffer", kills * SPARKS_PER_KILL * on_spark.chance * value["damage"])
		elif effect is OnHitTakenEffect:
			var on_hit: OnHitTakenEffect = effect
			var value: Dictionary = _action_value(on_hit.action, ctx)
			_add(parts, "Bei Treffer", float(state.get("landed", 0.0)) * on_hit.chance * value["damage"])
		elif effect is KillChargeEffect:
			var charge: KillChargeEffect = effect
			var charges: float = kills / maxf(1.0, charge.kills_needed)
			var bonus: float = charge.damage_factor - 1.0
			_add(parts, "Kondensator", minf(charges * bonus * volley, bonus * weapon_dps))
			single += minf(charges * bonus * volley_single, bonus * weapon_dps)
		elif effect is OrbitingDroneEffect:
			var drone: OrbitingDroneEffect = effect
			var count: int = drone.base_count
			for level: int in drone.extra_at_levels:
				if int(state["level"]) >= level:
					count += 1
			_add(parts, "Drohnen", count * _structure_dps(player, drone.drone, 1))
			single += count * _structure_dps(player, drone.drone, 1)
	var total: float = 0.0
	for key: String in parts:
		parts[key] *= curse_amp
		total += parts[key]
	single *= curse_amp
	return {"total": total, "single": single, "parts": parts, "hits": hits_per_second, "freeze": clampf(freeze_share, 0.0, 0.9),
		"slow": clampf(slow_share, 0.0, 0.9), "stop": clampf(root_stop * ROOT_HIT_STOP_SHARE / alive, 0.0, 0.9), "heal": heal_rate}


func _add(parts: Dictionary[String, float], key: String, value: float) -> void:
	parts[key] = parts.get(key, 0.0) + value


func _structure_dps(player: Player, structure: StructureData, tier: int) -> float:
	if structure.kind != StructureData.Kind.TURRET:
		return 0.0
	var damage: float = CombatMath.weapon_damage(structure.base_damage, CombatMath.scaling_bonus(structure.scalings, player.stats), 0.0, 1.0)
	return damage / CombatMath.attack_cooldown(structure.cooldown_for_tier(tier), player.stats.get_stat(Stats.STRUCTURE_ATTACK_SPEED_PCT))


## Ein Turm aus einem Item: Schaden pro Sekunde (alle Ziele, Einzelziel), Brandquelle (Rate, Tick, Ticks),
## Verlangsamung (Anteil der Gegner x Stärke) und Heilung pro Sekunde.
func _tower_value(player: Player, structure: StructureData, burn_mult: float) -> Dictionary:
	var stats: StatSystem = player.stats
	var value: Dictionary = {"damage": 0.0, "single": 0.0, "burn": Vector3.ZERO, "slow": 0.0, "heal": 0.0}
	var rate: float = 1.0 / structure.cooldown(1, stats)
	match structure.kind:
		StructureData.Kind.TURRET:
			value["damage"] = _structure_dps(player, structure, 1)
			value["single"] = value["damage"]
		StructureData.Kind.FLAME:
			value["damage"] = structure.damage(stats) * rate * FLAME_TARGETS
			value["single"] = structure.damage(stats) * rate
			value["burn"] = Vector3(rate * FLAME_TARGETS, structure.burn_tick(stats) * burn_mult, structure.burn_ticks)
		StructureData.Kind.FROST:
			var area: float = pow(structure.aura(stats) / FROST_REFERENCE_RADIUS, 2.0)
			value["slow"] = minf(1.0, FROST_ENEMY_SHARE * area) * structure.slow_pct / PERCENT
		StructureData.Kind.HEAL:
			value["heal"] = structure.heal(stats) * rate * HEAL_UPTIME
		StructureData.Kind.MINE_LAYER:
			var ctx: EffectContext = EffectContext.create(player)
			ctx.structure_damage = true
			var mine: Dictionary = _action_value(structure.mine, ctx)
			value["damage"] = rate * MINE_HIT_SHARE * mine["damage"]
			value["single"] = rate * MINE_HIT_SHARE * mine["single"]
	return value


## Wirkung einer Aktion pro Auslösung: Schaden (alle Ziele), Einzelziel-Schaden, eingefrorene Zeit (Anteil
## aller Gegner x Sekunden), Verlangsamung (Gegner x Sekunden), Heilung und Ranken.
func _action_value(action: EffectAction, ctx: EffectContext) -> Dictionary:
	var value: Dictionary = {"damage": 0.0, "single": 0.0, "freeze": 0.0, "slow": 0.0, "heal": 0.0, "root": 0.0}
	var stats: StatSystem = ctx.player.stats
	if action is ExplosionAction:
		var explosion: ExplosionAction = action
		var dmg: float = ctx.effect_damage(explosion.base_damage, explosion.scalings) * maxf(0.0, 1.0 + stats.get_stat(Stats.EXPLOSION_DMG_PCT) / PERCENT)
		value["damage"] = dmg * EXPLOSION_TARGETS * maxf(0.0, 1.0 + stats.get_stat(Stats.EXPLOSION_SIZE_PCT) / PERCENT)
		value["single"] = dmg
	elif action is FrostNovaAction:
		var nova: FrostNovaAction = action
		var dmg: float = ctx.effect_damage(nova.base_damage, nova.scalings)
		value["damage"] = dmg * NOVA_TARGETS
		value["single"] = dmg
		value["slow"] = NOVA_TARGETS * nova.duration * nova.slow_pct / PERCENT
	elif action is ChainLightningAction:
		var chain: ChainLightningAction = action
		var dmg: float = ctx.effect_damage(chain.base_damage, chain.scalings)
		value["damage"] = dmg * (1.0 + chain.jumps * CHAIN_HIT_SHARE)
		value["single"] = dmg
	elif action is DamageRandomEnemiesAction:
		var random_hit: DamageRandomEnemiesAction = action
		var dmg: float = ctx.effect_damage(random_hit.base_damage, random_hit.scalings)
		value["damage"] = dmg * random_hit.count
		value["single"] = dmg
	elif action is FreezeEnemiesAction:
		value["freeze"] = (action as FreezeEnemiesAction).duration
	elif action is SpawnPickupAction:
		var pickup: SpawnPickupAction = action
		if pickup.kind != 0:
			value["heal"] = pickup.count * (DROPS.battery_heal + ctx.player.stats.get_stat(Stats.CONSUMABLE_HEAL))
	elif action is BuildStructureAction:
		var build: BuildStructureAction = action
		if build.structure.kind == StructureData.Kind.ROOT:
			value["root"] = build.structure.max_count * build.structure.root_duration
	return value


func _action_name(action: EffectAction) -> String:
	if action is FreezeEnemiesAction:
		return "Lichtblitz"
	return "Zeitgesteuert"


func _overheal_damage(player: Player) -> float:
	var factor: float = 0.0
	for entry: TriggerEntry in player.triggers:
		if entry.effect is OverhealDamageEffect:
			factor += (entry.effect as OverhealDamageEffect).damage_per_hp
	return factor


# --- Eingesteckter Schaden und Heilung ---

func _defense(player: Player, offense: Dictionary, kills: float, pressure: float, hit_damage: float, state: Dictionary = {}) -> Dictionary:
	var stats: StatSystem = player.stats
	var melee_share: float = 0.0
	var weapons_now: Array[Weapon] = player.weapon_slots.get_weapons()
	for weapon: Weapon in weapons_now:
		if weapon.data.is_melee():
			melee_share += 1.0 / weapons_now.size()
	var speed_relief: float = clampf(stats.get_stat(Stats.SPEED) / SPEED_HIT_DIVISOR, -SPEED_HIT_MAX_REDUCTION, SPEED_HIT_MAX_REDUCTION)
	var attempts: float = HIT_COEF * pressure * lerpf(1.0, MELEE_HIT_FACTOR, melee_share) * (1.0 - speed_relief)
	attempts *= (1.0 - offense["freeze"]) * (1.0 - offense["stop"]) * (1.0 - offense["slow"] * SLOW_DEFENSE_SHARE)
	attempts = minf(attempts, MAX_HITS_PER_SECOND)
	for entry: Array in state.get("pets", []):
		var pet: PetData = entry[0]
		var stats_tier: PetTierStats = pet.get_tier(entry[1])
		if pet.behavior is PetBlockBehavior:
			attempts -= minf(attempts * float(state.get("projectile_share", 0.0)), PET_BLOCK_HIT_SHARE / maxf(stats_tier.cooldown, 0.1))
		elif pet.behavior is PetCollectBehavior:
			attempts *= 1.0 - minf(0.5, PET_COLLECT_HIT_RELIEF_PER_100 * stats_tier.radius / 100.0)
	var dodge: float = CombatMath.dodge_chance(stats.get_stat(Stats.DODGE), player.config.dodge_cap)
	var landed: float = attempts * (1.0 - dodge)
	var per_hit: float = maxf(CombatMath.MIN_DAMAGE, hit_damage * CombatMath.armor_multiplier(stats.get_stat(Stats.ARMOR)))
	var damage: float = landed * per_hit

	var heal: float = offense["heal"]
	if not player.has_rule(Player.Rule.NO_REGEN):
		heal += CombatMath.hp_regen_per_second(stats.get_stat(Stats.HP_REGEN))
	var lifesteal: float = CombatMath.lifesteal_chance(stats.get_stat(Stats.LIFESTEAL))
	heal += minf(offense["hits"] * lifesteal, LIFESTEAL_MAX_PER_SECOND / maxf(player.lifesteal_interval_factor, 0.1))
	var battery_heal: float = DROPS.battery_heal + stats.get_stat(Stats.CONSUMABLE_HEAL)
	var luck: float = maxf(0.0, 1.0 + stats.get_stat(Stats.LUCK) / PERCENT)
	heal += kills * DROPS.consumable_base_chance * luck * battery_heal
	heal += CRYSTAL_SPAWNS_PER_SECOND * maxf(0.0, 1.0 + stats.get_stat(Stats.CRYSTALS) / PERCENT) * battery_heal * BATTERY_SHARE
	var drain: float = 0.0
	var min_hp: float = 0.0
	for entry: TriggerEntry in player.triggers:
		if entry.effect is HpDrainEffect:
			var hp_drain: HpDrainEffect = entry.effect
			drain += hp_drain.amount / maxf(hp_drain.interval, 0.1)
			min_hp = maxf(min_hp, hp_drain.min_hp)
		elif entry.effect is OnHitTakenEffect:
			var on_hit: OnHitTakenEffect = entry.effect
			heal += landed * on_hit.chance * _action_value(on_hit.action, EffectContext.create(player))["heal"]
	for weapon: Weapon in weapons_now:
		var t: WeaponTierStats = weapon.get_tier_stats()
		heal += t.heal_on_hit_chance / weapon.get_cooldown() * BalanceModel.targets_per_attack(weapon.data, t)
	return {"damage": damage, "drain": drain, "min_hp": min_hp, "heal": heal, "attempts": attempts, "per_hit": per_hit, "landed": landed}
