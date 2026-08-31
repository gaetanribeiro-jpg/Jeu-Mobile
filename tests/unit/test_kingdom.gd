extends GutTest

## T4.1 — le royaume : réserves, habitants, chantiers, cycle.
##
## Deux propriétés portent tout le reste.
##
## LA PREMIÈRE : le cycle est une expédition, pas une minute. Aucun timer,
## aucune énergie — c'est une décision verrouillée. Une sortie courte
## rapporte plus de cycles, une longue plus de butin, et c'est ce qui
## relie les deux moitiés de la boucle du § 3.
##
## LA SECONDE : il y a toujours moins de bras que de places. Sans ça,
## affecter ne serait plus un arbitrage mais un remplissage, et le § 50
## veut qu'un tour contienne un choix.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()
	HeroProgression.reload()
	HeroNames.reload()
	Equipment.reload()
	ResourceTable.reload()
	Worksite.reload()


func _company(gold: int = 0) -> Company:
	var company := Company.new()
	company.gold = gold
	return company


# --- Les quatre ressources du § 6 -----------------------------------------

func test_les_quatre_ressources_sont_declarees() -> void:
	assert_eq(ResourceTable.ids().size(), 4)
	for resource_id: StringName in [&"wood", &"stone", &"gold", &"food"]:
		assert_true(ResourceTable.exists(resource_id), String(resource_id))


func test_l_or_vit_avec_la_compagnie_et_le_reste_au_royaume() -> void:
	# Deux bourses qui doivent rester d'accord finissent par ne plus
	# l'être. Il n'y en a qu'une, et elle voyage avec les héros.
	assert_false(ResourceTable.lives_in_kingdom(&"gold"))
	for resource_id: StringName in [&"wood", &"stone", &"food"]:
		assert_true(ResourceTable.lives_in_kingdom(resource_id), String(resource_id))

	var kingdom := Kingdom.create()
	assert_false(kingdom.stores.has(&"gold"), "l'or a une seconde bourse")
	assert_eq(kingdom.amount(&"gold", _company(340)), 340)


func test_une_ressource_inconnue_se_signale() -> void:
	ResourceTable.entry(&"mithril")
	assert_push_error("ResourceTable : ressource inconnue « mithril »")


# --- Payer et encaisser ----------------------------------------------------

func test_on_ne_paie_pas_a_moitie() -> void:
	# Une dépense partielle laisserait le joueur sans son bâtiment ET sans
	# ses réserves.
	var kingdom := Kingdom.create()
	var company := _company(10)
	var before := kingdom.amount(&"wood")
	assert_false(kingdom.pay({&"wood": 10, &"gold": 999}, company))
	assert_eq(kingdom.amount(&"wood"), before)
	assert_eq(company.gold, 10)


func test_payer_prend_dans_les_deux_bourses() -> void:
	var kingdom := Kingdom.create()
	var company := _company(200)
	var wood := kingdom.amount(&"wood")
	assert_true(kingdom.pay({&"wood": 10, &"gold": 50}, company))
	assert_eq(kingdom.amount(&"wood"), wood - 10)
	assert_eq(company.gold, 150)


func test_une_reserve_ne_descend_jamais_sous_zero() -> void:
	var kingdom := Kingdom.create()
	kingdom.grant({&"wood": -9999}, null)
	assert_eq(kingdom.amount(&"wood"), 0)


# --- Les bras --------------------------------------------------------------

func test_le_royaume_commence_petit() -> void:
	# § 5 : « au départ, quelques habitants, aucune armée ».
	var kingdom := Kingdom.create()
	assert_eq(kingdom.population, Worksite.starting_population())
	assert_eq(kingdom.assigned_total(), 0)
	assert_eq(kingdom.idle_pawns(), kingdom.population)


func test_il_y_a_toujours_plus_de_places_que_de_bras() -> void:
	# C'est ce qui fait de l'affectation un arbitrage.
	var slots := 0
	for worksite_id: StringName in Worksite.ids():
		slots += Worksite.slots_of(worksite_id)
	assert_gt(slots, Kingdom.create().population_cap())


func test_on_n_affecte_pas_plus_de_bras_qu_on_en_a() -> void:
	var kingdom := Kingdom.create()
	for i in kingdom.population:
		assert_true(kingdom.assign(&"lumber_camp"))
	assert_false(kingdom.assign(&"quarry"), "un habitant a été inventé")
	assert_eq(kingdom.idle_pawns(), 0)


func test_un_chantier_n_accepte_que_ses_places() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = 20
	var limit := Worksite.slots_of(&"quarry")
	for i in limit:
		assert_true(kingdom.assign(&"quarry"))
	assert_false(kingdom.assign(&"quarry"))
	assert_eq(kingdom.assigned_to(&"quarry"), limit)


func test_un_chantier_inconnu_ne_prend_personne() -> void:
	var kingdom := Kingdom.create()
	assert_false(kingdom.assign(&"raffinerie"))


