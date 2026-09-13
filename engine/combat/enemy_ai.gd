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
## Se tient derrière les siens et les recoud. Il fuit le contact comme un
## tirailleur, mais ce qui le place n'est pas sa cible : c'est son blessé.
const ROLE_SUPPORT := &"support"

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
	if intent.kind == CombatIntent.Kind.NONE:
		# Rien à frapper : on regarde ce qui BARRE LA ROUTE.
		intent = _breach_intent(board, unit, target)
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
	var intent := _intent_from_here(board, unit, target)
	if intent.kind == CombatIntent.Kind.NONE:
		intent = _breach_intent(board, unit, target)
	return intent


## Compétences de l'unité, de la plus chère à la moins chère. L'ennemi
## annonce le coup le plus fort qu'il puisse porter : c'est ce qui rend le
## télégraphe utile — un chiffre bas ne vaudrait pas la peine d'être lu.
func _abilities_of(unit: Unit) -> Array[Ability]:
	return _sorted_by_cost(unit, func(ability: Ability) -> bool: return ability.is_attack())


## Les soins de l'unité, du plus cher au moins cher. Même ordre que les
## attaques et pour la même raison : on annonce le geste le plus fort.
func _mends_of(unit: Unit) -> Array[Ability]:
	return _sorted_by_cost(
		unit, func(ability: Ability) -> bool: return ability.kind == Ability.KIND_HEAL
	)


func _sorted_by_cost(unit: Unit, keep: Callable) -> Array[Ability]:
	var out: Array[Ability] = []
	for ability_id: StringName in unit.abilities:
		var ability := Ability.of(ability_id)
		if ability != null and keep.call(ability):
			out.append(ability)
	out.sort_custom(func(a: Ability, b: Ability) -> bool:
		if a.action_points != b.action_points:
			return a.action_points > b.action_points
		return a.id < b.id)
	return out


## Le soin qu'on peut porter depuis cette case, et à qui. Rend
## { ability, ally } ou {} — jamais un soin sur quelqu'un d'intact, sinon
## le soigneur passerait son tour à recoudre des gens qui vont bien.
##
## LA RÈGLE EST SOBRE, comme celle de la brèche : on recoud le plus
## blessé, point. Attendre le bon moment serait plus malin que le jeu n'a
## besoin, et surtout ça brouillerait la question posée au joueur — tant
## qu'il a entamé quelqu'un, ce soigneur le recoudra. C'est le `cooldown`,
## déclaré en données, qui borne la chose ; pas une ruse de l'IA.
## L'allié à qui il manque le plus. Les égalités se départagent par
## identifiant, comme partout ailleurs : l'IA doit rester déterministe.
func _most_wounded(board: CombatBoard, unit: Unit) -> Unit:
	var wounded: Unit = null
	var missing := 0
	for ally: Unit in board.active_units(unit.side):
		var lack := ally.max_hit_points - ally.hit_points
		if lack <= 0:
			continue
		if lack > missing or (lack == missing and _lower_id(ally, wounded)):
			missing = lack
			wounded = ally
	return wounded


func _best_mend_from(
	board: CombatBoard, unit: Unit, from: Vector2i, budget: int
) -> Dictionary:
	var wounded := _most_wounded(board, unit)
	if wounded == null:
		return {}

	for ability: Ability in _mends_of(unit):
		if ability.action_points > budget or not _is_available(unit, ability):
			continue
		if not ability.is_distance_in_range(board.grid.distance(from, wounded.cell)):
			continue
		if ability.needs_line_of_sight and not board.has_line_of_sight(from, wounded.cell):
			continue
		return {"ability": ability, "ally": wounded}
	return {}


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
		if not _is_available(unit, ability):
			continue
		if not ability.is_distance_in_range(distance):
			continue
		if ability.needs_line_of_sight and not board.has_line_of_sight(from, target.cell):
			continue
		return ability
	return null


## LE SOIN PASSE AVANT LE COUP, et c'est ce qui fait le rôle. Un soigneur
## qui frapperait tant qu'il a une cible à portée ne soignerait jamais :
## il en a toujours une. La hiérarchie est donc explicite, et elle vaut
## pour tout le monde — une bête qui porte un soin ET une attaque recoud
## d'abord.
func _intent_from_here(board: CombatBoard, unit: Unit, target: Unit) -> CombatIntent:
	var mend := _best_mend_from(board, unit, unit.cell, unit.max_action_points)
	if not mend.is_empty():
		var care: Ability = mend["ability"]
		var ally: Unit = mend["ally"]
		return CombatIntent.support_cell(unit.id, care.id, unit.cell, ally.cell)

	var ability := _best_ability_from(
		board, unit, target, unit.cell, unit.max_action_points
	)
	if ability == null:
		return CombatIntent.none(unit.id)
	return CombatIntent.attack_cell(unit.id, ability.id, unit.cell, target.cell)


