class_name DefenceMap
extends RefCounted

## La bataille de défense du § 38 : « le terrain du royaume devient une
## carte de combat ».
##
## CETTE CARTE N'EXISTE DANS AUCUN FICHIER. Elle se fabrique à partir de ce
## que le joueur a bâti : plus le royaume est avancé, plus il y a de murs
## de pierre sur le plateau, et le même assaut ne se joue donc pas de la
## même façon selon ce qu'on a construit. C'est ce qui relie enfin les deux
## moitiés de la boucle par le TERRAIN, et pas seulement par des chiffres.
##
## ON PROTÈGE L'INTENDANT, PAS UN BÂTIMENT. L'IA ne vise que des unités —
## c'est ouvert depuis T1.12 — et un objectif « protéger une structure » ne
## pourrait donc jamais échouer. L'intendant est un villageois posté
## derrière tout le monde, et le protéger veut dire exactement ce que le
## § 38 demande : tenir la ligne.
##
## LES BÂTIMENTS NE SE CASSENT PAS. Le § 41 refuse la punition absolue, et
## regarder son monastère tomber pendant qu'on le défend serait exactement
## ça. La palissade, elle, se casse : elle donne aux assaillants un verbe
## autre que « contourner ».

const MAP_ID := &"kingdom_defence"

## Emplacement de chaque bâtiment sur le plateau de défense. Ils occupent
## le tiers gauche, derrière la palissade — c'est le royaume, vu du côté
## de celui qui l'attaque.
const SPOTS := {
	&"castle": Vector2i(2, 4),
	&"houses": Vector2i(1, 2),
	&"barracks": Vector2i(1, 6),
	&"archery": Vector2i(2, 1),
	&"monastery": Vector2i(2, 7),
}

## Colonne de la palissade, et les rangées qu'elle laisse ouvertes. Une
## palissade sans porte transformerait la carte en siège, et le § 38 veut
## une bataille : les assaillants doivent pouvoir entrer, au prix d'un
## goulot.
const FENCE_COLUMN := 4
const GATE_ROWS := [3, 4, 5]

## L'intendant se tient au fond, sur la rangée du château mais dans la
## colonne d'à côté : les décors de bâtiment débordent d'une demi-case de
## part et d'autre, et le château posé sur sa case le recouvrait.
const STEWARD_CELL := Vector2i(0, 4)

## Largeur du rivage des assaillants, en colonnes. C'est là qu'ils
## débarquent, et c'est la bande que le sol du royaume ne peut pas noyer
## (T12.15).
const SPAWN_COLUMNS := 3


## Fabrique la carte. `rng` sert au tirage des assaillants.
static func build(kingdom: Kingdom, raid: Invasion, rng: CombatRng) -> CombatMap:
	if kingdom == null or raid == null:
		return null
	var width := int(CombatRules.rule(&"grid", &"combat_width", 12))
	var height := int(CombatRules.rule(&"grid", &"combat_height", 9))

	var rows := _ground(kingdom, width, height)
	var data := {
		"name_key": "MAP_KINGDOM_DEFENCE",
		"act": 1,
		"rows": rows,
		"deployment_cells": _deployment(rows, width, height),
		# L'intendant emprunte la classe du Mage, comme le villageois de
		# vallee_05 : le pack ne fournit aucun PNJ non combattant, et
		# inventer une seconde convention pour le même manque coûterait
		# plus cher que de vivre avec la première.
		"allies": [{"type": "mage", "cell": [STEWARD_CELL.x, STEWARD_CELL.y]}],
		"enemies": _assault(raid, rng, width, height),
		"objective": {
			"kind": "protect",
			"turns": int(Invasion.number(&"assault", &"hold_rounds", 0.0)),
			"subject_ids": [CombatMap.ALLY_ID_BASE],
		},
	}
	return CombatMap.from_data(MAP_ID, data)


