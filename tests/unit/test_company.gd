extends GutTest

## T2.5 — la compagnie : les héros, l'or, la réserve.
##
## L'état qui traverse la campagne, et le seul qu'il faille sauvegarder
## entre deux rencontres. Ce que ces tests protègent surtout : **rien ne
## se perd**. Un objet remplacé retourne à la réserve, un héros qui part
## rend son équipement, et une sauvegarde qui a vu ses données changer se
## charge quand même.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()
	HeroProgression.clear_cache()
	HeroNames.clear_cache()
	Equipment.clear_cache()


func _company() -> Company:
	var company := Company.new()
	var rng := CombatRng.new(1234)
	for class_id: StringName in [&"warrior", &"archer", &"mage"]:
		company.recruit(class_id, rng)
	return company


# --- Recruter et perdre des héros ------------------------------------------

func test_une_compagnie_naît_vide() -> void:
	var company := Company.new()
	assert_eq(company.size(), 0)
	assert_eq(company.gold, 0)
	assert_true(company.stash.is_empty())


func test_recruter_donne_un_heros_nomme() -> void:
	var company := Company.new()
	var hero := company.recruit(&"warrior", CombatRng.new(7))
	assert_not_null(hero)
	assert_ne(hero.given_name, "")
	assert_eq(company.size(), 1)
	assert_eq(company.hero_by_id(hero.id), hero)


func test_les_identifiants_ne_se_repetent_jamais() -> void:
	# Deux héros qui partagent un identifiant, c'est une sauvegarde qui en
	# écrase un.
	var company := _company()
	var ids := {}
	for hero: Hero in company.heroes:
		assert_false(ids.has(hero.id), "identifiant en double : %d" % hero.id)
		ids[hero.id] = true

	var departed: Hero = company.heroes[0]
	company.remove(departed.id)
	var fresh := company.recruit(&"mage", CombatRng.new(9))
	assert_ne(fresh.id, departed.id, "l'identifiant d'un partant n'est pas réattribué")


func test_un_heros_qui_part_rend_son_equipement() -> void:
	var company := _company()
	var hero: Hero = company.heroes[0]
	company.stash.append(&"chainmail")
	company.equip_from_stash(hero.id, &"chainmail")
	assert_true(company.stash.is_empty())

	company.remove(hero.id)
	assert_eq(company.size(), 2)
	assert_true(company.stash.has(&"chainmail"), "la cotte est revenue à la réserve")


func test_retirer_un_heros_absent_ne_fait_rien() -> void:
	var company := _company()
	assert_null(company.remove(999))
	assert_eq(company.size(), 3)


# --- L'équipe qui part -----------------------------------------------------

func test_l_equipe_suit_l_ordre_donne() -> void:
	# L'ordre donne le numéro d'emplacement, qui est ce qui distingue deux
	# Guerriers sur le plateau.
	var company := _company()
	var wanted: Array = [company.heroes[2].id, company.heroes[0].id]
	var squad := company.squad(wanted)
	assert_eq(squad.size(), 2)
	assert_eq(squad[0].id, wanted[0])
	assert_eq(squad[1].id, wanted[1])


func test_une_equipe_trop_grande_est_refusee() -> void:
	var company := Company.new()
	var rng := CombatRng.new(3)
	var ids: Array = []
	for i in CombatRules.max_heroes() + 2:
		ids.append(company.recruit(&"warrior", rng).id)
	assert_eq(company.squad(ids).size(), CombatRules.max_heroes())
	assert_push_error("équipe de")


func test_l_equipe_devient_des_unites_numerotees() -> void:
	var company := _company()
	var ids: Array = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	var units := company.to_units(company.squad(ids))
	assert_eq(units.size(), 3)
	for i in units.size():
		assert_eq(units[i].slot, i + 1)
		assert_true(units[i].is_hero())


func test_un_heros_equipe_entre_en_combat_avec_son_equipement() -> void:
	var company := _company()
	var warrior: Hero = company.heroes[0]
	var bare := warrior.to_unit(1).max_hit_points
	company.stash.append(&"dragonscale")
	company.equip_from_stash(warrior.id, &"dragonscale")
	assert_gt(company.to_units([warrior] as Array[Hero])[0].max_hit_points, bare)


# --- Le butin --------------------------------------------------------------

func test_encaisser_un_butin_verse_l_or_et_range_les_objets() -> void:
	var company := _company()
	var taken := company.collect({"gold": 120, "items": ["plate", "copper_ring"]})
	assert_eq(company.gold, 120)
	assert_eq(taken.size(), 2)
	assert_true(company.stash.has(&"plate"))


