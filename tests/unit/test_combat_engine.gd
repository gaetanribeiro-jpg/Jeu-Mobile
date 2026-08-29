extends GutTest

## C1.8 et C1.13 — la machine à états du tour, et l'annulation.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _plain() -> CombatBoard:
	return _board(["........", "........", "........", "........", "........", "........"])


func _engine(board: CombatBoard, objective_data: Dictionary = {}) -> CombatEngine:
	var data := objective_data if not objective_data.is_empty() else {"kind": "eliminate"}
	return CombatEngine.new(
		board, CombatObjective.from_dictionary(data), CombatRng.new(4242)
	)


func _hero(board: CombatBoard, class_id: StringName, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_hero_class(id, class_id, at)
	board.place_unit(unit, at)
	return unit


func _enemy(board: CombatBoard, enemy_id: StringName, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_enemy(id, enemy_id, at)
	board.place_unit(unit, at)
	return unit


# --- Ouverture ------------------------------------------------------------

func test_le_telegraphe_est_pose_des_le_premier_tour() -> void:
	# Sans ça, le tour 1 n'aurait rien à contrer et la règle du § 4.2 ne
	# vaudrait qu'à partir du tour 2.
	var board := _plain()
	_hero(board, &"warrior", Vector2i(3, 3), 1)
	_enemy(board, &"spear_goblin", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	assert_eq(engine.turn_index, 1)
	assert_eq(engine.phase, CombatEngine.Phase.PLAYER_TURN)
	assert_eq(engine.telegraph().size(), 1, "le gobelin adjacent annonce dès le tour 1")


func test_les_ennemis_ne_bougent_pas_avant_le_premier_tour() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(1, 1), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(7, 5), 2)
	_engine(board).start()
	assert_eq(goblin.cell, Vector2i(7, 5), "la carte les a placés, ils y restent")


func test_le_telegraphe_annonce_les_degats_exacts() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	var announced: int = engine.telegraph()[0]["damage"][0]
	assert_eq(announced, goblin.damage)
	assert_eq(engine.threat_on(hero.cell), announced)
	var before := hero.hit_points
	engine.end_player_turn()
	assert_eq(before - hero.hit_points, announced, "le chiffre annoncé est le chiffre subi")


# --- Le télégraphe suit les poussées --------------------------------------

func test_pousser_l_attaquant_deplace_sa_menace() -> void:
	# La troisième réponse du § 4.2, de bout en bout.
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var lancer := _hero(board, &"lancer", Vector2i(4, 1), 2)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 3)
	var engine := _engine(board)
	engine.start()
	assert_gt(engine.threat_on(hero.cell), 0, "le héros est menacé")

	# Le lancier est au-dessus du gobelin : il le repousse vers le bas,
	# et la menace descend avec lui.
	engine.push_with(lancer, goblin)
	assert_eq(goblin.cell, Vector2i(4, 4), "le gobelin a reculé")
	assert_eq(engine.threat_on(hero.cell), 0, "la case du héros n'est plus visée")
	assert_eq(engine.threat_on(Vector2i(3, 4)), 2, "la menace a suivi, elle n'a pas disparu")

	var before := hero.hit_points
	engine.end_player_turn()
	assert_eq(hero.hit_points, before, "et le coup part effectivement dans le vide")


func test_la_poussee_suit_l_axe_dominant() -> void:
	# En orthogonal, une poussée en biais ne peut pas produire une
	# diagonale : elle suit l'axe le plus long, et x l'emporte à égalité.
	var board := _plain()
	var lancer := _hero(board, &"lancer", Vector2i(3, 2), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	engine.push_with(lancer, goblin)
	assert_eq(goblin.cell, Vector2i(5, 3), "poussé horizontalement, pas en diagonale")


func test_un_ennemi_pousse_dans_la_ligne_d_un_autre_prend_le_coup() -> void:
	# « Pousser un gobelin devient plus intéressant que le tuer » (§ 4.2).
	# Ici on vide la case visée, puis on y pousse un autre ennemi.
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var lancer := _hero(board, &"lancer", Vector2i(3, 1), 2)
	_enemy(board, &"spear_goblin", Vector2i(4, 3), 3)
	var gnome := _enemy(board, &"gnome", Vector2i(3, 2), 4)
	var engine := _engine(board)
	engine.start()
	assert_eq(engine.threat_on(Vector2i(3, 3)), 2, "le gobelin vise la case du héros")

	engine.move_hero(hero, Vector2i(1, 3))
	engine.push_with(lancer, gnome)
	assert_eq(gnome.cell, Vector2i(3, 3), "le gnome a pris la place du héros")
	assert_eq(engine.threat_on(gnome.cell), 2, "et se retrouve dans la ligne de tir")

	engine.end_player_turn()
	assert_true(gnome.is_downed(), "2 PV, 2 dégâts : le gobelin a tué son voisin")
	assert_eq(hero.hit_points, hero.max_hit_points, "et le héros n'a rien pris")


# --- Ordre du tour --------------------------------------------------------

func test_les_ennemis_frappent_avant_de_bouger() -> void:
	# Si l'ordre s'inversait, un ennemi pourrait avancer puis frapper dans
	# le même souffle, et le télégraphe ne vaudrait plus rien.
	var board := _plain()
	_hero(board, &"warrior", Vector2i(3, 3), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	var log := engine.end_player_turn()
	var attack_index := -1
	var move_index := -1
	for i in log.size():
		if log[i]["event"] == "attack_landed" and attack_index < 0:
			attack_index = i
		if log[i]["event"] == "enemy_moved" and move_index < 0:
			move_index = i
	assert_gte(attack_index, 0, "le gobelin a bien frappé")
	if move_index >= 0:
		assert_lt(attack_index, move_index, "frapper vient avant se déplacer")
	assert_eq(goblin.id, 2)


func test_le_tour_avance_et_les_heros_recuperent_leurs_actions() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(1, 1), 1)
	_enemy(board, &"spear_goblin", Vector2i(7, 5), 2)
	var engine := _engine(board)
	engine.start()
	engine.move_hero(hero, Vector2i(2, 1))
	assert_true(hero.has_moved)
	engine.end_player_turn()
	assert_eq(engine.turn_index, 2)
	assert_false(hero.has_moved, "nouveau tour, nouvelles actions")


func test_une_unite_ne_bouge_qu_une_fois_par_tour() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(1, 1), 1)
	_enemy(board, &"spear_goblin", Vector2i(7, 5), 2)
	var engine := _engine(board)
	engine.start()
	assert_true(engine.move_hero(hero, Vector2i(2, 1)))
	assert_false(engine.move_hero(hero, Vector2i(3, 1)), "déjà déplacé")


func test_un_deplacement_illegal_est_refuse() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(1, 1), 1)
	_enemy(board, &"spear_goblin", Vector2i(7, 5), 2)
	var engine := _engine(board)
	engine.start()
	assert_false(engine.move_hero(hero, Vector2i(7, 4)), "hors de portée de déplacement")
	assert_eq(hero.cell, Vector2i(1, 1))
	assert_eq(engine.undo_depth(), 0, "un refus n'empile pas d'annulation")


