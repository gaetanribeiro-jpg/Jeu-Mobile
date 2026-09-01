extends GutTest

## T1.8 — l'IA ennemie.
##
## Ce qu'on vérifie n'est pas « l'IA joue bien », qui ne se teste pas, mais
## quatre propriétés qui doivent tenir sinon le jeu ment :
##   1. elle ne peut pas frapper sans avoir annoncé ;
##   2. elle n'annonce jamais une attaque qu'elle ne peut pas porter ;
##   3. elle respecte son budget de PA et de PM ;
##   4. à graine et situation identiques, elle décide la même chose.


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
		"..........", "..........", "..........",
		"..........", "..........", "..........",
	])


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


func test_les_ennemis_des_terres_vertes_sont_declares() -> void:
	var ids := Unit.enemy_ids()
	assert_eq(ids.size(), 8)
	for expected: StringName in [
		&"spear_goblin", &"gnome", &"slingshot_gnome", &"torch_goblin",
		&"thief", &"troll", &"gnoll", &"hex_shaman"
	]:
		assert_true(ids.has(expected), "ennemi manquant : %s" % expected)


func test_le_bestiaire_sait_rendre_le_tir() -> void:
	# L'INVARIANT DE T1.14, et il vaut plus que le compte au-dessus. Tant
	# qu'un seul ennemi portait au-delà du contact, il mourait le premier
	# et une équipe entièrement à distance finissait ses combats à 97 % de
	# PV — sans jamais avoir été touchée. Retirer des tireurs du bestiaire
	# ramènerait ce défaut, et rien d'autre ne le dirait.
	var shooters: Array[StringName] = []
	for enemy_id: StringName in Unit.enemy_ids():
		for ability_id: Variant in Unit.enemy_stats(enemy_id).get("abilities", []):
			var ability := Ability.of(StringName(ability_id))
			if ability != null and ability.range_max > 1:
				shooters.append(enemy_id)
				break
	assert_gt(shooters.size(), 2, "le bestiaire ne sait pas rendre le tir : %s" % [shooters])


func test_au_moins_un_ennemi_frappe_en_zone() -> void:
	# Une zone est la seule chose qui punisse un groupe massé, et une
	# équipe à distance se masse par construction.
	var found := false
	for enemy_id: StringName in Unit.enemy_ids():
		for ability_id: Variant in Unit.enemy_stats(enemy_id).get("abilities", []):
			var ability := Ability.of(StringName(ability_id))
			if ability != null and not ability.targets_self() and ability.radius > 0:
				found = true
	assert_true(found, "aucun ennemi ne frappe en zone")


func test_chaque_ennemi_a_un_role() -> void:
	for id: StringName in Unit.enemy_ids():
		var unit := Unit.from_enemy(1, id, Vector2i.ZERO)
		assert_ne(unit.role, &"", "%s n'a pas de rôle" % id)


func test_le_corps_a_corps_se_rapproche_puis_annonce() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(1, 1), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(8, 1), 90)
	var plan := _ai().plan(board, goblin)

	var destination: Vector2i = plan["move_to"]
	assert_lt(
		board.grid.distance(destination, hero.cell),
		board.grid.distance(goblin.cell, hero.cell),
		"il s'est rapproché"
	)
	assert_eq(plan["target_id"], hero.id)


func test_une_attaque_annoncee_est_toujours_portable() -> void:
	# La propriété centrale : si l'IA annonce, elle doit pouvoir le faire.
	# Un télégraphe qui promet un coup impossible est pire qu'un mensonge,
	# c'est un piège.
	for enemy_id: StringName in Unit.enemy_ids():
		var board := _plain()
		var hero := _hero(board, &"warrior", Vector2i(2, 2), 1)
		var enemy := _enemy(board, enemy_id, Vector2i(6, 2), 90)
		var plan := _ai().plan(board, enemy)
		var intent: CombatIntent = plan["intent"]
		if not intent.is_attack():
			continue

		var destination: Vector2i = plan["move_to"]
		var ability := intent.ability()
		assert_not_null(ability, "%s : compétence inconnue" % enemy_id)
		assert_true(
			ability.action_points <= enemy.max_action_points,
			"%s annonce une compétence qu'il ne peut pas payer" % enemy_id
		)
		var distance := board.grid.distance(destination, destination + intent.target_offset)
		assert_true(
			ability.is_distance_in_range(distance),
			"%s annonce hors de portée depuis sa case d'arrivée" % enemy_id
		)
		assert_eq(
			intent.target_cell(destination), hero.cell,
			"%s vise une case vide" % enemy_id
		)


func test_le_deplacement_annonce_tient_dans_les_pm() -> void:
	for enemy_id: StringName in Unit.enemy_ids():
		var board := _plain()
		_hero(board, &"warrior", Vector2i(0, 2), 1)
		var enemy := _enemy(board, enemy_id, Vector2i(9, 2), 90)
		var plan := _ai().plan(board, enemy)
		var cost := board.move_cost_to(enemy, plan["move_to"])
		assert_true(
			cost >= 0 and cost <= enemy.movement_points,
			"%s prévoit un déplacement de %d PM, il en a %d"
				% [enemy_id, cost, enemy.movement_points]
		)


