extends GutTest

## C1.24 — les quatre capacités du § 3.1.
##
## Elles couvrent les quatre verbes tactiques : attirer, frapper à
## distance, déplacer, annuler. Chacune est testée sur son effet, et sur
## ce qu'elle refuse de faire.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _plain() -> CombatBoard:
	return _board(["........", "........", "........", "........", "........", "........"])


func _engine(board: CombatBoard) -> CombatEngine:
	return CombatEngine.new(
		board, CombatObjective.from_dictionary({"kind": "eliminate"}), CombatRng.new(77)
	)


func _hero(board: CombatBoard, class_id: StringName, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_hero_class(id, class_id, at)
	board.place_unit(unit, at)
	return unit


func _enemy(board: CombatBoard, enemy_id: StringName, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_enemy(id, enemy_id, at)
	board.place_unit(unit, at)
	return unit


func test_chaque_classe_a_sa_capacite_et_son_verbe() -> void:
	var expected := {
		&"warrior": [&"taunt", "attirer"],
		&"archer": [&"aimed_shot", "frapper à distance"],
		&"lancer": [&"push_back", "déplacer"],
		&"monk": [&"blessing", "annuler"],
	}
	for class_id: StringName in expected.keys():
		var ability_id := Ability.first_of_class(class_id)
		assert_eq(ability_id, expected[class_id][0], "capacité de %s" % class_id)
		assert_eq(
			Ability.get_ability(ability_id)["verb"], expected[class_id][1],
			"verbe tactique de %s" % class_id
		)


func test_les_quatre_verbes_sont_tous_couverts_une_fois() -> void:
	# « Toute la profondeur du combat vient de leurs combinaisons » (§ 3.1).
	# Deux classes qui feraient le même verbe seraient redondantes.
	var verbs := {}
	for class_id: StringName in [&"warrior", &"archer", &"lancer", &"monk"]:
		var verb: String = Ability.get_ability(Ability.first_of_class(class_id))["verb"]
		assert_false(verbs.has(verb), "le verbe « %s » est doublé" % verb)
		verbs[verb] = class_id
	assert_eq(verbs.size(), 4)


# --- Provocation ----------------------------------------------------------

func test_la_provocation_redirige_un_ennemi_adjacent() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var archer := _hero(board, &"archer", Vector2i(3, 4), 2)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 5), 3)
	var engine := _engine(board)
	engine.start()
	# Le gobelin vise naturellement l'archer, plus proche et plus fragile.
	assert_gt(engine.threat_on(archer.cell), 0)

	# Le guerrier se met au contact et provoque.
	engine.move_hero(warrior, Vector2i(2, 5))
	engine.use_ability(warrior, &"taunt")
	assert_true(engine.is_taunting(warrior.id))
	assert_eq(engine.threat_on(archer.cell), 0, "l'archer n'est plus visé")
	assert_gt(engine.threat_on(warrior.cell), 0, "c'est le guerrier qui prend")
	assert_eq(goblin.id, 3)


func test_la_provocation_ne_porte_pas_a_distance() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(0, 0), 1)
	var archer := _hero(board, &"archer", Vector2i(4, 4), 2)
	_enemy(board, &"spear_goblin", Vector2i(5, 4), 3)
	var engine := _engine(board)
	engine.start()
	engine.use_ability(warrior, &"taunt")
	assert_gt(engine.threat_on(archer.cell), 0, "le guerrier est trop loin pour couvrir")


func test_la_provocation_ne_dure_qu_un_tour() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	_enemy(board, &"spear_goblin", Vector2i(3, 4), 2)
	var engine := _engine(board)
	engine.start()
	engine.use_ability(warrior, &"taunt")
	assert_true(engine.is_taunting(warrior.id))
	engine.end_player_turn()
	assert_false(engine.is_taunting(warrior.id), "il faut la refaire chaque tour")


# --- Tir tendu ------------------------------------------------------------

