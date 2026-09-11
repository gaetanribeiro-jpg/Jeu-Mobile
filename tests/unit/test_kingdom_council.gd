extends GutTest

## LE CONSEIL DU ROYAUME ET LES VILLES VOISINES (T12.10).
##
## Ce qui se joue ici est la TROISIÈME décision de la ville. Bâtir quoi et
## qui travaille où se posent une fois et se revoient rarement ; le conseil
## se repose à chaque retour, et il se paie dans la monnaie de la ville.
##
## Le reste est la mécanique du crédit : il monte, il descend, il OUVRE des
## offres, et il survit à la sauvegarde. Un crédit qu'il faudrait
## reconstruire à chaque lancement ne serait pas une mémoire.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	ResourceTable.clear_cache()
	Worksite.clear_cache()
	Buildings.clear_cache()
	HeroNames.clear_cache()
	Invasion.clear_cache()
	Neighbour.clear_cache()
	KingdomEvent.clear_cache()


func _stocked() -> Kingdom:
	var kingdom := Kingdom.create()
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = 5000
	return kingdom


func _rich() -> Company:
	var company := Company.new()
	company.gold = 5000
	return company


# --- Les voisines ----------------------------------------------------------

func test_le_credit_part_de_zero_et_se_borne() -> void:
	var kingdom := Kingdom.create()
	var town: StringName = Neighbour.ids()[0]
	assert_eq(kingdom.standing_of(town), 0, "on ne commence ami de personne")
	kingdom.shift_standing(town, 99)
	assert_eq(kingdom.standing_of(town), Neighbour.maximum())
	kingdom.shift_standing(town, -99)
	assert_eq(kingdom.standing_of(town), Neighbour.minimum())


func test_chaque_cran_de_credit_a_un_nom() -> void:
	for value in range(Neighbour.minimum(), Neighbour.maximum() + 1):
		assert_false(Neighbour.standing_key(value).is_empty(),
			"le crédit %d ne tombe dans aucun palier" % value)


func test_une_ville_inconnue_ne_gagne_pas_de_credit() -> void:
	var kingdom := Kingdom.create()
	assert_eq(kingdom.shift_standing(&"nulle_part", 2), 0)
	assert_false(kingdom.standings.has(&"nulle_part"))


# --- Le tirage -------------------------------------------------------------

func test_le_cycle_pose_un_conseil() -> void:
	var kingdom := _stocked()
	assert_true(kingdom.council().is_empty())
	kingdom.run_cycle(_rich(), CombatRng.new(7))
	assert_false(kingdom.council().is_empty(), "aucun conseil n'attend au retour")


func test_un_cycle_sans_generateur_ne_propose_rien() -> void:
	var kingdom := _stocked()
	kingdom.run_cycle(_rich())
	assert_true(kingdom.council().is_empty())


## LE TIRAGE NE CONSOMME RIEN DE LA PARTIE. Il est dérivé du numéro de
## cycle — même règle que les candidats du recrutement et que les rochers
## du rivage : le décor et la diplomatie ne décalent pas le hasard des
## combats à venir.
func test_le_conseil_ne_decale_pas_le_hasard_de_la_partie() -> void:
	var witness := CombatRng.new(11)
	var expected := witness.int_between(1, 1000, &"témoin")

	var kingdom := _stocked()
	var rng := CombatRng.new(11)
	kingdom.run_cycle(_rich(), rng)
	assert_eq(rng.int_between(1, 1000, &"témoin"), expected,
		"le conseil a mangé un tirage de la partie")


func test_deux_royaumes_de_meme_graine_tirent_le_meme_conseil() -> void:
	var first := _stocked()
	var second := _stocked()
	first.run_cycle(_rich(), CombatRng.new(3))
	second.run_cycle(_rich(), CombatRng.new(3))
	assert_eq(first.council(), second.council())


## Un conseil posé n'est pas remplacé : il a été tiré pour une décision que
## le joueur n'a pas prise, et l'écraser la lui volerait.
func test_un_conseil_en_attente_survit_au_cycle_suivant() -> void:
	var kingdom := _stocked()
	kingdom.run_cycle(_rich(), CombatRng.new(5))
	var waiting := kingdom.council()
	kingdom.run_cycle(_rich(), CombatRng.new(9))
	assert_eq(kingdom.council(), waiting)


