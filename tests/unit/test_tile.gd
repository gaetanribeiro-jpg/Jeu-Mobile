extends GutTest

## Les tuiles ne portent aucune valeur chiffrée : elles interrogent
## data/combat/terrain.json. Ces tests vérifient d'abord que le lien tient,
## ensuite que les effets tactiques du § 4.3 sont bien ceux-là.


func before_each() -> void:
	CombatRules.reload()


func test_l_herbe_est_neutre() -> void:
	var tile := Tile.new(Vector2i(0, 0), &"grass")
	assert_true(tile.is_walkable())
	assert_false(tile.is_lethal())
	assert_false(tile.blocks_sight())
	assert_eq(tile.damage_taken_modifier(), 0)


func test_l_eau_est_infranchissable_et_mortelle() -> void:
	var tile := Tile.new(Vector2i(0, 0), &"water")
	assert_false(tile.is_walkable(), "un héros n'entre pas dans l'eau")
	assert_true(tile.is_lethal(), "y être poussé tue")
	assert_true(tile.is_swimmable(), "les unités aquatiques y circulent")
	assert_false(tile.blocks_sight(), "on tire par-dessus l'eau")


func test_la_foret_protege_et_bloque_la_vue() -> void:
	var tile := Tile.new(Vector2i(0, 0), &"forest")
	assert_true(tile.is_walkable())
	assert_true(tile.blocks_sight())
	assert_eq(tile.damage_taken_modifier(), -1, "−1 dégât subi")


func test_la_colline_donne_portee_et_degats() -> void:
	var tile := Tile.new(Vector2i(0, 0), &"hill")
	assert_eq(tile.ranged_range_bonus(), 1)
	assert_eq(tile.ranged_damage_bonus(), 1)


func test_le_rocher_bloque_tout() -> void:
	var tile := Tile.new(Vector2i(0, 0), &"rock")
	assert_false(tile.is_walkable())
	assert_true(tile.blocks_sight())
	assert_false(tile.is_lethal(), "un rocher arrête, il ne tue pas")


func test_la_ruine_expose() -> void:
	assert_eq(Tile.new(Vector2i(0, 0), &"ruin").damage_taken_modifier(), 1)


func test_le_pont_cede_et_devient_de_l_eau() -> void:
	var tile := Tile.new(Vector2i(0, 0), &"bridge")
	assert_true(tile.is_destructible())
	# Les PV du pont sont une donnée : un test qui les recopie casse au
	# premier réglage d'équilibrage, sans rien avoir attrapé.
	var total := int(CombatRules.terrain_property(&"bridge", &"hit_points", 0))
	assert_eq(tile.structure_hp, total)
	assert_gt(total, 1, "un pont doit encaisser plus d'un coup")
	assert_true(tile.is_walkable())

	assert_false(tile.damage_structure(total - 1), "il en reste un point")
	assert_eq(tile.structure_hp, 1)
	assert_true(tile.is_walkable(), "le pont tient encore")

	assert_true(tile.damage_structure(1), "le second dégât le fait céder")
	assert_eq(tile.terrain_id, &"water")
	assert_false(tile.is_walkable())
	assert_true(tile.is_lethal(), "le pont détruit devient un piège")


func test_un_decor_indestructible_ignore_les_degats() -> void:
	var tile := Tile.new(Vector2i(0, 0), &"rock")
	assert_false(tile.damage_structure(99))
	assert_eq(tile.terrain_id, &"rock")


func test_l_occupation() -> void:
	var tile := Tile.new(Vector2i(2, 3), &"grass")
	assert_false(tile.is_occupied())
	assert_eq(tile.occupant_id, Tile.NO_OCCUPANT)
	tile.occupant_id = 7
	assert_true(tile.is_occupied())
	tile.clear_occupant()
	assert_false(tile.is_occupied())


func test_un_terrain_inconnu_ne_plante_pas() -> void:
	var tile := Tile.new(Vector2i(0, 0), &"lave")
	assert_false(tile.is_walkable(), "par défaut, on ne marche pas sur l'inconnu")
	# Chaque interrogation d'un terrain inconnu doit se plaindre nommément :
	# une carte mal écrite doit se lire dans la console, pas se deviner.
	var errors := get_errors()
	assert_gt(errors.size(), 0, "un terrain inconnu doit produire une erreur")
	for error: GutTrackedError in errors:
		assert_true(error.contains_text("terrain inconnu"), "erreur inattendue : %s" % error.to_s())
		error.handled = true


func test_tous_les_terrains_declares_sont_complets() -> void:
	# Un terrain à qui il manque une propriété passerait silencieusement
	# sur la valeur par défaut, et le bug serait invisible en jeu.
	var required := [
		"walkable", "swimmable", "lethal", "blocks_sight",
		"move_cost", "damage_taken", "ranged_range_bonus", "ranged_damage_bonus",
	]
	var ids := CombatRules.terrain_ids()
	assert_gt(ids.size(), 0, "terrain.json doit déclarer des terrains")
	for id: StringName in ids:
		var block := CombatRules.terrain_type(id)
		for key: String in required:
			assert_true(block.has(key), "le terrain « %s » n'a pas « %s »" % [id, key])


func test_aller_retour_de_serialisation() -> void:
	var tile := Tile.new(Vector2i(4, 2), &"bridge")
	tile.occupant_id = 3
	tile.damage_structure(
		int(CombatRules.terrain_property(&"bridge", &"hit_points", 0)) - 1
	)
	var restored := Tile.from_dictionary(tile.to_dictionary())
	assert_eq(restored.cell, Vector2i(4, 2))
	assert_eq(restored.terrain_id, &"bridge")
	assert_eq(restored.occupant_id, 3)
	assert_eq(restored.structure_hp, 1, "les points de vie du pont survivent")
