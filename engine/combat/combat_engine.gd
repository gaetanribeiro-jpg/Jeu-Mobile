class_name CombatEngine
extends RefCounted

## La machine à états d'un combat, et le seul objet qui fait avancer le temps.
##
## LE MODÈLE DE TOUR (vision § 13 et § 16). Un seul combattant agit à la
## fois, alliés et ennemis entremêlés selon leur initiative. Chacun
## retrouve ses PA et ses PM au début de son activation, et les dépense
## comme il veut : deux attaques, ou une compétence puissante et un
## repositionnement.
##
##   0. Le joueur PLACE son équipe sur les cases que la carte propose.
##      Il y en a toujours plus que de personnages : partir groupé, étalé,
##      près de l'eau ou loin d'elle est déjà une décision, et elle se
##      prend en voyant où sont les ennemis et ce qu'ils atteignent.
##   1. La timeline désigne un combattant.
##   2. Si c'est un héros, le joueur dépense ses PA et ses PM, et peut tout
##      annuler tant qu'il n'a pas validé.
##   3. Si c'est un ennemi, il EXÉCUTE ce qu'il avait annoncé, PUIS se
##      déplace, PUIS annonce pour sa prochaine activation.
##   4. On regarde où en est l'objectif, et on passe au suivant.
##
## L'ordre de l'étape 3 est ce qui rend le télégraphe honnête : un ennemi
## ne peut pas bouger puis frapper dans le même souffle. Au début du
## combat, les ennemis annoncent sans se déplacer, pour que la première
## activation du joueur ait déjà quelque chose à contrer.
##
## Classe pure : aucun nœud, aucun signal. Elle rend un journal
## d'évènements que la couche de rendu relaiera sur l'EventBus. C'est ce
## qui permet de simuler mille combats en headless.

enum Phase { SETUP, DEPLOYMENT, ACTIVE, FINISHED }

var board: CombatBoard
var objective: CombatObjective
var rng: CombatRng
var ai: EnemyAI
var order: TurnOrder

## Les potions emportées, identifiant → compte (§ 44).
##
## LE SAC EST COMMUN À L'ÉQUIPE et il vit DANS le moteur : « rien n'est
## irréversible avant la fin de l'activation » vaut aussi pour une potion
## bue, et seul ce qui est dans l'instantané peut être rendu. L'appelant
## le charge au début du combat et le relit à la fin.
var supplies: Dictionary = {}

var phase: int = Phase.SETUP
var outcome: int = CombatObjective.Outcome.ONGOING

## Intentions annoncées, par identifiant d'unité.
var _intents: Dictionary = {}

## Pile d'annulation, vidée à chaque fin d'activation.
var _undo_stack: Array[Dictionary] = []

## Cases proposées par la carte pour le placement initial.
var _deployment_cells: Array[Vector2i] = []

## Héros pas encore posés, dans l'ordre de leurs emplacements.
var _pending: Array[Unit] = []

## Journal produit par l'ouverture du combat : si un ennemi joue avant le
## premier héros, il a déjà agi quand la vue prend la main, et elle doit
## pouvoir le rejouer.
var _opening_log: Array[Dictionary] = []

## Héros qui provoquent. Les ennemis adjacents doivent les cibler. Une
## provocation expire au début de la prochaine activation du provocateur :
## elle achète exactement un tour de timeline aux autres.
var _taunting: Array[int] = []


func _init(
	combat_board: CombatBoard,
	combat_objective: CombatObjective,
	combat_rng: CombatRng = null
) -> void:
	board = combat_board
	objective = combat_objective
	rng = combat_rng if combat_rng != null else CombatRng.new(0)
	ai = EnemyAI.new(rng)
	order = TurnOrder.new()


# --- Sauvegarde en plein combat (T7.1) -------------------------------------
#
# POURQUOI. Sur mobile, l'application meurt à tout moment. L'expédition
# survivait déjà à ça, le combat non : perdre sept rondes parce qu'un appel
# arrive est exactement la punition que le § 41 refuse.
#
# CE QU'ON N'ÉCRIT PAS, ET C'EST DÉLIBÉRÉ : la pile d'annulation. Annuler
# ne vaut qu'à l'intérieur d'une activation, et reprendre une partie
# commence l'activation à neuf. La sauver obligerait à sérialiser des
# instantanés entiers du plateau pour un service que personne ne réclamera
# après avoir rallumé son téléphone.
#
# CE QU'ON ÉCRIT ET QU'ON POURRAIT CROIRE SUPERFLU : les INTENTIONS, c'est
# à dire le télégraphe. Sans elles, un ennemi qui avait annoncé son coup
# frapperait sans l'avoir annoncé, et « information parfaite, toujours »
# tomberait sur un rechargement.

