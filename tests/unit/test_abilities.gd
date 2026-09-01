extends GutTest

## T1.3 — les compétences.
##
## Une compétence est décrite entièrement par ses données (§ 47). Ces
## tests vérifient que le moteur les lit correctement, et surtout que les
## contraintes qui font la tension du combat sont bien appliquées : le
## coût en PA, la recharge, la portée minimale, l'immobilité du Tir
## puissant, le tir ami de la Boule de feu.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()


func _board(rows: Array) -> CombatBoard:
	return CombatBoard.from_rows(
		PackedStringArray(rows), CombatRules.ADJACENCY_ORTHOGONAL
	)


func _plain() -> CombatBoard:
	return _board([
		"..........", "..........", "..........", "..........",
		"..........", "..........", "..........",
	])


func _engine(board: CombatBoard) -> CombatEngine:
	var engine := CombatEngine.new(
		board, CombatObjective.from_dictionary({"kind": "eliminate"}), CombatRng.new(7)
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


# --- Les données ----------------------------------------------------------

func test_chaque_classe_declare_des_competences_qui_existent() -> void:
	for class_id: StringName in Unit.hero_class_ids():
		var unit := Unit.from_hero_class(1, class_id, Vector2i.ZERO)
		assert_false(unit.abilities.is_empty(), "%s n'a aucune compétence" % class_id)
		for ability_id: StringName in unit.abilities:
			var ability := Ability.of(ability_id)
			assert_not_null(ability, "%s : compétence inconnue %s" % [class_id, ability_id])
			assert_eq(ability.class_id, class_id, "%s appartient à une autre classe" % ability_id)


func test_le_cout_en_pa_respecte_le_bareme() -> void:
	# § 13 : légère 2, base 3, moyenne 4, puissante 5 à 7.
	for ability_id: StringName in Ability.ids():
		var ability := Ability.of(ability_id)
		assert_between(
			ability.action_points, 2, 7, "%s : coût hors barème" % ability_id
		)


func test_toute_competence_qui_fait_des_degats_monte_a_une_statistique() -> void:
	for ability_id: StringName in Ability.ids():
		var ability := Ability.of(ability_id)
		if ability.damage <= 0:
			continue
		assert_false(
			ability.scaling.is_empty(), "%s ne monte à rien" % ability_id
		)


func test_une_competence_inconnue_ne_plante_pas() -> void:
	assert_null(Ability.of(&"meteore"))
	assert_push_error("compétence inconnue")


# --- Disponibilité --------------------------------------------------------

func test_une_competence_trop_chere_est_indisponible() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	var heavy := Ability.of(&"heavy_strike")
	assert_true(heavy.is_available_to(unit))
	unit.spend_action_points(unit.action_points - heavy.action_points + 1)
	assert_false(heavy.is_available_to(unit))
	assert_eq(heavy.unavailable_reason(unit), &"ability.not_enough_ap")


func test_une_competence_en_recharge_est_indisponible() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	var heavy := Ability.of(&"heavy_strike")
	unit.start_cooldown(heavy.id, heavy.cooldown)
	assert_false(heavy.is_available_to(unit))
	assert_eq(heavy.unavailable_reason(unit), &"ability.cooling_down")


func test_le_tir_puissant_est_refuse_apres_un_deplacement() -> void:
	# LA tension de l'Archer : rester immobile pour frapper fort, donc
	# devenir une cible pour le Voleur.
	var unit := Unit.from_hero_class(1, &"archer", Vector2i.ZERO)
	var power := Ability.of(&"power_shot")
	assert_true(power.is_available_to(unit))
	unit.spend_movement_points(1)
	assert_false(power.is_available_to(unit))
	assert_eq(power.unavailable_reason(unit), &"ability.already_moved")


func test_une_competence_qu_on_n_a_pas_est_indisponible() -> void:
	var warrior := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	assert_false(Ability.of(&"fireball").is_available_to(warrior))


# --- Portée et zone -------------------------------------------------------

func test_l_archer_ne_tire_pas_sur_son_voisin() -> void:
	var shot := Ability.of(&"shot")
	assert_false(shot.is_distance_in_range(1), "portée minimale 2")
	assert_true(shot.is_distance_in_range(2))
	assert_true(shot.is_distance_in_range(5))
	assert_false(shot.is_distance_in_range(6))


func test_une_zone_simple_ne_touche_qu_une_case() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	var cells := Ability.of(&"strike").area_cells(grid, Vector2i(2, 2), Vector2i(3, 2))
	assert_eq(cells, [Vector2i(3, 2)])


func test_la_boule_de_feu_touche_la_case_et_ses_quatre_voisines() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	var cells := Ability.of(&"fireball").area_cells(grid, Vector2i(1, 3), Vector2i(4, 3))
	assert_eq(cells.size(), 5, "la case visée plus ses voisines")
	for cell: Vector2i in [
		Vector2i(4, 3), Vector2i(3, 3), Vector2i(5, 3), Vector2i(4, 2), Vector2i(4, 4)
	]:
		assert_true(cells.has(cell), "case manquante : %s" % cell)


func test_une_zone_est_bornee_a_la_grille() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	var cells := Ability.of(&"fireball").area_cells(grid, Vector2i(3, 3), Vector2i(0, 0))
	for cell: Vector2i in cells:
		assert_true(grid.contains(cell), "case hors grille : %s" % cell)
	assert_eq(cells.size(), 3, "un coin ne touche que trois cases")


func test_l_attaque_en_ligne_du_troll_suit_la_direction_du_coup() -> void:
	var grid := Grid.new(8, 6, CombatRules.ADJACENCY_ORTHOGONAL)
	var cells := Ability.of(&"troll_smash").area_cells(grid, Vector2i(2, 3), Vector2i(3, 3))
	assert_eq(cells, [Vector2i(3, 3), Vector2i(4, 3)], "la cible et celui de derrière")


# --- En jeu ---------------------------------------------------------------

func test_lancer_une_competence_depense_ses_pa_et_arme_sa_recharge() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(2, 2))
	_enemy(board, &"spear_goblin", Vector2i(3, 2))
	var engine := _engine(board)
	var heavy := Ability.of(&"heavy_strike")

	var before := warrior.action_points
	assert_false(engine.use_ability(warrior, &"heavy_strike", Vector2i(3, 2)).is_empty())
	assert_eq(warrior.action_points, before - heavy.action_points)
	assert_false(warrior.is_ready(&"heavy_strike"))


