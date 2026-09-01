extends GutTest

## Les potions du § 44, et le soin qui les rend possibles.
##
## CE QUE CES TESTS PROTÈGENT, en une phrase : une potion bue puis annulée
## doit revenir dans le sac. C'est la règle « rien n'est irréversible
## avant la fin de l'activation » appliquée au seul objet du jeu qui
## disparaît quand on s'en sert.


func before_each() -> void:
	Consumable.clear_cache()
	Ability.clear_cache()
	CombatRules.clear_cache()
	Unit.clear_cache()


func after_all() -> void:
	Consumable.clear_cache()
	Ability.clear_cache()
	CombatRules.clear_cache()
	Unit.clear_cache()


func _board() -> CombatBoard:
	var rows := PackedStringArray([
		"............", "............", "............",
		"............", "............", "............",
		"............", "............", "............",
	])
	return CombatBoard.from_rows(rows, CombatRules.ADJACENCY_ORTHOGONAL)


## Un combat prêt, dont le personnage ACTIF est un héros.
##
## LA TIMELINE DÉCIDE QUI JOUE, pas l'ordre où on pose les unités — c'est
## le § 16, et l'oublier a fait échouer cinq tests d'un coup : le Guerrier
## posé en premier n'était pas celui qui avait la main, donc `can_use` le
## refusait et aucune potion ne partait. L'ennemi est relégué dans un coin
## pour que son activation, si elle vient, ne blesse personne.
func _engine(stock: Dictionary = {}) -> CombatEngine:
	var board := _board()
	board.place_unit(Unit.from_hero_class(1, &"warrior", Vector2i(1, 4)), Vector2i(1, 4))
	board.place_unit(Unit.from_hero_class(2, &"warrior", Vector2i(2, 4)), Vector2i(2, 4))
	board.place_unit(Unit.from_enemy(200, &"gnome", Vector2i(11, 8)), Vector2i(11, 8))
	var engine := CombatEngine.new(
		board, CombatObjective.from_dictionary({"kind": "eliminate"}), CombatRng.new(7)
	)
	engine.supplies = stock.duplicate() if not stock.is_empty() \
		else Consumable.starting_stock()
	engine.start()
	engine.begin_combat()
	var guard := 0
	while engine.current_unit() != null and not engine.current_unit().is_hero() \
			and guard < 8:
		engine.end_activation()
		guard += 1
	return engine


## Le héros qui a la main, et son coéquipier.
func _actors(engine: CombatEngine) -> Array[Unit]:
	var hero := engine.current_unit()
	var mate: Unit = null
	for unit: Unit in engine.board.active_units(Unit.Side.HEROES):
		if unit.id != hero.id:
			mate = unit
			break
	return [hero, mate]


# --- La table --------------------------------------------------------------

func test_chaque_potion_pointe_sur_une_competence_qui_existe() -> void:
	assert_gt(Consumable.ids().size(), 0, "aucune potion déclarée")
	for item_id: StringName in Consumable.ids():
		var ability := Ability.of(Consumable.ability_of(item_id))
		assert_not_null(ability, "%s : compétence introuvable" % item_id)
		assert_true(ability.is_carried(), "%s doit être de classe consumable" % item_id)


func test_une_potion_ne_depend_de_personne() -> void:
	# UNE BOMBE LANCÉE PAR LE MAGE ET PAR LE GUERRIER FAIT LES MÊMES
	# DÉGÂTS. Sa puissance vient de l'objet, pas de qui le tient — sinon
	# il faudrait la réserver au personnage qui la valorise le mieux, et
	# le sac COMMUN du § 44 n'aurait plus de sens.
	for item_id: StringName in Consumable.ids():
		var ability := Ability.of(Consumable.ability_of(item_id))
		assert_true(
			ability.scaling.is_empty(), "%s monte à une statistique" % item_id
		)


