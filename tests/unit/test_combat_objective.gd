extends GutTest

## Les six objectifs du § 4.5. Chacun est testé sur sa victoire, et sur sa
## défaite quand il en a une propre.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _plain() -> CombatBoard:
	return _board(["........", "........", "........", "........", "........", "........"])


func _hero(board: CombatBoard, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_hero_class(id, &"warrior", at)
	board.place_unit(unit, at)
	return unit


func _goblin(board: CombatBoard, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_stats(
		id, &"spear_goblin", Unit.Side.ENEMIES, at,
		{"hit_points": 3, "movement": 3, "range_min": 1, "range_max": 1, "damage": 2}
	)
	board.place_unit(unit, at)
	return unit


func test_toute_l_escouade_a_terre_est_une_defaite_quel_que_soit_l_objectif() -> void:
	for kind: String in ["eliminate", "survive", "escort", "protect", "seize", "extract"]:
		var board := _plain()
		var hero := _hero(board, Vector2i(1, 1), 1)
		hero.down()
		var objective := CombatObjective.from_dictionary({"kind": kind, "turns": 99})
		assert_eq(
			objective.evaluate(board, 1), CombatObjective.Outcome.DEFEAT,
			"objectif « %s » : escouade à terre" % kind
		)


func test_eliminer() -> void:
	var board := _plain()
	_hero(board, Vector2i(1, 1), 1)
	var goblin := _goblin(board, Vector2i(5, 1), 2)
	var objective := CombatObjective.from_dictionary({"kind": "eliminate"})
	assert_eq(objective.evaluate(board, 1), CombatObjective.Outcome.ONGOING)
	goblin.down()
	board.remove_from_board(goblin)
	assert_eq(objective.evaluate(board, 1), CombatObjective.Outcome.VICTORY)


func test_survivre_quatre_tours() -> void:
	var board := _plain()
	_hero(board, Vector2i(1, 1), 1)
	_goblin(board, Vector2i(5, 1), 2)
	var objective := CombatObjective.from_dictionary({"kind": "survive", "turns": 4})
	assert_eq(objective.evaluate(board, 3), CombatObjective.Outcome.ONGOING)
	assert_eq(objective.evaluate(board, 4), CombatObjective.Outcome.VICTORY,
		"tenir 4 tours suffit, les ennemis restent sur le terrain")


func test_survivre_prend_son_defaut_dans_les_donnees() -> void:
	var objective := CombatObjective.from_dictionary({"kind": "survive"})
	assert_eq(objective.turns, int(CombatRules.rule(&"objectives", &"survive_default_turns", 0)))


func test_escorter_un_pion_jusqu_au_bord() -> void:
	var board := _plain()
	_hero(board, Vector2i(1, 1), 1)
	var pawn := Unit.from_hero_class(2, &"monk", Vector2i(1, 3))
	board.place_unit(pawn, Vector2i(1, 3))
	var objective := CombatObjective.from_dictionary({
		"kind": "escort", "subject_ids": [2], "cells": [[7, 3], [7, 4]],
	})
	assert_eq(objective.evaluate(board, 1), CombatObjective.Outcome.ONGOING)
	board.move_unit(pawn, Vector2i(7, 3))
	assert_eq(objective.evaluate(board, 1), CombatObjective.Outcome.VICTORY)


func test_escorter_perdu_si_l_escorte_tombe() -> void:
	var board := _plain()
	_hero(board, Vector2i(1, 1), 1)
	var pawn := Unit.from_hero_class(2, &"monk", Vector2i(1, 3))
	board.place_unit(pawn, Vector2i(1, 3))
	var objective := CombatObjective.from_dictionary({
		"kind": "escort", "subject_ids": [2], "cells": [[7, 3]],
	})
	pawn.down()
	assert_eq(objective.evaluate(board, 1), CombatObjective.Outcome.DEFEAT)


func test_proteger_une_structure() -> void:
	var board := _board([
		"........", "...=....", "........", "........", "........", "........",
	])
	_hero(board, Vector2i(1, 1), 1)
	var objective := CombatObjective.from_dictionary({
		"kind": "protect", "turns": 4, "protected_cells": [[3, 1]],
	})
	assert_eq(objective.evaluate(board, 2), CombatObjective.Outcome.ONGOING)
	assert_eq(objective.evaluate(board, 4), CombatObjective.Outcome.VICTORY)


func test_proteger_perdu_si_la_structure_cede() -> void:
	var board := _board([
		"........", "...=....", "........", "........", "........", "........",
	])
	_hero(board, Vector2i(1, 1), 1)
	var objective := CombatObjective.from_dictionary({
		"kind": "protect", "turns": 4, "protected_cells": [[3, 1]],
	})
	board.tile_at(Vector2i(3, 1)).damage_structure(2)
	assert_eq(objective.evaluate(board, 1), CombatObjective.Outcome.DEFEAT)
	assert_eq(objective.evaluate(board, 4), CombatObjective.Outcome.DEFEAT,
		"la structure détruite ne se répare pas au tour limite")


func test_saisir_une_case_avant_le_tour_limite() -> void:
	var board := _plain()
	var hero := _hero(board, Vector2i(1, 1), 1)
	var objective := CombatObjective.from_dictionary({
		"kind": "seize", "cells": [[6, 4]], "deadline": 5,
	})
	assert_eq(objective.evaluate(board, 1), CombatObjective.Outcome.ONGOING)
	board.move_unit(hero, Vector2i(6, 4))
	assert_eq(objective.evaluate(board, 3), CombatObjective.Outcome.VICTORY)


func test_saisir_perdu_au_tour_limite() -> void:
	var board := _plain()
	_hero(board, Vector2i(1, 1), 1)
	var objective := CombatObjective.from_dictionary({
		"kind": "seize", "cells": [[6, 4]], "deadline": 5,
	})
	assert_eq(objective.evaluate(board, 4), CombatObjective.Outcome.ONGOING)
	assert_eq(objective.evaluate(board, 5), CombatObjective.Outcome.DEFEAT)


func test_extraire_demande_d_avoir_ramasse_avant_de_sortir() -> void:
	var board := _plain()
	var hero := _hero(board, Vector2i(1, 1), 1)
	var objective := CombatObjective.from_dictionary({"kind": "extract", "cells": [[0, 0]]})
	board.move_unit(hero, Vector2i(0, 0))
	assert_eq(objective.evaluate(board, 1), CombatObjective.Outcome.ONGOING,
		"sortir les mains vides ne gagne rien")
	objective.carried = true
	assert_eq(objective.evaluate(board, 1), CombatObjective.Outcome.VICTORY)


func test_un_ennemi_sur_la_case_de_saisie_ne_compte_pas() -> void:
	var board := _plain()
	_hero(board, Vector2i(1, 1), 1)
	_goblin(board, Vector2i(6, 4), 2)
	var objective := CombatObjective.from_dictionary({"kind": "seize", "cells": [[6, 4]]})
	assert_eq(objective.evaluate(board, 1), CombatObjective.Outcome.ONGOING)


func test_un_objectif_inconnu_ne_plante_pas() -> void:
	var objective := CombatObjective.from_dictionary({"kind": "danser"})
	assert_eq(objective.kind, CombatObjective.Kind.ELIMINATE, "on retombe sur le plus simple")
	assert_push_error("type d'objectif inconnu")


func test_le_nom_du_type_fait_l_aller_retour() -> void:
	for name_: String in ["eliminate", "survive", "escort", "protect", "seize", "extract"]:
		assert_eq(CombatObjective.from_dictionary({"kind": name_}).kind_name(), name_)
