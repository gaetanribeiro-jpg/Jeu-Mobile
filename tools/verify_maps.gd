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

	_check_decorations()
	_check_emplacements(ids)
	_check_vocabulary(ids)
	_check_reachable(ids)
	_check_defence_map()

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

	# La taille n'est pas un défaut, c'est une dette : les cartes ont
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

	# LA CASE DE DÉPART D'UN ENNEMI SE VÉRIFIE COMME CELLE D'UN HÉROS.
	# L'asymétrie était le trou : les cases de placement étaient contrôlées
	# depuis toujours, celles des ennemis jamais. Deux gnolls de
	# `vallee_09` se sont retrouvés PLANTÉS DANS UN ROCHER — ils voyaient
	# à travers rien, ne pouvaient pas y revenir, et l'outil disait « 0
	# problème ». Une carte fausse qui ne plante pas est exactement ce que
	# cet outil existe pour attraper.
	var occupied := {}
	for enemy: Unit in enemies:
		var cell := enemy.cell
		if not map.board.grid.contains(cell):
			_problems.append("%s : ennemi « %s » en %s, hors grille"
				% [id, enemy.class_id, cell])
			continue
		if occupied.has(cell):
			_problems.append("%s : deux ennemis sur la case %s" % [id, cell])
		occupied[cell] = true
		# ON DEMANDE AU PLATEAU, PAS À LA TUILE. `is_walkable()` répond
		# pour un fantassin ; un requin NAGE et une guêpe VOLE, et les
		# poser dans un lac est exactement ce que l'acte 3 fait. La
		# question n'est pas « la case est-elle de la terre » mais « cette
		# unité-là peut-elle s'y tenir ».
		var footing := map.board.tile_at(cell)
		if not map.board.can_stand_on(enemy, cell):
			_problems.append("%s : ennemi « %s » posé sur du « %s » en %s"
				% [id, enemy.class_id, footing.terrain_id, cell])

	_check_objective(map, id)