## Frapper l'obstacle destructible qui barre la route, faute de mieux.
##
## OUVERT DEPUIS T1.12, ET C'EST LA PHASE 5 QUI LE FERMAIT. L'IA ne visait
## que des UNITÉS : un pont ne se cassait jamais tout seul, et un objectif
## « protéger une structure » ne pouvait donc pas échouer — une carte dont
## l'objectif ne peut pas être perdu n'est pas une carte. La défense du
## royaume (§ 38) rend le manque criant : une palissade que personne
## n'attaque n'est pas un mur, c'est une frontière.
##
## LA RÈGLE EST SOBRE, et c'est voulu : un ennemi qui n'a RIEN à frapper
## frappe ce qui le sépare de sa cible. Il ne casse jamais un décor quand
## il peut cogner quelqu'un — sinon les assaillants s'occuperaient du
## paysage pendant que le joueur les contourne.
##
## Parmi les obstacles à portée, il choisit le plus proche de sa cible :
## un assiégeant ouvre la brèche en face de ce qu'il veut atteindre, pas
## à l'autre bout de la palissade.
func _breach_intent(board: CombatBoard, unit: Unit, target: Unit) -> CombatIntent:
	var best_cell := Vector2i.ZERO
	var best_ability: Ability = null
	var best_distance := -1

	for ability: Ability in _abilities_of(unit):
		if ability.action_points > unit.max_action_points or not ability.is_attack():
			continue
		if not _is_available(unit, ability):
			continue
		for cell: Vector2i in board.targetable_cells(unit, ability):
			if board.breakable_cells(unit, ability, cell).is_empty():
				continue
			var distance := board.grid.distance(cell, target.cell)
			if best_distance < 0 or distance < best_distance:
				best_distance = distance
				best_cell = cell
				best_ability = ability
		if best_ability != null:
			# Les compétences sont rangées de la plus chère à la moins
			# chère : la première qui ouvre une brèche est la bonne.
			break

	if best_ability == null:
		return CombatIntent.none(unit.id)
	return CombatIntent.attack_cell(unit.id, best_ability.id, unit.cell, best_cell)


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
	# CE QUI PLACE UN SOIGNEUR N'EST PAS SA CIBLE, C'EST SON BLESSÉ, et il
	# lui faut donc son propre barème — pas un bonus ajouté à celui des
	# autres.
	#
	# LE BONUS AJOUTÉ NE SUFFISAIT PAS, ET C'EST MESURÉ : un aumônier n'a
	# aucune ATTAQUE, donc `_useful_range` vaut 1 et la retombée
	# « se rapprocher de la portée utile » le tirait au CONTACT, dix points
	# par case. Il est parti de (8,4) à (4,4), droit sur le Guerrier. Un
	# bonus constant de deux mille ne pèse rien contre une pente : les deux
	# cases pouvaient soigner, donc il ne les départageait pas.
	if unit.role == ROLE_SUPPORT:
		return _score_support_cell(board, unit, cell)

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


## Le barème d'un soigneur : pouvoir recoudre d'abord, se tenir loin
## ensuite, et à défaut rejoindre son blessé.
func _score_support_cell(board: CombatBoard, unit: Unit, cell: Vector2i) -> float:
	var score := 0.0
	if not _best_mend_from(board, unit, cell, unit.max_action_points).is_empty():
		score += 1000.0
	else:
		# Hors de portée de tout le monde : on se rapproche du plus blessé,
		# pas du héros le plus proche. C'est la seule pente qu'un soigneur
		# doit suivre.
		var patient := _most_wounded(board, unit)
		if patient != null:
			score -= float(board.grid.distance(cell, patient.cell)) * 10.0
	# Reculer, comme un tirailleur : sa portée ne sert à rien s'il meurt.
	var nearest := -1
	for hero: Unit in board.active_units(Unit.Side.HEROES):
		var gap := board.grid.distance(cell, hero.cell)
		if nearest < 0 or gap < nearest:
			nearest = gap
		if gap <= 1:
			score -= 50.0
	if nearest >= 0:
		score += float(nearest) * 0.5
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


## Ce que cet ennemi a le droit d'annoncer, maintenant.
##
## `requires_not_moved` ÉTAIT IGNORÉ PAR L'IA, et c'était un mensonge :
## `Ability.can_be_used` le refuse au joueur, mais l'ennemi choisissait sa
## compétence sans jamais le lire — il se serait déplacé PUIS aurait porté
## un coup réservé à qui reste planté. Personne ne s'en apercevait parce
## qu'aucune bête ne portait le champ, exactement comme `KIND_HEAL`,
## `KIND_PUSH` et les 70 entrées `ui` avant elles.
##
## L'ordre de l'activation lui donne son sens : l'ennemi ANNONCE après
## s'être déplacé. Un coup qui exige de n'avoir pas bougé ne s'annonce
## donc que depuis une bête qui s'est plantée — et le joueur le lit sur le
## télégraphe avant qu'il ne tombe.
func _is_available(unit: Unit, ability: Ability) -> bool:
	if not unit.is_ready(ability.id):
		return false
	if ability.requires_not_moved and unit.has_moved:
		return false
	return true


func _lower_id(candidate: Unit, current: Unit) -> bool:
	return current == null or candidate.id < current.id


func _closer_to_origin(cell: Vector2i, current: Vector2i, origin: Vector2i) -> bool:
	var a := (cell - origin).abs()
	var b := (current - origin).abs()
	if a.x + a.y != b.x + b.y:
		return a.x + a.y < b.x + b.y
	# Départage stable : ordre de lecture de la grille.
	return cell.y < current.y or (cell.y == current.y and cell.x < current.x)
