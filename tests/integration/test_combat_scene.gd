extends GutTest

## La scène de combat, pilotée comme le ferait un doigt.
##
## Ces tests instancient la vraie scène et lui envoient des taps. Ils ne
## vérifient pas le rendu — je le contrôle en capture d'écran — mais la
## grammaire d'interaction, qui est du code comme le reste et qui casse
## aussi silencieusement.
##
## LA GRAMMAIRE A CHANGÉ AVEC LA TIMELINE : il n'y a plus de sélection à
## faire, le moteur désigne qui joue (§ 16). Un tap vise, un second sur la
## même case valide.


var _scene: Node2D


## Ces tests montent la vraie scène, donc ils chargent de vraies textures.
## Sans le pack — qui n'est pas versionné, sa licence l'interdit — chaque
## sprite manquant pousse une erreur nommée, et GUT les compte comme des
## échecs. Un dépôt fraîchement cloné doit montrer une suite verte avec des
## tests EN ATTENTE, pas une suite rouge : le nouveau venu croirait avoir
## cassé quelque chose alors qu'il lui manque juste une étape d'installation.
## GUT ignore le script dès qu'on lui rend une chaîne — MÊME VIDE. Il faut
## donc rendre `false` quand tout va bien, pas "". Et sans annotation de
## type de retour : la méthode parente n'en a pas, et GDScript refuse une
## redéfinition mieux typée que ce qu'elle redéfinit.
func should_skip_script():
	var entry := AssetTable.unit_animation(&"warrior", &"idle", "Blue")
	if entry.is_empty() or not FileAccess.file_exists(entry["path"]):
		return "Pack Tiny Swords absent — voir docs/installation.md"
	return false


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()
	ViewSettings.clear_cache()
	var packed: PackedScene = load("res://scenes/combat/combat_scene.tscn")
	_scene = packed.instantiate()
	_scene.map_id = &"vallee_01"
	add_child_autofree(_scene)
	await wait_process_frames(2)


## Pose l'escouade et démarre le combat, en passant par les vrais taps.
## La plupart des tests portent sur le combat, pas sur le placement : ils
## ont besoin d'un plateau garni, et le chemin le plus honnête pour y
## arriver est celui du joueur.
func _deploy_and_start() -> void:
	for cell: Vector2i in _engine().deployment_cells():
		if _engine().pending_heroes().is_empty():
			break
		_scene.handle_tap(cell)
	_scene._on_end_turn()
	await wait_process_frames(2)


func _engine() -> CombatEngine:
	return _scene.engine


func _first_hero() -> Unit:
	return _engine().board.active_units(Unit.Side.HEROES)[0]


func test_la_scene_se_construit_sur_une_carte() -> void:
	await _deploy_and_start()
	assert_not_null(_engine(), "le moteur est monté")
	assert_eq(_engine().round_index(), 1)
	assert_eq(
		_engine().board.active_units(Unit.Side.HEROES).size(),
		CombatRules.team_size(),
		"toute l'équipe est sur le plateau"
	)
	assert_gt(_engine().board.active_units(Unit.Side.ENEMIES).size(), 0)


func test_la_timeline_designe_le_personnage_sans_qu_on_le_selectionne() -> void:
	await _deploy_and_start()
	var active := _engine().current_unit()
	assert_not_null(active)
	assert_true(active.is_hero())
	_scene.handle_tap(_a_reachable_cell(active))
	assert_eq(_scene._selected, active, "c'est lui qu'on pilote, pas un autre")


func test_un_tap_dans_le_vide_ne_vise_rien() -> void:
	await _deploy_and_start()
	_scene.handle_tap(_far_cell())
	assert_eq(_scene._selection, _scene.Selection.NONE)


func test_le_premier_tap_previsualise_sans_rien_appliquer() -> void:
	# Toute la raison d'être du double tap : le premier montre, le second
	# engage. 90 % des erreurs de gros doigts s'arrêtent là.
	await _deploy_and_start()
	var hero := _engine().current_unit()
	var start := hero.cell
	var destination := _a_reachable_cell(hero)
	_scene.handle_tap(destination)
	assert_eq(_scene._selection, _scene.Selection.PREVIEW)
	assert_eq(_scene._preview_cell, destination)
	assert_eq(hero.cell, start, "rien n'a bougé")


