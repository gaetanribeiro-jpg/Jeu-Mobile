class_name EnemyAI
extends RefCounted

## Décide, pour un ennemi, quelle compétence il annonce, sur qui, et où il
## se place pour pouvoir la lancer.
##
## L'IA ne frappe jamais elle-même : elle produit un déplacement et une
## intention, et c'est l'activation suivante qui exécute l'intention.
## C'est ce décalage qui fait le télégraphe, et il est structurel — l'IA
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


## Plan d'un ennemi pour cette activation : { move_to, intent, target_id }.
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
## n'ira que plus tard — et le télégraphe désignerait des cases vides.
func intent_here(board: CombatBoard, unit: Unit, taunting: Array[int] = []) -> CombatIntent:
	if unit.is_downed():
		return CombatIntent.none(unit.id)
	var target := _choose_target(board, unit, taunting)
	if target == null:
		return CombatIntent.none(unit.id)
	return _intent_from_here(board, unit, target)


## Compétences de l'unité, de la plus chère à la moins chère. L'ennemi
## annonce le coup le plus fort qu'il puisse porter : c'est ce qui rend le
## télégraphe utile — un chiffre bas ne vaudrait pas la peine d'être lu.
func _abilities_of(unit: Unit) -> Array[Ability]:
	var out: Array[Ability] = []
	for ability_id: StringName in unit.abilities:
		var ability := Ability.of(ability_id)
		if ability != null and ability.is_attack():
			out.append(ability)
	out.sort_custom(func(a: Ability, b: Ability) -> bool:
		if a.action_points != b.action_points:
			return a.action_points > b.action_points
		return a.id < b.id)
	return out


## La meilleure compétence utilisable sur cette cible depuis cette case,
## ou null. `budget` est le nombre de PA supposé disponible : au moment de
## choisir une case, l'ennemi raisonne sur son plein, pas sur ce qui lui
## reste après le déplacement — les PM et les PA sont deux réserves
## distinctes (§ 13).
func _best_ability_from(
	board: CombatBoard, unit: Unit, target: Unit, from: Vector2i, budget: int
) -> Ability:
	var distance := board.grid.distance(from, target.cell)
	for ability: Ability in _abilities_of(unit):
		if ability.action_points > budget:
			continue
		if not unit.is_ready(ability.id):
			continue
		if not ability.is_distance_in_range(distance):
			continue
		if ability.needs_line_of_sight and not board.has_line_of_sight(from, target.cell):
			continue
		return ability
	return null


func _intent_from_here(board: CombatBoard, unit: Unit, target: Unit) -> CombatIntent:
	var ability := _best_ability_from(
		board, unit, target, unit.cell, unit.max_action_points
	)
	if ability == null:
		return CombatIntent.none(unit.id)
	return CombatIntent.attack_cell(unit.id, ability.id, unit.cell, target.cell)


## Dégâts que cet ennemi peut espérer porter à cette cible, au mieux.
## Sert à repérer une cible qu'on peut mettre à terre d'un coup.
func _best_damage_on(board: CombatBoard, unit: Unit, target: Unit) -> int:
	var best := 0
	for ability: Ability in _abilities_of(unit):
		best = maxi(best, board.predicted_damage(unit, ability, target))
	return best


## Cible retenue. Ordre de préférence, du plus fort au plus faible :
## la classe que ce rôle vise, puis celle qu'on peut achever, puis la plus
## proche. L'identifiant tranche les égalités pour rester déterministe.
func _choose_target(board: CombatBoard, unit: Unit, taunting: Array[int]) -> Unit:
	var candidates := board.active_units(Unit.Side.HEROES)
	if candidates.is_empty():
		return null

	# Provocation : un ennemi ADJACENT à un provocateur n'a pas le choix.
	# C'est ce qui permet au Guerrier d'acheter un tour aux autres.
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
		# Une cible qu'on peut mettre à terre maintenant vaut mieux qu'une
		# cible qu'on entame.
		if candidate.hit_points <= _best_damage_on(board, unit, candidate):
			score += 100.0
		score -= float(board.grid.distance(unit.cell, candidate.cell))
		score -= float(candidate.hit_points) * 0.01
		if score > best_score or (is_equal_approx(score, best_score) and _lower_id(candidate, best)):
			best_score = score
			best = candidate
	return best


## Case d'arrivée, selon le rôle. Le budget est ce qu'il reste de PM.
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
	var ability := _best_ability_from(board, unit, target, cell, unit.max_action_points)
	var score := 0.0

	# Pouvoir frapper prime sur tout le reste.
	if ability != null:
		score += 1000.0
		# À portée égale, le coup le plus fort.
		score += float(board.predicted_damage(unit, ability, target)) * 0.1
	else:
		# Sinon, se rapprocher de la portée utile de la meilleure
		# compétence dont on dispose.
		score -= float(absi(distance - _useful_range(unit))) * 10.0

	var tile := board.tile_at(cell)
	if tile != null:
		if _is_ranged(unit):
			score += float(tile.ranged_damage_bonus())
		# La forêt protège : à valeur égale, on s'y met.
		score -= float(tile.damage_taken_modifier())

	if unit.role == ROLE_SKIRMISHER:
		# Reculer : chaque héros au contact coûte cher.
		for hero: Unit in board.active_units(Unit.Side.HEROES):
			if board.grid.distance(cell, hero.cell) <= 1:
				score -= 50.0
		score += float(distance) * 0.5

	return score


## Portée maximale que cet ennemi sait exploiter, toutes compétences
## confondues. C'est vers là qu'il se rapproche quand il ne peut pas
## frapper.
func _useful_range(unit: Unit) -> int:
	var best := 1
	for ability: Ability in _abilities_of(unit):
		best = maxi(best, ability.range_max)
	return best


func _is_ranged(unit: Unit) -> bool:
	return _useful_range(unit) > 1


func _lower_id(candidate: Unit, current: Unit) -> bool:
	return current == null or candidate.id < current.id


func _closer_to_origin(cell: Vector2i, current: Vector2i, origin: Vector2i) -> bool:
	var a := (cell - origin).abs()
	var b := (current - origin).abs()
	if a.x + a.y != b.x + b.y:
		return a.x + a.y < b.x + b.y
	# Départage stable : ordre de lecture de la grille.
	return cell.y < current.y or (cell.y == current.y and cell.x < current.x)