func test_le_tir_tendu_ajoute_deux_degats() -> void:
	var board := _plain()
	var archer := _hero(board, &"archer", Vector2i(1, 3), 1)
	var troll := _enemy(board, &"troll", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	var before := troll.hit_points
	var report := engine.use_ability(archer, &"aimed_shot", troll)
	assert_eq(report["damage"], 4, "2 de base, +2 pour être resté immobile")
	assert_eq(before - troll.hit_points, 4)


func test_le_tir_tendu_est_refuse_apres_un_deplacement() -> void:
	# C'est ce qui rend l'immobilité tentante, et donc le Voleur dangereux.
	var board := _plain()
	var archer := _hero(board, &"archer", Vector2i(1, 3), 1)
	var troll := _enemy(board, &"troll", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	engine.move_hero(archer, Vector2i(2, 3))
	assert_eq(engine.use_ability(archer, &"aimed_shot", troll), {})
	assert_eq(troll.hit_points, troll.max_hit_points)


func test_le_tir_tendu_respecte_la_portee_minimale() -> void:
	var board := _plain()
	var archer := _hero(board, &"archer", Vector2i(3, 3), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	assert_eq(engine.use_ability(archer, &"aimed_shot", goblin), {}, "trop près pour tirer")


# --- Repousse -------------------------------------------------------------

func test_la_repousse_deplace_d_une_case() -> void:
	var board := _plain()
	var lancer := _hero(board, &"lancer", Vector2i(3, 3), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	var report := engine.use_ability(lancer, &"push_back", goblin)
	assert_eq(report["ability"], "push_back")
	assert_eq(goblin.cell, Vector2i(5, 3))


func test_la_repousse_dans_l_eau_tue() -> void:
	var board := _board([
		"........", "........", "........", "....~...", "........", "........",
	])
	var lancer := _hero(board, &"lancer", Vector2i(2, 3), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 3), 2)
	var engine := _engine(board)
	engine.start()
	var report := engine.use_ability(lancer, &"push_back", goblin)
	assert_true(report["drowns"])
	assert_true(goblin.is_downed())


func test_la_repousse_ne_porte_pas_hors_de_portee() -> void:
	var board := _plain()
	var lancer := _hero(board, &"lancer", Vector2i(0, 3), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(5, 3), 2)
	var engine := _engine(board)
	engine.start()
	assert_eq(engine.use_ability(lancer, &"push_back", goblin), {})
	assert_eq(goblin.cell, Vector2i(5, 3))


# --- Bénédiction ----------------------------------------------------------

func test_la_benediction_annule_une_attaque_telegraphiee() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var monk := _hero(board, &"monk", Vector2i(3, 2), 2)
	_enemy(board, &"spear_goblin", Vector2i(4, 3), 3)
	var engine := _engine(board)
	engine.start()
	assert_gt(engine.threat_on(warrior.cell), 0)

	assert_false(engine.use_ability(monk, &"blessing", warrior.cell).is_empty())
	assert_true(engine.is_warded(warrior.cell))

	var before := warrior.hit_points
	var log := engine.end_player_turn()
	assert_eq(warrior.hit_points, before, "le coup est annulé")
	var warded_events := 0
	for entry: Dictionary in log:
		if entry["event"] == "attack_warded":
			warded_events += 1
	assert_eq(warded_events, 1, "et le journal le dit")


func test_la_benediction_ne_couvre_que_sa_case() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var monk := _hero(board, &"monk", Vector2i(3, 2), 2)
	_enemy(board, &"spear_goblin", Vector2i(4, 3), 3)
	var engine := _engine(board)
	engine.start()
	engine.use_ability(monk, &"blessing", Vector2i(0, 0))
	var before := warrior.hit_points
	engine.end_player_turn()
	assert_lt(warrior.hit_points, before, "la mauvaise case n'a rien protégé")


func test_la_benediction_respecte_sa_portee() -> void:
	var board := _plain()
	var monk := _hero(board, &"monk", Vector2i(0, 0), 1)
	_enemy(board, &"spear_goblin", Vector2i(7, 5), 2)
	var engine := _engine(board)
	engine.start()
	assert_eq(engine.use_ability(monk, &"blessing", Vector2i(7, 5)), {}, "hors de portée")
	assert_eq(engine.use_ability(monk, &"blessing", Vector2i(0, 0)), {}, "pas sa propre case")


func test_la_benediction_ne_dure_qu_un_tour() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var monk := _hero(board, &"monk", Vector2i(3, 2), 2)
	_enemy(board, &"spear_goblin", Vector2i(4, 3), 3)
	var engine := _engine(board)
	engine.start()
	engine.use_ability(monk, &"blessing", warrior.cell)
	engine.end_player_turn()
	assert_false(engine.is_warded(warrior.cell))


# --- Règles communes ------------------------------------------------------

func test_une_capacite_consomme_l_action_du_tour() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	engine.use_ability(warrior, &"taunt")
	assert_true(warrior.has_acted)
	assert_eq(engine.attack(warrior, goblin), {}, "on n'agit qu'une fois")


func test_toute_capacite_est_annulable() -> void:
	# Rien n'est irréversible avant validation (§ 11.2), les capacités
	# comprises — c'est là qu'on essaie des combinaisons.
	var board := _plain()
	var lancer := _hero(board, &"lancer", Vector2i(3, 3), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	engine.use_ability(lancer, &"push_back", goblin)
	assert_eq(goblin.cell, Vector2i(5, 3))
	engine.undo()
	assert_eq(goblin.cell, Vector2i(4, 3))
	assert_false(lancer.has_acted)


func test_annuler_une_provocation_rend_l_annonce_d_origine() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 4), 1)
	var archer := _hero(board, &"archer", Vector2i(3, 3), 2)
	_enemy(board, &"spear_goblin", Vector2i(3, 5), 3)
	var engine := _engine(board)
	engine.start()
	var threat_before := engine.threat_on(archer.cell)
	engine.use_ability(warrior, &"taunt")
	engine.undo()
	assert_false(engine.is_taunting(warrior.id))
	assert_eq(engine.threat_on(archer.cell), threat_before, "l'annonce est revenue")


func test_une_capacite_inconnue_ne_plante_pas() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	_enemy(board, &"spear_goblin", Vector2i(4, 3), 2)
	var engine := _engine(board)
	engine.start()
	assert_eq(engine.use_ability(warrior, &"boule_de_feu"), {})
	assert_push_error("capacité inconnue")
