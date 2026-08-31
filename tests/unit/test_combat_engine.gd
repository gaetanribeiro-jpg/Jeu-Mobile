extends GutTest

## T1.6 — la machine à états : la timeline d'initiative, les PA, les PM,
## et l'annulation.
##
## Les initiatives sont forcées à la main dans la plupart de ces tests. Ce
## n'est pas de la triche : la timeline est le sujet, et un test qui
## dépend des chiffres d'équilibrage casserait à chaque réglage.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _plain() -> CombatBoard:
	return _board([
		"..........", "..........", "..........", "..........",
		"..........", "..........", "..........", "..........",
	])


func _engine(board: CombatBoard, objective_data: Dictionary = {}) -> CombatEngine:
	var data := objective_data if not objective_data.is_empty() else {"kind": "eliminate"}
	return CombatEngine.new(
		board, CombatObjective.from_dictionary(data), CombatRng.new(4242)
	)


## Un héros qui joue toujours en premier : la timeline est un sujet à
## part, testée dans test_turn_order.gd.
func _hero(
	board: CombatBoard, class_id: StringName, at: Vector2i, id: int,
	initiative: int = 50
) -> Unit:
	var unit := Unit.from_hero_class(id, class_id, at)
	unit.initiative = initiative
	board.place_unit(unit, at)
	return unit


func _enemy(
	board: CombatBoard, enemy_id: StringName, at: Vector2i, id: int,
	initiative: int = 1
) -> Unit:
	var unit := Unit.from_enemy(id, enemy_id, at)
	unit.initiative = initiative
	board.place_unit(unit, at)
	return unit


# --- Ouverture ------------------------------------------------------------

func test_le_telegraphe_est_pose_des_la_premiere_activation() -> void:
	# Sans ça, le joueur n'aurait rien à contrer avant la deuxième ronde.
	var board := _plain()
	_hero(board, &"warrior", Vector2i(3, 3), 1)
	_enemy(board, &"spear_goblin", Vector2i(4, 3), 90)
	var engine := _engine(board)
	engine.start()
	assert_eq(engine.telegraph().size(), 1)


func test_les_ennemis_ne_bougent_pas_avant_la_premiere_activation() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(0, 0), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(7, 3), 90)
	_engine(board).start()
	assert_eq(goblin.cell, Vector2i(7, 3))


func test_le_combat_s_ouvre_sur_le_plus_rapide() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(3, 3), 1, 4)
	var fast := _hero(board, &"archer", Vector2i(2, 3), 2, 9)
	_enemy(board, &"spear_goblin", Vector2i(6, 3), 90, 5)
	var engine := _engine(board)
	engine.start()
	assert_eq(engine.current_unit().id, fast.id)
	assert_true(engine.is_player_turn())
	assert_eq(engine.round_index(), 1)


func test_un_ennemi_plus_rapide_joue_avant_que_le_joueur_touche_a_rien() -> void:
	# Le Voleur a 9 d'initiative, plus que n'importe quel héros. Son
	# activation doit partir dans le journal d'ouverture, sinon la vue ne
	# la rejoue jamais et le joueur voit ses PV baisser sans explication.
	var board := _plain()
	_hero(board, &"warrior", Vector2i(3, 3), 1, 4)
	_enemy(board, &"thief", Vector2i(5, 3), 90, 20)
	var engine := _engine(board)
	engine.start()

	assert_true(engine.is_player_turn(), "la main revient au joueur")
	var log := engine.take_opening_log()
	assert_false(log.is_empty(), "l'ennemi rapide a joué")
	var seen := false
	for entry: Dictionary in log:
		if String(entry["event"]) == "activation_started" and int(entry["unit_id"]) == 90:
			seen = true
	assert_true(seen, "l'activation du Voleur est dans le journal")


