extends GutTest

## Les noms des héros. Ce que ces tests protègent : une compagnie se
## régénère à l'identique à partir de sa graine, et deux héros du même nom
## restent distinguables.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	HeroNames.clear_cache()


func test_le_pack_de_noms_est_complet() -> void:
	# Le § 3.2 en demandait 120 ; c'est resté le bon ordre de grandeur.
	assert_eq(HeroNames.all_given().size(), 120)
	assert_gt(HeroNames.epithets().size(), 0)


func test_aucun_nom_n_est_vide_ni_en_double() -> void:
	var seen := {}
	for name_: String in HeroNames.all_given():
		assert_ne(name_.strip_edges(), "", "un prénom vide")
		assert_false(seen.has(name_), "prénom en double : %s" % name_)
		seen[name_] = true


func test_la_meme_graine_donne_la_meme_compagnie() -> void:
	var first := HeroNames.given(CombatRng.new(77))
	var second := HeroNames.given(CombatRng.new(77))
	assert_eq(first, second)


func test_deux_graines_ne_donnent_pas_toujours_le_meme_nom() -> void:
	var seen := {}
	for seed_value in 30:
		seen[HeroNames.given(CombatRng.new(seed_value))] = true
	assert_gt(seen.size(), 1, "le tirage ne varie pas du tout")


func test_un_nom_deja_porte_est_evite() -> void:
	var taken := HeroNames.all_given()
	taken.remove_at(0)
	var chosen := HeroNames.given(CombatRng.new(3), taken)
	assert_eq(chosen, HeroNames.all_given()[0], "le seul nom libre")


func test_quand_tout_est_pris_on_nomme_quand_meme() -> void:
	# Mieux vaut un homonyme qu'un héros sans nom : c'est précisément ce
	# que l'épithète sert à réparer.
	var chosen := HeroNames.given(CombatRng.new(3), HeroNames.all_given())
	assert_ne(chosen, "")


func test_un_homonyme_recoit_une_epithete() -> void:
	var rng := CombatRng.new(11)
	var first := Hero.recruit(1, &"warrior", rng)
	var company: Array[Hero] = [first]
	# On force l'homonymie en prétendant que tous les autres noms sont pris.
	var crowded: Array[Hero] = []
	for name_: String in HeroNames.all_given():
		var stand_in := Hero.create(99, &"warrior", name_)
		crowded.append(stand_in)
	var late := Hero.recruit(2, &"archer", CombatRng.new(4), crowded)
	assert_ne(late.epithet, "", "il fallait bien le distinguer")
	assert_true(late.display_name().contains(late.epithet))
	assert_eq(company.size(), 1)


func test_un_recrutement_ordinaire_n_a_pas_d_epithete() -> void:
	var hero := Hero.recruit(1, &"mage", CombatRng.new(21))
	assert_eq(hero.epithet, "")
	assert_ne(hero.given_name, "")
	assert_eq(hero.class_id, &"mage")


func test_une_compagnie_entiere_n_a_pas_deux_fois_le_meme_nom() -> void:
	var rng := CombatRng.new(2024)
	var company: Array[Hero] = []
	for i in CombatRules.team_size():
		company.append(Hero.recruit(i + 1, &"warrior", rng, company))
	var seen := {}
	for hero: Hero in company:
		assert_false(seen.has(hero.display_name()), "deux %s" % hero.display_name())
		seen[hero.display_name()] = true
