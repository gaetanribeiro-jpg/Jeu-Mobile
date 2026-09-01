extends GutTest

## Le cycle jour / nuit du § 36.
##
## Ce que ces tests protègent tient en une phrase : LA NUIT DOIT COÛTER ET
## PAYER. Chaque moitié prise seule est parfaitement cohérente — c'est ce
## qui rend l'oubli de l'autre indétectable autrement.


func before_each() -> void:
	DayNight.clear_cache()
	Region.clear_cache()
	CombatRules.clear_cache()
	Unit.clear_cache()


func after_all() -> void:
	DayNight.clear_cache()
	Region.clear_cache()
	CombatRules.clear_cache()
	Unit.clear_cache()


func _board() -> CombatBoard:
	var rows := PackedStringArray([
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
	])
	return CombatBoard.from_rows(rows, CombatRules.ADJACENCY_ORTHOGONAL)


func _deployment() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(2, 7):
		out.append(Vector2i(0, y))
	return out


# --- L'horloge -------------------------------------------------------------

func test_on_part_au_matin() -> void:
	assert_eq(DayNight.moment_at(0), &"day", "la première étape est de jour")


func test_la_journee_avance_avec_les_etapes() -> void:
	var seen: Array[StringName] = []
	for step in 6:
		var moment := DayNight.moment_at(step)
		if not seen.has(moment):
			seen.append(moment)
	assert_gt(seen.size(), 1, "l'heure doit changer, sinon il n'y a pas de cycle")
	assert_eq(seen[0], &"day", "la journée commence de jour")
	assert_eq(seen[seen.size() - 1], &"night", "et finit de nuit")


func test_la_derniere_heure_tient_au_dela_du_calendrier() -> void:
	# UNE ROUTE LONGUE NE REPART PAS AU MATIN. Faire tourner l'horloge
	# rendrait l'expédition la plus profonde PLUS SÛRE que la courte, ce
	# qui est l'inverse exact de ce que le § 29 demande.
	var last := DayNight.moment_at(DayNight.schedule().size() - 1)
	for step in range(DayNight.schedule().size(), DayNight.schedule().size() + 12):
		assert_eq(DayNight.moment_at(step), last, "étape %d" % step)


func test_une_etape_negative_ne_plante_pas() -> void:
	assert_eq(DayNight.moment_at(-3), &"day")


# --- Les deux moitiés ------------------------------------------------------

func test_la_nuit_coute() -> void:
	assert_gt(DayNight.reinforcements(&"night"), 0, "la nuit ajoute des ennemis")
	assert_eq(DayNight.reinforcements(&"day"), 0, "le jour n'en ajoute pas")


func test_la_nuit_paie() -> void:
	var night := DayNight.loot_bonus(&"night")
	var day := DayNight.loot_bonus(&"day")
	assert_gt(
		float(night["gold_multiplier"]), float(day["gold_multiplier"]),
		"la nuit rapporte plus d'or"
	)
	assert_gt(
		int(night["rarity_bonus"]), int(day["rarity_bonus"]),
		"la nuit rapporte du meilleur"
	)


func test_aucune_heure_ne_coute_sans_payer() -> void:
	# L'INVARIANT DU § 29, et il vaut plus que les deux tests au-dessus :
	# ils vérifient les valeurs d'aujourd'hui, celui-ci vérifie la règle.
	for moment: StringName in DayNight.moments():
		var bonus := DayNight.loot_bonus(moment)
		if DayNight.reinforcements(moment) <= 0:
			continue
		assert_true(
			float(bonus["gold_multiplier"]) > 1.0 or int(bonus["rarity_bonus"]) > 0,
			"« %s » ajoute des ennemis sans rien payer" % moment
		)


# --- Le renfort ------------------------------------------------------------

func test_le_jour_n_ajoute_personne() -> void:
	var board := _board()
	var added := DayNight.reinforce(
		board, &"day", [&"gnoll"] as Array[StringName], _deployment(), CombatRng.new(1)
	)
	assert_eq(added.size(), 0)
	assert_eq(board.active_units(Unit.Side.ENEMIES).size(), 0)


