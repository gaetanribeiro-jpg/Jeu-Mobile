extends GutTest

## T1.2 — l'unité de combat : ses statistiques, ses PA, ses PM, sa vie.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()


func test_les_trois_classes_du_mvp_sont_declarees() -> void:
	var ids := Unit.hero_class_ids()
	assert_eq(ids.size(), 3, "trois classes dans le MVP (§ 11)")
	for wanted: StringName in [&"warrior", &"archer", &"mage"]:
		assert_true(ids.has(wanted), "classe manquante : %s" % wanted)


func test_chaque_classe_a_des_pa_des_pm_et_une_initiative() -> void:
	for class_id: StringName in Unit.hero_class_ids():
		var unit := Unit.from_hero_class(1, class_id, Vector2i.ZERO)
		assert_gt(unit.max_hit_points, 0, "%s : PV" % class_id)
		assert_gt(unit.max_action_points, 0, "%s : PA" % class_id)
		assert_gt(unit.max_movement_points, 0, "%s : PM" % class_id)
		assert_gt(unit.initiative, 0, "%s : initiative" % class_id)
		assert_false(unit.abilities.is_empty(), "%s : compétences" % class_id)


func test_les_trois_classes_ont_des_roles_distincts() -> void:
	# Ce n'est pas un test de valeurs, c'est un test d'identité (§ 11) :
	# le Guerrier encaisse, l'Archer porte loin, le Mage frappe fort mais
	# tombe vite. Si deux classes se mettent à se ressembler, il casse.
	var warrior := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	var archer := Unit.from_hero_class(2, &"archer", Vector2i.ZERO)
	var mage := Unit.from_hero_class(3, &"mage", Vector2i.ZERO)

	assert_gt(warrior.max_hit_points, archer.max_hit_points, "le Guerrier encaisse")
	assert_gt(archer.max_hit_points, mage.max_hit_points, "le Mage est le plus fragile")
	assert_gt(warrior.defence, mage.defence, "le Guerrier se défend mieux")
	assert_gt(archer.initiative, warrior.initiative, "l'Archer joue avant le Guerrier")
	assert_gt(archer.max_movement_points, warrior.max_movement_points, "l'Archer est mobile")
	assert_gt(warrior.strength, mage.strength)
	assert_gt(mage.intelligence, warrior.intelligence)


func test_une_unite_nait_en_pleine_forme_et_du_camp_des_heros() -> void:
	var unit := Unit.from_hero_class(7, &"warrior", Vector2i(2, 3))
	assert_eq(unit.id, 7)
	assert_eq(unit.cell, Vector2i(2, 3))
	assert_eq(unit.hit_points, unit.max_hit_points)
	assert_eq(unit.action_points, unit.max_action_points)
	assert_eq(unit.movement_points, unit.max_movement_points)
	assert_true(unit.is_hero())
	assert_true(unit.is_active())


func test_la_statistique_se_lit_par_son_nom() -> void:
	# C'est le seul chemin qu'une compétence emprunte : elle dit « je monte
	# à la Force », sans savoir ce qu'est un Guerrier.
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	assert_eq(unit.stat(Unit.STAT_STRENGTH), unit.strength)
	assert_eq(unit.stat(Unit.STAT_INTELLIGENCE), unit.intelligence)
	assert_eq(unit.stat(&"inexistante"), 0, "une statistique inconnue vaut zéro")


func test_l_attaque_de_base_est_la_premiere_competence() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	assert_eq(unit.basic_ability(), unit.abilities[0])
	assert_true(unit.has_ability(unit.abilities[0]))
	assert_false(unit.has_ability(&"fireball"), "le Guerrier ne lance pas de sort")


# --- PA et PM -------------------------------------------------------------

func test_depenser_des_pa_les_retire() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	var before := unit.action_points
	assert_true(unit.spend_action_points(3))
	assert_eq(unit.action_points, before - 3)


func test_on_ne_depense_pas_des_pa_qu_on_n_a_pas() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	assert_false(unit.spend_action_points(unit.action_points + 1))
	assert_eq(unit.action_points, unit.max_action_points, "rien n'a bougé")