func test_les_bras_en_trop_rentrent_au_repos() -> void:
	# Un chantier tenu par des gens qui n'existent plus produirait du bois
	# avec des fantômes.
	var kingdom := Kingdom.create()
	kingdom.population = 6
	for i in 3:
		kingdom.assign(&"lumber_camp")
	kingdom.assign(&"pasture")
	kingdom.population = 2
	kingdom.settle_assignments()
	assert_eq(kingdom.assigned_total(), 2)


# --- Le cycle --------------------------------------------------------------

func test_un_chantier_sans_personne_ne_produit_rien() -> void:
	var kingdom := Kingdom.create()
	var before := kingdom.amount(&"wood")
	var report := kingdom.run_cycle()
	assert_true((report["produced"] as Dictionary).is_empty())
	assert_lt(kingdom.amount(&"wood"), before + 1)


func test_un_bucheron_rapporte_ce_qu_il_annonce() -> void:
	var kingdom := Kingdom.create()
	var before := kingdom.amount(&"wood")
	kingdom.assign(&"lumber_camp")
	kingdom.run_cycle()
	assert_eq(kingdom.amount(&"wood"), before + Worksite.per_cycle(&"lumber_camp"))


func test_deux_bras_sur_le_meme_gisement_rapportent_le_double() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = 4
	var before := kingdom.amount(&"wood")
	kingdom.assign(&"lumber_camp")
	kingdom.assign(&"lumber_camp")
	kingdom.run_cycle()
	assert_eq(kingdom.amount(&"wood"), before + Worksite.per_cycle(&"lumber_camp") * 2)


func test_l_or_du_gisement_va_dans_la_bourse_de_la_compagnie() -> void:
	var kingdom := Kingdom.create()
	var company := _company(0)
	kingdom.assign(&"gold_mine")
	kingdom.run_cycle(company)
	assert_eq(company.gold, Worksite.per_cycle(&"gold_mine"))
	assert_false(kingdom.stores.has(&"gold"))


func test_tout_le_monde_mange_meme_les_oisifs() -> void:
	# Sinon la population serait gratuite et son plafond ne voudrait rien
	# dire.
	var kingdom := Kingdom.create()
	var before := kingdom.amount(&"food")
	var report := kingdom.run_cycle()
	assert_eq(int(report["eaten"]), Worksite.food_per_pawn() * kingdom.population)
	assert_eq(kingdom.amount(&"food"), before - int(report["eaten"]))


func test_personne_ne_meurt_de_faim() -> void:
	# Le § 41 refuse la punition absolue, et affamer un village pendant que
	# le joueur est en expédition en serait une : il n'était pas là.
	var kingdom := Kingdom.create()
	kingdom.stores[&"food"] = 0
	var before := kingdom.population
	var report := kingdom.run_cycle()
	assert_true(bool(report["hungry"]))
	assert_eq(kingdom.population, before, "un habitant est mort")
	assert_eq(kingdom.amount(&"food"), 0)


func test_la_nourriture_accumulee_fait_venir_un_habitant() -> void:
	var kingdom := Kingdom.create()
	kingdom.stores[&"food"] = Worksite.arrival_food() * 4
	var before := kingdom.population
	var report := kingdom.run_cycle()
	assert_true(bool(report["arrived"]))
	assert_eq(kingdom.population, before + 1)


func test_on_n_accueille_pas_au_dela_du_plafond() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = kingdom.population_cap()
	kingdom.stores[&"food"] = 9999
	assert_false(bool(kingdom.run_cycle()["arrived"]))
	assert_eq(kingdom.population, kingdom.population_cap())


func test_un_village_affame_n_accueille_personne() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = 1
	kingdom.stores[&"food"] = Worksite.food_per_pawn() - 1
	var report := kingdom.run_cycle()
	assert_true(bool(report["hungry"]))
	assert_false(bool(report["arrived"]))


func test_on_produit_avant_de_manger() -> void:
	# Sinon le premier cycle affamerait le royaume qu'on vient de fonder.
	var kingdom := Kingdom.create()
	kingdom.stores[&"food"] = 0
	kingdom.population = 1
	kingdom.assign(&"pasture")
	var report := kingdom.run_cycle()
	assert_false(bool(report["hungry"]), "la récolte est arrivée trop tard")
	assert_eq(
		kingdom.amount(&"food"),
		Worksite.per_cycle(&"pasture") - Worksite.food_per_pawn()
	)


# --- La sauvegarde ---------------------------------------------------------

func test_le_royaume_survit_a_un_rechargement() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = 4
	kingdom.assign(&"lumber_camp")
	kingdom.assign(&"pasture")
	kingdom.run_cycle()

	var reloaded := Kingdom.from_dictionary(kingdom.to_dictionary())
	assert_eq(reloaded.population, kingdom.population)
	assert_eq(reloaded.cycles, kingdom.cycles)
	assert_eq(reloaded.assignments, kingdom.assignments)
	assert_eq(reloaded.amount(&"wood"), kingdom.amount(&"wood"))


func test_un_chantier_disparu_des_donnees_ne_fait_pas_tomber_la_partie() -> void:
	var saved := Kingdom.create().to_dictionary()
	saved["assignments"] = {"raffinerie": 3}
	assert_eq(Kingdom.from_dictionary(saved).assigned_total(), 0)