func test_la_nuit_ajoute_un_ennemi() -> void:
	var board := _board()
	var added := DayNight.reinforce(
		board, &"night", [&"gnoll"] as Array[StringName], _deployment(), CombatRng.new(1)
	)
	assert_eq(added.size(), 1, "un renfort")
	assert_eq(added[0].class_id, &"gnoll")
	assert_eq(board.active_units(Unit.Side.ENEMIES).size(), 1)


func test_le_renfort_arrive_par_le_fond() -> void:
	# Une bête qui sort du noir sort de DERRIÈRE. Posée à côté des héros,
	# la nuit deviendrait une embuscade, et le § 39 — information parfaite
	# — l'interdit : on doit pouvoir compter ses adversaires avant de poser
	# son équipe.
	var board := _board()
	var cells := _deployment()
	var added := DayNight.reinforce(
		board, &"night", [&"gnoll"] as Array[StringName], cells, CombatRng.new(7)
	)
	assert_eq(added.size(), 1)
	var closest := 99
	for start: Vector2i in cells:
		closest = mini(closest, board.grid.distance(added[0].cell, start))
	assert_gte(closest, board.grid.width - 2, "le renfort doit être au fond")


func test_le_renfort_rejoint_la_troupe() -> void:
	# LA RÈGLE PRINCIPALE, et elle a remplacé « le plus loin possible du
	# joueur ». Sur `vallee_05`, dont la zone de placement est au CENTRE,
	# la case la plus lointaine est un coin — le renfort apparaissait en
	# (0,0), DANS LE DOS de l'équipe. Une règle qui suppose que le joueur
	# se déploie sur un bord ne tient pas sur une carte où il se déploie
	# au milieu.
	var board := _board()
	var pack: Array[Vector2i] = [Vector2i(9, 3), Vector2i(9, 5), Vector2i(10, 4)]
	var id := 200
	for cell: Vector2i in pack:
		board.place_unit(Unit.from_enemy(id, &"gnome", cell), cell)
		id += 1

	var added := DayNight.reinforce(
		board, &"night", [&"thief"] as Array[StringName], _deployment(), CombatRng.new(11)
	)
	assert_eq(added.size(), 1)
	var arrival := added[0].cell

	var to_pack := 99
	for cell: Vector2i in pack:
		to_pack = mini(to_pack, board.grid.distance(arrival, cell))
	assert_lte(to_pack, 2, "le renfort doit se poser dans la formation, pas au loin")

	# Et jamais plus près du joueur que la bête la plus avancée : la nuit
	# ajoute du monde, elle ne tend pas une embuscade (§ 39).
	var frontline := 99
	for cell: Vector2i in pack:
		for start: Vector2i in _deployment():
			frontline = mini(frontline, board.grid.distance(cell, start))
	var arrival_reach := 99
	for start: Vector2i in _deployment():
		arrival_reach = mini(arrival_reach, board.grid.distance(arrival, start))
	assert_gte(arrival_reach, frontline, "le renfort ne double jamais la ligne")


func test_une_carte_a_horloge_ne_recoit_pas_de_renfort() -> void:
	# LA MESURE A IMPOSÉ CETTE RÈGLE. `vallee_04` demande trois cases en
	# six rondes ; l'ennemi de plus allonge le combat d'une demi-ronde et
	# le taux de réussite tombait de 100 % à 44 %. Ce n'est pas une nuit
	# plus dure, c'est une falaise : on ne perd pas un peu plus de PV, on
	# rate l'objectif ou on ne le rate pas.
	var board := _board()
	var timed := CombatObjective.from_dictionary({
		"kind": "seize", "cells": [[11, 4]], "deadline": 6,
	})
	var added := DayNight.reinforce(
		board, &"night", [&"thief"] as Array[StringName], _deployment(),
		CombatRng.new(1), timed
	)
	assert_eq(added.size(), 0, "la pression est déjà dans l'horloge")

	# Sans horloge, la même carte reçoit son renfort.
	var open_objective := CombatObjective.from_dictionary({"kind": "eliminate"})
	assert_eq(
		DayNight.reinforce(
			_board(), &"night", [&"thief"] as Array[StringName], _deployment(),
			CombatRng.new(1), open_objective
		).size(),
		1
	)