func test_deux_frappes_dans_le_meme_tour() -> void:
	# 8 PA, une Frappe à 3 : c'est le tour du § 14, et il doit passer.
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(2, 2))
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 2))
	var engine := _engine(board)
	var before := goblin.hit_points

	assert_false(engine.use_ability(warrior, &"strike", Vector2i(3, 2)).is_empty())
	var after_first := goblin.hit_points
	assert_lt(after_first, before, "le premier coup a porté")
	assert_false(engine.use_ability(warrior, &"strike", Vector2i(3, 2)).is_empty())
	assert_lt(goblin.hit_points, after_first, "le second aussi")
	assert_eq(warrior.action_points, warrior.max_action_points - 6)


func test_on_ne_lance_pas_sans_pa() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(2, 2))
	_enemy(board, &"spear_goblin", Vector2i(3, 2))
	var engine := _engine(board)

	warrior.spend_action_points(warrior.action_points)
	assert_true(engine.use_ability(warrior, &"strike", Vector2i(3, 2)).is_empty())


func test_la_boule_de_feu_brule_plusieurs_ennemis_d_un_coup() -> void:
	var board := _plain()
	var mage := _hero(board, &"mage", Vector2i(1, 3))
	var first := _enemy(board, &"gnome", Vector2i(4, 3), 90)
	var second := _enemy(board, &"gnome", Vector2i(5, 3), 91)
	var engine := _engine(board)

	assert_false(engine.use_ability(mage, &"fireball", Vector2i(4, 3)).is_empty())
	assert_lt(first.hit_points, first.max_hit_points, "la cible")
	assert_lt(second.hit_points, second.max_hit_points, "et son voisin")


