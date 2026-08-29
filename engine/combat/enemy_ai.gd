class_name EnemyAI
extends RefCounted

## Décide, pour un ennemi, où il va et ce qu'il annonce.
##
## L'IA ne frappe jamais elle-même : elle produit un déplacement et une
## intention, et c'est le tour suivant qui exécute l'intention. C'est ce
## décalage qui fait le télégraphe du § 4.2, et il est structurel — l'IA
## n'a physiquement pas le moyen d'attaquer sans avoir prévenu.
##
## RÈGLE : toute décision est déterministe pour une graine donnée. Les
## égalités se départagent par identifiant d'unité, jamais par l'ordre
## d'un dictionnaire, et le hasard passe par `CombatRng`.

## Fonce au contact et frappe. La piétaille.
const ROLE_MELEE := &"melee"
## Tire de loin et recule si on l'approche.
const ROLE_SKIRMISHER := &"skirmisher"
## Tire de loin sans reculer.
const ROLE_RANGED := &"ranged"
## Ne bouge pas : il occupe le terrain.
const ROLE_BLOCKER := &"blocker"
## Lent, lourd, frappe en ligne.
const ROLE_BRUTE := &"brute"
## Vise une classe précise et l'atteint coûte que coûte.
const ROLE_ASSASSIN := &"assassin"

var _rng: CombatRng


func _init(rng: CombatRng = null) -> void:
	_rng = rng if rng != null else CombatRng.new(0)


## Plan d'un ennemi pour ce tour : { move_to, intent, target_id }.
## `move_to` vaut toujours une case légale — au pire celle de départ.
func plan(board: CombatBoard, unit: Unit, taunting: Array[int] = []) -> Dictionary:
	var empty := {
		"move_to": unit.cell, "intent": CombatIntent.none(unit.id), "target_id": -1,
	}
	if unit.is_downed():
		return empty

	var target := _choose_target(board, unit, taunting)
	if target == null:
		return empty

	var destination := _choose_cell(board, unit, target)

	# On simule le déplacement pour décider de l'intention depuis la case
	# d'arrivée : annoncer une attaque impossible serait un mensonge.
	var origin := unit.cell
	var moved := destination != origin and board.move_unit(unit, destination)
	var intent := _intent_from_here(board, unit, target)
	if moved:
		board.move_unit(unit, origin)

	return {"move_to": destination, "intent": intent, "target_id": target.id}


## Intention depuis la case OÙ L'UNITÉ SE TROUVE, sans rien déplacer.
##
## C'est ce qu'il faut à l'ouverture du combat : les ennemis sont posés par
## la carte et annoncent de là. Utiliser `plan()["intent"]` à ce moment-là
## donnerait des décalages calculés depuis une case d'arrivée où l'ennemi
## n'ira que le tour suivant — et le télégraphe désignerait des cases vides.
func intent_here(board: CombatBoard, unit: Unit, taunting: Array[int] = []) -> CombatIntent:
	if unit.is_downed():
		return CombatIntent.none(unit.id)
	var target := _choose_target(board, unit, taunting)
	if target == null:
		return CombatIntent.none(unit.id)
	return _intent_from_here(board, unit, target)


func _intent_from_here(board: CombatBoard, unit: Unit, target: Unit) -> CombatIntent:
	if not board.attackable_units(unit).has(target):
		return CombatIntent.none(unit.id)
	if unit.role == ROLE_BRUTE:
		return _line_intent(board, unit, target)
	return CombatIntent.attack_cell(unit.id, unit.cell, target.cell)


