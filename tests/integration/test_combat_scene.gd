extends GutTest

## La scène de combat, pilotée comme le ferait un doigt (C1.17, C1.18).
##
## Ces tests instancient la vraie scène et lui envoient des taps. Ils ne
## vérifient pas le rendu — je le contrôle en capture d'écran — mais la
## grammaire d'interaction du § 11.2, qui est du code comme le reste et
## qui casse aussi silencieusement.


var _scene: Node2D


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()
	ViewSettings.reload()
	var packed: PackedScene = load("res://scenes/combat/combat_scene.tscn")
	_scene = packed.instantiate()
	_scene.map_id = &"vallee_01"
	add_child_autofree(_scene)
	await wait_frames(2)


func _engine() -> CombatEngine:
	return _scene.engine


func _first_hero() -> Unit:
	return _engine().board.active_units(Unit.Side.HEROES)[0]


func test_la_scene_se_construit_sur_une_carte() -> void:
	assert_not_null(_engine(), "le moteur est monté")
	assert_eq(_engine().turn_index, 1)
	assert_eq(
		_engine().board.active_units(Unit.Side.HEROES).size(),
		CombatRules.squad_size(),
		"trois emplacements pour quatre classes : il faut choisir"
	)
	assert_gt(_engine().board.active_units(Unit.Side.ENEMIES).size(), 0)


func test_un_tap_sur_un_heros_le_selectionne() -> void:
	var hero := _first_hero()
	_scene.handle_tap(hero.cell)
	assert_eq(_scene._selection, _scene.Selection.UNIT)
	assert_eq(_scene._selected, hero)


func test_un_tap_dans_le_vide_ne_selectionne_rien() -> void:
	_scene.handle_tap(Vector2i(4, 5))
	assert_eq(_scene._selection, _scene.Selection.NONE)


func test_le_deuxieme_tap_previsualise_sans_rien_appliquer() -> void:
	# Toute la raison d'être du double tap : le premier montre, le second
	# engage. 90 % des erreurs de gros doigts s'arrêtent là (§ 11.2).
	var hero := _first_hero()
	var start := hero.cell
	_scene.handle_tap(start)
	var destination := _a_reachable_cell(hero)
	_scene.handle_tap(destination)
	assert_eq(_scene._selection, _scene.Selection.PREVIEW)
	assert_eq(_scene._preview_cell, destination)
	assert_eq(hero.cell, start, "rien n'a bougé")


func test_le_troisieme_tap_sur_la_meme_case_valide() -> void:
	var hero := _first_hero()
	_scene.handle_tap(hero.cell)
	var destination := _a_reachable_cell(hero)
	_scene.handle_tap(destination)
	_scene.handle_tap(destination)
	assert_eq(hero.cell, destination, "le déplacement est appliqué")
	assert_true(hero.has_moved)
	assert_eq(_scene._selection, _scene.Selection.NONE, "la sélection se referme")


func test_un_tap_sur_une_autre_case_deplace_la_previsualisation() -> void:
	var hero := _first_hero()
	_scene.handle_tap(hero.cell)
	var cells := _reachable_cells(hero)
	if cells.size() < 2:
		pending("pas assez de cases atteignables sur cette carte")
		return
	_scene.handle_tap(cells[0])
	_scene.handle_tap(cells[1])
	assert_eq(_scene._preview_cell, cells[1], "on vise ailleurs, on ne valide pas")
	assert_eq(hero.cell, _first_hero().cell)


func test_un_tap_sur_un_autre_heros_change_de_selection() -> void:
	var heroes := _engine().board.active_units(Unit.Side.HEROES)
	_scene.handle_tap(heroes[0].cell)
	_scene.handle_tap(heroes[1].cell)
	assert_eq(_scene._selected, heroes[1])
	assert_eq(_scene._selection, _scene.Selection.UNIT)


func test_on_ne_selectionne_pas_un_ennemi() -> void:
	var enemy: Unit = _engine().board.active_units(Unit.Side.ENEMIES)[0]
	_scene.handle_tap(enemy.cell)
	assert_eq(_scene._selection, _scene.Selection.NONE)


func test_le_hud_reflete_le_moteur() -> void:
	var hud: CanvasLayer = _scene._hud
	assert_not_null(hud)
	assert_true(hud._undo.disabled, "rien à annuler en début de tour")
	var hero := _first_hero()
	var destination := _a_reachable_cell(hero)
	_scene.handle_tap(hero.cell)
	_scene.handle_tap(destination)
	_scene.handle_tap(destination)
	await wait_frames(2)
	hud.refresh(_engine())
	assert_false(hud._undo.disabled, "après une action, on peut annuler")


