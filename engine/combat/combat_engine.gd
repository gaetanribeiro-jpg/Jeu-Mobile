class_name CombatEngine
extends RefCounted

## La machine à états d'un combat, et le seul objet qui fait avancer le temps.
##
## L'ordre d'un tour découle directement de la décision verrouillée du
## § 4.2 — les ennemis annoncent leur attaque un tour à l'avance :
##
##   1. Le joueur agit, en voyant le télégraphe posé au tour précédent.
##   2. Il valide son tour.
##   3. Les ennemis EXÉCUTENT ce qu'ils avaient annoncé, dans l'ordre.
##   4. Puis ils se déplacent et annoncent pour le tour suivant.
##   5. On regarde où en est l'objectif, et on rend la main.
##
## L'étape 3 vient avant l'étape 4, et c'est ce qui rend le télégraphe
## honnête : un ennemi ne peut pas bouger puis frapper dans le même souffle.
## Au début du combat, les ennemis annoncent sans se déplacer, pour que le
## premier tour du joueur ait déjà quelque chose à contrer.
##
## Classe pure : aucun nœud, aucun signal. Elle rend un journal
## d'évènements que la couche de rendu relaiera sur l'EventBus. C'est ce
## qui permet de simuler mille combats en headless (T10.2).

enum Phase { SETUP, PLAYER_TURN, RESOLVING, FINISHED }

var board: CombatBoard
var objective: CombatObjective
var rng: CombatRng
var ai: EnemyAI

var phase: int = Phase.SETUP
var turn_index: int = 0
var outcome: int = CombatObjective.Outcome.ONGOING

## Intentions en cours, par identifiant d'unité.
var _intents: Dictionary = {}

## Piles d'annulation, vidées à chaque validation de tour (C1.13).
var _undo_stack: Array[Dictionary] = []

## Héros qui provoquent ce tour-ci. Les ennemis adjacents doivent les
## cibler (§ 3.1, Provocation du Guerrier).
var _taunting: Array[int] = []

## Cases bénies : les attaques télégraphiées qui y tombent sont annulées
## (§ 3.1, Bénédiction du Moine). Vidées après la résolution ennemie.
var _warded: Array[Vector2i] = []


func _init(
	combat_board: CombatBoard,
	combat_objective: CombatObjective,
	combat_rng: CombatRng = null
) -> void:
	board = combat_board
	objective = combat_objective
	rng = combat_rng if combat_rng != null else CombatRng.new(0)
	ai = EnemyAI.new(rng)


## Ouvre le combat : premier tour du joueur, télégraphe déjà posé.
func start() -> void:
	turn_index = 1
	phase = Phase.PLAYER_TURN
	outcome = CombatObjective.Outcome.ONGOING
	_undo_stack.clear()
	_begin_player_turn()
	# Les ennemis annoncent sans bouger : ils sont déjà placés par la carte,
	# et le joueur doit avoir quelque chose à contrer dès le premier tour.
	for enemy: Unit in _ordered(board.active_units(Unit.Side.ENEMIES)):
		_intents[enemy.id] = ai.plan(board, enemy, _taunting)["intent"]


# --- Télégraphe (C1.9) ----------------------------------------------------

## Ce que le joueur voit : une entrée par ennemi qui annonce quelque chose.
## { attacker_id, cells, damage } — les cases et les dégâts sont recalculés
## à chaque appel depuis l'état courant, donc l'affichage suit en direct
## les poussées que le joueur essaie.
func telegraph() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enemy: Unit in _ordered(board.active_units(Unit.Side.ENEMIES)):
		var intent: CombatIntent = _intents.get(enemy.id, null)
		if intent == null or not intent.is_attack():
			continue
		var cells: Array[Vector2i] = []
		var damage: Array[int] = []
		for cell: Vector2i in intent.target_cells(enemy.cell):
			if not board.grid.contains(cell):
				continue
			cells.append(cell)
			damage.append(board.predicted_damage(enemy, cell))
		if cells.is_empty():
			continue
		out.append({"attacker_id": enemy.id, "cells": cells, "damage": damage})
	return out


## Dégâts annoncés sur une case donnée, tous attaquants confondus.
## C'est ce qu'affiche l'icône chiffrée du § 4.2 : le joueur doit lire le
## total qu'il va prendre, pas trois chiffres à additionner lui-même.
func threat_on(cell: Vector2i) -> int:
	var total := 0
	for entry: Dictionary in telegraph():
		var cells: Array = entry["cells"]
		var index := cells.find(cell)
		if index >= 0:
			total += int(entry["damage"][index])
	return total


func intent_of(unit_id: int) -> CombatIntent:
	return _intents.get(unit_id, null)