func test_le_champion_reste_ferme_sans_credit() -> void:
	var gated := &""
	for event_id: StringName in KingdomEvent.ids():
		if not KingdomEvent.required_standing(event_id).is_empty():
			gated = event_id
			break
	assert_false(gated.is_empty(), "aucun conseil n'est ouvert par le crédit")
	assert_false(KingdomEvent.is_open(gated, {}), "il sort sans qu'on ait rien fait")
	var required := KingdomEvent.required_standing(gated)
	var earned := {StringName(required.get("town", "")): int(required.get("minimum", 0))}
	assert_true(KingdomEvent.is_open(gated, earned), "le crédit ne l'ouvre pas")


func test_le_tirage_ecarte_les_conseils_recents() -> void:
	var seen := KingdomEvent.ids()[0]
	for i in 40:
		assert_ne(KingdomEvent.draw(CombatRng.new(i), [String(seen)]), seen)


# --- Trancher --------------------------------------------------------------

func _pose(kingdom: Kingdom, event_id: StringName) -> void:
	kingdom.pending_council = event_id


func test_trancher_efface_le_conseil_et_le_retient() -> void:
	var kingdom := _stocked()
	_pose(kingdom, &"dispute")
	assert_false(kingdom.resolve_council(0, _rich(), CombatRng.new(1)).is_empty())
	assert_true(kingdom.council().is_empty())
	assert_true(kingdom.recent_councils.has("dispute"))


func test_une_option_inconnue_ne_touche_a_rien() -> void:
	var kingdom := _stocked()
	_pose(kingdom, &"dispute")
	assert_true(kingdom.resolve_council(9, _rich(), CombatRng.new(1)).is_empty())
	assert_eq(kingdom.council(), &"dispute", "le conseil a été perdu")


## Une option qu'on ne peut pas payer reste PROPOSÉE, grisée : savoir ce
## qu'on ne peut pas s'offrir fait partie de la décision.
func test_une_option_trop_chere_est_refusee_sans_emporter_le_conseil() -> void:
	var kingdom := Kingdom.create()
	kingdom.stores[&"food"] = 0
	_pose(kingdom, &"dispute")
	assert_false(kingdom.can_choose(0, _rich()))
	assert_true(kingdom.resolve_council(0, _rich(), CombatRng.new(1)).is_empty())
	assert_eq(kingdom.council(), &"dispute")


func test_une_option_deplace_les_reserves() -> void:
	var kingdom := _stocked()
	var before := kingdom.amount(&"stone")
	_pose(kingdom, &"good_seam")
	var report := kingdom.resolve_council(0, _rich(), CombatRng.new(1))
	assert_gt(kingdom.amount(&"stone"), before)
	assert_true((report.get("moved", {}) as Dictionary).has(&"stone"))


func test_une_option_fait_bouger_le_credit() -> void:
	var kingdom := _stocked()
	_pose(kingdom, &"caravan")
	kingdom.resolve_council(0, _rich(), CombatRng.new(1))
	assert_eq(kingdom.standing_of(&"valmont"), 1)
	_pose(kingdom, &"caravan")
	kingdom.resolve_council(1, _rich(), CombatRng.new(1))
	assert_eq(kingdom.standing_of(&"valmont"), 0)


## QUI PART EST LE MOINS EXPÉRIMENTÉ : le geste rapide ne doit pas détruire
## ce que le joueur a patiemment formé. C'est la règle du rappel de T12.8,
## poussée d'un cran.
func test_le_partant_est_le_moins_experimente() -> void:
	var kingdom := _stocked()
	kingdom.population = 3
	var trade: StringName = Worksite.ids()[0]
	kingdom.pawns[0].learn(trade, 100)
	var veteran := kingdom.pawns[0].id
	_pose(kingdom, &"dispute")
	var report := kingdom.resolve_council(1, _rich(), CombatRng.new(1))
	assert_eq(kingdom.population, 2)
	assert_not_null(kingdom.pawn_by_id(veteran), "le spécialiste est parti")
	assert_eq((report.get("left", []) as Array).size(), 1)