func test_le_bouton_annuler_defait_le_deplacement() -> void:
	var hero := _first_hero()
	var start := hero.cell
	var destination := _a_reachable_cell(hero)
	_scene.handle_tap(start)
	_scene.handle_tap(destination)
	_scene.handle_tap(destination)
	assert_eq(hero.cell, destination)
	_scene._on_undo()
	assert_eq(hero.cell, start, "le héros est revenu")
	assert_false(hero.has_moved)


func test_la_couche_de_surbrillance_suit_la_selection() -> void:
	var hero := _first_hero()
	var overlay: Node2D = _scene._overlay
	assert_eq(overlay.move_cells.size(), 0, "rien de sélectionné, rien d'allumé")
	_scene.handle_tap(hero.cell)
	assert_gt(overlay.move_cells.size(), 0, "les cases de déplacement s'allument")
	assert_eq(overlay.selected_cell, hero.cell)
	_scene.handle_tap(Vector2i(7, 5))
	assert_eq(overlay.move_cells.size(), 0, "et s'éteignent quand on désélectionne")


func test_le_fantome_ne_parait_que_sur_un_deplacement() -> void:
	var hero := _first_hero()
	_scene.handle_tap(hero.cell)
	assert_false(_scene._ghost.visible, "pas de fantôme sur une simple sélection")
	var destination := _a_reachable_cell(hero)
	_scene.handle_tap(destination)
	assert_true(_scene._ghost.visible, "le fantôme montre QUI va bouger")
	assert_eq(
		_scene._ghost.position,
		_engine().board.grid.to_world_center(destination, AssetTable.tile_size())
	)


func test_le_telegraphe_de_la_couche_correspond_au_moteur() -> void:
	# La couche d'affichage ne recalcule rien : elle recopie le moteur.
	# S'ils divergent, le joueur voit un chiffre qui n'est pas celui qu'il
	# va prendre, et le pilier de l'information parfaite tombe.
	var engine := _engine()
	for i in 3:
		engine.end_player_turn()
		_scene._refresh_all()
		if engine.is_finished():
			break
	var overlay: Node2D = _scene._overlay
	for cell: Vector2i in overlay.threat.keys():
		assert_eq(
			int(overlay.threat[cell]), engine.threat_on(cell),
			"case %s : la couche annonce %d, le moteur %d"
				% [cell, int(overlay.threat[cell]), engine.threat_on(cell)]
		)


func _reachable_cells(hero: Unit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _engine().board.reachable_cells(hero).keys():
		if cell != hero.cell:
			out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


func _a_reachable_cell(hero: Unit) -> Vector2i:
	var cells := _reachable_cells(hero)
	return cells[0] if not cells.is_empty() else hero.cell


func test_un_rocher_est_de_la_terre_pas_de_l_eau() -> void:
	# Défaut vu en capture d'écran : les rochers apparaissaient au fond
	# d'une mare. Le rendu du terrain demandait « peut-on marcher dessus »
	# là où la question est « est-ce de l'eau ».
	var terrain: Node2D = _scene._terrain
	var board := CombatBoard.from_rows(
		PackedStringArray(["..#.", "..~.", "....", "...."]),
		CombatRules.ADJACENCY_ORTHOGONAL
	)
	terrain.setup(board)
	assert_true(terrain._is_land(Vector2i(2, 0)), "un rocher est de la terre")
	assert_false(terrain._is_land(Vector2i(2, 1)), "l'eau n'en est pas")
	assert_true(terrain._is_land(Vector2i(0, 0)), "l'herbe non plus n'est pas de l'eau")
	assert_false(terrain._is_land(Vector2i(-1, 0)), "hors grille compte comme de l'eau")


func test_deux_heros_de_meme_classe_restent_distincts_a_l_ecran() -> void:
	# Conséquence directe des doublons : sans numéro d'emplacement, deux
	# Guerriers bleus sont le même sprite et le joueur ne sait pas lequel
	# il vient de déplacer.
	var squad := Unit.squad_from_classes([&"warrior", &"warrior", &"monk"])
	var slots := {}
	for unit: Unit in squad:
		assert_false(slots.has(unit.slot), "deux héros au même emplacement")
		slots[unit.slot] = true
	assert_eq(slots.size(), 3)

	var hud: CanvasLayer = _scene._hud
	var texts := {}
	for unit: Unit in squad:
		var name_ := tr("CLASS_%s" % String(unit.class_id).to_upper())
		var line := "%d  %s  %d/%d" % [
			unit.slot, name_, unit.hit_points, unit.max_hit_points
		]
		assert_false(texts.has(line), "deux lignes de HUD identiques : %s" % line)
		texts[line] = true
	assert_not_null(hud)
