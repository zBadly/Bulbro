extends GutTest
## Paket 4: Porträts, Darstellung der Charaktere und Status-Grafiken auf Gegnern.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const SCHATTENLING: EnemyData = preload("res://data/enemies/schattenling.tres")
const STATUS: StatusConfig = preload("res://data/config/status_config.tres")
const NEW_CHARACTERS: Array[StringName] = [&"irrlicht", &"zuendkerze", &"kronleuchter", &"schwarzlicht",
	&"gewaechshauslampe", &"smartbulb", &"drohnenleuchte", &"stroboskop", &"vampirbirne", &"spiegelkugel"]

var _player: Player


func before_each() -> void:
	GameState.start_run(7)
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func _enemy() -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child_autofree(enemy)
	enemy.setup(SCHATTENLING)
	enemy.activate(1, Vector2.ZERO, _player, Rect2(), _player.rng)
	return enemy


func _overlays(enemy: Enemy) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for child: Node in enemy.visual.get_children():
		if child is Sprite2D and child.name != &"Sprite":
			result.append(child)
	return result


func _tint(enemy: Enemy) -> Color:
	var mat: ShaderMaterial = enemy.visual.get_node("Sprite").material
	return mat.get_shader_parameter(Enemy.TINT_PARAM)


func test_every_character_has_a_square_portrait() -> void:
	for character: CharacterData in Unlocks.all_characters():
		assert_not_null(character.portrait, String(character.id))
		var portrait: Texture2D = character.get_portrait()
		assert_eq(portrait.get_width(), portrait.get_height(), String(character.id))


func test_new_characters_have_own_art_and_light() -> void:
	var textures: Dictionary[Texture2D, bool] = {}
	for id: StringName in NEW_CHARACTERS:
		var character: CharacterData = load("res://data/characters/%s.tres" % id)
		assert_false(textures.has(character.texture), "eigenes Sprite: %s" % id)
		textures[character.texture] = true
		assert_gt(character.light_color.a, 0.0, "eigene Lichtfarbe: %s" % id)


func test_character_light_and_swing_part_are_applied() -> void:
	var kronleuchter: CharacterData = load("res://data/characters/kronleuchter.tres")
	_player.apply_character(kronleuchter)
	assert_eq((_player.get_node("Light") as PointLight2D).color, kronleuchter.light_color)
	var swing_found: bool = false
	for child: Node in _player.get_node("Visual").get_children():
		if child is Sprite2D and (child as Sprite2D).texture == kronleuchter.swing_texture:
			swing_found = true
	assert_true(swing_found)


func test_frozen_enemy_shows_ice_and_frost_tint() -> void:
	var enemy: Enemy = _enemy()
	enemy.freeze(1.0)
	var visible: Array[Sprite2D] = _overlays(enemy).filter(func(s: Sprite2D) -> bool: return s.visible)
	assert_eq(visible.size(), 1)
	assert_eq(visible[0].texture, Enemy.ICE_TEXTURE)
	assert_eq(_tint(enemy), STATUS.frost_tint)


func test_rooted_enemy_shows_vines_without_frost_tint() -> void:
	var enemy: Enemy = _enemy()
	assert_true(enemy.root(1.0))
	assert_true(enemy.is_rooted())
	var visible: Array[Sprite2D] = _overlays(enemy).filter(func(s: Sprite2D) -> bool: return s.visible)
	assert_eq(visible.size(), 1)
	assert_eq(visible[0].texture, Enemy.ROOT_TEXTURE)
	assert_ne(_tint(enemy), STATUS.frost_tint)
	enemy.call("_update_statuses", 1.1)
	assert_false(enemy.is_rooted())
	assert_eq(_overlays(enemy).filter(func(s: Sprite2D) -> bool: return s.visible).size(), 0)


func test_burning_enemy_shows_flames_until_burn_ends() -> void:
	var enemy: Enemy = _enemy()
	enemy.apply_burn(1.0, 1, null)
	var flames: Array[Sprite2D] = _overlays(enemy).filter(func(s: Sprite2D) -> bool: return s.texture == Enemy.BURN_TEXTURE)
	assert_eq(flames.size(), 1)
	assert_true(flames[0].visible)
	enemy.despawn()
	assert_false(flames[0].visible)


func test_curse_marker_shows_stacks() -> void:
	var enemy: Enemy = _enemy()
	var marker: CurseMarker = null
	for child: Node in enemy.visual.get_children():
		if child is CurseMarker:
			marker = child
	assert_not_null(marker)
	assert_false(marker.visible)
	enemy.apply_curse(1.0, 10.0, 4.0, 3)
	assert_true(marker.visible)
	enemy.despawn()
	assert_false(marker.visible)