# --- Actions du joueur ----------------------------------------------------

## Déplace un héros. Refuse si la case n'est pas atteignable ou si l'unité
## a déjà bougé ce tour.
func move_hero(unit: Unit, to: Vector2i) -> bool:
	if not _can_act(unit) or unit.has_moved:
		return false
	if not board.can_move_to(unit, to):
		return false
	_push_undo()
	var from := unit.cell
	if not board.move_unit(unit, to):
		_undo_stack.pop_back()
		return false
	unit.has_moved = true
	_check_lethal_landing(unit, from)
	_check_pickup(unit)
	return true


## Attaque avec un héros. Renvoie le compte rendu, ou {} si le coup est illégal.
func attack(attacker: Unit, target: Unit) -> Dictionary:
	if not _can_act(attacker) or attacker.has_acted:
		return {}
	if not board.can_attack(attacker, target):
		return {}
	_push_undo()
	return board.resolve_attack(attacker, target)


## Pousse une unité avec un héros — la Repousse du Lancier (§ 3.1).
func push_with(attacker: Unit, target: Unit, distance: int = -1) -> Dictionary:
	if not _can_act(attacker) or attacker.has_acted:
		return {}
	if not board.can_attack(attacker, target):
		return {}
	_push_undo()
	attacker.has_acted = true
	return board.push_away_from(target, attacker.cell, distance)


# --- Capacités de classe (C1.24) ------------------------------------------

## Les quatre verbes tactiques du § 3.1. `target` est une Unit pour une
## attaque ou une poussée, un Vector2i pour une Bénédiction, et n'est pas
## lu pour une Provocation.
## Renvoie un compte rendu, ou {} si le coup est illégal.
func use_ability(unit: Unit, ability_id: StringName, target: Variant = null) -> Dictionary:
	if not _can_act(unit) or unit.has_acted:
		return {}
	var ability := Ability.get_ability(ability_id)
	if ability.is_empty():
		return {}

	match StringName(ability.get("kind", "")):
		Ability.KIND_TAUNT:
			return _use_taunt(unit)
		Ability.KIND_ATTACK:
			return _use_aimed_attack(unit, ability, target)
		Ability.KIND_PUSH:
			return _use_push(unit, ability, target)
		Ability.KIND_WARD:
			return _use_ward(unit, ability, target)
	push_error("CombatEngine : capacité « %s » sans effet connu" % ability_id)
	return {}


## Ce héros provoque-t-il ce tour-ci ?
func is_taunting(unit_id: int) -> bool:
	return _taunting.has(unit_id)


## Cette case est-elle protégée par une Bénédiction ?
func is_warded(cell: Vector2i) -> bool:
	return _warded.has(cell)


func _use_taunt(unit: Unit) -> Dictionary:
	_push_undo()
	unit.has_acted = true
	if not _taunting.has(unit.id):
		_taunting.append(unit.id)
	# Les ennemis déjà adjacents redirigent leur annonce immédiatement :
	# le joueur doit VOIR la provocation faire effet avant de valider.
	_retelegraph_adjacent(unit)
	return {"ability": "taunt", "unit_id": unit.id}


## Tir tendu : une attaque ordinaire, augmentée si l'archer n'a pas bougé.
func _use_aimed_attack(unit: Unit, ability: Dictionary, target: Variant) -> Dictionary:
	if not (target is Unit) or not board.can_attack(unit, target):
		return {}
	if bool(ability.get("requires_not_moved", false)) and unit.has_moved:
		return {}
	_push_undo()
	var victim: Unit = target
	var damage := board.predicted_damage(unit, victim.cell) + int(ability.get("damage_bonus", 0))
	var downed := victim.take_damage(damage)
	if downed:
		board.remove_from_board(victim)
	unit.has_acted = true
	return {
		"ability": "aimed_shot", "attacker_id": unit.id, "target_id": victim.id,
		"damage": damage, "downed": downed,
	}


func _use_push(unit: Unit, ability: Dictionary, target: Variant) -> Dictionary:
	if not (target is Unit) or not board.can_attack(unit, target):
		return {}
	_push_undo()
	unit.has_acted = true
	var report := board.push_away_from(target, unit.cell, int(ability.get("distance", 1)))
	report["ability"] = "push_back"
	return report


func _use_ward(unit: Unit, ability: Dictionary, target: Variant) -> Dictionary:
	if not (target is Vector2i) or not board.grid.contains(target):
		return {}
	var distance := board.grid.distance(unit.cell, target)
	if distance < int(ability.get("range_min", 1)) or distance > int(ability.get("range_max", 1)):
		return {}
	_push_undo()
	unit.has_acted = true
	if not _warded.has(target):
		_warded.append(target)
	return {"ability": "blessing", "unit_id": unit.id, "cell": target}


