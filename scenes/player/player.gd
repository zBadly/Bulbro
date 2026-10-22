class_name Player
extends CharacterBody2D
## Spielfigur Bulbro: Bewegung, HP, Regeneration, Trefferablauf und Lebensraub.
## Trefferablauf (GDD 4): Ausweichwurf -> Rüstungsreduktion -> HP abziehen -> Unverwundbarkeit.

signal hp_changed(current: float, maximum: float)
signal damaged(amount: int)
signal dodged
signal died
## Eine Waffe greift an (Zauberzyklus). Spiegelbild-Waffen melden sich nicht.
signal weapon_attacked(weapon: Weapon, target: Damageable)
## Ein Waffen- oder Strukturtreffer (Fluch, Brandchance).
signal enemy_hit(target: Damageable, info: DamageInfo)
## Heilung über Max HP hinaus (Vampirbirne).
signal overhealed(amount: float)

## Sonderregeln, die Charakter-Effekte setzen (PlayerRuleEffect).
enum Rule { NO_REGEN, NO_CRIT }

const GROUP: StringName = &"player"
## Standardanzahl Waffenslots (Charaktere wie die Lichterkette weichen davon ab).
const DEFAULT_WEAPON_SLOTS: int = 6
const AIM_STICK_DEADZONE: float = 0.3
## Effekt-Blitz (Stroboskop): Lichtstärke kurz mal diesem Faktor.
const EFFECT_LIGHT_BOOST: float = 2.5

@export var config: PlayerConfig

var stats: StatSystem
var current_hp: float = 0.0
var is_dead: bool = false
## Debug-Menü: Treffer werden ignoriert.
var debug_invulnerable: bool = false
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
## Herkunft der Effekte, die gerade angewendet werden (Item oder Charakter), für die Trigger.
var _applying_origin: StringName = &""
## Multiplikator für Set-Boni einzelner Klassen (z. B. Kerze: Primitiv doppelt).
var set_bonus_multiplier: Dictionary[StringName, float] = {}

var character: CharacterData
## Klassen-Boni des Charakters (z. B. +50 % Angriffstempo mit Unbewaffnet).
var class_bonuses: Array[ClassBonusEffect] = []
var per_weapon_effects: Array[PerWeaponStatEffect] = []
var standing_still_modifiers: Array[StatModifier] = []

## Modifikatoren aus dem Run (Level-up-Wahl, Max HP pro Level, Aufladungs-Wachstum) – für Fortsetzen gespeichert.
var run_modifiers: Array[StatModifier] = []
## Manuelles Zielen: Waffen feuern in Richtung Maus/rechter Stick statt auf den nächsten Gegner.
var manual_aim: bool = false
## Faktor auf den Mindestabstand zwischen zwei Lebensraub-Heilungen (0,5 = doppeltes Limit).
var lifesteal_interval_factor: float = 1.0
var rules: Dictionary[Rule, bool] = {}

var _set_modifiers: Array[StatModifier] = []
var _still_active: bool = false
var _aim_direction: Vector2 = Vector2.RIGHT
## Nachschwingendes Zusatzteil des Charakters (Kronleuchter-Kristalle), sonst null.
var _swing: Sprite2D

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
	weapon_slots.weapons_changed.connect(update_weapon_modifiers)
	weapon_slots.weapons_changed.connect(_track_run)
	Juice.idle_bob(_visual)
	Events.level_up.connect(_on_level_up)
	Events.wave_ended.connect(_on_wave_ended)
	manual_aim = SaveManager.get_option(SaveManager.MANUAL_AIM_KEY, false)
	hp_changed.emit(current_hp, _known_max_hp)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_aim") and GameState.phase == GameState.Phase.WAVE:
		manual_aim = not manual_aim
		get_viewport().set_input_as_handled()


