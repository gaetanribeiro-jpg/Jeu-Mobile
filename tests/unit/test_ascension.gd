extends GutTest

## L'ascension des héros — Bleu → Violet → Or.
##
## `Hero.color` existait depuis la Phase 2, avec sa valeur par défaut, et
## n'était lu par personne : les vues figeaient le bleu en constante dans
## cinq endroits. Sixième mécanique déclarée et jamais branchée du projet,
## après `KIND_HEAL`, `KIND_PUSH`, les 70 entrées `ui` et
## `requires_not_moved`.
##
## CE QUE CES TESTS PROTÈGENT EN PRIORITÉ : que la couleur atteigne la
## `Unit`. Le reste — les coûts, les conditions — se lit dans les données
## et se corrige en une ligne ; une couleur qui n'arrive pas jusqu'au
## plateau rend un héros en ombre nue, sans une seule erreur.


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
	Ascension.clear_cache()


## L'OR VIT DANS LA BOURSE DE LA COMPAGNIE, pas dans les réserves du
## royaume : sans compagnie, `can_afford` refuse toujours un coût qui
## demande de l'or, et l'ascension en demande. C'est ce qui a fait échouer
## le premier jet de ces tests.
func _purse(gold: int = 100000) -> Company:
	var company := Company.new()
	company.gold = gold
	return company


func _rich() -> Kingdom:
	var kingdom := Kingdom.create()
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = 100000
	return kingdom


func _with_tower(level: int) -> Kingdom:
	var kingdom := _rich()
	# LA CLÉ EST UNE `StringName` : `level_of` lit `levels.get(building_id)`
	# et une String n'y correspond pas. Le royaume répondait « pas de tour »
	# alors que le test croyait en avoir bâti une.
	kingdom.levels[Ascension.BUILDING] = level
	return kingdom


func _hero(level: int = 10) -> Hero:
	var hero := Hero.create(1, &"warrior", "Aldric")
	hero.level = level
	return hero


# --- Les rangs ------------------------------------------------------------

func test_un_heros_neuf_est_au_premier_rang() -> void:
	var hero := _hero(1)
	assert_eq(hero.rank, 0, "un héros neuf est commun")
	assert_eq(hero.color, Ascension.color_of(0), "et il porte la couleur du rang")


func test_les_trois_rangs_ont_des_couleurs_distinctes() -> void:
	var seen := {}
	for index in Ascension.rank_count():
		var color := Ascension.color_of(index)
		assert_false(seen.has(color), "« %s » ne doit servir qu'une fois" % color)
		seen[color] = true
	assert_gt(Ascension.rank_count(), 1, "il faut au moins deux rangs")


# --- Ce qui refuse --------------------------------------------------------

func test_un_heros_trop_bas_ne_s_eleve_pas() -> void:
	var kingdom := _with_tower(5)
	var hero := _hero(1)
	assert_eq(
		kingdom.cannot_ascend_because(hero, _purse()), Ascension.BLOCKED_LEVEL,
		"le niveau manque avant tout le reste"
	)
	assert_eq(kingdom.ascend(hero, _purse()), -1)
	assert_eq(hero.rank, 0, "et rien n'a bougé")


## SANS LA TOUR, RIEN. C'est le point où le royaume devient nécessaire à un
## héros qu'on a déjà — recruter est un début, élever demande d'avoir bâti.
func test_sans_tour_personne_ne_s_eleve() -> void:
	var kingdom := _with_tower(0)
	assert_eq(
		kingdom.cannot_ascend_because(_hero(), _purse()), Ascension.BLOCKED_TOWER,
		"la tour manque"
	)


func test_sans_ressources_personne_ne_s_eleve() -> void:
	var kingdom := Kingdom.create()
	kingdom.levels[Ascension.BUILDING] = 5
	for resource_id: StringName in ResourceTable.ids():
		kingdom.stores[resource_id] = 0
	assert_eq(
		kingdom.cannot_ascend_because(_hero(), _purse(0)), Ascension.BLOCKED_COST,
		"le coût manque"
	)


