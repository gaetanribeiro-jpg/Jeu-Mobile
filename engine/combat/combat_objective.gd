class_name CombatObjective
extends RefCounted

## L'objectif d'un combat, et le seul juge de sa fin.
##
## § 4.5 : « Ne jamais enchaîner six fois tue tout le monde. » Six types,
## et c'est la carte de combat qui en choisit un.
##
## Une règle vaut pour tous : si toute l'escouade est hors de combat, c'est
## perdu, quel que soit l'objectif. Chaque type ajoute ensuite sa propre
## condition de victoire, et parfois sa propre défaite — l'escorté qui
## tombe, la structure qui cède.

enum Kind { ELIMINATE, SURVIVE, ESCORT, PROTECT, SEIZE, EXTRACT }
enum Outcome { ONGOING, VICTORY, DEFEAT }

const KIND_NAMES := {
	"eliminate": Kind.ELIMINATE, "survive": Kind.SURVIVE, "escort": Kind.ESCORT,
	"protect": Kind.PROTECT, "seize": Kind.SEIZE, "extract": Kind.EXTRACT,
}

var kind: int = Kind.ELIMINATE

## SURVIVE : nombre de tours à tenir.
var turns: int = 0

## SEIZE, EXTRACT, ESCORT : cases à atteindre.
var cells: Array[Vector2i] = []

## ESCORT, PROTECT : unités à garder debout.
var subject_ids: Array[int] = []

## PROTECT : cases de décor à garder intactes.
var protected_cells: Array[Vector2i] = []

## SEIZE : tour limite. 0 = pas de limite.
var deadline: int = 0

## EXTRACT : cases où se trouve la cache à ramasser.
var pickup_cells: Array[Vector2i] = []

## EXTRACT : vrai une fois la cache ramassée, posé par le moteur.
var carried := false


## Construit un objectif depuis les données d'une carte de combat.
static func from_dictionary(data: Dictionary) -> CombatObjective:
	var objective := CombatObjective.new()
	var name_ := String(data.get("kind", "eliminate"))
	if not KIND_NAMES.has(name_):
		push_error("CombatObjective : type d'objectif inconnu « %s »" % name_)
		return objective
	objective.kind = KIND_NAMES[name_]
	objective.turns = int(data.get(
		"turns", CombatRules.rule(&"objectives", &"survive_default_turns", 0)
	))
	objective.deadline = int(data.get("deadline", 0))
	objective.cells = _cells_from(data.get("cells", []))
	objective.protected_cells = _cells_from(data.get("protected_cells", []))
	objective.pickup_cells = _cells_from(data.get("pickup_cells", []))
	var ids: Array[int] = []
	for raw: Variant in data.get("subject_ids", []):
		ids.append(int(raw))
	objective.subject_ids = ids
	return objective


## Où en est le combat. `turn_index` est le numéro du tour de joueur qui
## vient de s'achever, à partir de 1.
func evaluate(board: CombatBoard, turn_index: int) -> int:
	# Défaite universelle : plus personne debout.
	if board.active_units(Unit.Side.HEROES).is_empty():
		return Outcome.DEFEAT

	match kind:
		Kind.ELIMINATE:
			if board.active_units(Unit.Side.ENEMIES).is_empty():
				return Outcome.VICTORY
		Kind.SURVIVE:
			if turn_index >= turns:
				return Outcome.VICTORY
		Kind.ESCORT:
			if _any_subject_down(board):
				return Outcome.DEFEAT
			if _all_subjects_on_cells(board):
				return Outcome.VICTORY
		Kind.PROTECT:
			if _any_subject_down(board) or _any_protected_cell_broken(board):
				return Outcome.DEFEAT
			if turn_index >= turns:
				return Outcome.VICTORY
		Kind.SEIZE:
			if _any_hero_on_cells(board):
				return Outcome.VICTORY
			if deadline > 0 and turn_index >= deadline:
				return Outcome.DEFEAT
		Kind.EXTRACT:
			if carried and _any_hero_on_cells(board):
				return Outcome.VICTORY
	return Outcome.ONGOING


## Nom lisible du type, pour la sauvegarde et les journaux.
func kind_name() -> String:
	for key: String in KIND_NAMES.keys():
		if KIND_NAMES[key] == kind:
			return key
	return "eliminate"


static func _cells_from(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pair: Variant in raw:
		out.append(Vector2i(int(pair[0]), int(pair[1])))
	return out


func _any_subject_down(board: CombatBoard) -> bool:
	for id: int in subject_ids:
		var unit := board.unit_by_id(id)
		if unit == null or unit.is_downed():
			return true
	return false


func _all_subjects_on_cells(board: CombatBoard) -> bool:
	if subject_ids.is_empty() or cells.is_empty():
		return false
	for id: int in subject_ids:
		var unit := board.unit_by_id(id)
		if unit == null or not cells.has(unit.cell):
			return false
	return true


func _any_hero_on_cells(board: CombatBoard) -> bool:
	for cell: Vector2i in cells:
		var unit := board.unit_at(cell)
		if unit != null and unit.is_hero() and unit.is_active():
			return true
	return false


func _any_protected_cell_broken(board: CombatBoard) -> bool:
	for cell: Vector2i in protected_cells:
		var tile := board.tile_at(cell)
		# Le décor a cédé : il n'est plus destructible, il est devenu autre chose.
		if tile == null or not tile.is_destructible():
			return true
	return false
