class_name DayNight
extends RefCounted

## Le cycle jour / nuit du § 36.
##
## UNE EXPÉDITION EST UNE JOURNÉE. On part au matin, et chaque étape
## franchie avance l'heure. Aller plus loin ne veut plus seulement dire
## « depth + 1 » : ça veut dire rentrer plus tard. C'est ce qui donne au
## § 29 sa formulation la plus concrète — rentrer avant la nuit, ou pas —
## et au § 36 le « véritable intérêt gameplay » qu'il réclame, puisque le
## moment cesse d'être un décor pour devenir un terme de la décision.
##
## DEUX MOITIÉS, ET IL EN FAUT DEUX. La nuit ajoute un ennemi et paie
## davantage. Livrer la première seule ferait une punition gratuite ;
## livrer la seconde seule, un cadeau gratuit. Dans les deux cas le § 29
## tombe, et le cycle ne serait qu'un filtre de couleur.
##
## LE MOMENT SE DÉDUIT, IL NE SE STOCKE PAS. Il est fonction de l'indice
## d'étape, donc une expédition sauvegardée le retrouve sans qu'on ait
## écrit quoi que ce soit — et une sauvegarde d'avant ce cycle se recharge
## sans conversion.
##
## CLASSE PURE : elle lit une table et rend des nombres. Le renfort est
## posé sur un `CombatBoard`, qui ne connaît pas Godot non plus.

const PATH := "res://data/world/day_night.json"

## Moment par défaut, quand rien n'est déclaré : le plein jour ne change
## rien à rien, c'est le seul repli qui ne fausse pas une mesure.
const DEFAULT_MOMENT := &"day"

## Sel du générateur dérivé qui tire les renforts. Constante technique :
## n'importe quelle valeur ferait l'affaire, seule compte sa stabilité.
const NIGHT_SALT := 0x4E49_4748

static var _data: Dictionary = {}


