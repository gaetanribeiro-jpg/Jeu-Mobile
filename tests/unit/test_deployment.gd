extends GutTest

## Le placement initial (décision de Gaetan, 2026-08-29).
##
## La carte propose plus de cases que le joueur n'a de héros : c'est cet
## écart qui fait du placement une décision. Partir groupé ou étalé, près
## de l'eau pour pousser dedans ou loin d'elle pour ne pas y tomber, à
## portée d'un tirailleur pour le faire taire ou hors de portée pour
## encaisser un tour de moins — tout cela se joue avant le premier tour.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _plain() -> CombatBoard:
	return _board(["........", "........", "........", "........", "........", "........"])


func _engine(board: CombatBoard, squad: Array[Unit], cells: Array[Vector2i]) -> CombatEngine:
	var engine := CombatEngine.new(
		board, CombatObjective.from_dictionary({"kind": "eliminate"}), CombatRng.new(7)
	)
	engine.set_deployment(cells, squad)
	engine.start()
	return engine


func _squad() -> Array[Unit]:
	return Unit.squad_from_classes([&"warrior", &"archer", &"mage"])


func _zone() -> Array[Vector2i]:
	return [
		Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
		Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
	] as Array[Vector2i]


func _with_enemy(board: CombatBoard, at: Vector2i, id: int = 200) -> Unit:
	var enemy := Unit.from_enemy(id, &"spear_goblin", at)
	board.place_unit(enemy, at)
	return enemy


func test_le_combat_s_ouvre_sur_le_placement() -> void:
	var board := _plain()
	_with_enemy(board, Vector2i(7, 2))
	var engine := _engine(board, _squad(), _zone())
	assert_true(engine.is_deploying())
	assert_eq(engine.phase, CombatEngine.Phase.DEPLOYMENT)
	assert_eq(engine.pending_heroes().size(), 3, "personne n'est encore posé")
	assert_true(engine.board.active_units(Unit.Side.HEROES).is_empty())


func test_la_zone_offre_plus_de_cases_que_de_heros() -> void:
	# Sans cet écart, le placement ne serait pas un choix mais une formalité.
	var board := _plain()
	_with_enemy(board, Vector2i(7, 2))
	var engine := _engine(board, _squad(), _zone())
	assert_gt(engine.deployment_cells().size(), engine.pending_heroes().size())


func test_poser_un_heros_sur_une_case_proposee() -> void:
	var board := _plain()
	_with_enemy(board, Vector2i(7, 2))
	var engine := _engine(board, _squad(), _zone())
	assert_true(engine.deploy(Vector2i(1, 2)))
	assert_eq(engine.pending_heroes().size(), 2)
	var placed := engine.board.unit_at(Vector2i(1, 2))
	assert_not_null(placed)
	assert_eq(placed.slot, 1, "le premier de la file est posé en premier")


func test_on_choisit_qui_l_on_pose() -> void:
	var board := _plain()
	_with_enemy(board, Vector2i(7, 2))
	var squad := _squad()
	var engine := _engine(board, squad, _zone())
	assert_true(engine.deploy(Vector2i(0, 1), squad[2]), "le Mage d'abord")
	assert_eq(engine.board.unit_at(Vector2i(0, 1)).class_id, &"mage")
	assert_eq(engine.pending_heroes().size(), 2)


func test_on_ne_pose_pas_hors_de_la_zone() -> void:
	var board := _plain()
	_with_enemy(board, Vector2i(7, 2))
	var engine := _engine(board, _squad(), _zone())
	assert_false(engine.deploy(Vector2i(5, 5)), "case hors de la zone proposée")
	assert_eq(engine.pending_heroes().size(), 3)


func test_on_ne_pose_pas_deux_heros_sur_la_meme_case() -> void:
	var board := _plain()
	_with_enemy(board, Vector2i(7, 2))
	var engine := _engine(board, _squad(), _zone())
	engine.deploy(Vector2i(1, 2))
	assert_false(engine.deploy(Vector2i(1, 2)))
	assert_eq(engine.pending_heroes().size(), 2)


func test_reprendre_un_heros_pose() -> void:
	# Rien n'est irréversible tant que le combat n'a pas commencé.
	var board := _plain()
	_with_enemy(board, Vector2i(7, 2))
	var engine := _engine(board, _squad(), _zone())
	engine.deploy(Vector2i(1, 2))
	var placed := engine.board.unit_at(Vector2i(1, 2))
	assert_true(engine.undeploy(placed))
	assert_null(engine.board.unit_at(Vector2i(1, 2)))
	assert_eq(engine.pending_heroes().size(), 3)


