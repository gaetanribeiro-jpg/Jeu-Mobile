class_name Neighbour
extends RefCounted

## Les villes voisines, lues dans `data/kingdom/neighbours.json` (T12.10).
##
## ELLES N'EXISTENT QUE PAR LES ÉVÈNEMENTS, et c'est délibéré. Le marchand
## du § 40 n'a jamais eu d'écran non plus : il arrive, il propose, il
## repart. Un écran de diplomatie écrit avant d'avoir la moindre offre à y
## mettre serait une coquille — on écrit d'abord ce qui se DÉCIDE, l'écran
## vient quand il y a de quoi le remplir.
##
## LE CRÉDIT EST UNE MÉMOIRE, PAS UNE MONNAIE. Il monte quand on commerce,
## il descend quand on refuse, et il OUVRE des offres au lieu de s'acheter :
## au-delà d'un certain crédit Fort-Aubin propose son champion, et aucune
## somme d'or ne remplace les échanges qu'il a fallu pour y arriver. C'est
## la même différence qu'entre acheter un objet et en trouver un.
##
## ON NE PEUT PAS ÊTRE L'AMI DE TOUT LE MONDE, et c'est la querelle qui
## l'impose : soutenir Valmont fâche Roche-Claire. Sans un évènement à
## somme nulle, le crédit ne serait qu'un compteur qui monte, donc une
## barre de progression déguisée en diplomatie.
##
## CLASSE PURE, comme tout `engine/`. Elle lit la table ; c'est `Kingdom`
## qui tient les crédits et `KingdomEvent` qui les fait bouger.

const PATH := "res://data/kingdom/neighbours.json"

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
		push_error("Neighbour : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Neighbour : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Neighbour : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func _table() -> Dictionary:
	return data().get("towns", {})


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var keys: Array = _table().keys()
	keys.sort()
	for key: String in keys:
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


static func exists(town_id: StringName) -> bool:
	return _table().has(String(town_id))


static func entry(town_id: StringName) -> Dictionary:
	var table := _table()
	if not table.has(String(town_id)):
		push_error("Neighbour : ville inconnue « %s »" % town_id)
		return {}
	return table[String(town_id)]


static func name_key(town_id: StringName) -> String:
	return String(entry(town_id).get("name_key", ""))


static func description_key(town_id: StringName) -> String:
	return String(entry(town_id).get("description_key", ""))


## La ressource dont la ville fait commerce. Elle ne sert pas au calcul —
## les échanges sont écrits dans les évènements — mais à l'écrire sur la
## fiche : « Valmont, les greniers » se retient, « Valmont » ne se retient
## pas.
static func trade_of(town_id: StringName) -> StringName:
	return StringName(entry(town_id).get("trade", ""))


# --- Le crédit -------------------------------------------------------------

static func _standing() -> Dictionary:
	return data().get("standing", {})


static func minimum() -> int:
	return int(_standing().get("minimum", 0))


static func maximum() -> int:
	return int(_standing().get("maximum", 0))


static func clamp_standing(value: int) -> int:
	return clampi(value, minimum(), maximum())


static func levels() -> Array:
	return _standing().get("levels", [])


## Le nom du palier où tombe un crédit. L'écran dit « cordial » plutôt que
## « +1 », qui ne veut rien dire pour personne.
## La couleur du palier où tombe un crédit — le NOM d'une couleur de la
## palette, jamais un code (règle de T11.6). `verify_kingdom` refuse une
## couleur inconnue.
static func standing_tint(value: int) -> StringName:
	var found := &""
	for level: Variant in levels():
		var step: Dictionary = level
		if value >= int(step.get("from", 0)):
			found = StringName(step.get("tint", ""))
	return found


static func standing_key(value: int) -> String:
	var found := ""
	for level: Variant in levels():
		var step: Dictionary = level
		if value >= int(step.get("from", 0)):
			found = String(step.get("name_key", ""))
	if found.is_empty() and not levels().is_empty():
		found = String((levels()[0] as Dictionary).get("name_key", ""))
	return found
