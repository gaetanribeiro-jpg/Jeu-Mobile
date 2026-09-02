extends GutTest

## T11.4 — l'avancement dans le monde.
##
## LE MAILLON QUI MANQUAIT DEPUIS TOUJOURS. `regions.json` déclarait six
## régions dont cinq verrouillées, et **aucune ligne du jeu n'écrivait
## jamais leur ouverture** : battre le boss de l'acte 1 changeait une
## ligne de texte et renvoyait le joueur sur la même carte. Rien
## n'échouait — une boucle sans terme se joue parfaitement, elle ne mène
## simplement nulle part.


func before_each() -> void:
	Region.clear_cache()


func _first_of_act(act: int) -> StringName:
	for region_id: StringName in Region.ids():
		if Region.act_of(region_id) == act:
			return region_id
	return &""


func test_une_partie_neuve_n_ouvre_que_le_premier_acte() -> void:
	var run := Campaign.new()
	var open := run.open_ids()
	assert_eq(open.size(), 1, "une seule terre au départ")
	assert_eq(Region.act_of(open[0]), 1)


func test_conclure_une_region_ouvre_la_suivante() -> void:
	var run := Campaign.new()
	var first := _first_of_act(1)
	var second := _first_of_act(2)
	assert_false(run.is_open(second), "l'acte 2 ne s'ouvre pas tout seul")

	assert_eq(run.clear_region(first), second, "conclure doit rendre ce qui s'ouvre")
	assert_true(run.is_cleared(first))
	assert_true(run.is_open(second), "l'acte 2 doit s'être ouvert")
	assert_true(run.is_open(first), "et le premier reste jouable")


func test_l_acte_3_attend_l_acte_2() -> void:
	# L'ORDRE VIENT DES ACTES, pas d'une liste écrite à la main : une
	# région ne s'ouvre que quand celle qui la précède est conclue.
	var run := Campaign.new()
	run.clear_region(_first_of_act(1))
	assert_false(run.is_open(_first_of_act(3)), "l'acte 3 saute son tour")
	run.clear_region(_first_of_act(2))
	assert_true(run.is_open(_first_of_act(3)))


func test_on_ne_conclut_pas_deux_fois() -> void:
	# Refaire l'acte 1 après l'avoir fini est permis — le joueur peut
	# vouloir du butin — mais ça ne doit pas réannoncer une ouverture
	# qu'il connaît déjà.
	var run := Campaign.new()
	var first := _first_of_act(1)
	assert_false(run.clear_region(first).is_empty())
	assert_true(run.clear_region(first).is_empty(), "la seconde fois n'ouvre rien")


func test_une_region_inconnue_ne_conclut_rien() -> void:
	var run := Campaign.new()
	assert_true(run.clear_region(&"pas_une_region").is_empty())
	assert_false(run.is_cleared(&"pas_une_region"))


func test_la_campagne_finit_quand_tout_le_jouable_est_conclu() -> void:
	var run := Campaign.new()
	assert_false(run.is_complete(), "rien n'est fait au départ")
	var guard := 0
	while not run.is_complete() and guard < 32:
		guard += 1
		for region_id: StringName in run.open_ids():
			if not run.is_cleared(region_id):
				run.clear_region(region_id)
				break
	assert_true(run.is_complete(), "la campagne doit pouvoir se finir")
	assert_eq(run.open_ids().size(), Region.ids().size(), "tout doit s'être ouvert")


func test_l_avancement_survit_a_une_sauvegarde() -> void:
	# Il vit dans la PARTIE, pas dans `regions.json` : le fichier de
	# données dit ce qui est ouvert au départ d'une partie neuve, la
	# sauvegarde dit ce qui s'est ouvert depuis.
	var run := Campaign.new()
	run.clear_region(_first_of_act(1))
	var reloaded := Campaign.from_dictionary(run.to_dictionary())
	assert_true(reloaded.is_cleared(_first_of_act(1)))
	assert_true(reloaded.is_open(_first_of_act(2)))


func test_une_sauvegarde_d_avant_l_avancement_ne_casse_rien() -> void:
	var fresh := Campaign.from_dictionary({})
	assert_eq(fresh.open_ids().size(), 1, "elle repart d'un monde d'acte 1")


func test_une_region_disparue_des_donnees_ne_casse_pas_la_partie() -> void:
	var reloaded := Campaign.from_dictionary({"cleared": {"pas_une_region": true}})
	assert_false(reloaded.is_cleared(&"pas_une_region"))
	assert_eq(reloaded.open_ids().size(), 1)
