class_name CombatBoard
extends RefCounted

## Le plateau : la grille, les tuiles et les unités qui les occupent.
##
## Il répond aux quatre questions du combat qui ne dépendent que de l'état
## présent, sans rien décider du tour ni de l'IA :
##   C1.4 — où cette unité peut-elle aller ?
##   C1.5 — que peut-elle voir et atteindre ?
##   C1.6 — que se passe-t-il si elle frappe ici ?
##   C1.7 — où atterrit une unité qu'on pousse ?
##
## Aucun nœud, aucune valeur chiffrée : tout vient de `data/combat/`.
## La machine à états du tour (C1.8), le télégraphe (C1.9) et l'IA (C1.10)
## se poseront par-dessus.

var grid: Grid

var _tiles: Dictionary = {}
var _units: Dictionary = {}


func _init(board_grid: Grid) -> void:
	grid = board_grid
	for cell: Vector2i in grid.cells():
		_tiles[cell] = Tile.new(cell, &"grass")


## Plateau lu dans une carte écrite à la main : une ligne par rangée, un
## caractère par case, les symboles étant ceux de `terrain.json`.
## C'est ce que liront les cartes de combat en JSON (C1.26), et c'est ce
## qui rend les tests lisibles.
static func from_rows(rows: PackedStringArray, adjacency: String = "") -> CombatBoard:
	if rows.is_empty():
		push_error("CombatBoard : carte vide")
		return null
	var width := rows[0].length()
	for row: String in rows:
		if row.length() != width:
			push_error("CombatBoard : la carte n'est pas rectangulaire")
			return null

	var board := CombatBoard.new(Grid.new(width, rows.size(), adjacency))
	for y in rows.size():
		for x in width:
			var terrain := CombatRules.terrain_for_symbol(rows[y][x])
			if terrain.is_empty():
				return null
			board.tile_at(Vector2i(x, y)).set_terrain(terrain)
	return board


# --- Tuiles et unités ------------------------------------------------------

func tile_at(cell: Vector2i) -> Tile:
	return _tiles.get(cell, null)


func unit_by_id(unit_id: int) -> Unit:
	return _units.get(unit_id, null)


func unit_at(cell: Vector2i) -> Unit:
	var tile := tile_at(cell)
	if tile == null or not tile.is_occupied():
		return null
	return unit_by_id(tile.occupant_id)


func units() -> Array[Unit]:
	var out: Array[Unit] = []
	for unit: Unit in _units.values():
		out.append(unit)
	return out


