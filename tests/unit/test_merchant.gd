extends GutTest

## T3.4 — le marchand du § 28.
##
## Ce que ces tests protègent, c'est ce qui distingue le marchand d'un
## autre tas de butin : **ce qu'on achète est à l'abri tout de suite**,
## alors que ce qu'on trouve reste en jeu jusqu'au retour. L'or achète
## donc de la sécurité autant qu'un objet, et c'est ce qui en fait une
## décision.
##
## Et une propriété qui a l'air technique mais ne l'est pas : le prix sort
## du barème de l'équipement. Une table de prix séparée aurait dérivé du
## barème dès le deuxième objet ajouté, et personne ne l'aurait vu.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()
	HeroProgression.reload()
	HeroNames.reload()
	Equipment.reload()
	Loot.reload()
	Region.reload()
	ExpeditionRules.reload()
	Merchant.reload()


func _company(gold: int = 0) -> Company:
	var company := Company.new()
	var rng := CombatRng.new(1234)
	for class_id: StringName in [&"warrior", &"archer", &"mage"]:
		company.recruit(class_id, rng)
	company.gold = gold
	return company


## Une expédition arrêtée devant l'étal. La chaîne la plus courte n'a pas
## de marchand du tout — c'est voulu, une sortie sans boutique est une
## sortie différente — donc on cherche une graine qui en pose un.
func _at_merchant(company: Company) -> Expedition:
	var ids: Array[int] = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	for seed_value in 40:
		var run := Expedition.depart(&"greenlands", ids, CombatRng.new(seed_value))
		run.squad_units(company)
		while run.is_ongoing() and run.current_kind() != Expedition.KIND_MERCHANT:
			run.index += 1
		if run.is_ongoing():
			return run
	fail_test("aucune graine ne pose de marchand")
	return null


# --- Le prix vient du barème ----------------------------------------------

func test_le_prix_suit_la_rarete() -> void:
	var previous := 0
	for rarity: StringName in [&"common", &"uncommon", &"rare", &"epic", &"legendary"]:
		for item_id: StringName in Equipment.ids():
			if Equipment.rarity_of(item_id) != rarity:
				continue
			assert_gt(Merchant.price_of(item_id), previous, String(rarity))
			previous = Merchant.price_of(item_id)
			break


func test_deux_objets_de_meme_rarete_valent_pareil() -> void:
	# Le prix sort du budget, pas de l'objet : c'est ce qui le rend juste
	# par construction.
	var by_rarity := {}
	for item_id: StringName in Equipment.ids():
		var rarity := Equipment.rarity_of(item_id)
		if by_rarity.has(rarity):
			assert_eq(Merchant.price_of(item_id), int(by_rarity[rarity]), String(item_id))
		by_rarity[rarity] = Merchant.price_of(item_id)


func test_revendre_rapporte_moins_que_ce_qu_on_a_paye() -> void:
	# Sinon acheter puis revendre serait gratuit, et l'or et les objets
	# deviendraient la même chose.
	for item_id: StringName in Equipment.ids():
		assert_lt(Merchant.resale_of(item_id), Merchant.price_of(item_id), String(item_id))


func test_un_objet_inconnu_ne_vaut_rien() -> void:
	assert_eq(Merchant.price_of(&"epee_du_neant"), 0)


# --- Acheter ---------------------------------------------------------------

func test_acheter_prend_l_or_et_range_dans_la_reserve() -> void:
	var company := _company(1000)
	var item_id := Equipment.ids()[0]
	assert_true(Merchant.buy(item_id, company))
	assert_eq(company.gold, 1000 - Merchant.price_of(item_id))
	assert_true(company.stash.has(item_id))


func test_on_n_achete_pas_a_credit() -> void:
	var company := _company(0)
	var item_id := Equipment.ids()[0]
	assert_false(Merchant.buy(item_id, company))
	assert_eq(company.gold, 0)
	assert_true(company.stash.is_empty())


func test_ce_qu_on_achete_echappe_a_la_deroute() -> void:
	# C'est LA propriété du marchand : l'or achète de la sécurité. Sans
	# elle, l'étal ne serait qu'une source de butin de plus.
	var company := _company(1000)
	var run := _at_merchant(company)
	run.reveal_stock(CombatRng.new(5))
	var bought := run.buy(0, company)
	assert_false(bought.is_empty())

	run.index = 0
	run.resolve_combat({"victory": false, "enemies_downed": 0}, [] as Array[Unit], CombatRng.new(1))
	assert_eq(run.state, Expedition.State.LOST)
	assert_true(company.stash.has(bought), "la déroute a repris ce qui était payé")


