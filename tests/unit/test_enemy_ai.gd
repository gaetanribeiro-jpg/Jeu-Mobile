extends GutTest

## C1.10 — l'IA ennemie.
##
## Ce qu'on vérifie n'est pas « l'IA joue bien », qui ne se teste pas, mais
## trois propriétés qui doivent tenir sinon le jeu ment :
##   1. elle ne peut pas frapper sans avoir annoncé ;
##   2. elle n'annonce jamais une attaque qu'elle ne peut pas porter ;
##   3. à graine et situation identiques, elle décide la même chose.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _plain() -> CombatBoard:
	return _board(["........", "........", "........", "........", "........", "........"])


func _hero(board: CombatBoard, class_id: StringName, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_hero_class(id, class_id, at)
	board.place_unit(unit, at)
	return unit


func _enemy(board: CombatBoard, enemy_id: StringName, at: Vector2i, id: int) -> Unit:
	var unit := Unit.from_enemy(id, enemy_id, at)
	board.place_unit(unit, at)
	return unit


func _ai() -> EnemyAI:
	return EnemyAI.new(CombatRng.new(1234))


func test_les_six_ennemis_de_l_acte_i_sont_declares() -> void:
	var ids := Unit.enemy_ids()
	assert_eq(ids.size(), 6)
	for expected: StringName in [
		&"spear_goblin", &"gnome", &"slingshot_gnome", &"torch_goblin", &"thief", &"troll"
	]:
		assert_true(ids.has(expected), "ennemi manquant : %s" % expected)


func test_chaque_ennemi_a_un_role() -> void:
	for id: StringName in Unit.enemy_ids():
		var unit := Unit.from_enemy(1, id, Vector2i.ZERO)
		assert_ne(unit.role, &"", "%s n'a pas de rôle" % id)


func test_le_corps_a_corps_se_rapproche_puis_annonce() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(1, 1), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(7, 1), 2)
	var plan := _ai().plan(board, goblin)
	assert_lt(
		board.grid.distance(plan["move_to"], hero.cell),
		board.grid.distance(Vector2i(7, 1), hero.cell),
		"le gobelin doit se rapprocher"
	)
	assert_eq(plan["target_id"], hero.id)


func test_une_attaque_annoncee_est_toujours_portable() -> void:
	# La propriété qui empêche le télégraphe de mentir : si l'IA annonce,
	# c'est qu'elle peut le faire depuis la case où elle arrive.
	for enemy_id: StringName in Unit.enemy_ids():
		var board := _plain()
		var hero := _hero(board, &"warrior", Vector2i(3, 3), 1)
		var enemy := _enemy(board, enemy_id, Vector2i(5, 3), 2)
		var plan := _ai().plan(board, enemy)
		var intent: CombatIntent = plan["intent"]
		if not intent.is_attack():
			continue
		board.move_unit(enemy, plan["move_to"])
		var distance := board.grid.distance(enemy.cell, hero.cell)
		assert_between(
			distance, enemy.range_min, board.effective_range_max(enemy),
			"%s annonce une attaque hors de portée" % enemy_id
		)


func test_l_ia_n_annonce_rien_si_elle_ne_peut_pas_atteindre() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(0, 0), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(7, 5), 2)
	var plan := _ai().plan(board, goblin)
	assert_false(plan["intent"].is_attack(), "trop loin pour annoncer quoi que ce soit")


func test_le_voleur_vise_l_archer_meme_de_plus_loin() -> void:
	# Le Thief a prefers_class: archer. C'est ce qui oblige le joueur à
	# protéger son arrière au lieu d'aligner tout le monde.
	var board := _plain()
	_hero(board, &"warrior", Vector2i(4, 3), 1)
	var archer := _hero(board, &"archer", Vector2i(1, 3), 2)
	var thief := _enemy(board, &"thief", Vector2i(6, 3), 3)
	assert_eq(_ai().plan(board, thief)["target_id"], archer.id)


