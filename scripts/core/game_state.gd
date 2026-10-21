extends Node
## Zustand des aktuellen Runs (Autoload "GameState").
## Hält den Run-RNG mit Seed, damit Runs für Debugging reproduzierbar sind, sowie Funken, Beutel, XP, Level, Items
## und die State Machine des Ablaufs nach einer Welle:
##   WAVE -> POST_WAVE -> CRATES (je Karton) -> LEVEL_UP (je Level) -> SHOP -> WAVE

## Phasen eines Runs.
enum Phase { WAVE, POST_WAVE, CRATES, LEVEL_UP, SHOP, ENDED }

var run_seed: int = 0
var current_wave: int = 0
var is_run_active: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Währung (1 Funke = 1 Währung + 1 XP).
var sparks: int = 0
## Nicht aufgesammelte Funken der letzten Welle; jeder neue Funke gibt +1 daraus dazu.
var bag: int = 0
var xp: float = 0.0
var level: int = 0
## Level-ups, die am Wellenende abgearbeitet werden.
var pending_level_ups: int = 0
var crates_this_wave: int = 0
## Eingesammelte Kartons, die am Wellenende geöffnet werden.
var pending_crates: int = 0
## Davon legendär (Elites/Boss): garantiert Tier IV.
var pending_legendary_crates: int = 0
## Sonderwellen dieses Runs nach Spannung: Wellennummer -> "elite" oder "horde".
var special_waves: Dictionary[int, String] = {}
var total_sparks_collected: int = 0
var phase: Phase = Phase.WAVE
## Alle gekauften oder aus Kartons genommenen Items (Mehrfachbesitz möglich).
var items: Array[ItemData] = []
## Tags, die der aktuelle Charakter bevorzugt (Shop-Gewichtung).
var preferred_tags: Array[StringName] = []
## Shop-Zustand über die Wellen hinweg (gesperrte Angebote).
var shop: Shop
## Höchste Zahl gleichzeitiger Strukturen in diesem Run (Freischaltung Taschenlampe).
var max_structures: int = 0
## Barrierefreiheit (Optionen): Faktoren 0,25-1,0 auf Gegner-HP, -Schaden und -Tempo, je Run gelesen.
var assist_hp: float = 1.0
var assist_damage: float = 1.0
var assist_speed: float = 1.0
## Gesetzt vom Hauptmenü ("Fortsetzen"): gespeicherter Run, den die Arena wiederherstellt.
var resume_data: Dictionary = {}
## Endlos-Modus nach dem Sieg in der letzten regulären Welle.
var endless: bool = false
var endless_start_wave: int = 0
## Bereits in die Gesamtstatistik übernommen (Endlos-Modus wertet den Run zweimal aus).
var run_reported: bool = false
var reported_sparks: int = 0
var reported_kills: int = 0
var run_stats: RunStats = RunStats.new()
## Seelenglas des Irrlichts (wird beim Fortsetzen gespeichert).
var souls: SoulCounter = SoulCounter.new()

## Run-Einstellungen aus dem Menü (bleiben über start_run und Neustart erhalten).
var character: CharacterData
var starting_weapon: WeaponData
var difficulty: DifficultyData


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(_data: EnemyData, _position: Vector2, info: DamageInfo) -> void:
	run_stats.enemies_killed += 1
	if info != null and info.is_burn:
		run_stats.burn_kills += 1


## Startet einen neuen Run. Ohne Seed wird ein zufälliger gewählt.
func start_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
		run_seed = rng.seed
	else:
		run_seed = seed_value
	rng.seed = run_seed
	current_wave = 0
	sparks = 0
	bag = 0
	xp = 0.0
	level = 0
	pending_level_ups = 0
	crates_this_wave = 0
	pending_crates = 0
	pending_legendary_crates = 0
	special_waves.clear()
	total_sparks_collected = 0
	items.clear()
	preferred_tags.clear()
	shop = Shop.create_from_registry()
	max_structures = 0
	run_stats = RunStats.new()
	souls = SoulCounter.new()
	endless = false
	endless_start_wave = 0
	run_reported = false
	reported_sparks = 0
	reported_kills = 0
	assist_hp = SaveManager.get_assist_factor(SaveManager.ENEMY_HP_KEY)
	assist_damage = SaveManager.get_assist_factor(SaveManager.ENEMY_DAMAGE_KEY)
	assist_speed = SaveManager.get_assist_factor(SaveManager.ENEMY_SPEED_KEY)
	_ensure_setup()
	phase = Phase.WAVE
	is_run_active = true
	Events.run_started.emit(run_seed)