## Tout ce qu'il faut pour reprendre ce combat exactement où il en est.
func to_dictionary() -> Dictionary:
	var saved_intents := {}
	for unit_id: Variant in _intents.keys():
		saved_intents[str(unit_id)] = (_intents[unit_id] as CombatIntent).to_dictionary()
	var saved_pending: Array = []
	for unit: Unit in _pending:
		saved_pending.append(unit.to_dictionary())
	var saved_cells: Array = []
	for cell: Vector2i in _deployment_cells:
		saved_cells.append([cell.x, cell.y])

	return {
		"phase": phase,
		"outcome": outcome,
		"board": board.to_dictionary(),
		"objective": objective.to_dictionary(),
		"order": order.to_dictionary(),
		"rng": rng.position(),
		"intents": saved_intents,
		"pending": saved_pending,
		"deployment_cells": saved_cells,
		"taunting": _taunting.duplicate(),
		"supplies": supplies.duplicate(),
	}


static func from_dictionary(data: Dictionary) -> CombatEngine:
	if data.is_empty():
		return null
	var restored_board := CombatBoard.from_dictionary(data.get("board", {}))
	if restored_board == null:
		return null

	var restored_rng := CombatRng.new(0)
	restored_rng.rewind_to(data.get("rng", {}))
	var engine := CombatEngine.new(
		restored_board,
		CombatObjective.from_dictionary(data.get("objective", {})),
		restored_rng
	)
	engine.phase = int(data.get("phase", Phase.SETUP))
	engine.outcome = int(data.get("outcome", CombatObjective.Outcome.ONGOING))
	engine.order = TurnOrder.from_dictionary(data.get("order", {}), restored_board.units())
	# Le sac fait partie du combat rechargé : reprendre une bataille avec
	# ses potions déjà bues serait pire que de ne pas la reprendre.
	engine.supplies = (data.get("supplies", {}) as Dictionary).duplicate()

	for key: Variant in (data.get("intents", {}) as Dictionary).keys():
		var intent := CombatIntent.from_dictionary((data["intents"] as Dictionary)[key])
		if intent != null:
			engine._intents[int(String(key))] = intent
	for raw: Variant in data.get("pending", []):
		var unit := Unit.from_dictionary(raw)
		if unit != null:
			engine._pending.append(unit)
	for pair: Variant in data.get("deployment_cells", []):
		engine._deployment_cells.append(Vector2i(int(pair[0]), int(pair[1])))
	for raw: Variant in data.get("taunting", []):
		engine._taunting.append(int(raw))
	return engine


## Déclare la zone de placement et l'équipe à poser. À appeler avant
## `start()` ; sans elle, le combat s'ouvre directement, ce qui reste
## utile aux tests qui posent les unités eux-mêmes.
func set_deployment(cells: Array[Vector2i], squad: Array[Unit]) -> void:
	_deployment_cells = cells.duplicate()
	_pending = squad.duplicate()


## Ouvre le combat. Sur la phase de placement s'il y a une équipe à poser,
## sur la première activation sinon.
func start() -> void:
	outcome = CombatObjective.Outcome.ONGOING
	_undo_stack.clear()
	if not _pending.is_empty() and not _deployment_cells.is_empty():
		phase = Phase.DEPLOYMENT
		return
	_open_combat()


func _open_combat() -> void:
	phase = Phase.ACTIVE
	# Les ennemis annoncent sans bouger : ils sont déjà placés par la carte,
	# et le joueur doit avoir quelque chose à contrer dès sa première
	# activation. `intent_here` et non `plan()` — les décalages d'une
	# intention sont relatifs à l'attaquant, donc une intention calculée
	# depuis la case d'arrivée d'un déplacement qui n'a pas eu lieu
	# désignerait des cases vides.
	for enemy: Unit in _ordered(board.active_units(Unit.Side.ENEMIES)):
		_intents[enemy.id] = ai.intent_here(board, enemy, _taunting)
	order.begin_round(board.units())
	# La timeline peut très bien désigner un ennemi en premier : le Voleur a
	# 9 d'initiative, plus que n'importe quel héros. Il joue donc avant que
	# le joueur ne touche à quoi que ce soit, et son activation part dans le
	# journal d'ouverture.
	_opening_log = []
	if _open_current(_opening_log):
		return
	if _settle(_opening_log):
		return
	_drain(_opening_log)


## Ce qui s'est passé avant que le joueur ne prenne la main. Vidé à la
## lecture : c'est un journal à rejouer une fois, pas un état.
func take_opening_log() -> Array[Dictionary]:
	var log := _opening_log
	_opening_log = []
	return log


