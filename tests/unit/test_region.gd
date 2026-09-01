extends GutTest

## T3.1 — les régions.
##
## Deux propriétés à protéger. La première : une région verrouillée n'a pas
## de cartes et rien ne doit en exiger, sinon déclarer les cinq régions du
## § 26 pour la carte du monde ferait tomber le jeu. La seconde : la
## fenêtre de tirage glisse vers les cartes dures avec la profondeur —
## c'est toute l'escalade du § 29, et elle ne touche à aucun chiffre de
## combat.


func before_each() -> void:
	Region.clear_cache()
	CombatRules.clear_cache()


# --- Ce que la table promet ------------------------------------------------

func test_les_six_regions_du_paragraphe_26_sont_declarees() -> void:
	assert_eq(Region.ids().size(), 6)


func test_les_regions_sortent_dans_l_ordre_des_actes() -> void:
	# La carte du monde les propose dans cet ordre ; il ne doit pas dépendre
	# de l'ordre d'écriture du fichier.
	var previous := 0
	for region_id: StringName in Region.ids():
		assert_true(Region.act_of(region_id) >= previous, String(region_id))
		previous = Region.act_of(region_id)


func test_une_seule_region_est_ouverte_au_mvp() -> void:
	assert_eq(Region.unlocked_ids(), [&"greenlands"] as Array[StringName])


func test_une_region_verrouillee_n_a_pas_de_cartes_et_ne_plante_pas() -> void:
	assert_true(Region.encounter_maps(&"black_empire").is_empty())
	assert_true(Region.boss_map(&"black_empire").is_empty())
	assert_true(Region.chain_pattern(&"black_empire").is_empty())


func test_une_region_inconnue_se_signale() -> void:
	Region.entry(&"atlantide")
	assert_push_error("Region : région inconnue « atlantide »")


func test_toutes_les_cartes_declarees_existent() -> void:
	# Un nom de carte mal orthographié ne doit pas se découvrir en pleine
	# expédition, deux rencontres après le départ.
	var known := CombatMap.map_ids()
	for region_id: StringName in Region.unlocked_ids():
		for map_id: StringName in Region.encounter_maps(region_id):
			assert_true(known.has(map_id), String(map_id))
		assert_true(known.has(Region.miniboss_map(region_id)))
		assert_true(known.has(Region.boss_map(region_id)))


func test_le_boss_et_le_mini_boss_ne_sont_pas_des_rencontres_ordinaires() -> void:
	# Sinon le boss pourrait tomber au milieu de la chaîne, et le mini-boss
	# deux fois de suite.
	for region_id: StringName in Region.unlocked_ids():
		var ordinary := Region.encounter_maps(region_id)
		assert_false(ordinary.has(Region.boss_map(region_id)))
		assert_false(ordinary.has(Region.miniboss_map(region_id)))


# --- L'escalade du § 29 ----------------------------------------------------

func test_la_fenetre_glisse_vers_les_cartes_dures() -> void:
	var shallow := Region.map_window(&"greenlands", 0)
	var deep := Region.map_window(&"greenlands", 12)
	assert_eq(shallow.size(), deep.size(), "la fenêtre change de taille")
	assert_ne(shallow, deep, "la fenêtre ne bouge pas avec la profondeur")
	# Le fond de l'expédition ne propose plus la carte du tutoriel.
	assert_false(deep.has(Region.encounter_maps(&"greenlands")[0]))


func test_la_fenetre_ne_deborde_jamais_de_la_liste() -> void:
	var maps := Region.encounter_maps(&"greenlands")
	for depth in 40:
		var window := Region.map_window(&"greenlands", depth)
		assert_false(window.is_empty(), "profondeur %d" % depth)
		for map_id: StringName in window:
			assert_true(maps.has(map_id))


func test_la_fenetre_reste_contigue() -> void:
	# Une fenêtre trouée ferait réapparaître des cartes faciles au fond.
	var maps := Region.encounter_maps(&"greenlands")
	for depth in 20:
		var window := Region.map_window(&"greenlands", depth)
		var start := maps.find(window[0])
		assert_eq(window, maps.slice(start, start + window.size()))


func test_le_tirage_se_rejoue_a_l_identique() -> void:
	var first := Region.draw_map(&"greenlands", 2, CombatRng.new(99))
	var second := Region.draw_map(&"greenlands", 2, CombatRng.new(99))
	assert_eq(first, second)


func test_le_tirage_evite_la_carte_qu_on_vient_de_faire() -> void:
	# Deux fois la même carte de suite est la seule répétition que le joueur
	# remarque vraiment.
	for seed_value in 30:
		var previous := Region.draw_map(&"greenlands", 1, CombatRng.new(seed_value))
		var next := Region.draw_map(&"greenlands", 1, CombatRng.new(seed_value), previous)
		assert_ne(next, previous)


func test_une_longueur_de_corps_reste_dans_ses_bornes() -> void:
	var body: Dictionary = Region.chain(&"greenlands").get("body", {})
	for seed_value in 50:
		var drawn := Region.body_length(&"greenlands", CombatRng.new(seed_value))
		assert_between(drawn, int(body["min"]), int(body["max"]))
