extends GutTest

## T1.5 et T1.7 — ligne de vue, portée, zone, résolution d'une compétence.
##
## Le point le plus important est celui-ci : `predicted_damage` est la
## seule source du calcul, et c'est elle que lit le télégraphe. Un
## télégraphe qui annonce 30 et inflige 40 est pire qu'une absence de
## télégraphe. Ces tests vérifient donc systématiquement que le chiffre
## annoncé est le chiffre appliqué.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _hero(board: CombatBoard, class_id: StringName, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_hero_class(id, class_id, at)
	board.place_unit(unit, at)
	return unit


func _goblin(board: CombatBoard, at: Vector2i, id: int, hp: int = 45) -> Unit:
	var unit := Unit.from_enemy(id, &"spear_goblin", at)
	unit.max_hit_points = hp
	unit.hit_points = hp
	board.place_unit(unit, at)
	return unit


func _of(id: StringName) -> Ability:
	return Ability.of(id)


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
	# La case de la cible ne compte pas : la forêt protège d'un point de
	# dégât, elle ne rend pas invisible. Sinon l'Archer n'aurait plus de
	# cible.
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
	var board := _board([
		"..........", "..........", "..........",
	])
	var archer := _hero(board, &"archer", Vector2i(3, 1), 1)
	var cells := board.targetable_cells(archer, _of(&"shot"))
	assert_false(cells.has(Vector2i(3, 1)), "ni sa propre case")
	assert_false(cells.has(Vector2i(4, 1)), "ni la case adjacente")
	assert_true(cells.has(Vector2i(5, 1)), "à 2 cases : oui")
	assert_true(cells.has(Vector2i(8, 1)), "à 5 cases : oui")


func test_le_guerrier_ne_frappe_que_ses_voisins() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var cells := board.targetable_cells(warrior, _of(&"strike"))
	assert_eq(cells.size(), 4, "les quatre cases adjacentes")
	for cell: Vector2i in cells:
		assert_eq(board.grid.distance(Vector2i(3, 1), cell), 1)


func test_chaque_competence_a_sa_propre_portee() -> void:
	# C'est la différence avec l'ancien modèle : la portée appartient à la
	# compétence, pas à l'unité. Le Mage frappe à 5 au Trait et à 4 au Gel.
	var board := _board([
		"..........", "..........", "..........",
	])
	var mage := _hero(board, &"mage", Vector2i(0, 1), 1)
	assert_true(board.targetable_cells(mage, _of(&"bolt")).has(Vector2i(5, 1)))
	assert_false(board.targetable_cells(mage, _of(&"frost")).has(Vector2i(5, 1)))


func test_la_colline_allonge_la_portee_du_tireur() -> void:
	var board := _board([
		"..........", "^.........", "..........",
	])
	var archer := _hero(board, &"archer", Vector2i(0, 1), 1)
	var shot := _of(&"shot")
	assert_eq(board.effective_range_max(archer, shot), shot.range_max + 1)
	assert_true(board.targetable_cells(archer, shot).has(Vector2i(shot.range_max + 1, 1)))