## Zielrichtung beim manuellen Zielen: rechter Stick, sonst Maus.
func get_aim_direction() -> Vector2:
	var stick: Vector2 = Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > AIM_STICK_DEADZONE:
		_aim_direction = stick.normalized()
	elif is_inside_tree():
		var to_mouse: Vector2 = get_global_mouse_position() - get_center()
		if not to_mouse.is_zero_approx():
			_aim_direction = to_mouse.normalized()
	return _aim_direction


func add_run_modifier(mod: StatModifier) -> void:
	run_modifiers.append(mod)
	stats.add_modifier(mod)


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
	if _swing != null:
		Juice.swing(_swing, velocity, delta)
	_update_standing_still()
	_regenerate(delta)


func get_max_hp() -> float:
	return CombatMath.effective_max_hp(stats.get_stat(Stats.MAX_HP))


func get_move_speed() -> float:
	return CombatMath.move_speed(config.base_move_speed, stats.get_stat(Stats.SPEED))


func get_pickup_radius() -> float:
	return Economy.pickup_radius(config.pickup_radius, stats.get_stat(Stats.PICKUP_RANGE_PCT))


func get_body_texture() -> Texture2D:
	return _sprite.texture


## Körpermitte in Weltkoordinaten (Ziel für Pickups).
func get_center() -> Vector2:
	return _collision.global_position


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Wendet einen gegnerischen Treffer an. Gibt den tatsächlich erlittenen Schaden zurück (0 = ausgewichen oder unverwundbar).
func take_hit(raw_damage: float) -> int:
	if is_dead or is_invulnerable() or debug_invulnerable:
		return 0
	var amount: int = CombatMath.resolve_incoming_damage(
		raw_damage, stats.get_stat(Stats.ARMOR), stats.get_stat(Stats.DODGE), config.dodge_cap, rng.randf())
	if amount == 0:
		dodged.emit()
		return 0
	if not GameState.admin.infinite_hp:
		current_hp = maxf(0.0, current_hp - amount)
	_invulnerable_left = config.invulnerability_time
	Juice.hit_flash(_sprite)
	damaged.emit(amount)
	hp_changed.emit(current_hp, get_max_hp())
	if current_hp <= 0.0:
		_die()
	return amount


func apply_item(item: ItemData) -> void:
	_applying_origin = DamageSource.item(item.id)
	for effect: ItemEffect in item.effects:
		effect.apply(self)
	_applying_origin = &""


## Charakter anwenden: Grafik, Waffenslots, Effekte, Sonderregeln, Shop-Vorlieben.
func apply_character(data: CharacterData) -> void:
	character = data
	_apply_character_visuals(data)
	_apply_character_rules(data)
	update_weapon_modifiers()


## Waffenslots, Set-Multiplikatoren, Effekte und Shop-Vorlieben (ohne Grafik).
func _apply_character_rules(data: CharacterData) -> void:
	if data.weapon_slots > 0:
		weapon_slots.max_slots = data.weapon_slots
	set_bonus_multiplier = data.set_bonus_multiplier.duplicate()
	_applying_origin = DamageSource.character(data.id)
	for effect: ItemEffect in data.effects:
		_apply_character_effect(effect)
	_applying_origin = &""
	GameState.preferred_tags = data.preferred_tags.duplicate()


