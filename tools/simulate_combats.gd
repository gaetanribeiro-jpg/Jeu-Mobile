extends SceneTree

## Simulateur de combats en masse — l'amorce de T10.2.
##
##     godot --headless --path . -s tools/simulate_combats.gd
##     godot --headless --path . -s tools/simulate_combats.gd -- 200
##
## Joue chaque carte sur N graines avec une politique de joueur triviale,
## et rend le taux de victoire et la durée moyenne. Les chiffres ne
## disent pas si une carte est bonne — la politique ne joue pas bien —
## mais ils disent si elle est jouable, si elle se termine, et de quel
## ordre de grandeur est sa durée. C'est ce qu'il faut pour repérer une
## carte impossible ou une carte qui se gagne toute seule.
##
## Le § 4.1 vise 3 à 6 tours. Une carte qui sort largement de cette
## fourchette est à revoir en T10.5.

const TURN_CAP := 30


func _init() -> void:
	var runs := 50
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0 and arguments[0].is_valid_int():
		runs = maxi(1, arguments[0].to_int())

	print("Simulation : %d graines par carte, politique de joueur triviale.\n" % runs)
	print("%-14s %8s %8s %8s %8s" % ["carte", "victoire", "tours~", "min", "max"])
	print("-".repeat(50))

	var total_turns := 0
	var total_runs := 0
	for id: StringName in CombatMap.map_ids():
		var wins := 0
		var turns_sum := 0
		var shortest := TURN_CAP + 1
		var longest := 0
		for i in runs:
			var result := _run(id, 1000 + i * 7919)
			if result.is_empty():
				continue
			if result["victory"]:
				wins += 1
			var turns: int = result["turns"]
			turns_sum += turns
			shortest = mini(shortest, turns)
			longest = maxi(longest, turns)
		var average := float(turns_sum) / float(runs)
		total_turns += turns_sum
		total_runs += runs
		print("%-14s %7d%% %8.1f %8d %8d"
			% [id, int(round(100.0 * wins / runs)), average, shortest, longest])

	print("-".repeat(50))
	print("Durée moyenne toutes cartes : %.1f tours (cible du § 4.1 : 3 à 6)"
		% (float(total_turns) / float(maxi(total_runs, 1))))
	quit(0)


func _squad() -> Array[Unit]:
	var wanted: Array = [&"warrior", &"archer", &"lancer", &"monk"]
	return Unit.squad_from_classes(wanted.slice(0, CombatRules.squad_size()))


func _run(map_id: StringName, seed_value: int) -> Dictionary:
	var map := CombatMap.load_map(map_id)
	if map == null:
		return {}
	var engine := map.to_engine(_squad(), CombatRng.new(seed_value))
	engine.start()
	var turns := 0
	while not engine.is_finished() and turns < TURN_CAP:
		_play_turn(engine)
		engine.end_player_turn()
		turns += 1
	return {"victory": engine.is_victory(), "turns": turns}


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
