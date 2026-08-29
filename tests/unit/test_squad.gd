extends GutTest

## L'escouade : trois emplacements, quatre classes, doublons autorisés.
##
## Décision de Gaetan (2026-08-29). Le point n'est pas de réduire la
## puissance du joueur mais de lui retirer la composition évidente : avec
## quatre emplacements il prenait un exemplaire de chaque classe et ne
## choisissait rien. À trois, il renonce toujours à quelque chose.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()


func test_trois_emplacements_pour_quatre_classes() -> void:
	assert_eq(CombatRules.squad_size(), 3)
	assert_eq(Unit.hero_class_ids().size(), 4)
	assert_lt(
		CombatRules.squad_size(), Unit.hero_class_ids().size(),
		"il doit être impossible de prendre un exemplaire de chaque classe"
	)


func test_le_plafond_laisse_la_place_a_la_caserne_de_niveau_3() -> void:
	# § 5.4 : la Caserne 3 donne « +1 héros en expédition ».
	assert_eq(CombatRules.max_heroes(), CombatRules.squad_size() + 1)


func test_une_escouade_se_fabrique_a_partir_de_classes() -> void:
	var squad := Unit.squad_from_classes([&"warrior", &"archer", &"monk"])
	assert_eq(squad.size(), 3)
	assert_eq(squad[0].class_id, &"warrior")
	assert_eq(squad[2].class_id, &"monk")


func test_les_doublons_sont_autorises() -> void:
	# C'est tout l'intérêt de la règle : 3 emplacements et 4 classes avec
	# répétition donnent 20 compositions, pas une.
	var squad := Unit.squad_from_classes([&"warrior", &"warrior", &"monk"])
	assert_eq(squad.size(), 3)
	assert_eq(squad[0].class_id, &"warrior")
	assert_eq(squad[1].class_id, &"warrior")
	assert_ne(squad[0].id, squad[1].id, "deux héros distincts, pas le même deux fois")


func test_trois_fois_la_meme_classe_est_legal() -> void:
	var squad := Unit.squad_from_classes([&"lancer", &"lancer", &"lancer"])
	assert_eq(squad.size(), 3)
	for unit: Unit in squad:
		assert_eq(unit.class_id, &"lancer")


func test_chaque_heros_porte_son_numero_d_emplacement() -> void:
	# Sans lui, deux Guerriers de la même couleur sont le même sprite au
	# même endroit du roster, et le joueur ne sait pas lequel il a bougé.
	var squad := Unit.squad_from_classes([&"warrior", &"warrior", &"warrior"])
	for i in squad.size():
		assert_eq(squad[i].slot, i + 1, "emplacement du héros %d" % i)


func test_une_escouade_trop_grande_est_refusee() -> void:
	var squad := Unit.squad_from_classes(
		[&"warrior", &"archer", &"lancer", &"monk", &"warrior"]
	)
	assert_eq(squad.size(), CombatRules.max_heroes())
	assert_push_error("escouade")


func test_les_doublons_partagent_leur_portrait_mais_pas_leur_etat() -> void:
	# Le portrait découle de la classe et de la couleur (§ 3.2) : deux
	# Guerriers se ressemblent, et c'est voulu. Leurs PV, eux, sont à eux.
	var squad := Unit.squad_from_classes([&"warrior", &"warrior", &"monk"])
	assert_eq(
		AssetTable.portrait(squad[0].class_id, "Blue")["path"],
		AssetTable.portrait(squad[1].class_id, "Blue")["path"]
	)
	squad[0].take_damage(3)
	assert_ne(squad[0].hit_points, squad[1].hit_points)


func test_le_numero_survit_a_la_sauvegarde() -> void:
	var squad := Unit.squad_from_classes([&"monk", &"monk", &"archer"])
	var restored := Unit.from_dictionary(squad[1].to_dictionary())
	assert_eq(restored.slot, 2)
	assert_eq(restored.class_id, &"monk")


func test_les_vingt_compositions_sont_toutes_constructibles() -> void:
	# 4 classes, 3 emplacements, avec répétition : C(6, 3) = 20.
	var classes := Unit.hero_class_ids()
	var seen := {}
	for a in classes.size():
		for b in range(a, classes.size()):
			for c in range(b, classes.size()):
				var squad := Unit.squad_from_classes(
					[classes[a], classes[b], classes[c]]
				)
				assert_eq(squad.size(), 3)
				seen["%s|%s|%s" % [classes[a], classes[b], classes[c]]] = true
	assert_eq(seen.size(), 20, "vingt compositions distinctes")