## Unités encore debout, d'un camp donné.
func active_units(side: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for unit: Unit in _units.values():
		if unit.side == side and unit.is_active():
			out.append(unit)
	return out


## Pose une unité sur le plateau. Refuse une case occupée ou hors grille.
func place_unit(unit: Unit, at: Vector2i) -> bool:
	var tile := tile_at(at)
	if tile == null:
		push_error("CombatBoard : case %s hors grille" % at)
		return false
	if tile.is_occupied():
		push_error("CombatBoard : case %s déjà occupée" % at)
		return false
	_units[unit.id] = unit
	unit.cell = at
	tile.occupant_id = unit.id
	return true


## Retire une unité du plateau. Elle reste connue par son identifiant :
## un héros tombé garde son existence, il n'occupe simplement plus de case.
func remove_from_board(unit: Unit) -> void:
	var tile := tile_at(unit.cell)
	if tile != null and tile.occupant_id == unit.id:
		tile.clear_occupant()


## Déplace une unité d'une case à l'autre sans vérifier la légalité du
## chemin : c'est `reachable_cells` qui décide de ce qui est légal.
func move_unit(unit: Unit, to: Vector2i) -> bool:
	var destination := tile_at(to)
	if destination == null or destination.is_occupied():
		return false
	remove_from_board(unit)
	unit.cell = to
	destination.occupant_id = unit.id
	return true


# --- C1.4 : déplacement ----------------------------------------------------

## Cette unité peut-elle tenir sur cette case, terrain mis à part de
## l'occupation ? L'eau est infranchissable pour les héros et ouverte aux
## créatures aquatiques.
func can_stand_on(unit: Unit, cell: Vector2i) -> bool:
	var tile := tile_at(cell)
	if tile == null:
		return false
	# Le volant ignore le terrain : ni rocher, ni eau, ni forêt ne l'arrêtent.
	if unit.flying:
		return true
	if tile.is_swimmable() and unit.aquatic:
		return true
	return tile.is_walkable()


## Cette unité peut-elle traverser cette case sans s'y arrêter ?
func can_pass_through(unit: Unit, cell: Vector2i) -> bool:
	if not can_stand_on(unit, cell):
		return false
	var occupant := unit_at(cell)
	if occupant == null or occupant.id == unit.id:
		return true
	var key := &"pass_through_allies" if occupant.side == unit.side else &"pass_through_enemies"
	return bool(CombatRules.rule(&"movement", key, false))


## Cases où l'unité peut terminer son déplacement, avec leur coût.
## Parcours en largeur pondéré : { Vector2i → coût }. La case de départ
## est incluse au coût 0 — rester sur place est toujours légal.
func reachable_cells(unit: Unit) -> Dictionary:
	var costs := {unit.cell: 0}
	if unit.is_downed():
		return {}

	var frontier: Array[Vector2i] = [unit.cell]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = costs[current]
		for neighbor: Vector2i in grid.neighbors(current):
			if not can_pass_through(unit, neighbor):
				continue
			var step_cost: int = current_cost + tile_at(neighbor).move_cost()
			if step_cost > unit.movement:
				continue
			if costs.has(neighbor) and int(costs[neighbor]) <= step_cost:
				continue
			costs[neighbor] = step_cost
			frontier.append(neighbor)

	# Traverser n'est pas s'arrêter : on retire les cases occupées.
	var out := {}
	for cell: Vector2i in costs.keys():
		var occupant := unit_at(cell)
		if occupant != null and occupant.id != unit.id:
			continue
		out[cell] = costs[cell]
	return out


func can_move_to(unit: Unit, cell: Vector2i) -> bool:
	return reachable_cells(unit).has(cell)


# --- C1.5 : ligne de vue et portée ----------------------------------------

## La vue passe-t-elle de `from` à `to` ? Les deux extrémités ne comptent
## pas : une unité en forêt reste visible, mais on ne tire pas à travers
## la forêt qui la sépare d'un tireur.
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var path := grid.line(from, to)
	for i in range(1, path.size() - 1):
		var tile := tile_at(path[i])
		if tile != null and tile.blocks_sight():
			return false
	return true


## Portée maximale effective, colline comprise. Le bonus de la colline ne
## vaut que pour les unités à distance : un guerrier perché ne frappe pas
## plus loin.
func effective_range_max(unit: Unit) -> int:
	if not unit.is_ranged():
		return unit.range_max
	var tile := tile_at(unit.cell)
	var bonus := tile.ranged_range_bonus() if tile != null else 0
	return unit.range_max + bonus


## Cases que l'unité peut prendre pour cible depuis là où elle est.
func attackable_cells(unit: Unit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if unit.is_downed():
		return out
	for cell: Vector2i in grid.cells_in_range(
		unit.cell, unit.range_min, effective_range_max(unit)
	):
		if unit.is_ranged() and not has_line_of_sight(unit.cell, cell):
			continue
		out.append(cell)
	return out


## Cibles ennemies effectivement atteignables.
func attackable_units(unit: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for cell: Vector2i in attackable_cells(unit):
		var target := unit_at(cell)
		if target != null and target.is_active() and target.side != unit.side:
			out.append(target)
	return out


func can_attack(unit: Unit, target: Unit) -> bool:
	return attackable_units(unit).has(target)


# --- C1.6 : résolution d'une attaque --------------------------------------

## Dégâts qu'une attaque infligerait, sans rien appliquer.
##
## C'est cette fonction que lit le télégraphe : le joueur voit le chiffre
## exact avant que le coup ne parte, colline et forêt comprises. Elle doit
## donc rester la seule source du calcul — un télégraphe qui ment est pire
## qu'une absence de télégraphe.
func predicted_damage(attacker: Unit, target_cell: Vector2i) -> int:
	var total := attacker.damage

	var attacker_tile := tile_at(attacker.cell)
	if attacker_tile != null and attacker.is_ranged():
		total += attacker_tile.ranged_damage_bonus()

	var target_tile := tile_at(target_cell)
	if target_tile != null:
		total += target_tile.damage_taken_modifier()

	return maxi(total, 0)


## Applique une attaque. Renvoie le compte rendu du coup :
## { damage, target_id, downed, drowned }.
func resolve_attack(attacker: Unit, target: Unit) -> Dictionary:
	var damage := predicted_damage(attacker, target.cell)
	var downed := target.take_damage(damage)
	if downed:
		remove_from_board(target)
	attacker.has_acted = true
	return {
		"attacker_id": attacker.id,
		"target_id": target.id,
		"damage": damage,
		"downed": downed,
		"drowned": false,
	}


# --- C1.7 : poussée --------------------------------------------------------

## Où atterrirait une unité poussée, sans rien appliquer.
## Renvoie { destination, blocked, drowns, blocked_by }.
##
## Le télégraphe et la prévisualisation lisent cette fonction : le joueur
## doit voir la case d'arrivée avant de valider, y compris quand elle est
## dans l'eau.
func predict_push(unit: Unit, direction: Vector2i, distance: int) -> Dictionary:
	var destination := unit.cell
	var blocked := false
	var blocked_by := "" 

	for step in distance:
		var candidate := destination + direction
		if not grid.contains(candidate):
			blocked = true
			blocked_by = "edge"
			break
		var occupant := unit_at(candidate)
		if occupant != null and occupant.id != unit.id:
			blocked = true
			blocked_by = "unit"
			break
		var tile := tile_at(candidate)
		# Une case mortelle arrête la poussée en accueillant la victime :
		# c'est le but de la manœuvre, pas un obstacle.
		if tile.is_lethal() and not unit.aquatic:
			destination = candidate
			blocked = false
			blocked_by = ""
			break
		if not can_stand_on(unit, candidate):
			blocked = true
			blocked_by = "terrain"
			break
		destination = candidate

	var destination_tile := tile_at(destination)
	var drowns := (
		destination != unit.cell
		and destination_tile != null
		and destination_tile.is_lethal()
		and not unit.aquatic
	)
	return {
		"destination": destination,
		"blocked": blocked,
		"blocked_by": blocked_by,
		"drowns": drowns,
	}


## Pousse une unité. Renvoie le compte rendu, augmenté de `damage` et
## `downed`. Une poussée bloquée applique les dégâts de `rules.json`
## (zéro par défaut : le pousseur a gâché son coup).
func push(unit: Unit, direction: Vector2i, distance: int = -1) -> Dictionary:
	var steps := distance
	if steps < 0:
		steps = int(CombatRules.rule(&"push", &"distance", 1))

	var prediction := predict_push(unit, direction, steps)
	var destination: Vector2i = prediction["destination"]
	var report := prediction.duplicate()
	report["unit_id"] = unit.id
	report["from"] = unit.cell
	report["damage"] = 0
	report["downed"] = false

	if destination != unit.cell:
		move_unit(unit, destination)

	if bool(prediction["drowns"]):
		report["downed"] = unit.down()
		remove_from_board(unit)
		return report

	if bool(prediction["blocked"]):
		var blocked_damage := int(CombatRules.rule(&"push", &"blocked_damage", 0))
		if blocked_damage > 0:
			report["damage"] = blocked_damage
			report["downed"] = unit.take_damage(blocked_damage)
			if bool(report["downed"]):
				remove_from_board(unit)
	return report


## Pousse une unité en s'éloignant de `from`, dans la direction du coup.
func push_away_from(unit: Unit, from: Vector2i, distance: int = -1) -> Dictionary:
	return push(unit, grid.direction(from, unit.cell), distance)