const DEFAULT_CHARACTER: String = "res://data/characters/standardbirne.tres"
const DEFAULT_DIFFICULTY: String = "res://data/difficulties/spannung_0.tres"


## Ohne Menü (Szene direkt gestartet, Tests): Standardbirne, erste Startwaffe, Spannung 0.
func _ensure_setup() -> void:
	if character == null:
		character = load(DEFAULT_CHARACTER)
	if starting_weapon == null or not character.can_use_weapon(starting_weapon):
		starting_weapon = character.starting_weapons[0] if not character.starting_weapons.is_empty() else null
	if difficulty == null:
		difficulty = load(DEFAULT_DIFFICULTY)


## Anzahl Endloswellen bisher (0 vor dem Endlos-Modus).
func endless_level() -> int:
	return maxi(0, current_wave - endless_start_wave) if endless else 0


## Gegner-Faktor im Endlos-Modus: (1 + Zuwachs)^Endloswelle, optional gedeckelt.
func endless_factor(growth: float, cap: float = INF) -> float:
	return minf(pow(1.0 + growth, endless_level()), 1.0 + cap)


func set_run_setup(p_character: CharacterData, p_weapon: WeaponData, p_difficulty: DifficultyData) -> void:
	character = p_character
	starting_weapon = p_weapon
	difficulty = p_difficulty


func end_run(victory: bool) -> void:
	is_run_active = false
	set_phase(Phase.ENDED)
	Events.run_ended.emit(victory)


func set_phase(new_phase: Phase) -> void:
	phase = new_phase
	Events.run_phase_changed.emit(new_phase)


## Nächster Schritt nach einer Welle: erst alle Kartons, dann alle Level-ups, dann der Shop.
func advance_post_wave() -> void:
	if pending_crates > 0:
		set_phase(Phase.CRATES)
	elif pending_level_ups > 0:
		set_phase(Phase.LEVEL_UP)
	else:
		set_phase(Phase.SHOP)


func finish_crate() -> void:
	pending_crates = maxi(0, pending_crates - 1)
	pending_legendary_crates = maxi(0, pending_legendary_crates - 1)
	advance_post_wave()


func finish_level_up() -> void:
	pending_level_ups = maxi(0, pending_level_ups - 1)
	Events.xp_changed.emit(xp, xp_needed(), level)
	advance_post_wave()


## Level, dessen Upgrade gerade gewählt wird (für die garantierte Seltenheit).
func level_being_upgraded() -> int:
	return level - pending_level_ups + 1


func item_count(item_id: StringName) -> int:
	var count: int = 0
	for item: ItemData in items:
		if item.id == item_id:
			count += 1
	return count


func item_counts() -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for item: ItemData in items:
		counts[item.id] = counts.get(item.id, 0) + 1
	return counts


func add_item(item: ItemData) -> void:
	items.append(item)
	Events.item_added.emit(item)


## Zieht Funken ab, wenn genug vorhanden sind.
func spend(amount: int) -> bool:
	if amount > sparks:
		return false
	add_sparks(-amount)
	return true


func xp_needed() -> float:
	return Economy.xp_for_level(level)


## Ein Funke wurde aufgesammelt. Gibt den tatsächlichen Wert inkl. Beutel-Bonus zurück.
func collect_spark(value: int, xp_gain_pct: float) -> int:
	var bonus: int = mini(bag, value)
	bag -= bonus
	var total: int = value + bonus
	total_sparks_collected += total
	add_sparks(total)
	add_xp(Economy.xp_gain(total, xp_gain_pct))
	return total


func add_sparks(amount: int) -> void:
	sparks = maxi(0, sparks + amount)
	Events.sparks_changed.emit(sparks, bag)


func add_to_bag(amount: int) -> void:
	bag += amount
	Events.sparks_changed.emit(sparks, bag)


func add_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		pending_level_ups += 1
		Events.level_up.emit(level)
	Events.xp_changed.emit(xp, xp_needed(), level)


func add_crate(legendary: bool = false) -> void:
	pending_crates += 1
	if legendary:
		pending_legendary_crates += 1
	Events.crate_collected.emit(pending_crates)
