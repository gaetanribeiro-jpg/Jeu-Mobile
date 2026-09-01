extends GutTest

## T4.2 — les bâtiments du royaume.
##
## Une seule question gouverne la table : « qu'est-ce que ça permet à mes
## héros ? » Aucun bâtiment décoratif, c'est une décision verrouillée, et
## c'est la première chose que ces tests protègent.
##
## La seconde est le sens de la dépendance. Le royaume rend un bloc de
## modificateurs, `Hero.effective_stats` l'ajoute comme il ajoute
## l'équipement, et ni `Hero` ni `Unit` ne savent qu'un royaume existe.
## C'est ce qui permet encore de simuler mille combats en headless.


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


func _company(gold: int = 0) -> Company:
	var company := Company.new()
	company.gold = gold
	return company


## Un royaume riche : on veut tester les règles, pas la patience.
func _rich() -> Kingdom:
	var kingdom := Kingdom.create()
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = 100000
	return kingdom


# --- Aucun bâtiment décoratif ---------------------------------------------

func test_chaque_batiment_accorde_quelque_chose_a_chaque_niveau() -> void:
	for building_id: StringName in Buildings.ids():
		for level in range(1, Buildings.max_level(building_id) + 1):
			assert_false(
				Buildings.grants_at(building_id, level).is_empty(),
				"%s niveau %d" % [building_id, level]
			)


func test_la_tour_n_est_pas_batissable_au_mvp() -> void:
	# Le pack la dessine, mais elle sert à la défense et les invasions sont
	# la Phase 5. Une tour sans invasion ne répond à rien.
	assert_false(Buildings.exists(&"tower"))


func test_chaque_classe_du_mvp_a_son_batiment() -> void:
	var served := {}
	for building_id: StringName in Buildings.ids():
		var class_id := Buildings.hero_class(building_id)
		if not class_id.is_empty():
			served[class_id] = true
	for class_id: StringName in Unit.hero_class_ids():
		assert_true(served.has(class_id), String(class_id))


func test_un_batiment_inconnu_se_signale() -> void:
	Buildings.entry(&"donjon")
	assert_push_error("Buildings : bâtiment inconnu « donjon »")


# --- Les coûts -------------------------------------------------------------

func test_un_niveau_coute_plus_cher_que_le_precedent() -> void:
	for building_id: StringName in Buildings.ids():
		var previous := 0
		for level in range(Buildings.starts_at(building_id) + 1, Buildings.max_level(building_id) + 1):
			var total := 0
			for key: Variant in Buildings.cost_of(building_id, level).keys():
				total += int(Buildings.cost_of(building_id, level)[key])
			assert_gt(total, previous, "%s niveau %d" % [building_id, level])
			previous = total


func test_le_chateau_est_deja_la_au_premier_jour() -> void:
	# § 5 : « un bâtiment principal rudimentaire ». Sans lui, rien ne peut
	# monter, et le joueur ouvre un écran vide.
	assert_eq(Buildings.starts_at(Buildings.KEYSTONE), 1)
	assert_true(Buildings.cost_of(Buildings.KEYSTONE, 1).is_empty())
	assert_eq(Kingdom.create().level_of(Buildings.KEYSTONE), 1)


func test_un_niveau_hors_de_portee_ne_coute_rien() -> void:
	var top := Buildings.max_level(&"barracks")
	assert_true(Buildings.cost_of(&"barracks", top + 1).is_empty())


# --- Bâtir -----------------------------------------------------------------

func test_batir_prend_les_ressources_et_monte_d_un_niveau() -> void:
	var kingdom := _rich()
	var company := _company(100000)
	var wood := kingdom.amount(&"wood")
	assert_eq(kingdom.build(&"houses", company), 1)
	assert_eq(kingdom.level_of(&"houses"), 1)
	assert_lt(kingdom.amount(&"wood"), wood)


func test_on_ne_batit_pas_sans_les_moyens() -> void:
	var kingdom := Kingdom.create()
	kingdom.stores[&"wood"] = 0
	var company := _company(0)
	assert_eq(kingdom.blocked_because(&"houses", company), &"cost")
	assert_eq(kingdom.build(&"houses", company), 0)
	assert_eq(kingdom.level_of(&"houses"), 0)


func test_le_chateau_plafonne_tout_le_reste() -> void:
	# Sans cette règle, on monterait une caserne au niveau 5 dans un
	# hameau, et la progression du royaume n'aurait plus de colonne.
	var kingdom := _rich()
	var company := _company(100000)
	assert_eq(kingdom.level_of(Buildings.KEYSTONE), 1)
	assert_eq(kingdom.build(&"barracks", company), 1)
	assert_eq(kingdom.blocked_because(&"barracks", company), &"castle")
	assert_eq(kingdom.build(&"barracks", company), 0)

	kingdom.build(Buildings.KEYSTONE, company)
	assert_eq(kingdom.build(&"barracks", company), 2)


