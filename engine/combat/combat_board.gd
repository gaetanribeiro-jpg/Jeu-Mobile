class_name CombatBoard
extends RefCounted

## Le plateau : la grille, les tuiles et les unités qui les occupent.
##
## Il répond aux quatre questions du combat qui ne dépendent que de l'état
## présent, sans rien décider de la timeline ni de l'IA :
##   — jusqu'où cette unité peut-elle aller avec ses PM ?
##   — que peut-elle voir et viser avec telle compétence ?
##   — quelles cases cette compétence touche-t-elle, et pour combien ?
##   — où atterrit une unité qu'on pousse ?
##
## Aucun nœud, aucune valeur chiffrée : tout vient de `data/combat/`.
## La timeline (TurnOrder), le télégraphe et l'IA se posent par-dessus.

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


# --- Déplacement : les PM ----------------------------------------------------

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
	if occupant.side == unit.side:
		return CombatRules.pass_through_allies()
	return CombatRules.pass_through_enemies()


## Cases où l'unité peut terminer son déplacement, avec leur coût en PM.
##
## Parcours en largeur pondéré : { Vector2i → PM dépensés }. La case de
## départ est incluse au coût 0 — rester sur place est toujours légal.
## Le budget est ce qu'il RESTE de PM dans l'activation en cours, pas le
## maximum de l'unité : c'est ce qui permet d'avancer de deux cases,
## frapper, puis avancer encore (§ 14).
##
## `budget` force un autre budget que les PM courants. L'IA s'en sert pour
## se demander où elle pourrait aller avec le plein.
func reachable_cells(unit: Unit, budget: int = -1) -> Dictionary:
	var costs := {unit.cell: 0}
	if unit.is_downed():
		return {}
	var points := unit.movement_points if budget < 0 else budget

	var frontier: Array[Vector2i] = [unit.cell]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = costs[current]
		for neighbor: Vector2i in grid.neighbors(current):
			if not can_pass_through(unit, neighbor):
				continue
			var step_cost: int = (
				current_cost
				+ CombatRules.move_cost_per_cell() * tile_at(neighbor).move_cost()
			)
			if step_cost > points:
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


## Coût en PM pour rejoindre cette case, ou -1 si elle est hors d'atteinte.
func move_cost_to(unit: Unit, cell: Vector2i, budget: int = -1) -> int:
	var costs := reachable_cells(unit, budget)
	return int(costs[cell]) if costs.has(cell) else -1


# --- Ligne de vue, portée, zone ----------------------------------------

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


## Portée maximale d'une compétence depuis la case où se tient l'unité,
## colline comprise. Le bonus de la colline ne vaut que pour les
## compétences à distance : un guerrier perché ne frappe pas plus loin.
func effective_range_max(unit: Unit, ability: Ability) -> int:
	if ability.range_max <= 1:
		return ability.range_max
	var tile := tile_at(unit.cell)
	var bonus := tile.ranged_range_bonus() if tile != null else 0
	return ability.range_max + bonus


## Cases que cette compétence peut VISER depuis là où l'unité se tient.
## Ce n'est pas la même chose que les cases touchées : une Boule de foudre
## vise une case et en touche cinq.
func targetable_cells(unit: Unit, ability: Ability) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if unit.is_downed() or ability == null:
		return out
	if ability.targets_self():
		out.append(unit.cell)
		return out
	for cell: Vector2i in grid.cells_in_range(
		unit.cell, ability.range_min, effective_range_max(unit, ability)
	):
		if ability.needs_line_of_sight and not has_line_of_sight(unit.cell, cell):
			continue
		out.append(cell)
	return out


## Cette case est-elle un tir LÉGAL pour cette compétence ?
##
## Ce n'est pas la même question que « est-elle à portée » : la portée
## s'affiche (§ 17), le tir s'autorise. Une Frappe à portée d'une case
## vide reste dessinée en rouge — c'est l'allonge du personnage — mais
## elle ne part pas, parce qu'elle ne toucherait personne.
func can_target(unit: Unit, ability: Ability, cell: Vector2i) -> bool:
	if not targetable_cells(unit, ability).has(cell):
		return false
	if ability.needs_occupant() and affected_units(unit, ability, cell).is_empty():
		return false
	return true