## Ouvre l'activation du combattant courant. Renvoie true s'il faut rendre
## la main au joueur.
func _open_current(log: Array[Dictionary]) -> bool:
	var unit := order.current_unit()
	if unit == null:
		return false
	_begin_activation(unit)
	log.append({
		"event": "activation_started", "unit_id": unit.id,
		"side": unit.side, "round": order.round_index,
	})
	var burn := _burn(unit)
	if not burn.is_empty():
		log.append(burn)
		if not unit.is_active():
			return false
	if unit.is_hero():
		return true
	_run_enemy(unit, log)
	return false


func _begin_activation(unit: Unit) -> void:
	var penalty := 0
	for status_id: Variant in unit.statuses.keys():
		penalty += CombatRules.status_movement_penalty(StringName(status_id))
	unit.begin_activation(penalty)
	# Une provocation ne dure que jusqu'au retour de son auteur.
	_taunting.erase(unit.id)
	_undo_stack.clear()


## Ce que le terrain retire à celui qui commence son activation dessus :
## le feu brûle (§ 19). Renvoie le compte rendu, ou {} s'il ne se passe
## rien — appelé APRÈS `_begin_activation`, pour que les dégâts s'appliquent
## à une unité qui a déjà retrouvé ses points.
func _burn(unit: Unit) -> Dictionary:
	var tile := board.tile_at(unit.cell)
	if tile == null:
		return {}
	var amount := tile.damage_per_activation()
	if amount <= 0:
		return {}
	var downed := unit.take_damage(amount)
	if downed:
		board.remove_from_board(unit)
		order.remove(unit.id)
	return {
		"event": "terrain_burned", "unit_id": unit.id, "cell": unit.cell,
		"terrain": String(tile.terrain_id), "damage": amount, "downed": downed,
	}


# --- La timeline ----------------------------------------------------------

## Le combattant qui joue maintenant, ou null.
func current_unit() -> Unit:
	return order.current_unit() if phase == Phase.ACTIVE else null


## Est-ce au joueur d'agir ?
func is_player_turn() -> bool:
	var unit := current_unit()
	return unit != null and unit.is_hero()


func round_index() -> int:
	return order.round_index


## Les prochaines activations, celle en cours comprise. C'est ce que le
## HUD affiche : le § 16 demande de voir qui joue maintenant ET qui joue
## ensuite.
func timeline(count: int = -1) -> Array[int]:
	var length := count if count > 0 else CombatRules.initiative_preview_length()
	return order.preview(board.units(), length)


# --- Placement initial ----------------------------------------------------

func is_deploying() -> bool:
	return phase == Phase.DEPLOYMENT


## Cases où le joueur a le droit de poser un personnage.
func deployment_cells() -> Array[Vector2i]:
	return _deployment_cells.duplicate()


## Personnages qui restent à poser, dans l'ordre de leurs emplacements.
func pending_heroes() -> Array[Unit]:
	return _pending.duplicate()


## Cases qu'un ennemi peut viser depuis là où il se tient.
##
## Ce n'est pas encore le télégraphe — aucun ennemi n'a d'intention tant
## que personne n'est placé — mais c'est l'information dont le joueur a
## besoin pour choisir : se poser là, c'est se mettre à portée.
func threatened_deployment_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for enemy: Unit in board.active_units(Unit.Side.ENEMIES):
		for ability_id: StringName in enemy.abilities:
			var ability := Ability.of(ability_id)
			if ability == null or not ability.is_attack():
				continue
			for cell: Vector2i in board.targetable_cells(enemy, ability):
				if _deployment_cells.has(cell) and not out.has(cell):
					out.append(cell)
	return out


## Ce que chaque case de placement coûterait, si un personnage s'y tenait.
## { case → dégâts annoncés }. Le joueur choisit en sachant : se poser sur
## une case menacée est un choix, pas un piège.
func deployment_threat() -> Dictionary:
	var out := {}
	for enemy: Unit in board.active_units(Unit.Side.ENEMIES):
		for ability_id: StringName in enemy.abilities:
			var ability := Ability.of(ability_id)
			if ability == null or not ability.is_attack():
				continue
			for cell: Vector2i in board.targetable_cells(enemy, ability):
				if not _deployment_cells.has(cell):
					continue
				var amount := _damage_on_cell(enemy, ability, cell)
				out[cell] = maxi(int(out.get(cell, 0)), amount)
	return out


## Pose un personnage sur une case. Sans unité précisée, pose le premier
## qui attend, dans l'ordre des emplacements.
func deploy(cell: Vector2i, unit: Unit = null) -> bool:
	if not is_deploying() or not _deployment_cells.has(cell):
		return false
	if board.unit_at(cell) != null:
		return false
	var chosen := unit if unit != null else (_pending[0] if not _pending.is_empty() else null)
	if chosen == null or not _pending.has(chosen):
		return false
	if not board.place_unit(chosen, cell):
		return false
	_pending.erase(chosen)
	return true


