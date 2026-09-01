extends GutTest

## T5.2 — les invasions du § 37.
##
## CE QU'ELLES APPORTENT À LA BOUCLE, et c'est la seule raison de les
## écrire. Jusqu'ici, partir en expédition ne coûtait rien au royaume : il
## produisait pendant l'absence, sans risque. L'invasion le met EN JEU, et
## donne au § 29 une seconde question — « je rentre pour le butin » devient
## « je rentre pour le butin OU pour défendre ».


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
	Invasion.clear_cache()


func _kingdom(built: bool = false) -> Kingdom:
	var kingdom := Kingdom.create()
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = 1000
	if built:
		var company := Company.new()
		company.gold = 100000
		for i in 3:
			kingdom.build(Buildings.KEYSTONE, company)
		kingdom.build(&"houses", company)
		kingdom.build(&"barracks", company)
	return kingdom


# --- La menace est un compteur, pas une probabilité -----------------------

func test_la_menace_monte_a_chaque_etape() -> void:
	# Un tirage pourrait épargner un joueur toute une partie, et une
	# mécanique qu'on peut ne jamais rencontrer n'en est pas une.
	var kingdom := _kingdom()
	var before := kingdom.threat
	kingdom.raise_threat(CombatRng.new(1), 0)
	assert_gt(kingdom.threat, before)


func test_une_invasion_finit_toujours_par_se_declarer() -> void:
	var kingdom := _kingdom()
	var raid: Invasion = null
	for step in 40:
		raid = kingdom.raise_threat(CombatRng.new(step), step)
		if raid != null:
			break
	assert_not_null(raid, "aucune invasion en quarante étapes")
	assert_eq(kingdom.threat, 0, "le compteur n'est pas retombé")


func test_un_royaume_riche_attire_plus_vite() -> void:
	# Bâtir doit avoir un revers : le § 50 veut qu'une récompense soit
	# tentante, pas gratuite.
	var poor := _kingdom()
	var rich := _kingdom(true)
	poor.raise_threat(CombatRng.new(1), 0)
	rich.raise_threat(CombatRng.new(1), 0)
	assert_gt(rich.threat, poor.threat)


func test_un_assaut_deja_declare_n_en_declare_pas_un_second() -> void:
	var kingdom := _kingdom()
	while kingdom.invasion == null:
		kingdom.raise_threat(CombatRng.new(3), 0)
	assert_null(kingdom.raise_threat(CombatRng.new(4), 0))


func test_l_assaut_laisse_le_temps_de_rentrer() -> void:
	# Sans délai, l'invasion serait une nouvelle et pas un choix.
	var kingdom := _kingdom()
	var raid: Invasion = null
	while raid == null:
		raid = kingdom.raise_threat(CombatRng.new(5), 0)
	assert_gt(raid.steps_left, 0)
	assert_false(raid.is_imminent())
	for i in raid.steps_left:
		kingdom.raise_threat(CombatRng.new(i), 0)
	assert_true(kingdom.invasion.is_imminent())


# --- Rentrer doit être meilleur, jamais obligatoire -----------------------

func test_le_retour_du_joueur_renforce_la_defense() -> void:
	var kingdom := _kingdom(true)
	assert_gt(kingdom.defence_strength(20), kingdom.defence_strength(0))


func test_un_royaume_bati_se_defend_mieux() -> void:
	assert_gt(_kingdom(true).defence_strength(), _kingdom().defence_strength())


func test_l_armee_peut_defendre_seule() -> void:
	# § 37 : « l'armée peut défendre seule ». Un royaume bâti doit pouvoir
	# repousser un assaut sans personne, sinon partir devient interdit.
	var kingdom := _kingdom(true)
	kingdom.population = kingdom.population_cap()
	kingdom.invasion = Invasion.new()
	kingdom.invasion.strength = 1
	assert_true(bool(kingdom.resolve_invasion(Company.new(), 0)["repelled"]))


# --- Ce qu'un assaut coûte et rapporte ------------------------------------

func test_une_defense_reussie_rapporte_du_butin() -> void:
	var kingdom := _kingdom(true)
	var company := Company.new()
	kingdom.invasion = Invasion.new()
	kingdom.invasion.strength = 1
	var report := kingdom.resolve_invasion(company, 100)
	assert_true(bool(report["repelled"]))
	assert_gt(int(report["spoils"]), 0)
	assert_eq(company.gold, int(report["spoils"]))


func test_une_defense_ratee_pille_sans_detruire() -> void:
	# Le § 41 refuse la punition absolue : voir son château redescendre
	# d'un niveau après trois heures de jeu ferait fermer l'application.
	var kingdom := _kingdom(true)
	var company := Company.new()
	company.gold = 400
	var wood := kingdom.amount(&"wood")
	var levels := kingdom.building_levels()
	var people := kingdom.population

	kingdom.invasion = Invasion.new()
	kingdom.invasion.strength = 99999
	var report := kingdom.resolve_invasion(company, 0)

	assert_false(bool(report["repelled"]))
	assert_lt(kingdom.amount(&"wood"), wood, "rien n'a été pillé")
	assert_gt(kingdom.amount(&"wood"), 0, "tout a été pris")
	assert_lt(company.gold, 400)
	assert_eq(kingdom.building_levels(), levels, "un bâtiment a été détruit")
	assert_eq(kingdom.population, people, "un habitant est mort")


func test_resoudre_efface_l_assaut() -> void:
	var kingdom := _kingdom(true)
	kingdom.invasion = Invasion.new()
	kingdom.invasion.strength = 10
	kingdom.resolve_invasion(Company.new(), 0)
	assert_null(kingdom.invasion)
	assert_eq(kingdom.resolve_invasion(Company.new(), 0), {})


func test_un_assaut_plus_profond_frappe_plus_fort() -> void:
	var shallow := 0
	var deep := 0
	for seed_value in 30:
		shallow += Invasion.declare(CombatRng.new(seed_value), 5, 0).strength
		deep += Invasion.declare(CombatRng.new(seed_value), 5, 8).strength
	assert_gt(deep, shallow, "s'enfoncer n'expose pas davantage le royaume")


# --- La sauvegarde ---------------------------------------------------------

func test_l_assaut_survit_a_un_rechargement() -> void:
	var kingdom := _kingdom(true)
	while kingdom.invasion == null:
		kingdom.raise_threat(CombatRng.new(7), 2)
	var reloaded := Kingdom.from_dictionary(kingdom.to_dictionary())
	assert_not_null(reloaded.invasion)
	assert_eq(reloaded.invasion.strength, kingdom.invasion.strength)
	assert_eq(reloaded.invasion.steps_left, kingdom.invasion.steps_left)


func test_un_royaume_sans_assaut_se_recharge_sans_assaut() -> void:
	assert_null(Kingdom.from_dictionary(_kingdom().to_dictionary()).invasion)