func test_le_chateau_ne_se_plafonne_que_lui_meme() -> void:
	# Sinon rien ne pourrait jamais monter.
	var kingdom := _rich()
	var company := _company(1000000)
	for level in range(2, Buildings.max_level(Buildings.KEYSTONE) + 1):
		assert_eq(kingdom.build(Buildings.KEYSTONE, company), level)


func test_on_ne_depasse_pas_le_niveau_maximum() -> void:
	var kingdom := _rich()
	var company := _company(1000000)
	for i in 20:
		kingdom.build(Buildings.KEYSTONE, company)
	assert_eq(kingdom.level_of(Buildings.KEYSTONE), Buildings.max_level(Buildings.KEYSTONE))
	assert_eq(kingdom.blocked_because(Buildings.KEYSTONE), &"maxed")


# --- Ce que le royaume donne aux héros ------------------------------------

func test_une_caserne_ne_renforce_que_les_guerriers() -> void:
	# Sinon bâtir ne serait plus un choix entre trois voies mais un cumul.
	var kingdom := _rich()
	var company := _company(100000)
	kingdom.build(&"barracks", company)
	assert_false(kingdom.hero_bonuses(&"warrior").is_empty())
	assert_true(kingdom.hero_bonuses(&"archer").is_empty())


func test_un_batiment_non_bati_n_accorde_rien() -> void:
	var kingdom := Kingdom.create()
	assert_true(kingdom.hero_bonuses(&"warrior").is_empty())
	assert_eq(kingdom.healing_between_steps(), 0.0)


func test_le_royaume_rend_des_pv_au_guerrier_sans_que_le_heros_le_sache() -> void:
	# Le sens de la dépendance : le royaume rend un bloc, le héros
	# l'applique comme il applique un anneau.
	var kingdom := _rich()
	var company := _company(100000)
	var hero := company.recruit(&"warrior", CombatRng.new(5))
	var before: int = hero.effective_stats()["hit_points"]

	kingdom.build(&"barracks", company)
	var bonuses := kingdom.hero_bonuses(&"warrior")
	assert_gt(int(bonuses["hit_points"]), 0)
	assert_eq(
		int(hero.effective_stats(bonuses)["hit_points"]),
		before + int(bonuses["hit_points"])
	)


func test_les_gains_s_additionnent_avec_les_niveaux() -> void:
	var one := Buildings.grants_up_to(&"barracks", 1)
	var three := Buildings.grants_up_to(&"barracks", 3)
	assert_gt(int(three.get("hit_points", 0)), int(one.get("hit_points", 0)))


func test_seul_le_monastere_touche_a_l_expedition() -> void:
	# C'est le seul bâtiment qui déplace la courbe d'usure de T1.11, et
	# c'est le levier si les 13 % par rencontre se révèlent trop durs.
	var kingdom := _rich()
	var company := _company(1000000)
	kingdom.build(&"monastery", company)
	assert_gt(kingdom.healing_between_steps(), 0.0)

	var other := _rich()
	other.build(&"barracks", _company(100000))
	assert_eq(other.healing_between_steps(), 0.0)


func test_le_soin_ne_part_jamais_dans_les_statistiques_de_combat() -> void:
	# Un gain qu'on croit acquis sans qu'il le soit est pire qu'un gain
	# absent : `Unit.from_stats` l'ignorerait en silence.
	var kingdom := _rich()
	kingdom.build(&"monastery", _company(1000000))
	assert_false(kingdom.hero_bonuses(&"mage").has(&"heal_between_steps"))
	assert_false(kingdom.hero_bonuses(&"mage").has(&"population_cap"))


func test_les_maisons_montent_le_plafond_de_population() -> void:
	var kingdom := _rich()
	var before := kingdom.population_cap()
	kingdom.build(&"houses", _company(100000))
	assert_gt(kingdom.population_cap(), before)


func test_on_ne_recrute_que_ce_que_le_royaume_sait_former() -> void:
	# Sans caserne, pas de Guerrier : le premier héros de chaque classe
	# vient d'un bâtiment.
	var kingdom := Kingdom.create()
	assert_true(kingdom.recruitable_classes().is_empty())
	kingdom.stores[&"wood"] = 100000
	kingdom.stores[&"stone"] = 100000
	kingdom.build(&"archery", _company(100000))
	assert_eq(kingdom.recruitable_classes(), [&"archer"] as Array[StringName])


# --- La sauvegarde ---------------------------------------------------------

func test_les_niveaux_survivent_a_un_rechargement() -> void:
	var kingdom := _rich()
	var company := _company(1000000)
	kingdom.build(&"houses", company)
	kingdom.build(&"barracks", company)

	var reloaded := Kingdom.from_dictionary(kingdom.to_dictionary())
	assert_eq(reloaded.level_of(&"houses"), 1)
	assert_eq(reloaded.level_of(&"barracks"), 1)
	assert_eq(reloaded.population_cap(), kingdom.population_cap())


func test_un_batiment_disparu_des_donnees_ne_fait_pas_tomber_la_partie() -> void:
	var saved := Kingdom.create().to_dictionary()
	saved["levels"] = {"donjon": 4}
	assert_eq(Kingdom.from_dictionary(saved).level_of(&"donjon"), 0)