## Cible retenue. Ordre de préférence, du plus fort au plus faible :
## la classe que ce rôle vise, puis celle qu'on peut achever, puis la plus
## proche. L'identifiant tranche les égalités pour rester déterministe.
func _choose_target(board: CombatBoard, unit: Unit, taunting: Array[int]) -> Unit:
	var candidates := board.active_units(Unit.Side.HEROES)
	if candidates.is_empty():
		return null

	# Provocation (§ 3.1) : un ennemi ADJACENT à un provocateur n'a pas le
	# choix. C'est ce qui permet au Guerrier d'acheter un tour aux autres.
	if not taunting.is_empty():
		var forced: Unit = null
		for candidate: Unit in candidates:
			if not taunting.has(candidate.id):
				continue
			if board.grid.distance(unit.cell, candidate.cell) > 1:
				continue
			if forced == null or candidate.id < forced.id:
				forced = candidate
		if forced != null:
			return forced

	var preferred := StringName(Unit.enemy_stats(unit.class_id).get("prefers_class", ""))
	var best: Unit = null
	# -INF, pas -1 : le score d'une cible lointaine est négatif, et un
	# plancher à -1 rejetait silencieusement toutes les cibles à plus
	# d'une case. L'ennemi restait planté sans rien annoncer.
	var best_score := -INF
	for candidate: Unit in candidates:
		var score := 0.0
		if not preferred.is_empty() and candidate.class_id == preferred:
			score += 1000.0
		# Une cible qu'on peut mettre à terre ce tour-ci vaut mieux qu'une
		# cible qu'on entame.
		if candidate.hit_points <= unit.damage:
			score += 100.0
		score -= float(board.grid.distance(unit.cell, candidate.cell))
		score -= float(candidate.hit_points) * 0.1
		if score > best_score or (is_equal_approx(score, best_score) and _lower_id(candidate, best)):
			best_score = score
			best = candidate
	return best


## Case d'arrivée, selon le rôle.
func _choose_cell(board: CombatBoard, unit: Unit, target: Unit) -> Vector2i:
	if unit.role == ROLE_BLOCKER:
		return unit.cell

	var reachable := board.reachable_cells(unit)
	var origin := unit.cell
	var best := origin
	var best_score := -INF

	for cell: Vector2i in reachable.keys():
		var score := _score_cell(board, unit, target, cell)
		if score > best_score or (is_equal_approx(score, best_score) and _closer_to_origin(cell, best, origin)):
			best_score = score
			best = cell
	return best


func _score_cell(board: CombatBoard, unit: Unit, target: Unit, cell: Vector2i) -> float:
	var distance := board.grid.distance(cell, target.cell)
	var in_range := distance >= unit.range_min and distance <= unit.range_max
	var sees := not unit.is_ranged() or board.has_line_of_sight(cell, target.cell)
	var score := 0.0

	# Pouvoir frapper prime sur tout le reste.
	if in_range and sees:
		score += 1000.0
	else:
		# Sinon, se rapprocher de la portée utile.
		score -= float(absi(distance - unit.range_max)) * 10.0

	var tile := board.tile_at(cell)
	if tile != null:
		score += float(tile.ranged_damage_bonus() if unit.is_ranged() else 0)
		# La forêt protège de 1 dégât : à valeur égale, on s'y met.
		score -= float(tile.damage_taken_modifier())

	if unit.role == ROLE_SKIRMISHER:
		# Reculer : chaque héros au contact coûte cher.
		for hero: Unit in board.active_units(Unit.Side.HEROES):
			if board.grid.distance(cell, hero.cell) <= 1:
				score -= 50.0
		score += float(distance) * 0.5

	return score


## Attaque en ligne de la brute : la case de la cible et les suivantes,
## dans la même direction (§ 4.4, le Minotaure).
func _line_intent(board: CombatBoard, unit: Unit, target: Unit) -> CombatIntent:
	var length := int(Unit.enemy_stats(unit.class_id).get("line_attack", 1))
	var step := board.grid.direction(unit.cell, target.cell)
	if step == Vector2i.ZERO:
		return CombatIntent.none(unit.id)
	var offsets: Array[Vector2i] = []
	for i in range(1, length + 1):
		offsets.append(step * i)
	return CombatIntent.attack(unit.id, offsets)


func _lower_id(candidate: Unit, current: Unit) -> bool:
	return current == null or candidate.id < current.id


func _closer_to_origin(cell: Vector2i, current: Vector2i, origin: Vector2i) -> bool:
	var a := (cell - origin).abs()
	var b := (current - origin).abs()
	if a.x + a.y != b.x + b.y:
		return a.x + a.y < b.x + b.y
	# Départage stable : ordre de lecture de la grille.
	return cell.y < current.y or (cell.y == current.y and cell.x < current.x)