## Baut alle Werte neu auf: Grundwerte, Charakter, Items (in Kaufreihenfolge), Run-Modifikatoren, Set-Boni.
## Ergibt dieselben Werte wie der normale Aufbau im Run. Trigger-Effekte, die es weiterhin gibt, behalten ihren
## Zustand (Timer, Zähler, erzeugte Drohnen/Spiegelbild/Geister); weggefallene räumen ihre Knoten auf,
## neue starten während einer Welle sofort. Waffen und aktuelle HP bleiben (HP höchstens bis Max HP).
func rebuild() -> void:
	var hp: float = current_hp
	var old_triggers: Array[TriggerEntry] = triggers.duplicate()
	triggers.clear()
	stats.stats_changed.disconnect(_on_stats_changed)
	stats = StatSystem.new(config.base_stats)
	class_bonuses.clear()
	per_weapon_effects.clear()
	standing_still_modifiers.clear()
	_still_active = false
	rules.clear()
	lifesteal_interval_factor = 1.0
	set_bonus_multiplier.clear()
	_set_modifiers = []
	weapon_slots.max_slots = config.weapon_slots
	if character != null:
		_apply_character_rules(character)
	for item: ItemData in GameState.items:
		apply_item(item)
	stats.add_modifiers(run_modifiers)
	update_weapon_modifiers()
	_reconcile_triggers(old_triggers)
	stats.stats_changed.connect(_on_stats_changed)
	_known_max_hp = get_max_hp()
	current_hp = minf(hp, _known_max_hp)
	hp_changed.emit(current_hp, _known_max_hp)


## Neu registrierte Trigger übernehmen den Zustand ihres Vorgängers (gleiche Effekt-Resource, gleiche Reihenfolge).
func _reconcile_triggers(old_triggers: Array[TriggerEntry]) -> void:
	var ctx: EffectContext = EffectContext.create(self)
	var in_wave: bool = GameState.is_run_active and GameState.phase == GameState.Phase.WAVE
	var unmatched: Array[TriggerEntry] = old_triggers.duplicate()
	for i in triggers.size():
		var fresh: TriggerEntry = triggers[i]
		var previous: TriggerEntry = null
		for old: TriggerEntry in unmatched:
			if old.effect == fresh.effect:
				previous = old
				break
		if previous != null:
			unmatched.erase(previous)
			triggers[i] = previous
		elif in_wave:
			ctx.origin = fresh.origin
			fresh.effect.on_wave_started(ctx, fresh)
	for old: TriggerEntry in unmatched:
		ctx.origin = old.origin
		old.effect.on_wave_ended(ctx, old)


## Admin: Charakter wechseln. Werte werden neu berechnet, Waffen bleiben (auch über dem neuen Slot-Limit).
## Laufende Werte des Runs (Seelenglas, Zähler von Items) bleiben, Effekte des alten Charakters enden.
func switch_character(data: CharacterData) -> void:
	character = data
	_reset_character_visuals()
	_apply_character_visuals(data)
	rebuild()
	GameState.character = data


func _reset_character_visuals() -> void:
	Juice.stop_idle(_visual)
	Juice.stop_flicker(_sprite)
	Juice.idle_bob(_visual)
	_light.color = config.light_color
	if _swing != null:
		_swing.queue_free()
		_swing = null


## Admin: Level direkt setzen. Der Max-HP-Bonus pro Level wird angepasst, Upgrade-Karten gibt es nicht.
func admin_set_level(level: int) -> void:
	var delta: int = level - GameState.level
	GameState.level = maxi(0, level)
	GameState.xp = 0.0
	if delta > 0:
		for i in delta:
			add_run_modifier(StatModifier.create(Stats.MAX_HP, config.max_hp_per_level))
	else:
		for i in -delta:
			for j in range(run_modifiers.size() - 1, -1, -1):
				var mod: StatModifier = run_modifiers[j]
				if mod.stat == Stats.MAX_HP and mod.kind == StatModifier.Kind.FLAT and is_equal_approx(mod.value, config.max_hp_per_level):
					run_modifiers.remove_at(j)
					stats.remove_modifier(mod)
					break
	Events.xp_changed.emit(GameState.xp, GameState.xp_needed(), GameState.level)