func test_la_timeline_montre_qui_joue_ensuite() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(3, 3), 1, 8)
	_hero(board, &"archer", Vector2i(2, 3), 2, 4)
	_enemy(board, &"spear_goblin", Vector2i(6, 3), 90, 6)
	var engine := _engine(board)
	engine.start()
	assert_eq(engine.timeline(3), [1, 90, 2])


# --- Télégraphe -----------------------------------------------------------

func test_le_telegraphe_annonce_les_degats_exacts() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	_enemy(board, &"spear_goblin", Vector2i(4, 3), 90)
	var engine := _engine(board)
	engine.start()

	var announced := engine.threat_on(warrior.cell)
	assert_gt(announced, 0)
	var before := warrior.hit_points
	engine.end_activation()
	assert_eq(before - warrior.hit_points, announced, "le télégraphe ne ment pas")


func test_l_annonce_vise_la_bonne_case() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 90)
	var engine := _engine(board)
	engine.start()
	assert_eq(
		engine.intent_of(goblin.id).target_cell(goblin.cell), warrior.cell
	)


func test_un_ennemi_hors_de_portee_n_annonce_rien() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(0, 0), 1)
	_enemy(board, &"spear_goblin", Vector2i(9, 7), 90)
	var engine := _engine(board)
	engine.start()
	assert_true(engine.telegraph().is_empty())


func test_sortir_de_la_case_annoncee_evite_le_coup() -> void:
	# C'est la première des réponses au télégraphe, et la plus simple.
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	_enemy(board, &"spear_goblin", Vector2i(5, 3), 90)
	var engine := _engine(board)
	engine.start()
	assert_gt(engine.threat_on(warrior.cell), 0)

	assert_true(engine.move(warrior, Vector2i(1, 3)))
	var before := warrior.hit_points
	engine.end_activation()
	assert_eq(warrior.hit_points, before, "le coup est parti dans le vide")


func test_les_ennemis_frappent_avant_de_bouger() -> void:
	# C'est ce qui rend le télégraphe honnête : un ennemi ne peut pas
	# bouger puis frapper dans le même souffle.
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	_enemy(board, &"spear_goblin", Vector2i(4, 3), 90)
	var engine := _engine(board)
	engine.start()

	var log := engine.end_activation()
	var attack_at := -1
	var move_at := -1
	for i in log.size():
		var name_ := String(log[i]["event"])
		if name_ == "attack_landed" and attack_at < 0:
			attack_at = i
		if name_ == "enemy_moved" and move_at < 0:
			move_at = i
	assert_gt(attack_at, -1, "le gobelin a frappé")
	if move_at >= 0:
		assert_lt(attack_at, move_at, "il a frappé avant de bouger")
	assert_eq(warrior.hit_points < warrior.max_hit_points, true)


# --- PA, PM et activations ------------------------------------------------

func test_chacun_retrouve_ses_pa_et_ses_pm_a_son_activation() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1, 9)
	_hero(board, &"archer", Vector2i(2, 3), 2, 8)
	_enemy(board, &"spear_goblin", Vector2i(9, 7), 90, 1)
	var engine := _engine(board)
	engine.start()

	warrior.spend_action_points(3)
	warrior.spend_movement_points(2)
	engine.end_activation()
	assert_eq(engine.current_unit().id, 2, "au tour de l'Archer")
	# Une seule validation de plus : le gobelin est joué par le moteur
	# dans la foulée, la main ne revient qu'au héros suivant.
	engine.end_activation()
	assert_eq(engine.round_index(), 2)
	assert_eq(engine.current_unit().id, 1)
	assert_eq(warrior.action_points, warrior.max_action_points)
	assert_eq(warrior.movement_points, warrior.max_movement_points)


func test_on_peut_bouger_frapper_puis_bouger_encore() -> void:
	# Le tour du § 14. Si ce test tombe, le modèle PA/PM ne sert à rien.
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(0, 3), 1, 9)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 3), 90, 1)
	var engine := _engine(board)
	engine.start()

	assert_true(engine.move(warrior, Vector2i(2, 3)), "deux pas")
	assert_false(engine.use_ability(warrior, &"strike", goblin.cell).is_empty(), "un coup")
	assert_true(engine.move(warrior, Vector2i(2, 4)), "et un pas de plus")
	assert_eq(warrior.movement_points, warrior.max_movement_points - 3)


