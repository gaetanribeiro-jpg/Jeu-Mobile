class_name WorldAtlas
extends RefCounted

## La carte du monde, lue dans `data/world/atlas.json` (T12.11).
##
## CLASSE PURE, comme `TitleSet` et `KingdomGround` : elle lit une table et
## rend des valeurs. Elle ne construit aucun nœud.
##
## POURQUOI ELLE EXISTE. Une carte est du RESSENTI — où est une terre par
## rapport à une autre, jusqu'où va la côte, par où passe la route — et le
## ressenti se règle dans les données, pas dans un `.gd` (règle 1). C'est
## exactement le genre d'endroit où on la viole sans y penser, parce que
## « ce ne sont que des coordonnées ».
##
## LE NOM MENTAIT DEPUIS T3.6. L'écran s'appelait « carte du monde » et
## empilait six boîtes rectangulaires : rien n'y disait où sont les Dunes
## par rapport aux Terres Vertes. Le § 27 — « le joueur découvre » —
## n'avait rien à découvrir.

const PATH := "res://data/world/atlas.json"

## Le nœud de départ : l'île du royaume. Ce n'est pas une région — on n'y
## part pas en expédition — mais c'est un bout de route.
const HOME := &"home"

static var _data: Dictionary = {}


## Vide le cache, pour les tests et le rechargement à chaud.
##
## PAS `reload()` : ce nom entre en collision avec `Script.reload()` de
## Godot, et c'est CELUI-LÀ qui était appelé (T7.4).
static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("WorldAtlas : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("WorldAtlas : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("WorldAtlas : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func canvas() -> Vector2:
	var declared: Array = data().get("canvas", [])
	if declared.size() < 2:
		return Vector2.ZERO
	return Vector2(float(declared[0]), float(declared[1]))


static func _entry(node_id: StringName) -> Dictionary:
	if node_id == HOME:
		return data().get("home", {})
	return (data().get("regions", {}) as Dictionary).get(String(node_id), {})


static func has_node(node_id: StringName) -> bool:
	return not _entry(node_id).is_empty()


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var keys: Array = (data().get("regions", {}) as Dictionary).keys()
	keys.sort()
	for key: String in keys:
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


## Le contour d'une terre. Un polygone, pas un rectangle : six carrés
## identiques obligent à LIRE, et c'est ce qu'on remplace.
static func shape_of(node_id: StringName) -> PackedVector2Array:
	var out := PackedVector2Array()
	for raw: Variant in _entry(node_id).get("shape", []):
		var point: Array = raw
		if point.size() >= 2:
			out.append(Vector2(float(point[0]), float(point[1])))
	return out


static func _point(entry: Dictionary, key: String) -> Vector2:
	var declared: Array = entry.get(key, [])
	if declared.size() < 2:
		return Vector2.ZERO
	return Vector2(float(declared[0]), float(declared[1]))


## Le cœur d'une terre : là où aboutit une route et où se pose un repère.
static func anchor_of(node_id: StringName) -> Vector2:
	var entry := _entry(node_id)
	if entry.has("at"):
		return _point(entry, "at")
	return _point(entry, "castle")


static func label_of(node_id: StringName) -> Vector2:
	return _point(_entry(node_id), "label")


static func castle() -> Vector2:
	return _point(data().get("home", {}), "castle")


# --- Les villes voisines ---------------------------------------------------

static func towns() -> Array[StringName]:
	var out: Array[StringName] = []
	var keys: Array = (data().get("towns", {}) as Dictionary).keys()
	keys.sort()
	for key: String in keys:
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


static func town(town_id: StringName) -> Dictionary:
	return (data().get("towns", {}) as Dictionary).get(String(town_id), {})


static func town_at(town_id: StringName) -> Vector2:
	return _point(town(town_id), "at")


# --- Les routes ------------------------------------------------------------

## Les routes, dans l'ordre des actes. Chacune est un couple de nœuds.
##
## LA ROUTE REND L'ORDRE LISIBLE. Sans elle, six terres posées sur une mer
## sont six terres ; avec elle, c'est un chemin, et on voit d'un coup d'œil
## que l'Empire est au bout.
static func roads() -> Array[Array]:
	var out: Array[Array] = []
	for raw: Variant in data().get("roads", []):
		var pair: Array = raw
		if pair.size() >= 2:
			out.append([StringName(pair[0]), StringName(pair[1])])
	return out
