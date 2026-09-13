extends GutTest

## LE RENFORT ET LE PRÊT (T12.12) — les deux façons dont une voisine rend
## des bras.
##
## LE RENFORT (option D) ne sert qu'UNE fois et c'est le joueur qui dit
## quand : acheté au départ, dépensé sur une rencontre. Le PRÊT (option B)
## est l'inverse — c'est un des siens qui part, et le coût est un CORPS
## dans un jeu où l'équipe est de quatre.


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
	Neighbour.clear_cache()
	KingdomEvent.clear_cache()


func _town() -> StringName:
	for town_id: StringName in Neighbour.ids():
		if Neighbour.musters(town_id):
			return town_id
	return &""


func _company(count: int) -> Company:
	var company := Company.new()
	company.gold = 5000
	for i in count:
		var hero := Hero.recruit(company.next_id(), &"warrior", CombatRng.new(i))
		company.take(hero)
	return company


func _stocked() -> Kingdom:
	var kingdom := Kingdom.create()
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = 5000
	return kingdom


# --- Le renfort d'un combat ------------------------------------------------

func test_chaque_ville_qui_envoie_declare_une_unite_jouable() -> void:
	for town_id: StringName in Neighbour.ids():
		if not Neighbour.musters(town_id):
			continue
		var unit := Neighbour.muster_unit(town_id)
		assert_true(
			Unit.hero_class_ids().has(StringName(unit.get("type", ""))),
			"« %s » envoie une classe inconnue" % town_id
		)
		assert_false(Neighbour.muster_cost(town_id).is_empty(),
			"« %s » envoie un bras gratuitement" % town_id)


## IL ARRIVE AVEC L'ÉQUIPE, pas au milieu du plateau : un renfort lâché
## seul devant les lignes ennemies mourrait au premier tour.
func test_le_milicien_se_pose_sur_une_case_de_placement() -> void:
	var map := CombatMap.load_map(&"vallee_01")
	assert_not_null(map)
	var before := map.board.active_units(Unit.Side.HEROES).size()
	var militia := Muster.join(map, _town())
	assert_not_null(militia, "aucun milicien n'est venu")
	assert_eq(map.board.active_units(Unit.Side.HEROES).size(), before + 1)
	assert_true(
		map.deployment_cells.has(militia.cell),
		"le milicien est posé hors de la zone de placement"
	)


## LE DESSIN SE DÉCLARE À PART DES STATISTIQUES : un milicien a les
## chiffres d'un Guerrier et le dessin d'un Pawn.
func test_le_milicien_porte_son_propre_dessin_et_son_nom() -> void:
	var map := CombatMap.load_map(&"vallee_01")
	var militia := Muster.join(map, _town())
	assert_eq(militia.sprite_id, &"pawn")
	assert_false(militia.sprite_variant.is_empty())
	assert_ne(militia.name_key, "", "le milicien s'annoncerait comme un Guerrier")


func test_une_ville_qui_n_envoie_rien_ne_pose_personne() -> void:
	var map := CombatMap.load_map(&"vallee_01")
	assert_null(Muster.join(map, &"nulle_part"))


func test_le_jeton_ne_sert_qu_une_fois() -> void:
	var run := Expedition.depart(&"greenlands", [1], CombatRng.new(3))
	run.ally_town = _town()
	assert_true(run.has_ally())
	assert_eq(run.spend_ally(), _town())
	assert_false(run.has_ally(), "le jeton se dépense deux fois")
	assert_true(run.ally_joins_now(), "le milicien ne se bat pas sur l'étape payée")
	assert_eq(run.spend_ally(), &"")


func test_le_jeton_traverse_la_sauvegarde() -> void:
	var run := Expedition.depart(&"greenlands", [1], CombatRng.new(4))
	run.ally_town = _town()
	run.spend_ally()
	var relu := Expedition.from_dictionary(run.to_dictionary())
	assert_eq(relu.ally_town, run.ally_town)
	assert_true(relu.ally_joins_now())


# --- Le prêt d'un héros ----------------------------------------------------

func test_preter_retire_le_heros_de_l_equipe() -> void:
	var company := _company(5)
	var kingdom := _stocked()
	var hero := company.heroes[0]
	assert_true(company.squad_ids.has(hero.id), "il n'était pas dans l'équipe")
	assert_true(kingdom.lend(hero, &"valmont", company))
	assert_false(hero.is_available())
	assert_false(company.squad_ids.has(hero.id), "un fantôme part en expédition")
	assert_eq(company.available().size(), 4)
	assert_eq(company.lent().size(), 1)


