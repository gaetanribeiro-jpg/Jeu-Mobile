class_name TitleSet
extends RefCounted

## Le décor de l'écran de titre, lu dans `data/ui/title.json`.
##
## CLASSE PURE, comme `ViewSettings` et `UiTheme` : elle lit une table et
## rend des valeurs. Elle ne construit aucun nœud et ne connaît pas Godot
## au-delà de ses types de base.
##
## POURQUOI ELLE EXISTE. L'écran de titre est du RESSENTI — où est l'île,
## à quelle vitesse dérivent les nuages, quelle classe se tient où — et le
## ressenti ne se règle pas en réécrivant du code. C'est la règle 1 du
## projet, et un écran de titre est exactement le genre d'endroit où on la
## viole sans y penser, parce que « ce n'est que du décor ».

const PATH := "res://data/ui/title.json"

static var _data: Dictionary = {}


## Vide le cache, pour les tests et le rechargement à chaud.
##
## PAS `reload()` : ce nom entre en collision avec `Script.reload()` de
## Godot, et c'est celui-là qui serait appelé.
static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("TitleSet : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("TitleSet : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("TitleSet : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func section(name_: StringName) -> Dictionary:
	return data().get(String(name_), {})


## Les rangées de l'île, dans l'alphabet des cartes de combat.
##
## C'EST UN VRAI PLATEAU, et c'est tout l'intérêt : bâtie par
## `CombatBoard.from_rows`, l'île hérite gratuitement des rives du
## tileset, de l'écume animée, des rochers et de la mer. Un décor peint à
## la main aurait fallu les redessiner, et aurait divergé au premier
## changement de terrain.
static func island_rows() -> PackedStringArray:
	var out := PackedStringArray()
	for row: Variant in section(&"island").get("rows", []):
		out.append(String(row))
	return out


## Les décors posés sur l'île : bâtiments, arbres, moutons, barques.
static func props() -> Array:
	return section(&"props").get("entries", [])


## Les personnages qui s'y tiennent, animés en attente.
static func actors() -> Array:
	return section(&"actors").get("entries", [])


static func clouds() -> Dictionary:
	return section(&"clouds")


static func scrim() -> Dictionary:
	return section(&"scrim")


static func tile_size() -> int:
	return int(section(&"camera").get("tile_size", 64))


## La taille de référence du décor, en cases. Elle sert à le mettre à
## l'échelle de la fenêtre.
static func reference_size() -> Vector2i:
	var raw: Array = section(&"camera").get("reference", [])
	if raw.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(raw[0]), int(raw[1]))


## Position d'une entrée, en pixels, décalage compris.
##
## POSÉ AU BAS DE SA CASE, comme les décors de terrain : un sprite du pack
## se dessine les pieds sur le sol, jamais centré sur la case. Le décalage
## casse l'alignement sur la grille — sans lui, le décor a l'air d'un
## damier.
static func anchor_of(entry: Dictionary, tile: int) -> Vector2:
	var cell: Array = entry.get("cell", [0, 0])
	var offset: Array = entry.get("offset", [0, 0])
	return Vector2(
		(float(cell[0]) + 0.5) * float(tile) + float(offset[0]),
		float(cell[1] + 1) * float(tile) + float(offset[1])
	)
