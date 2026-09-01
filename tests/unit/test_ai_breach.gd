extends GutTest

## T7.3 — l'IA sait frapper ce qui barre la route.
##
## OUVERT DEPUIS T1.12, et signalé trois fois. L'IA ne visait que des
## UNITÉS : un pont ne se cassait jamais tout seul, et un objectif
## « protéger une structure » ne pouvait donc pas échouer — une carte dont
## l'objectif ne peut pas être perdu n'est pas une carte. La défense du
## royaume (§ 38) rendait le manque criant : une palissade que personne
## n'attaque n'est pas un mur, c'est une frontière.
##
## LA RÈGLE EST SOBRE, et les deux premiers tests sont là pour qu'elle le
## reste : un ennemi qui a quelqu'un à frapper le frappe. Sinon les
## assaillants s'occuperaient du paysage pendant que le joueur les
## contourne.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()


## Un plateau nu avec une palissade au milieu, un gobelin d'un côté, un
## héros de l'autre.
func _walled() -> CombatBoard:
	var rows := PackedStringArray()
	var fence := String(CombatRules.terrain_property(&"palisade", &"symbol", "p"))
	for row in 5:
		var line := ""
		for column in 9:
			line += fence if column == 4 else "."
		rows.append(line)
	return CombatBoard.from_rows(rows, CombatRules.ADJACENCY_ORTHOGONAL)


func _place(board: CombatBoard, unit: Unit, cell: Vector2i) -> Unit:
	board.place_unit(unit, cell)
	return unit


# --- La sobriété d'abord ---------------------------------------------------

func test_un_ennemi_qui_a_quelqu_un_a_frapper_le_frappe() -> void:
	var board := _walled()
	var hero := _place(board, Unit.from_hero_class(1, &"warrior", Vector2i.ZERO), Vector2i(6, 2))
	var goblin := _place(
		board, Unit.from_enemy(200, &"spear_goblin", Vector2i.ZERO), Vector2i(5, 2)
	)
	var intent := EnemyAI.new(CombatRng.new(1)).intent_here(board, goblin)
	assert_eq(intent.kind, CombatIntent.Kind.ATTACK)
	assert_eq(goblin.cell + intent.target_offset, hero.cell, "il vise autre chose que le héros")


func test_un_ennemi_ne_casse_pas_le_decor_pour_le_plaisir() -> void:
	# Un gobelin adjacent à la palissade ET au héros doit choisir le héros.
	var board := _walled()
	var hero := _place(board, Unit.from_hero_class(1, &"warrior", Vector2i.ZERO), Vector2i(2, 2))
	var goblin := _place(
		board, Unit.from_enemy(200, &"spear_goblin", Vector2i.ZERO), Vector2i(3, 2)
	)
	var intent := EnemyAI.new(CombatRng.new(1)).intent_here(board, goblin)
	assert_eq(goblin.cell + intent.target_offset, hero.cell)


# --- Et la brèche quand il n'y a rien d'autre -----------------------------

func test_un_ennemi_bloque_frappe_ce_qui_barre_la_route() -> void:
	var board := _walled()
	_place(board, Unit.from_hero_class(1, &"warrior", Vector2i.ZERO), Vector2i(0, 2))
	var goblin := _place(
		board, Unit.from_enemy(200, &"spear_goblin", Vector2i.ZERO), Vector2i(5, 2)
	)
	var intent := EnemyAI.new(CombatRng.new(1)).intent_here(board, goblin)
	assert_eq(intent.kind, CombatIntent.Kind.ATTACK, "l'ennemi reste planté devant le mur")
	var aimed := goblin.cell + intent.target_offset
	assert_eq(board.tile_at(aimed).terrain_id, &"palisade")


func test_il_ouvre_la_breche_en_face_de_sa_cible() -> void:
	# Un assiégeant ouvre la brèche devant ce qu'il veut atteindre, pas à
	# l'autre bout de la palissade.
	var board := _walled()
	_place(board, Unit.from_hero_class(1, &"warrior", Vector2i.ZERO), Vector2i(0, 0))
	var gnoll := _place(board, Unit.from_enemy(200, &"gnoll", Vector2i.ZERO), Vector2i(6, 2))
	var intent := EnemyAI.new(CombatRng.new(1)).intent_here(board, gnoll)
	var aimed := gnoll.cell + intent.target_offset
	assert_eq(board.tile_at(aimed).terrain_id, &"palisade")
	# Parmi les cases de palissade à sa portée, la plus proche du héros.
	for row in 5:
		var candidate := Vector2i(4, row)
		if board.grid.distance(candidate, gnoll.cell) > gnoll.max_movement_points + 6:
			continue
		assert_true(
			board.grid.distance(aimed, Vector2i(0, 0))
				<= board.grid.distance(candidate, Vector2i(0, 0)),
			"il vise %s alors que %s est plus près de la cible" % [aimed, candidate]
		)


func test_la_palissade_finit_par_tomber() -> void:
	# Le vrai enjeu : la brèche doit s'ouvrir, sinon la défense du royaume
	# est un siège que personne ne mène.
	var board := _walled()
	_place(board, Unit.from_hero_class(1, &"warrior", Vector2i.ZERO), Vector2i(0, 2))
	var goblin := _place(
		board, Unit.from_enemy(200, &"spear_goblin", Vector2i.ZERO), Vector2i(5, 2)
	)
	var engine := CombatEngine.new(
		board, CombatObjective.from_dictionary({"kind": "eliminate"}), CombatRng.new(1)
	)
	engine.start()

	var guard := 0
	while guard < 30:
		var fence := 0
		for row in 5:
			if board.tile_at(Vector2i(4, row)).terrain_id == &"palisade":
				fence += 1
		if fence < 5:
			pass_test("la palissade est percée en %d activations" % guard)
			return
		engine.end_activation()
		guard += 1
		if goblin.is_downed():
			break
	fail_test("la palissade tient indéfiniment")


func test_un_ennemi_sans_rien_a_frapper_n_invente_pas_de_cible() -> void:
	# Pas d'obstacle, pas de héros à portée : l'intention reste vide.
	var rows := PackedStringArray()
	for row in 5:
		rows.append(".........")
	var board := CombatBoard.from_rows(rows, CombatRules.ADJACENCY_ORTHOGONAL)
	_place(board, Unit.from_hero_class(1, &"warrior", Vector2i.ZERO), Vector2i(0, 0))
	var goblin := _place(
		board, Unit.from_enemy(200, &"spear_goblin", Vector2i.ZERO), Vector2i(8, 4)
	)
	assert_eq(
		EnemyAI.new(CombatRng.new(1)).intent_here(board, goblin).kind,
		CombatIntent.Kind.NONE
	)