func test_le_second_tap_sur_la_meme_case_valide() -> void:
	await _deploy_and_start()
	var hero := _engine().current_unit()
	var destination := _a_reachable_cell(hero)
	_scene.handle_tap(destination)
	_scene.handle_tap(destination)
	await _settle()
	assert_eq(hero.cell, destination, "le déplacement est appliqué")
	assert_true(hero.has_moved)
	assert_eq(_scene._selection, _scene.Selection.NONE, "la visée se referme")


func test_un_tap_sur_une_autre_case_deplace_la_previsualisation() -> void:
	await _deploy_and_start()
	var hero := _engine().current_unit()
	var start := hero.cell
	var cells := _reachable_cells(hero)
	if cells.size() < 2:
		pending("pas assez de cases atteignables sur cette carte")
		return
	_scene.handle_tap(cells[0])
	_scene.handle_tap(cells[1])
	assert_eq(_scene._preview_cell, cells[1], "on vise ailleurs, on ne valide pas")
	assert_eq(hero.cell, start)


func test_les_pm_se_depensent_au_fil_des_pas() -> void:
	# Ce que le modèle PM apporte à l'interaction : on peut bouger deux
	# fois dans la même activation, et la seconde coûte moins cher.
	await _deploy_and_start()
	var hero := _engine().current_unit()
	var full := hero.movement_points
	var destination := _a_reachable_cell(hero)
	_scene.handle_tap(destination)
	_scene.handle_tap(destination)
	await _settle()
	assert_lt(hero.movement_points, full, "des PM ont été dépensés")


func test_on_ne_pilote_pas_un_autre_heros_que_celui_qui_joue() -> void:
	await _deploy_and_start()
	var active := _engine().current_unit()
	var other: Unit = null
	for unit: Unit in _engine().board.active_units(Unit.Side.HEROES):
		if unit.id != active.id:
			other = unit
			break
	assert_not_null(other)
	var before := other.cell
	_scene.handle_tap(other.cell)
	_scene.handle_tap(other.cell)
	await _settle()
	assert_eq(other.cell, before, "ce n'est pas son tour")


func test_le_hud_reflete_le_moteur() -> void:
	await _deploy_and_start()
	var hud: CanvasLayer = _scene._hud
	assert_not_null(hud)
	assert_true(hud._undo.disabled, "rien à annuler en début d'activation")
	var hero := _engine().current_unit()
	var destination := _a_reachable_cell(hero)
	_scene.handle_tap(destination)
	_scene.handle_tap(destination)
	await _settle()
	hud.refresh(_engine())
	assert_false(hud._undo.disabled, "après une action, on peut annuler")


func test_le_bouton_annuler_defait_le_deplacement() -> void:
	await _deploy_and_start()
	var hero := _engine().current_unit()
	var start := hero.cell
	var destination := _a_reachable_cell(hero)
	_scene.handle_tap(destination)
	_scene.handle_tap(destination)
	await _settle()
	assert_eq(hero.cell, destination)
	_scene._on_undo()
	assert_eq(hero.cell, start, "le héros est revenu")
	assert_false(hero.has_moved)
	assert_eq(hero.movement_points, hero.max_movement_points, "les PM sont rendus")


func test_la_couche_de_surbrillance_suit_le_personnage_actif() -> void:
	await _deploy_and_start()
	var hero := _engine().current_unit()
	var overlay: Node2D = _scene._overlay
	assert_gt(
		overlay.move_cells.size(), 0,
		"les cases du personnage qui joue sont allumées sans rien toucher"
	)
	assert_eq(overlay.selected_cell, hero.cell)

	var before: int = overlay.move_cells.size()
	var destination := _a_reachable_cell(hero)
	_scene.handle_tap(destination)
	_scene.handle_tap(destination)
	await _settle()
	assert_lt(
		overlay.move_cells.size(), before,
		"la zone rétrécit à mesure que les PM se dépensent"
	)


