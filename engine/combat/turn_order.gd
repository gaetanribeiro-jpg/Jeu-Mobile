class_name TurnOrder
extends RefCounted

## La timeline d'initiative (vision § 16).
##
## Un seul combattant agit à la fois, alliés et ennemis mélangés. L'ordre
## est recalculé à chaque ronde, pour qu'un bonus ou un malus d'initiative
## se voie dès la ronde suivante.
##
## Une RONDE est une activation de chaque combattant encore debout. Ce
## n'est pas « le tour du joueur puis le tour de l'ennemi » : le Voleur,
## avec 9 d'initiative, joue avant l'Archer du joueur, qui joue avant le
## Gobelin, qui joue avant le Guerrier.
##
## Les égalités ne sont jamais tranchées au hasard. À initiative égale, un
## héros passe avant un ennemi, puis c'est le plus petit identifiant qui
## gagne : le joueur ne perd pas un échange sur un tirage.

## Départage des égalités, lu dans `rules.json`.
const TIE_HEROES_FIRST := "heroes_first"

## Numéro de la ronde en cours, à partir de 1. Zéro tant que rien n'a
## commencé.
var round_index: int = 0

## Identifiants des combattants de la ronde en cours, dans l'ordre.
var _order: Array[int] = []

## Position dans `_order`. Peut dépasser la fin : la ronde est finie.
var _position: int = 0

## Identifiant → Unit, rafraîchi à chaque ronde. Sert à sauter ceux qui
## sont tombés en cours de ronde.
var _units: Dictionary = {}


## Ouvre une nouvelle ronde à partir des combattants encore debout.
func begin_round(units: Array[Unit]) -> void:
	round_index += 1
	_order = TurnOrder.sorted_ids(units)
	_position = 0
	_index(units)
	_skip_downed()


## Identifiant du combattant qui joue maintenant, ou -1 si la ronde est
## terminée.
func current() -> int:
	_skip_downed()
	if _position < 0 or _position >= _order.size():
		return -1
	return _order[_position]


## Le combattant qui joue maintenant, ou null.
func current_unit() -> Unit:
	var unit_id := current()
	return _units.get(unit_id, null) if unit_id >= 0 else null


func is_round_over() -> bool:
	return current() < 0


## Passe au combattant suivant. Ouvre une nouvelle ronde si celle-ci est
## épuisée. Renvoie l'identifiant du nouveau combattant courant, ou -1 s'il
## n'y a plus personne à faire jouer.
func advance(units: Array[Unit]) -> int:
	_position += 1
	_skip_downed()
	if _position < _order.size():
		return current()
	begin_round(units)
	return current()


## Ce qu'il reste à jouer dans la ronde, le combattant courant compris.
func remaining() -> Array[int]:
	var out: Array[int] = []
	for i in range(maxi(_position, 0), _order.size()):
		var unit_id := _order[i]
		if _is_active(unit_id):
			out.append(unit_id)
	return out


## Les `count` prochaines activations, celle en cours comprise, en
## débordant sur les rondes suivantes.
##
## C'est ce que le HUD affiche : le § 16 demande de voir qui joue
## maintenant ET qui joue ensuite, ce qui n'a de sens que si la vue peut
## regarder au-delà de la fin de la ronde.
func preview(units: Array[Unit], count: int) -> Array[int]:
	var out: Array[int] = remaining()
	var next_round := TurnOrder.sorted_ids(units)
	while out.size() < count and not next_round.is_empty():
		for unit_id: int in next_round:
			out.append(unit_id)
			if out.size() >= count:
				break
	return out.slice(0, maxi(count, 0))


## Retire un combattant de la ronde en cours. Appelé quand une unité tombe
## avant d'avoir joué : elle ne joue pas.
func remove(unit_id: int) -> void:
	_units.erase(unit_id)
	var at := _order.find(unit_id)
	if at < 0:
		return
	_order.remove_at(at)
	if at < _position:
		_position -= 1


## Les identifiants triés par initiative décroissante, à égalité les héros
## d'abord, puis le plus petit identifiant. Les unités hors de combat sont
## écartées.
static func sorted_ids(units: Array[Unit]) -> Array[int]:
	var active: Array[Unit] = []
	for unit: Unit in units:
		if unit != null and unit.is_active():
			active.append(unit)
	active.sort_custom(TurnOrder._before)
	var out: Array[int] = []
	for unit: Unit in active:
		out.append(unit.id)
	return out


## `a` joue-t-elle avant `b` ?
static func _before(a: Unit, b: Unit) -> bool:
	if a.initiative != b.initiative:
		return a.initiative > b.initiative
	if CombatRules.initiative_tie_break() == TIE_HEROES_FIRST and a.side != b.side:
		return a.is_hero()
	return a.id < b.id


func _index(units: Array[Unit]) -> void:
	_units.clear()
	for unit: Unit in units:
		if unit != null:
			_units[unit.id] = unit


func _is_active(unit_id: int) -> bool:
	var unit: Unit = _units.get(unit_id, null)
	return unit != null and unit.is_active()


## Avance la position tant que le combattant désigné est tombé.
func _skip_downed() -> void:
	while _position < _order.size() and not _is_active(_order[_position]):
		_position += 1


func to_dictionary() -> Dictionary:
	return {
		"round": round_index,
		"order": _order.duplicate(),
		"position": _position,
	}


## Restaure une timeline. `units` sert à réindexer : les Unit d'un
## instantané ne sont pas celles d'origine.
static func from_dictionary(data: Dictionary, units: Array[Unit]) -> TurnOrder:
	var order := TurnOrder.new()
	order.round_index = int(data.get("round", 0))
	order._position = int(data.get("position", 0))
	order._order = []
	for unit_id: Variant in data.get("order", []):
		order._order.append(int(unit_id))
	order._index(units)
	return order
