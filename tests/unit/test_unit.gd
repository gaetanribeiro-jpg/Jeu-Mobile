extends GutTest

## Une unité ne meurt pas : elle tombe. C'est la décision verrouillée du
## § 3.4, et c'est le point le plus facile à casser par inadvertance.


func before_each() -> void:
	Unit.reload()


func test_les_quatre_classes_sont_declarees() -> void:
	var ids := Unit.hero_class_ids()
	assert_eq(ids.size(), 4, "quatre classes de héros (§ 3.1)")
	for expected: StringName in [&"warrior", &"archer", &"lancer", &"monk"]:
		assert_true(ids.has(expected), "classe manquante : %s" % expected)


func test_les_statistiques_du_tableau_de_conception() -> void:
	# Les valeurs du § 3.1, une par une. Si une seule bouge, ce test le dit.
	var expected := {
		&"warrior": {"hp": 8, "move": 3, "min": 1, "max": 1, "dmg": 3},
		&"archer": {"hp": 4, "move": 3, "min": 2, "max": 4, "dmg": 2},
		&"lancer": {"hp": 6, "move": 3, "min": 1, "max": 2, "dmg": 2},
		&"monk": {"hp": 5, "move": 4, "min": 1, "max": 2, "dmg": 1},
	}
	for class_id: StringName in expected.keys():
		var unit := Unit.from_hero_class(1, class_id, Vector2i.ZERO)
		var want: Dictionary = expected[class_id]
		assert_eq(unit.max_hit_points, want["hp"], "%s : PV" % class_id)
		assert_eq(unit.movement, want["move"], "%s : déplacement" % class_id)
		assert_eq(unit.range_min, want["min"], "%s : portée mini" % class_id)
		assert_eq(unit.range_max, want["max"], "%s : portée maxi" % class_id)
		assert_eq(unit.damage, want["dmg"], "%s : dégâts" % class_id)


func test_une_unite_naît_en_pleine_forme_et_du_camp_des_heros() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i(2, 3))
	assert_eq(unit.hit_points, unit.max_hit_points)
	assert_true(unit.is_active())
	assert_true(unit.is_hero())
	assert_false(unit.is_enemy())
	assert_eq(unit.cell, Vector2i(2, 3))
	assert_false(unit.aquatic, "aucun héros ne nage")


func test_qui_frappe_a_distance() -> void:
	assert_false(Unit.from_hero_class(1, &"warrior", Vector2i.ZERO).is_ranged())
	assert_true(Unit.from_hero_class(2, &"archer", Vector2i.ZERO).is_ranged())
	assert_true(Unit.from_hero_class(3, &"lancer", Vector2i.ZERO).is_ranged())


func test_seul_l_archer_a_une_portee_minimale() -> void:
	# L'Archer ne peut pas tirer sur son voisin : c'est ce qui l'oblige à
	# reculer, et donc ce qui donne son intérêt au Thief qui le vise.
	assert_true(Unit.from_hero_class(1, &"archer", Vector2i.ZERO).has_minimum_range())
	for class_id: StringName in [&"warrior", &"lancer", &"monk"]:
		assert_false(
			Unit.from_hero_class(1, class_id, Vector2i.ZERO).has_minimum_range(),
			"%s ne doit pas avoir de portée minimale" % class_id
		)


func test_zero_pv_met_hors_de_combat_sans_tuer() -> void:
	var unit := Unit.from_hero_class(1, &"monk", Vector2i.ZERO)
	assert_false(unit.take_damage(3), "5 PV moins 3 : encore debout")
	assert_eq(unit.hit_points, 2)
	assert_true(unit.take_damage(2), "le coup qui fait tomber")
	assert_eq(unit.hit_points, 0, "les PV ne descendent pas sous zéro")
	assert_true(unit.is_downed())
	assert_false(unit.is_active())


func test_un_exces_de_degats_ne_creuse_pas_les_pv() -> void:
	var unit := Unit.from_hero_class(1, &"archer", Vector2i.ZERO)
	unit.take_damage(99)
	assert_eq(unit.hit_points, 0)