func test_depenser_des_pm_marque_l_unite_comme_ayant_bouge() -> void:
	# Le Tir puissant de l'Archer ne part que si ce drapeau est faux.
	var unit := Unit.from_hero_class(1, &"archer", Vector2i.ZERO)
	assert_false(unit.has_moved)
	assert_true(unit.spend_movement_points(2))
	assert_true(unit.has_moved)
	assert_eq(unit.movement_points, unit.max_movement_points - 2)


func test_depenser_zero_pm_ne_compte_pas_comme_un_deplacement() -> void:
	var unit := Unit.from_hero_class(1, &"archer", Vector2i.ZERO)
	assert_true(unit.spend_movement_points(0))
	assert_false(unit.has_moved, "rester sur place n'est pas bouger")


func test_le_debut_d_activation_refait_le_plein() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.spend_action_points(5)
	unit.spend_movement_points(2)
	unit.begin_activation()
	assert_eq(unit.action_points, unit.max_action_points)
	assert_eq(unit.movement_points, unit.max_movement_points)
	assert_false(unit.has_moved)


func test_un_malus_de_pm_s_applique_au_debut_de_l_activation() -> void:
	# C'est le Gel du Mage : la cible retrouve ses PA, mais pas tous ses PM.
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.begin_activation(2)
	assert_eq(unit.movement_points, unit.max_movement_points - 2)
	assert_eq(unit.action_points, unit.max_action_points, "les PA ne sont pas touchés")


func test_un_malus_de_pm_ne_descend_pas_sous_zero() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.begin_activation(99)
	assert_eq(unit.movement_points, 0)


func test_une_unite_epuisee_n_a_plus_rien_a_faire() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	assert_false(unit.is_spent())
	unit.spend_action_points(unit.action_points)
	unit.spend_movement_points(unit.movement_points)
	assert_true(unit.is_spent())


# --- Recharges et statuts -------------------------------------------------

func test_une_competence_en_recharge_n_est_pas_prete() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	assert_true(unit.is_ready(&"heavy_strike"))
	unit.start_cooldown(&"heavy_strike", 2)
	assert_false(unit.is_ready(&"heavy_strike"))
	assert_eq(unit.cooldown_left(&"heavy_strike"), 2)


func test_la_recharge_descend_a_chaque_activation() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.start_cooldown(&"heavy_strike", 2)
	unit.begin_activation()
	assert_eq(unit.cooldown_left(&"heavy_strike"), 1, "une activation plus tard")
	assert_false(unit.is_ready(&"heavy_strike"))
	unit.begin_activation()
	assert_true(unit.is_ready(&"heavy_strike"), "deux activations plus tard, elle revient")


func test_une_recharge_a_zero_ne_bloque_rien() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.start_cooldown(&"strike", 0)
	assert_true(unit.is_ready(&"strike"), "une Frappe est toujours disponible")


func test_un_statut_vieillit_et_disparait() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.apply_status(&"chilled", 1)
	assert_true(unit.has_status(&"chilled"))
	unit.begin_activation()
	assert_false(unit.has_status(&"chilled"), "un gel d'un tour ne dure qu'un tour")


func test_reposer_un_statut_ne_le_raccourcit_pas() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.apply_status(&"chilled", 3)
	unit.apply_status(&"chilled", 1)
	assert_eq(int(unit.statuses[&"chilled"]), 3, "on garde la plus longue")


# --- Vie et blessures -----------------------------------------------------

func test_zero_pv_met_hors_de_combat_sans_tuer() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	assert_false(unit.take_damage(unit.max_hit_points - 1))
	assert_true(unit.is_active())
	assert_true(unit.take_damage(1))
	assert_true(unit.is_downed())
	assert_eq(unit.hit_points, 0)


func test_un_exces_de_degats_ne_creuse_pas_les_pv() -> void:
	var unit := Unit.from_hero_class(1, &"mage", Vector2i.ZERO)
	unit.take_damage(9999)
	assert_eq(unit.hit_points, 0)