func test_au_sommet_on_ne_monte_plus() -> void:
	var kingdom := _with_tower(5)
	var hero := _hero()
	hero.set_rank(Ascension.top_rank())
	assert_eq(kingdom.cannot_ascend_because(hero, _purse()), Ascension.BLOCKED_MAXED)


# --- Ce qui accepte -------------------------------------------------------

func test_elever_change_le_rang_et_la_couleur() -> void:
	var kingdom := _with_tower(5)
	var hero := _hero(4)
	var purse := _purse()
	var before := kingdom.amount(&"gold", purse)
	assert_eq(kingdom.ascend(hero, purse), 1, "il atteint le second rang")
	assert_eq(hero.rank, 1)
	assert_eq(hero.color, Ascension.color_of(1), "et il en porte la couleur")
	assert_lt(kingdom.amount(&"gold", purse), before, "la bourse a payé")


## ON MONTE, ON NE REMPLACE PAS : un héros au dernier rang garde ce que le
## précédent lui a donné.
func test_les_gains_des_rangs_se_cumulent() -> void:
	var first := Ascension.grants_of(1)
	var both := Ascension.grants_up_to(Ascension.top_rank())
	for key: Variant in first.keys():
		assert_gte(
			int(both.get(key, 0)), int(first[key]),
			"le rang %s doit survivre au suivant" % key
		)


func test_un_heros_eleve_est_plus_solide() -> void:
	var plain := _hero()
	var raised := _hero()
	raised.set_rank(Ascension.top_rank())
	assert_gt(
		int(raised.effective_stats().get("hit_points", 0)),
		int(plain.effective_stats().get("hit_points", 0)),
		"l'élévation doit se sentir, même modestement"
	)


# --- Ce que ces tests protègent vraiment ----------------------------------

## LA COULEUR DOIT ATTEINDRE LA `Unit`, sinon la vue dessine une ombre nue
## sans qu'aucune erreur ne soit poussée — le défaut de T11.8.
func test_la_couleur_du_rang_atteint_l_unite() -> void:
	var hero := _hero()
	hero.set_rank(Ascension.top_rank())
	var unit := hero.to_unit(1)
	assert_not_null(unit)
	assert_eq(
		unit.sprite_color, Ascension.color_of(Ascension.top_rank()),
		"la couleur voyage dans le bloc de statistiques"
	)
	assert_false(
		SpriteFrameFactory.for_unit(unit.sprite_id, &"idle", unit.sprite_color) == null,
		"et le pack sait la dessiner"
	)


## Un héros du banc d'essai n'a pas de `Hero` derrière lui : il doit tout
## de même porter une couleur, sinon il se dessine en ombre nue.
func test_un_heros_sans_fiche_porte_quand_meme_une_couleur() -> void:
	var unit := Unit.from_hero_class(1, &"warrior", Vector2i.ZERO)
	assert_not_null(unit)
	assert_eq(unit.sprite_color, Ascension.color_of(0))


# --- La sauvegarde --------------------------------------------------------

func test_le_rang_survit_a_la_sauvegarde() -> void:
	var hero := _hero()
	hero.set_rank(1)
	var back := Hero.from_dictionary(hero.to_dictionary())
	assert_eq(back.rank, 1)
	assert_eq(back.color, Ascension.color_of(1))


## UNE SAUVEGARDE D'AVANT L'ASCENSION n'a qu'une couleur. Son héros ne doit
## pas repartir de zéro : le rang se déduit de la couleur enregistrée.
func test_une_vieille_sauvegarde_retrouve_son_rang() -> void:
	var hero := _hero()
	var old := hero.to_dictionary()
	old.erase("rank")
	old["color"] = Ascension.color_of(0)
	assert_eq(Hero.from_dictionary(old).rank, 0)
