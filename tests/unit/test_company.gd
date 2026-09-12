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


# --- La composition de l'équipe (T12.7) ------------------------------------
#
# ELLE VIVAIT DANS L'ÉCRAN DE TITRE, remise à zéro chaque fois qu'on
# fermait un écran : le joueur repartait toujours avec ses quatre PREMIERS
# héros. Un cinquième recruté ne jouait donc JAMAIS — ce qui vidait de son
# sens le recrutement à trois candidats de T12.3, et la demande de Gaetan
# « changer de personnage ou de composition » avec.

func _crowded(count: int) -> Company:
	var company := Company.new()
	var classes: Array[StringName] = [&"warrior", &"archer", &"mage"]
	for i in count:
		company.recruit(classes[i % classes.size()], CombatRng.new(100 + i))
	return company


func test_une_compagnie_neuve_a_une_equipe_complete() -> void:
	var company := _crowded(6)
	assert_eq(company.squad_ids.size(), CombatRules.team_size())
	for hero_id: int in company.squad_ids:
		assert_not_null(company.hero_by_id(hero_id))


## LE CŒUR : un héros recruté au-delà du plafond N'ENTRE PAS tout seul.
## S'il entrait, la composition serait encore subie — simplement dans
## l'autre sens.
func test_un_heros_de_trop_ne_part_pas_tout_seul() -> void:
	var company := _crowded(CombatRules.team_size())
	var extra := company.recruit(&"warrior", CombatRng.new(77))
	assert_not_null(extra)
	assert_false(company.is_in_squad(extra.id), "il s'est invité")
	assert_eq(company.squad_ids.size(), CombatRules.team_size())


func test_on_echange_un_heros_contre_un_autre() -> void:
	var company := _crowded(CombatRules.team_size())
	var extra := company.recruit(&"mage", CombatRng.new(78))
	var benched := company.squad_ids[0]
	assert_false(company.toggle_squad(benched), "il devrait sortir")
	assert_true(company.toggle_squad(extra.id), "il devrait entrer")
	assert_true(company.is_in_squad(extra.id))
	assert_false(company.is_in_squad(benched))
	assert_eq(company.squad_ids.size(), CombatRules.team_size())


## LES DEUX BORNES. On ne dépasse pas le plafond — la carte ne prévoit pas
## plus de cases de départ — et on ne descend pas sous un héros, parce
## qu'une équipe vide n'est pas une composition, c'est une impasse.
func test_l_equipe_ne_depasse_pas_le_plafond() -> void:
	var company := _crowded(CombatRules.team_size() + 2)
	var outside := company.heroes[CombatRules.team_size()]
	assert_false(company.toggle_squad(outside.id), "l'équipe était pleine")
	assert_eq(company.squad_ids.size(), CombatRules.team_size())


func test_le_dernier_ne_peut_pas_sortir() -> void:
	var company := _crowded(1)
	var alone := company.heroes[0].id
	assert_true(company.toggle_squad(alone), "il doit rester")
	assert_true(company.is_in_squad(alone))


func test_un_heros_qui_part_quitte_l_equipe() -> void:
	var company := _crowded(CombatRules.team_size())
	var leaving := company.squad_ids[0]
	company.remove(leaving)
	assert_false(company.is_in_squad(leaving))


func test_la_composition_survit_a_la_sauvegarde() -> void:
	var company := _crowded(CombatRules.team_size() + 2)
	var benched := company.squad_ids[0]
	company.toggle_squad(benched)
	company.toggle_squad(company.heroes[CombatRules.team_size()].id)
	var chosen := company.squad_ids.duplicate()
	var copy := Company.from_dictionary(company.to_dictionary())
	assert_eq(copy.squad_ids, chosen, "la composition a été refaite au chargement")
	assert_false(copy.is_in_squad(benched))


func test_l_equipe_choisie_rend_les_heros_dans_l_ordre() -> void:
	var company := _crowded(CombatRules.team_size() + 1)
	var picked := company.selected_squad()
	assert_eq(picked.size(), company.squad_ids.size())
	for i in picked.size():
		assert_eq(picked[i].id, company.squad_ids[i])


# --- Fondre un objet (§ 32, T12.8) -----------------------------------------
#
# « UN MÊME OBJET PEUT ÊTRE VENDU, AMÉLIORER UNE ARME, AMÉLIORER UN
# BÂTIMENT OU DÉBLOQUER UNE TECHNOLOGIE — CELA CRÉE DES CHOIX
# STRATÉGIQUES. » La réserve n'avait aucun débouché : trente objets pour
# vingt-cinq cases portées, et rien à faire du reste.

func _with_stash(item_id: StringName) -> Company:
	var company := Company.new()
	company.stash.append(item_id)
	return company


func test_fondre_retire_l_objet_et_verse_au_royaume() -> void:
	var kingdom := Kingdom.create()
	var item_id: StringName = Equipment.ids()[0]
	var company := _with_stash(item_id)
	var wood := kingdom.amount(&"wood")
	var gained := company.melt(item_id, kingdom)
	assert_false(gained.is_empty(), "fondre devrait rendre quelque chose")
	assert_false(company.stash.has(item_id), "l'objet est resté dans la réserve")
	assert_gt(kingdom.amount(&"wood"), wood)


## PAS D'OR, ET C'EST CE QUI SÉPARE FONDRE DE VENDRE. Le marchand rend de
## l'or pendant une expédition ; la fonderie rend des matériaux au
## royaume. Si elle rendait aussi de l'or, elle dominerait le marchand et
## il n'y aurait plus deux options mais une bonne réponse.
func test_fondre_ne_rend_jamais_d_or() -> void:
	var kingdom := Kingdom.create()
	var company := _with_stash(Equipment.ids()[0])
	company.gold = 100
	company.melt(Equipment.ids()[0], kingdom)
	assert_eq(company.gold, 100, "la fonderie a rendu de l'or")


## Ce qu'un objet vaut à la fonte suit son BUDGET DE RARETÉ, le barème que
## `verify_items` vérifie déjà : un objet ne peut donc pas valoir à la
## fonte autre chose que ce qu'il vaut.
func test_un_objet_rare_rend_plus_qu_un_commun() -> void:
	var common: StringName = &""
	var better: StringName = &""
	for item_id: StringName in Equipment.ids():
		if Equipment.rarity_of(item_id) == &"common" and common.is_empty():
			common = item_id
		elif Equipment.rarity_of(item_id) == &"epic" and better.is_empty():
			better = item_id
	assert_false(common.is_empty(), "aucun objet commun dans les données")
	assert_false(better.is_empty(), "aucun objet épique dans les données")
	assert_gt(
		int(Equipment.salvage_of(better).get(&"wood", 0)),
		int(Equipment.salvage_of(common).get(&"wood", 0))
	)


func test_on_ne_fond_pas_ce_qu_on_n_a_pas() -> void:
	var kingdom := Kingdom.create()
	var company := Company.new()
	assert_true(company.melt(Equipment.ids()[0], kingdom).is_empty())


func test_on_ne_fond_pas_sans_royaume() -> void:
	var company := _with_stash(Equipment.ids()[0])
	assert_true(company.melt(Equipment.ids()[0], null).is_empty())
	assert_eq(company.stash.size(), 1, "l'objet a disparu sans rien rendre")
