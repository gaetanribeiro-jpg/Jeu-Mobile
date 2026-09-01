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


## Le terrain : de l'herbe, les bâtiments bâtis, et la palissade.
static func _ground(kingdom: Kingdom, width: int, height: int) -> Array:
	var grid: Array[PackedStringArray] = []
	for row in height:
		var line := PackedStringArray()
		for column in width:
			line.append(String(CombatRules.terrain_property(&"grass", &"symbol", ".")))
		grid.append(line)

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

	var out: Array = []
	for line: PackedStringArray in grid:
		out.append("".join(line))
	return out


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
	for column in range(maxi(width - 3, 0), width):
		for row in height:
			free.append(Vector2i(column, row))
	if rng != null:
		free = rng.shuffled(free, &"defence_spawn")

	for i in mini(count, free.size()):
		var cell: Vector2i = free[i]
		out.append({"type": String(types[i % types.size()]), "cell": [cell.x, cell.y]})
	return out
