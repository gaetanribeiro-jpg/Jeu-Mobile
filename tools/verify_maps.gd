extends SceneTree

## Vérifie que chaque carte de combat est jouable.
##
##     godot --headless --path . -s tools/verify_maps.gd
##
## Une carte écrite à la main est vite fausse : une case de départ dans
## l'eau, un objectif qui désigne une unité absente, une case à protéger
## qui n'est pas un décor destructible. Aucune de ces erreurs ne plante —
## elles rendent juste le combat impossible à gagner, ce qui se découvre
## bien plus tard et bien plus mal.

var _problems: Array[String] = []

## Cartes encore écrites pour l\'ancienne grille : une dette connue,
## pas un défaut. Elles sont jouables, elles ne sont plus au format.
var _to_rewrite: Array[String] = []


func _init() -> void:
	var ids := CombatMap.map_ids()
	print("Vérification de %d cartes de combat…\n" % ids.size())

	var width := int(CombatRules.rule(&"grid", &"combat_width", 0))
	var height := int(CombatRules.rule(&"grid", &"combat_height", 0))

	for id: StringName in ids:
		var map := CombatMap.load_map(id)
		if map == null:
			_problems.append("%s : ne se charge pas" % id)
			continue
		_check(map, width, height)

	if not _to_rewrite.is_empty():
		print("\nÀ réécrire pour la nouvelle grille (T1.10) : %d" % _to_rewrite.size())
		for line: String in _to_rewrite:
			print("  %s" % line)

	print("\nProblèmes : %d" % _problems.size())
	for line: String in _problems:
		print("  %s" % line)
	if _problems.is_empty():
		print("\nToutes les cartes sont jouables.")
		quit(0)
	else:
		quit(1)


func _check(map: CombatMap, width: int, height: int) -> void:
	var id := String(map.id)

	# La taille n'est pas un défaut, c'est une dette : les huit cartes ont
	# été écrites pour l'ancienne grille et attendent leur réécriture
	# (T1.10). Elles restent parfaitement jouables en attendant, donc on
	# les signale à part au lieu de faire rougir l'outil pour rien.
	if map.board.grid.width != width or map.board.grid.height != height:
		_to_rewrite.append("%s : grille %dx%d, la référence est %dx%d"
			% [id, map.board.grid.width, map.board.grid.height, width, height])

	if map.name_key.is_empty():
		_problems.append("%s : pas de clé de traduction" % id)
	elif TranslationServer.translate(map.name_key) == map.name_key:
		_problems.append("%s : la clé « %s » n'est pas traduite" % [id, map.name_key])

	# La zone de placement doit proposer PLUS de cases que le joueur n'a de
	# héros : c'est cet écart qui fait du placement une décision. Trop peu
	# et le choix disparaît, trop et il se dilue.
	var minimum := int(CombatRules.rule(&"deployment", &"cells_min", 6))
	var maximum := int(CombatRules.rule(&"deployment", &"cells_max", 10))
	var count := map.deployment_cells.size()
	if count < minimum:
		_problems.append("%s : %d cases de placement, %d au moins" % [id, count, minimum])
	if count > maximum:
		_problems.append("%s : %d cases de placement, %d au plus" % [id, count, maximum])
	if count <= CombatRules.max_heroes():
		_problems.append("%s : %d cases pour %d héros — aucun choix de placement"
			% [id, count, CombatRules.max_heroes()])

	var seen := {}
	for cell: Vector2i in map.deployment_cells:
		if not map.board.grid.contains(cell):
			_problems.append("%s : case de placement %s hors grille" % [id, cell])
			continue
		if seen.has(cell):
			_problems.append("%s : case de placement %s en double" % [id, cell])
		seen[cell] = true
		var tile := map.board.tile_at(cell)
		if not tile.is_walkable():
			_problems.append("%s : case de placement %s sur du « %s »"
				% [id, cell, tile.terrain_id])
		if tile.is_occupied():
			_problems.append("%s : case de placement %s déjà occupée" % [id, cell])

	var enemies := map.board.active_units(Unit.Side.ENEMIES)
	if enemies.is_empty():
		_problems.append("%s : aucun ennemi" % id)
	var max_enemies := int(CombatRules.rule(&"sides", &"max_enemies", 7))
	if enemies.size() > max_enemies:
		_problems.append("%s : %d ennemis, %d au plus" % [id, enemies.size(), max_enemies])

	_check_objective(map, id)


func _check_objective(map: CombatMap, id: String) -> void:
	var objective := map.objective
	for cell: Vector2i in objective.cells:
		if not map.board.grid.contains(cell):
			_problems.append("%s : case d'objectif %s hors grille" % [id, cell])

	for subject: int in objective.subject_ids:
		if map.board.unit_by_id(subject) == null:
			_problems.append("%s : l'objectif désigne l'unité %d, absente" % [id, subject])

	for cell: Vector2i in objective.protected_cells:
		var tile := map.board.tile_at(cell)
		if tile == null:
			_problems.append("%s : case protégée %s hors grille" % [id, cell])
		elif not tile.is_destructible():
			_problems.append("%s : case protégée %s est du « %s », qui ne peut pas être détruit"
				% [id, cell, tile.terrain_id])

	match objective.kind:
		CombatObjective.Kind.ESCORT:
			if objective.subject_ids.is_empty():
				_problems.append("%s : escorte sans escorté" % id)
			if objective.cells.is_empty():
				_problems.append("%s : escorte sans destination" % id)
		CombatObjective.Kind.SEIZE, CombatObjective.Kind.EXTRACT:
			if objective.cells.is_empty():
				_problems.append("%s : objectif sans case à atteindre" % id)
		CombatObjective.Kind.PROTECT:
			if objective.protected_cells.is_empty() and objective.subject_ids.is_empty():
				_problems.append("%s : protection sans rien à protéger" % id)
			if objective.turns <= 0:
				_problems.append("%s : protection sans durée" % id)
		CombatObjective.Kind.SURVIVE:
			var limit := int(CombatRules.rule(&"turns", &"max_rounds", 8))
			if objective.turns <= 0 or objective.turns > limit:
				_problems.append("%s : tenir %d rondes, hors des %d rondes visées"
					% [id, objective.turns, limit])