# --- Fin de combat --------------------------------------------------------

func test_eliminer_le_dernier_ennemi_gagne() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var goblin := _enemy(board, &"gnome", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	engine.attack(hero, goblin)
	assert_true(goblin.is_downed(), "2 PV contre 3 dégâts")
	engine.end_player_turn()
	assert_true(engine.is_finished())
	assert_true(engine.is_victory())


func test_l_escouade_a_terre_perd() -> void:
	var board := _plain()
	var monk := _hero(board, &"monk", Vector2i(3, 3), 1)
	_enemy(board, &"troll", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	monk.take_damage(2)
	engine.end_player_turn()
	assert_true(engine.is_finished())
	assert_false(engine.is_victory())


func test_rien_ne_se_passe_apres_la_fin() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var gnome := _enemy(board, &"gnome", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	engine.attack(hero, gnome)
	engine.end_player_turn()
	assert_eq(engine.end_player_turn(), [] as Array[Dictionary])
	assert_false(engine.move_hero(hero, Vector2i(1, 1)))


# --- Annulation (C1.13) ---------------------------------------------------

func test_annuler_un_deplacement() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(1, 1), 1)
	_enemy(board, &"spear_goblin", Vector2i(7, 5), 2)
	var engine := _engine(board)
	engine.start()
	assert_false(engine.can_undo(), "rien à annuler au début du tour")

	engine.move_hero(hero, Vector2i(3, 1))
	assert_true(engine.can_undo())
	assert_true(engine.undo())
	assert_eq(hero.cell, Vector2i(1, 1))
	assert_false(hero.has_moved, "le droit de bouger est rendu")
	assert_eq(board.unit_at(Vector2i(1, 1)), hero, "et le plateau suit")
	assert_null(board.unit_at(Vector2i(3, 1)))


func test_annuler_une_attaque_rend_les_pv() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	engine.attack(hero, goblin)
	assert_eq(goblin.hit_points, 0)
	assert_true(goblin.is_downed())

	engine.undo()
	assert_eq(goblin.hit_points, 3, "le gobelin est rendu intact")
	assert_true(goblin.is_active())
	assert_eq(board.unit_at(Vector2i(4, 3)), goblin, "et remis sur sa case")
	assert_false(hero.has_acted)


func test_annuler_une_poussee_dans_l_eau_ressuscite() -> void:
	# Le cas le plus lourd : une poussée mortelle doit se défaire
	# entièrement, sinon le bouton Annuler ment.
	var board := _board([
		"........", "........", "...~....", "........", "........", "........",
	])
	var lancer := _hero(board, &"lancer", Vector2i(1, 2), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(2, 2), 2)
	var engine := _engine(board)
	engine.start()
	engine.push_with(lancer, goblin)
	assert_true(goblin.is_downed(), "poussé dans l'eau")

	engine.undo()
	assert_true(goblin.is_active())
	assert_eq(goblin.cell, Vector2i(2, 2))
	assert_eq(goblin.hit_points, 3)
	assert_eq(board.unit_at(Vector2i(2, 2)), goblin)


func test_annuler_plusieurs_fois_de_suite() -> void:
	var board := _plain()
	var a := _hero(board, &"warrior", Vector2i(1, 1), 1)
	var b := _hero(board, &"archer", Vector2i(1, 3), 2)
	_enemy(board, &"spear_goblin", Vector2i(7, 5), 3)
	var engine := _engine(board)
	engine.start()
	engine.move_hero(a, Vector2i(2, 1))
	engine.move_hero(b, Vector2i(2, 3))
	assert_eq(engine.undo_depth(), 2)
	engine.undo()
	assert_eq(b.cell, Vector2i(1, 3))
	assert_eq(a.cell, Vector2i(2, 1), "seule la dernière action est défaite")
	engine.undo()
	assert_eq(a.cell, Vector2i(1, 1))
	assert_false(engine.can_undo())


func test_tout_annuler_ramene_au_debut_du_tour() -> void:
	var board := _plain()
	var a := _hero(board, &"warrior", Vector2i(1, 1), 1)
	var b := _hero(board, &"archer", Vector2i(1, 3), 2)
	_enemy(board, &"spear_goblin", Vector2i(7, 5), 3)
	var engine := _engine(board)
	engine.start()
	engine.move_hero(a, Vector2i(2, 1))
	engine.move_hero(b, Vector2i(2, 3))
	assert_true(engine.undo_all())
	assert_eq(a.cell, Vector2i(1, 1))
	assert_eq(b.cell, Vector2i(1, 3))
	assert_false(engine.can_undo())


func test_la_validation_du_tour_ferme_l_annulation() -> void:
	# C'est la contrepartie de l'annulation libre : on peut tout essayer,
	# mais valider engage.
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(1, 1), 1)
	_enemy(board, &"spear_goblin", Vector2i(7, 5), 2)
	var engine := _engine(board)
	engine.start()
	engine.move_hero(hero, Vector2i(2, 1))
	engine.end_player_turn()
	assert_false(engine.can_undo())
	assert_false(engine.undo())


func test_l_annulation_remet_le_hasard_en_place() -> void:
	# Sans ça, annuler puis rejouer donnerait deux combats différents à
	# partir de la même graine, et la règle 4 tomberait.
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(1, 1), 1)
	_enemy(board, &"spear_goblin", Vector2i(7, 5), 2)
	var engine := _engine(board)
	engine.start()
	var before := engine.rng.position()
	engine.move_hero(hero, Vector2i(2, 1))
	engine.rng.int_between(0, 100, &"test")
	engine.undo()
	assert_eq(engine.rng.position(), before)


