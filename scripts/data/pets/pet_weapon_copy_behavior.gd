class_name PetWeaponCopyBehavior
extends PetBehavior
## Mini-Birne: trägt eine Kopie der aktuell ersten Waffe des Spielers mit `damage_factor` Schaden (wie das Spiegelbild:
## kein Lebensraub, keine Angriffs-Effekte). Ändern sich die Waffen, wird die Kopie neu gebaut.
## Schaden und Kills zählen für die Mini-Birne, nicht für die Waffe.

const SLOTS_KEY: String = "slots"
## Kennung der kopierten Waffe (ID und Tier), damit nur bei echten Änderungen neu gebaut wird.
const COPIED_KEY: String = "copied"

## Abstand der Waffe von der Körpermitte der Mini-Birne.
@export var weapon_offset: float = 0.0


func start(pet: Pet) -> void:
	super.start(pet)
	var slots: WeaponSlots = WeaponSlots.new()
	slots.player = pet.player
	slots.max_slots = 1
	slots.orbit_radius = weapon_offset
	slots.position = pet.get_center() - pet.global_position
	pet.add_child(slots)
	pet.state[SLOTS_KEY] = slots
	on_weapons_changed(pet)


func stop(pet: Pet) -> void:
	pet.state.erase(SLOTS_KEY)
	pet.state.erase(COPIED_KEY)


func on_weapons_changed(pet: Pet) -> void:
	var slots: WeaponSlots = pet.state.get(SLOTS_KEY) as WeaponSlots
	if slots == null:
		return
	var source: Weapon = copied_weapon(pet.player)
	var key: String = "%s/%d/%d" % [source.data.id, source.tier, pet.tier] if source != null else ""
	if key == String(pet.state.get(COPIED_KEY, "")) and slots.get_weapons().size() == (1 if source != null else 0):
		return
	pet.state[COPIED_KEY] = key
	for weapon: Weapon in slots.get_weapons():
		slots.remove_weapon(weapon)
	if source == null:
		return
	var copy: Weapon = slots.add_weapon(source.data, source.tier)
	copy.is_clone = true
	copy.damage_factor = pet.get_tier_stats().damage_factor
	copy.origin_override = pet.get_origin()


## Die aktuell erste Waffe des Spielers (null ohne Waffen).
static func copied_weapon(player: Player) -> Weapon:
	var weapons: Array[Weapon] = player.weapon_slots.get_weapons()
	return weapons[0] if not weapons.is_empty() else null


## Die Kopie in der Hand der Mini-Birne (null ohne Waffe).
static func copy_of(pet: Pet) -> Weapon:
	var slots: WeaponSlots = pet.state.get(SLOTS_KEY) as WeaponSlots
	if slots == null or slots.get_weapons().is_empty():
		return null
	return slots.get_weapons()[0]


func describe(stats: PetTierStats) -> PackedStringArray:
	return [TextFormat.t("PET_COPY_DESC") % roundi(stats.damage_factor * CombatMath.PERCENT)]


func status_lines(pet: Pet) -> PackedStringArray:
	var copy: Weapon = copy_of(pet)
	if copy == null:
		return [TextFormat.t("TIP_PET_COPY_NONE")]
	return [TextFormat.t("TIP_PET_COPY") % [TextFormat.t(copy.data.name_key), TextFormat.tier_name(copy.tier)],
		TooltipText.weapon_damage_line(copy)]
