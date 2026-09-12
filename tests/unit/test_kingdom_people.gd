extends GutTest

## LE ROYAUME EST FAIT DE GENS (§ 9, T12.9) — le pendant de
## `test_pawn.gd`, côté royaume.
##
## Ce qui se joue ici est l'ARBITRAGE : les chantiers et la garde se
## disputent maintenant les mêmes PERSONNES, et pas seulement le même
## nombre de bras. Retirer son meilleur bûcheron du bois pour le poster à
## la garde coûte une production précise, et c'est la décision que la
## ville n'avait pas.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	ResourceTable.clear_cache()
	Worksite.clear_cache()
	Buildings.clear_cache()
	HeroNames.clear_cache()
	Invasion.clear_cache()


func _trade() -> StringName:
	return Worksite.ids()[0]


func _stocked() -> Kingdom:
	var kingdom := Kingdom.create()
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = 5000
	return kingdom


# --- Les gens --------------------------------------------------------------

func test_un_royaume_neuf_a_des_habitants_nommes() -> void:
	var kingdom := Kingdom.create()
	assert_eq(kingdom.pawns.size(), Worksite.starting_population())
	assert_eq(kingdom.population, kingdom.pawns.size(), "le compteur a divergé de la liste")
	for pawn: Pawn in kingdom.pawns:
		assert_false(pawn.given_name().is_empty())


## `population` et `assignments` sont des VUES sur la liste. Une trentaine
## d'appels les lisent : s'ils divergeaient, la moitié du royaume
## compterait des gens qui ne sont pas là.
func test_les_anciennes_vues_suivent_la_liste() -> void:
	var kingdom := Kingdom.create()
	kingdom.assign(_trade())
	assert_eq(int(kingdom.assignments.get(_trade(), 0)), 1)
	assert_eq(kingdom.assigned_to(_trade()), 1)
	assert_eq(kingdom.idle_pawns(), kingdom.population - 1)


func test_ecrire_dans_la_population_ajoute_des_gens() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = 6
	assert_eq(kingdom.pawns.size(), 6)
	var seen := {}
	for pawn: Pawn in kingdom.pawns:
		assert_false(seen.has(pawn.id), "deux habitants partagent un identifiant")
		seen[pawn.id] = true


# --- L'arbitrage -----------------------------------------------------------

## LE DÉFAUT EST LE MEILLEUR : un royaume qu'on remplit sans réfléchir doit
## rester jouable, et le geste rapide ne doit pas être le mauvais.
func test_sans_nom_c_est_le_plus_experimente_qui_part_travailler() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = 3
	kingdom.pawns[1].experience[_trade()] = Worksite.xp_per_level() * 3
	kingdom.assign(_trade())
	assert_eq(kingdom.workers_at(_trade())[0].id, kingdom.pawns[1].id)


## Et le rappel prend le MOINS expérimenté : le geste rapide garde les
## spécialistes là où ils valent quelque chose.
func test_sans_nom_c_est_le_moins_experimente_qu_on_rappelle() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = 3
	for pawn: Pawn in kingdom.pawns:
		pawn.posting = _trade()
	kingdom.pawns[0].experience[_trade()] = Worksite.xp_per_level() * 4
	kingdom.unassign(_trade())
	assert_eq(kingdom.pawns[0].posting, _trade(), "le spécialiste est parti")


func test_on_peut_designer_qui_va_ou() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = 3
	var wanted: Pawn = kingdom.pawns[2]
	assert_true(kingdom.assign(_trade(), wanted.id))
	assert_eq(kingdom.workers_at(_trade())[0].id, wanted.id)
	assert_true(kingdom.unassign(_trade(), wanted.id))
	assert_true(wanted.posting.is_empty())


func test_on_ne_poste_pas_quelqu_un_qui_travaille_deja() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = 3
	kingdom.assign(_trade(), kingdom.pawns[0].id)
	assert_false(
		kingdom.assign(Worksite.ids()[1], kingdom.pawns[0].id),
		"le même habitant tient deux chantiers"
	)


func test_un_chantier_plein_n_accepte_personne_de_plus() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = 12
	for i in Worksite.slots_of(_trade()):
		assert_true(kingdom.assign(_trade()))
	assert_false(kingdom.assign(_trade()))
	assert_eq(kingdom.assigned_to(_trade()), Worksite.slots_of(_trade()))


# --- Le cycle --------------------------------------------------------------

## CHACUN REND CE QUE SON MÉTIER VAUT. Sans ça, la spécialisation serait
## une décoration et le déplacement ne coûterait rien.
func test_la_production_suit_le_metier() -> void:
	var kingdom := _stocked()
	kingdom.population = 2
	kingdom.assign(_trade(), kingdom.pawns[0].id)
	var resource := Worksite.resource_of(_trade())

	var before := kingdom.amount(resource)
	kingdom.run_cycle()
	var rookie_made := kingdom.amount(resource) - before

	var veteran := _stocked()
	veteran.population = 2
	veteran.pawns[0].experience[_trade()] = Worksite.xp_per_level() * Worksite.max_trade_level()
	veteran.assign(_trade(), veteran.pawns[0].id)
	var was := veteran.amount(resource)
	veteran.run_cycle()
	assert_gt(veteran.amount(resource) - was, rookie_made)