func test_un_instantane_et_sa_restauration_sont_fideles() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(1, 1), 1)
	_enemy(board, &"spear_goblin", Vector2i(5, 1), 2)
	var engine := _engine(board)
	engine.start()
	var state := engine.snapshot()
	engine.move_hero(hero, Vector2i(3, 1))
	engine.end_player_turn()
	engine._restore(state)
	assert_eq(engine.turn_index, 1)
	assert_eq(hero.cell, Vector2i(1, 1))
	assert_eq(engine.phase, CombatEngine.Phase.PLAYER_TURN)


func test_un_ennemi_hors_de_portee_n_annonce_rien_au_premier_tour() -> void:
	# Bug attrapé en regardant une capture d'écran, pas en lisant du code :
	# les cases menacées apparaissaient à côté des ennemis, sur du vide.
	# La cause tenait en un mot — l'intention était calculée depuis la case
	# d'ARRIVÉE du plan de déplacement, alors qu'au premier tour personne
	# n'a bougé, et ses décalages sont relatifs à l'attaquant.
	var board := _plain()
	_hero(board, &"warrior", Vector2i(0, 2), 1)
	_hero(board, &"archer", Vector2i(0, 3), 2)
	_enemy(board, &"gnome", Vector2i(6, 2), 3)
	_enemy(board, &"spear_goblin", Vector2i(7, 2), 4)
	var engine := _engine(board)
	engine.start()
	assert_eq(engine.telegraph(), [] as Array[Dictionary],
		"aucun ennemi n'est à portée : rien ne doit être annoncé")
	for cell: Vector2i in board.grid.cells():
		assert_eq(engine.threat_on(cell), 0, "case %s menacée à tort" % cell)


func test_l_annonce_du_premier_tour_vise_la_bonne_case() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(3, 3), 1)
	_enemy(board, &"gnome", Vector2i(5, 3), 2)
	var engine := _engine(board)
	engine.start()
	# Le gnome a un déplacement de 4 : son plan l'amènerait au contact.
	# Mais tant qu'il n'a pas bougé, il n'annonce rien.
	assert_eq(engine.threat_on(hero.cell), 0, "il n'est pas encore à portée")
	engine.end_player_turn()
	assert_gt(engine.threat_on(hero.cell), 0, "après s'être approché, il annonce")
