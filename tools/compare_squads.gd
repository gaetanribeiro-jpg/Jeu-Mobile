extends SceneTree

## Compare toutes les compositions d'escouade possibles.
##
##     godot --headless --path . -s tools/compare_squads.gd
##     godot --headless --path . -s tools/compare_squads.gd -- 10
##
## Trois emplacements et quatre classes, doublons autorisés, font vingt
## compositions. Cet outil les joue toutes sur les huit cartes et rend le
## taux de victoire de chacune.
##
## Il répond à LA question que pose la règle des trois emplacements : le
## choix est-il réel ? Si une composition gagne partout et les autres
## nulle part, il n'y a pas de choix, il y a une bonne réponse et dix-neuf
## erreurs. Si toutes se valent, il n'y a pas de choix non plus. Ce qu'on
## veut voir, c'est un étalement — des compositions fortes sur certaines
## cartes et faibles sur d'autres.
##
## La politique de joueur est triviale et n'utilise aucune capacité de
## classe : les chiffres sont donc un plancher, pas un verdict.

const TURN_CAP := 30


func _init() -> void:
	var runs := 5
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0 and arguments[0].is_valid_int():
		runs = maxi(1, arguments[0].to_int())

	var classes := Unit.hero_class_ids()
	var maps := CombatMap.map_ids()
	var compositions := _compositions(classes, CombatRules.squad_size())

	print("%d compositions × %d cartes × %d graines = %d combats\n"
		% [compositions.size(), maps.size(), runs,
		   compositions.size() * maps.size() * runs])
	print("%-34s %9s %8s" % ["composition", "victoires", "tours~"])
	print("-".repeat(54))

	var results: Array[Dictionary] = []
	for composition: Array in compositions:
		var wins := 0
		var turns := 0
		var total := 0
		for map_id: StringName in maps:
			for i in runs:
				var result := _run(map_id, composition, 500 + i * 7919)
				if result.is_empty():
					continue
				total += 1
				turns += int(result["turns"])
				if result["victory"]:
					wins += 1
		results.append({
			"label": _label(composition),
			"rate": 100.0 * float(wins) / float(maxi(total, 1)),
			"turns": float(turns) / float(maxi(total, 1)),
		})

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["rate"]) > float(b["rate"]))
	for entry: Dictionary in results:
		print("%-34s %8.0f%% %8.1f" % [entry["label"], entry["rate"], entry["turns"]])

	print("-".repeat(54))
	var best := float(results[0]["rate"])
	var worst := float(results[-1]["rate"])
	var flawless := 0
	for entry: Dictionary in results:
		if float(entry["rate"]) >= 95.0:
			flawless += 1

	print("Écart entre la meilleure et la pire : %.0f points." % (best - worst))
	print("Compositions qui gagnent presque toujours : %d sur %d."
		% [flawless, results.size()])

	# Ce qu'on cherche n'est pas un écart, c'est que peu de compositions
	# soient sans risque. Tant que la moitié gagne à tous les coups, le
	# choix n'engage à rien, quel que soit l'écart entre les extrêmes.
	if flawless * 2 > results.size():
		print("Plus de la moitié des compositions gagnent sans risque : le choix")
		print("n'engage à rien. C'est un symptôme d'ennemis trop faibles (T10.5),")
		print("pas de la règle des trois emplacements.")
	elif best - worst < 10.0:
		print("Trop resserré : toutes les compositions se valent, donc aucune")
		print("n'est un choix.")
	else:
		print("Étalement exploitable : les compositions ne se valent pas.")
	quit(0)


## Multiensembles de `size` classes parmi celles fournies — les doublons
## comptent, donc « 2 Guerriers + 1 Moine » est une composition à part.
func _compositions(classes: Array[StringName], size: int) -> Array:
	var out: Array = []
	_extend(classes, size, 0, [], out)
	return out


func _extend(classes: Array[StringName], size: int, start: int,
		current: Array, out: Array) -> void:
	if current.size() == size:
		out.append(current.duplicate())
		return
	for i in range(start, classes.size()):
		current.append(classes[i])
		_extend(classes, size, i, current, out)
		current.pop_back()


func _label(composition: Array) -> String:
	var counts := {}
	for class_id: StringName in composition:
		counts[class_id] = int(counts.get(class_id, 0)) + 1
	var parts: Array[String] = []
	for class_id: StringName in counts.keys():
		var count: int = counts[class_id]
		parts.append("%s%s" % ["%d " % count if count > 1 else "", class_id])
	return " + ".join(parts)


func _run(map_id: StringName, composition: Array, seed_value: int) -> Dictionary:
	var map := CombatMap.load_map(map_id)
	if map == null:
		return {}
	var engine := map.to_engine(
		Unit.squad_from_classes(composition), CombatRng.new(seed_value)
	)
	engine.start()
	# Les simulations ne choisissent pas leur placement : ce serait une
	# stratégie de plus à écrire, et c'est justement la décision qu'on veut
	# laisser au joueur. On pose sur les premières cases libres.
	engine.auto_deploy()
	engine.begin_combat()
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