func test_frapper_une_unite_deja_tombee_ne_fait_rien() -> void:
	var unit := Unit.from_hero_class(1, &"mage", Vector2i.ZERO)
	unit.down()
	assert_false(unit.take_damage(10))


func test_des_degats_negatifs_ne_soignent_pas() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.take_damage(10)
	var wounded := unit.hit_points
	unit.take_damage(-5)
	assert_eq(unit.hit_points, wounded)


func test_le_soin_plafonne_au_maximum() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.take_damage(10)
	assert_eq(unit.heal(50), 10, "on ne rend que ce qui manquait")
	assert_eq(unit.hit_points, unit.max_hit_points)


func test_un_soin_ne_releve_pas_une_unite_tombee() -> void:
	var unit := Unit.from_hero_class(1, &"mage", Vector2i.ZERO)
	unit.down()
	assert_eq(unit.heal(20), 0)
	assert_true(unit.is_downed())


func test_la_releve_remet_debout() -> void:
	var unit := Unit.from_hero_class(1, &"mage", Vector2i.ZERO)
	unit.down()
	assert_true(unit.revive(5))
	assert_true(unit.is_active())
	assert_eq(unit.hit_points, 5)


func test_la_releve_ne_depasse_pas_le_maximum() -> void:
	var unit := Unit.from_hero_class(1, &"mage", Vector2i.ZERO)
	unit.down()
	unit.revive(9999)
	assert_eq(unit.hit_points, unit.max_hit_points)


func test_la_chute_dans_l_eau_met_hors_de_combat_a_pleine_vie() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	assert_true(unit.down())
	assert_true(unit.is_downed())
	assert_false(unit.down(), "on ne tombe pas deux fois")


# --- Données et sérialisation ---------------------------------------------

func test_une_classe_inconnue_ne_plante_pas() -> void:
	# Rien ne doit jamais planter parce qu'une donnée manque : c'est une
	# règle du projet, pas une politesse.
	assert_null(Unit.from_hero_class(1, &"paladin", Vector2i.ZERO))
	assert_push_error("classe de héros inconnue")


func test_aller_retour_de_serialisation() -> void:
	var unit := Unit.from_hero_class(3, &"archer", Vector2i(4, 2))
	unit.slot = 2
	unit.take_damage(12)
	unit.spend_action_points(3)
	unit.spend_movement_points(1)
	unit.start_cooldown(&"power_shot", 2)
	unit.apply_status(&"chilled", 1)

	var copy := Unit.from_dictionary(unit.to_dictionary())
	assert_eq(copy.id, unit.id)
	assert_eq(copy.class_id, unit.class_id)
	assert_eq(copy.cell, unit.cell)
	assert_eq(copy.slot, unit.slot)
	assert_eq(copy.hit_points, unit.hit_points)
	assert_eq(copy.action_points, unit.action_points)
	assert_eq(copy.movement_points, unit.movement_points)
	assert_eq(copy.initiative, unit.initiative)
	assert_eq(copy.abilities, unit.abilities)
	assert_eq(copy.cooldown_left(&"power_shot"), 2)
	assert_true(copy.has_status(&"chilled"))
	assert_eq(copy.has_moved, unit.has_moved)


func test_une_unite_ennemie_se_fabrique_a_partir_de_son_identifiant() -> void:
	var enemy := Unit.from_enemy(50, &"spear_goblin", Vector2i(1, 1))
	assert_not_null(enemy)
	assert_true(enemy.is_enemy())
	assert_eq(enemy.role, &"melee")
	assert_gt(enemy.max_action_points, 0)
	assert_false(enemy.abilities.is_empty())


func test_chaque_ennemi_declare_des_competences_qui_existent() -> void:
	for enemy_id: StringName in Unit.enemy_ids():
		var enemy := Unit.from_enemy(1, enemy_id, Vector2i.ZERO)
		assert_false(enemy.abilities.is_empty(), "%s n'a aucune compétence" % enemy_id)
		for ability_id: StringName in enemy.abilities:
			assert_not_null(
				Ability.of(ability_id), "%s : compétence inconnue %s" % [enemy_id, ability_id]
			)