## Reprend un personnage déjà posé. Il retourne dans la file, à sa place
## selon son numéro d'emplacement, pour que l'ordre reste prévisible.
func undeploy(unit: Unit) -> bool:
	if not is_deploying() or unit == null or not unit.is_hero():
		return false
	if _pending.has(unit) or board.unit_at(unit.cell) != unit:
		return false
	board.remove_from_board(unit)
	var index := 0
	while index < _pending.size() and _pending[index].slot < unit.slot:
		index += 1
	_pending.insert(index, unit)
	return true


## Reprend le dernier personnage posé. C'est ce que fait le bouton Annuler
## pendant le placement : rien n'est irréversible avant que le combat
## commence, comme rien ne l'est avant la validation d'une activation.
func undeploy_last() -> Unit:
	if not is_deploying():
		return null
	var last: Unit = null
	for unit: Unit in board.active_units(Unit.Side.HEROES):
		if _pending.has(unit):
			continue
		if last == null or unit.slot > last.slot:
			last = unit
	if last == null or not undeploy(last):
		return null
	return last


## Pose ce qui reste sur les premières cases libres. Sert aux simulations
## et aux tests, pas au jeu : le placement est justement ce qu'on veut
## laisser au joueur.
func auto_deploy() -> void:
	if not is_deploying():
		return
	for cell: Vector2i in _deployment_cells:
		if _pending.is_empty():
			break
		if board.unit_at(cell) == null:
			deploy(cell)


func can_begin_combat() -> bool:
	return is_deploying() and _pending.is_empty()


## Referme le placement et ouvre la première activation.
func begin_combat() -> bool:
	if not can_begin_combat():
		return false
	_open_combat()
	return true


# --- Télégraphe -----------------------------------------------------------

## Ce que le joueur voit : une entrée par ennemi qui annonce quelque chose.
## { attacker_id, ability, cells, damage } — les cases et les dégâts sont
## recalculés à chaque appel depuis l'état courant, donc l'affichage suit
## en direct ce que le joueur essaie.
func telegraph() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enemy: Unit in _ordered(board.active_units(Unit.Side.ENEMIES)):
		var intent: CombatIntent = _intents.get(enemy.id, null)
		if intent == null or not intent.is_attack():
			continue
		var ability := intent.ability()
		if ability == null:
			continue
		var cells: Array[Vector2i] = []
		var damage: Array[int] = []
		for cell: Vector2i in intent.target_cells(enemy.cell, board.grid):
			if not board.grid.contains(cell):
				continue
			cells.append(cell)
			damage.append(_damage_on_cell(enemy, ability, cell))
		if cells.is_empty():
			continue
		out.append({
			"attacker_id": enemy.id,
			"ability": String(ability.id),
			"cells": cells,
			"damage": damage,
			"shoves": _shoves_of(enemy, ability, cells),
		})
	return out


