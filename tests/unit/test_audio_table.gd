extends GutTest

## La table audio est la seule source de chemins de sons. Ces tests
## portent sur la table, pas sur les fichiers : la vérification des
## fichiers réels est le travail de `tools/verify_audio.gd`.


func before_each() -> void:
	AudioTable.clear_cache()


func test_la_table_se_charge() -> void:
	assert_false(AudioTable.table().is_empty())


func test_les_trois_musiques_du_document() -> void:
	# § 13.2 : un thème de ville, un thème de bataille, un thème de boss.
	var ids := AudioTable.music_ids()
	assert_eq(ids.size(), 3)
	for expected: StringName in [&"town", &"battle", &"boss"]:
		assert_true(ids.has(expected), "musique manquante : %s" % expected)


func test_une_musique_boucle_et_porte_un_chemin_complet() -> void:
	var entry := AudioTable.music(&"town")
	assert_true(entry["loop"], "une musique d'ambiance boucle")
	assert_true(entry["path"].begins_with("res://assets/audio/music/"))
	assert_false(entry.has("file"), "le chemin relatif est remplacé, pas doublé")


func test_le_compte_d_effets_couvre_le_besoin_annonce() -> void:
	# § 13.3 : « il te faut environ 25 sons ».
	assert_gte(AudioTable.sfx_ids().size(), 25)


func test_les_effets_du_combat_sont_declares() -> void:
	# Les sons sans lesquels un coup ne se sent pas.
	for expected: StringName in [
		&"sword_hit", &"bow_release", &"arrow_hit", &"hit_flesh",
		&"unit_downed", &"push", &"ui_click", &"ui_confirm",
	]:
		assert_false(AudioTable.sfx(expected).is_empty(), "effet manquant : %s" % expected)


func test_chaque_chemin_est_sous_la_racine_audio() -> void:
	for entry: Dictionary in AudioTable.all_entries():
		assert_true(
			entry["path"].begins_with("res://assets/audio/"),
			"%s pointe hors de assets/audio : %s" % [entry["id"], entry["path"]]
		)


func test_deux_noms_logiques_ne_pointent_pas_sur_le_meme_fichier() -> void:
	# Deux évènements distincts qui sonnent pareil, c'est un oubli de
	# copier-coller bien plus souvent qu'un choix.
	var seen := {}
	for entry: Dictionary in AudioTable.all_entries():
		var path: String = entry["path"]
		assert_false(seen.has(path), "%s et %s partagent %s" % [seen.get(path, ""), entry["id"], path])
		seen[path] = entry["id"]


func test_les_manques_sont_nommes_plutot_que_remplaces_en_douce() -> void:
	# Aucun paquet installé ne fournit la gerbe d'eau ni la fanfare. Les
	# déclarer manquants vaut mieux que de leur substituer un son approchant
	# qu'on oubliera de corriger.
	var missing := AudioTable.missing_ids()
	assert_gt(missing.size(), 0)
	for id: StringName in missing:
		assert_true(AudioTable.sfx_ids().has(id) == false, "%s est à la fois déclaré et manquant" % id)
	assert_true(missing.has(&"water_splash"), "la chute dans l'eau n'a pas de son")


func test_un_son_inconnu_ne_plante_pas() -> void:
	assert_eq(AudioTable.sfx(&"explosion_nucleaire"), {})
	assert_push_error("effet sonore inconnu")


func test_une_musique_inconnue_ne_plante_pas() -> void:
	assert_eq(AudioTable.music(&"generique_de_fin"), {})
	assert_push_error("musique inconnu")
