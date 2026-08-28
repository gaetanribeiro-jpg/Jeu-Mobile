extends GutTest

## C1.5 et C1.6 — ligne de vue, portée, résolution d'une attaque.
##
## Le point le plus important est celui-ci : `predicted_damage` est la
## seule source du calcul, et c'est elle que lira le télégraphe. Un
## télégraphe qui annonce 3 et inflige 4 est pire qu'une absence de
## télégraphe. Ces tests vérifient donc systématiquement que le chiffre
## annoncé est le chiffre appliqué.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _hero(board: CombatBoard, class_id: StringName, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_hero_class(id, class_id, at)
	board.place_unit(unit, at)
	return unit


func _goblin(board: CombatBoard, at: Vector2i, id: int, hp: int = 5) -> Unit:
	var unit := Unit.from_stats(
		id, &"spear_goblin", Unit.Side.ENEMIES, at,
		{"hit_points": hp, "movement": 3, "range_min": 1, "range_max": 1, "damage": 2}
	)
	board.place_unit(unit, at)
	return unit


# --- Ligne de vue ---------------------------------------------------------

func test_la_vue_passe_en_terrain_degage() -> void:
	var board := _board(["........", "........", "........"])
	assert_true(board.has_line_of_sight(Vector2i(0, 1), Vector2i(7, 1)))


func test_le_rocher_coupe_la_vue() -> void:
	var board := _board(["........", "...#....", "........"])
	assert_false(board.has_line_of_sight(Vector2i(0, 1), Vector2i(7, 1)))


func test_la_foret_coupe_la_vue() -> void:
	var board := _board(["........", "...f....", "........"])
	assert_false(board.has_line_of_sight(Vector2i(0, 1), Vector2i(7, 1)))


func test_une_unite_dans_la_foret_reste_visible() -> void:
	# La case de la cible ne compte pas : la forêt protège de 1 dégât,
	# elle ne rend pas invisible. Sinon l'Archer n'aurait plus de cible.
	var board := _board(["........", ".....f..", "........"])
	assert_true(board.has_line_of_sight(Vector2i(1, 1), Vector2i(5, 1)))


func test_on_ne_tire_pas_depuis_la_foret_a_travers_une_autre() -> void:
	var board := _board(["........", "f..f...f", "........"])
	assert_true(board.has_line_of_sight(Vector2i(0, 1), Vector2i(3, 1)), "rien entre les deux")
	assert_false(board.has_line_of_sight(Vector2i(0, 1), Vector2i(7, 1)), "la forêt du milieu")


func test_l_eau_ne_coupe_pas_la_vue() -> void:
	var board := _board(["........", "..~~~~..", "........"])
	assert_true(board.has_line_of_sight(Vector2i(0, 1), Vector2i(7, 1)))


# --- Portée ---------------------------------------------------------------

func test_l_archer_ne_tire_pas_sur_son_voisin() -> void:
	var board := _board(["........", "........", "........"])
	var archer := _hero(board, &"archer", Vector2i(3, 1), 1)
	var cells := board.attackable_cells(archer)
	assert_false(cells.has(Vector2i(3, 1)), "ni sa propre case")
	assert_false(cells.has(Vector2i(4, 1)), "ni la case adjacente")
	assert_true(cells.has(Vector2i(5, 1)), "à 2 cases : oui")
	assert_true(cells.has(Vector2i(7, 1)), "à 4 cases : oui")


func test_le_guerrier_ne_frappe_que_ses_voisins() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var cells := board.attackable_cells(warrior)
	assert_eq(cells.size(), 4, "les quatre cases adjacentes")
	for cell: Vector2i in cells:
		assert_eq(board.grid.distance(Vector2i(3, 1), cell), 1)


func test_la_colline_allonge_la_portee_du_tireur() -> void:
	var board := _board(["........", "^.......", "........"])
	var archer := _hero(board, &"archer", Vector2i(0, 1), 1)
	assert_eq(board.effective_range_max(archer), 5, "4 de base, +1 de colline")
	assert_true(board.attackable_cells(archer).has(Vector2i(5, 1)))


