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

	print("Problèmes : %d" % _problems.size())
	for line: String in _problems:
		print("  %s" % line)
	if _problems.is_empty():
		print("\nToutes les cartes sont jouables.")
		quit(0)
	else:
		quit(1)


func _check(map: CombatMap, width: int, height: int) -> void:
	var id := String(map.id)

	if map.board.grid.width != width or map.board.grid.height != height:
		_problems.append("%s : grille %dx%d, attendu %dx%d"
			% [id, map.board.grid.width, map.board.grid.height, width, height])

	if map.name_key.is_empty():
		_problems.append("%s : pas de clé de traduction" % id)
	elif TranslationServer.translate(map.name_key) == map.name_key:
		_problems.append("%s : la clé « %s » n'est pas traduite" % [id, map.name_key])

	if map.hero_spawns.is_empty():
		_problems.append("%s : aucune case de départ" % id)
	var max_heroes := int(CombatRules.rule(&"sides", &"max_heroes", 4))
	if map.hero_spawns.size() > max_heroes:
		_problems.append("%s : %d cases de départ pour %d héros au plus"
			% [id, map.hero_spawns.size(), max_heroes])

	var seen := {}
	for cell: Vector2i in map.hero_spawns:
		if not map.board.grid.contains(cell):
			_problems.append("%s : case de départ %s hors grille" % [id, cell])
			continue
		if seen.has(cell):
			_problems.append("%s : deux héros partent de %s" % [id, cell])
		seen[cell] = true
		var tile := map.board.tile_at(cell)
		if not tile.is_walkable():
			_problems.append("%s : case de départ %s sur du « %s »" % [id, cell, tile.terrain_id])
		if tile.is_occupied():
			_problems.append("%s : case de départ %s déjà occupée" % [id, cell])

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
			var limit := int(CombatRules.rule(&"turns", &"max_turns", 6))
			if objective.turns <= 0 or objective.turns > limit:
				_problems.append("%s : tenir %d tours, hors des %d tours visés"
					% [id, objective.turns, limit])
