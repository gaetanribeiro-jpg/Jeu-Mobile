extends GutTest

## Joue des combats entiers, jusqu'à la fin, sur toutes les cartes.
##
## Les tests unitaires vérifient chaque règle isolément. Celui-ci vérifie
## la seule chose qu'ils ne peuvent pas voir : qu'un combat SE TERMINE.
## Un moteur au tour par tour qui tourne en rond ne plante pas, il fige la
## partie — et c'est le genre de panne qu'on ne découvre qu'en jouant.
##
## Le « joueur » ici est une politique triviale : avancer vers l'ennemi le
## plus proche et vider ses PA dessus. Elle ne joue pas bien, et ce n'est
## pas le sujet.

const ACTIVATION_CAP := 200


func before_each() -> void:
	CombatRules.clear_cache()
	Unit.clear_cache()
	Ability.clear_cache()


func _squad() -> Array[Unit]:
	var wanted: Array = [&"warrior", &"archer", &"mage", &"warrior"]
	return Unit.squad_from_classes(wanted.slice(0, CombatRules.team_size()))


## Politique de joueur bête : le personnage que la timeline désigne avance
## vers l'ennemi le plus proche et vide ses PA dessus — sauf les unités que
## l'objectif charge d'aller quelque part, qui vont là-bas. Elle ne joue
## pas bien, et ce n'est pas le sujet : elle sert à faire avancer le
## combat jusqu'au bout.
func _play_activation(engine: CombatEngine, hero: Unit) -> void:
	var goal := _goal_for(engine, hero)
	if goal != Vector2i(-1, -1):
		_walk_toward(engine, hero, goal, 0)
		# Les PA ne se gardent pas d'une activation à l'autre : marcher vers
		# un objectif n'empêche pas de frapper ce qui barre la route. Sans
		# cette ligne, une carte à couloir se solde par une file de héros
		# bloqués derrière un gobelin qu'ils ne songent jamais à écarter.
		_spend_action_points(engine, hero)
		return

	var target := _nearest_enemy(engine, hero)
	if target == null:
		return
	if _best_ability(engine, hero, target) == null:
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


## La portée minimale la plus basse dont dispose ce personnage : c'est la
## distance à laquelle il doit s'arrêter d'avancer.
func _closest_range(hero: Unit) -> int:
	var closest := 99
	for ability_id: StringName in hero.abilities:
		var ability := Ability.of(ability_id)
		if ability != null and ability.is_attack():
			closest = mini(closest, ability.range_min)
	return closest if closest < 99 else 1


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
		engine.move(hero, best)


func _run(map_id: StringName, seed_value: int) -> Dictionary:
	var map := CombatMap.load_map(map_id, CombatRules.ADJACENCY_ORTHOGONAL)
	if map == null:
		return {}
	var engine := map.to_engine(_squad(), CombatRng.new(seed_value))
	engine.start()
	# Les simulations ne choisissent pas leur placement : ce serait une
	# stratégie de plus à écrire, et c'est justement la décision qu'on veut
	# laisser au joueur. On pose sur les premières cases libres.
	engine.auto_deploy()
	engine.begin_combat()
	var activations := 0
	while not engine.is_finished() and activations < ACTIVATION_CAP:
		var hero := engine.current_unit()
		if hero != null and hero.is_hero():
			_play_activation(engine, hero)
		engine.end_activation()
		activations += 1
	return {
		"finished": engine.is_finished(),
		"victory": engine.is_victory(),
		"rounds": engine.round_index(),
	}


func test_chaque_carte_declaree_se_charge() -> void:
	# LE COMPTE N'EST PLUS FIXÉ. Il valait 9 — les cartes de l'Acte I —
	# et l'acte 2 en a ajouté neuf : un test qui compte les cartes échoue
	# à chaque ajout de contenu sans que rien ne soit faux. Ce qui compte
	# est que CHACUNE se charge entière.
	var ids := CombatMap.map_ids()
	assert_gt(ids.size(), 9, "les deux actes, mini-boss et boss compris")
	for id: StringName in ids:
		var map := CombatMap.load_map(id, CombatRules.ADJACENCY_ORTHOGONAL)
		assert_not_null(map, String(id))
		if map != null:
			assert_not_null(map.objective, "%s : pas d'objectif" % id)
			assert_gt(
				map.deployment_cells.size(), CombatRules.max_heroes(),
				"%s : la zone de placement doit offrir un choix" % id
			)


