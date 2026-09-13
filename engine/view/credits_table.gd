class_name CreditsTable
extends RefCounted

## Les crédits du jeu, lus dans `data/ui/credits.json`.
##
## CLASSE PURE, comme `UiTheme` et `TitleSet`.
##
## POURQUOI CE N'EST PAS DU TEXTE EN DUR DANS L'ÉCRAN. Une attribution qui
## vit dans le code d'un écran est une attribution qu'on oublie de mettre
## à jour le jour où on ajoute un pack — et pour game-icons.net, en
## CC BY 3.0, l'oublier n'est pas une négligence de style : c'est une
## violation de licence. La table est la même liste que `CREDITS.md`, à
## ceci près que celle-ci, le joueur la lit.

const PATH := "res://data/ui/credits.json"

static var _data: Dictionary = {}


static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("CreditsTable : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("CreditsTable : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CreditsTable : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func sections() -> Array:
	return data().get("sections", [])


## Toutes les entrées, sections confondues. C'est ce dont un vérificateur
## a besoin : il ne juge pas la mise en page, il juge que rien ne manque.
static func entries() -> Array:
	var out: Array = []
	for section: Variant in sections():
		out.append_array((section as Dictionary).get("entries", []))
	return out