func test_ce_qu_on_trouve_reste_en_jeu() -> void:
	# La contrepartie exacte du test précédent.
	var company := _company()
	var run := _at_merchant(company)
	run.satchel_items.append(Equipment.ids()[0])
	run.satchel_gold = 300
	run.index = 0
	run.resolve_combat({"victory": false, "enemies_downed": 0}, [] as Array[Unit], CombatRng.new(1))
	assert_lt(run.satchel_gold, 300)
	assert_true(company.stash.is_empty())


# --- L'étal ----------------------------------------------------------------

func test_l_etal_propose_de_quoi_choisir() -> void:
	var run := _at_merchant(_company())
	assert_eq(run.reveal_stock(CombatRng.new(5)).size(), Merchant.stock_size())
	assert_gt(Merchant.stock_size(), 1)


func test_l_etal_ne_change_plus_une_fois_vu() -> void:
	# Un stock qui se retire à chaque rechargement permettrait de le
	# relancer jusqu'à voir un légendaire.
	var company := _company()
	var run := _at_merchant(company)
	var first := run.reveal_stock(CombatRng.new(5))
	assert_eq(run.reveal_stock(CombatRng.new(99999)), first)

	var reloaded := Expedition.from_dictionary(run.to_dictionary())
	assert_eq(reloaded.reveal_stock(CombatRng.new(12345)), first)


func test_on_n_achete_pas_deux_fois_le_meme_etalage() -> void:
	var company := _company(5000)
	var run := _at_merchant(company)
	run.reveal_stock(CombatRng.new(5))
	assert_false(run.buy(0, company).is_empty())
	assert_true(run.buy(0, company).is_empty(), "l'étalage s'est réapprovisionné")
	assert_eq(run.sold_slots(), [0] as Array[int])


func test_un_etalage_inexistant_ne_vend_rien() -> void:
	var company := _company(5000)
	var run := _at_merchant(company)
	run.reveal_stock(CombatRng.new(5))
	assert_true(run.buy(-1, company).is_empty())
	assert_true(run.buy(99, company).is_empty())


func test_on_n_achete_pas_a_un_etal_qu_on_n_a_pas_regarde() -> void:
	# Lire un étal ne le remplit pas, et acheter non plus : c'est l'arrivée
	# sur l'étape qui tire le stock, une fois, avec son générateur.
	var company := _company(5000)
	var run := _at_merchant(company)
	assert_true(run.stock().is_empty())
	assert_true(run.buy(0, company).is_empty())
	assert_eq(company.gold, 5000)
	assert_eq(run.reveal_stock(CombatRng.new(5)).size(), Merchant.stock_size())


func test_une_etape_qui_n_est_pas_un_marchand_n_a_pas_d_etal() -> void:
	var company := _company()
	var ids: Array[int] = []
	for hero: Hero in company.heroes:
		ids.append(hero.id)
	var run := Expedition.depart(&"greenlands", ids, CombatRng.new(3))
	assert_true(run.current_is_combat())
	assert_true(run.reveal_stock(CombatRng.new(5)).is_empty())


func test_l_etal_paie_mieux_au_fond_de_l_expedition() -> void:
	# Le § 29 encore : s'enfoncer doit tenter.
	var shallow := 0.0
	var deep := 0.0
	for seed_value in 40:
		for item_id: StringName in Merchant.draw_stock(CombatRng.new(seed_value), 0):
			shallow += float(Merchant.price_of(item_id))
		for item_id: StringName in Merchant.draw_stock(CombatRng.new(seed_value), 9):
			deep += float(Merchant.price_of(item_id))
	assert_gt(deep, shallow, "l'étal du fond ne vaut pas mieux")


# --- Vendre ----------------------------------------------------------------

func test_vendre_vide_la_reserve_et_remplit_la_bourse() -> void:
	var company := _company()
	var item_id := Equipment.ids()[0]
	company.stash.append(item_id)
	assert_eq(Merchant.sell(item_id, company), Merchant.resale_of(item_id))
	assert_false(company.stash.has(item_id))
	assert_eq(company.gold, Merchant.resale_of(item_id))


func test_on_ne_vend_pas_ce_qu_un_heros_porte() -> void:
	# Un objet porté n'est pas dans la réserve : il ne peut pas partir par
	# mégarde pendant qu'on fait le ménage.
	var company := _company()
	var item_id := Equipment.of_slot(Equipment.slots()[0], &"warrior")[0]
	company.stash.append(item_id)
	company.equip_from_stash(company.heroes[0].id, item_id)
	assert_eq(Merchant.sell(item_id, company), 0)
	assert_eq(company.gold, 0)