## Cases effectivement TOUCHÉES si l'unité vise `target`. C'est ce que le
## HUD colore avant de valider (§ 18 : les zones doivent être très
## lisibles), et c'est ce que la résolution parcourt.
func affected_cells(unit: Unit, ability: Ability, target: Vector2i) -> Array[Vector2i]:
	if ability == null:
		return []
	return ability.area_cells(grid, unit.cell, target)


## Unités présentes dans la zone touchée.
##
## Sans `friendly_fire`, les alliés du lanceur sont épargnés — et le
## lanceur lui-même toujours. Avec, la Boule de feu brûle tout le monde :
## c'est ce qui donne du poids au positionnement (§ 20).
func affected_units(unit: Unit, ability: Ability, target: Vector2i) -> Array[Unit]:
	var out: Array[Unit] = []
	for cell: Vector2i in affected_cells(unit, ability, target):
		var occupant := unit_at(cell)
		if occupant == null or not occupant.is_active():
			continue
		if occupant.id == unit.id:
			continue
		if occupant.side == unit.side and not ability.friendly_fire:
			continue
		out.append(occupant)
	return out


## Cibles ennemies qu'une compétence peut atteindre depuis là où l'unité
## se tient, sans bouger.
func reachable_targets(unit: Unit, ability: Ability) -> Array[Unit]:
	var out: Array[Unit] = []
	for cell: Vector2i in targetable_cells(unit, ability):
		var target := unit_at(cell)
		if target != null and target.is_active() and target.side != unit.side:
			out.append(target)
	return out


## L'unité peut-elle frapper cette cible avec cette compétence, là, tout
## de suite ? Vérifie les PA et la recharge autant que la portée.
func can_use_on(unit: Unit, ability: Ability, target: Unit) -> bool:
	if ability == null or target == null or not target.is_active():
		return false
	if not ability.is_available_to(unit):
		return false
	return reachable_targets(unit, ability).has(target)


## Dégâts qu'une compétence infligerait à une unité, sans rien appliquer.
##
## C'est cette fonction que lit le télégraphe : le joueur voit le chiffre
## exact avant que le coup ne parte, colline et forêt comprises. Elle doit
## rester la seule source du calcul.
func predicted_damage(attacker: Unit, ability: Ability, target: Unit) -> int:
	return Damage.compute(
		attacker, ability, target, tile_at(attacker.cell), tile_at(target.cell)
	)


## Applique une compétence sur une case. Renvoie le compte rendu :
## { caster_id, ability, target, hits: [ { target_id, damage, downed,
## status } ], downed_ids }.
##
## Ne dépense NI les PA NI la recharge : c'est le moteur qui décide qu'une
## action a lieu, le plateau ne fait que l'appliquer. Cela permet à l'IA
## et au télégraphe de simuler sans consommer.
func resolve_ability(attacker: Unit, ability: Ability, target: Vector2i) -> Dictionary:
	var hits: Array[Dictionary] = []
	var downed_ids: Array[int] = []
	for victim: Unit in affected_units(attacker, ability, target):
		var amount := predicted_damage(attacker, ability, victim)
		var downed := victim.take_damage(amount)
		if not ability.status_id.is_empty():
			victim.apply_status(ability.status_id, ability.status_duration)
		if downed:
			remove_from_board(victim)
			downed_ids.append(victim.id)
		hits.append({
			"target_id": victim.id,
			"cell": victim.cell,
			"damage": amount,
			"downed": downed,
			"status": String(ability.status_id),
		})
	return {
		"caster_id": attacker.id,
		"ability": String(ability.id),
		"target": target,
		"cells": affected_cells(attacker, ability, target),
		"hits": hits,
		"downed_ids": downed_ids,
	}


# --- Poussée --------------------------------------------------------

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