func test_le_renfort_vient_au_contact() -> void:
	# UN TIRAILLEUR N'EST PAS UN RENFORT. Le gnoll était le premier choix ;
	# il RECULE quand on l'approche, et `vallee_02` passait de 5,0 à 9,8
	# rondes les nuits où il sortait. Le combat ne devenait pas plus dur,
	# il devenait une poursuite — et le § 28 veut trois à huit rondes.
	for region_id: StringName in Region.ids():
		for enemy_id: StringName in Region.night_roster(region_id):
			var role := StringName(Unit.enemy_stats(enemy_id).get("role", ""))
			assert_ne(
				role, EnemyAI.ROLE_SKIRMISHER,
				"%s : « %s » recule, il allongerait le combat au lieu de le durcir"
					% [region_id, enemy_id]
			)


func test_le_renfort_ne_se_pose_pas_sur_une_case_occupee() -> void:
	var board := _board()
	var squatter := Unit.from_enemy(200, &"gnome", Vector2i(11, 8))
	board.place_unit(squatter, Vector2i(11, 8))
	var added := DayNight.reinforce(
		board, &"night", [&"gnoll"] as Array[StringName], _deployment(), CombatRng.new(3)
	)
	assert_eq(added.size(), 1)
	assert_ne(added[0].cell, squatter.cell, "deux unités sur une case")
	assert_ne(added[0].id, squatter.id, "deux unités sous le même identifiant")


func test_le_renfort_respecte_le_plafond_d_ennemis() -> void:
	# Trois cartes portent déjà six ennemis sur sept. Une bête de plus est
	# le maximum ; une de plus encore déborderait la timeline.
	var board := _board()
	var ceiling := int(CombatRules.rule(&"sides", &"max_enemies", 7))
	for i in ceiling:
		var filler := Unit.from_enemy(200 + i, &"gnome", Vector2i(11, i))
		board.place_unit(filler, Vector2i(11, i))
	var added := DayNight.reinforce(
		board, &"night", [&"gnoll"] as Array[StringName], _deployment(), CombatRng.new(5)
	)
	assert_eq(added.size(), 0, "le plafond tient")
	assert_eq(board.active_units(Unit.Side.ENEMIES).size(), ceiling)


func test_une_region_sans_renfort_ne_plante_pas() -> void:
	var board := _board()
	var added := DayNight.reinforce(
		board, &"night", [] as Array[StringName], _deployment(), CombatRng.new(1)
	)
	assert_eq(added.size(), 0)


func test_le_renfort_est_reproductible_a_graine_egale() -> void:
	# Règle 4 : un combat doit se rejouer à l'identique, renfort compris.
	var roster: Array[StringName] = [&"gnoll", &"thief"]
	var first := DayNight.reinforce(
		_board(), &"night", roster, _deployment(), CombatRng.new(4242)
	)
	var second := DayNight.reinforce(
		_board(), &"night", roster, _deployment(), CombatRng.new(4242)
	)
	assert_eq(first.size(), second.size())
	assert_eq(first[0].class_id, second[0].class_id)
	assert_eq(first[0].cell, second[0].cell)


func test_le_roster_de_la_region_existe_dans_le_bestiaire() -> void:
	for region_id: StringName in Region.ids():
		for enemy_id: StringName in Region.night_roster(region_id):
			assert_false(
				Unit.enemy_stats(enemy_id).is_empty(),
				"%s : renfort inconnu « %s »" % [region_id, enemy_id]
			)
