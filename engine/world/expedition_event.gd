class_name ExpeditionEvent
extends RefCounted

## Les évènements du § 40, lus dans `data/world/events.json`.
##
## LA LIGNE QUI GOUVERNE TOUT : « les événements doivent créer des
## décisions ». Un évènement qui donne trente pièces d'or n'est pas un
## évènement, c'est une récompense déguisée en texte. Chacun offre donc au
## moins deux options qui s'excluent, et `verify_world` refuse celui qui
## n'en aurait qu'une ou dont une option dominerait l'autre sur toute la
## ligne.
##
## L'ÉVÈNEMENT SE TIRE À L'ARRIVÉE, pas au départ. La route est connue
## d'avance — c'est ce qui permet de décider si l'on rentre (§ 29) — mais
## elle dit « un évènement », pas lequel. Le § 40 les appelle aléatoires ;
## les afficher trois rencontres à l'avance leur retirerait le seul effet
## que ce mot décrit.
##
## CETTE CLASSE NE CHANGE RIEN. Elle lit la table et résout la chance ;
## c'est `Expedition` qui applique. La frontière est la même qu'entre
## `CombatRewards` et `Company` : celui qui calcule n'est pas celui qui
## encaisse, sinon rien ne se teste seul.

const PATH := "res://data/world/events.json"

static var _data: Dictionary = {}


## Vide le cache de données, pour les tests et le rechargement à chaud.
##
## PAS `reload()` : ce nom entre en collision avec `Script.reload()` de
## Godot, et c'est CELUI-LÀ qui était appelé — « Cannot reload script while
## instances exist », 472 fois par exécution des tests. Le cache n'était
## donc jamais vidé, et la table de données que le test croyait relire
## était celle du test précédent.
static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("ExpeditionEvent : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("ExpeditionEvent : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ExpeditionEvent : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func _table() -> Dictionary:
	return data().get("events", {})


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
		push_error("ExpeditionEvent : évènement inconnu « %s »" % event_id)
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


## Ce qu'une option coûte en or, au pire de ses deux issues. C'est ce
## chiffre qui décide si le joueur peut se la permettre.
static func option_gold_cost(event_id: StringName, index: int) -> int:
	var chosen := option(event_id, index)
	var worst := 0
	for branch: String in ["success", "failure"]:
		var effects: Dictionary = chosen.get(branch, {})
		worst = mini(worst, int(effects.get("gold", 0)))
	return -worst


## Une option qu'on ne peut pas payer reste PROPOSÉE, grisée : savoir ce
## qu'on ne peut pas s'offrir fait partie de la décision.
static func can_afford(event_id: StringName, index: int, purse: int) -> bool:
	return purse >= option_gold_cost(event_id, index)


## Tire un évènement aux poids déclarés. `avoid` évite de servir deux fois
## le même dans la même sortie — le seul rabâchage que le joueur remarque.
static func draw(rng: CombatRng, avoid: Array = []) -> StringName:
	var pool: Array[StringName] = []
	for event_id: StringName in ids():
		if weight_of(event_id) > 0 and not avoid.has(String(event_id)):
			pool.append(event_id)
	if pool.is_empty():
		# Tout a déjà été vu : on rouvre la table plutôt que de rendre une
		# étape vide, qui serait un trou dans la chaîne.
		for event_id: StringName in ids():
			if weight_of(event_id) > 0:
				pool.append(event_id)
	if pool.is_empty():
		push_error("ExpeditionEvent : aucun évènement tirable")
		return &""

	var total := 0
	for event_id: StringName in pool:
		total += weight_of(event_id)
	if rng == null:
		return pool[0]
	var draw_value := rng.int_between(1, total, &"expedition_event")
	for event_id: StringName in pool:
		draw_value -= weight_of(event_id)
		if draw_value <= 0:
			return event_id
	return pool[pool.size() - 1]


## Résout une option : tire la chance s'il y en a une, et rend les effets
## à appliquer, augmentés de l'issue obtenue.
##
## Le dé est jeté ICI et une seule fois. Le rejeter à l'application
## donnerait deux résultats à partir d'une même graine, et un pari qu'on ne
## peut pas rejouer est un pari qu'on ne peut pas déboguer.
static func resolve(event_id: StringName, index: int, rng: CombatRng) -> Dictionary:
	var chosen := option(event_id, index)
	if chosen.is_empty():
		push_error("ExpeditionEvent : « %s » n'a pas d'option %d" % [event_id, index])
		return {}

	var won := true
	if chosen.has("chance") and rng != null:
		won = rng.chance(clampf(float(chosen["chance"]), 0.0, 1.0), &"event_gamble")

	var effects: Dictionary = (chosen.get("success", {}) if won else chosen.get("failure", {})).duplicate()
	effects["event"] = String(event_id)
	effects["option"] = index
	effects["gambled"] = chosen.has("chance")
	effects["succeeded"] = won
	return effects
