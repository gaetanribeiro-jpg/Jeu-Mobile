class_name Muster
extends RefCounted

## Le renfort d'un seul combat (T12.12) — l'option D de Gaetan.
##
## UNE VILLE ENVOIE UN BRAS, ET LE JOUEUR CHOISIT QUAND. Le milicien est
## acheté au DÉPART, sur la carte du monde, et dépensé sur UNE rencontre de
## la route. C'est la décision : le garder pour le boss, ou le dépenser sur
## la carte qui fait peur. La même forme que « rentrer ou continuer » du
## § 29, appliquée à un objet qu'on ne peut employer qu'une fois.
##
## IL NE VIOLE PAS LE § 23. L'équipe reste de quatre : le milicien est une
## unité ALLIÉE posée sur le plateau, exactement comme le villageois
## escorté de T12.6. La déclaration qu'une ville en fait a d'ailleurs la
## même forme qu'une entrée `allies` de carte — rien de neuf côté moteur.
##
## CLASSE PURE. Elle pose une unité sur un plateau ; c'est tout.

## Les identifiants d'alliés commencent haut pour ne croiser ni un héros ni
## un ennemi. Le milicien se range JUSTE AU-DESSUS des alliés de carte :
## une carte d'escorte qui en porte déjà un ne doit pas se le faire écraser.
const MUSTER_ID_BASE := 900


## Pose le milicien d'une ville sur un plateau, et le rend. Null si la
## ville n'en envoie pas, ou s'il n'y a pas de place.
##
## IL ARRIVE AVANT LE PLACEMENT, jamais après. Le § 39 veut l'information
## parfaite : le joueur doit pouvoir compter ses forces pendant qu'il
## décide où poser son équipe. Même règle que le renfort de nuit, par
## l'autre camp.
static func join(map: CombatMap, town_id: StringName) -> Unit:
	if map == null or map.board == null or not Neighbour.musters(town_id):
		return null
	var declared := Neighbour.muster_unit(town_id)
	if declared.is_empty():
		return null
	var cell := arrival_cell(map)
	if cell.x < 0:
		return null

	var unit := Unit.from_hero_class(
		_free_id(map.board), StringName(declared.get("type", "")), cell
	)
	if unit == null:
		return null
	# LE DESSIN SE DÉCLARE À PART DES STATISTIQUES (T11.8, T12.6). Un
	# milicien a les chiffres d'un Guerrier et le dessin d'un Pawn : ce
	# qu'on EST et ce qu'on MONTRE sont deux déclarations, et les confondre
	# a déjà donné sept ombres nues.
	if declared.has("sprite"):
		unit.sprite_id = StringName(declared["sprite"])
	if declared.has("sprite_variant"):
		unit.sprite_variant = String(declared["sprite_variant"])
	if declared.has("sprite_color"):
		unit.sprite_color = String(declared["sprite_color"])
	if declared.has("name_key"):
		unit.name_key = String(declared["name_key"])
	if not map.board.place_unit(unit, cell):
		return null
	return unit


## Où se pose le milicien : une case de placement LIBRE, sinon la case
## libre la plus proche d'elles.
##
## AVEC L'ÉQUIPE, PAS AU MILIEU DU PLATEAU. Un renfort lâché seul devant
## les lignes ennemies serait un cadeau empoisonné — il mourrait au premier
## tour et le joueur aurait payé pour perdre un tour d'ennemi. Il arrive
## là où l'équipe se pose, et c'est tout ce qu'on lui promet.
static func arrival_cell(map: CombatMap) -> Vector2i:
	if map == null or map.board == null:
		return Vector2i(-1, -1)
	for cell: Vector2i in map.deployment_cells:
		if _is_free(map.board, cell):
			return cell

	var best := Vector2i(-1, -1)
	var shortest := -1
	for cell: Vector2i in map.board.grid.cells():
		if not _is_free(map.board, cell):
			continue
		for anchor: Vector2i in map.deployment_cells:
			var reach := absi(cell.x - anchor.x) + absi(cell.y - anchor.y)
			if shortest < 0 or reach < shortest:
				shortest = reach
				best = cell
	return best


static func _is_free(board: CombatBoard, cell: Vector2i) -> bool:
	if board.unit_at(cell) != null:
		return false
	var tile := board.tile_at(cell)
	return tile != null and tile.is_walkable()


## Un identifiant qu'aucune unité du plateau ne porte. On part du socle des
## miliciens et on monte : deux unités qui le partageraient s'écraseraient.
static func _free_id(board: CombatBoard) -> int:
	var taken := {}
	for side in [Unit.Side.HEROES, Unit.Side.ENEMIES]:
		for unit: Unit in board.active_units(side):
			taken[unit.id] = true
	var candidate := MUSTER_ID_BASE
	while taken.has(candidate):
		candidate += 1
	return candidate
