extends GutTest

## Joue des combats entiers, jusqu'à la fin, sur les huit cartes.
##
## Les tests unitaires vérifient chaque règle isolément. Celui-ci vérifie
## la seule chose qu'ils ne peuvent pas voir : qu'un combat SE TERMINE.
## Un moteur au tour par tour qui tourne en rond ne plante pas, il fige la
## partie — et c'est le genre de panne qu'on ne découvre qu'en jouant.
##
## Le « joueur » ici est une politique triviale : avancer vers l'ennemi le
## plus proche et frapper si possible. Elle ne joue pas bien, et ce n'est
## pas le sujet. C'est aussi l'amorce du simulateur de T10.2.

const TURN_CAP := 30


func before_each() -> void:
	CombatRules.reload()
	Unit.reload()
	Ability.reload()


func _squad() -> Array[Unit]:
	var out: Array[Unit] = []
	var id := 1
	for class_id: StringName in [&"warrior", &"archer", &"lancer", &"monk"]:
		out.append(Unit.from_hero_class(id, class_id, Vector2i.ZERO))
		id += 1
	return out


## Politique de joueur bête : chaque héros avance vers l'ennemi le plus
## proche et frappe s'il le peut — sauf les unités que l'objectif charge
## d'aller quelque part, qui vont là-bas. Elle ne joue pas bien, et ce
## n'est pas le sujet : elle sert à faire avancer le combat jusqu'au bout.
func _play_turn(engine: CombatEngine) -> void:
	for hero: Unit in engine.board.active_units(Unit.Side.HEROES):
		var goal := _goal_for(engine, hero)
		if goal != Vector2i(-1, -1):
			_walk_toward(engine, hero, goal, 0)
			continue

		var enemies := engine.board.active_units(Unit.Side.ENEMIES)
		if enemies.is_empty():
			return
		var target := enemies[0]
		for candidate: Unit in enemies:
			if engine.board.grid.distance(hero.cell, candidate.cell) \
					< engine.board.grid.distance(hero.cell, target.cell):
				target = candidate

		if not engine.board.can_attack(hero, target):
			_walk_toward(engine, hero, target.cell, hero.range_min)

		if engine.board.can_attack(hero, target):
			engine.attack(hero, target)


## Case que l'objectif demande à cette unité d'atteindre, ou (-1, -1).
func _goal_for(engine: CombatEngine, hero: Unit) -> Vector2i:
	var objective := engine.objective
	match objective.kind:
		CombatObjective.Kind.ESCORT:
			if objective.subject_ids.has(hero.id) and not objective.cells.is_empty():
				return objective.cells[0]
		CombatObjective.Kind.SEIZE:
			if not objective.cells.is_empty():
				return objective.cells[0]
		CombatObjective.Kind.EXTRACT:
			if not objective.carried:
				if not objective.pickup_cells.is_empty():
					return objective.pickup_cells[0]
			elif not objective.cells.is_empty():
				return objective.cells[0]
	return Vector2i(-1, -1)


func _walk_toward(engine: CombatEngine, hero: Unit, goal: Vector2i, keep: int) -> void:
	var best := hero.cell
	var best_distance := engine.board.grid.distance(hero.cell, goal)
	for cell: Vector2i in engine.board.reachable_cells(hero).keys():
		var distance := engine.board.grid.distance(cell, goal)
		if distance < best_distance and distance >= keep:
			best_distance = distance
			best = cell
	if best != hero.cell:
		engine.move_hero(hero, best)


func _run(map_id: StringName, seed_value: int) -> Dictionary:
	var map := CombatMap.load_map(map_id, CombatRules.ADJACENCY_ORTHOGONAL)
	if map == null:
		return {}
	var engine := map.to_engine(_squad(), CombatRng.new(seed_value))
	engine.start()
	var turns := 0
	while not engine.is_finished() and turns < TURN_CAP:
		_play_turn(engine)
		engine.end_player_turn()
		turns += 1
	return {"finished": engine.is_finished(), "victory": engine.is_victory(), "turns": turns}


