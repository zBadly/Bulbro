class_name OrbitingDroneEffect
extends ItemEffect
## Drohnenleuchte: Drohnen kreisen um den Spieler und schießen auf das nächste Ziel (Werte aus einer StructureData,
## Schaden mit Technik wie Lampentürme). `base_count` Drohnen, +1 auf jedem Level aus `extra_at_levels`.

const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const STRUCTURE_SCENE: PackedScene = preload("res://scenes/structures/structure.tscn")
const DRONES_KEY: String = "drones"
const ANGLE_KEY: String = "angle"

@export var drone: StructureData
@export var base_count: int = 0
@export var extra_at_levels: Array[int] = []


func is_trigger() -> bool:
	return true


func drone_count(level: int) -> int:
	var count: int = base_count
	for threshold: int in extra_at_levels:
		if level >= threshold:
			count += 1
	return count


func on_wave_started(ctx: EffectContext, entry: TriggerEntry) -> void:
	super.on_wave_started(ctx, entry)
	_remove(entry)
	_sync(ctx, entry)


func on_wave_tick(ctx: EffectContext, entry: TriggerEntry, delta: float) -> void:
	var drones: Array = _sync(ctx, entry)
	var angle: float = float(entry.state.get(ANGLE_KEY, 0.0)) + deg_to_rad(STATUS.drone_orbit_speed_deg) * delta
	entry.state[ANGLE_KEY] = wrapf(angle, 0.0, TAU)
	var center: Vector2 = ctx.player.get_center()
	for i in drones.size():
		(drones[i] as Node2D).global_position = center + Vector2.from_angle(angle + TAU * i / drones.size()) * STATUS.drone_orbit_radius


func on_wave_ended(_ctx: EffectContext, entry: TriggerEntry) -> void:
	_remove(entry)


## Ergänzt fehlende Drohnen (z. B. nach einem Level-up während der Welle).
func _sync(ctx: EffectContext, entry: TriggerEntry) -> Array:
	var drones: Array = entry.state.get_or_add(DRONES_KEY, [])
	var wanted: int = drone_count(GameState.level)
	while drones.size() < wanted:
		var structure: Structure = STRUCTURE_SCENE.instantiate() as Structure
		structure.setup(drone, 1, ctx.player)
		structure.global_position = ctx.player.get_center()
		ctx.player.get_parent().add_child(structure)
		drones.append(structure)
	return drones


func _remove(entry: TriggerEntry) -> void:
	for structure: Variant in entry.state.get(DRONES_KEY, []):
		if is_instance_valid(structure):
			(structure as Node).queue_free()
	entry.state.erase(DRONES_KEY)


func describe() -> PackedStringArray:
	var levels: PackedStringArray = []
	for level: int in extra_at_levels:
		levels.append(str(level))
	return [TextFormat.t("EFFECT_DRONES") % [base_count, EffectAction.damage_text(drone.base_damage, drone.scalings), ", ".join(levels)]]
