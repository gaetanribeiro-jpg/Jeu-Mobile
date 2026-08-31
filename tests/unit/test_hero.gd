extends GutTest

## T2.1 et T2.2 — le héros et sa progression.
##
## Ce que ces tests protègent avant tout : `Hero` applique les
## modifications UNE FOIS, et `Unit` les reçoit toutes faites. Si un bonus
## de niveau se remettait à vivre dans le combat, la même unité vaudrait
## deux choses différentes selon d'où on la regarde.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()
	HeroProgression.reload()


func _hero(class_id: StringName = &"warrior") -> Hero:
	return Hero.create(1, class_id, "Aldric")


# --- Identité --------------------------------------------------------------

func test_un_heros_naît_au_niveau_un_sans_experience() -> void:
	var hero := _hero()
	assert_eq(hero.level, 1)
	assert_eq(hero.experience, 0)
	assert_eq(hero.class_id, &"warrior")
	assert_eq(hero.given_name, "Aldric")


func test_une_classe_inconnue_ne_fabrique_pas_de_heros() -> void:
	assert_null(Hero.create(1, &"paladin", "Brom"))
	assert_push_error("classe de héros inconnue")


func test_l_epithete_ne_paraît_que_s_il_y_en_a_une() -> void:
	# Elle sert à départager deux homonymes dans la même compagnie.
	var hero := _hero()
	assert_eq(hero.display_name(), "Aldric")
	hero.epithet = "le Boiteux"
	assert_eq(hero.display_name(), "Aldric le Boiteux")


func test_chaque_classe_declare_sa_statistique_maîtresse() -> void:
	assert_eq(Hero.create(1, &"warrior", "A").primary_stat(), &"strength")
	assert_eq(Hero.create(2, &"archer", "B").primary_stat(), &"agility")
	assert_eq(Hero.create(3, &"mage", "C").primary_stat(), &"intelligence")


# --- Expérience ------------------------------------------------------------

func test_l_experience_ouvre_des_niveaux_sans_les_prendre() -> void:
	# Une montée peut demander un choix : c'est au joueur de le faire, pas
	# à l'expérience de trancher pour lui.
	var hero := _hero()
	assert_eq(hero.add_experience(HeroProgression.experience_to_reach(2)), 1)
	assert_eq(hero.level, 1, "le niveau n'a pas encore été pris")
	assert_true(hero.can_level_up())


func test_une_experience_nulle_ou_negative_ne_fait_rien() -> void:
	var hero := _hero()
	assert_eq(hero.add_experience(0), 0)
	assert_eq(hero.add_experience(-50), 0)
	assert_eq(hero.experience, 0)


func test_l_experience_peut_ouvrir_plusieurs_niveaux_d_un_coup() -> void:
	var hero := _hero()
	assert_eq(hero.add_experience(HeroProgression.experience_to_reach(4)), 3)
	assert_eq(hero.reachable_level(), 4)


func test_le_plafond_de_niveau_est_respecte() -> void:
	var hero := _hero()
	hero.add_experience(999999)
	assert_eq(hero.reachable_level(), HeroProgression.max_level())
	while hero.can_level_up():
		var offered := hero.pending_choices()
		hero.level_up(offered[0] if not offered.is_empty() else &"")
	assert_eq(hero.level, HeroProgression.max_level())
	assert_false(hero.can_level_up())


func test_l_experience_restante_se_lit() -> void:
	var hero := _hero()
	assert_eq(hero.experience_to_next_level(), HeroProgression.experience_to_reach(2))
	hero.add_experience(10)
	assert_eq(
		hero.experience_to_next_level(),
		HeroProgression.experience_to_reach(2) - 10
	)


func test_les_seuils_croissent_toujours() -> void:
	# Un seuil qui redescendrait donnerait deux niveaux pour la même
	# expérience, et `reachable_level` renverrait n'importe quoi.
	var previous := 0
	for level in range(2, HeroProgression.max_level() + 1):
		var threshold := HeroProgression.experience_to_reach(level)
		assert_gt(threshold, previous, "seuil du niveau %d" % level)
		previous = threshold


# --- Montée en niveau ------------------------------------------------------

func test_monter_sans_experience_est_refuse() -> void:
	assert_false(_hero().level_up())