func test_frapper_une_unite_deja_tombee_ne_fait_rien() -> void:
	var unit := Unit.from_hero_class(1, &"archer", Vector2i.ZERO)
	unit.take_damage(99)
	assert_false(unit.take_damage(5), "on ne fait pas tomber deux fois")


func test_des_degats_negatifs_ne_soignent_pas() -> void:
	# Le modificateur de la forêt vaut −1 : sur une attaque à 1 dégât,
	# le total doit s'arrêter à zéro, jamais rendre des PV.
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.take_damage(3)
	assert_eq(unit.hit_points, 5)
	unit.take_damage(-2)
	assert_eq(unit.hit_points, 5, "un soin déguisé en dégât négatif est refusé")


func test_le_soin_plafonne_au_maximum() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.take_damage(5)
	assert_eq(unit.heal(2), 2, "2 PV rendus")
	assert_eq(unit.hit_points, 5)
	assert_eq(unit.heal(99), 3, "seulement les 3 PV qui manquaient")
	assert_eq(unit.hit_points, unit.max_hit_points)
	assert_eq(unit.heal(1), 0, "à plein, un soin ne rend rien")


func test_un_soin_ne_releve_pas_une_unite_tombee() -> void:
	# Seule la Relève du Moine remet debout. Un soin ordinaire sur un héros
	# tombé doit rester sans effet, sinon la blessure ne coûte plus rien.
	var unit := Unit.from_hero_class(1, &"monk", Vector2i.ZERO)
	unit.take_damage(99)
	assert_eq(unit.heal(5), 0)
	assert_true(unit.is_downed())


func test_la_releve_remet_debout_avec_un_pv() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	unit.take_damage(99)
	assert_true(unit.revive(1))
	assert_true(unit.is_active())
	assert_eq(unit.hit_points, 1)
	assert_false(unit.revive(1), "on ne relève pas une unité debout")


func test_la_releve_ne_depasse_pas_le_maximum() -> void:
	var unit := Unit.from_hero_class(1, &"monk", Vector2i.ZERO)
	unit.down()
	unit.revive(99)
	assert_eq(unit.hit_points, unit.max_hit_points)


func test_la_chute_dans_l_eau_met_hors_de_combat_a_pleine_vie() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	assert_true(unit.down(), "8 PV intacts, mais l'eau ne négocie pas")
	assert_true(unit.is_downed())
	assert_eq(unit.hit_points, 0)


func test_le_debut_de_tour_rend_le_droit_d_agir() -> void:
	var unit := Unit.from_hero_class(1, &"archer", Vector2i.ZERO)
	unit.has_moved = true
	unit.has_acted = true
	assert_true(unit.is_spent())
	unit.begin_turn()
	assert_false(unit.has_moved)
	assert_false(unit.has_acted)
	assert_false(unit.is_spent())


func test_une_classe_inconnue_ne_plante_pas() -> void:
	assert_null(Unit.from_hero_class(1, &"paladin", Vector2i.ZERO))
	assert_push_error("classe de héros inconnue")


func test_aller_retour_de_serialisation() -> void:
	var unit := Unit.from_hero_class(7, &"lancer", Vector2i(3, 4))
	unit.take_damage(2)
	unit.has_moved = true
	var restored := Unit.from_dictionary(unit.to_dictionary())
	assert_eq(restored.id, 7)
	assert_eq(restored.class_id, &"lancer")
	assert_eq(restored.cell, Vector2i(3, 4))
	assert_eq(restored.hit_points, 4)
	assert_eq(restored.max_hit_points, 6)
	assert_true(restored.has_moved)
	assert_true(restored.is_hero())
	assert_eq(restored.to_dictionary(), unit.to_dictionary(), "aller-retour stable")


func test_une_unite_ennemie_se_fabrique_a_partir_de_statistiques() -> void:
	var enemy := Unit.from_stats(
		2, &"spear_goblin", Unit.Side.ENEMIES, Vector2i(6, 1),
		{"hit_points": 3, "movement": 3, "range_min": 1, "range_max": 1, "damage": 2}
	)
	assert_true(enemy.is_enemy())
	assert_eq(enemy.hit_points, 3)
	assert_eq(enemy.cell, Vector2i(6, 1))
