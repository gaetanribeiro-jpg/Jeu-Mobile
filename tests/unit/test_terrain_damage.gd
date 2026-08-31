extends GutTest

## T1.12 — le décor encaisse, et le feu brûle.
##
## Deux choses étaient déclarées en données et jamais appliquées : les
## points de vie d'un pont, et le `leaves_terrain` du Torch Goblin. Le § 19
## en fait une exigence — « le terrain doit avoir un véritable impact » —
## et sans elles un objectif « protéger une structure » ne pouvait
## littéralement pas échouer.


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


func _engine(board: CombatBoard) -> CombatEngine:
	var engine := CombatEngine.new(
		board, CombatObjective.from_dictionary({"kind": "eliminate"}), CombatRng.new(3)
	)
	engine.start()
	return engine


func _hero(board: CombatBoard, class_id: StringName, at: Vector2i, id: int = 1) -> Unit:
	var unit := Unit.from_hero_class(id, class_id, at)
	unit.initiative = 99 - id
	board.place_unit(unit, at)
	return unit


func _enemy(board: CombatBoard, enemy_id: StringName, at: Vector2i, id: int = 90) -> Unit:
	var unit := Unit.from_enemy(id, enemy_id, at)
	unit.initiative = 1
	board.place_unit(unit, at)
	return unit


# --- Casser le décor -------------------------------------------------------

func test_une_case_vide_avec_un_pont_reste_une_cible_legitime() -> void:
	# Sans cette règle, une Frappe ne pourrait jamais viser un pont : elle
	# exige une victime, et un pont n'en est pas une.
	var board := _board([
		"..........", "....=.....", "..........",
	])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1))
	var engine := _engine(board)
	assert_true(engine.can_aim(warrior, &"strike", Vector2i(4, 1)))


func test_frapper_un_pont_l_entame() -> void:
	var board := _board([
		"..........", "....=.....", "..........",
	])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1))
	var engine := _engine(board)
	var tile := board.tile_at(Vector2i(4, 1))
	var before := tile.structure_hp

	var report := engine.use_ability(warrior, &"strike", Vector2i(4, 1))
	assert_false(report.is_empty())
	assert_lt(tile.structure_hp, before, "le pont a pris le coup")
	assert_true((report["hits"] as Array).is_empty(), "personne n'a été touché")


func test_un_pont_qui_cede_devient_de_l_eau() -> void:
	var board := _board([
		"..........", "....=.....", "..........",
	])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1))
	var engine := _engine(board)
	var tile := board.tile_at(Vector2i(4, 1))

	var broken := false
	for i in 12:
		if not engine.can_use(warrior, &"strike"):
			warrior.begin_activation()
		var report := engine.use_ability(warrior, &"strike", Vector2i(4, 1))
		if report.is_empty():
			break
		if not (report["broken"] as Array).is_empty():
			broken = true
			break
	assert_true(broken, "le pont a fini par céder")
	assert_eq(tile.terrain_id, &"water")
	assert_false(tile.is_walkable(), "et le passage est coupé")


func test_on_ne_casse_pas_le_pont_sous_les_pieds_d_un_occupant() -> void:
	# On frappe ce qui se tient sur le pont, pas le pont. Sinon une Boule de
	# feu lancée dans une mêlée noierait tout le monde sans prévenir.
	var board := _board([
		"..........", "....=.....", "..........",
	])
	var warrior := _hero(board, &"warrior", Vector2i(3, 1), 1)
	var goblin := _enemy(board, &"gnome", Vector2i(4, 1))
	var engine := _engine(board)
	var tile := board.tile_at(Vector2i(4, 1))
	var before := tile.structure_hp

	engine.use_ability(warrior, &"strike", Vector2i(4, 1))
	assert_eq(tile.structure_hp, before, "le pont est intact")
	assert_lt(goblin.hit_points, goblin.max_hit_points, "c'est le gobelin qui a pris")


func test_une_case_vide_sans_rien_a_casser_reste_interdite() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 1))
	var engine := _engine(board)
	assert_false(engine.can_aim(warrior, &"strike", Vector2i(4, 1)))