func test_un_niveau_sans_choix_se_prend_directement() -> void:
	var hero := _hero()
	hero.add_experience(HeroProgression.experience_to_reach(2))
	assert_true(HeroProgression.choices_at(2).is_empty(), "le niveau 2 ne demande rien")
	assert_true(hero.level_up())
	assert_eq(hero.level, 2)


func test_un_niveau_a_choix_refuse_une_option_absente() -> void:
	var hero := _hero()
	var level: int = HeroProgression.choice_levels()[0]
	hero.add_experience(HeroProgression.experience_to_reach(level))
	while hero.level < level - 1:
		hero.level_up()
	assert_false(hero.level_up(&"invincibilite"))
	assert_push_error("n'est pas une option")


func test_un_niveau_a_choix_refuse_l_absence_de_choix() -> void:
	var hero := _hero()
	var level: int = HeroProgression.choice_levels()[0]
	hero.add_experience(HeroProgression.experience_to_reach(level))
	while hero.level < level - 1:
		hero.level_up()
	assert_false(hero.level_up(), "on ne monte pas en laissant le choix en suspens")
	assert_push_error("n'est pas une option")
	assert_eq(hero.level, level - 1)


func test_la_montee_libre_s_arrete_devant_un_choix() -> void:
	# C'est ce qui permet d'encaisser l'expérience d'une expédition entière
	# sans voler au joueur les décisions qu'elle contient.
	var hero := _hero()
	hero.add_experience(999999)
	hero.level_up_free()
	assert_eq(hero.level, HeroProgression.choice_levels()[0] - 1)
	assert_true(hero.can_level_up())
	assert_false(hero.pending_choices().is_empty())


func test_le_choix_retenu_est_conserve() -> void:
	var hero := _hero()
	hero.add_experience(999999)
	hero.level_up_free()
	var option: StringName = hero.pending_choices()[0]
	assert_true(hero.level_up(option))
	assert_eq(StringName(hero.choices[hero.level]), option)


func test_chaque_niveau_a_choix_offre_au_moins_deux_options() -> void:
	# Une seule option n'est pas un choix.
	for level: int in HeroProgression.choice_levels():
		assert_gt(
			HeroProgression.choices_at(level).size(), 1,
			"le niveau %d n'offre pas de vrai choix" % level
		)


func test_toute_option_declaree_donne_quelque_chose() -> void:
	for level: int in HeroProgression.choice_levels():
		for option: StringName in HeroProgression.choices_at(level):
			assert_false(
				HeroProgression.option_grants(option).is_empty(),
				"l'option %s ne donne rien" % option
			)
			assert_ne(
				HeroProgression.option_name_key(option), "",
				"l'option %s n'a pas de clé de traduction" % option
			)


# --- Statistiques ----------------------------------------------------------

func test_un_heros_de_niveau_un_vaut_sa_classe() -> void:
	var hero := _hero()
	var base := Unit.hero_class(&"warrior")
	var stats := hero.effective_stats()
	assert_eq(int(stats["hit_points"]), int(base["hit_points"]))
	assert_eq(int(stats["strength"]), int(base["strength"]))


func test_chaque_niveau_ajoute_des_pv() -> void:
	# C'est le gain qui se VOIT, sur la barre de vie, à chaque combat.
	var hero := _hero()
	var before := int(hero.effective_stats()["hit_points"])
	hero.add_experience(HeroProgression.experience_to_reach(2))
	hero.level_up()
	assert_eq(
		int(hero.effective_stats()["hit_points"]),
		before + int(HeroProgression.per_level()[&"hit_points"])
	)


func test_un_niveau_pair_nourrit_la_statistique_maîtresse() -> void:
	var hero := _hero(&"mage")
	var before := int(hero.effective_stats()["intelligence"])
	hero.add_experience(999999)
	hero.level_up()
	assert_eq(hero.level, 2)
	assert_gt(
		int(hero.effective_stats()["intelligence"]), before,
		"le niveau 2 nourrit l'Intelligence du Mage"
	)


