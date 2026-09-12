extends SceneTree

## Compare toutes les compositions d'équipe possibles.
##
##     godot --headless --path . -s tools/compare_squads.gd
##     godot --headless --path . -s tools/compare_squads.gd -- 10
##
## Quatre emplacements et trois classes, doublons autorisés, font quinze
## compositions. Cet outil les joue toutes sur toutes les cartes et rend le
## taux de victoire de chacune.
##
## Il répond à la question que pose la composition d'équipe : le choix
## est-il réel ? Si une composition gagne partout et les autres nulle
## part, il n'y a pas de choix, il y a une bonne réponse et quatorze
## erreurs. Si toutes se valent, il n'y a pas de choix non plus. Ce qu'on
## veut voir, c'est un étalement — des compositions fortes sur certaines
## cartes et faibles sur d'autres.
##
## La colonne qui compte est « PV » : ce qu'il reste à l'équipe à la fin.
## Le taux de victoire seul ment — une escouade qui gagne tous ses combats
## à 95 % de PV et une autre qui les gagne à 70 % ne jouent pas au même
## jeu, et c'est la seconde qui rentrera à la maison en boitant.
##
## La politique de joueur est triviale : elle vide ses PA sur la cible la
## plus proche. Les chiffres sont un plancher, pas un verdict.

const TURN_CAP := 30


func _init() -> void:
	var runs := 5
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0 and arguments[0].is_valid_int():
		runs = maxi(1, arguments[0].to_int())

	var classes := Unit.hero_class_ids()
	var maps := CombatMap.map_ids()
	var compositions := _compositions(classes, CombatRules.team_size())

	print("%d compositions × %d cartes × %d graines = %d combats\n"
		% [compositions.size(), maps.size(), runs,
		   compositions.size() * maps.size() * runs])
	print("%-34s %9s %7s %6s" % ["composition", "victoires", "rondes", "PV"])
	print("-".repeat(60))

	var results: Array[Dictionary] = []
	for composition: Array in compositions:
		var wins := 0
		var turns := 0
		var health := 0.0
		var total := 0
		for map_id: StringName in maps:
			for i in runs:
				var result := _run(map_id, composition, 500 + i * 7919)
				if result.is_empty():
					continue
				total += 1
				turns += int(result["turns"])
				health += float(result["health"])
				if result["victory"]:
					wins += 1
		results.append({
			"label": _label(composition),
			"rate": 100.0 * float(wins) / float(maxi(total, 1)),
			"turns": float(turns) / float(maxi(total, 1)),
			"health": 100.0 * health / float(maxi(total, 1)),
		})

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["rate"]) > float(b["rate"]))
	for entry: Dictionary in results:
		print("%-34s %8.0f%% %7.1f %5.0f%%" % [
			entry["label"], entry["rate"], entry["turns"], entry["health"]
		])

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

	# Le taux de victoire ne suffit pas à juger : une rencontre du MVP est
	# faite pour être gagnée, le risque vit à l'échelle de l'expédition
	# (§ 29). Ce qu'on regarde, c'est ce que chaque composition PAIE.
	var cheapest := 0.0
	var dearest := 100.0
	for entry: Dictionary in results:
		cheapest = maxf(cheapest, float(entry["health"]))
		dearest = minf(dearest, float(entry["health"]))
	print("Écart de PV entre la composition la moins chère et la plus chère : %.0f points."
		% (cheapest - dearest))

	if cheapest - dearest < 5.0:
		print("Trop resserré : toutes les compositions coûtent la même chose,")
		print("donc aucune n'est un choix.")
	else:
		print("Les compositions ne se valent pas : il y a un choix à faire.")
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
	var activations := 0
	while not engine.is_finished() and activations < TURN_CAP:
		var hero := engine.current_unit()
		if hero != null and hero.is_hero():
			_play_activation(engine, hero)
		engine.end_activation()
		activations += 1
	var current := 0
	var maximum := 0
	for unit: Unit in engine.board.units():
		if not unit.is_hero():
			continue
		current += unit.hit_points
		maximum += unit.max_hit_points
	return {
		"victory": engine.is_victory(),
		"turns": engine.round_index(),
		"health": float(current) / float(maxi(maximum, 1)),
	}


