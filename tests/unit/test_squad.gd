extends GutTest

## L'équipe : quatre emplacements, trois classes, doublons autorisés.
##
## Le § 23 fixe l'équipe du MVP à quatre personnages, et le § 11 les
## classes à trois. Le joueur peut donc emmener un exemplaire de chaque et
## doubler l'un d'eux : c'est un choix de composition, pas un renoncement.
## Les doublons restent le cas courant, pas un cas limite.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()


## LE PLAFOND EST FIXE, LE NOMBRE DE CLASSES NE L'EST PLUS. Le § 23 veut
## quatre personnages au maximum et ça ne bouge pas ; le § 11 voulait trois
## classes DANS LE MVP, et le MVP est fini. Le Lancier est arrivé en
## quatrième le 2026-09-11, et c'est justement ce que la décision annonçait
## — « les autres viendront après ».
##
## CE QUE LE TEST GARDE : plus de classes que de rien, les trois du MVP
## toujours là, et moins de classes que d'emplacements n'aurait aucun sens.
func test_quatre_emplacements_et_de_quoi_les_remplir() -> void:
	assert_eq(CombatRules.team_size(), 4, "§ 23 : 4 personnages au maximum")
	var ids := Unit.hero_class_ids()
	assert_gte(ids.size(), 3, "les trois classes du MVP au minimum")
	for wanted: StringName in [&"warrior", &"archer", &"mage"]:
		assert_true(ids.has(wanted), "classe du MVP manquante : %s" % wanted)


func test_le_plafond_dur_vaut_la_taille_de_l_equipe() -> void:
	# C'est le nombre de cases de départ qu'une carte doit prévoir.
	assert_eq(CombatRules.max_heroes(), CombatRules.team_size())


func test_une_equipe_se_fabrique_a_partir_de_classes() -> void:
	var squad := Unit.squad_from_classes([&"warrior", &"archer", &"mage"])
	assert_eq(squad.size(), 3)
	assert_eq(squad[0].class_id, &"warrior")
	assert_eq(squad[2].class_id, &"mage")


func test_les_doublons_sont_autorises() -> void:
	var squad := Unit.squad_from_classes([&"warrior", &"warrior", &"mage"])
	assert_eq(squad.size(), 3)
	assert_eq(squad[0].class_id, &"warrior")
	assert_eq(squad[1].class_id, &"warrior")
	assert_ne(squad[0].id, squad[1].id, "deux héros distincts, pas le même deux fois")


func test_quatre_fois_la_meme_classe_est_legal() -> void:
	var squad := Unit.squad_from_classes([&"mage", &"mage", &"mage", &"mage"])
	assert_eq(squad.size(), 4)
	for unit: Unit in squad:
		assert_eq(unit.class_id, &"mage")


func test_chaque_heros_porte_son_numero_d_emplacement() -> void:
	# Sans lui, deux Guerriers de la même couleur sont le même sprite au
	# même endroit du roster, et le joueur ne sait pas lequel il a bougé.
	var squad := Unit.squad_from_classes([&"warrior", &"warrior", &"warrior"])
	for i in squad.size():
		assert_eq(squad[i].slot, i + 1, "emplacement du héros %d" % i)


func test_une_equipe_trop_grande_est_refusee() -> void:
	var squad := Unit.squad_from_classes(
		[&"warrior", &"archer", &"mage", &"warrior", &"archer"]
	)
	assert_eq(squad.size(), CombatRules.max_heroes())
	assert_push_error("équipe")


func test_les_doublons_partagent_leur_portrait_mais_pas_leur_etat() -> void:
	# Le portrait découle de la classe et de la couleur : deux Guerriers se
	# ressemblent, et c'est voulu. Leurs PV, eux, sont à eux.
	var squad := Unit.squad_from_classes([&"warrior", &"warrior", &"mage"])
	assert_eq(
		AssetTable.portrait(squad[0].class_id, "Blue")["path"],
		AssetTable.portrait(squad[1].class_id, "Blue")["path"]
	)
	squad[0].take_damage(15)
	assert_ne(squad[0].hit_points, squad[1].hit_points)


func test_les_doublons_ont_chacun_leurs_pa_et_leurs_pm() -> void:
	# Le point qui compte vraiment avec le modèle PA/PM : deux Guerriers
	# jouent à deux moments différents de la timeline, avec deux réserves.
	var squad := Unit.squad_from_classes([&"warrior", &"warrior"])
	squad[0].spend_action_points(3)
	squad[0].spend_movement_points(2)
	assert_eq(squad[1].action_points, squad[1].max_action_points)
	assert_eq(squad[1].movement_points, squad[1].max_movement_points)


func test_le_numero_survit_a_la_sauvegarde() -> void:
	var squad := Unit.squad_from_classes([&"mage", &"mage", &"archer"])
	var restored := Unit.from_dictionary(squad[1].to_dictionary())
	assert_eq(restored.slot, 2)
	assert_eq(restored.class_id, &"mage")


func test_toutes_les_compositions_sont_constructibles() -> void:
	# 3 classes, 4 emplacements, avec répétition : C(6, 4) = 15.
	var classes := Unit.hero_class_ids()
	var seen := {}
	for a in classes.size():
		for b in range(a, classes.size()):
			for c in range(b, classes.size()):
				for d in range(c, classes.size()):
					var squad := Unit.squad_from_classes(
						[classes[a], classes[b], classes[c], classes[d]]
					)
					assert_eq(squad.size(), 4)
					seen["%s|%s|%s|%s" % [
						classes[a], classes[b], classes[c], classes[d]
					]] = true
	# LE COMPTE SE CALCULE, IL NE S'ÉCRIT PAS. C'est le nombre de
	# combinaisons avec répétition de `team_size` parmi les classes —
	# quinze à trois classes, trente-cinq à quatre. Un nombre écrit en dur
	# échoue à chaque classe ajoutée sans que rien ne soit faux.
	var classes_count := classes.size()
	var expected := 1
	for i in CombatRules.team_size():
		expected = expected * (classes_count + i) / (i + 1)
	assert_eq(seen.size(), expected, "toutes les compositions distinctes")
