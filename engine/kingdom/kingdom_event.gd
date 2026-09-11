class_name KingdomEvent
extends RefCounted

## Le conseil du royaume : les évènements qui attendent au RETOUR, lus dans
## `data/kingdom/events.json` (T12.10).
##
## POURQUOI AU RETOUR. Le § 43 veut que chaque activité influence les
## autres. L'expédition influençait déjà la ville — le butin, la menace, le
## cycle de production — mais la ville ne lui rendait que des chiffres. Un
## conseil qui attend au retour donne à la ville sa PROPRE étape de
## décision, au même endroit de la boucle que « rentrer ou continuer » :
## on rentre, et quelque chose s'est passé pendant qu'on n'était pas là.
##
## CE QU'UN CONSEIL DÉPENSE N'EST PAS CE QU'UNE ÉTAPE DÉPENSE. Une étape
## d'expédition se paie en or et en points de vie ; un conseil se paie en
## BOIS, en PIERRE, en VIVRES et en GENS — la monnaie de la ville, celle
## que le joueur a passé son cycle à produire. Sans ça, le conseil serait
## une seconde étape d'expédition posée au mauvais endroit de la boucle.
##
## CETTE CLASSE NE CHANGE RIEN. Elle lit la table et résout la chance ;
## c'est `Kingdom.resolve_council` qui applique. Même frontière qu'entre
## `ExpeditionEvent` et `Expedition` : celui qui calcule n'est pas celui
## qui encaisse, sinon rien ne se teste seul.

const PATH := "res://data/kingdom/events.json"

static var _data: Dictionary = {}