func test_chaque_unite_a_son_sprite_a_sa_case() -> void:
	# Invariant de la couche de rendu, et le seul moyen de le vérifier
	# autrement qu'à l'œil : une capture d'écran ne dit pas si un sprite
	# manque ou s'il est simplement caché derrière un autre.
	await _deploy_and_start()
	var engine := _engine()
	var tile := AssetTable.tile_size()
	for i in 6:
		if engine.is_finished():
			break
		engine.end_activation()
		_scene._sync_views()
		for unit: Unit in engine.board.units():
			if not unit.is_active():
				continue
			var view: Node2D = _scene._views.get(unit.id, null)
			assert_not_null(view, "l'unité %d n'a pas de sprite" % unit.id)
			if view == null:
				continue
			assert_true(view.visible, "le sprite de l'unité %d est caché" % unit.id)
			assert_eq(
				view.position, engine.board.grid.to_world_center(unit.cell, tile),
				"le sprite de l'unité %d n'est pas sur sa case" % unit.id
			)


func test_la_case_mise_en_avant_est_celle_du_personnage_actif() -> void:
	# La question du § 16 — qui joue maintenant ? — doit avoir une réponse
	# visuelle exacte : le cadre est sur le personnage, jamais à côté.
	await _deploy_and_start()
	var engine := _engine()
	var overlay: Node2D = _scene._overlay
	for i in 6:
		if engine.is_finished():
			break
		_scene._refresh_all()
		var active := engine.current_unit()
		if active != null and active.is_hero():
			assert_eq(
				overlay.selected_cell, active.cell,
				"le cadre désigne %s, le personnage actif est en %s"
					% [overlay.selected_cell, active.cell]
			)
			assert_not_null(
				engine.board.unit_at(overlay.selected_cell),
				"le cadre est posé sur une case vide"
			)
		engine.end_activation()


# --- Le HUD de combat (T1.9) ----------------------------------------------

func test_la_barre_montre_les_competences_du_personnage_actif() -> void:
	await _deploy_and_start()
	var hero := _engine().current_unit()
	var hud: CanvasLayer = _scene._hud
	assert_eq(
		hud._ability_buttons.keys().size(), hero.abilities.size(),
		"un bouton par compétence"
	)
	for ability_id: StringName in hero.abilities:
		assert_true(
			hud._ability_buttons.has(ability_id),
			"la compétence %s n'a pas de bouton" % ability_id
		)


func test_un_bouton_de_competence_dit_son_cout_en_pa() -> void:
	# Exigence du § 48 : le joueur doit savoir ce qu'une action coûte AVANT
	# de la choisir.
	await _deploy_and_start()
	var hero := _engine().current_unit()
	var hud: CanvasLayer = _scene._hud
	for ability_id: StringName in hero.abilities:
		var ability := Ability.of(ability_id)
		var button: Button = hud._ability_buttons[ability_id]
		assert_true(
			button.text.contains(str(ability.action_points)),
			"« %s » ne dit pas son coût de %d PA" % [button.text, ability.action_points]
		)


func test_une_competence_sans_pa_est_grisee_et_dit_pourquoi() -> void:
	await _deploy_and_start()
	var hero := _engine().current_unit()
	var hud: CanvasLayer = _scene._hud
	hero.spend_action_points(hero.action_points)
	hud.refresh(_engine())
	for ability_id: StringName in hero.abilities:
		var button: Button = hud._ability_buttons[ability_id]
		assert_true(button.disabled, "%s devrait être grisée" % ability_id)
		assert_ne(button.tooltip_text, "", "%s ne dit pas pourquoi" % ability_id)


func test_les_jauges_suivent_les_pa_et_les_pm() -> void:
	await _deploy_and_start()
	var hero := _engine().current_unit()
	var hud: CanvasLayer = _scene._hud
	assert_eq(hud._action_pips.filled, hero.action_points)
	assert_eq(hud._action_pips.total, hero.max_action_points)
	assert_eq(hud._movement_pips.filled, hero.movement_points)

	hero.spend_action_points(3)
	hud.refresh(_engine())
	assert_eq(hud._action_pips.filled, hero.action_points, "la jauge a suivi")


func test_la_timeline_montre_qui_joue_et_qui_suit() -> void:
	await _deploy_and_start()
	var hud: CanvasLayer = _scene._hud
	assert_eq(
		hud._timeline.get_child_count(), _engine().timeline().size(),
		"un badge par activation annoncée"
	)
	assert_gt(hud._timeline.get_child_count(), 1, "on voit au-delà du tour en cours")