func test_chaque_carte_va_jusqu_a_une_conclusion() -> void:
	var summary: Array[String] = []
	for id: StringName in CombatMap.map_ids():
		var result := _run(id, 1000)
		assert_true(
			result.get("finished", false),
			"%s ne se termine pas en %d activations" % [id, ACTIVATION_CAP]
		)
		summary.append("%s : %d rondes, %s" % [
			id, result["rounds"], "victoire" if result["victory"] else "défaite",
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
	# La propriété la plus importante du jeu, vérifiée sur chaque coup
	# porté de chaque carte : le chiffre qu'un ennemi annonce sur une case
	# est exactement le chiffre que cette case encaisse quand il frappe.
	#
	# La comparaison se fait PAR ATTAQUANT, et pas en additionnant tout ce
	# que le télégraphe affiche. Avec une timeline entremêlée, un ennemi
	# qui vient de jouer a déjà réannoncé pour sa PROCHAINE activation :
	# son annonce est visible à l'écran mais ne partira pas dans cette
	# fenêtre-ci. Additionner les deux reviendrait à tester la timeline, ce
	# que fait test_turn_order.gd, pas l'honnêteté du télégraphe.
	var checked := 0
	for id: StringName in CombatMap.map_ids():
		var map := CombatMap.load_map(id, CombatRules.ADJACENCY_ORTHOGONAL)
		var engine := map.to_engine(_squad(), CombatRng.new(555))
		engine.start()
		engine.auto_deploy()
		engine.begin_combat()

		var activations := 0
		while not engine.is_finished() and activations < ACTIVATION_CAP:
			var hero := engine.current_unit()
			if hero != null and hero.is_hero():
				_play_activation(engine, hero)

			# { attaquant → { case → dégâts annoncés } }
			var announced := {}
			for entry: Dictionary in engine.telegraph():
				var per_cell := {}
				var cells: Array = entry["cells"]
				for i in cells.size():
					per_cell[cells[i]] = int(entry["damage"][i])
				announced[int(entry["attacker_id"])] = per_cell

			for event: Dictionary in engine.end_activation():
				if String(event["event"]) != "attack_landed":
					continue
				var attacker_id := int(event["attacker_id"])
				var cell: Vector2i = event["cell"]
				assert_true(
					announced.has(attacker_id),
					"%s : le héros %d a frappé sans avoir rien annoncé"
						% [id, attacker_id]
				)
				var per_cell: Dictionary = announced.get(attacker_id, {})
				assert_true(
					per_cell.has(cell),
					"%s : l'ennemi %d a frappé une case qu'il n'avait pas annoncée"
						% [id, attacker_id]
				)
				assert_eq(
					int(event["damage"]), int(per_cell.get(cell, -1)),
					"%s : l'ennemi %d annonçait %s sur %s, il a infligé %d"
						% [id, attacker_id, per_cell.get(cell, -1), cell, int(event["damage"])]
				)
				checked += 1
			activations += 1
	assert_gt(checked, 0, "aucun coup n'a été porté, le test ne prouve rien")


func test_le_telegraphe_ne_ment_pas_sur_un_joueur_qui_ne_fait_rien() -> void:
	# Le test précédent ne contrôle que les coups qui partent, et pour
	# l'instant les héros expédient les ennemis avant qu'ils n'aient
	# l'occasion de frapper (c'est le déséquilibre de T1.11). Celui-ci
	# garantit qu'au moins un scénario met le télégraphe à l'épreuve : un
	# héros planté qui ne fait rien, et trois gobelins qui le trouvent.
	var board := CombatBoard.from_rows(PackedStringArray([
		"..........", "..........", "..........",
		"..........", "..........", "..........",
	]), CombatRules.ADJACENCY_ORTHOGONAL)
	var hero := Unit.from_hero_class(1, &"warrior", Vector2i(1, 2))
	hero.max_hit_points = 9999
	hero.hit_points = 9999
	board.place_unit(hero, hero.cell)
	for i in 3:
		var goblin := Unit.from_enemy(90 + i, &"spear_goblin", Vector2i(6, i + 1))
		board.place_unit(goblin, goblin.cell)

	var engine := CombatEngine.new(
		board, CombatObjective.from_dictionary({"kind": "eliminate"}), CombatRng.new(9)
	)
	engine.start()

	var landed := 0
	for activation in 40:
		if engine.is_finished():
			break
		var announced := {}
		for entry: Dictionary in engine.telegraph():
			var per_cell := {}
			var cells: Array = entry["cells"]
			for i in cells.size():
				per_cell[cells[i]] = int(entry["damage"][i])
			announced[int(entry["attacker_id"])] = per_cell

		for event: Dictionary in engine.end_activation():
			if String(event["event"]) != "attack_landed":
				continue
			var per_cell: Dictionary = announced.get(int(event["attacker_id"]), {})
			assert_eq(
				int(event["damage"]), int(per_cell.get(event["cell"], -1)),
				"l'ennemi %d n'a pas frappé comme il l'avait annoncé"
					% int(event["attacker_id"])
			)
			landed += 1
	assert_gt(landed, 0, "les gobelins n'ont jamais frappé")