func test_la_maîtresse_suit_la_classe_et_pas_l_inverse() -> void:
	var warrior := _hero(&"warrior")
	var archer := Hero.create(2, &"archer", "Lyra")
	for hero: Hero in [warrior, archer]:
		hero.add_experience(999999)
		hero.level_up()
	assert_gt(
		int(warrior.effective_stats()["strength"]),
		int(Unit.hero_class(&"warrior")["strength"]), "la Force du Guerrier"
	)
	assert_eq(
		int(warrior.effective_stats()["agility"]),
		int(Unit.hero_class(&"warrior")["agility"]), "son Agilité n'a pas bougé"
	)
	assert_gt(
		int(archer.effective_stats()["agility"]),
		int(Unit.hero_class(&"archer")["agility"]), "l'Agilité de l'Archer"
	)


func test_un_choix_retenu_modifie_les_statistiques() -> void:
	var hero := _hero()
	hero.add_experience(999999)
	hero.level_up_free()
	var option: StringName = hero.pending_choices()[0]
	var grants := HeroProgression.option_grants(option)
	var before := hero.effective_stats()
	hero.level_up(option)
	var after := hero.effective_stats()
	for key: Variant in grants.keys():
		var field := StringName(key)
		if field == HeroProgression.PRIMARY:
			field = hero.primary_stat()
		assert_gt(
			int(after[String(field)]), int(before.get(String(field), 0)),
			"le choix %s n'a pas changé %s" % [option, field]
		)


func test_un_bonus_exterieur_s_ajoute_sans_être_conserve() -> void:
	# C'est par là que passeront les bâtiments du royaume et les
	# bénédictions d'expédition, sans que le héros ait à les connaître.
	var hero := _hero()
	var base := int(hero.effective_stats()["hit_points"])
	assert_eq(int(hero.effective_stats({"hit_points": 40})["hit_points"]), base + 40)
	assert_eq(int(hero.effective_stats()["hit_points"]), base, "rien n'a été retenu")


# --- Entrée en combat ------------------------------------------------------

func test_le_heros_fabrique_son_unite_de_combat() -> void:
	var hero := _hero()
	hero.add_experience(999999)
	hero.level_up_free()
	var unit := hero.to_unit(7, 2)
	assert_not_null(unit)
	assert_eq(unit.id, 7)
	assert_eq(unit.slot, 2)
	assert_eq(unit.class_id, &"warrior")
	assert_true(unit.is_hero())
	assert_eq(unit.max_hit_points, int(hero.effective_stats()["hit_points"]))
	assert_eq(unit.hit_points, unit.max_hit_points, "elle entre en pleine forme")


func test_l_unite_porte_les_gains_de_niveau() -> void:
	var novice := Hero.create(1, &"warrior", "Aldric").to_unit(1)
	var veteran := _hero()
	veteran.add_experience(999999)
	veteran.level_up_free()
	assert_gt(
		veteran.to_unit(2).max_hit_points, novice.max_hit_points,
		"un vétéran encaisse plus qu'une recrue"
	)


func test_l_unite_ne_recalcule_jamais_les_bonus() -> void:
	# Le sens de la dépendance : Hero connaît Unit, jamais l'inverse. Si le
	# combat se remettait à lire le niveau, la même unité vaudrait deux
	# choses selon d'où on la regarde.
	var hero := _hero()
	hero.add_experience(999999)
	hero.level_up_free()
	var unit := hero.to_unit(1)
	var carried := unit.max_hit_points
	hero.level = 1
	assert_eq(unit.max_hit_points, carried, "l'unité ne dépend plus du héros")


# --- Sérialisation ---------------------------------------------------------

func test_aller_retour_de_serialisation() -> void:
	var hero := _hero(&"archer")
	hero.epithet = "la Rousse"
	hero.color = "Purple"
	hero.add_experience(999999)
	hero.level_up_free()
	hero.level_up(hero.pending_choices()[1])

	var copy := Hero.from_dictionary(hero.to_dictionary())
	assert_eq(copy.id, hero.id)
	assert_eq(copy.display_name(), hero.display_name())
	assert_eq(copy.class_id, hero.class_id)
	assert_eq(copy.color, hero.color)
	assert_eq(copy.level, hero.level)
	assert_eq(copy.experience, hero.experience)
	assert_eq(copy.choices, hero.choices)
	assert_eq(copy.effective_stats(), hero.effective_stats(), "mêmes statistiques")