## Recalcule l'annonce des ennemis adjacents à un provocateur.
func _retelegraph_adjacent(taunter: Unit) -> void:
	for enemy: Unit in _ordered(board.active_units(Unit.Side.ENEMIES)):
		if board.grid.distance(enemy.cell, taunter.cell) > 1:
			continue
		if board.attackable_units(enemy).has(taunter):
			_intents[enemy.id] = CombatIntent.attack_cell(enemy.id, enemy.cell, taunter.cell)


# --- Annulation (C1.13) ---------------------------------------------------

## Rien n'est irréversible avant la validation du tour (§ 11.2).
func can_undo() -> bool:
	return phase == Phase.PLAYER_TURN and not _undo_stack.is_empty()


## Revient à l'état d'avant la dernière action du joueur.
func undo() -> bool:
	if not can_undo():
		return false
	_restore(_undo_stack.pop_back())
	return true


## Annule tout le tour d'un coup.
func undo_all() -> bool:
	if not can_undo():
		return false
	_restore(_undo_stack[0])
	_undo_stack.clear()
	return true


func undo_depth() -> int:
	return _undo_stack.size()


# --- Fin de tour ----------------------------------------------------------

## Valide le tour du joueur et résout celui des ennemis.
## Renvoie le journal ordonné des évènements, à rejouer par le rendu (C1.22).
func end_player_turn() -> Array[Dictionary]:
	if phase != Phase.PLAYER_TURN:
		return []
	var log: Array[Dictionary] = []
	phase = Phase.RESOLVING
	# Passé ce point, plus rien n'est annulable : c'est la contrepartie de
	# l'annulation libre pendant le tour.
	_undo_stack.clear()

	_execute_intents(log)
	# La Bénédiction et la Provocation ne valent que pour le tour qu'elles
	# viennent de couvrir.
	_warded.clear()
	_taunting.clear()

	if _settle(log):
		return log

	_advance_enemies(log)

	turn_index += 1
	phase = Phase.PLAYER_TURN
	_begin_player_turn()
	log.append({"event": "turn_started", "turn": turn_index})
	return log


func is_finished() -> bool:
	return phase == Phase.FINISHED


func is_victory() -> bool:
	return outcome == CombatObjective.Outcome.VICTORY


# --- Interne --------------------------------------------------------------

## Exécute les intentions annoncées. Elles frappent la case, pas l'unité :
## si le joueur a déplacé sa cible, le coup part dans le vide, et s'il a
## poussé un gobelin dans la ligne d'un autre, le gobelin le prend.
func _execute_intents(log: Array[Dictionary]) -> void:
	for enemy: Unit in _ordered(board.active_units(Unit.Side.ENEMIES)):
		var intent: CombatIntent = _intents.get(enemy.id, null)
		if intent == null or not intent.is_attack():
			continue
		for cell: Vector2i in intent.target_cells(enemy.cell):
			if not board.grid.contains(cell):
				continue
			if _warded.has(cell):
				log.append({
					"event": "attack_warded", "attacker_id": enemy.id, "cell": cell,
				})
				continue
			var damage := board.predicted_damage(enemy, cell)
			var victim := board.unit_at(cell)
			if victim == null or not victim.is_active():
				log.append({
					"event": "attack_missed", "attacker_id": enemy.id,
					"cell": cell, "damage": damage,
				})
				continue
			var downed := victim.take_damage(damage)
			if downed:
				board.remove_from_board(victim)
			log.append({
				"event": "attack_landed", "attacker_id": enemy.id,
				"target_id": victim.id, "cell": cell,
				"damage": damage, "downed": downed,
			})
		_intents[enemy.id] = CombatIntent.none(enemy.id)


## Déplacements et nouvelles annonces, après que tous les coups sont partis.
func _advance_enemies(log: Array[Dictionary]) -> void:
	for enemy: Unit in _ordered(board.active_units(Unit.Side.ENEMIES)):
		var plan := ai.plan(board, enemy, _taunting)
		var destination: Vector2i = plan["move_to"]
		if destination != enemy.cell:
			var from := enemy.cell
			board.move_unit(enemy, destination)
			log.append({
				"event": "enemy_moved", "unit_id": enemy.id, "from": from, "to": destination,
			})
			_check_lethal_landing(enemy, from)
		if enemy.is_active():
			_intents[enemy.id] = plan["intent"]
	log.append({"event": "telegraph_updated"})