func test_on_ne_bouge_pas_plus_loin_que_ses_pm() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(0, 0), 1, 9)
	_enemy(board, &"spear_goblin", Vector2i(9, 7), 90, 1)
	var engine := _engine(board)
	engine.start()

	warrior.spend_movement_points(warrior.movement_points)
	assert_false(engine.move(warrior, Vector2i(1, 0)), "plus un seul PM")


func test_le_joueur_ne_pilote_que_le_personnage_designe() -> void:
	# Avec la timeline, il n'y a plus de sélection : le moteur l'a faite.
	var board := _plain()
	_hero(board, &"warrior", Vector2i(3, 3), 1, 9)
	var other := _hero(board, &"archer", Vector2i(2, 3), 2, 4)
	_enemy(board, &"spear_goblin", Vector2i(9, 7), 90, 1)
	var engine := _engine(board)
	engine.start()

	assert_false(engine.move(other, Vector2i(2, 4)), "ce n'est pas son tour")
	assert_eq(other.cell, Vector2i(2, 3))


func test_un_deplacement_illegal_est_refuse() -> void:
	var board := _board([
		"..........", "..........", "....#.....",
		"..........", "..........", "..........",
	])
	var warrior := _hero(board, &"warrior", Vector2i(4, 1), 1, 9)
	_enemy(board, &"spear_goblin", Vector2i(9, 5), 90, 1)
	var engine := _engine(board)
	engine.start()
	assert_false(engine.move(warrior, Vector2i(4, 2)), "un rocher")
	assert_false(engine.move(warrior, Vector2i(0, 5)), "trop loin")
	assert_eq(warrior.cell, Vector2i(4, 1))


# --- Fin de combat --------------------------------------------------------

func test_eliminer_le_dernier_ennemi_gagne() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1, 9)
	var goblin := _enemy(board, &"gnome", Vector2i(4, 3), 90, 1)
	var engine := _engine(board)
	engine.start()

	while goblin.is_active() and warrior.action_points >= 3:
		engine.use_ability(warrior, &"strike", goblin.cell)
	assert_true(goblin.is_downed(), "le gnome est tombé")
	engine.end_activation()
	assert_true(engine.is_finished())
	assert_true(engine.is_victory())


func test_l_equipe_a_terre_perd() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1, 9)
	_enemy(board, &"spear_goblin", Vector2i(4, 3), 90, 1)
	var engine := _engine(board)
	engine.start()

	warrior.down()
	board.remove_from_board(warrior)
	engine.end_activation()
	assert_true(engine.is_finished())
	assert_false(engine.is_victory())


func test_rien_ne_se_passe_apres_la_fin() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1, 9)
	_enemy(board, &"spear_goblin", Vector2i(4, 3), 90, 1)
	var engine := _engine(board)
	engine.start()
	warrior.down()
	board.remove_from_board(warrior)
	engine.end_activation()
	assert_true(engine.end_activation().is_empty())
	assert_null(engine.current_unit())


func test_un_combat_finit_toujours() -> void:
	# Garde-fou : sans plafond de rondes, une escorte qu'on n'avance pas
	# tournerait sans fin.
	var board := _plain()
	_hero(board, &"warrior", Vector2i(0, 0), 1, 9)
	_enemy(board, &"spear_goblin", Vector2i(9, 7), 90, 1)
	var engine := _engine(board, {"kind": "escort", "subject_ids": [1], "cells": [[9, 0]]})
	engine.start()
	var guard := 0
	while not engine.is_finished() and guard < 200:
		engine.end_activation()
		guard += 1
	assert_true(engine.is_finished(), "le combat s'est arrêté tout seul")


