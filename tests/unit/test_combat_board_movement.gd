extends GutTest

## T1.5 — déplacement au coût en PM (§ 13). Les cartes sont écrites en
## clair : un caractère par case, avec les symboles de terrain.json.
## « . » herbe, « ~ » eau, « f » forêt, « ^ » colline, « # » rocher,
## « = » pont, « r » ruine, « b » boue.
##
## LE POINT DU MODÈLE PM : le budget est ce qu'il RESTE dans l'activation,
## pas le maximum de l'unité. Avancer de deux cases, frapper, puis avancer
## encore est le tour du § 14, et il faut que la zone rétrécisse entre les
## deux.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _hero(board: CombatBoard, class_id: StringName, at: Vector2i, id: int = 1) -> Unit:
	var unit := Unit.from_hero_class(id, class_id, at)
	board.place_unit(unit, at)
	return unit


func test_une_plaine_libre_donne_un_losange() -> void:
	# En distance de Manhattan : toutes les cases à portée de PM, et pas
	# une de plus.
	var board := _board([
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
	])
	var unit := _hero(board, &"warrior", Vector2i(4, 3))
	var budget := unit.movement_points
	var reachable := board.reachable_cells(unit)
	for cell: Vector2i in board.grid.cells():
		var expected: bool = board.grid.distance(Vector2i(4, 3), cell) <= budget
		assert_eq(reachable.has(cell), expected, "case %s" % cell)


func test_la_zone_retrecit_a_mesure_qu_on_depense_ses_pm() -> void:
	# Sans ça, le joueur ne verrait pas ce que son premier pas lui a coûté,
	# et le § 14 — optimiser son tour — n'aurait aucun support visuel.
	var board := _board([
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
	])
	var unit := _hero(board, &"warrior", Vector2i(4, 3))
	var full := board.reachable_cells(unit).size()
	unit.spend_movement_points(2)
	var after := board.reachable_cells(unit).size()
	assert_lt(after, full, "il reste moins de cases après deux pas")
	unit.spend_movement_points(unit.movement_points)
	assert_eq(
		board.reachable_cells(unit).size(), 1,
		"sans PM, il ne reste que la case où l'on est"
	)


func test_le_budget_peut_etre_force_pour_une_simulation() -> void:
	# L'IA s'en sert pour se demander où elle pourrait aller avec le plein,
	# sans avoir à toucher aux PM de l'unité.
	var board := _board([
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
	])
	var unit := _hero(board, &"warrior", Vector2i(4, 3))
	unit.spend_movement_points(unit.movement_points)
	assert_eq(board.reachable_cells(unit).size(), 1)
	assert_gt(board.reachable_cells(unit, 3).size(), 1, "avec un budget forcé")


func test_la_boue_coute_deux_pm() -> void:
	# Ce que le système PM apporte et que l'ancien modèle ne pouvait pas
	# exprimer : toutes les cases ne se valent pas.
	var board := _board([
		"........",
		"bbbbbbbb",
		"........",
		"........",
		"........",
		"........",
	])
	var unit := _hero(board, &"warrior", Vector2i(0, 0))
	var reachable := board.reachable_cells(unit)
	assert_eq(reachable[Vector2i(0, 1)], 2, "entrer dans la boue coûte 2")
	assert_eq(reachable[Vector2i(1, 0)], 1, "l'herbe à côté n'en coûte qu'un")


func test_le_cout_pour_rejoindre_une_case_est_lisible() -> void:
	var board := _board([
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
	])
	var unit := _hero(board, &"warrior", Vector2i(0, 0))
	assert_eq(board.move_cost_to(unit, Vector2i(2, 0)), 2)
	assert_eq(board.move_cost_to(unit, Vector2i(7, 5)), -1, "hors d'atteinte")


func test_la_case_de_depart_est_toujours_atteignable() -> void:
	var board := _board(["....", "....", "....", "...."])
	var unit := _hero(board, &"warrior", Vector2i(1, 1))
	assert_true(board.reachable_cells(unit).has(Vector2i(1, 1)))
	assert_eq(board.reachable_cells(unit)[Vector2i(1, 1)], 0)


func test_le_cout_est_la_distance_reelle_pas_a_vol_d_oiseau() -> void:
	# Un rocher force le détour : (2, 0) est à 2 cases à vol d'oiseau, mais
	# en coûte 4 en PM — soit plus que ce que le Mage possède.
	var board := _board([
		".#......",
		"........",
		"........",
		"........",
		"........",
		"........",
	])
	var unit := _hero(board, &"mage", Vector2i(0, 0))
	assert_false(
		board.reachable_cells(unit, 9).has(Vector2i(1, 0)),
		"le rocher n'est pas franchissable"
	)
	assert_eq(board.grid.distance(Vector2i(0, 0), Vector2i(2, 0)), 2, "2 à vol d'oiseau")
	assert_eq(board.move_cost_to(unit, Vector2i(2, 0), 9), 4, "mais 4 en contournant")
	assert_eq(
		board.move_cost_to(unit, Vector2i(2, 0), 3), -1,
		"avec 3 PM, le détour est hors de portée"
	)


