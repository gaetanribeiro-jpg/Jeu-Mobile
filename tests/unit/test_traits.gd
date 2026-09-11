extends GutTest

## Les traits de caractère, et le recrutement à trois candidats (T12.3).
##
## LE REPROCHE DE GAETAN, EN UNE PHRASE : « un bâtiment = une classe = un
## héros générique ». Avec un seul recruté possible, l'écran du royaume
## n'offrait pas une décision, il offrait un bouton.
##
## CE QUE CES TESTS PROTÈGENT EN PRIORITÉ, dans cet ordre :
##  1. qu'un trait soit un ÉCHANGE — s'il était un bonus, l'un des trois
##     candidats serait « le bon » et en proposer trois reviendrait à en
##     proposer un avec deux distractions ;
##  2. que les candidats soient une FONCTION et pas un tirage — sortir de
##     l'écran et y revenir ne doit pas relancer les dés, sans quoi le
##     joueur n'a pas trois candidats, il en a autant qu'il a de patience ;
##  3. que le trait SURVIVE à la sauvegarde, comme le rang.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()
	HeroProgression.clear_cache()
	HeroNames.clear_cache()
	Equipment.clear_cache()
	ResourceTable.clear_cache()
	Worksite.clear_cache()
	Buildings.clear_cache()
	Ascension.clear_cache()
	HeroTrait.clear_cache()


## L'or vit dans la bourse de la compagnie, pas dans les réserves du
## royaume — et le recrutement en demande.
func _purse(gold: int = 100000) -> Company:
	var company := Company.new()
	company.gold = gold
	return company


func _rich() -> Kingdom:
	var kingdom := Kingdom.create()
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = 100000
	for building_id: StringName in Buildings.ids():
		kingdom.levels[building_id] = maxi(kingdom.level_of(building_id), 1)
	return kingdom


func _names(offered: Array[Hero]) -> Array:
	var out: Array = []
	for hero: Hero in offered:
		out.append(hero.display_name())
	return out


# --- Le trait est un échange ------------------------------------------------

func test_chaque_trait_donne_autant_qu_il_retire() -> void:
	assert_gt(HeroTrait.ids().size(), 0, "aucun trait dans les données")
	for trait_id: StringName in HeroTrait.ids():
		var given := Equipment.price_of_grants(HeroTrait.grants(trait_id))
		var taken := Equipment.price_of_grants(HeroTrait.costs(trait_id))
		assert_almost_eq(given, taken, 0.01,
			"%s : %.1f donné pour %.1f retiré" % [trait_id, given, taken])


func test_les_modificateurs_sont_le_gain_moins_le_retrait() -> void:
	var modifiers := HeroTrait.modifiers(&"hardy")
	assert_eq(int(modifiers.get("hit_points", 0)), 20)
	assert_eq(int(modifiers.get("agility", 0)), -2)


## L'ÉCHANGE DOIT SE VOIR SUR LA FICHE, pas seulement dans le fichier :
## c'est `effective_stats` qui décide, et un trait qui s'arrêterait à
## `Hero.trait_id` serait une septième mécanique déclarée et jamais
## branchée.
func test_le_trait_atteint_les_statistiques_du_heros() -> void:
	var plain := Hero.create(1, &"warrior", "Aldric")
	var hardy := Hero.create(2, &"warrior", "Bregon")
	hardy.trait_id = &"hardy"
	var before: Dictionary = plain.effective_stats()
	var after: Dictionary = hardy.effective_stats()
	assert_eq(
		int(after["hit_points"]) - int(before["hit_points"]), 20,
		"l'endurci n'a pas ses points de vie"
	)
	assert_lt(int(after["agility"]), int(before["agility"]),
		"l'endurci ne paie pas son agilité")


func test_un_heros_sans_trait_reste_jouable() -> void:
	var hero := Hero.create(1, &"archer", "Naïs")
	assert_true(hero.trait_id.is_empty())
	assert_gt(int(hero.effective_stats().get("hit_points", 0)), 0)


# --- Les candidats sont une fonction ---------------------------------------

func test_le_batiment_propose_trois_candidats() -> void:
	var kingdom := _rich()
	var offered := kingdom.candidates(&"barracks", _purse(), CombatRng.new(7))
	assert_eq(offered.size(), Buildings.candidate_count())
	# LA CASERNE EN FORME DEUX depuis que le Lancier existe, et les trois
	# candidats tournent entre elles : le choix porte donc aussi sur la
	# classe, pas seulement sur le caractère.
	var taught := Buildings.recruits(&"barracks")
	assert_gt(taught.size(), 1, "la caserne devrait former plusieurs classes")
	var seen_classes := {}
	for hero: Hero in offered:
		assert_true(taught.has(hero.class_id), "candidat hors programme : %s" % hero.class_id)
		seen_classes[hero.class_id] = true
	assert_eq(
		seen_classes.size(), taught.size(),
		"les trois candidats devraient couvrir les deux classes"
	)