func test_un_cycle_fait_progresser_ceux_qui_travaillent() -> void:
	var kingdom := _stocked()
	kingdom.population = 2
	var worker: Pawn = kingdom.pawns[0]
	kingdom.assign(_trade(), worker.id)
	kingdom.run_cycle()
	assert_eq(worker.experience_at(_trade()), Worksite.xp_per_cycle())
	assert_eq(kingdom.pawns[1].experience_at(_trade()), 0, "la garde a appris un métier")


## UN ARRIVANT ARRIVE À LA GARDE : il ne prend pas tout seul la place d'un
## spécialiste. Un habitant qui s'affecterait seul serait un bras de plus,
## pas une personne de plus.
func test_un_arrivant_rejoint_la_garde() -> void:
	var kingdom := _stocked()
	kingdom.levels[&"houses"] = Buildings.max_level(&"houses")
	var before := kingdom.population
	var report := kingdom.run_cycle()
	# PAS DE BRANCHE « SI PERSONNE N'ARRIVE » : un test qui passe à vide ne
	# protège rien. Les conditions d'arrivée sont toutes réunies ici — des
	# maisons au maximum, cinq mille vivres, deux habitants sur un plafond
	# bien plus haut — donc l'arrivée est EXIGÉE.
	assert_true(bool(report.get("arrived", false)), "personne n'est arrivé")
	assert_eq(kingdom.population, before + 1)
	assert_true(kingdom.pawns[kingdom.pawns.size() - 1].posting.is_empty())


# --- La sauvegarde ---------------------------------------------------------

func test_les_gens_et_leurs_metiers_survivent_a_la_sauvegarde() -> void:
	var kingdom := Kingdom.create()
	kingdom.population = 4
	kingdom.assign(_trade(), kingdom.pawns[1].id)
	kingdom.pawns[1].experience[_trade()] = Worksite.xp_per_level() * 2

	var copy := Kingdom.from_dictionary(kingdom.to_dictionary())
	assert_eq(copy.population, 4)
	assert_eq(copy.assigned_to(_trade()), 1)
	var restored := copy.workers_at(_trade())[0]
	assert_eq(restored.id, kingdom.pawns[1].id)
	assert_eq(restored.level_at(_trade()), 2)


## UNE SAUVEGARDE D'AVANT LE § 9 n'a qu'un compteur et des comptes. Elle
## doit garder ses habitants — elle perd seulement leurs métiers, qui
## n'existaient pas.
func test_une_sauvegarde_ancienne_garde_ses_habitants() -> void:
	var copy := Kingdom.from_dictionary({
		"population": 5,
		"assignments": {String(_trade()): 2},
		"levels": {},
		"stores": {},
	})
	assert_eq(copy.population, 5)
	assert_eq(copy.assigned_to(_trade()), 2)
	assert_eq(copy.idle_pawns(), 3)


## LE CYCLE DIT QUI A MONTÉ D'UN RANG. Sans ce retour, la progression des
## métiers est invisible tant qu'on ne rouvre pas un panneau — et une
## récompense qu'on ne voit pas ne récompense rien.
func test_le_cycle_nomme_ceux_qui_ont_progresse() -> void:
	var kingdom := _stocked()
	kingdom.population = 2
	var worker: Pawn = kingdom.pawns[0]
	# À un point du rang suivant : le cycle doit le faire basculer.
	worker.experience[_trade()] = Worksite.xp_per_level() - Worksite.xp_per_cycle()
	kingdom.assign(_trade(), worker.id)

	var promoted: Array = kingdom.run_cycle().get("promoted", [])
	assert_eq(promoted.size(), 1, "personne n'est annoncé")
	assert_eq(String((promoted[0] as Dictionary)["name"]), worker.given_name())
	assert_eq(int((promoted[0] as Dictionary)["level"]), 1)


func test_un_cycle_sans_progression_n_annonce_personne() -> void:
	var kingdom := _stocked()
	kingdom.population = 2
	kingdom.assign(_trade(), kingdom.pawns[0].id)
	# Fraîchement posté : il lui faut plusieurs cycles pour le premier rang.
	assert_eq((kingdom.run_cycle().get("promoted", []) as Array).size(), 0)


## LE MAÎTRE EST ANNONCÉ AUTREMENT, parce que c'est la dernière fois : au
## sommet, laisser quelqu'un là n'apprend plus rien, et l'écran doit le
## dire au lieu de laisser le joueur l'apprendre en comparant des rangs.
func test_le_dernier_rang_s_annonce_comme_une_maitrise() -> void:
	var kingdom := _stocked()
	kingdom.population = 2
	var worker: Pawn = kingdom.pawns[0]
	var top := Worksite.xp_per_level() * Worksite.max_trade_level()
	worker.experience[_trade()] = top - Worksite.xp_per_cycle()
	kingdom.assign(_trade(), worker.id)

	var promoted: Array = kingdom.run_cycle().get("promoted", [])
	assert_eq(promoted.size(), 1)
	assert_true(bool((promoted[0] as Dictionary)["master"]), "la maîtrise n'est pas signalée")