# --- Le feu ---------------------------------------------------------------

func test_la_torche_laisse_du_feu_derriere_elle() -> void:
	var board := _plain()
	var goblin := _enemy(board, &"torch_goblin", Vector2i(3, 2), 90)
	var hero := _hero(board, &"warrior", Vector2i(4, 2), 1)
	var report := board.resolve_ability(
		goblin, Ability.of(&"goblin_torch"), hero.cell
	)
	assert_eq(report["burned"], [hero.cell])
	assert_eq(board.tile_at(hero.cell).terrain_id, &"fire")


func test_le_feu_ne_prend_pas_sur_l_eau() -> void:
	var board := _board([
		"..........", "...~......", "..........",
	])
	var goblin := _enemy(board, &"torch_goblin", Vector2i(2, 1), 90)
	board.resolve_ability(goblin, Ability.of(&"goblin_torch"), Vector2i(3, 1))
	assert_eq(board.tile_at(Vector2i(3, 1)).terrain_id, &"water")


func test_commencer_son_activation_dans_le_feu_brule() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 2), 1)
	_enemy(board, &"gnome", Vector2i(9, 5), 90)
	var engine := _engine(board)
	assert_true(board.tile_at(warrior.cell).cover_with(&"fire"))

	var before := warrior.hit_points
	# On boucle jusqu'au retour du Guerrier : c'est au DÉBUT de son
	# activation que le feu mord.
	for i in 6:
		engine.end_activation()
		if engine.current_unit() == warrior:
			break
	assert_lt(warrior.hit_points, before, "le feu a mordu")


func test_le_feu_s_eteint_et_rend_la_case() -> void:
	var tile := Tile.new(Vector2i(1, 1), &"forest")
	assert_true(tile.cover_with(&"fire"))
	assert_eq(tile.terrain_id, &"fire")

	var turns := int(CombatRules.terrain_property(&"fire", &"duration", 0))
	for i in turns - 1:
		assert_false(tile.tick_terrain(), "il brûle encore")
	assert_true(tile.tick_terrain(), "il s'éteint")
	assert_eq(tile.terrain_id, &"forest", "la forêt est rendue, pas de l'herbe")


func test_rallumer_un_feu_ne_perd_pas_le_terrain_d_origine() -> void:
	var tile := Tile.new(Vector2i(1, 1), &"forest")
	tile.cover_with(&"fire")
	tile.tick_terrain()
	tile.cover_with(&"fire")
	while not tile.tick_terrain():
		pass
	assert_eq(tile.terrain_id, &"forest")


func test_le_feu_ne_prend_pas_sur_la_pierre() -> void:
	var tile := Tile.new(Vector2i(1, 1), &"rock")
	assert_false(tile.cover_with(&"fire"))
	assert_eq(tile.terrain_id, &"rock")


func test_l_etat_du_terrain_temporaire_survit_a_la_sauvegarde() -> void:
	var tile := Tile.new(Vector2i(2, 3), &"forest")
	tile.cover_with(&"fire")
	var copy := Tile.from_dictionary(tile.to_dictionary())
	assert_eq(copy.terrain_id, &"fire")
	assert_eq(copy.terrain_turns_left, tile.terrain_turns_left)
	while not copy.tick_terrain():
		pass
	assert_eq(copy.terrain_id, &"forest", "il sait encore d'où il vient")


func test_le_feu_s_eteint_au_fil_des_rondes() -> void:
	var board := _plain()
	_hero(board, &"warrior", Vector2i(0, 0), 1)
	_enemy(board, &"gnome", Vector2i(9, 5), 90)
	var engine := _engine(board)
	var tile := board.tile_at(Vector2i(5, 3))
	tile.cover_with(&"fire")

	var turns := int(CombatRules.terrain_property(&"fire", &"duration", 0))
	var guard := 0
	while tile.terrain_id == &"fire" and guard < turns * 8:
		engine.end_activation()
		guard += 1
	assert_ne(tile.terrain_id, &"fire", "le feu a fini par s'éteindre")