## Le pilote automatique d'un personnage : il va vers son objectif s'il en
## a un, sinon il s'approche de l'ennemi le plus proche et vide ses PA
## dessus. Ce n'est pas une bonne stratégie, c'est une stratégie
## REPRODUCTIBLE — ce qu'il faut pour comparer deux réglages.
func _play_activation(engine: CombatEngine, hero: Unit) -> void:
	var goal := _goal_for(engine, hero)
	if goal != Vector2i(-1, -1):
		_walk_toward(engine, hero, goal, 0)
		# Les PA ne se gardent pas d'une activation à l'autre : marcher vers
		# un objectif n'empêche pas de frapper ce qui barre la route. Sans
		# cette ligne, une carte à couloir se solde par une file de héros
		# bloqués derrière un gobelin qu'ils ne songent jamais à écarter —
		# et l'outil mesure alors sa propre bêtise, pas la carte.
		_spend_action_points(engine, hero)
		return

	var target := _nearest_enemy(engine, hero)
	if target == null:
		return
	if not _can_hit(engine, hero, target):
		_walk_toward(engine, hero, target.cell, _closest_range(hero))
	_spend_action_points(engine, hero)


## Vide les PA du personnage sur l'ennemi le plus proche qu'il peut
## atteindre, la compétence la plus chère d'abord.
func _spend_action_points(engine: CombatEngine, hero: Unit) -> void:
	while true:
		var target := _nearest_reachable_enemy(engine, hero)
		if target == null:
			return
		var ability := _best_ability(engine, hero, target)
		if ability == null:
			return
		if engine.use_ability(hero, ability.id, target.cell).is_empty():
			return


func _nearest_enemy(engine: CombatEngine, hero: Unit) -> Unit:
	var best: Unit = null
	for candidate: Unit in engine.board.active_units(Unit.Side.ENEMIES):
		if best == null or engine.board.grid.distance(hero.cell, candidate.cell) \
				< engine.board.grid.distance(hero.cell, best.cell):
			best = candidate
	return best


## Le plus proche ennemi que ce personnage peut frapper là où il se tient.
func _nearest_reachable_enemy(engine: CombatEngine, hero: Unit) -> Unit:
	var best: Unit = null
	for candidate: Unit in engine.board.active_units(Unit.Side.ENEMIES):
		if _best_ability(engine, hero, candidate) == null:
			continue
		if best == null or engine.board.grid.distance(hero.cell, candidate.cell) \
				< engine.board.grid.distance(hero.cell, best.cell):
			best = candidate
	return best


## La compétence la plus chère que ce personnage peut porter maintenant.
func _best_ability(engine: CombatEngine, hero: Unit, target: Unit) -> Ability:
	var best: Ability = null
	for ability_id: StringName in hero.abilities:
		var ability := Ability.of(ability_id)
		if ability == null or not ability.is_attack():
			continue
		if not engine.can_use(hero, ability_id):
			continue
		if not engine.targetable_cells(hero, ability_id).has(target.cell):
			continue
		if best == null or ability.action_points > best.action_points:
			best = ability
	return best


func _can_hit(engine: CombatEngine, hero: Unit, target: Unit) -> bool:
	return _best_ability(engine, hero, target) != null


## La portée minimale la plus basse dont dispose ce personnage : c'est la
## distance à laquelle il doit s'arrêter d'avancer.
func _closest_range(hero: Unit) -> int:
	var closest := 99
	for ability_id: StringName in hero.abilities:
		var ability := Ability.of(ability_id)
		if ability != null and ability.is_attack():
			closest = mini(closest, ability.range_min)
	return closest if closest < 99 else 1


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
		engine.move(hero, best)