## Lichtfarbe, Animationsstil und nachschwingende Teile des Charakters.
func _apply_character_visuals(data: CharacterData) -> void:
	_sprite.texture = data.texture
	_sprite.offset = Vector2(0.0, -data.texture.get_height() * 0.5)
	if data.light_color.a > 0.0:
		_light.color = data.light_color
	if data.idle_style == CharacterData.IdleStyle.HOVER_FLICKER:
		Juice.hover(_visual)
		Juice.flicker(_sprite)
	if data.swing_texture != null:
		var size: Vector2 = data.texture.get_size()
		_swing = Sprite2D.new()
		_swing.texture = data.swing_texture
		_swing.centered = false
		_swing.material = _sprite.material
		_swing.position = Vector2(data.swing_pivot.x - size.x * 0.5, data.swing_pivot.y - size.y)
		_swing.offset = -data.swing_pivot
		_visual.add_child(_swing)


## Kurzes Aufleuchten von Figur und Licht, wenn ein Effekt auslöst (Stroboskop-Blitz).
func effect_flash() -> void:
	Juice.effect_flash(_sprite)
	var tween: Tween = _light.create_tween()
	tween.tween_property(_light, "energy", config.light_energy * EFFECT_LIGHT_BOOST, Juice.EFFECT_FLASH_TIME * 0.3)
	tween.tween_property(_light, "energy", config.light_energy, Juice.EFFECT_FLASH_TIME * 0.7)


## Flache Stat-Boni des Charakters gehen in die Basis: "X-Modifikationen" wirken nur auf spätere Zuwächse.
func _apply_character_effect(effect: ItemEffect) -> void:
	var stat_effect: StatEffect = effect as StatEffect
	if stat_effect == null:
		effect.apply(self)
		return
	for mod: StatModifier in stat_effect.modifiers:
		if mod.kind == StatModifier.Kind.FLAT:
			stats.add_base_value(mod.stat, mod.value)
		else:
			stats.add_modifier(mod)


func can_use_weapon(weapon: WeaponData) -> bool:
	return character == null or character.can_use_weapon(weapon)


## Summe der Klassen-Boni auf `stat` für eine Waffe mit diesen Klassen.
func class_bonus(stat: StringName, classes: Array[StringName]) -> float:
	var total: float = 0.0
	for bonus: ClassBonusEffect in class_bonuses:
		if bonus.stat == stat and bonus.weapon_class in classes:
			total += bonus.value
	return total


## Waffenabhängige Modifikatoren neu berechnen: Klassen-Set-Boni (GDD 8) und Effekte pro Waffe.
func update_weapon_modifiers() -> void:
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
	var weapon_count: int = weapon_slots.get_weapons().size()
	for effect: PerWeaponStatEffect in per_weapon_effects:
		new_mods.append(StatModifier.create(effect.stat, effect.value_per_weapon * weapon_count))
	stats.remove_modifiers(_set_modifiers)
	_set_modifiers = new_mods
	stats.add_modifiers(new_mods)


func get_set_modifiers() -> Array[StatModifier]:
	return _set_modifiers


func add_trigger(effect: ItemEffect) -> void:
	triggers.append(TriggerEntry.create(effect, _applying_origin))


