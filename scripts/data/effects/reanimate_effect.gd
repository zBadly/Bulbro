class_name ReanimateEffect
extends ItemEffect
## Irrlicht: Kills füllen das Seelenglas (GameState.souls, wird nicht verbraucht). Alle `interval` Sekunden ab
## `min_souls` kehrt der zuletzt getötete Gegnertyp als Schattengeist (Ally) zurück. Mehr Seelen = mehr Geisterschaden.

const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const ALLIES_KEY: String = "allies"

@export var interval: float = 0.0
@export var min_souls: int = 0
@export var max_souls: int = 0
@export var souls_per_kill: int = 1
@export var lifetime: float = 0.0
@export var max_allies: int = 0
@export var base_damage: float = 0.0
@export var scalings: Dictionary[StringName, float] = {}
## +`bonus_per_step` Schaden pro volle `souls_per_step` Seelen.
@export var souls_per_step: int = 0
@export var bonus_per_step: float = 0.0


func apply(player: Player) -> void:
	GameState.souls.max_souls = max_souls
	super.apply(player)


func is_trigger() -> bool:
	return true


func on_enemy_killed(_ctx: EffectContext, _entry: TriggerEntry, position: Vector2, data: EnemyData, info: DamageInfo) -> void:
	var extra: int = info.extra_souls if info != null else 0
	GameState.souls.add(souls_per_kill + extra, data, position)


func on_wave_tick(ctx: EffectContext, entry: TriggerEntry, delta: float) -> void:
	entry.timer += delta
	if entry.timer < interval:
		return
	if summon(ctx, entry):
		entry.timer -= interval
	else:
		entry.timer = interval


func on_wave_ended(_ctx: EffectContext, entry: TriggerEntry) -> void:
	for ally: Ally in active_allies(entry):
		ally.dismiss()
	entry.state.erase(ALLIES_KEY)


## Erzeugt einen Schattengeist, wenn Seelen, eigenes und globales Limit es erlauben.
func summon(ctx: EffectContext, entry: TriggerEntry) -> bool:
	var souls: SoulCounter = GameState.souls
	if not souls.can_summon(min_souls):
		return false
	var allies: Array[Ally] = active_allies(entry)
	if allies.size() >= max_allies or Ally.active_count(ctx.tree) >= STATUS.ally_global_max:
		return false
	var pool: ObjectPool = Pools.get_pool(ctx.tree, Pools.ALLIES)
	if pool == null:
		return false
	var ally: Ally = pool.acquire() as Ally
	var damage: int = ctx.effect_damage(base_damage + souls.bonus_damage(souls_per_step, bonus_per_step), scalings)
	ally.summon(souls.last_type, souls.last_position, damage, lifetime, ctx.player.arena_bounds)
	allies.append(ally)
	entry.state[ALLIES_KEY] = allies
	return true


## Noch lebende Geister dieses Effekts.
func active_allies(entry: TriggerEntry) -> Array[Ally]:
	var result: Array[Ally] = []
	var stored: Array = entry.state.get(ALLIES_KEY, [])
	for ally: Variant in stored:
		if is_instance_valid(ally) and (ally as Ally).is_active():
			result.append(ally)
	return result


func describe() -> PackedStringArray:
	return [TextFormat.t("EFFECT_REANIMATE") % [max_souls, TextFormat.number(interval), min_souls, TextFormat.number(lifetime),
		EffectAction.damage_text(base_damage, scalings), max_allies, TextFormat.number(bonus_per_step), souls_per_step]]