func test_le_tirailleur_recule_quand_on_le_colle() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var gnome := _enemy(board, &"slingshot_gnome", Vector2i(4, 3), 2)
	var plan := _ai().plan(board, gnome)
	assert_gt(
		board.grid.distance(plan["move_to"], hero.cell), 1,
		"le tirailleur ne reste pas au contact"
	)


func test_le_tirailleur_reste_a_portee_apres_avoir_recule() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(3, 3), 1)
	var gnome := _enemy(board, &"slingshot_gnome", Vector2i(4, 3), 2)
	var plan := _ai().plan(board, gnome)
	assert_true(plan["intent"].is_attack(), "reculer ne doit pas lui faire perdre son tir")


func test_le_tireur_ne_vise_pas_a_travers_un_rocher() -> void:
	var board := _board([
		"........", "........", "..#.....", "........", "........", "........",
	])
	var hero := _hero(board, &"warrior", Vector2i(0, 2), 1)
	var gnome := _enemy(board, &"slingshot_gnome", Vector2i(4, 2), 2)
	var plan := _ai().plan(board, gnome)
	var intent: CombatIntent = plan["intent"]
	if intent.is_attack():
		board.move_unit(gnome, plan["move_to"])
		assert_true(
			board.has_line_of_sight(gnome.cell, hero.cell),
			"annoncer un tir sans ligne de vue serait un mensonge"
		)


func test_la_brute_frappe_en_ligne() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(3, 3), 1)
	var troll := _enemy(board, &"troll", Vector2i(4, 3), 2)
	var plan := _ai().plan(board, troll)
	var intent: CombatIntent = plan["intent"]
	assert_true(intent.is_attack())
	assert_eq(intent.offsets.size(), 2, "le troll frappe sur 2 cases en ligne")


func test_l_ia_prefere_achever() -> void:
	var board := _plain()
	var fresh := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var wounded := _hero(board, &"archer", Vector2i(5, 3), 2)
	wounded.take_damage(3)
	assert_eq(wounded.hit_points, 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(4, 3), 3)
	assert_eq(
		_ai().plan(board, goblin)["target_id"], wounded.id,
		"à distance égale, on achève plutôt qu'on entame"
	)
	assert_true(fresh.is_active())


func test_une_unite_a_terre_ne_planifie_rien() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(1, 1), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(2, 1), 2)
	goblin.down()
	var plan := _ai().plan(board, goblin)
	assert_eq(plan["move_to"], goblin.cell)
	assert_false(plan["intent"].is_attack())


func test_la_decision_est_reproductible() -> void:
	# Règle 4 : rejouer une graine doit rejouer le combat à l'identique.
	var first: Array = []
	var second: Array = []
	for pass_index in 2:
		var board := _plain()
		_hero(board, &"warrior", Vector2i(2, 2), 1)
		_hero(board, &"archer", Vector2i(1, 4), 2)
		var results: Array = []
		var id := 10
		for enemy_id: StringName in Unit.enemy_ids():
			var enemy := _enemy(board, enemy_id, Vector2i(6, id - 10), id)
			var plan := EnemyAI.new(CombatRng.new(999)).plan(board, enemy)
			results.append([plan["move_to"], plan["target_id"], plan["intent"].offsets])
			id += 1
		if pass_index == 0:
			first = results
		else:
			second = results
	assert_eq(first, second, "même graine, même plan")


func test_le_plan_ne_deplace_pas_reellement_l_unite() -> void:
	# plan() simule pour décider, mais ne doit rien laisser derrière lui :
	# c'est le moteur qui applique, après quoi l'annulation reste possible.
	var board := _plain()
	_hero(board, &"warrior", Vector2i(1, 1), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(6, 1), 2)
	var before := goblin.cell
	var plan := _ai().plan(board, goblin)
	assert_eq(goblin.cell, before, "l'unité n'a pas bougé")
	assert_eq(board.unit_at(before), goblin, "et le plateau non plus")
	assert_ne(plan["move_to"], before, "alors que le plan, lui, propose de bouger")