## UN ENNEMI QU'AUCUN HÉROS NE PEUT TOUCHER REND LA CARTE INGAGNABLE.
##
## L'acte 3 met des bêtes AQUATIQUES dans des lacs où aucun héros ne pose
## le pied. Un requin au corps à corps en sort pour mordre, donc il finit
## toujours à portée ; un harponneur en `ranged` n'a AUCUNE raison de
## bouger, et posé au milieu d'un lac il est intouchable pour une équipe
## sans portée. L'objectif « éliminer » ne se remplit alors jamais.
##
## LE CONTRÔLE EST DÉLIBÉRÉMENT GROSSIER : on demande qu'une case de terre
## touche l'ennemi, ce qui garantit qu'un Guerrier peut le frapper depuis
## le rivage. C'est plus strict que nécessaire — un tireur suffirait — et
## c'est voulu : le § 23 laisse la composition au joueur, et une carte ne
## doit pas la lui imposer.
##
## Les VOLANTS sont soumis à la même règle pour la même raison.
func _check_reachable(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		var map := CombatMap.load_map(id)
		if map == null or map.board == null:
			continue
		for enemy: Unit in map.board.active_units(Unit.Side.ENEMIES):
			if not (enemy.aquatic or enemy.flying):
				continue
			var touchable := false
			for step: Vector2i in [
				Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN
			]:
				var tile := map.board.tile_at(enemy.cell + step)
				if tile != null and tile.is_walkable():
					touchable = true
					break
			if not touchable:
				_problems.append(
					"%s : « %s » en %s ne touche aucune case de terre — "
					% [id, enemy.class_id, enemy.cell]
					+ "une équipe sans portée ne peut pas finir la carte."
				)


## UN ACTE QUI N'A QU'UN MOT DE VOCABULAIRE SE JOUE NEUF FOIS PAREIL.
##
## L'acte 2 est né avec du ROCHER et rien d'autre : sept cartes sur neuf
## n'employaient que lui, une avait du feu, une avait une colline. Rien ne
## s'en plaignait — chaque carte était jouable, mesurée, équilibrée. Mais
## « les Dunes ressemblent aux Terres Vertes » n'est pas un défaut qui se
## voit carte par carte, il se voit sur l'ACTE.
##
## Le seuil est bas exprès : il refuse l'acte MONOTONE, pas l'acte sobre.
## Trois terrains, c'est déjà une carte de rocher, une de relief et une
## d'obstacle destructible — de quoi poser trois questions différentes.
## UN EMPLACEMENT HORS DE PORTÉE N'EST PAS UN ENNEMI, C'EST DU DÉCOR.
##
## Une bête qui ne peut pas bouger — zéro PM — ne se rapprochera jamais.
## Si sa portée n'atteint aucune case de placement, elle ne tirera pas tant
## que le joueur ne sera pas venu à elle, et un joueur qui n'a aucune raison
## d'avancer n'ira nulle part. `fer_04` rendait 100 % des PV pour cette
## seule raison : trois canons posés au bord du plateau, à onze cases d'une
## équipe qu'ils atteignent à neuf.
##
## C'EST L'INVERSE DE LA LEÇON SUR LES OBSTACLES. Pour une bête mobile, la
## distance n'est qu'un délai — elle finit par arriver. Pour un
## emplacement, la distance est une ANNULATION.
func _check_emplacements(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		var map := CombatMap.load_map(id)
		if map == null or map.board == null or map.deployment_cells.is_empty():
			continue
		for unit: Unit in map.board.active_units(Unit.Side.ENEMIES):
			if unit.max_movement_points > 0:
				continue
			# UN SOUTIEN N'A PAS À TIRER : son métier est d'être derrière.
			# La règle ne vise que ce qui est censé faire mal.
			var reach := 0
			var armed := false
			for ability_id: StringName in unit.abilities:
				var ability := Ability.of(ability_id)
				if ability != null and ability.is_attack():
					armed = true
					reach = maxi(reach, ability.range_max)
			if not armed:
				continue
			var nearest := -1
			for cell: Vector2i in map.deployment_cells:
				var gap := map.board.grid.distance(unit.cell, cell)
				if nearest < 0 or gap < nearest:
					nearest = gap
			if nearest > reach:
				_problems.append(
					"%s : « %s » ne bouge pas et porte à %d, mais la zone de "
					% [id, unit.class_id, reach]
					+ "placement est à %d cases. Il ne tirera jamais." % nearest
				)


func _check_vocabulary(ids: Array[StringName]) -> void:
	var minimum := 3
	var per_act := {}
	for id: StringName in ids:
		var map := CombatMap.load_map(id)
		if map == null or map.board == null:
			continue
		var seen: Dictionary = per_act.get(map.act, {})
		for cell: Vector2i in map.board.grid.cells():
			var tile := map.board.tile_at(cell)
			if tile != null and tile.terrain_id != &"grass":
				seen[tile.terrain_id] = true
		per_act[map.act] = seen

	print("")
	for act: int in per_act.keys():
		var words: Dictionary = per_act[act]
		var names := PackedStringArray()
		for terrain_id: StringName in words.keys():
			names.append(String(terrain_id))
		names.sort()
		print("acte %d : %d terrains — %s" % [act, names.size(), ", ".join(names)])
		if names.size() < minimum:
			_problems.append(
				"acte %d : %d terrain(s) pour tout l'acte (%s) — il en faut %d. "
				% [act, names.size(), ", ".join(names), minimum]
				+ "Un acte qui n'a qu'un mot se joue neuf fois pareil."
			)


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


## Chaque décor de terrain doit exister dans la table des assets.
##
## POURQUOI ICI. Un décor qui pointe sur une image absente ne plante pas la
## carte : il pousse une erreur au moment de DESSINER, donc dans un test
## d'intégration ou à l'écran, jamais à l'endroit du problème. C'est arrivé
## avec la carte de défense — le royaume regroupe trois maisons sous un
## bâtiment « houses » que le pack ne dessine pas.
func _check_decorations() -> void:
	print("")
	for terrain_id: StringName in CombatRules.terrain_ids():
		var entry := ViewSettings.terrain_decoration(terrain_id)
		if entry.is_empty():
			continue
		var category := StringName(entry["category"])
		var key := StringName(entry["key"])
		var table := AssetTable.table().get(String(category), {}) as Dictionary
		if not table.has(String(key)):
			_problems.append("%s : décor « %s/%s » absent de la table des assets"
				% [terrain_id, category, key])


## La carte de défense du royaume (§ 38) ne vit dans aucun fichier : elle
## se fabrique. Elle doit donc être vérifiée là où on vérifie les autres,
## sinon elle est la seule carte du jeu que personne ne contrôle.
func _check_defence_map() -> void:
	var kingdom := Kingdom.create()
	for building_id: StringName in Buildings.ids():
		kingdom.levels[building_id] = 1
	var raid := Invasion.declare(CombatRng.new(1), kingdom.building_levels(), 0)
	var map := DefenceMap.build(kingdom, raid, CombatRng.new(1))
	if map == null:
		_problems.append("la carte de défense du royaume ne se construit pas")
		return
	print("carte de défense : %d cases de placement, %d assaillants"
		% [map.deployment_cells.size(), map.board.active_units(Unit.Side.ENEMIES).size()])
	_check(map, int(CombatRules.rule(&"grid", &"combat_width", 0)),
		int(CombatRules.rule(&"grid", &"combat_height", 0)))