# --- Annulation -----------------------------------------------------------

func test_annuler_un_deplacement() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1, 9)
	_enemy(board, &"spear_goblin", Vector2i(9, 7), 90, 1)
	var engine := _engine(board)
	engine.start()

	assert_false(engine.can_undo(), "rien à annuler au départ")
	engine.move(warrior, Vector2i(3, 4))
	assert_true(engine.can_undo())
	assert_true(engine.undo())
	assert_eq(warrior.cell, Vector2i(3, 3))
	assert_eq(warrior.movement_points, warrior.max_movement_points, "les PM sont rendus")
	assert_false(warrior.has_moved)


func test_annuler_une_attaque_rend_les_pv_et_les_pa() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1, 9)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 90, 1)
	var engine := _engine(board)
	engine.start()

	engine.use_ability(warrior, &"strike", goblin.cell)
	assert_lt(goblin.hit_points, goblin.max_hit_points)
	assert_true(engine.undo())
	assert_eq(goblin.hit_points, goblin.max_hit_points)
	assert_eq(warrior.action_points, warrior.max_action_points)


func test_annuler_plusieurs_fois_de_suite() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(0, 3), 1, 9)
	_enemy(board, &"spear_goblin", Vector2i(9, 7), 90, 1)
	var engine := _engine(board)
	engine.start()

	engine.move(warrior, Vector2i(1, 3))
	engine.move(warrior, Vector2i(2, 3))
	assert_eq(engine.undo_depth(), 2)
	engine.undo()
	assert_eq(warrior.cell, Vector2i(1, 3))
	engine.undo()
	assert_eq(warrior.cell, Vector2i(0, 3))
	assert_false(engine.can_undo())


func test_tout_annuler_ramene_au_debut_de_l_activation() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(0, 3), 1, 9)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 3), 90, 1)
	var engine := _engine(board)
	engine.start()

	engine.move(warrior, Vector2i(2, 3))
	engine.use_ability(warrior, &"strike", goblin.cell)
	assert_true(engine.undo_all())
	assert_eq(warrior.cell, Vector2i(0, 3))
	assert_eq(goblin.hit_points, goblin.max_hit_points)
	assert_eq(warrior.action_points, warrior.max_action_points)
	assert_false(engine.can_undo())


func test_valider_l_activation_ferme_l_annulation() -> void:
	# La contrepartie de l'annulation libre : une fois validée, c'est joué.
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(0, 3), 1, 9)
	_enemy(board, &"spear_goblin", Vector2i(9, 7), 90, 1)
	var engine := _engine(board)
	engine.start()

	engine.move(warrior, Vector2i(1, 3))
	engine.end_activation()
	assert_false(engine.can_undo())
	assert_eq(engine.undo_depth(), 0)


func test_l_annulation_remet_le_hasard_en_place() -> void:
	# Sans ça, annuler puis rejouer donnerait un autre résultat, et le
	# rejeu d'un bug à graine fixe deviendrait impossible.
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(0, 3), 1, 9)
	_enemy(board, &"spear_goblin", Vector2i(9, 7), 90, 1)
	var engine := _engine(board)
	engine.start()

	engine.move(warrior, Vector2i(1, 3))
	var before := engine.rng.position()
	engine.rng.int_between(0, 100, &"test")
	engine.undo()
	assert_eq(engine.rng.position(), before)


func test_un_instantane_et_sa_restauration_sont_fideles() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(0, 3), 1, 9)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 3), 90, 1)
	var engine := _engine(board)
	engine.start()

	var state := engine.snapshot()
	engine.move(warrior, Vector2i(2, 3))
	engine.use_ability(warrior, &"strike", goblin.cell)
	engine._restore(state)

	assert_eq(warrior.cell, Vector2i(0, 3))
	assert_eq(goblin.hit_points, goblin.max_hit_points)
	assert_eq(engine.round_index(), 1)
	assert_eq(engine.current_unit().id, warrior.id)
