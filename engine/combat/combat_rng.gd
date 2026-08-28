class_name CombatRng
extends RefCounted

## Générateur aléatoire à graine, journalisé.
##
## RÈGLE DURE : aucun `randi()` ni `randf()` en direct dans le jeu. Tout
## tirage passe par ici.
##
## Deux raisons, et la seconde est la vraie :
##  1. Un combat rejoué avec la même graine se déroule à l'identique.
##  2. Chaque tirage est journalisé avec sa raison. Quand un combat part de
##     travers, on ne relit pas le code en se demandant « qui a tiré ce
##     nombre » : on lit le journal, qui le dit.
##
## Classe pure : aucun nœud, testable en headless.

## Graine du combat. Sauvegardée avec la partie, affichable dans la console
## de debug (T10.1) pour rejouer un bug à l'identique.
var seed_value: int:
	get:
		return _seed

var _seed: int
var _rng := RandomNumberGenerator.new()
var _log: Array[Dictionary] = []
var _draws := 0


func _init(seed_to_use: int = 0) -> void:
	reset(seed_to_use)


## Repart de zéro sur une graine. Le journal est vidé.
func reset(seed_to_use: int) -> void:
	_seed = seed_to_use
	_rng.seed = seed_to_use
	_log.clear()
	_draws = 0


## Nombre de tirages effectués depuis la dernière remise à zéro.
func draw_count() -> int:
	return _draws


## Journal des tirages : { index, reason, kind, result }.
## Sert au rapport de bug et à la console de debug, jamais au gameplay.
func log_entries() -> Array[Dictionary]:
	return _log.duplicate(true)


## Entier dans [from, to], bornes comprises.
## `reason` est obligatoire : un tirage sans raison est un tirage qu'on ne
## saura pas expliquer trois semaines plus tard.
func int_between(from: int, to: int, reason: StringName) -> int:
	var result := _rng.randi_range(from, to)
	_record(reason, &"int_between", result)
	return result


## Flottant dans [0, 1[.
func unit_float(reason: StringName) -> float:
	var result := _rng.randf()
	_record(reason, &"unit_float", result)
	return result


## Vrai avec la probabilité donnée. `chance` vient toujours de `data/`.
func chance(probability: float, reason: StringName) -> bool:
	var draw := _rng.randf()
	var result := draw < probability
	_record(reason, &"chance", result)
	return result


## Un élément au hasard. Renvoie null sur un tableau vide.
func pick(options: Array, reason: StringName) -> Variant:
	if options.is_empty():
		push_error("CombatRng : tirage dans un tableau vide (%s)" % reason)
		return null
	var index := _rng.randi_range(0, options.size() - 1)
	_record(reason, &"pick", index)
	return options[index]


## Copie mélangée, sans toucher au tableau d'origine.
## Mélange de Fisher-Yates fait à la main : `Array.shuffle()` utilise le
## générateur global de Godot, qui n'est pas à graine.
func shuffled(options: Array, reason: StringName) -> Array:
	var out := options.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Variant = out[i]
		out[i] = out[j]
		out[j] = swap
	_record(reason, &"shuffled", out.size())
	return out


## Générateur dérivé, indépendant, pour un sous-système qu'on veut pouvoir
## rejouer seul sans dépendre de l'ordre des tirages précédents.
func derive(salt: int) -> CombatRng:
	return CombatRng.new(hash([_seed, salt]))


func _record(reason: StringName, kind: StringName, result: Variant) -> void:
	_log.append({
		"index": _draws,
		"reason": String(reason),
		"kind": String(kind),
		"result": result,
	})
	_draws += 1