func test_le_prix_suit_le_bareme() -> void:
	# ON NE SIMULE PAS MILLE COMBATS POUR UNE POTION. La règle qui
	# remplace la mesure : elle vaut ce qu'elle épargne, en points de vie,
	# et son prix suit.
	for item_id: StringName in Consumable.ids():
		var fair := Consumable.fair_price(item_id)
		var written := float(Consumable.price_of(item_id))
		var gap := absf(written - fair) / maxf(fair, 1.0)
		assert_lte(
			gap, Consumable.price_tolerance(),
			"%s : %d d'or pour un barème à %.0f" % [item_id, written, fair]
		)


func test_le_stock_de_depart_ne_contient_que_des_potions_connues() -> void:
	var stock := Consumable.starting_stock()
	assert_gt(Consumable.total(stock), 0, "une potion qu'on ne peut pas obtenir "
		+ "n'est pas une mécanique")
	for item_id: Variant in stock.keys():
		assert_true(Consumable.exists(StringName(item_id)), String(item_id))


func test_prendre_dans_un_sac_vide_echoue_sans_planter() -> void:
	var stock := {}
	assert_false(Consumable.take(stock, &"draught_of_mending"))
	Consumable.add(stock, &"draught_of_mending", 2)
	assert_true(Consumable.take(stock, &"draught_of_mending"))
	assert_eq(int(stock[&"draught_of_mending"]), 1)
	assert_true(Consumable.take(stock, &"draught_of_mending"))
	assert_false(stock.has(&"draught_of_mending"), "un compteur à zéro s'efface")


# --- Le soin ---------------------------------------------------------------

func test_le_soin_rend_des_points_de_vie_a_un_allie() -> void:
	# `KIND_HEAL` était déclaré depuis le premier jour et jamais écrit :
	# `resolve_ability` ne le lisait pas, et une compétence de soin aurait
	# silencieusement blessé les siens.
	var engine := _engine({&"draught_of_mending": 1})
	var actors := _actors(engine)
	var hero: Unit = actors[0]
	var mate: Unit = actors[1]
	mate.take_damage(50)
	var hurt := mate.hit_points
	var report := engine.use_consumable(hero, &"draught_of_mending", mate.cell)
	assert_false(report.is_empty(), "la potion doit se boire")
	assert_gt(mate.hit_points, hurt, "l'allié doit être soigné")


func test_le_soin_ne_blesse_pas_l_ennemi_qu_il_touche() -> void:
	var engine := _engine({&"draught_of_mending": 1})
	var hero: Unit = _actors(engine)[0]
	var foe := engine.board.unit_by_id(200)
	var before := foe.hit_points
	# Hors de portée : la potion ne part pas, et surtout elle ne blesse
	# personne au passage.
	engine.use_consumable(hero, &"draught_of_mending", foe.cell)
	assert_eq(foe.hit_points, before)


func test_un_soin_ne_depasse_pas_le_maximum() -> void:
	var engine := _engine({&"draught_of_mending": 1})
	var hero: Unit = _actors(engine)[0]
	hero.take_damage(5)
	engine.use_consumable(hero, &"draught_of_mending", hero.cell)
	assert_eq(hero.hit_points, hero.max_hit_points)


# --- Le sac ----------------------------------------------------------------

func test_boire_une_potion_la_retire_du_sac() -> void:
	var engine := _engine({&"draught_of_mending": 2})
	var hero: Unit = _actors(engine)[0]
	hero.take_damage(40)
	assert_false(engine.use_consumable(hero, &"draught_of_mending", hero.cell).is_empty())
	assert_eq(int(engine.supplies.get(&"draught_of_mending", 0)), 1)


func test_un_sac_vide_refuse_la_potion() -> void:
	var engine := _engine({&"draught_of_mending": 0})
	var hero: Unit = _actors(engine)[0]
	hero.take_damage(40)
	var before := hero.hit_points
	assert_true(engine.use_consumable(hero, &"draught_of_mending", hero.cell).is_empty())
	assert_eq(hero.hit_points, before, "rien ne doit se passer")


