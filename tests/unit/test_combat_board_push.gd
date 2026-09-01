extends GutTest

## C1.7 — la poussée.
##
## C'est l'outil tactique central du jeu : le § 4.2 dit qu'on peut répondre
## à une attaque télégraphiée en sortant de la case, en tuant l'ennemi, ou
## en le déplaçant. La troisième réponse passe entièrement par ici, et
## l'eau est ce qui la rend redoutable.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _goblin(board: CombatBoard, at: Vector2i, id: int = 1, aquatic: bool = false) -> Unit:
	var unit := Unit.from_stats(
		id, &"spear_goblin", Unit.Side.ENEMIES, at,
		{"hit_points": 5, "movement": 3, "range_min": 1, "range_max": 1,
		 "damage": 2, "aquatic": aquatic}
	)
	board.place_unit(unit, at)
	return unit


func test_une_poussee_libre_avance_d_une_case() -> void:
	var board := _board(["........", "........", "........"])
	var goblin := _goblin(board, Vector2i(3, 1))
	var report := board.push(goblin, Vector2i(1, 0))
	assert_eq(report["destination"], Vector2i(4, 1))
	assert_eq(goblin.cell, Vector2i(4, 1))
	assert_false(report["blocked"])
	assert_null(board.unit_at(Vector2i(3, 1)), "la case de départ est libérée")
	assert_eq(board.unit_at(Vector2i(4, 1)), goblin, "et la case d'arrivée occupée")


func test_le_bord_de_grille_bloque() -> void:
	var board := _board(["........", "........", "........"])
	var goblin := _goblin(board, Vector2i(7, 1))
	var report := board.push(goblin, Vector2i(1, 0))
	assert_true(report["blocked"])
	assert_eq(report["blocked_by"], "edge")
	assert_eq(goblin.cell, Vector2i(7, 1), "l'ennemi ne bouge pas")


func test_un_rocher_bloque() -> void:
	var board := _board(["........", "...#....", "........"])
	var goblin := _goblin(board, Vector2i(2, 1))
	var report := board.push(goblin, Vector2i(1, 0))
	assert_true(report["blocked"])
	assert_eq(report["blocked_by"], "terrain")
	assert_eq(goblin.cell, Vector2i(2, 1))


func test_une_autre_unite_bloque() -> void:
	var board := _board(["........", "........", "........"])
	var goblin := _goblin(board, Vector2i(2, 1), 1)
	_goblin(board, Vector2i(3, 1), 2)
	var report := board.push(goblin, Vector2i(1, 0))
	assert_true(report["blocked"])
	assert_eq(report["blocked_by"], "unit")
	assert_eq(goblin.cell, Vector2i(2, 1))


func test_une_poussee_bloquee_ne_fait_pas_de_degat_par_defaut() -> void:
	# rules.json fixe push.blocked_damage à 0 : le pousseur a gâché son
	# coup, et c'est ce qui rend le placement intéressant.
	var board := _board(["........", "........", "........"])
	var goblin := _goblin(board, Vector2i(7, 1))
	var report := board.push(goblin, Vector2i(1, 0))
	assert_eq(report["damage"], 0)
	assert_eq(goblin.hit_points, 5)
	assert_false(report["downed"])


func test_pousse_dans_l_eau_egale_mort() -> void:
	var board := _board(["........", "...~....", "........"])
	var goblin := _goblin(board, Vector2i(2, 1))
	var report := board.push(goblin, Vector2i(1, 0))
	assert_true(report["drowns"], "l'eau ne pardonne pas")
	assert_true(report["downed"])
	assert_true(goblin.is_downed())
	assert_eq(goblin.cell, Vector2i(3, 1), "la victime finit bien dans l'eau")
	assert_null(board.unit_at(Vector2i(3, 1)), "et libère la case")
	assert_false(report["blocked"], "l'eau accueille, elle ne bloque pas")