func test_l_ia_n_annonce_rien_si_elle_ne_peut_pas_atteindre() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(0, 0), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(9, 5), 90)
	assert_false(_ai().plan(board, goblin)["intent"].is_attack())


func test_le_voleur_vise_l_archer_meme_de_plus_loin() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(4, 2), 1)
	var archer := _hero(board, &"archer", Vector2i(7, 4), 2)
	var thief := _enemy(board, &"thief", Vector2i(5, 2), 90)
	assert_eq(_ai().plan(board, thief)["target_id"], archer.id)


func test_le_tirailleur_recule_quand_on_le_colle() -> void:
	var board := _plain()
	var hero := _hero(board, &"warrior", Vector2i(4, 2), 1)
	var gnome := _enemy(board, &"slingshot_gnome", Vector2i(5, 2), 90)
	var destination: Vector2i = _ai().plan(board, gnome)["move_to"]
	assert_gt(
		board.grid.distance(destination, hero.cell), 1,
		"il s'est écarté du contact"
	)


func test_le_tirailleur_reste_a_portee_apres_avoir_recule() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(4, 2), 1)
	var gnome := _enemy(board, &"slingshot_gnome", Vector2i(5, 2), 90)
	assert_true(
		_ai().plan(board, gnome)["intent"].is_attack(),
		"reculer ne doit pas revenir à renoncer"
	)


func test_le_tireur_ne_vise_pas_a_travers_un_rocher() -> void:
	var board := _board([
		"..........",
		"..........",
		".....#....",
		"..........",
		"..........",
		"..........",
	])
	var hero := _hero(board, &"warrior", Vector2i(2, 2), 1)
	var gnome := _enemy(board, &"slingshot_gnome", Vector2i(8, 2), 90)
	var plan := _ai().plan(board, gnome)
	var intent: CombatIntent = plan["intent"]
	# Deux issues acceptables : il contourne pour voir, ou il n'annonce
	# rien. La seule qui ne l'est pas est d'annoncer un tir à travers la
	# pierre.
	if intent.is_attack():
		assert_true(
			board.has_line_of_sight(plan["move_to"], hero.cell),
			"il a contourné pour voir sa cible"
		)
	else:
		assert_false(
			board.has_line_of_sight(gnome.cell, hero.cell),
			"s'il voyait sa cible, il devait annoncer"
		)


func test_la_brute_annonce_son_attaque_en_ligne() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(4, 2), 1)
	var troll := _enemy(board, &"troll", Vector2i(5, 2), 90)
	var intent: CombatIntent = _ai().plan(board, troll)["intent"]
	assert_true(intent.is_attack())
	assert_eq(intent.ability_id, &"troll_smash")
	assert_eq(
		intent.target_cells(Vector2i(5, 2), board.grid).size(), 2,
		"deux cases en ligne"
	)


func test_l_ia_prefere_achever() -> void:
	var board := _plain()
	var healthy := _hero(board, &"warrior", Vector2i(4, 2), 1)
	var dying := _hero(board, &"warrior", Vector2i(6, 2), 2)
	dying.hit_points = 1
	var goblin := _enemy(board, &"spear_goblin", Vector2i(5, 2), 90)
	assert_eq(
		_ai().plan(board, goblin)["target_id"], dying.id,
		"à distance égale, on achève"
	)
	assert_true(healthy.is_active())


func test_une_unite_a_terre_ne_planifie_rien() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(4, 2), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(5, 2), 90)
	goblin.down()
	var plan := _ai().plan(board, goblin)
	assert_false(plan["intent"].is_attack())
	assert_eq(plan["target_id"], -1)


func test_la_decision_est_reproductible() -> void:
	# Règle 4 : c'est ce qui permet de rejouer un bug à l'identique.
	for i in 5:
		var board := _plain()
		_hero(board, &"warrior", Vector2i(2, 2), 1)
		_hero(board, &"archer", Vector2i(3, 4), 2)
		var goblin := _enemy(board, &"spear_goblin", Vector2i(7, 3), 90)
		var first := _ai().plan(board, goblin)
		var second := _ai().plan(board, goblin)
		assert_eq(first["move_to"], second["move_to"])
		assert_eq(first["target_id"], second["target_id"])


func test_le_plan_ne_deplace_pas_reellement_l_unite() -> void:
	# L'IA simule un déplacement pour décider de son annonce, et doit
	# remettre l'unité où elle était : c'est le moteur qui bouge, pas elle.
	var board := _plain()
	_hero(board, &"warrior", Vector2i(1, 2), 1)
	var goblin := _enemy(board, &"spear_goblin", Vector2i(8, 2), 90)
	_ai().plan(board, goblin)
	assert_eq(goblin.cell, Vector2i(8, 2))
	assert_eq(board.unit_at(Vector2i(8, 2)), goblin)


func test_la_provocation_prime_sur_tout_le_reste() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(5, 2), 1)
	var archer := _hero(board, &"archer", Vector2i(6, 3), 2)
	var thief := _enemy(board, &"thief", Vector2i(5, 1), 90)
	assert_eq(
		_ai().plan(board, thief)["target_id"], archer.id,
		"sans provocation, le Voleur vise l'Archer"
	)
	assert_eq(
		_ai().plan(board, thief, [warrior.id])["target_id"], warrior.id,
		"provoqué, il n'a plus le choix"
	)