func test_les_huit_cartes_se_chargent() -> void:
	var ids := CombatMap.map_ids()
	assert_eq(ids.size(), 8, "huit cartes de l'Acte I")
	for id: StringName in ids:
		var map := CombatMap.load_map(id, CombatRules.ADJACENCY_ORTHOGONAL)
		assert_not_null(map, String(id))
		if map != null:
			assert_not_null(map.objective, "%s : pas d'objectif" % id)
			assert_gt(map.hero_spawns.size(), 0, "%s : pas de case de départ" % id)


func test_chaque_carte_va_jusqu_a_une_conclusion() -> void:
	var summary: Array[String] = []
	for id: StringName in CombatMap.map_ids():
		var result := _run(id, 1000)
		assert_true(
			result.get("finished", false),
			"%s ne se termine pas en %d tours" % [id, TURN_CAP]
		)
		summary.append("%s : %d tours, %s" % [
			id, result["turns"], "victoire" if result["victory"] else "défaite",
		])
	gut.p("\n".join(summary))


func test_une_meme_graine_rejoue_le_meme_combat() -> void:
	# Règle 4 : c'est ce qui permettra de rejouer un bug à l'identique.
	for id: StringName in CombatMap.map_ids():
		var first := _run(id, 31337)
		var second := _run(id, 31337)
		assert_eq(first, second, "%s diverge d'une exécution à l'autre" % id)


func test_le_combat_ne_depend_pas_du_hasard() -> void:
	# Constat de la simulation, et il est conforme au deuxième pilier :
	# « Il perd parce qu'il a mal calculé, jamais parce qu'un dé lui a
	# menti. » Aucun tirage n'intervient dans un combat — ni les dégâts,
	# ni le choix de cible, ni le départage des égalités de l'IA. À
	# situation identique, la graine ne change rien.
	#
	# Le générateur n'est pas décoratif pour autant : il servira à la
	# Convocation, aux cartes d'événement et au butin, c'est-à-dire à la
	# couche campagne, où le hasard a sa place.
	#
	# Si ce test venait à échouer, ce ne serait pas une régression
	# technique mais une décision de design à assumer explicitement.
	for id: StringName in CombatMap.map_ids():
		var reference := _run(id, 1)
		for seed_value: int in [2, 3, 7, 11, 42, 99, 12345]:
			assert_eq(
				_run(id, seed_value), reference,
				"%s : la graine %d change le combat" % [id, seed_value]
			)


func test_le_telegraphe_ne_ment_jamais_sur_une_partie_entiere() -> void:
	# La propriété la plus importante du jeu, vérifiée à chaque tour de
	# chaque carte : ce que le télégraphe annonce sur une case est
	# exactement ce que cette case encaisse.
	for id: StringName in CombatMap.map_ids():
		var map := CombatMap.load_map(id, CombatRules.ADJACENCY_ORTHOGONAL)
		var engine := map.to_engine(_squad(), CombatRng.new(555))
		engine.start()
		var turns := 0
		while not engine.is_finished() and turns < TURN_CAP:
			_play_turn(engine)

			var announced := {}
			for hero: Unit in engine.board.active_units(Unit.Side.HEROES):
				announced[hero.id] = [engine.threat_on(hero.cell), hero.hit_points]

			engine.end_player_turn()

			for hero_id: int in announced.keys():
				var hero := engine.board.unit_by_id(hero_id)
				var expected: int = announced[hero_id][0]
				var before: int = announced[hero_id][1]
				var taken: int = before - hero.hit_points
				assert_eq(
					taken, expected,
					"%s tour %d : %d dégâts annoncés sur le héros %d, %d subis"
						% [id, turns + 1, expected, hero_id, taken]
				)
			turns += 1