func test_la_boule_de_feu_brule_aussi_les_allies() -> void:
	# Sans tir ami, le positionnement du Mage ne coûterait rien (§ 20).
	var board := _plain()
	var mage := _hero(board, &"mage", Vector2i(1, 3), 1)
	var friend := _hero(board, &"warrior", Vector2i(5, 3), 2)
	_enemy(board, &"gnome", Vector2i(4, 3))
	var engine := _engine(board)

	engine.use_ability(mage, &"fireball", Vector2i(4, 3))
	assert_lt(friend.hit_points, friend.max_hit_points, "le Guerrier a pris le sort")


func test_la_boule_de_feu_n_atteint_pas_son_lanceur() -> void:
	var board := _plain()
	var mage := _hero(board, &"mage", Vector2i(3, 3))
	_enemy(board, &"gnome", Vector2i(5, 3))
	var engine := _engine(board)

	engine.use_ability(mage, &"fireball", Vector2i(5, 3))
	assert_eq(mage.hit_points, mage.max_hit_points)


func test_la_frappe_ne_touche_pas_les_allies() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(2, 2), 1)
	var friend := _hero(board, &"archer", Vector2i(3, 2), 2)
	_enemy(board, &"gnome", Vector2i(6, 2))
	var engine := _engine(board)

	engine.use_ability(warrior, &"strike", Vector2i(3, 2))
	assert_eq(friend.hit_points, friend.max_hit_points)


func test_le_gel_retire_des_pm_a_la_prochaine_activation() -> void:
	var board := _plain()
	var mage := _hero(board, &"mage", Vector2i(2, 3))
	var goblin := _enemy(board, &"gnome", Vector2i(5, 3))
	var engine := _engine(board)

	engine.use_ability(mage, &"frost", Vector2i(5, 3))
	assert_true(goblin.has_status(&"chilled"))

	goblin.begin_activation(CombatRules.status_movement_penalty(&"chilled"))
	assert_eq(
		goblin.movement_points,
		goblin.max_movement_points - CombatRules.status_movement_penalty(&"chilled")
	)


func test_le_bond_de_l_archer_ne_coute_pas_de_pm() -> void:
	var board := _plain()
	var archer := _hero(board, &"archer", Vector2i(4, 3))
	_enemy(board, &"gnome", Vector2i(8, 3))
	var engine := _engine(board)

	var before := archer.movement_points
	assert_false(engine.use_ability(archer, &"hop_back", Vector2i(2, 3)).is_empty())
	assert_eq(archer.cell, Vector2i(2, 3))
	assert_eq(archer.movement_points, before, "aucun PM dépensé")
	assert_true(archer.has_moved, "mais cela reste un déplacement")


func test_le_bond_ne_pose_pas_l_archer_sur_quelqu_un() -> void:
	var board := _plain()
	var archer := _hero(board, &"archer", Vector2i(4, 3), 1)
	_hero(board, &"warrior", Vector2i(2, 3), 2)
	_enemy(board, &"gnome", Vector2i(8, 3))
	var engine := _engine(board)

	assert_true(engine.use_ability(archer, &"hop_back", Vector2i(2, 3)).is_empty())
	assert_eq(archer.cell, Vector2i(4, 3))


func test_la_provocation_redirige_un_ennemi_adjacent() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3), 1)
	var archer := _hero(board, &"archer", Vector2i(3, 2), 2)
	var goblin := _enemy(board, &"gnome", Vector2i(3, 1))
	var engine := _engine(board)

	# Sans provocation, le gobelin vise l'Archer, qui est à sa portée.
	assert_eq(engine.intent_of(goblin.id).target_cell(goblin.cell), archer.cell)

	engine.use_ability(warrior, &"taunt", warrior.cell)
	assert_true(engine.is_taunting(warrior.id))


func test_la_provocation_ne_porte_pas_a_distance() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(0, 5), 1)
	var archer := _hero(board, &"archer", Vector2i(6, 1), 2)
	var goblin := _enemy(board, &"gnome", Vector2i(6, 2))
	var engine := _engine(board)

	engine.use_ability(warrior, &"taunt", warrior.cell)
	assert_eq(
		engine.intent_of(goblin.id).target_cell(goblin.cell), archer.cell,
		"le gobelin est trop loin pour être provoqué"
	)


# --- Ce qu'un tir a le droit de viser -------------------------------------