static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("DayNight : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("DayNight : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DayNight : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


## Le calendrier, moment par indice d'étape.
static func schedule() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Variant in data().get("schedule", []):
		out.append(StringName(entry))
	return out


## Les moments déclarés, dans l'ordre du calendrier puis de la table.
static func moments() -> Array[StringName]:
	var out: Array[StringName] = []
	for moment: StringName in schedule():
		if not out.has(moment):
			out.append(moment)
	for key: Variant in data().get("moments", {}).keys():
		var moment := StringName(key)
		if not out.has(moment):
			out.append(moment)
	return out


## Le moment d'une étape. LA DERNIÈRE VALEUR DU CALENDRIER TIENT au-delà
## de sa longueur : une chaîne plus longue que le calendrier finit dans le
## noir, elle ne repart pas au matin. Une expédition ne dure pas deux
## jours, et faire tourner l'horloge rendrait la route longue PLUS SÛRE
## que la courte — exactement l'inverse de ce que le § 29 demande.
static func moment_at(step_index: int) -> StringName:
	var days := schedule()
	if days.is_empty():
		return DEFAULT_MOMENT
	return days[clampi(step_index, 0, days.size() - 1)]


static func exists(moment: StringName) -> bool:
	return data().get("moments", {}).has(String(moment))


static func entry(moment: StringName) -> Dictionary:
	var table: Dictionary = data().get("moments", {})
	if not table.has(String(moment)):
		push_error("DayNight : moment « %s » inconnu" % moment)
		return {}
	return table[String(moment)]


static func name_key(moment: StringName) -> String:
	return String(entry(moment).get("name_key", ""))


## Combien d'ennemis la nuit ajoute à une rencontre.
static func reinforcements(moment: StringName) -> int:
	return maxi(int(entry(moment).get("reinforcements", 0)), 0)


## Ce que le moment fait au butin : { gold_multiplier, rarity_bonus }.
## `Loot` reste ignorant de l'heure — il reçoit un bonus, pas une horloge.
static func loot_bonus(moment: StringName) -> Dictionary:
	var block := entry(moment)
	return {
		"gold_multiplier": float(block.get("gold_multiplier", 1.0)),
		"rarity_bonus": int(block.get("rarity_bonus", 0)),
	}


## Ajoute les renforts de la nuit sur un plateau déjà construit, et rend
## les unités posées.
##
## LE RENFORT REJOINT LA LIGNE ENNEMIE. Il se pose près des bêtes déjà
## là, et JAMAIS plus près du joueur que la plus avancée d'entre elles.
## Poser un ennemi derrière l'équipe ferait de la nuit une embuscade, et
## le § 39 — information parfaite — l'interdit : le joueur doit pouvoir
## compter ses adversaires, et voir d'où ils viennent, avant de placer.
##
## LA PREMIÈRE RÈGLE ÉTAIT « LA CASE LA PLUS LOIN DU PLACEMENT », ET ELLE
## ÉTAIT FAUSSE. Sur `vallee_05`, dont la zone de placement est au CENTRE
## de la carte, la case la plus lointaine est un coin — et le renfort
## apparaissait en (0,0), dans le dos de l'équipe. Une règle qui suppose
## que le joueur se déploie sur un bord ne tient pas sur une carte où il
## se déploie au milieu.
##
## LE PLAFOND DE `rules.json` EST RESPECTÉ. Trois cartes ont déjà six
## ennemis sur sept ; une septième bête est le maximum, une huitième
## déborderait la timeline et le plateau.
##
## LE TIRAGE SE FAIT SUR UN GÉNÉRATEUR DÉRIVÉ, pas sur celui du combat.
## Tirer dans le flux du combat décalerait tous ses tirages suivants : la
## même carte, aux mêmes graines, ne se jouerait plus pareil de jour et de
## nuit, et la mesure de `simulate_combats` comparerait deux échantillons
## différents en croyant comparer deux réglages. Deux cartes en sortaient
## PLUS FACILES la nuit — du bruit qu'on aurait lu comme un résultat.
static func reinforce(
	board: CombatBoard, moment: StringName, roster: Array[StringName],
	deployment_cells: Array[Vector2i], rng: CombatRng,
	objective: CombatObjective = null
) -> Array[Unit]:
	var added: Array[Unit] = []
	if board == null or roster.is_empty():
		return added
	var wanted := reinforcements(moment)
	if wanted <= 0:
		return added
	# UNE CARTE À HORLOGE NE REÇOIT PAS DE RENFORT, et c'est la mesure qui
	# l'a imposé. `vallee_04` demande de tenir trois cases en six rondes ;
	# une bête de plus allonge le combat d'une demi-ronde, et le taux de
	# réussite est tombé de 100 % à 44 %. Ce n'est pas une nuit plus dure,
	# c'est une falaise : on ne perd pas un peu plus de PV, on rate
	# l'objectif ou on ne le rate pas.
	#
	# La règle qui en sort se dit en une ligne : LA PRESSION EST DÉJÀ DANS
	# L'HORLOGE. Une carte qui court n'a pas besoin qu'on lui ajoute du
	# monde ; les autres, si.
	if objective != null and objective.deadline > 0:
		return added

	var ceiling := int(CombatRules.rule(&"sides", &"max_enemies", 7))
	var draws := rng.derive(NIGHT_SALT) if rng != null else null
	for i in wanted:
		var present := board.active_units(Unit.Side.ENEMIES).size()
		if present >= ceiling:
			break
		var cell := _arrival_cell(board, deployment_cells)
		if cell.x < 0:
			break
		var enemy_id: StringName = roster[0]
		if draws != null:
			enemy_id = StringName(draws.pick(roster, &"night_roster"))
		var unit := Unit.from_enemy(_free_id(board), enemy_id, cell)
		if unit == null:
			break
		if not board.place_unit(unit, cell):
			break
		added.append(unit)
	return added


## La case d'arrivée : la plus proche de la troupe déjà en place, parmi
## celles qui ne sont pas plus près du joueur que l'ennemi le plus avancé.
##
## L'ordre de lecture de la grille départage les égalités. Un départage
## stable vaut mieux qu'un tirage : un renfort qui saute d'une case entre
## deux rechargements se remarque, et ferait douter de la sauvegarde.
static func _arrival_cell(
	board: CombatBoard, deployment_cells: Array[Vector2i]
) -> Vector2i:
	var enemies := board.active_units(Unit.Side.ENEMIES)
	# Sans troupe à rejoindre, on reprend la règle simple : le plus loin
	# possible du joueur. C'est le cas d'une carte vide, donc des tests.
	var frontline := -1
	for enemy: Unit in enemies:
		var reach := _distance_to_deployment(board, enemy.cell, deployment_cells)
		if frontline < 0 or reach < frontline:
			frontline = reach

	var best := Vector2i(-1, -1)
	var best_score := -1
	for y in board.grid.height:
		for x in board.grid.width:
			var cell := Vector2i(x, y)
			var tile := board.tile_at(cell)
			if tile == null or not tile.is_walkable() or tile.is_occupied():
				continue
			if deployment_cells.has(cell):
				continue
			var to_player := _distance_to_deployment(board, cell, deployment_cells)
			if frontline >= 0:
				if to_player < frontline:
					continue
				# AU MILIEU DE LA TROUPE, pas au bord. On somme les
				# distances à toutes les bêtes : le minimum tombe au centre
				# de la formation, là où le renfort est soutenu et où il
				# gêne. Se contenter de la bête la plus proche l'envoyait
				# se coller au premier venu — souvent celui du coin, où il
				# se faisait cueillir seul et n'ajoutait rien.
				var score := _pack_span(board) - _distance_to_pack(board, cell, enemies)
				if score > best_score:
					best_score = score
					best = cell
			elif to_player > best_score:
				best_score = to_player
				best = cell
	return best


## Plafond de la somme des distances, pour retourner le sens de la
## comparaison sans jamais passer sous zéro.
static func _pack_span(board: CombatBoard) -> int:
	var ceiling := int(CombatRules.rule(&"sides", &"max_enemies", 7))
	return (board.grid.width + board.grid.height) * (ceiling + 1)


## Somme des distances à toute la troupe. Le minimum est le centre de la
## formation.
static func _distance_to_pack(
	board: CombatBoard, cell: Vector2i, enemies: Array[Unit]
) -> int:
	var total := 0
	for enemy: Unit in enemies:
		total += board.grid.distance(cell, enemy.cell)
	return total


static func _distance_to_deployment(
	board: CombatBoard, cell: Vector2i, deployment_cells: Array[Vector2i]
) -> int:
	if deployment_cells.is_empty():
		return 0
	var closest := -1
	for start: Vector2i in deployment_cells:
		var distance := board.grid.distance(cell, start)
		if closest < 0 or distance < closest:
			closest = distance
	return closest


## Un identifiant que personne n'utilise sur ce plateau. Les cartes
## numérotent les ennemis à partir de `ENEMY_ID_BASE` ; un renfort qui
## réutiliserait un identifiant écraserait une unité dans la timeline.
static func _free_id(board: CombatBoard) -> int:
	var highest := CombatMap.ENEMY_ID_BASE - 1
	for unit: Unit in board.units():
		highest = maxi(highest, unit.id)
	return highest + 1
