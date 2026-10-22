class_name Hits
extends RefCounted
## Zielauswahl und Flächenschaden für Waffen und Effekte.

const PERCENT: float = 100.0
const EXPLOSION_TRAUMA: float = 0.15


## Liste der Gruppe pro Physik-Frame zwischengespeichert (Heiler, Verstärker, Zielsuche fragen sehr oft).
## Betritt oder verlässt ein Ziel den Baum, wird sie sofort ungültig (invalidate_targets).
static var _cache_frame: int = -1
static var _cache_nodes: Array[Node] = []


static func invalidate_targets() -> void:
	_cache_frame = -1


## Alle lebenden Ziele. Neutrale Objekte (Leuchtkristalle) nur auf Wunsch.
static func alive_targets(tree: SceneTree, include_neutral: bool = false) -> Array[Damageable]:
	var frame: int = Engine.get_physics_frames()
	if frame != _cache_frame:
		_cache_frame = frame
		_cache_nodes = tree.get_nodes_in_group(Damageable.GROUP)
	var result: Array[Damageable] = []
	for node: Node in _cache_nodes:
		if not is_instance_valid(node):
			continue
		var target: Damageable = node as Damageable
		if target != null and target.is_alive() and (include_neutral or not target.is_neutral()):
			result.append(target)
	return result


static func random_enemies(tree: SceneTree, count: int, rng: RandomNumberGenerator) -> Array[Damageable]:
	var pool: Array[Damageable] = alive_targets(tree)
	var result: Array[Damageable] = []
	while result.size() < count and not pool.is_empty():
		result.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return result


## Nächstes lebendes Ziel innerhalb von `max_range`, das nicht in `exclude` (Instanz-IDs) steht.
static func nearest_target(tree: SceneTree, origin: Vector2, max_range: float, exclude: Dictionary[int, bool]) -> Damageable:
	var best: Damageable = null
	var best_dist: float = max_range * max_range
	for target: Damageable in alive_targets(tree, true):
		if exclude.has(target.get_instance_id()):
			continue
		var dist: float = origin.distance_squared_to(target.get_hit_position())
		if dist < best_dist:
			best = target
			best_dist = dist
	return best


## Ein Waffentreffer mit allen Zusatzwirkungen: Schaden, Brand, Lebensraub, Heilchance, Treffer-Effekte.
static func apply_weapon_hit(target: Damageable, info: DamageInfo, player: Player, lifesteal: bool = true) -> void:
	_damage(target, info, player)
	if player == null:
		if info.burn_damage > 0.0 and target is Enemy:
			(target as Enemy).apply_burn(info.burn_damage, info.burn_ticks, null, info.origin)
		return
	var enemy: Enemy = target as Enemy
	if enemy != null and info.burn_damage > 0.0 and (info.burn_chance >= 1.0 or player.rng.randf() < info.burn_chance):
		var burn: float = CombatMath.burn_damage(info.burn_damage, player.stats.get_stat(Stats.BURN_DMG_PCT))
		enemy.apply_burn(burn, info.burn_ticks, player, info.origin)
	if enemy != null and info.root_chance > 0.0 and player.rng.randf() < info.root_chance:
		enemy.root(info.root_duration)
	player.enemy_hit.emit(target, info)
	if lifesteal:
		player.try_lifesteal()
	if info.heal_on_hit_chance > 0.0 and player.rng.randf() < info.heal_on_hit_chance:
		player.heal(1.0)


## Explosion: Radius und Schaden wachsen mit Explosionsgröße/-schaden des Spielers. Trifft alle Ziele im Radius.
static func explode(tree: SceneTree, player: Player, origin: Vector2, radius: float, info: DamageInfo) -> void:
	var size: float = radius
	var amount: int = info.amount
	if player != null:
		size *= maxf(0.0, 1.0 + player.stats.get_stat(Stats.EXPLOSION_SIZE_PCT) / PERCENT)
		amount = maxi(CombatMath.MIN_DAMAGE, roundi(amount * maxf(0.0, 1.0 + player.stats.get_stat(Stats.EXPLOSION_DMG_PCT) / PERCENT)))
	Fx.explosion(tree, origin, size)
	Fx.particles(tree, ParticleFx.Kind.EXPLOSION, origin)
	Fx.shake(tree, EXPLOSION_TRAUMA)
	AudioManager.play(&"explosion")
	var blast: DamageInfo = DamageInfo.create(amount, info.is_crit, info.knockback, info.source, info.origin)
	for target: Damageable in alive_targets(tree, true):
		var hit_pos: Vector2 = target.get_hit_position()
		if origin.distance_to(hit_pos) <= size:
			blast.knockback_dir = origin.direction_to(hit_pos)
			_damage(target, blast, player)


## Schaden mit Boss-Schaden-Stat gegen Elites und Bosse. Der Treffer wird danach unverändert weiterverwendet.
static func _damage(target: Damageable, info: DamageInfo, player: Player) -> void:
	var enemy: Enemy = target as Enemy
	if player == null or enemy == null or enemy.data == null or not (enemy.data.is_elite or enemy.data.is_boss):
		target.take_damage(info)
		return
	var original: int = info.amount
	info.amount = CombatMath.percent_damage(original, player.stats.get_stat(Stats.BOSS_DMG_PCT))
	target.take_damage(info)
	info.amount = original
