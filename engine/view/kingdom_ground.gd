class_name KingdomGround
extends RefCounted

## Le sol du royaume, lu dans `data/kingdom/ground.json` (T12.11).
##
## CLASSE PURE, comme `TitleSet` : elle lit une table et rend des valeurs.
## Elle ne construit aucun nœud.
##
## POURQUOI ELLE EXISTE. Le terrain d'un royaume est du RESSENTI — où
## passe la rive, où s'arrête la clôture, à quelle vitesse dérive un
## nuage — et le ressenti ne se règle pas en réécrivant du code (règle 1).
## C'est exactement le genre d'endroit où on la viole sans y penser, parce
## que « ce n'est que du décor ».
##
## LA GRILLE EST LA TOILE. `canvas()` rend la taille en pixels de la
## grille, et c'est elle que `buildings.json` déclare : les emplacements
## des bâtiments sont donc des pixels de CE plateau, ce qui permet à
## `verify_kingdom` de refuser un château posé à l'eau.

const PATH := "res://data/kingdom/ground.json"

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
		push_error("KingdomGround : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("KingdomGround : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("KingdomGround : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


## Les rangées du terrain, dans l'alphabet des cartes de combat.
##
## C'EST UN VRAI PLATEAU, et c'est tout l'intérêt : bâti par
## `CombatBoard.from_rows`, le royaume hérite gratuitement des rives du
## tileset, de l'écume animée, des rochers d'eau et de la mer. Un décor
## peint à la main aurait fallu les redessiner, et aurait divergé au
## premier changement de terrain.
static func rows() -> PackedStringArray:
	var out := PackedStringArray()
	for row: Variant in data().get("rows", []):
		out.append(String(row))
	return out


static func tile_size() -> int:
	return maxi(int(data().get("tile", 64)), 1)


static func width() -> int:
	var all := rows()
	return all[0].length() if not all.is_empty() else 0


static func height() -> int:
	return rows().size()


## La taille de la toile, en pixels. C'est la grille : une constante
## recopiée dans `buildings.json` finirait par ne plus dire la même chose,
## et un bâtiment se retrouverait hors du terrain sans que rien ne le dise
## — ce qui est EXACTEMENT arrivé à la tour de guet en T12.8.
static func canvas() -> Vector2:
	return Vector2(width() * tile_size(), height() * tile_size())


## Le terrain d'une case, ou vide hors du plateau.
static func terrain_at(cell: Vector2i) -> StringName:
	var all := rows()
	if cell.y < 0 or cell.y >= all.size():
		return &""
	var row := all[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return &""
	return CombatRules.terrain_for_symbol(row[cell.x])


## La case où tombe un point en pixels de la toile.
static func cell_of(point: Vector2) -> Vector2i:
	var tile := float(tile_size())
	return Vector2i(int(floor(point.x / tile)), int(floor(point.y / tile)))


## Peut-on poser un bâtiment ici ? Un château à l'eau ou dans un rocher se
## dessinerait très bien, et se lirait comme un défaut.
static func can_stand_at(point: Vector2) -> bool:
	var terrain := terrain_at(cell_of(point))
	if terrain.is_empty():
		return false
	return bool(CombatRules.terrain_property(terrain, &"walkable", false))


static func props() -> Array:
	return data().get("props", [])


static func clouds() -> Array:
	return data().get("clouds", [])


# --- La clôture ------------------------------------------------------------
#
# ELLE EST DÉCLARÉE À PART DU TERRAIN, et c'est la capture qui l'a imposé.
# Le terrain `palisade` n'a qu'UNE tuile pour tout le jeu — la verticale —
# parce qu'une case de combat ne sait pas si elle est un bout de ligne ou
# un coin. Posée en rangée, elle donnait des PIQUETS ISOLÉS espacés de
# 64 px, pas une enceinte.
#
# Le royaume, lui, SAIT où sont ses coins : sa clôture ne bouge jamais.

static func _fence() -> Dictionary:
	return data().get("fence", {})


static func fence_atlas() -> StringName:
	return StringName(_fence().get("atlas", ""))


## La case d'atlas d'un morceau nommé — « start », « run », « end »… Les
## indices vivent dans les données : un numéro de tuile écrit dans un `.gd`
## est exactement ce que la règle 1 refuse.
static func fence_part(part: StringName) -> Vector2i:
	var declared: Array = (_fence().get("parts", {}) as Dictionary).get(String(part), [])
	if declared.size() < 2:
		return Vector2i(-1, -1)
	return Vector2i(int(declared[0]), int(declared[1]))


## Les morceaux de clôture à poser, case par case : { cell, part }.
##
## LE PREMIER ET LE DERNIER SONT DES BOUTS, le reste alterne. Alterner
## n'est pas décoratif : les deux traverses du pack ne portent pas leur
## nœud de corde au même endroit, et une rangée d'un seul morceau se lit
## comme un motif répété plutôt que comme une clôture.
static func fence_pieces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in (_fence().get("lines", []) as Array):
		var line: Dictionary = entry
		var row := int(line.get("row", 0))
		var first := int(line.get("from", 0))
		var last := int(line.get("to", 0))
		for column in range(first, last + 1):
			var part := &"run" if (column - first) % 2 == 0 else &"run_alt"
			if column == first:
				part = &"start"
			elif column == last:
				part = &"end"
			out.append({"cell": Vector2i(column, row), "part": part})
	return out