func test_choisir_une_competence_change_la_portee_affichee() -> void:
	# § 17 : la portée doit être affichée dès qu'une compétence est
	# sélectionnée — et changer de compétence doit changer ce qu'on voit.
	await _deploy_and_start()
	var engine := _engine()
	var hero := engine.current_unit()
	if hero.abilities.size() < 2:
		pending("ce personnage n'a qu'une compétence")
		return
	var overlay: Node2D = _scene._overlay
	var counts := {}
	for ability_id: StringName in hero.abilities:
		if not engine.can_use(hero, ability_id):
			continue
		_scene._hud.set_selected_ability(ability_id)
		_scene._refresh_all()
		counts[ability_id] = overlay.attack_cells.size()
	assert_gt(counts.size(), 1, "au moins deux compétences disponibles")
	var seen := {}
	for value: int in counts.values():
		seen[value] = true
	assert_gt(seen.size(), 1, "deux compétences allument le même nombre de cases")


func test_viser_une_zone_montre_ce_qu_elle_touchera() -> void:
	# § 18 : les zones doivent être très lisibles. La portée dit où l'on
	# peut viser, la zone dit ce que ça touchera — ce n'est pas la même
	# information, et les confondre promet au joueur ce qu'il n'aura pas.
	await _deploy_and_start()
	var engine := _engine()

	# On laisse la timeline tourner jusqu'à ce que le Mage joue : la scène
	# réimpose le personnage désigné à chaque rafraîchissement, donc lui
	# forcer la main ne servirait à rien.
	var mage: Unit = null
	for i in 10:
		var active := engine.current_unit()
		if active != null and active.has_ability(&"fireball"):
			mage = active
			break
		engine.end_activation()
	if mage == null:
		pending("le Mage n'a pas joué dans les dix premières activations")
		return

	var overlay: Node2D = _scene._overlay
	_scene._hud.set_selected_ability(&"fireball")
	var aimed := engine.targetable_cells(mage, &"fireball")
	if aimed.is_empty():
		pending("aucune case à portée depuis le placement")
		return
	_scene._preview_is_ability = true
	_scene._preview_cell = aimed[0]
	_scene._refresh_overlay()
	assert_eq(
		overlay.area_cells,
		engine.affected_cells(mage, &"fireball", aimed[0]),
		"la zone dessinée est celle que le moteur touchera"
	)
	assert_lt(
		overlay.area_cells.size(), overlay.attack_cells.size(),
		"une Boule de feu vise loin et ne touche que cinq cases"
	)


func test_le_plateau_ne_passe_pas_sous_le_hud() -> void:
	# Défaut vu en capture d'écran : la liste d'équipe recouvrait le
	# terrain. La caméra cadre désormais dans la zone que le HUD laisse.
	var hud: CanvasLayer = _scene._hud
	var viewport := Vector2(1280, 720)
	var safe: Rect2 = hud.safe_area(viewport)
	assert_gt(safe.position.y, 0.0, "le bandeau haut est réservé")
	assert_lt(
		safe.position.y + safe.size.y, viewport.y,
		"le bandeau bas aussi"
	)
	assert_gt(safe.size.y, viewport.y * 0.5, "il reste plus de la moitié pour le plateau")


func test_les_panneaux_lateraux_sont_reserves_eux_aussi() -> void:
	# T9.8 : la zone sûre ne bornait que le haut et le bas. Depuis T9.7 il
	# y a une colonne de cartes à gauche et un panneau de détail à droite,
	# et le plateau était cadré sur une zone dont un tiers était couvert.
	var hud: CanvasLayer = _scene._hud
	var viewport := Vector2(1280, 720)
	var safe: Rect2 = hud.safe_area(viewport)
	assert_gt(safe.position.x, 0.0, "la colonne de cartes est réservée")
	assert_lt(
		safe.position.x + safe.size.x, viewport.x,
		"le panneau de détail aussi"
	)


