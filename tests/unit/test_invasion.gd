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


# --- La garnison (T12.8) ---------------------------------------------------
#
# SE PROTÉGER N'ÉTAIT PAS UNE DÉCISION, C'ÉTAIT UNE CONSÉQUENCE. La défense
# valait `building_levels × 7 + population × 4` : une MAISON défendait
# autant qu'une tour de guet, un bûcheron autant qu'une sentinelle. Tout ce
# qu'on bâtissait et tout le monde qu'on avait défendait tout seul, donc le
# joueur n'avait aucun levier.
#
# ET LES BRAS EN TROP NE FAISAIENT RIEN. À population maximale le royaume a
# quatorze habitants pour douze places : deux étaient oisifs pour toujours,
# alors que le carnet affirmait « il y a toujours moins de bras que de
# places ». Ce n'était plus vrai au sommet.

func _max_kingdom() -> Kingdom:
	var kingdom := Kingdom.create()
	for building_id: StringName in Buildings.ids():
		kingdom.levels[building_id] = Buildings.max_level(building_id)
	kingdom.population = kingdom.population_cap()
	return kingdom


## LE CŒUR : retirer un bras d'un chantier doit CHANGER l'issue. Si les
## deux états repoussent l'assaut, monter la garde ne sert à rien ; si
## aucun ne le repousse, elle ne suffit jamais. Dans les deux cas se
## protéger cesse d'être une décision.
func test_monter_la_garde_change_l_issue() -> void:
	var kingdom := _max_kingdom()
	while kingdom.idle_pawns() > 0:
		var placed := false
		for worksite_id: StringName in Worksite.ids():
			if kingdom.assign(worksite_id):
				placed = true
				break
		if not placed:
			break
	var busy := kingdom.defence_strength()
	var assault := kingdom.expected_assault()
	assert_lt(busy, assault, "tous aux chantiers, le royaume tient déjà : aucun arbitrage")

	# Les mêmes bras, à la garde.
	for worksite_id: StringName in Worksite.ids():
		while kingdom.unassign(worksite_id):
			pass
	assert_gt(
		kingdom.defence_strength(), assault,
		"tous à la garde, le royaume ne tient toujours pas : la garde ne sert à rien"
	)


func test_une_sentinelle_vaut_plus_qu_un_ouvrier() -> void:
	var kingdom := _max_kingdom()
	var watching := kingdom.defence_strength()
	kingdom.assign(Worksite.ids()[0])
	assert_lt(
		kingdom.defence_strength(), watching,
		"mettre un bras au travail devrait coûter de la défense"
	)


## UNE MAISON NE DÉFEND PAS COMME UNE TOUR DE GUET, et c'est le second
## levier : bâtir devient un arbitrage entre produire plus et tenir mieux.
func test_le_rempart_vient_des_batiments_qui_le_declarent() -> void:
	# ON MESURE L'ÉCART, PAS LE TOTAL : le château est bâti d'entrée et
	# donne déjà du rempart, donc un royaume « avec des maisons » n'est
	# jamais à zéro. Le premier jet du test l'avait oublié et accusait le
	# code d'un chiffre qui était juste.
	var base := Kingdom.create().ward_strength()
	var housed := Kingdom.create()
	housed.levels[&"houses"] = Buildings.max_level(&"houses")
	var towered := Kingdom.create()
	towered.levels[&"tower"] = Buildings.max_level(&"tower")
	assert_eq(housed.ward_strength(), base, "une maison ne devrait rien défendre")
	assert_gt(towered.ward_strength(), base, "la tour de guet devrait défendre")
	assert_gt(
		towered.defence_strength(), housed.defence_strength(),
		"la tour de guet défend comme une maison : elle n'a plus de rôle"
	)


## Le § 37 veut que rentrer soit MEILLEUR, jamais obligatoire.
func test_rentrer_defendre_ajoute_toujours() -> void:
	var kingdom := _max_kingdom()
	assert_gt(kingdom.defence_strength(20), kingdom.defence_strength(0))
