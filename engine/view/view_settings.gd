class_name ViewSettings
extends RefCounted

## Accès aux valeurs de présentation du combat (`data/combat/view.json`).
##
## Séparé de `CombatRules`, qui porte les règles du jeu. Ici vivent les
## couleurs, les durées et les tailles : tout ce qui touche au ressenti,
## c'est-à-dire précisément la partie que je ne peux pas juger seul. Elle
## se règle sans toucher au code.

const VIEW_PATH := "res://data/combat/view.json"

static var _view: Dictionary = {}


static func reload() -> void:
	_view = {}


static func all() -> Dictionary:
	if not _view.is_empty():
		return _view
	if not FileAccess.file_exists(VIEW_PATH):
		push_error("ViewSettings : %s introuvable" % VIEW_PATH)
		return {}
	var file := FileAccess.open(VIEW_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ViewSettings : %s n'est pas un objet JSON" % VIEW_PATH)
		return {}
	_view = parsed
	return _view


static func section(name_: StringName) -> Dictionary:
	return all().get(String(name_), {})


static func number(section_name: StringName, key: StringName, fallback: float = 0.0) -> float:
	var block := section(section_name)
	if not block.has(String(key)):
		push_error("ViewSettings : « %s.%s » absent de view.json" % [section_name, key])
		return fallback
	return float(block[String(key)])


static func integer(section_name: StringName, key: StringName, fallback: int = 0) -> int:
	return int(number(section_name, key, float(fallback)))


## Couleur nommée, lue comme [r, g, b, a].
static func color(key: StringName) -> Color:
	var raw: Variant = section(&"colors").get(String(key), null)
	if raw == null:
		push_error("ViewSettings : couleur « %s » absente de view.json" % key)
		return Color.MAGENTA
	var values: Array = raw
	return Color(
		float(values[0]), float(values[1]), float(values[2]),
		float(values[3]) if values.size() > 3 else 1.0
	)


static func duration(key: StringName) -> float:
	return number(&"durations", key, 0.0)


static func size_of(key: StringName) -> float:
	return number(&"sizes", key, 0.0)


## Coin haut-gauche du bloc 4 x 4 dans lequel se prend un terrain.
static func terrain_block_origin(terrain_id: StringName) -> Vector2i:
	var block_name := String(section(&"terrain_block_of").get(String(terrain_id), "land"))
	var raw: Variant = section(&"terrain_blocks").get(block_name, [0, 0])
	var cell: Array = raw
	return Vector2i(int(cell[0]), int(cell[1]))


## Tuile à prendre dans un bloc 4 x 4 selon les voisins du même milieu.
##
## Le bloc encode CHAQUE AXE sur quatre états, et pas trois comme on
## l'attendrait — relevé sur les fichiers, pas supposé :
##   1 = aucun bord      (les deux voisins sont du même milieu)
##   0 = bord avant      (rien à gauche, ou rien au-dessus)
##   2 = bord après      (rien à droite, ou rien en dessous)
##   3 = les deux bords  (une bande d'une case de large ou de haut)
##
## Sans le quatrième état, une bande d'une seule case reçoit un bord d'un
## côté et pas de l'autre : la rive s'arrête net au milieu de l'herbe.
static func terrain_tile_region(
	terrain_id: StringName, tile_size: int,
	land_left: bool = true, land_right: bool = true,
	land_up: bool = true, land_down: bool = true
) -> Rect2:
	var origin := terrain_block_origin(terrain_id)
	return Rect2(
		(origin.x + _edge_index(land_left, land_right)) * tile_size,
		(origin.y + _edge_index(land_up, land_down)) * tile_size,
		tile_size, tile_size
	)


static func _edge_index(before: bool, after: bool) -> int:
	if not before and not after:
		return 3
	if not before:
		return 0
	if not after:
		return 2
	return 1


## Décoration posée sur un terrain : { category, key }, ou {} s'il n'y en a pas.
static func terrain_decoration(terrain_id: StringName) -> Dictionary:
	var raw: Variant = section(&"terrain_decorations").get(String(terrain_id), null)
	if raw == null:
		return {}
	var pair: Array = raw
	var out := {"category": StringName(pair[0]), "key": StringName(pair[1])}
	# Une entrée d'atlas peut préciser la cellule voulue : [cat, clé, col, rangée].
	if pair.size() >= 4:
		out["cell"] = Vector2i(int(pair[2]), int(pair[3]))
	return out