## LE CŒUR DU SYSTÈME. Sortir de l'écran du royaume et y revenir rappelle
## `candidates()` ; si les trois changeaient, le joueur relancerait les dés
## en cliquant deux fois et le choix n'en serait plus un.
func test_les_candidats_ne_changent_pas_quand_on_redemande() -> void:
	var kingdom := _rich()
	var company := _purse()
	var rng := CombatRng.new(11)
	var first := kingdom.candidates(&"barracks", company, rng)
	var again := kingdom.candidates(&"barracks", company, rng)
	assert_eq(_names(first), _names(again))
	assert_eq(first[0].trait_id, again[0].trait_id)


## Regarder l'étal ne doit pas décaler le hasard des combats à venir —
## même leçon que les rochers du rivage en T9.10.
func test_regarder_les_candidats_ne_consomme_aucun_tirage() -> void:
	var kingdom := _rich()
	var rng := CombatRng.new(3)
	var before := rng.draw_count()
	kingdom.candidates(&"barracks", _purse(), rng)
	assert_eq(rng.draw_count(), before)


func test_les_trois_candidats_ont_des_caracteres_differents() -> void:
	var kingdom := _rich()
	var seen := {}
	var offered := kingdom.candidates(&"barracks", _purse(), CombatRng.new(5))
	for hero: Hero in offered:
		assert_true(HeroTrait.exists(hero.trait_id),
			"un candidat sans caractère : %s" % hero.trait_id)
		assert_false(seen.has(hero.trait_id), "deux fois le même caractère")
		seen[hero.trait_id] = true


func test_deux_batiments_ne_proposent_pas_les_memes_gens() -> void:
	var kingdom := _rich()
	var company := _purse()
	var rng := CombatRng.new(13)
	var warriors := kingdom.candidates(&"barracks", company, rng)
	var archers := kingdom.candidates(&"archery", company, rng)
	assert_ne(_names(warriors), _names(archers))


func test_un_batiment_qui_ne_forme_personne_ne_propose_rien() -> void:
	var kingdom := _rich()
	assert_eq(kingdom.candidates(&"castle", _purse(), CombatRng.new(1)).size(), 0)


func test_un_batiment_non_bati_ne_propose_rien() -> void:
	var kingdom := Kingdom.create()
	kingdom.levels[&"barracks"] = 0
	assert_eq(kingdom.candidates(&"barracks", _purse(), CombatRng.new(1)).size(), 0)


# --- Engager ---------------------------------------------------------------

func test_engager_prend_le_candidat_designe() -> void:
	var kingdom := _rich()
	var company := _purse()
	var rng := CombatRng.new(17)
	var offered := kingdom.candidates(&"barracks", company, rng)
	var wanted := offered[1]
	var hired := kingdom.hire(&"barracks", 1, company, rng)
	assert_not_null(hired)
	assert_eq(hired.display_name(), wanted.display_name())
	assert_eq(hired.trait_id, wanted.trait_id)
	assert_eq(company.size(), 1)


## LES DEUX AUTRES PARTENT AVEC LUI : c'est ce qui donne son poids au
## choix. Sans ça, prendre le troisième « plus tard » serait toujours
## possible et il n'y aurait rien à arbitrer.
func test_engager_renouvelle_la_fournee() -> void:
	var kingdom := _rich()
	var company := _purse()
	var rng := CombatRng.new(19)
	var before := _names(kingdom.candidates(&"barracks", company, rng))
	kingdom.hire(&"barracks", 0, company, rng)
	var after := _names(kingdom.candidates(&"barracks", company, rng))
	assert_ne(before, after)


func test_engager_paie_le_prix() -> void:
	var kingdom := _rich()
	var company := _purse(100000)
	var cost := Buildings.recruit_cost(&"barracks")
	var gold_before := company.gold
	var food_before := kingdom.amount(&"food", company)
	kingdom.hire(&"barracks", 0, company, CombatRng.new(23))
	assert_eq(company.gold, gold_before - int(cost.get(&"gold", 0)))
	assert_eq(kingdom.amount(&"food", company), food_before - int(cost.get(&"food", 0)))


func test_sans_le_prix_personne_ne_rejoint() -> void:
	var kingdom := Kingdom.create()
	kingdom.levels[&"barracks"] = 1
	var company := _purse(0)
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = 0
	assert_null(kingdom.hire(&"barracks", 0, company, CombatRng.new(29)))
	assert_eq(company.size(), 0)


func test_un_numero_hors_de_l_etal_n_engage_rien() -> void:
	var kingdom := _rich()
	var company := _purse()
	var gold_before := company.gold
	assert_null(kingdom.hire(&"barracks", 9, company, CombatRng.new(31)))
	assert_eq(company.gold, gold_before, "l'étal a facturé un candidat absent")