func test_une_creature_aquatique_ne_se_noie_pas() -> void:
	var board := _board(["........", "...~....", "........"])
	var shark := _goblin(board, Vector2i(2, 1), 1, true)
	var report := board.push(shark, Vector2i(1, 0))
	assert_false(report["drowns"])
	assert_false(report["downed"])
	assert_eq(shark.cell, Vector2i(3, 1))
	assert_true(shark.is_active(), "elle y est chez elle")


func test_la_prevision_annonce_exactement_ce_qui_arrive() -> void:
	# La prévisualisation du § 11.2 lit predict_push : ce qu'elle montre
	# doit être ce que la validation applique, sans exception.
	var cases := [
		{"rows": ["........", "........", "........"], "at": Vector2i(3, 1)},
		{"rows": ["........", "...~....", "........"], "at": Vector2i(2, 1)},
		{"rows": ["........", "...#....", "........"], "at": Vector2i(2, 1)},
		{"rows": ["........", "........", "........"], "at": Vector2i(7, 1)},
	]
	for entry: Dictionary in cases:
		var board := _board(entry["rows"])
		var goblin := _goblin(board, entry["at"])
		var prediction := board.predict_push(goblin, Vector2i(1, 0), 1)
		var report := board.push(goblin, Vector2i(1, 0))
		assert_eq(report["destination"], prediction["destination"], "case d'arrivée")
		assert_eq(report["blocked"], prediction["blocked"], "blocage")
		assert_eq(report["drowns"], prediction["drowns"], "noyade")
		assert_eq(goblin.cell, prediction["destination"], "position réelle")


func test_la_poussee_du_hallebardier_avance_de_deux() -> void:
	# L'Élévation « Hallebardier » pousse de 2 cases (§ 3.5.4).
	var board := _board(["........", "........", "........"])
	var goblin := _goblin(board, Vector2i(2, 1))
	var report := board.push(goblin, Vector2i(1, 0), 2)
	assert_eq(report["destination"], Vector2i(4, 1))
	assert_false(report["blocked"])


func test_une_poussee_de_deux_s_arrete_sur_l_obstacle() -> void:
	var board := _board(["........", "....#...", "........"])
	var goblin := _goblin(board, Vector2i(2, 1))
	var report := board.push(goblin, Vector2i(1, 0), 2)
	assert_eq(report["destination"], Vector2i(3, 1), "une case gagnée, puis le rocher")
	assert_true(report["blocked"])
	assert_eq(goblin.cell, Vector2i(3, 1))


func test_une_poussee_de_deux_s_arrete_dans_l_eau_rencontree_en_chemin() -> void:
	var board := _board(["........", "...~....", "........"])
	var goblin := _goblin(board, Vector2i(2, 1))
	var report := board.push(goblin, Vector2i(1, 0), 2)
	assert_eq(report["destination"], Vector2i(3, 1), "l'eau arrête le vol")
	assert_true(report["drowns"])
	assert_true(goblin.is_downed())


func test_la_direction_se_deduit_de_la_position_du_pousseur() -> void:
	var board := _board(["........", "........", "........"])
	var goblin := _goblin(board, Vector2i(3, 1))
	# Le lancier est en (2, 1) : il pousse vers la droite.
	board.push_away_from(goblin, Vector2i(2, 1))
	assert_eq(goblin.cell, Vector2i(4, 1))


func test_on_pousse_par_dessus_un_pont_et_dans_l_eau_qu_il_laisse() -> void:
	var board := _board(["........", "..=~....", "........"])
	var goblin := _goblin(board, Vector2i(1, 1))
	board.push(goblin, Vector2i(1, 0))
	assert_eq(goblin.cell, Vector2i(2, 1), "le pont se marche")
	assert_true(goblin.is_active())
	board.push(goblin, Vector2i(1, 0))
	assert_eq(goblin.cell, Vector2i(3, 1))
	assert_true(goblin.is_downed(), "la case suivante est de l'eau")
