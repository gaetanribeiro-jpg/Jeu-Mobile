extends GutTest

## T1.4 — la timeline d'initiative (§ 16).
##
## Ce que ces tests protègent : un seul combattant agit à la fois, alliés
## et ennemis entremêlés, et les égalités ne se tranchent jamais au hasard.


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()


func _unit(id: int, side: int, initiative: int) -> Unit:
	return Unit.from_stats(id, &"test", side, Vector2i.ZERO, {
		"hit_points": 10, "action_points": 6, "movement_points": 3,
		"initiative": initiative,
	})


func _hero(id: int, initiative: int) -> Unit:
	return _unit(id, Unit.Side.HEROES, initiative)


func _enemy(id: int, initiative: int) -> Unit:
	return _unit(id, Unit.Side.ENEMIES, initiative)


func test_la_plus_haute_initiative_joue_en_premier() -> void:
	var units: Array[Unit] = [_hero(1, 4), _enemy(2, 9), _hero(3, 6)]
	assert_eq(TurnOrder.sorted_ids(units), [2, 3, 1])


func test_la_timeline_entremele_les_deux_camps() -> void:
	# C'est LA différence avec l'ancien modèle : ce n'est pas « tout le
	# camp du joueur, puis tout le camp ennemi ».
	var units: Array[Unit] = [
		_hero(1, 8), _enemy(2, 9), _hero(3, 4), _enemy(4, 5),
	]
	var order := TurnOrder.sorted_ids(units)
	assert_eq(order, [2, 1, 4, 3])


func test_a_initiative_egale_le_heros_passe_avant() -> void:
	# Le joueur ne perd jamais un échange sur un tirage.
	var units: Array[Unit] = [_enemy(1, 5), _hero(2, 5)]
	assert_eq(TurnOrder.sorted_ids(units), [2, 1])


func test_a_egalite_complete_le_plus_petit_identifiant_gagne() -> void:
	var units: Array[Unit] = [_hero(3, 5), _hero(1, 5), _hero(2, 5)]
	assert_eq(TurnOrder.sorted_ids(units), [1, 2, 3])


func test_les_unites_tombees_ne_jouent_pas() -> void:
	var down := _hero(2, 9)
	down.down()
	var units: Array[Unit] = [_hero(1, 4), down]
	assert_eq(TurnOrder.sorted_ids(units), [1])


func test_une_ronde_fait_jouer_tout_le_monde_une_fois() -> void:
	var units: Array[Unit] = [_hero(1, 8), _enemy(2, 9), _hero(3, 4)]
	var order := TurnOrder.new()
	order.begin_round(units)
	assert_eq(order.round_index, 1)

	var seen: Array[int] = [order.current()]
	while true:
		var next := order.advance(units)
		if order.round_index != 1:
			break
		seen.append(next)
	assert_eq(seen, [2, 1, 3])


func test_la_ronde_suivante_s_ouvre_toute_seule() -> void:
	var units: Array[Unit] = [_hero(1, 5)]
	var order := TurnOrder.new()
	order.begin_round(units)
	assert_eq(order.round_index, 1)
	assert_eq(order.advance(units), 1, "le seul combattant rejoue")
	assert_eq(order.round_index, 2)


func test_l_ordre_est_recalcule_a_chaque_ronde() -> void:
	# Un bonus d'initiative doit se voir dès la ronde suivante, sinon il ne
	# sert à rien.
	var fast := _hero(1, 4)
	var slow := _enemy(2, 5)
	var units: Array[Unit] = [fast, slow]
	var order := TurnOrder.new()
	order.begin_round(units)
	assert_eq(order.current(), 2, "l'ennemi est le plus rapide")

	fast.initiative = 9
	order.advance(units)
	order.advance(units)
	assert_eq(order.round_index, 2)
	assert_eq(order.current(), 1, "le héros a pris la tête")


func test_une_unite_qui_tombe_perd_son_tour() -> void:
	var victim := _hero(3, 1)
	var units: Array[Unit] = [_hero(1, 9), _enemy(2, 5), victim]
	var order := TurnOrder.new()
	order.begin_round(units)
	assert_eq(order.current(), 1)

	victim.down()
	order.remove(victim.id)
	assert_eq(order.remaining(), [1, 2])
	order.advance(units)
	assert_eq(order.current(), 2)
	order.advance(units)
	assert_eq(order.round_index, 2, "la ronde s'achève sans le mort")


func test_retirer_une_unite_deja_jouee_ne_decale_pas_la_suite() -> void:
	var first := _hero(1, 9)
	var units: Array[Unit] = [first, _enemy(2, 5), _hero(3, 3)]
	var order := TurnOrder.new()
	order.begin_round(units)
	order.advance(units)
	assert_eq(order.current(), 2)
	first.down()
	order.remove(first.id)
	assert_eq(order.current(), 2, "on reste sur le même combattant")


func test_l_apercu_montre_qui_joue_maintenant_et_qui_suit() -> void:
	# Exigence explicite du § 16.
	var units: Array[Unit] = [_hero(1, 8), _enemy(2, 9), _hero(3, 4)]
	var order := TurnOrder.new()
	order.begin_round(units)
	assert_eq(order.preview(units, 3), [2, 1, 3])


func test_l_apercu_deborde_sur_la_ronde_suivante() -> void:
	# Sans ça, la timeline se viderait en fin de ronde et le joueur ne
	# verrait plus rien venir au pire moment.
	var units: Array[Unit] = [_hero(1, 8), _enemy(2, 9)]
	var order := TurnOrder.new()
	order.begin_round(units)
	order.advance(units)
	assert_eq(order.preview(units, 4), [1, 2, 1, 2])


func test_l_apercu_est_borne_a_ce_qu_on_demande() -> void:
	var units: Array[Unit] = [_hero(1, 8), _enemy(2, 9), _hero(3, 4)]
	var order := TurnOrder.new()
	order.begin_round(units)
	assert_eq(order.preview(units, 2).size(), 2)


func test_une_timeline_vide_ne_designe_personne() -> void:
	var units: Array[Unit] = []
	var order := TurnOrder.new()
	order.begin_round(units)
	assert_eq(order.current(), -1)
	assert_true(order.is_round_over())
	assert_null(order.current_unit())


func test_aller_retour_de_serialisation() -> void:
	var units: Array[Unit] = [_hero(1, 8), _enemy(2, 9), _hero(3, 4)]
	var order := TurnOrder.new()
	order.begin_round(units)
	order.advance(units)

	var copy := TurnOrder.from_dictionary(order.to_dictionary(), units)
	assert_eq(copy.round_index, order.round_index)
	assert_eq(copy.current(), order.current())
	assert_eq(copy.remaining(), order.remaining())