## UN ARRIVANT N'ENTRE PAS SI LE ROYAUME NE PEUT PAS LE NOURRIR : le
## plafond de population est une promesse faite ailleurs dans l'écran.
func test_un_conseil_ne_depasse_pas_le_plafond() -> void:
	var kingdom := _stocked()
	kingdom.population = kingdom.population_cap()
	_pose(kingdom, &"newcomers")
	var report := kingdom.resolve_council(0, _rich(), CombatRng.new(1))
	assert_eq(kingdom.population, kingdom.population_cap())
	assert_eq(int(report.get("arrived", 0)), 0)


func test_un_conseil_forme_ceux_qui_sont_au_chantier() -> void:
	var kingdom := _stocked()
	kingdom.population = 4
	kingdom.assign(&"pasture")
	var worker := kingdom.workers_at(&"pasture")[0]
	var before := worker.experience_at(&"pasture")
	_pose(kingdom, &"dispute")
	kingdom.resolve_council(2, _rich(), CombatRng.new(1))
	assert_gt(worker.experience_at(&"pasture"), before)


func test_un_pari_rend_ses_deux_issues() -> void:
	var wins := 0
	for seed_value in 60:
		var kingdom := _stocked()
		_pose(kingdom, &"deserter")
		var report := kingdom.resolve_council(2, _rich(), CombatRng.new(seed_value))
		assert_true(bool(report.get("gambled", false)))
		if bool(report.get("succeeded", false)):
			wins += 1
	assert_gt(wins, 0, "le pari ne réussit jamais")
	assert_lt(wins, 60, "le pari ne rate jamais")


## LA POTION VA DANS LE SAC, PAS DANS LA RÉSERVE — règle de T10.2 : elle
## est buvable à la sortie suivante.
func test_les_fioles_vont_au_sac() -> void:
	var kingdom := _stocked()
	var company := _rich()
	_pose(kingdom, &"champion")
	var report := kingdom.resolve_council(1, company, CombatRng.new(1))
	var flasks: Dictionary = report.get("flasks", {})
	assert_false(flasks.is_empty(), "aucune fiole rendue")
	for potion: StringName in flasks.keys():
		assert_eq(int(company.supplies.get(potion, 0)), int(flasks[potion]))


## IL ARRIVE DÉJÀ AGUERRI, et c'est ce que le crédit achète : la caserne ne
## sait former que des recrues de niveau 1.
func test_le_champion_rejoint_la_compagnie_aguerri() -> void:
	var kingdom := _stocked()
	var company := _rich()
	var before := company.heroes.size()
	_pose(kingdom, &"champion")
	var report := kingdom.resolve_council(0, company, CombatRng.new(4))
	var champion: Variant = report.get("champion", null)
	assert_true(champion is Hero, "aucun champion n'est venu")
	assert_eq(company.heroes.size(), before + 1)
	assert_gt((champion as Hero).level, 1, "un champion de niveau 1 n'est pas un champion")


# --- La sauvegarde ---------------------------------------------------------

## LE CONSEIL SURVIT À LA SAUVEGARDE. Sur mobile l'application peut être
## tuée entre le retour au royaume et la décision, et un conseil perdu dans
## ce trou serait une décision volée au joueur.
func test_le_conseil_et_le_credit_traversent_la_sauvegarde() -> void:
	var kingdom := _stocked()
	kingdom.shift_standing(&"valmont", 2)
	kingdom.shift_standing(&"fort_aubin", -1)
	_pose(kingdom, &"masons")
	kingdom.recent_councils = ["storm"]

	var relu := Kingdom.from_dictionary(kingdom.to_dictionary())
	assert_eq(relu.council(), &"masons")
	assert_eq(relu.standing_of(&"valmont"), 2)
	assert_eq(relu.standing_of(&"fort_aubin"), -1)
	assert_eq(relu.recent_councils, ["storm"])


func test_un_conseil_disparu_des_donnees_n_emporte_pas_la_partie() -> void:
	var saved := _stocked().to_dictionary()
	saved["council"] = "un_conseil_effacé"
	saved["recent_councils"] = ["un_autre"]
	var relu := Kingdom.from_dictionary(saved)
	assert_true(relu.council().is_empty())
	assert_true(relu.recent_councils.is_empty())
