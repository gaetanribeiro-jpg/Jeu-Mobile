extends GutTest

## LES HABITANTS SONT DES GENS (§ 9, T12.9).
##
## « Le royaume a une population : agriculteurs, bûcherons, mineurs… à
## terme certains habitants auront nom, niveau, métier. »
##
## LE DÉFAUT QUE ÇA CORRIGE : `population: int` et
## `assignments: { chantier → nombre }`. Douze bras interchangeables,
## répartis une fois et jamais revus. Un nombre n'est pas une décision, et
## c'est ce qui rendait la ville expédiable en trente secondes entre deux
## sorties — le reproche de Gaetan, mot pour mot.
##
## CE QUE CES TESTS PROTÈGENT EN PRIORITÉ, dans cet ordre :
##  1. que le métier s'apprenne SÉPARÉMENT par chantier — c'est ce qui
##     donne un prix au déplacement, donc une décision ;
##  2. que la production suive le métier, sinon la spécialisation est une
##     décoration ;
##  3. que les gens SURVIVENT à la sauvegarde, métiers compris.


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	ResourceTable.clear_cache()
	Worksite.clear_cache()
	Buildings.clear_cache()
	HeroNames.clear_cache()


func _trade() -> StringName:
	return Worksite.ids()[0]


func _other_trade() -> StringName:
	return Worksite.ids()[1]


func _veteran(worksite_id: StringName, levels: int) -> Pawn:
	var pawn := Pawn.create(1)
	pawn.experience[worksite_id] = Worksite.xp_per_level() * levels
	return pawn


# --- Le métier -------------------------------------------------------------

func test_un_habitant_porte_un_nom() -> void:
	assert_false(Pawn.create(0).given_name().is_empty())
	# Deux identifiants voisins ne doivent pas donner le même nom, sinon le
	# village entier s'appelle pareil et la liste devient illisible.
	assert_ne(Pawn.create(0).given_name(), Pawn.create(1).given_name())


## SON NOM EST UNE FONCTION DE SON IDENTIFIANT, jamais un tirage : le décor
## n'a pas à consommer la graine de la partie (règle des rochers, T9.10).
func test_le_nom_ne_depend_que_de_l_identifiant() -> void:
	assert_eq(Pawn.create(7).given_name(), Pawn.create(7).given_name())


## LE PAS DOIT RESTER PREMIER AVEC LA TAILLE DE LA LISTE. `pool[id]`
## donnait le village dans l'ORDRE ALPHABÉTIQUE — Aldric, Anselme,
## Arnaud… — ce qui se lit comme une liste et pas comme des gens. Un pas
## premier disperse SANS perdre l'unicité ; un pas mal choisi ferait
## revenir les mêmes noms au bout de quelques habitants, et deux voisins
## de chantier s'appelleraient pareil.
func test_les_noms_ne_se_repetent_pas_avant_d_avoir_ete_tous_pris() -> void:
	var pool := HeroNames.all_given()
	assert_gt(pool.size(), 0)
	var seen := {}
	for i in pool.size():
		seen[Pawn.create(i).given_name()] = true
	assert_eq(
		seen.size(), pool.size(),
		"le pas de dispersion n'est pas premier avec la taille de la liste"
	)


func test_les_habitants_ne_sortent_pas_dans_l_ordre_alphabetique() -> void:
	var names := PackedStringArray()
	for i in 6:
		names.append(Pawn.create(i).given_name())
	var sorted := names.duplicate()
	sorted.sort()
	assert_ne(
		Array(names), Array(sorted),
		"le village sort dans l'ordre alphabétique : ça se lit comme une liste"
	)


## LE CŒUR DU SYSTÈME. Un bûcheron de rang 4 est un carrier de rang 0 :
## c'est ce qui donne un prix PRÉCIS au déplacement, et ce prix est la
## décision qu'on demande au joueur à chaque retour.
func test_le_metier_s_apprend_separement_par_chantier() -> void:
	var pawn := _veteran(_trade(), 3)
	assert_eq(pawn.level_at(_trade()), 3)
	assert_eq(pawn.level_at(_other_trade()), 0, "le métier a déteint sur l'autre chantier")


func test_un_cycle_de_travail_fait_progresser_au_poste_tenu() -> void:
	var pawn := Pawn.create(1)
	pawn.posting = _trade()
	var before := pawn.experience_at(_trade())
	pawn.work_a_cycle()
	assert_eq(pawn.experience_at(_trade()), before + Worksite.xp_per_cycle())
	assert_eq(pawn.experience_at(_other_trade()), 0)


## RIEN NE S'APPREND À LA GARDE, et c'est ce qui rend le choix coûteux des
## DEUX côtés : poster un spécialiste le prive de sa progression, en plus
## de sa production.
func test_la_garde_n_apprend_aucun_metier() -> void:
	var pawn := Pawn.create(1)
	pawn.posting = &""
	pawn.work_a_cycle()
	for worksite_id: StringName in Worksite.ids():
		assert_eq(pawn.experience_at(worksite_id), 0)


func test_le_rang_est_plafonne() -> void:
	var pawn := _veteran(_trade(), Worksite.max_trade_level() + 40)
	assert_eq(pawn.level_at(_trade()), Worksite.max_trade_level())
	assert_true(pawn.is_master_at(_trade()))


# --- La production ---------------------------------------------------------

func test_un_chevronne_produit_plus_qu_un_debutant() -> void:
	var rookie := Pawn.create(1)
	var expert := _veteran(_trade(), Worksite.max_trade_level())
	assert_eq(rookie.yield_at(_trade()), Worksite.per_cycle(_trade()))
	assert_gt(expert.yield_at(_trade()), rookie.yield_at(_trade()))


## Le gain est une FRACTION de la base : un seul réglage vaut pour les
## quatre chantiers, et une scierie comme une mine doublent au même rang.
func test_le_gain_suit_la_base_du_chantier() -> void:
	for worksite_id: StringName in Worksite.ids():
		var expert := _veteran(worksite_id, Worksite.max_trade_level())
		var ratio := float(expert.yield_at(worksite_id)) / float(Worksite.per_cycle(worksite_id))
		assert_almost_eq(
			ratio, 1.0 + Worksite.yield_per_level() * Worksite.max_trade_level(), 0.06,
			"%s ne double pas au même rang que les autres" % worksite_id
		)


# --- La sauvegarde ---------------------------------------------------------

func test_un_habitant_survit_a_la_sauvegarde() -> void:
	var pawn := _veteran(_trade(), 2)
	pawn.posting = _trade()
	var copy := Pawn.from_dictionary(pawn.to_dictionary())
	assert_eq(copy.id, pawn.id)
	assert_eq(copy.posting, pawn.posting)
	assert_eq(copy.level_at(_trade()), 2)
	assert_eq(copy.given_name(), pawn.given_name())


## Un chantier retiré des données depuis la sauvegarde renvoie son monde à
## la garde, sans emporter la partie — même règle que la réserve et le sac.
func test_un_chantier_disparu_renvoie_a_la_garde() -> void:
	var saved := Pawn.create(3).to_dictionary()
	saved["posting"] = "chantier_qui_n_existe_plus"
	assert_true(Pawn.from_dictionary(saved).posting.is_empty())