func test_un_butin_inventé_est_ignore_sans_planter() -> void:
	var company := _company()
	var taken := company.collect({"gold": 10, "items": ["excalibur"]})
	assert_true(taken.is_empty())
	assert_true(company.stash.is_empty())
	assert_eq(company.gold, 10)


func test_l_or_ne_descend_pas_sous_zero() -> void:
	var company := _company()
	company.collect({"gold": -500})
	assert_eq(company.gold, 0)


func test_les_butins_s_additionnent() -> void:
	var company := _company()
	company.collect({"gold": 40})
	company.collect({"gold": 60})
	assert_eq(company.gold, 100)


# --- La réserve ------------------------------------------------------------

func test_equiper_depuis_la_reserve_l_en_retire() -> void:
	var company := _company()
	company.stash.append(&"chainmail")
	assert_true(company.equip_from_stash(company.heroes[0].id, &"chainmail"))
	assert_false(company.stash.has(&"chainmail"))
	assert_eq(company.heroes[0].equipped(&"armour"), &"chainmail")


func test_l_objet_remplace_retourne_a_la_reserve() -> void:
	# Rien ne se perd : c'est la règle de la réserve.
	var company := _company()
	var hero: Hero = company.heroes[0]
	company.stash.append(&"padded_coat")
	company.stash.append(&"plate")
	company.equip_from_stash(hero.id, &"padded_coat")
	company.equip_from_stash(hero.id, &"plate")
	assert_eq(hero.equipped(&"armour"), &"plate")
	assert_true(company.stash.has(&"padded_coat"), "le gambison est revenu")


func test_on_n_equipe_pas_ce_qu_on_ne_possede_pas() -> void:
	var company := _company()
	assert_false(company.equip_from_stash(company.heroes[0].id, &"kingmaker"))


func test_on_n_equipe_pas_une_arme_d_une_autre_classe() -> void:
	var company := _company()
	var mage: Hero = company.heroes[2]
	assert_eq(mage.class_id, &"mage")
	company.stash.append(&"kingmaker")
	assert_false(company.equip_from_stash(mage.id, &"kingmaker"))
	assert_true(company.stash.has(&"kingmaker"), "l'épée est restée en réserve")


func test_retirer_un_objet_le_rend_a_la_reserve() -> void:
	var company := _company()
	var hero: Hero = company.heroes[0]
	company.stash.append(&"iron_helm")
	company.equip_from_stash(hero.id, &"iron_helm")
	assert_true(company.unequip_to_stash(hero.id, &"helmet"))
	assert_true(company.stash.has(&"iron_helm"))
	assert_eq(hero.equipped(&"helmet"), &"")


func test_retirer_un_emplacement_vide_ne_fait_rien() -> void:
	var company := _company()
	assert_false(company.unequip_to_stash(company.heroes[0].id, &"helmet"))
	assert_true(company.stash.is_empty())


# --- Sauvegarde ------------------------------------------------------------

func test_aller_retour_de_serialisation() -> void:
	var company := _company()
	company.collect({"gold": 340, "items": ["plate", "swift_boots"]})
	company.equip_from_stash(company.heroes[0].id, &"plate")
	company.heroes[1].add_experience(999999)
	company.heroes[1].level_up_free()

	var copy := Company.from_dictionary(company.to_dictionary())
	assert_eq(copy.gold, company.gold)
	assert_eq(copy.size(), company.size())
	assert_eq(copy.stash, company.stash)
	for hero: Hero in company.heroes:
		var twin := copy.hero_by_id(hero.id)
		assert_not_null(twin, "le héros %d a disparu" % hero.id)
		assert_eq(twin.display_name(), hero.display_name())
		assert_eq(twin.level, hero.level)
		assert_eq(twin.effective_stats(), hero.effective_stats())


func test_le_prochain_identifiant_survit_a_la_sauvegarde() -> void:
	# Sans lui, un rechargement réattribuerait l'identifiant d'un héros
	# encore vivant au recrutement suivant.
	var company := _company()
	var copy := Company.from_dictionary(company.to_dictionary())
	var fresh := copy.recruit(&"warrior", CombatRng.new(1))
	for hero: Hero in company.heroes:
		assert_ne(fresh.id, hero.id)


func test_un_objet_disparu_des_donnees_ne_bloque_pas_le_chargement() -> void:
	# Perdre un anneau vaut mieux que perdre la partie.
	var company := _company()
	var raw := company.to_dictionary()
	raw["stash"] = ["plate", "excalibur"]
	var copy := Company.from_dictionary(raw)
	assert_eq(copy.stash.size(), 1)
	assert_true(copy.stash.has(&"plate"))