## Vide le cache de données, pour les tests et le rechargement à chaud.
##
## PAS `reload()` : ce nom entre en collision avec `Script.reload()` de
## Godot, et c'est CELUI-LÀ qui était appelé (T7.4).
static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("KingdomEvent : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("KingdomEvent : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("KingdomEvent : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func _table() -> Dictionary:
	return data().get("events", {})


static func _pool() -> Dictionary:
	return data().get("pool", {})


## Combien de conseils récents on refuse de reproposer.
static func recent_kept() -> int:
	return maxi(int(_pool().get("recent", 0)), 0)


static func minimum_pool() -> int:
	return maxi(int(_pool().get("minimum_pool", 0)), 0)


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var keys: Array = _table().keys()
	keys.sort()
	for key: String in keys:
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


static func exists(event_id: StringName) -> bool:
	return _table().has(String(event_id))


static func entry(event_id: StringName) -> Dictionary:
	var table := _table()
	if not table.has(String(event_id)):
		push_error("KingdomEvent : conseil inconnu « %s »" % event_id)
		return {}
	return table[String(event_id)]


static func name_key(event_id: StringName) -> String:
	return String(entry(event_id).get("name_key", ""))


static func text_key(event_id: StringName) -> String:
	return String(entry(event_id).get("text_key", ""))


static func weight_of(event_id: StringName) -> int:
	return maxi(int(entry(event_id).get("weight", 0)), 0)


static func options(event_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for option: Variant in entry(event_id).get("options", []):
		out.append(option)
	return out


static func option(event_id: StringName, index: int) -> Dictionary:
	var all := options(event_id)
	if index < 0 or index >= all.size():
		return {}
	return all[index]


static func option_label(event_id: StringName, index: int) -> String:
	return String(option(event_id, index).get("label_key", ""))


## Chance de réussite d'une option. Un pour une option sans pari — c'est
## aussi ce qui permet à l'écran de n'afficher un pourcentage que là où il
## y en a un.
static func option_chance(event_id: StringName, index: int) -> float:
	return float(option(event_id, index).get("chance", 1.0))


static func option_gambles(event_id: StringName, index: int) -> bool:
	return option(event_id, index).has("chance")


## Ce qu'une option coûte, ressource par ressource, AU PIRE de ses deux
## issues. C'est ce chiffre qui décide si le joueur peut se la permettre,
## et c'est le pire qui compte : promettre une issue qu'on ne pourra pas
## payer serait un piège.
static func option_cost(event_id: StringName, index: int) -> Dictionary:
	var chosen := option(event_id, index)
	var worst := {}
	for branch: String in ["success", "failure"]:
		var effects: Dictionary = chosen.get(branch, {})
		for resource_id: StringName in ResourceTable.ids():
			var delta := int(effects.get(String(resource_id), 0))
			if delta < 0:
				worst[resource_id] = maxi(int(worst.get(resource_id, 0)), -delta)
	return worst


## Le crédit qu'un conseil exige pour se présenter, ou vide.
##
## LE CRÉDIT OUVRE DES OFFRES AU LIEU DE S'ACHETER. C'est ce qui le sépare
## de l'or : on n'achète pas un champion à Fort-Aubin, on obtient qu'il
## vous en confie un.
static func required_standing(event_id: StringName) -> Dictionary:
	return entry(event_id).get("requires_standing", {})


static func is_open(event_id: StringName, standings: Dictionary = {}) -> bool:
	var required := required_standing(event_id)
	if required.is_empty():
		return true
	var town_id := StringName(required.get("town", ""))
	return int(standings.get(town_id, 0)) >= int(required.get("minimum", 0))


## Les villes qu'un conseil met en jeu, dans l'ordre des données. Sert à
## l'écran : un conseil qui touche au crédit doit dire de QUI il parle.
static func towns_of(event_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var required := required_standing(event_id)
	if not required.is_empty():
		out.append(StringName(required.get("town", "")))
	for index in options(event_id).size():
		for branch: String in ["success", "failure"]:
			var effects: Dictionary = option(event_id, index).get(branch, {})
			for key: Variant in (effects.get("standing", {}) as Dictionary).keys():
				var town_id := StringName(key)
				if not out.has(town_id):
					out.append(town_id)
	return out


## Tire un conseil aux poids déclarés. `avoid` évite de reproposer les
## derniers vus — le seul rabâchage que le joueur remarque — et `standings`
## ferme ceux que le crédit n'a pas encore ouverts.
static func draw(rng: CombatRng, avoid: Array = [], standings: Dictionary = {}) -> StringName:
	var pool: Array[StringName] = []
	for event_id: StringName in ids():
		if (weight_of(event_id) > 0 and not avoid.has(String(event_id))
				and is_open(event_id, standings)):
			pool.append(event_id)
	if pool.is_empty():
		# Tout a été vu récemment : on rouvre la table plutôt que de ne
		# rien proposer. Le crédit, lui, reste respecté — rouvrir ne doit
		# pas offrir un champion à qui n'a jamais commercé.
		for event_id: StringName in ids():
			if weight_of(event_id) > 0 and is_open(event_id, standings):
				pool.append(event_id)
	if pool.is_empty():
		push_error("KingdomEvent : aucun conseil tirable")
		return &""

	var total := 0
	for event_id: StringName in pool:
		total += weight_of(event_id)
	if rng == null:
		return pool[0]
	var draw_value := rng.int_between(1, total, &"kingdom_event")
	for event_id: StringName in pool:
		draw_value -= weight_of(event_id)
		if draw_value <= 0:
			return event_id
	return pool[pool.size() - 1]


## Résout une option : tire la chance s'il y en a une, et rend les effets à
## appliquer, augmentés de l'issue obtenue.
##
## Le dé est jeté ICI et une seule fois. Le rejeter à l'application
## donnerait deux résultats à partir d'une même graine, et un pari qu'on ne
## peut pas rejouer est un pari qu'on ne peut pas déboguer.
static func resolve(event_id: StringName, index: int, rng: CombatRng) -> Dictionary:
	var chosen := option(event_id, index)
	if chosen.is_empty():
		push_error("KingdomEvent : « %s » n'a pas d'option %d" % [event_id, index])
		return {}

	var won := true
	if chosen.has("chance") and rng != null:
		won = rng.chance(clampf(float(chosen["chance"]), 0.0, 1.0), &"council_gamble")

	var effects: Dictionary = (chosen.get("success", {}) if won else chosen.get("failure", {})).duplicate()
	effects["event"] = String(event_id)
	effects["option"] = index
	effects["gambled"] = chosen.has("chance")
	effects["succeeded"] = won
	return effects