func test_la_colline_n_allonge_pas_le_bras_du_guerrier() -> void:
	var board := _board(["........", "^.......", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(0, 1), 1)
	assert_eq(board.effective_range_max(warrior), 1, "un guerrier perché frappe aussi loin")


func test_le_rocher_protege_la_cible_du_tireur() -> void:
	var board := _board(["........", "..#.....", "........"])
	var archer := _hero(board, &"archer", Vector2i(0, 1), 1)
	var goblin := _goblin(board, Vector2i(4, 1), 2)
	assert_false(board.can_attack(archer, goblin), "le rocher est entre les deux")
	assert_true(board.attackable_units(archer).is_empty())


func test_on_ne_vise_que_le_camp_d_en_face() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	_hero(board, &"monk", Vector2i(4, 1), 2)
	var goblin := _goblin(board, Vector2i(2, 1), 3)
	var targets := board.attackable_units(warrior)
	assert_eq(targets.size(), 1, "un seul ennemi à portée")
	assert_eq(targets[0].id, goblin.id, "le moine allié n'est pas une cible")


func test_une_unite_tombee_n_est_plus_une_cible() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var goblin := _goblin(board, Vector2i(2, 1), 2)
	goblin.down()
	board.remove_from_board(goblin)
	assert_true(board.attackable_units(warrior).is_empty())


# --- Résolution d'une attaque ---------------------------------------------

func test_les_degats_annonces_sont_les_degats_infliges() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var goblin := _goblin(board, Vector2i(4, 1), 2)
	var announced := board.predicted_damage(warrior, goblin.cell)
	var report := board.resolve_attack(warrior, goblin)
	assert_eq(announced, 3, "le guerrier frappe à 3")
	assert_eq(report["damage"], announced, "le télégraphe ne doit jamais mentir")
	assert_eq(goblin.hit_points, 2, "5 − 3")


func test_la_foret_retire_un_degat() -> void:
	var board := _board(["........", "...f....", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(2, 1), 1)
	var goblin := _goblin(board, Vector2i(3, 1), 2)
	assert_eq(board.predicted_damage(warrior, goblin.cell), 2, "3 − 1")


func test_la_ruine_ajoute_un_degat() -> void:
	var board := _board(["........", "...r....", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(2, 1), 1)
	var goblin := _goblin(board, Vector2i(3, 1), 2)
	assert_eq(board.predicted_damage(warrior, goblin.cell), 4, "3 + 1")


func test_la_colline_ajoute_un_degat_au_tireur_seulement() -> void:
	var board := _board(["........", "^.......", "........"])
	var archer := _hero(board, &"archer", Vector2i(0, 1), 1)
	var goblin := _goblin(board, Vector2i(3, 1), 2)
	assert_eq(board.predicted_damage(archer, goblin.cell), 3, "2 + 1 de colline")

	var other := _board(["........", "^.......", "........"])
	var warrior := _hero(other, &"warrior", Vector2i(0, 1), 1)
	var target := _goblin(other, Vector2i(1, 1), 2)
	assert_eq(other.predicted_damage(warrior, target.cell), 3, "3, sans bonus de colline")


func test_la_foret_ne_peut_pas_soigner() -> void:
	# Le Moine frappe à 1. En forêt, 1 − 1 = 0, et surtout pas −1.
	var board := _board(["........", "...f....", "........"])
	var monk := _hero(board, &"monk", Vector2i(2, 1), 1)
	var goblin := _goblin(board, Vector2i(3, 1), 2)
	assert_eq(board.predicted_damage(monk, goblin.cell), 0)
	board.resolve_attack(monk, goblin)
	assert_eq(goblin.hit_points, 5, "intact, pas soigné")


func test_le_coup_fatal_met_hors_de_combat_et_libere_la_case() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var goblin := _goblin(board, Vector2i(4, 1), 2, 3)
	var report := board.resolve_attack(warrior, goblin)
	assert_true(report["downed"])
	assert_true(goblin.is_downed())
	assert_null(board.unit_at(Vector2i(4, 1)), "la case est rendue au plateau")
	assert_false(board.tile_at(Vector2i(4, 1)).is_occupied())


func test_attaquer_consomme_l_action_du_tour() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var goblin := _goblin(board, Vector2i(4, 1), 2)
	assert_false(warrior.has_acted)
	board.resolve_attack(warrior, goblin)
	assert_true(warrior.has_acted)