## UN CANDIDAT NE CONSOMME PAS D'IDENTIFIANT tant qu'on ne l'engage pas :
## sinon deux visites à l'écran du royaume laisseraient des trous, et deux
## héros pourraient finir par en partager un — ce qui en écrase un à la
## sauvegarde.
func test_deux_embauches_de_suite_ont_des_identifiants_distincts() -> void:
	var kingdom := _rich()
	var company := _purse()
	var rng := CombatRng.new(37)
	var first := kingdom.hire(&"barracks", 0, company, rng)
	var second := kingdom.hire(&"archery", 0, company, rng)
	assert_not_null(first)
	assert_not_null(second)
	assert_ne(first.id, second.id)


# --- Sauvegarde ------------------------------------------------------------

func test_le_trait_survit_a_la_sauvegarde() -> void:
	var hero := Hero.create(4, &"mage", "Sylve")
	hero.trait_id = &"studious"
	var copy := Hero.from_dictionary(hero.to_dictionary())
	assert_eq(copy.trait_id, &"studious")


func test_la_fournee_survit_a_la_sauvegarde() -> void:
	var kingdom := _rich()
	kingdom.hire(&"barracks", 0, _purse(), CombatRng.new(41))
	var copy := Kingdom.from_dictionary(kingdom.to_dictionary())
	assert_eq(copy.recruit_round, kingdom.recruit_round)
	assert_gt(copy.recruit_round, 0)


## Un trait retiré des données depuis la sauvegarde disparaît, sans
## emporter la partie avec lui — même règle que la réserve et le sac.
func test_un_trait_inconnu_disparait_a_la_relecture() -> void:
	var hero := Hero.create(4, &"mage", "Sylve")
	var saved := hero.to_dictionary()
	saved["trait"] = "trait_qui_n_existe_plus"
	assert_true(Hero.from_dictionary(saved).trait_id.is_empty())


# --- La brasserie du monastère ---------------------------------------------
#
# LE PREMIER BÂTIMENT QUI PRODUIT AUTRE CHOSE QU'UN CHIFFRE, avec la Tour.
# Le reproche était « les bâtiments ne font que monter des chiffres » ; la
# Tour OUVRE l'ascension, le Monastère alimente le sac.
#
# C'EST UN MAILLON D'OBTENTION, et c'est ce que `verify_world` a appris à
# chercher en Phase 10 : les potions ne tombaient que du butin et de
# l'étal, deux fils que l'expédition alimente. Le royaume en ouvre un
# troisième, et c'est le seul qui récompense d'être RENTRÉ.

func _monastery(level: int) -> Kingdom:
	var kingdom := _rich()
	kingdom.levels[&"monastery"] = level
	return kingdom


func test_un_cycle_remplit_le_sac() -> void:
	var kingdom := _monastery(Buildings.max_level(&"monastery"))
	var company := _purse()
	var potion := kingdom.brewed_potion()
	assert_true(Consumable.exists(potion), "le monastère ne prépare rien de connu")
	var before := int(company.supplies.get(potion, 0))
	var report := kingdom.run_cycle(company)
	assert_eq(
		int(company.supplies.get(potion, 0)) - before, kingdom.brew_per_cycle()
	)
	assert_eq(
		int((report.get("brewed", {}) as Dictionary).get(potion, 0)),
		kingdom.brew_per_cycle(),
		"le compte rendu ne dit pas ce qui a été préparé"
	)


## Un monastère de niveau 1 ne prépare rien : la brasserie s'ouvre au
## niveau 2, donc bâtir plus haut a une conséquence qui n'est pas un
## chiffre de plus.
func test_le_premier_niveau_ne_prepare_rien() -> void:
	var kingdom := _monastery(1)
	assert_eq(kingdom.brew_per_cycle(), 0)
	var company := _purse()
	kingdom.run_cycle(company)
	assert_eq(company.supplies.size(), 0)


func test_sans_monastere_personne_ne_prepare() -> void:
	var kingdom := _rich()
	kingdom.levels[&"monastery"] = 0
	assert_eq(kingdom.brewed_potion(), &"")
	assert_eq(kingdom.brew_per_cycle(), 0)


## LA BRASSERIE NE DOIT PAS ATTEINDRE `Unit.from_stats`, qui l'ignorerait
## SANS RIEN DIRE. La liste des gains qui s'arrêtent au royaume vit dans
## les données depuis qu'elle a compté trois entrées : écrite en dur, elle
## oubliait la suivante.
func test_la_brasserie_n_est_pas_une_statistique_de_combat() -> void:
	var kingdom := _monastery(Buildings.max_level(&"monastery"))
	var bonuses := kingdom.hero_bonuses(&"mage")
	assert_false(bonuses.has(&"brew"), "la brasserie est partie dans les statistiques")
	assert_false(bonuses.has(&"heal_between_steps"))
	assert_false(bonuses.has(&"population_cap"))
	assert_true(Buildings.is_kingdom_grant(&"brew"))
