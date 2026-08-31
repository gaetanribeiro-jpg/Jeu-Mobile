class_name ResourceTable
extends RefCounted

## Les quatre ressources du § 6, lues dans `data/kingdom/resources.json`.
##
## OÙ VIT CHAQUE RESSOURCE, ET POURQUOI CE N'EST PAS UNIFORME. L'or vit
## avec la COMPAGNIE : ce sont les héros qui le gagnent sur la route et qui
## le dépensent chez le marchand, en pleine expédition, loin du royaume.
## Lui faire une seconde bourse au royaume obligerait à tenir les deux
## d'accord, et deux bourses qui doivent rester d'accord finissent toujours
## par ne plus l'être. Les trois autres vivent dans les réserves du
## royaume : personne ne transporte une carrière.
##
## `holder` dit donc où lire chaque ressource, et c'est la seule chose que
## l'appelant a besoin de savoir.

const PATH := "res://data/kingdom/resources.json"

const HOLDER_KINGDOM := &"kingdom"
const HOLDER_COMPANY := &"company"

static var _data: Dictionary = {}


static func reload() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("ResourceTable : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("ResourceTable : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ResourceTable : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func _table() -> Dictionary:
	return data().get("resources", {})


## Les ressources dans l'ordre du § 6 : bois, pierre, or, nourriture.
## L'ordre du fichier est l'ordre d'affichage, et il est voulu.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in _table().keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


static func exists(resource_id: StringName) -> bool:
	return _table().has(String(resource_id))


static func entry(resource_id: StringName) -> Dictionary:
	var table := _table()
	if not table.has(String(resource_id)):
		push_error("ResourceTable : ressource inconnue « %s »" % resource_id)
		return {}
	return table[String(resource_id)]


static func name_key(resource_id: StringName) -> String:
	return String(entry(resource_id).get("name_key", ""))


static func asset_of(resource_id: StringName) -> String:
	return String(entry(resource_id).get("asset", ""))


static func holder_of(resource_id: StringName) -> StringName:
	return StringName(entry(resource_id).get("holder", HOLDER_KINGDOM))


static func lives_in_kingdom(resource_id: StringName) -> bool:
	return holder_of(resource_id) == HOLDER_KINGDOM


static func starting_amount(resource_id: StringName) -> int:
	return int(entry(resource_id).get("start", 0))
