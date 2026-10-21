extends GutTest
## Neue Systeme für Charaktere: Verlangsamen/Einfrieren/Festhalten, Zauberzyklus, Brand-Erweiterungen,
## Spiegelbild, Drohnen, Ranken und die Vampirbirnen-Effekte.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/enemies/training_dummy.tscn")
const WEAPON_SCENE: PackedScene = preload("res://scenes/weapons/weapon.tscn")
const STRUCTURE_SCENE: PackedScene = preload("res://scenes/structures/structure.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const GLASSCHERBE: WeaponData = preload("res://data/weapons/glasscherbe.tres")
const FUNKENPISTOLE: WeaponData = preload("res://data/weapons/funkenpistole.tres")
const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const COMBAT: CombatConfig = preload("res://data/config/combat_config.tres")

var _player: Player
var _system: EffectSystem
var _ctx: EffectContext


func before_each() -> void:
	GameState.start_run(41)
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_system = EffectSystem.new()
	add_child_autofree(_system)
	_system.player = _player
	_ctx = EffectContext.create(_player)


func _enemy(hp: float, at: Vector2, boss: bool = false) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	var data: EnemyData = SCHATTENLING.duplicate()
	data.base_hp = hp
	data.is_boss = boss
	enemy.setup(data)
	enemy.activate(1, at, _player, Rect2(), _player.rng)
	return enemy


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	add_child_autofree(dummy)
	dummy.global_position = at
	return dummy


func _entry(effect: ItemEffect) -> TriggerEntry:
	for entry: TriggerEntry in _player.triggers:
		if entry.effect == effect:
			return entry
	return null


# --- Verlangsamen, Einfrieren, Festhalten ---

func test_slow_keeps_the_stronger_effect() -> void:
	var slow: SlowStatus = SlowStatus.new()
	slow.apply(0.6, 2.0)
	assert_almost_eq(slow.speed_factor(), 0.6, 0.001)
	slow.apply(0.9, 5.0)
	assert_almost_eq(slow.speed_factor(), 0.6, 0.001, "schwächere Verlangsamung ersetzt nicht")
	slow.apply(0.0, 1.0)
	assert_true(slow.is_stopped())
	slow.tick(1.1)
	assert_false(slow.is_active())
	assert_eq(slow.speed_factor(), 1.0)


func test_bosses_hold_status_shorter() -> void:
	var normal: Enemy = _enemy(100.0, Vector2(400, 0))
	var boss: Enemy = _enemy(100.0, Vector2(500, 0), true)
	normal.freeze(1.0)
	boss.freeze(1.0)
	assert_almost_eq(normal.slow.time_left, 1.0, 0.001)
	assert_almost_eq(boss.slow.time_left, 1.0 * STATUS.boss_status_factor, 0.001)


func test_frozen_enemy_deals_no_contact_damage() -> void:
	var enemy: Enemy = _enemy(100.0, Vector2.ZERO)
	enemy.freeze(1.0)
	var hp: float = _player.current_hp
	await wait_physics_frames(5)
	assert_eq(_player.current_hp, hp, "eingefroren: kein Kontaktschaden")
	enemy.slow.clear()
	await wait_physics_frames(5)
	assert_lt(_player.current_hp, hp, "aufgetaut: Kontaktschaden wieder aktiv")


func test_root_has_immunity_afterwards() -> void:
	var enemy: Enemy = _enemy(100.0, Vector2(400, 0))
	enemy.set_physics_process(false)
	assert_true(enemy.root(1.5))
	assert_true(enemy.is_stopped())
	enemy.call("_update_statuses", 1.6)
	assert_false(enemy.is_stopped())
	assert_false(enemy.root(1.5), "Schutzzeit nach dem Festhalten")
	enemy.call("_update_statuses", STATUS.root_immunity_time)
	assert_true(enemy.root(1.5))


func test_root_structure_holds_enemies_in_radius() -> void:
	var near: Enemy = _enemy(100.0, Vector2(30, 0))
	var far: Enemy = _enemy(100.0, Vector2(600, 0))
	near.set_physics_process(false)
	far.set_physics_process(false)
	var structure: Structure = STRUCTURE_SCENE.instantiate() as Structure
	structure.setup(load("res://data/structures/lichtranke.tres"), 1, _player)
	add_child_autofree(structure)
	await wait_physics_frames(3)
	assert_true(near.is_stopped())
	assert_false(far.is_stopped())


func test_freeze_action_only_hits_visible_enemies() -> void:
	var visible: Enemy = _enemy(100.0, Vector2(200, 200))
	var hidden: Enemy = _enemy(100.0, Vector2(9000, 9000))
	var action: FreezeEnemiesAction = FreezeEnemiesAction.new()
	action.duration = 1.0
	action.execute(_ctx, Vector2.ZERO)
	assert_true(visible.is_stopped())
	assert_false(hidden.is_stopped())


func test_frost_nova_slows_in_radius() -> void:
	var near: Enemy = _enemy(100.0, Vector2(50, 0))
	var far: Enemy = _enemy(100.0, Vector2(500, 0))
	var nova: FrostNovaAction = FrostNovaAction.new()
	nova.radius = 120.0
	nova.slow_pct = 40.0
	nova.duration = 2.0
	nova.execute(_ctx, Vector2(50, -near.hit_height))
	assert_almost_eq(near.slow.speed_factor(), 0.6, 0.001)
	assert_eq(far.slow.speed_factor(), 1.0)


# --- Zauberzyklus ---

func test_spell_cycle_casts_every_nth_attack_per_weapon() -> void:
	var dummy: TrainingDummy = _dummy(Vector2(300, 0))
	var spell: DamageRandomEnemiesAction = DamageRandomEnemiesAction.new()
	spell.count = 1
	spell.base_damage = 10.0
	var effect: SpellCycleEffect = SpellCycleEffect.new()
	effect.every_nth = 4
	effect.spells = [spell]
	effect.apply(_player)
	var a: Weapon = WEAPON_SCENE.instantiate()
	var b: Weapon = WEAPON_SCENE.instantiate()
	add_child_autofree(a)
	add_child_autofree(b)
	for i in 3:
		effect.on_weapon_attack(_ctx, _entry(effect), a, dummy)
		effect.on_weapon_attack(_ctx, _entry(effect), b, dummy)
	assert_eq(dummy.total_damage, 0, "je Waffe erst 3 Angriffe")
	effect.on_weapon_attack(_ctx, _entry(effect), a, dummy)
	assert_eq(dummy.total_damage, 10, "4. Angriff von Waffe A")
	effect.on_weapon_attack(_ctx, _entry(effect), b, dummy)
	assert_eq(dummy.total_damage, 20)


func test_weapon_attack_reaches_effects_but_clones_do_not() -> void:
	_dummy(Vector2(150, 0))
	var counter: Array[int] = [0]
	_player.weapon_attacked.connect(func(_w: Weapon, _t: Damageable) -> void: counter[0] += 1)
	var weapon: Weapon = _player.weapon_slots.add_weapon(FUNKENPISTOLE)
	await wait_seconds(0.3)
	assert_gt(counter[0], 0)
	counter[0] = 0
	weapon.is_clone = true
	await wait_seconds(1.5)
	assert_eq(counter[0], 0)


# --- Brand ---

func test_burn_on_hit_uses_burn_damage_stat() -> void:
	var effect: BurnOnHitEffect = BurnOnHitEffect.new()
	effect.chance = 1.0
	effect.base_damage = 4.0
	effect.ticks = 3
	effect.apply(_player)
	_player.stats.add_modifier(StatModifier.create(Stats.BURN_DMG_PCT, 50.0))
	var enemy: Enemy = _enemy(1000.0, Vector2(400, 0))
	Hits.apply_weapon_hit(enemy, DamageInfo.create(1, false, 0.0, null), _player, false)
	assert_true(enemy.is_burning())
	assert_almost_eq(float(enemy.get("_burn_damage")), 6.0, 0.001, "4 x 1,5")


func test_weapon_burn_also_scales() -> void:
	_player.stats.add_modifier(StatModifier.create(Stats.BURN_DMG_PCT, 50.0))
	var enemy: Enemy = _enemy(1000.0, Vector2(400, 0))
	var info: DamageInfo = DamageInfo.create(1, false, 0.0, null)
	info.burn_damage = 2.0
	info.burn_ticks = 3
	Hits.apply_weapon_hit(enemy, info, _player, false)
	assert_almost_eq(float(enemy.get("_burn_damage")), 3.0, 0.001)


func test_burn_kills_are_counted() -> void:
	var enemy: Enemy = _enemy(1.0, Vector2(400, 0))
	enemy.set_physics_process(false)
	enemy.apply_burn(5.0, 2, _player)
	enemy.call("_update_burn", COMBAT.burn_interval)
	assert_false(enemy.is_alive())
	assert_eq(GameState.run_stats.burn_kills, 1)


func test_burning_death_triggers_explosion_effect() -> void:
	var dummy: TrainingDummy = _dummy(Vector2(420, 36))
	var explosion: ExplosionAction = ExplosionAction.new()
	explosion.radius = 80.0
	explosion.base_damage = 7.0
	var effect: OnKillEffect = OnKillEffect.new()
	effect.chance = 1.0
	effect.only_burning = true
	effect.action = explosion
	effect.apply(_player)
	var cold: Enemy = _enemy(1.0, Vector2(400, 0))
	cold.take_damage(DamageInfo.create(5, false, 0.0, null))
	await wait_physics_frames(2)
	assert_eq(dummy.total_damage, 0, "nicht brennend gestorben")
	var burning: Enemy = _enemy(1.0, Vector2(400, 0))
	burning.apply_burn(1.0, 5, _player)
	burning.take_damage(DamageInfo.create(5, false, 0.0, null))
	await wait_physics_frames(2)
	assert_eq(dummy.total_damage, 7)


# --- Spiegelbild und Drohnen ---

func test_mirror_clone_copies_weapons_with_reduced_damage() -> void:
	for i in 6:
		_player.weapon_slots.add_weapon(GLASSCHERBE)
	var effect: MirrorCloneEffect = MirrorCloneEffect.new()
	effect.damage_factor = 0.4
	effect.apply(_player)
	effect.on_wave_started(_ctx, _entry(effect))
	var clone: MirrorClone = _entry(effect).state[MirrorCloneEffect.CLONE_KEY]
	var copies: Array[Weapon] = clone.weapon_slots.get_weapons()
	assert_eq(copies.size(), 6)
	assert_true(copies[0].is_clone)
	_player.rules[Player.Rule.NO_CRIT] = true
	var original: DamageInfo = _player.weapon_slots.get_weapons()[0].call("_roll_damage")
	var copy: DamageInfo = copies[0].call("_roll_damage")
	assert_eq(copy.amount, maxi(1, roundi(original.amount * 0.4)))
	effect.on_wave_ended(_ctx, _entry(effect))
	await wait_physics_frames(1)
	assert_false(is_instance_valid(clone), "am Wellenende entfernt")


func test_drone_count_grows_with_levels() -> void:
	var effect: OrbitingDroneEffect = OrbitingDroneEffect.new()
	effect.drone = load("res://data/structures/drohne.tres")
	effect.base_count = 2
	effect.extra_at_levels = [5, 10, 15]
	assert_eq(effect.drone_count(1), 2)
	assert_eq(effect.drone_count(5), 3)
	assert_eq(effect.drone_count(15), 5)
	effect.apply(_player)
	effect.on_wave_started(_ctx, _entry(effect))
	var drones: Array = _entry(effect).state[OrbitingDroneEffect.DRONES_KEY]
	assert_eq(drones.size(), 2)
	GameState.level = 5
	effect.on_wave_tick(_ctx, _entry(effect), 0.1)
	assert_eq(drones.size(), 3, "Level-up während der Welle: sofort eine Drohne mehr")
	var distance: float = (drones[0] as Node2D).global_position.distance_to(_player.get_center())
	assert_almost_eq(distance, STATUS.drone_orbit_radius, 0.5)
	effect.on_wave_ended(_ctx, _entry(effect))
	assert_false(_entry(effect).state.has(OrbitingDroneEffect.DRONES_KEY))


func test_build_structure_action_requests_structure() -> void:
	var received: Array = []
	var callback: Callable = func(data: StructureData, tier: int, at: Vector2) -> void: received.append([data, tier, at])
	Events.structure_requested.connect(callback)
	var action: BuildStructureAction = BuildStructureAction.new()
	action.structure = load("res://data/structures/lichtranke.tres")
	action.distance = 100.0
	action.execute(_ctx, Vector2.ZERO)
	Events.structure_requested.disconnect(callback)
	assert_eq(received.size(), 1)
	assert_eq(received[0][0], action.structure)
	assert_lte((received[0][2] as Vector2).distance_to(_player.global_position), 100.01)


# --- Vampirbirne, Fluchwirker ---

func test_overheal_becomes_damage() -> void:
	var dummy: TrainingDummy = _dummy(Vector2(300, 0))
	var effect: OverhealDamageEffect = OverhealDamageEffect.new()
	effect.apply(_player)
	_player.take_hit(1.0)
	_player.heal(3.0)
	assert_eq(dummy.total_damage, 2, "1 HP geheilt, 2 HP Überschuss")


func test_lifesteal_cap_and_tracking() -> void:
	assert_false(CombatMath.lifesteal_ready(0.06, 0.0))
	assert_true(CombatMath.lifesteal_ready(0.06, 0.0, 0.5), "doppeltes Limit")
	var effect: LifestealCapEffect = LifestealCapEffect.new()
	effect.interval_factor = 0.5
	effect.apply(_player)
	assert_almost_eq(_player.lifesteal_interval_factor, 0.5, 0.001)
	_player.stats.add_modifier(StatModifier.create(Stats.LIFESTEAL, 100.0))
	_player.take_hit(3.0)
	_player.try_lifesteal()
	assert_eq(GameState.run_stats.lifesteal_healed, 1.0)


func test_hp_drain_never_kills() -> void:
	var effect: HpDrainEffect = HpDrainEffect.new()
	effect.amount = 1.0
	effect.interval = 2.0
	effect.min_hp = 1.0
	effect.apply(_player)
	var start: float = _player.current_hp
	effect.on_wave_tick(_ctx, _entry(effect), 4.0)
	assert_eq(_player.current_hp, start - 2.0)
	effect.on_wave_tick(_ctx, _entry(effect), 100.0)
	assert_eq(_player.current_hp, 1.0)
	assert_false(_player.is_dead)


func test_rules_disable_regen_and_crits() -> void:
	var no_regen: PlayerRuleEffect = PlayerRuleEffect.new()
	no_regen.rule = Player.Rule.NO_REGEN
	no_regen.apply(_player)
	_player.stats.add_modifier(StatModifier.create(Stats.HP_REGEN, 20.0))
	_player.take_hit(3.0)
	var hp: float = _player.current_hp
	_player.call("_regenerate", 1.0)
	assert_eq(_player.current_hp, hp)
	var no_crit: PlayerRuleEffect = PlayerRuleEffect.new()
	no_crit.rule = Player.Rule.NO_CRIT
	no_crit.apply(_player)
	_player.stats.add_modifier(StatModifier.create(Stats.CRIT_CHANCE, 100.0))
	var weapon: Weapon = _player.weapon_slots.add_weapon(GLASSCHERBE)
	for i in 10:
		assert_false((weapon.call("_roll_damage") as DamageInfo).is_crit)


func test_new_effects_describe_without_missing_keys() -> void:
	var drone: OrbitingDroneEffect = OrbitingDroneEffect.new()
	drone.drone = load("res://data/structures/drohne.tres")
	drone.extra_at_levels = [5, 10]
	var build: BuildStructureAction = BuildStructureAction.new()
	build.structure = load("res://data/structures/lichtranke.tres")
	var timed: TimedSpawnEffect = TimedSpawnEffect.new()
	timed.action = build
	var cycle: SpellCycleEffect = SpellCycleEffect.new()
	cycle.spells = [ExplosionAction.new(), FrostNovaAction.new(), ChainLightningAction.new()]
	var freeze: TimedSpawnEffect = TimedSpawnEffect.new()
	freeze.action = FreezeEnemiesAction.new()
	var burning: OnKillEffect = OnKillEffect.new()
	burning.only_burning = true
	burning.action = ExplosionAction.new()
	var rule: PlayerRuleEffect = PlayerRuleEffect.new()
	rule.rule = Player.Rule.NO_CRIT
	var effects: Array[ItemEffect] = [ReanimateEffect.new(), CurseOnHitEffect.new(), BurnOnHitEffect.new(), cycle,
		freeze, timed, MirrorCloneEffect.new(), drone, LifestealCapEffect.new(), HpDrainEffect.new(),
		OverhealDamageEffect.new(), rule, burning]
	for effect: ItemEffect in effects:
		var lines: PackedStringArray = effect.describe()
		assert_eq(lines.size(), 1, effect.get_script().get_global_name())
		assert_false(lines[0].contains("EFFECT_") or lines[0].contains("ACTION_") or lines[0].contains("RULE_"), lines[0])