func test_la_mer_borde_le_plateau_sans_le_cadrer() -> void:
	# T9.9 : la mer est du DÉCOR. Elle déborde À L'HORIZONTALE pour
	# remplir l'écart entre les panneaux et l'île, mais la caméra continue
	# de cadrer sur la grille SEULE — cadrer sur la mer coûterait 17 % de
	# la taille des cases, puisque c'est la hauteur qui contraint et
	# qu'élargir ferait passer la contrainte en largeur.
	await _deploy_and_start()
	var terrain: Node2D = _scene._terrain
	var grid := _engine().board.grid
	var tile := AssetTable.tile_size()
	var span := Vector2(grid.width * tile, grid.height * tile)

	var sea: Rect2 = terrain._sea()
	assert_lt(sea.position.x, 0.0, "la mer déborde à gauche")
	assert_gt(sea.end.x, span.x, "et à droite")
	# PAS EN HAUTEUR : une mer qui déborde des quatre côtés remplit
	# l'écran entier et le fond sombre disparaît.
	assert_eq(sea.position.y, 0.0, "la mer ne monte pas au-dessus du plateau")
	assert_eq(sea.end.y, span.y, "ni ne descend en dessous")

	# Le fondu tient DANS la marge : sinon la mer se termine par une
	# coupure franche au lieu de s'éteindre.
	var side := ViewSettings.number(&"sizes", &"sea_side_tiles", 0.0)
	var fade := ViewSettings.number(&"sizes", &"sea_fade_tiles", 0.0)
	assert_gt(fade, 0.0, "sans fondu, le bord de la mer est tranché")
	assert_lt(fade, side, "il reste de l'eau franche contre l'île")

	# LE CADRAGE NE CONNAÎT QUE LA GRILLE.
	var hud: CanvasLayer = _scene._hud
	var viewport := Vector2(1280, 720)
	var safe: Rect2 = hud.safe_area(viewport)
	var camera: Camera2D = _scene._camera
	camera.frame_board(grid, tile, safe, viewport)
	assert_almost_eq(
		camera.zoom_level(),
		minf(safe.size.x / span.x, safe.size.y / span.y),
		0.001,
		"le zoom se calcule sur la grille, jamais sur le décor"
	)


func test_le_fantome_ne_parait_que_sur_un_deplacement() -> void:
	await _deploy_and_start()
	var hero := _engine().current_unit()
	assert_false(_scene._ghost.visible, "pas de fantôme tant qu'on ne vise rien")
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
	await _deploy_and_start()
	var engine := _engine()
	var overlay: Node2D = _scene._overlay
	var seen := 0
	# On laisse la timeline tourner : les ennemis mettent quelques
	# activations à se mettre à portée, et tant qu'ils n'y sont pas la
	# couche n'a rien à afficher.
	for i in 20:
		if engine.is_finished():
			break
		engine.end_activation()
		_scene._refresh_all()
		for cell: Vector2i in overlay.threat.keys():
			assert_eq(
				int(overlay.threat[cell]), engine.threat_on(cell),
				"case %s : la couche annonce %d, le moteur %d"
					% [cell, int(overlay.threat[cell]), engine.threat_on(cell)]
			)
			seen += 1
	assert_gt(seen, 0, "aucune menace n'a jamais été affichée, le test ne prouve rien")


## Attend que la scène ait fini son animation.
##
## Sans cette attente, le test se termine pendant le glissement, GUT libère
## la scène, et la coroutine d'animation reste suspendue en retenant l'unité
## qu'elle déplaçait. Godot le signalait à la sortie par un « 1 resources
## still in use » qui ne désignait rien de compréhensible.
func _settle() -> void:
	await wait_until(func() -> bool: return not _scene.is_busy(), 3.0)


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


## Une case libre, loin de tout, où un tap ne vise rien.
func _far_cell() -> Vector2i:
	var grid := _engine().board.grid
	for cell: Vector2i in grid.cells():
		if _engine().board.unit_at(cell) != null:
			continue
		if _engine().board.move_cost_to(_engine().current_unit(), cell) >= 0:
			continue
		return cell
	return Vector2i(-1, -1)


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
	var squad := Unit.squad_from_classes([&"warrior", &"warrior", &"mage"])
	var slots := {}
	for unit: Unit in squad:
		assert_false(slots.has(unit.slot), "deux héros au même emplacement")
		slots[unit.slot] = true
	assert_eq(slots.size(), 3)

	var hud: CanvasLayer = _scene._hud
	var texts := {}
	for unit: Unit in squad:
		var name_ := tr("CLASS_%s" % String(unit.class_id).to_upper())
		var line := "%d  %s  %d/%d   PA %d/%d  PM %d/%d" % [
			unit.slot, name_, unit.hit_points, unit.max_hit_points,
			unit.action_points, unit.max_action_points,
			unit.movement_points, unit.max_movement_points,
		]
		assert_false(texts.has(line), "deux lignes de HUD identiques : %s" % line)
		texts[line] = true
	assert_not_null(hud)