func test_la_colline_n_allonge_pas_le_bras_du_guerrier() -> void:
	var board := _board(["........", "^.......", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(0, 1), 1)
	assert_eq(
		board.effective_range_max(warrior, _of(&"strike")), 1,
		"un guerrier perché frappe aussi loin"
	)


func test_le_rocher_protege_la_cible_du_tireur() -> void:
	var board := _board(["........", "..#.....", "........"])
	var archer := _hero(board, &"archer", Vector2i(0, 1), 1)
	_goblin(board, Vector2i(4, 1), 2)
	assert_true(
		board.reachable_targets(archer, _of(&"shot")).is_empty(),
		"le rocher est entre les deux"
	)


func test_on_ne_vise_que_le_camp_d_en_face() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	_hero(board, &"mage", Vector2i(4, 1), 2)
	var goblin := _goblin(board, Vector2i(2, 1), 3)
	var targets := board.reachable_targets(warrior, _of(&"strike"))
	assert_eq(targets.size(), 1, "un seul ennemi à portée")
	assert_eq(targets[0].id, goblin.id, "le Mage allié n'est pas une cible")


func test_une_unite_tombee_n_est_plus_une_cible() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var goblin := _goblin(board, Vector2i(2, 1), 2)
	goblin.down()
	board.remove_from_board(goblin)
	assert_true(board.reachable_targets(warrior, _of(&"strike")).is_empty())


func test_frapper_demande_des_pa_autant_qu_une_portee() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var goblin := _goblin(board, Vector2i(4, 1), 2)
	assert_true(board.can_use_on(warrior, _of(&"strike"), goblin))
	warrior.spend_action_points(warrior.action_points)
	assert_false(board.can_use_on(warrior, _of(&"strike"), goblin), "plus de PA")


# --- Zone -----------------------------------------------------------------

func test_une_frappe_ne_touche_que_sa_case() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	assert_eq(
		board.affected_cells(warrior, _of(&"strike"), Vector2i(4, 1)),
		[Vector2i(4, 1)]
	)


func test_la_boule_de_feu_ramasse_tous_les_ennemis_de_sa_zone() -> void:
	var board := _board([
		"..........", "..........", "..........", "..........",
	])
	var mage := _hero(board, &"mage", Vector2i(0, 1), 1)
	_goblin(board, Vector2i(4, 1), 2)
	_goblin(board, Vector2i(5, 1), 3)
	_goblin(board, Vector2i(4, 2), 4)
	var hit := board.affected_units(mage, _of(&"fireball"), Vector2i(4, 1))
	assert_eq(hit.size(), 3, "la cible et ses deux voisins")


func test_sans_tir_ami_les_allies_sont_epargnes() -> void:
	var board := _board([
		"..........", "..........", "..........",
	])
	var warrior := _hero(board, &"warrior", Vector2i(0, 1), 1)
	_hero(board, &"archer", Vector2i(1, 1), 2)
	assert_true(board.affected_units(warrior, _of(&"strike"), Vector2i(1, 1)).is_empty())


# --- Résolution -----------------------------------------------------------

func test_les_degats_annonces_sont_les_degats_infliges() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var goblin := _goblin(board, Vector2i(4, 1), 2)
	var strike := _of(&"strike")

	var announced := board.predicted_damage(warrior, strike, goblin)
	var report := board.resolve_ability(warrior, strike, goblin.cell)
	var hits: Array = report["hits"]
	assert_eq(hits.size(), 1)
	assert_eq(
		int(hits[0]["damage"]), announced, "le télégraphe ne doit jamais mentir"
	)
	assert_eq(goblin.hit_points, goblin.max_hit_points - announced)


func test_le_coup_fatal_met_hors_de_combat_et_libere_la_case() -> void:
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var goblin := _goblin(board, Vector2i(4, 1), 2, 5)
	var report := board.resolve_ability(warrior, _of(&"strike"), goblin.cell)
	assert_eq(report["downed_ids"], [goblin.id])
	assert_true(goblin.is_downed())
	assert_null(board.unit_at(Vector2i(4, 1)), "la case est rendue au plateau")
	assert_false(board.tile_at(Vector2i(4, 1)).is_occupied())


func test_frapper_le_vide_ne_touche_personne() -> void:
	# C'est ce qui arrive quand le joueur a déplacé la cible d'un
	# télégraphe : le coup part, et il rate.
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var report := board.resolve_ability(warrior, _of(&"strike"), Vector2i(4, 1))
	assert_true((report["hits"] as Array).is_empty())


func test_resoudre_ne_depense_pas_les_pa() -> void:
	# Le plateau applique, le moteur décide : c'est ce qui permet à l'IA et
	# au télégraphe de simuler un coup sans le consommer.
	var board := _board(["........", "........", "........"])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var goblin := _goblin(board, Vector2i(4, 1), 2)
	board.resolve_ability(warrior, _of(&"strike"), goblin.cell)
	assert_eq(warrior.action_points, warrior.max_action_points)


func test_un_statut_est_pose_par_la_resolution() -> void:
	var board := _board([
		"..........", "..........", "..........",
	])
	var mage := _hero(board, &"mage", Vector2i(0, 1), 1)
	var goblin := _goblin(board, Vector2i(3, 1), 2)
	board.resolve_ability(mage, _of(&"frost"), goblin.cell)
	assert_true(goblin.has_status(&"chilled"))
