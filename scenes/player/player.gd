class_name Player
extends CharacterBody2D
## Spielfigur Bulbro: Bewegung, HP, Regeneration, Trefferablauf und Lebensraub.
## Trefferablauf (GDD 4): Ausweichwurf -> Rüstungsreduktion -> HP abziehen -> Unverwundbarkeit.

signal hp_changed(current: float, maximum: float)
signal damaged(amount: int)
signal dodged
signal died

const GROUP: StringName = &"player"

@export var config: PlayerConfig

var stats: StatSystem
var current_hp: float = 0.0
var is_dead: bool = false
## Bewegungsgrenze; leeres Rect = keine Begrenzung. Wird von der Arena gesetzt.
var arena_bounds: Rect2 = Rect2()
## Zufallsquelle für Ausweichen und Lebensraub. Standard: der Run-RNG mit Seed.
var rng: RandomNumberGenerator

var _invulnerable_left: float = 0.0
var _elapsed: float = 0.0
var _last_lifesteal_time: float = -INF
var _known_max_hp: float = 0.0
## Registrierte Trigger-Effekte von Items und Charakter (vom EffectSystem aufgerufen).
var triggers: Array[TriggerEntry] = []
## Multiplikator für Set-Boni einzelner Klassen (z. B. Kerze: Primitiv doppelt).
var set_bonus_multiplier: Dictionary[StringName, float] = {}

var _set_modifiers: Array[StatModifier] = []

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite
@onready var _light: PointLight2D = $Light
@onready var weapon_slots: WeaponSlots = $WeaponSlots
@onready var _collision: CollisionShape2D = $CollisionShape


func _ready() -> void:
	add_to_group(GROUP)
	if rng == null:
		rng = GameState.rng
	stats = StatSystem.new(config.base_stats)
	stats.stats_changed.connect(_on_stats_changed)
	_known_max_hp = get_max_hp()
	current_hp = _known_max_hp
	_light.color = config.light_color
	_light.energy = config.light_energy
	_light.texture_scale = config.light_texture_scale
	weapon_slots.player = self
	weapon_slots.max_slots = config.weapon_slots
	weapon_slots.orbit_radius = config.weapon_orbit_radius
	weapon_slots.weapons_changed.connect(update_set_bonuses)
	Juice.idle_bob(_visual)
	Events.level_up.connect(_on_level_up)
	hp_changed.emit(current_hp, _known_max_hp)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _invulnerable_left > 0.0:
		_invulnerable_left -= delta
	if is_dead:
		return
	var direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = direction * get_move_speed()
	move_and_slide()
	_clamp_to_arena()
	Juice.walk_tilt(_visual, velocity)
	_regenerate(delta)


func get_max_hp() -> float:
	return CombatMath.effective_max_hp(stats.get_stat(Stats.MAX_HP))


func get_move_speed() -> float:
	return CombatMath.move_speed(config.base_move_speed, stats.get_stat(Stats.SPEED))


func get_pickup_radius() -> float:
	return Economy.pickup_radius(config.pickup_radius, stats.get_stat(Stats.PICKUP_RANGE_PCT))


## Körpermitte in Weltkoordinaten (Ziel für Pickups).
func get_center() -> Vector2:
	return _collision.global_position


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Wendet einen gegnerischen Treffer an. Gibt den tatsächlich erlittenen Schaden zurück (0 = ausgewichen oder unverwundbar).
func take_hit(raw_damage: float) -> int:
	if is_dead or is_invulnerable():
		return 0
	var amount: int = CombatMath.resolve_incoming_damage(
		raw_damage, stats.get_stat(Stats.ARMOR), stats.get_stat(Stats.DODGE), config.dodge_cap, rng.randf())
	if amount == 0:
		dodged.emit()
		return 0
	current_hp = maxf(0.0, current_hp - amount)
	_invulnerable_left = config.invulnerability_time
	Juice.hit_flash(_sprite)
	damaged.emit(amount)
	hp_changed.emit(current_hp, get_max_hp())
	if current_hp <= 0.0:
		_die()
	return amount


func apply_item(item: ItemData) -> void:
	for effect: ItemEffect in item.effects:
		effect.apply(self)


## Klassen-Set-Boni (GDD 8) aus der Anzahl Waffen je Klasse neu berechnen.
func update_set_bonuses() -> void:
	var counts: Dictionary[StringName, int] = {}
	for weapon: Weapon in weapon_slots.get_weapons():
		for weapon_class: StringName in weapon.data.classes:
			counts[weapon_class] = counts.get(weapon_class, 0) + 1
	var new_mods: Array[StatModifier] = []
	for res: Resource in DataRegistry.get_all("sets"):
		var set_bonus: SetBonusData = res as SetBonusData
		var factor: float = set_bonus_multiplier.get(set_bonus.weapon_class, 1.0)
		for mod: StatModifier in set_bonus.modifiers_for(counts.get(set_bonus.weapon_class, 0)):
			new_mods.append(StatModifier.create(mod.stat, mod.value * factor, mod.kind))
	stats.remove_modifiers(_set_modifiers)
	_set_modifiers = new_mods
	stats.add_modifiers(new_mods)


func get_set_modifiers() -> Array[StatModifier]:
	return _set_modifiers


func add_trigger(effect: ItemEffect) -> void:
	triggers.append(TriggerEntry.create(effect))


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_hp = minf(current_hp + amount, get_max_hp())
	hp_changed.emit(current_hp, get_max_hp())


## Von Waffen bei jedem Treffer aufgerufen. Gibt true zurück, wenn Lebensraub geheilt hat.
func try_lifesteal() -> bool:
	if not CombatMath.lifesteal_ready(_elapsed, _last_lifesteal_time):
		return false
	if rng.randf() >= CombatMath.lifesteal_chance(stats.get_stat(Stats.LIFESTEAL)):
		return false
	_last_lifesteal_time = _elapsed
	heal(1.0)
	return true


func _regenerate(delta: float) -> void:
	var per_second: float = CombatMath.hp_regen_per_second(stats.get_stat(Stats.HP_REGEN))
	if per_second > 0.0 and current_hp < get_max_hp():
		heal(per_second * delta)


func _clamp_to_arena() -> void:
	if not arena_bounds.has_area():
		return
	var margin: Vector2 = Vector2.ONE * config.collision_radius
	global_position = global_position.clamp(arena_bounds.position + margin, arena_bounds.end - margin)


func _die() -> void:
	is_dead = true
	current_hp = 0.0
	died.emit()
	Events.player_died.emit()
	weapon_slots.hide()
	Juice.squash_pop(_visual)


## Jedes Level-up gibt sofort Max HP; die Upgrade-Auswahl folgt am Wellenende.
func _on_level_up(_new_level: int) -> void:
	stats.add_modifier(StatModifier.create(Stats.MAX_HP, config.max_hp_per_level))


## Steigt Max HP, steigen die aktuellen HP um denselben Betrag; sinkt es, werden sie nur gekappt.
func _on_stats_changed() -> void:
	var new_max: float = get_max_hp()
	if new_max > _known_max_hp:
		current_hp += new_max - _known_max_hp
	current_hp = minf(current_hp, new_max)
	_known_max_hp = new_max
	hp_changed.emit(current_hp, new_max)