func test_un_detour_trop_long_met_la_case_hors_d_atteinte() -> void:
	# Le même rocher allongé en mur : la case derrière devient inatteignable
	# alors qu'elle reste à 2 cases à vol d'oiseau.
	var board := _board([
		".#......",
		".#......",
		".#......",
		".#......",
		".#......",
		".#......",
	])
	var unit := _hero(board, &"mage", Vector2i(0, 0))
	assert_false(
		board.reachable_cells(unit).has(Vector2i(2, 0)),
		"le mur est trop long pour être contourné avec les PM d'un tour"
	)


func test_l_eau_est_infranchissable_pour_un_heros() -> void:
	var board := _board([
		"..~.....",
		"..~.....",
		"..~.....",
		"..~.....",
		"..~.....",
		"..~.....",
	])
	var unit := _hero(board, &"warrior", Vector2i(1, 3))
	var reachable := board.reachable_cells(unit)
	for y in 6:
		assert_false(reachable.has(Vector2i(2, y)), "l'eau en (2, %d)" % y)
	assert_false(reachable.has(Vector2i(3, 3)), "l'autre rive est hors d'atteinte")


func test_une_creature_aquatique_circule_dans_l_eau() -> void:
	var board := _board([
		"~~~~~~~~",
		"~~~~~~~~",
		"........",
		"........",
		"........",
		"........",
	])
	var shark := Unit.from_stats(
		1, &"paddle_shark", Unit.Side.ENEMIES, Vector2i(3, 0),
		{"hit_points": 40, "action_points": 6, "movement_points": 3,
		 "initiative": 5, "aquatic": true}
	)
	board.place_unit(shark, Vector2i(3, 0))
	var reachable := board.reachable_cells(shark)
	assert_true(reachable.has(Vector2i(6, 0)), "l'eau lui est ouverte")
	assert_true(reachable.has(Vector2i(3, 2)), "la terre ferme aussi")


func test_le_pont_franchit_l_eau() -> void:
	var board := _board([
		"..~.....",
		"..=.....",
		"..~.....",
		"........",
		"........",
		"........",
	])
	var unit := _hero(board, &"warrior", Vector2i(1, 1))
	assert_true(board.reachable_cells(unit).has(Vector2i(3, 1)), "on passe par le pont")


func test_le_pont_detruit_coupe_le_passage() -> void:
	var board := _board([
		"..~.....",
		"..=.....",
		"..~.....",
		"........",
		"........",
		"........",
	])
	var unit := _hero(board, &"warrior", Vector2i(1, 1))
	board.tile_at(Vector2i(2, 1)).damage_structure(2)
	assert_false(board.reachable_cells(unit).has(Vector2i(3, 1)), "le pont a cédé")


func test_on_traverse_un_allie_mais_on_ne_s_arrete_pas_dessus() -> void:
	var board := _board([
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
	])
	var unit := _hero(board, &"warrior", Vector2i(1, 0), 1)
	_hero(board, &"mage", Vector2i(2, 0), 2)
	var reachable := board.reachable_cells(unit)
	assert_false(reachable.has(Vector2i(2, 0)), "on ne finit pas sur un allié")
	assert_true(reachable.has(Vector2i(3, 0)), "mais on passe derrière lui")


func test_un_ennemi_barre_le_passage() -> void:
	var board := _board([
		"#.......",
		"........",
		"#.......",
		"........",
		"........",
		"........",
	])
	var unit := _hero(board, &"warrior", Vector2i(0, 1), 1)
	var goblin := Unit.from_stats(
		2, &"spear_goblin", Unit.Side.ENEMIES, Vector2i(1, 1),
		{"hit_points": 30, "action_points": 6, "movement_points": 3, "initiative": 5}
	)
	board.place_unit(goblin, Vector2i(1, 1))
	var reachable := board.reachable_cells(unit)
	assert_false(reachable.has(Vector2i(2, 1)), "l'ennemi ferme le couloir")


func test_les_pm_de_chaque_classe_sont_ceux_des_donnees() -> void:
	var board := _board([
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
	])
	for class_id: StringName in Unit.hero_class_ids():
		var unit := Unit.from_hero_class(1, class_id, Vector2i(4, 3))
		board.place_unit(unit, Vector2i(4, 3))
		var reachable := board.reachable_cells(unit)
		var furthest := 0
		for cost: int in reachable.values():
			furthest = maxi(furthest, cost)
		assert_eq(furthest, unit.max_movement_points, "%s : portée en PM" % class_id)
		board.remove_from_board(unit)


func test_une_unite_tombee_ne_se_deplace_plus() -> void:
	var board := _board(["....", "....", "....", "...."])
	var unit := _hero(board, &"warrior", Vector2i(1, 1))
	unit.down()
	assert_eq(board.reachable_cells(unit), {})


func test_une_carte_non_rectangulaire_est_refusee() -> void:
	assert_null(CombatBoard.from_rows(PackedStringArray(["....", "..."])))
	assert_push_error("rectangulaire")
