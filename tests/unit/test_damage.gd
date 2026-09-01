extends GutTest

## T1.7 — la formule de dégâts.
##
## Un seul calcul, appelé par la prévision comme par la résolution : le
## chiffre annoncé par le télégraphe DOIT être le chiffre appliqué.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _plain() -> CombatBoard:
	return _board([
		"........", "........", "........",
		"........", "........", "........",
	])


func _hero(board: CombatBoard, class_id: StringName, at: Vector2i, id: int = 1) -> Unit:
	var unit := Unit.from_hero_class(id, class_id, at)
	board.place_unit(unit, at)
	return unit


func _enemy(board: CombatBoard, enemy_id: StringName, at: Vector2i, id: int = 90) -> Unit:
	var unit := Unit.from_enemy(id, enemy_id, at)
	board.place_unit(unit, at)
	return unit


func test_base_plus_statistique_moins_defense() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(2, 2))
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 2))
	var strike := Ability.of(&"strike")

	var expected := strike.damage + warrior.strength - goblin.defence
	assert_eq(Damage.compute(warrior, strike, goblin), expected)


func test_la_statistique_d_echelle_est_celle_de_la_competence() -> void:
	# Le Trait ardent monte à l'Intelligence, pas à la Force : un Mage
	# musclé ne lance pas mieux.
	var board := _plain()
	var mage := _hero(board, &"mage", Vector2i(2, 2))
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 2))
	var bolt := Ability.of(&"bolt")

	mage.strength = 99
	var without := Damage.compute(mage, bolt, goblin)
	mage.intelligence += 10
	assert_eq(Damage.compute(mage, bolt, goblin), without + 10)


func test_une_defense_enorme_laisse_le_plancher() -> void:
	# Une attaque qui passe fait toujours quelque chose, sinon le joueur ne
	# comprend pas ce qui vient de se produire.
	var board := _plain()
	var mage := _hero(board, &"mage", Vector2i(2, 2))
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 2))
	goblin.defence = 9999
	assert_eq(
		Damage.compute(mage, Ability.of(&"bolt"), goblin), CombatRules.damage_minimum()
	)


func test_la_foret_protege_celui_qui_s_y_tient() -> void:
	var board := _board([
		"........", "........", "...f....",
		"........", "........", "........",
	])
	var warrior := _hero(board, &"warrior", Vector2i(2, 2))
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 2))
	var strike := Ability.of(&"strike")

	var in_forest := board.predicted_damage(warrior, strike, goblin)
	board.move_unit(goblin, Vector2i(1, 2))
	var in_the_open := board.predicted_damage(warrior, strike, goblin)
	assert_lt(in_forest, in_the_open, "la forêt encaisse un point")


func test_la_ruine_expose_celui_qui_s_y_tient() -> void:
	var board := _board([
		"........", "........", "...r....",
		"........", "........", "........",
	])
	var warrior := _hero(board, &"warrior", Vector2i(2, 2))
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 2))
	var strike := Ability.of(&"strike")

	var in_ruin := board.predicted_damage(warrior, strike, goblin)
	board.move_unit(goblin, Vector2i(1, 2))
	assert_gt(in_ruin, board.predicted_damage(warrior, strike, goblin))


func test_la_colline_ne_sert_qu_aux_competences_a_distance() -> void:
	var board := _board([
		"^.......", "........", "........",
		"........", "........", "........",
	])
	var archer := _hero(board, &"archer", Vector2i(0, 0))
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 0))
	var shot := Ability.of(&"shot")
	var on_hill := board.predicted_damage(archer, shot, goblin)

	board.move_unit(archer, Vector2i(0, 1))
	board.move_unit(goblin, Vector2i(3, 1))
	assert_gt(on_hill, board.predicted_damage(archer, shot, goblin))


func test_un_guerrier_perche_ne_frappe_pas_plus_fort() -> void:
	var board := _board([
		"^.......", "........", "........",
		"........", "........", "........",
	])
	var warrior := _hero(board, &"warrior", Vector2i(0, 0))
	var goblin := _enemy(board, &"spear_goblin", Vector2i(1, 0))
	var on_hill := board.predicted_damage(warrior, Ability.of(&"strike"), goblin)

	board.move_unit(warrior, Vector2i(0, 1))
	board.move_unit(goblin, Vector2i(1, 1))
	assert_eq(on_hill, board.predicted_damage(warrior, Ability.of(&"strike"), goblin))


func test_une_competence_sans_degats_ne_calcule_rien() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(2, 2))
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 2))
	assert_eq(Damage.compute(warrior, Ability.of(&"taunt"), goblin), 0)


func test_le_chiffre_annonce_est_le_chiffre_applique() -> void:
	# La raison d'être de la classe. Si ce test tombe, le télégraphe ment.
	var board := _board([
		"........", "...f....", "........",
		"........", "........", "........",
	])
	var warrior := _hero(board, &"warrior", Vector2i(2, 1))
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 1))
	var strike := Ability.of(&"strike")

	var announced := board.predicted_damage(warrior, strike, goblin)
	var before := goblin.hit_points
	board.resolve_ability(warrior, strike, goblin.cell)
	assert_eq(before - goblin.hit_points, announced)