## Où atterrirait chaque héros repoussé par cette attaque.
##
## SANS ÇA, LA NOYADE VIOLE LE § 39. Un coup d'épaule qui projette dans un
## lac gelé tue quels que soient les PV : annoncer « 14 dégâts » et rendre
## un héros à terre est exactement le piège que le télégraphe existe pour
## interdire. Le joueur doit voir la case d'arrivée avant de décider, et
## voir qu'elle est en eau.
##
## Rendu en cases absolues et relu à chaque affichage, comme les dégâts :
## déplacer l'attaquant change la direction de la poussée, donc la case
## d'arrivée suit toute seule.
func _shoves_of(
	enemy: Unit, ability: Ability, cells: Array[Vector2i]
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if ability.push <= 0:
		return out
	for cell: Vector2i in cells:
		var victim := board.unit_at(cell)
		if victim == null or victim.side == enemy.side or not victim.is_active():
			continue
		var landing: Vector2i = board.predict_push(
			victim, board.grid.direction(enemy.cell, victim.cell), ability.push
		)["destination"]
		if landing != victim.cell and not out.has(landing):
			out.append(landing)
	return out


## Dégâts annoncés sur une case donnée, tous attaquants confondus.
## Le joueur doit lire le total qu'il va prendre, pas trois chiffres à
## additionner lui-même.
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


## Dégâts qu'une compétence ferait sur une case, occupée ou non. Une case
## vide affiche quand même un chiffre : c'est ce que prendrait celui qui
## s'y tiendrait, et c'est l'information qui décide d'un déplacement.
func _damage_on_cell(attacker: Unit, ability: Ability, cell: Vector2i) -> int:
	var victim := board.unit_at(cell)
	if victim != null and victim.is_active():
		return board.predicted_damage(attacker, ability, victim)
	# Pas d'occupant : on chiffre contre une défense nulle, ce qui donne le
	# haut de la fourchette. Le joueur voit le pire cas, jamais un chiffre
	# optimiste.
	var total := ability.damage
	if not ability.scaling.is_empty():
		total += attacker.stat(ability.scaling)
	var attacker_tile := board.tile_at(attacker.cell)
	if attacker_tile != null and ability.range_max > 1:
		total += attacker_tile.ranged_damage_bonus()
	var target_tile := board.tile_at(cell)
	if target_tile != null:
		total += target_tile.damage_taken_modifier()
	return maxi(total, CombatRules.damage_minimum())


# --- Actions du joueur ----------------------------------------------------

## Déplace le personnage actif, en dépensant ses PM. Il peut se déplacer
## plusieurs fois dans son activation tant qu'il lui en reste (§ 14).
func move(unit: Unit, to: Vector2i) -> bool:
	if not _can_act(unit):
		return false
	var cost := board.move_cost_to(unit, to)
	if cost < 0 or cost > unit.movement_points:
		return false
	_push_undo()
	var from := unit.cell
	if not board.move_unit(unit, to):
		_undo_stack.pop_back()
		return false
	unit.spend_movement_points(cost)
	_check_lethal_landing(unit, from)
	_check_pickup(unit)
	return true


## Coût en PM pour rejoindre cette case, ou -1 si elle est hors d'atteinte.
func move_cost(unit: Unit, to: Vector2i) -> int:
	return board.move_cost_to(unit, to)


## Le personnage actif peut-il lancer cette compétence, PA et recharge
## comprises ?
func can_use(unit: Unit, ability_id: StringName) -> bool:
	if not _can_act(unit):
		return false
	var ability := Ability.of(ability_id)
	return ability != null and ability.is_available_to(unit)


## Cases que cette compétence peut viser depuis là où le personnage actif
## se tient.
func targetable_cells(unit: Unit, ability_id: StringName) -> Array[Vector2i]:
	var ability := Ability.of(ability_id)
	if ability == null:
		return []
	return board.targetable_cells(unit, ability)


## Le tir est-il légal sur cette case ? Distinct de « à portée » : une
## attaque à cible unique ne part pas sur du vide.
func can_aim(unit: Unit, ability_id: StringName, cell: Vector2i) -> bool:
	if not can_use(unit, ability_id):
		return false
	var ability := Ability.of(ability_id)
	if ability == null:
		return false
	if ability.targets_self():
		return cell == unit.cell
	return board.can_target(unit, ability, cell)


## Cases que la compétence toucherait si on visait celle-ci. C'est ce que
## le HUD colore avant de valider (§ 18).
func affected_cells(unit: Unit, ability_id: StringName, target: Vector2i) -> Array[Vector2i]:
	var ability := Ability.of(ability_id)
	if ability == null:
		return []
	return board.affected_cells(unit, ability, target)


## Lance une compétence sur une case. Renvoie le compte rendu, ou {} si le
## coup est illégal.
##
## C'est ici que les PA sont dépensés et la recharge armée : le plateau
## applique, le moteur décide.
## Boit ou lance une potion (§ 44). Rend le même compte rendu qu'une
## compétence, parce que c'en est une.
##
## LE STOCK EST DANS LE MOTEUR, PAS DANS LA COMPAGNIE, et c'est
## l'annulation qui l'impose. « Rien n'est irréversible avant la fin de
## l'activation » : une potion bue puis annulée doit revenir dans le sac.
## Si le compteur vivait sur `Company`, l'instantané d'annulation ne le
## verrait pas et la potion serait perdue pour de bon — le seul geste du
## jeu qu'on ne pourrait pas reprendre.
##
## L'appelant charge `supplies` au début du combat et le relit à la fin.
## Le moteur, lui, ignore ce qu'est une compagnie.
func use_consumable(
	unit: Unit, item_id: StringName, target: Vector2i
) -> Dictionary:
	if phase != Phase.ACTIVE or unit == null or not unit.is_hero():
		return {}
	if int(supplies.get(item_id, 0)) <= 0:
		return {}
	var ability_id := Consumable.ability_of(item_id)
	if ability_id.is_empty() or not can_use(unit, ability_id):
		return {}
	# ON RETIRE LA POTION APRÈS, ET L'ORDRE EST TOUT. `use_ability` empile
	# l'instantané d'annulation, et cet instantané est l'état où l'on
	# REVIENT : il doit donc montrer le sac ENCORE PLEIN. En retirant
	# d'abord, l'annulation rendait le soin mais gardait la potion bue —
	# le seul geste du jeu qu'on ne pouvait pas reprendre, et c'est
	# exactement celui qu'on voulait pouvoir reprendre.
	#
	# Le bénéfice second : une compétence qui refuse (cible hors de
	# portée) n'a rien à remettre dans le sac.
	var report := use_ability(unit, ability_id, target)
	if report.is_empty():
		return {}
	Consumable.take(supplies, item_id)
	report["consumable"] = String(item_id)
	report["left"] = int(supplies.get(item_id, 0))
	return report


## Les potions qu'il reste, et celles que ce personnage peut employer
## maintenant — celles dont il a les PA.
func usable_consumables(unit: Unit) -> Array[StringName]:
	var out: Array[StringName] = []
	if unit == null or not unit.is_hero():
		return out
	for item_id: StringName in Consumable.ids():
		if int(supplies.get(item_id, 0)) <= 0:
			continue
		var ability := Ability.of(Consumable.ability_of(item_id))
		if ability != null and unit.action_points >= ability.action_points:
			out.append(item_id)
	return out


func use_ability(unit: Unit, ability_id: StringName, target: Vector2i) -> Dictionary:
	if not can_use(unit, ability_id):
		return {}
	var ability := Ability.of(ability_id)
	var aimed := unit.cell if ability.targets_self() else target
	if not ability.targets_self() and not board.can_target(unit, ability, aimed):
		return {}

	_push_undo()
	unit.spend_action_points(ability.action_points)
	if ability.movement_points > 0:
		unit.spend_movement_points(ability.movement_points)
	# Les PM rendus peuvent DÉPASSER le maximum : c'est un philtre, pas un
	# repos. Le plafonner à `max_movement_points` le rendrait inutile
	# précisément quand on en a besoin — au début d'une activation, quand
	# on est encore au plein.
	if ability.restores_movement_points > 0:
		unit.movement_points += ability.restores_movement_points
	unit.start_cooldown(ability.id, ability.cooldown)

	match ability.kind:
		Ability.KIND_TAUNT:
			return _use_taunt(unit, ability)
		Ability.KIND_REPOSITION:
			return _use_reposition(unit, ability, aimed)
		Ability.KIND_PUSH:
			return _use_push(unit, ability, aimed)
	var report := board.resolve_ability(unit, ability, aimed)
	report["action_points_left"] = unit.action_points
	return report


## Ce personnage provoque-t-il ?
func is_taunting(unit_id: int) -> bool:
	return _taunting.has(unit_id)


func _use_taunt(unit: Unit, ability: Ability) -> Dictionary:
	if not _taunting.has(unit.id):
		_taunting.append(unit.id)
	# Les ennemis déjà adjacents redirigent leur annonce immédiatement :
	# le joueur doit VOIR la provocation faire effet avant de valider.
	_retelegraph_adjacent(unit)
	return {
		"caster_id": unit.id, "ability": String(ability.id),
		"target": unit.cell, "hits": [], "downed_ids": [],
		"action_points_left": unit.action_points,
	}


## Bond de l'Archer : un déplacement qui ne coûte pas de PM. La case doit
## être libre et praticable ; c'est la portée de la compétence qui dit
## jusqu'où.
func _use_reposition(unit: Unit, ability: Ability, target: Vector2i) -> Dictionary:
	if board.unit_at(target) != null or not board.can_stand_on(unit, target):
		return {}
	var from := unit.cell
	if not board.move_unit(unit, target):
		return {}
	if ability.counts_as_movement:
		unit.has_moved = true
	_check_lethal_landing(unit, from)
	_check_pickup(unit)
	return {
		"caster_id": unit.id, "ability": String(ability.id),
		"from": from, "target": target, "hits": [], "downed_ids": [],
		"action_points_left": unit.action_points,
	}


func _use_push(unit: Unit, ability: Ability, target: Vector2i) -> Dictionary:
	var victim := board.unit_at(target)
	if victim == null or not victim.is_active():
		return {}
	var report := board.push_away_from(victim, unit.cell, ability.length)
	report["caster_id"] = unit.id
	report["ability"] = String(ability.id)
	report["action_points_left"] = unit.action_points
	return report


## Recalcule l'annonce des ennemis adjacents à un provocateur.
func _retelegraph_adjacent(taunter: Unit) -> void:
	for enemy: Unit in _ordered(board.active_units(Unit.Side.ENEMIES)):
		if board.grid.distance(enemy.cell, taunter.cell) > 1:
			continue
		_intents[enemy.id] = ai.intent_here(board, enemy, _taunting)


# --- Annulation -----------------------------------------------------------

## Rien n'est irréversible tant que l'activation en cours n'est pas
## validée. La contrepartie est qu'une fois validée, elle l'est pour de
## bon : la pile est vidée à chaque nouvelle activation.
func can_undo() -> bool:
	return is_player_turn() and not _undo_stack.is_empty()


## Revient à l'état d'avant la dernière action du joueur.
func undo() -> bool:
	if not can_undo():
		return false
	_restore(_undo_stack.pop_back())
	return true


## Annule toute l'activation d'un coup.
func undo_all() -> bool:
	if not can_undo():
		return false
	_restore(_undo_stack[0])
	_undo_stack.clear()
	return true


func undo_depth() -> int:
	return _undo_stack.size()


# --- Fin d'activation -----------------------------------------------------

## Valide l'activation en cours et fait jouer tous les ennemis qui suivent,
## jusqu'à ce que ce soit de nouveau au joueur — ou que le combat s'arrête.
##
## Renvoie le journal ordonné des évènements, à rejouer par le rendu.
func end_activation() -> Array[Dictionary]:
	if phase != Phase.ACTIVE:
		return []
	var log: Array[Dictionary] = []
	_undo_stack.clear()
	_drain(log)
	return log


## Fait tourner la timeline jusqu'à ce que ce soit de nouveau au joueur,
## ou que le combat s'arrête.
func _drain(log: Array[Dictionary]) -> void:
	var guard := 0
	var limit := (board.units().size() + 1) * (maxi(_round_cap(), 1) + 1)
	while phase == Phase.ACTIVE:
		guard += 1
		if guard > limit:
			push_error("CombatEngine : la timeline ne progresse plus")
			return
		var previous_round := order.round_index
		if order.advance(board.units()) < 0:
			_settle(log)
			return
		if order.round_index != previous_round:
			_tick_terrain(log)
			log.append({"event": "round_started", "round": order.round_index})
			if _settle(log):
				return
		if _open_current(log):
			return
		if _settle(log):
			return


## Fait passer une ronde aux terrains temporaires : les feux s'éteignent.
func _tick_terrain(log: Array[Dictionary]) -> void:
	for cell: Vector2i in board.grid.cells():
		var tile := board.tile_at(cell)
		if tile != null and tile.tick_terrain():
			log.append({"event": "terrain_cleared", "cell": cell})


## Une activation d'ennemi : il exécute ce qu'il avait annoncé, PUIS se
## déplace, PUIS annonce pour la fois d'après. Cet ordre est ce qui rend le
## télégraphe honnête.
func _run_enemy(enemy: Unit, log: Array[Dictionary]) -> void:
	_execute_intent(enemy, log)
	if not enemy.is_active():
		return

	var plan := ai.plan(board, enemy, _taunting)
	var destination: Vector2i = plan["move_to"]
	if destination != enemy.cell:
		var from := enemy.cell
		var cost := board.move_cost_to(enemy, destination)
		if cost >= 0 and board.move_unit(enemy, destination):
			enemy.spend_movement_points(cost)
			log.append({
				"event": "enemy_moved", "unit_id": enemy.id,
				"from": from, "to": destination,
			})
			_check_lethal_landing(enemy, from)
	if enemy.is_active():
		_intents[enemy.id] = plan["intent"]
		log.append({"event": "telegraph_updated", "unit_id": enemy.id})


## Exécute l'intention annoncée. Elle frappe la case, pas l'unité : si le
## joueur a déplacé sa cible, le coup part dans le vide.
func _execute_intent(enemy: Unit, log: Array[Dictionary]) -> void:
	var intent: CombatIntent = _intents.get(enemy.id, null)
	if intent == null or not intent.is_attack():
		return
	var ability := intent.ability()
	if ability == null:
		return
	_intents[enemy.id] = CombatIntent.none(enemy.id)
	if not enemy.can_spend_action_points(ability.action_points):
		return
	enemy.spend_action_points(ability.action_points)
	enemy.start_cooldown(ability.id, ability.cooldown)

	var aimed := intent.target_cell(enemy.cell)
	var report := board.resolve_ability(enemy, ability, aimed)
	var hits: Array = report["hits"]
	if hits.is_empty():
		log.append({
			"event": "attack_missed", "attacker_id": enemy.id,
			"ability": String(ability.id), "cell": aimed,
			"cells": report["cells"],
		})
		return
	for hit: Dictionary in hits:
		log.append({
			"event": "attack_landed", "attacker_id": enemy.id,
			"ability": String(ability.id),
			"target_id": hit["target_id"], "cell": hit["cell"],
			"damage": hit["damage"], "downed": hit["downed"],
		})
	for downed_id: int in report["downed_ids"]:
		order.remove(downed_id)


func is_finished() -> bool:
	return phase == Phase.FINISHED


func is_victory() -> bool:
	return outcome == CombatObjective.Outcome.VICTORY


# --- Interne --------------------------------------------------------------

## Abandonne le combat : défaite immédiate.
##
## POURQUOI CETTE PORTE EXISTE. Sur mobile on est interrompu, et un combat
## dont on ne peut pas sortir se quitte par le bouton système — ce qui tue
## l'application et, avec elle, l'expédition. Mieux vaut une défaite que le
## joueur a choisie qu'une partie qu'il a perdue en fermant la fenêtre.
##
## C'est une VRAIE défaite, pas une sortie sans frais : l'expédition la
## traite comme n'importe quelle autre, avec la besace amputée du § 41.
func surrender() -> Array[Dictionary]:
	var log: Array[Dictionary] = []
	if is_finished():
		return log
	outcome = CombatObjective.Outcome.DEFEAT
	phase = Phase.FINISHED
	log.append({"event": "surrendered"})
	log.append({
		"event": "combat_ended",
		"victory": false,
		"round": order.round_index,
	})
	return log


func _round_cap() -> int:
	return int(CombatRules.rule(&"objectives", &"max_rounds_before_draw", 0))


## Regarde où en est l'objectif. Renvoie true si le combat s'arrête ici.
func _settle(log: Array[Dictionary]) -> bool:
	outcome = objective.evaluate(board, order.round_index)
	# Garde-fou : un combat doit toujours finir. Au-delà du plafond,
	# l'objectif n'a pas été rempli à temps, et c'est une défaite. Sans ça,
	# une escorte qu'on n'avance pas tourne sans fin.
	if outcome == CombatObjective.Outcome.ONGOING:
		var cap := _round_cap()
		if cap > 0 and order.round_index > cap:
			outcome = CombatObjective.Outcome.DEFEAT
			log.append({"event": "round_limit_reached", "round": order.round_index})
	if outcome == CombatObjective.Outcome.ONGOING:
		return false
	phase = Phase.FINISHED
	log.append({
		"event": "combat_ended",
		"victory": outcome == CombatObjective.Outcome.VICTORY,
		"round": order.round_index,
	})
	return true


## Ramassage de la cache d'un objectif « Extraire ». Il se fait en passant
## dessus, sans action : le coût de l'objectif est le détour, pas le geste.
func _check_pickup(unit: Unit) -> void:
	if objective.carried or objective.kind != CombatObjective.Kind.EXTRACT:
		return
	if unit.is_hero() and objective.pickup_cells.has(unit.cell):
		objective.carried = true


## Le joueur ne pilote que le personnage que la timeline désigne.
func _can_act(unit: Unit) -> bool:
	if phase != Phase.ACTIVE or unit == null or not unit.is_active():
		return false
	return unit.is_hero() and order.current() == unit.id


## Une unité qui finit sur une case mortelle y reste. Le déplacement passe
## par `can_stand_on`, donc un héros n'y va jamais de son plein gré ; ce
## garde-fou existe pour les cas indirects — un pont détruit sous les pieds.
func _check_lethal_landing(unit: Unit, _from: Vector2i) -> void:
	var tile := board.tile_at(unit.cell)
	if tile == null or not tile.is_lethal() or unit.aquatic or unit.flying:
		return
	unit.down()
	board.remove_from_board(unit)
	order.remove(unit.id)


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
		"phase": phase,
		"outcome": outcome,
		"order": order.to_dictionary(),
		"carried": objective.carried,
		"supplies": supplies.duplicate(),
		"rng": rng.position(),
		"pending": _pending.size(),
		"taunting": _taunting.duplicate(),
		"tiles": tiles,
		"units": units,
		"intents": intents,
	}


func _restore(state: Dictionary) -> void:
	phase = int(state["phase"])
	outcome = int(state["outcome"])
	objective.carried = bool(state["carried"])
	# Une potion annulée revient dans le sac : sans cette ligne, c'était le
	# seul geste du jeu qu'on ne pouvait pas reprendre.
	supplies = (state.get("supplies", {}) as Dictionary).duplicate()
	rng.rewind_to(state["rng"])
	_taunting = (state.get("taunting", []) as Array).duplicate()

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
		unit.action_points = int(raw["action_points"])
		unit.movement_points = int(raw["movement_points"])
		unit.cooldowns = (raw["cooldowns"] as Dictionary).duplicate()
		unit.statuses = (raw["statuses"] as Dictionary).duplicate()
		unit.state = int(raw["state"])
		unit.has_moved = bool(raw["has_moved"])

	order = TurnOrder.from_dictionary(state["order"], board.units())

	_intents.clear()
	for raw: Dictionary in state["intents"]:
		var intent := CombatIntent.from_dictionary(raw)
		_intents[intent.attacker_id] = intent