## Regarde où en est l'objectif. Renvoie true si le combat s'arrête ici.
func _settle(log: Array[Dictionary]) -> bool:
	outcome = objective.evaluate(board, turn_index)
	# Garde-fou : un combat doit toujours finir. Le § 4.1 vise 3 à 6 tours ;
	# au-delà du plafond, l'objectif n'a pas été rempli à temps, et c'est
	# une défaite. Sans ça, une escorte qu'on n'avance pas tourne sans fin.
	if outcome == CombatObjective.Outcome.ONGOING:
		var cap := int(CombatRules.rule(&"objectives", &"max_turns_before_draw", 0))
		if cap > 0 and turn_index >= cap:
			outcome = CombatObjective.Outcome.DEFEAT
			log.append({"event": "turn_limit_reached", "turn": turn_index})
	if outcome == CombatObjective.Outcome.ONGOING:
		return false
	phase = Phase.FINISHED
	log.append({
		"event": "combat_ended",
		"victory": outcome == CombatObjective.Outcome.VICTORY,
		"turn": turn_index,
	})
	return true


func _begin_player_turn() -> void:
	for hero: Unit in board.active_units(Unit.Side.HEROES):
		hero.begin_turn()


## Ramassage de la cache d'un objectif « Extraire ». Il se fait en passant
## dessus, sans action : le coût de l'objectif est le détour, pas le geste.
func _check_pickup(unit: Unit) -> void:
	if objective.carried or objective.kind != CombatObjective.Kind.EXTRACT:
		return
	if unit.is_hero() and objective.pickup_cells.has(unit.cell):
		objective.carried = true


func _can_act(unit: Unit) -> bool:
	return phase == Phase.PLAYER_TURN and unit != null and unit.is_active() and unit.is_hero()


## Une unité qui finit sur une case mortelle y reste. Le déplacement passe
## par `can_stand_on`, donc un héros n'y va jamais de son plein gré ; ce
## garde-fou existe pour les cas indirects — un pont détruit sous les pieds.
func _check_lethal_landing(unit: Unit, from: Vector2i) -> void:
	var tile := board.tile_at(unit.cell)
	if tile == null or not tile.is_lethal() or unit.aquatic or unit.flying:
		return
	unit.down()
	board.remove_from_board(unit)
	if from == unit.cell:
		return


func _ordered(units: Array[Unit]) -> Array[Unit]:
	var out := units.duplicate()
	out.sort_custom(func(a: Unit, b: Unit) -> bool: return a.id < b.id)
	return out


# --- Instantanés ----------------------------------------------------------

func _push_undo() -> void:
	_undo_stack.append(snapshot())


## État complet du combat. Sert à l'annulation, et servira à la sauvegarde
## en cours d'expédition (règle 5 : l'application peut être tuée à tout
## moment).
func snapshot() -> Dictionary:
	var tiles: Array = []
	for cell: Vector2i in board.grid.cells():
		tiles.append(board.tile_at(cell).to_dictionary())
	var units: Array = []
	for unit: Unit in board.units():
		units.append(unit.to_dictionary())
	var intents: Array = []
	for id: int in _intents.keys():
		intents.append(_intents[id].to_dictionary())
	return {
		"turn": turn_index,
		"phase": phase,
		"outcome": outcome,
		"carried": objective.carried,
		"rng": rng.position(),
		"taunting": _taunting.duplicate(),
		"warded": _warded.duplicate(),
		"tiles": tiles,
		"units": units,
		"intents": intents,
	}


func _restore(state: Dictionary) -> void:
	turn_index = int(state["turn"])
	phase = int(state["phase"])
	outcome = int(state["outcome"])
	objective.carried = bool(state["carried"])
	rng.rewind_to(state["rng"])
	_taunting = (state.get("taunting", []) as Array).duplicate()
	var wards: Array[Vector2i] = []
	for cell: Variant in state.get("warded", []):
		wards.append(cell)
	_warded = wards

	for raw: Dictionary in state["tiles"]:
		var tile := board.tile_at(Vector2i(int(raw["x"]), int(raw["y"])))
		tile.set_terrain(StringName(raw["terrain"]))
		tile.occupant_id = int(raw["occupant"])
		tile.structure_hp = int(raw["structure_hp"])

	for raw: Dictionary in state["units"]:
		var unit := board.unit_by_id(int(raw["id"]))
		if unit == null:
			continue
		unit.cell = Vector2i(int(raw["x"]), int(raw["y"]))
		unit.hit_points = int(raw["hit_points"])
		unit.max_hit_points = int(raw["max_hit_points"])
		unit.state = int(raw["state"])
		unit.has_moved = bool(raw["has_moved"])
		unit.has_acted = bool(raw["has_acted"])

	_intents.clear()
	for raw: Dictionary in state["intents"]:
		var intent := CombatIntent.from_dictionary(raw)
		_intents[intent.attacker_id] = intent
