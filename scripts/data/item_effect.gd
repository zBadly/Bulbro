class_name ItemEffect
extends Resource
## Baustein eines Items oder Charakters (GDD 13: Effektsystem statt Spezialcode pro Item).
## Passive Effekte ändern beim Anwenden Stats; Trigger-Effekte werden beim Spieler registriert und
## vom EffectSystem bei Ereignissen aufgerufen. Zustand pro Exemplar liegt im TriggerEntry, nie in der Resource.


## Wendet den Effekt dauerhaft auf den Spieler an. Trigger-Effekte registrieren sich standardmäßig.
func apply(player: Player) -> void:
	if is_trigger():
		player.add_trigger(self)


## Stat-Modifikatoren, die der Effekt bewirkt (für Beschreibung und Vorher/Nachher-Vorschau).
func get_modifiers() -> Array[StatModifier]:
	return []


## Zusätzliche Beschreibungszeilen (BBCode) für Effekte, die keine reinen Stats sind.
func describe() -> PackedStringArray:
	return []


func is_trigger() -> bool:
	return false


func on_enemy_killed(_ctx: EffectContext, _entry: TriggerEntry, _position: Vector2, _data: EnemyData, _info: DamageInfo) -> void:
	pass


func on_hit_taken(_ctx: EffectContext, _entry: TriggerEntry) -> void:
	pass


func on_spark_collected(_ctx: EffectContext, _entry: TriggerEntry) -> void:
	pass


func on_wave_started(_ctx: EffectContext, entry: TriggerEntry) -> void:
	entry.timer = 0.0


func on_wave_tick(_ctx: EffectContext, _entry: TriggerEntry, _delta: float) -> void:
	pass


## Am Wellenende: erzeugte Knoten (Drohnen, Spiegelbild, Verbündete) aufräumen.
func on_wave_ended(_ctx: EffectContext, _entry: TriggerEntry) -> void:
	pass


## Eine Waffe des Spielers greift an (vor dem Treffer).
func on_weapon_attack(_ctx: EffectContext, _entry: TriggerEntry, _weapon: Weapon, _target: Damageable) -> void:
	pass


## Ein Waffen- oder Strukturtreffer hat ein Ziel getroffen.
func on_enemy_hit(_ctx: EffectContext, _entry: TriggerEntry, _target: Damageable, _info: DamageInfo) -> void:
	pass


func on_burning_enemy_killed(_ctx: EffectContext, _entry: TriggerEntry, _position: Vector2) -> void:
	pass


## Heilung über Max HP hinaus (`amount` = überschüssige HP).
func on_overheal(_ctx: EffectContext, _entry: TriggerEntry, _amount: float) -> void:
	pass