## Le terrain : LE SOL DU ROYAUME, les bâtiments bâtis, et la palissade.
##
## LE SOL VIENT DU ROYAUME DEPUIS T12.15, et c'est ce qui donne un sens à
## le façonner. Cette carte prenait les BÂTIMENTS du royaume et les posait
## sur douze colonnes d'herbe nue : le joueur pouvait élever une butte
## derrière sa porte sans que l'assaut ne la rencontre jamais. Ce qu'on
## façonne est maintenant ce sur quoi on se bat — § 43, chaque activité
## influence les autres, et par le TERRAIN cette fois.
##
## ON PREND LA FENÊTRE DE DROITE, pas celle de gauche. L'île fait quinze
## colonnes, la carte douze : c'est le côté par lequel l'assaut arrive
## qu'il faut montrer, donc les douze dernières colonnes. Prendre les
## premières aurait montré l'arrière-pays, que personne ne défend.
static func _ground(kingdom: Kingdom, width: int, height: int) -> Array:
	var grid: Array[PackedStringArray] = []
	var open := String(CombatRules.terrain_property(&"grass", &"symbol", "."))
	var island := kingdom.ground()
	var offset := maxi(KingdomGround.width() - width, 0)
	for row in height:
		var line := PackedStringArray()
		for column in width:
			line.append(_island_symbol(island, offset + column, row, open))
		grid.append(line)

	# LE TIERS GAUCHE RESTE PRATICABLE, QUOI QU'ON AIT CREUSÉ. C'est là que
	# le joueur se place et que l'intendant se tient : une mare tombée
	# dessus rendrait la bataille impossible à mettre en place, et
	# `verify_maps` ne voit pas une carte qui n'existe dans aucun fichier.
	# Façonner son royaume doit pouvoir compliquer sa défense, jamais
	# l'annuler.
	for row in height:
		for column in range(mini(FENCE_COLUMN + 1, width)):
			if not _walkable(grid[row][column]):
				grid[row][column] = open

	for building_id: StringName in SPOTS.keys():
		if kingdom.level_of(building_id) <= 0:
			continue
		var cell: Vector2i = SPOTS[building_id]
		if cell.x < width and cell.y < height:
			# Un terrain par bâtiment : un terrain ne porte qu'un décor, et
			# un seul type « bâtiment » les dessinait tous en château.
			grid[cell.y][cell.x] = String(CombatRules.terrain_property(
				StringName("building_%s" % building_id), &"symbol", "C"
			))

	for row in height:
		if GATE_ROWS.has(row) or FENCE_COLUMN >= width:
			continue
		grid[row][FENCE_COLUMN] = String(CombatRules.terrain_property(&"palisade", &"symbol", "p"))

	# LES ASSAILLANTS DOIVENT POUVOIR ARRIVER. Les trois dernières colonnes
	# sont leur rivage — `_assault` les y pose — et un joueur qui aurait
	# creusé tout le bord de son île les noierait avant le premier coup.
	# Ce n'est pas une défense, c'est une annulation, et le § 41 refuse
	# déjà l'inverse : on ne punit pas absolument, on ne gagne pas
	# absolument non plus.
	#
	# TROIS COLONNES, ET LE CHIFFRE SE LIT OÙ IL SERT. `SPAWN_COLUMNS` est
	# la même constante que `_assault` emploie : deux nombres écrits
	# séparément auraient fini par ne plus dire la même chose, et le jour
	# où ils divergent un assaillant apparaît dans un lac sans qu'une
	# seule erreur soit poussée.
	for row in height:
		for column in range(maxi(width - SPAWN_COLUMNS, 0), width):
			if not _walkable(grid[row][column]):
				grid[row][column] = open

	var out: Array = []
	for line: PackedStringArray in grid:
		out.append("".join(line))
	return out


## Le symbole d'une case de l'île, ou de l'herbe hors de ses bords.
##
## LES BÂTIMENTS DU ROYAUME NE VIENNENT PAS PAR LÀ. Le sol de l'île porte
## de l'herbe, de l'eau, du bois et des collines ; les bâtiments sont posés
## en PIXELS par `buildings.json`, pas en cases, et ils arrivent juste
## après par `SPOTS`. Confondre les deux poserait un château deux fois.
static func _island_symbol(
	island: PackedStringArray, column: int, row: int, fallback: String
) -> String:
	if row < 0 or row >= island.size():
		return fallback
	var line := island[row]
	if column < 0 or column >= line.length():
		return fallback
	return line[column]


static func _walkable(symbol: String) -> bool:
	var terrain := CombatRules.terrain_for_symbol(symbol)
	if terrain.is_empty():
		return false
	return bool(CombatRules.terrain_property(terrain, &"walkable", false))


## Les cases de placement : les deux colonnes qui précèdent la palissade.
## Le joueur choisit qui garde la porte et qui couvre le fond.
##
## PAS TOUT L'INTÉRIEUR. `verify_maps` plafonne les cases de placement, et
## il a raison : vingt-deux cases proposées ne sont pas vingt-deux
## décisions, c'est une décision noyée. Deux colonnes suffisent à opposer
## « devant la porte » à « en retrait ».
static func _deployment(rows: Array, width: int, height: int) -> Array:
	var out: Array = []
	var open_symbol := String(CombatRules.terrain_property(&"grass", &"symbol", "."))
	var first := maxi(FENCE_COLUMN - 2, 0)
	for row in range(1, maxi(height - 1, 1)):
		for column in range(first, mini(FENCE_COLUMN, width)):
			if String(rows[row])[column] == open_symbol:
				out.append([column, row])
	return out


## Les assaillants. Leur nombre se déduit de la force de l'assaut : c'est
## le même chiffre qui décide si l'armée s'en sort seule, donc les deux
## issues parlent de la même invasion.
static func _assault(raid: Invasion, rng: CombatRng, width: int, height: int) -> Array:
	var types: Array = Invasion.data().get("assault", {}).get("types", [])
	if types.is_empty():
		return []
	var cost := maxf(Invasion.number(&"assault", &"cost_per_enemy", 1.0), 1.0)
	var count := clampi(
		int(round(float(raid.strength) / cost)),
		int(Invasion.number(&"assault", &"min_enemies", 1.0)),
		int(Invasion.number(&"assault", &"max_enemies", 1.0))
	)

	var out: Array = []
	var free: Array[Vector2i] = []
	for column in range(maxi(width - SPAWN_COLUMNS, 0), width):
		for row in height:
			free.append(Vector2i(column, row))
	if rng != null:
		free = rng.shuffled(free, &"defence_spawn")

	for i in mini(count, free.size()):
		var cell: Vector2i = free[i]
		out.append({"type": String(types[i % types.size()]), "cell": [cell.x, cell.y]})
	return out