## ON GARDE TOUJOURS DE QUOI PARTIR : sans plancher, on pourrait prêter
## toute la compagnie et se bloquer.
func test_on_ne_prete_pas_sous_le_plancher() -> void:
	var company := _company(Neighbour.loan_minimum_left())
	var kingdom := _stocked()
	assert_eq(
		kingdom.cannot_lend_because(company.heroes[0], &"valmont", company), &"too_few"
	)
	assert_false(kingdom.lend(company.heroes[0], &"valmont", company))


func test_on_ne_prete_pas_a_une_ville_brouillee() -> void:
	var company := _company(5)
	var kingdom := _stocked()
	kingdom.shift_standing(&"valmont", Neighbour.minimum())
	assert_eq(
		kingdom.cannot_lend_because(company.heroes[0], &"valmont", company), &"standing"
	)


func test_on_ne_prete_pas_deux_fois_le_meme() -> void:
	var company := _company(6)
	var kingdom := _stocked()
	var hero := company.heroes[0]
	kingdom.lend(hero, &"valmont", company)
	assert_eq(kingdom.cannot_lend_because(hero, &"roche_claire", company), &"already_away")


## IL REVIENT PLUS FORT QU'IL N'EST PARTI, sinon prêter serait une punition
## qu'on n'accepterait que par obligation.
func test_il_rentre_paye_et_aguerri() -> void:
	var company := _company(5)
	var kingdom := _stocked()
	var hero := company.heroes[0]
	var experience := hero.experience
	kingdom.lend(hero, &"valmont", company)
	var purse := company.gold

	var report := {}
	for i in Neighbour.loan_cycles():
		report = kingdom.run_cycle(company)
		if i < Neighbour.loan_cycles() - 1:
			assert_false(hero.is_available(), "il est rentré trop tôt")

	assert_true(hero.is_available(), "il n'est jamais rentré")
	assert_gt(company.gold, purse, "il rentre les mains vides")
	assert_gt(hero.experience, experience, "il n'a rien appris")
	assert_eq(kingdom.standing_of(&"valmont"), Neighbour.loan_standing())
	assert_eq((report.get("returned", []) as Array).size(), 1)


## IL NE REPREND PAS SA PLACE TOUT SEUL, et c'est la règle de T12.7 : « un
## recruté de trop n'entre pas tout seul ». Une composition qui se refait
## dans le dos du joueur n'est plus la sienne — celui qui rentre est
## disponible, c'est au joueur de le remettre dans l'équipe.
func test_celui_qui_rentre_ne_bouscule_personne() -> void:
	var company := _company(5)
	var kingdom := _stocked()
	var hero := company.heroes[0]
	kingdom.lend(hero, &"valmont", company)
	var squad := company.squad_ids.duplicate()
	for i in Neighbour.loan_cycles():
		kingdom.run_cycle(company)
	assert_true(hero.is_available())
	assert_eq(company.squad_ids, squad, "la composition a été refaite sans le joueur")


## Mais s'il reste de la place, il la prend : une équipe incomplète après
## un prêt serait une punition qui dure après le retour.
func test_il_reprend_sa_place_si_elle_est_libre() -> void:
	var company := _company(4)
	var kingdom := _stocked()
	company.take(Hero.recruit(company.next_id(), &"archer", CombatRng.new(9)))
	var hero := company.heroes[0]
	kingdom.lend(hero, &"valmont", company)
	for i in Neighbour.loan_cycles():
		kingdom.run_cycle(company)
	company.remove(company.heroes[1].id)
	company.settle_squad()
	assert_true(company.squad_ids.has(hero.id), "il ne reprend jamais sa place")


func test_le_pret_traverse_la_sauvegarde() -> void:
	var company := _company(5)
	var kingdom := _stocked()
	kingdom.lend(company.heroes[0], &"valmont", company)

	var relu := Company.from_dictionary(company.to_dictionary())
	var hero := relu.hero_by_id(company.heroes[0].id)
	assert_false(hero.is_available(), "le prêt a disparu au rechargement")
	assert_eq(hero.away_town, &"valmont")
	assert_eq(hero.away_cycles, Neighbour.loan_cycles())
	assert_false(relu.squad_ids.has(hero.id))