## Heilt und gibt die tatsächlich geheilten HP zurück. Überschuss meldet `overhealed`.
func heal(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	var before: float = current_hp
	current_hp = minf(current_hp + amount, get_max_hp())
	var healed: float = current_hp - before
	GameState.run_stats.healed += healed
	hp_changed.emit(current_hp, get_max_hp())
	if amount > healed:
		overhealed.emit(amount - healed)
	return healed


## HP-Verlust ohne Ausweichen, Rüstung und Unverwundbarkeit (Vampirbirne); nie unter `min_hp`.
func drain_hp(amount: float, min_hp: float) -> void:
	if is_dead or current_hp <= min_hp:
		return
	current_hp = maxf(min_hp, current_hp - amount)
	hp_changed.emit(current_hp, get_max_hp())


func has_rule(rule: Rule) -> bool:
	return rules.get(rule, false)


## Von Waffen bei jedem Treffer aufgerufen. Gibt true zurück, wenn Lebensraub geheilt hat.
func try_lifesteal() -> bool:
	if not CombatMath.lifesteal_ready(_elapsed, _last_lifesteal_time, lifesteal_interval_factor):
		return false
	if rng.randf() >= CombatMath.lifesteal_chance(stats.get_stat(Stats.LIFESTEAL)):
		return false
	_last_lifesteal_time = _elapsed
	GameState.run_stats.lifesteal_healed += heal(1.0)
	return true


func _regenerate(delta: float) -> void:
	if has_rule(Rule.NO_REGEN):
		return
	var per_second: float = CombatMath.hp_regen_per_second(stats.get_stat(Stats.HP_REGEN))
	if per_second > 0.0 and current_hp < get_max_hp():
		heal(per_second * delta)


func _clamp_to_arena() -> void:
	if not arena_bounds.has_area():
		return
	var margin: Vector2 = Vector2.ONE * config.collision_radius
	global_position = global_position.clamp(arena_bounds.position + margin, arena_bounds.end - margin)


## Blitzlicht: Modifikatoren gelten nur, solange der Spieler stillsteht.
func _update_standing_still() -> void:
	if standing_still_modifiers.is_empty():
		return
	var still: bool = velocity.is_zero_approx()
	if still == _still_active:
		return
	_still_active = still
	if still:
		stats.add_modifiers(standing_still_modifiers)
	else:
		stats.remove_modifiers(standing_still_modifiers)


## Werte für Freischaltungen mitschreiben (höchster Schaden-%, Tempo-%, verschiedene Waffen, nur Primitiv).
func _track_run() -> void:
	var run: RunStats = GameState.run_stats
	run.max_damage_pct = maxf(run.max_damage_pct, stats.get_stat(Stats.DAMAGE_PCT))
	run.max_speed_pct = maxf(run.max_speed_pct, stats.get_stat(Stats.SPEED))
	run.max_elemental = maxf(run.max_elemental, stats.get_stat(Stats.ELEMENTAL_DMG))
	var ids: Dictionary[StringName, bool] = {}
	for weapon: Weapon in weapon_slots.get_weapons():
		ids[weapon.data.id] = true
		if WeaponClasses.PRIMITIVE not in weapon.data.classes:
			run.primitive_only = false
	run.max_distinct_weapons = maxi(run.max_distinct_weapons, ids.size())


## Aufgeben im Pausemenü: Run sofort als Niederlage beenden.
func kill() -> void:
	if not is_dead:
		_die()


func _die() -> void:
	is_dead = true
	current_hp = 0.0
	died.emit()
	Events.player_died.emit()
	weapon_slots.hide()
	Juice.squash_pop(_visual)


## Spiegelkugel-Freischaltung: höchste Zahl gleicher Waffen beim Ende einer Welle.
func _on_wave_ended(_wave_number: int) -> void:
	if is_dead:
		return
	var counts: Dictionary[StringName, int] = {}
	for weapon: Weapon in weapon_slots.get_weapons():
		counts[weapon.data.id] = counts.get(weapon.data.id, 0) + 1
	var run: RunStats = GameState.run_stats
	run.max_same_weapons = maxi(run.max_same_weapons, counts.values().max() if not counts.is_empty() else 0)


## Jedes Level-up gibt sofort Max HP; die Upgrade-Auswahl folgt am Wellenende.
func _on_level_up(_new_level: int) -> void:
	add_run_modifier(StatModifier.create(Stats.MAX_HP, config.max_hp_per_level))


## Steigt Max HP, steigen die aktuellen HP um denselben Betrag; sinkt es, werden sie nur gekappt.
func _on_stats_changed() -> void:
	var new_max: float = get_max_hp()
	if new_max > _known_max_hp:
		current_hp += new_max - _known_max_hp
	current_hp = minf(current_hp, new_max)
	_known_max_hp = new_max
	hp_changed.emit(current_hp, new_max)
	_track_run()