func test_une_attaque_a_cible_unique_ne_part_pas_sur_du_vide() -> void:
	# Sinon l'Archer dépense 3 PA pour rien et n'a aucun moyen de
	# comprendre ce qui vient de se passer.
	var board := _plain()
	var archer := _hero(board, &"archer", Vector2i(1, 3))
	_enemy(board, &"gnome", Vector2i(6, 3))
	var engine := _engine(board)

	assert_true(
		board.targetable_cells(archer, Ability.of(&"shot")).has(Vector2i(4, 3)),
		"la case vide est bien dans la portée affichée"
	)
	assert_false(
		engine.can_aim(archer, &"shot", Vector2i(4, 3)),
		"mais le tir n'y est pas légal"
	)
	assert_true(engine.use_ability(archer, &"shot", Vector2i(4, 3)).is_empty())
	assert_eq(archer.action_points, archer.max_action_points, "aucun PA perdu")


func test_une_attaque_a_cible_unique_part_sur_un_ennemi() -> void:
	var board := _plain()
	var archer := _hero(board, &"archer", Vector2i(1, 3))
	_enemy(board, &"gnome", Vector2i(4, 3))
	var engine := _engine(board)
	assert_true(engine.can_aim(archer, &"shot", Vector2i(4, 3)))


func test_une_attaque_a_cible_unique_ne_part_pas_sur_un_allie() -> void:
	# Sans tir ami, elle ne toucherait personne : c'est le même gâchis.
	var board := _plain()
	var archer := _hero(board, &"archer", Vector2i(1, 3), 1)
	_hero(board, &"warrior", Vector2i(4, 3), 2)
	_enemy(board, &"gnome", Vector2i(8, 3))
	var engine := _engine(board)
	assert_false(engine.can_aim(archer, &"shot", Vector2i(4, 3)))


func test_une_competence_de_zone_se_lance_sur_du_vide() -> void:
	# Viser entre deux ennemis pour les attraper tous les deux est
	# précisément l'usage d'une Boule de feu (§ 18).
	var board := _plain()
	var mage := _hero(board, &"mage", Vector2i(1, 3))
	var first := _enemy(board, &"gnome", Vector2i(4, 2), 90)
	var second := _enemy(board, &"gnome", Vector2i(4, 4), 91)
	var engine := _engine(board)

	assert_true(
		engine.can_aim(mage, &"fireball", Vector2i(4, 3)),
		"la case du milieu est vide, et c'est là qu'il faut viser"
	)
	engine.use_ability(mage, &"fireball", Vector2i(4, 3))
	assert_lt(first.hit_points, first.max_hit_points)
	assert_lt(second.hit_points, second.max_hit_points)


func test_le_bond_se_lance_sur_une_case_vide() -> void:
	var board := _plain()
	var archer := _hero(board, &"archer", Vector2i(4, 3))
	_enemy(board, &"gnome", Vector2i(8, 3))
	var engine := _engine(board)
	assert_true(engine.can_aim(archer, &"hop_back", Vector2i(2, 3)))


func test_la_provocation_ne_vise_que_sa_propre_case() -> void:
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(3, 3))
	_enemy(board, &"gnome", Vector2i(4, 3))
	var engine := _engine(board)
	assert_true(engine.can_aim(warrior, &"taunt", warrior.cell))
	assert_false(engine.can_aim(warrior, &"taunt", Vector2i(4, 3)))


func test_toute_competence_est_annulable() -> void:
	# Rien n'est irréversible avant la validation de l'activation.
	var board := _plain()
	var warrior := _hero(board, &"warrior", Vector2i(2, 2))
	var goblin := _enemy(board, &"spear_goblin", Vector2i(3, 2))
	var engine := _engine(board)

	engine.use_ability(warrior, &"heavy_strike", Vector2i(3, 2))
	assert_lt(goblin.hit_points, goblin.max_hit_points)
	assert_true(engine.undo())
	assert_eq(goblin.hit_points, goblin.max_hit_points, "la vie est revenue")
	assert_eq(warrior.action_points, warrior.max_action_points, "les PA aussi")
	assert_true(warrior.is_ready(&"heavy_strike"), "et la recharge")