func test_annuler_rend_la_potion() -> void:
	# L'INVARIANT DE CETTE TÂCHE. « Rien n'est irréversible avant la fin
	# de l'activation » vaut aussi pour une potion bue — et si le compteur
	# vivait sur la Compagnie, l'instantané d'annulation ne le verrait pas
	# et la potion serait perdue pour de bon.
	var engine := _engine({&"draught_of_mending": 1})
	var hero: Unit = _actors(engine)[0]
	hero.take_damage(40)
	var hurt := hero.hit_points
	engine.use_consumable(hero, &"draught_of_mending", hero.cell)
	assert_eq(int(engine.supplies.get(&"draught_of_mending", 0)), 0)

	assert_true(engine.undo(), "l'annulation doit passer")
	assert_eq(
		int(engine.supplies.get(&"draught_of_mending", 0)), 1,
		"la potion doit revenir dans le sac"
	)
	assert_eq(hero.hit_points, hurt, "et le soin être défait")


func test_une_potion_refusee_reste_dans_le_sac() -> void:
	var engine := _engine({&"firebomb": 1})
	var hero: Unit = _actors(engine)[0]
	# Case hors de portée : la compétence refuse, et la potion ne doit pas
	# disparaître au passage.
	assert_true(engine.use_consumable(hero, &"firebomb", Vector2i(11, 8)).is_empty())
	assert_eq(int(engine.supplies.get(&"firebomb", 0)), 1)


func test_le_sac_survit_a_la_sauvegarde_du_combat() -> void:
	# Reprendre une bataille avec ses potions déjà bues serait pire que de
	# ne pas la reprendre.
	var engine := _engine({&"draught_of_mending": 2, &"firebomb": 1})
	var reloaded := CombatEngine.from_dictionary(engine.to_dictionary())
	assert_not_null(reloaded)
	assert_eq(int(reloaded.supplies.get(&"draught_of_mending", 0)), 2)
	assert_eq(int(reloaded.supplies.get(&"firebomb", 0)), 1)


func test_le_sac_de_la_compagnie_se_sauvegarde() -> void:
	var company := Company.new()
	company.supplies = {&"draught_of_mending": 3}
	var back := Company.from_dictionary(company.to_dictionary())
	assert_eq(int(back.supplies.get(&"draught_of_mending", 0)), 3)


func test_une_potion_disparue_des_donnees_ne_casse_pas_la_partie() -> void:
	var back := Company.from_dictionary({
		"gold": 0, "heroes": [], "stash": [],
		"supplies": {"elixir_de_jouvence": 4},
	})
	assert_eq(Consumable.total(back.supplies), 0)


# --- Ce que le personnage peut employer ------------------------------------

func test_on_ne_propose_que_les_potions_qu_on_peut_payer() -> void:
	var engine := _engine({&"draught_of_mending": 1, &"firebomb": 1})
	var hero: Unit = _actors(engine)[0]
	assert_eq(engine.usable_consumables(hero).size(), 2, "à plein, les deux")
	# Il ne reste plus de quoi lancer la bombe (3 PA) mais encore de quoi
	# boire (2 PA) : la barre doit le refléter, sinon le refus n'est
	# lisible qu'au moment de cliquer.
	hero.spend_action_points(hero.action_points - 2)
	var left := engine.usable_consumables(hero)
	assert_eq(left.size(), 1)
	assert_eq(left[0], &"draught_of_mending")


func test_le_philtre_rend_des_points_de_mouvement() -> void:
	var engine := _engine({&"philtre_of_haste": 1})
	var hero: Unit = _actors(engine)[0]
	hero.spend_movement_points(hero.movement_points)
	assert_eq(hero.movement_points, 0)
	engine.use_consumable(hero, &"philtre_of_haste", hero.cell)
	assert_gt(hero.movement_points, 0, "le philtre doit redonner de quoi bouger")


func test_un_ennemi_ne_touche_pas_au_sac() -> void:
	var engine := _engine({&"draught_of_mending": 1})
	var foe := engine.board.unit_by_id(200)
	assert_true(engine.use_consumable(foe, &"draught_of_mending", foe.cell).is_empty())
	assert_eq(int(engine.supplies.get(&"draught_of_mending", 0)), 1)