func test_un_heros_repris_retrouve_sa_place_dans_la_file() -> void:
	# L'ordre reste celui des emplacements, sinon reprendre un héros
	# rebattrait les cartes et le joueur perdrait le fil.
	var board := _plain()
	_with_enemy(board, Vector2i(7, 2))
	var squad := _squad()
	var engine := _engine(board, squad, _zone())
	engine.deploy(Vector2i(0, 1), squad[0])
	engine.deploy(Vector2i(0, 2), squad[1])
	engine.undeploy(squad[0])
	var pending := engine.pending_heroes()
	assert_eq(pending[0].slot, 1, "le premier emplacement revient en tête")
	assert_eq(pending[1].slot, 3)


func test_annuler_reprend_le_dernier_pose() -> void:
	var board := _plain()
	_with_enemy(board, Vector2i(7, 2))
	var squad := _squad()
	var engine := _engine(board, squad, _zone())
	engine.deploy(Vector2i(0, 1), squad[0])
	engine.deploy(Vector2i(0, 2), squad[2])
	var taken := engine.undeploy_last()
	assert_not_null(taken)
	assert_eq(taken.slot, 3, "le moine, posé en dernier")
	assert_null(engine.board.unit_at(Vector2i(0, 2)))
	assert_eq(engine.board.unit_at(Vector2i(0, 1)), squad[0])


func test_le_combat_ne_commence_pas_avant_que_tous_soient_poses() -> void:
	var board := _plain()
	_with_enemy(board, Vector2i(7, 2))
	var engine := _engine(board, _squad(), _zone())
	assert_false(engine.can_begin_combat())
	assert_false(engine.begin_combat())
	assert_true(engine.is_deploying())

	engine.auto_deploy()
	assert_true(engine.can_begin_combat())
	assert_true(engine.begin_combat())
	assert_false(engine.is_deploying())
	assert_eq(engine.phase, CombatEngine.Phase.ACTIVE)
	assert_eq(engine.round_index(), 1)


func test_le_telegraphe_n_existe_qu_une_fois_le_combat_commence() -> void:
	# Tant que personne n'est posé, aucun ennemi n'a de cible : annoncer
	# quoi que ce soit serait inventer.
	var board := _plain()
	_with_enemy(board, Vector2i(2, 2))
	var squad := _squad()
	var engine := _engine(board, squad, _zone())
	assert_eq(engine.telegraph(), [] as Array[Dictionary])

	# On se pose volontairement au contact : c'est là que l'annonce naît.
	engine.deploy(Vector2i(1, 2), squad[0])
	engine.auto_deploy()
	engine.begin_combat()
	assert_gt(engine.telegraph().size(), 0, "les ennemis annoncent dès le tour 1")
	assert_gt(engine.threat_on(Vector2i(1, 2)), 0, "et visent bien le héros au contact")


func test_les_cases_menacees_sont_connues_avant_de_se_poser() -> void:
	# Le pilier de l'information parfaite vaut aussi avant le premier tour :
	# se poser à portée d'un ennemi doit être un choix, pas un piège.
	var board := _plain()
	_with_enemy(board, Vector2i(2, 2))
	var engine := _engine(board, _squad(), _zone())
	var threatened := engine.threatened_deployment_cells()
	assert_true(threatened.has(Vector2i(1, 2)), "voisine du gobelin")
	assert_false(threatened.has(Vector2i(0, 1)), "hors de sa portée")


func test_on_ne_pose_plus_rien_une_fois_le_combat_commence() -> void:
	var board := _plain()
	_with_enemy(board, Vector2i(7, 2))
	var engine := _engine(board, _squad(), _zone())
	engine.auto_deploy()
	engine.begin_combat()
	assert_false(engine.deploy(Vector2i(0, 1)))
	assert_null(engine.undeploy_last())


func test_sans_zone_le_combat_s_ouvre_directement() -> void:
	# Les tests de moteur posent leurs unités eux-mêmes : ils ne doivent
	# pas avoir à traverser une phase de placement.
	var board := _plain()
	var hero := Unit.from_hero_class(1, &"warrior", Vector2i(1, 1))
	board.place_unit(hero, Vector2i(1, 1))
	_with_enemy(board, Vector2i(7, 2))
	var engine := CombatEngine.new(
		board, CombatObjective.from_dictionary({"kind": "eliminate"}), CombatRng.new(7)
	)
	engine.start()
	assert_false(engine.is_deploying())
	assert_eq(engine.phase, CombatEngine.Phase.ACTIVE)


func test_les_huit_cartes_proposent_un_choix_de_placement() -> void:
	for id: StringName in CombatMap.map_ids():
		var map := CombatMap.load_map(id, CombatRules.ADJACENCY_ORTHOGONAL)
		assert_not_null(map, String(id))
		if map == null:
			continue
		assert_gt(
			map.deployment_cells.size(), CombatRules.max_heroes(),
			"%s : autant de cases que de héros, donc aucun choix" % id
		)
		for cell: Vector2i in map.deployment_cells:
			assert_true(map.board.tile_at(cell).is_walkable(), "%s : %s" % [id, cell])
