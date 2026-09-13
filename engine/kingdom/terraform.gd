class_name Terraform
extends RefCounted

## Façonner le sol du royaume (T12.15), lu dans `data/kingdom/terraform.json`.
##
## CLASSE PURE. Elle ne connaît ni `Kingdom` ni aucun nœud : elle prend des
## rangées de terrain, rend des rangées de terrain, et dit pourquoi elle
## refuse. C'est ce qui permet de la faire tourner en tête dans un test
## sans monter un royaume entier, et c'est la règle 2.
##
## CE QU'ON FAÇONNE EST CE SUR QUOI ON SE BAT. Le § 38 fabrique la carte de
## la bataille de défense à partir du royaume ; elle n'en prenait que les
## bâtiments, posés sur douze colonnes d'herbe nue. Élever une butte
## derrière la porte donne donc une hauteur aux archers le jour de
## l'assaut, et creuser des douves oblige les assaillants à contourner.
## Sans ça, façonner son île serait de la décoration — et le carnet refuse
## les bâtiments décoratifs depuis le premier jour.
##
## AUCUN CHIFFRE ICI. Les coûts, les terrains de départ et d'arrivée sont
## dans la table : ce sont des réglages, et la règle 1 ne fait pas
## d'exception pour un chantier.

const PATH := "res://data/kingdom/terraform.json"

static var _data: Dictionary = {}


## Vide le cache. PAS `reload()` — ce nom est celui de `Script.reload()`
## et c'est CELUI-LÀ qui était appelé (T7.4).
static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("Terraform : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Terraform : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Terraform : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


## Les travaux déclarés, dans l'ordre du fichier.
static func work_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in (data().get("works", {}) as Dictionary).keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


static func exists(work_id: StringName) -> bool:
	return (data().get("works", {}) as Dictionary).has(String(work_id))


## L'entrée d'un travail. Rend vide pour un inconnu SANS pousser d'erreur :
## même distinction qu'`AssetTable.has()` contre `sprite()` — un appelant
## qui demande « est-ce que ça existe » ne doit pas faire rougir la console.
static func entry(work_id: StringName) -> Dictionary:
	return (data().get("works", {}) as Dictionary).get(String(work_id), {})


static func name_key(work_id: StringName) -> String:
	return String(entry(work_id).get("name_key", ""))


static func hint_key(work_id: StringName) -> String:
	return String(entry(work_id).get("hint_key", ""))


static func cost(work_id: StringName) -> Dictionary:
	return entry(work_id).get("cost", {})


## Les terrains sur lesquels ce travail s'applique.
static func sources(work_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for raw: Variant in (entry(work_id).get("from", []) as Array):
		out.append(StringName(raw))
	return out


static func target(work_id: StringName) -> StringName:
	return StringName(entry(work_id).get("to", ""))


## Ce travail exige-t-il une case de terre voisine ? Gagner sur la mer,
## oui : une case posée au large serait injoignable (T12.1).
static func needs_shore(work_id: StringName) -> bool:
	return bool(entry(work_id).get("needs_shore", false))


## Pourquoi ce travail est refusé ici, ou &"" s'il est permis.
##
## `taken` porte les cases déjà occupées par un bâtiment ou un chantier :
## araser sous un château le laisserait en l'air, et l'inonder le noierait.
## La liste vient de l'appelant parce que cette classe ne connaît pas le
## royaume — c'est ce qui la garde pure.
static func refusal(
	rows: PackedStringArray, cell: Vector2i, work_id: StringName,
	taken: Array[Vector2i] = []
) -> StringName:
	if not exists(work_id):
		return &"TERRAFORM_UNKNOWN"
	if not _inside(rows, cell):
		return &"TERRAFORM_OFF_BOARD"
	if not sources(work_id).has(_terrain_at(rows, cell)):
		return &"TERRAFORM_WRONG_GROUND"
	if taken.has(cell):
		return &"TERRAFORM_OCCUPIED"
	if needs_shore(work_id) and not _touches_land(rows, cell):
		return &"TERRAFORM_NO_SHORE"

	# ON NE COUPE PAS SON ÎLE EN DEUX, ni on n'en détache un bout : c'est
	# la leçon de T12.1, « de la terre INJOIGNABLE au quart de l'écran ».
	# Un étang mal placé donnerait une rive où plus rien ne peut aller, et
	# rien ne s'en plaindrait — surtout pas le jour de l'assaut.
	var after := applied(rows, cell, work_id)
	if _islands(after) > _islands(rows):
		return &"TERRAFORM_WOULD_SPLIT"
	return &""


static func allowed(
	rows: PackedStringArray, cell: Vector2i, work_id: StringName,
	taken: Array[Vector2i] = []
) -> bool:
	return refusal(rows, cell, work_id, taken).is_empty()


## Les rangées après le travail. Ne vérifie rien : `refusal` est là pour ça,
## et séparer les deux permet d'ESSAYER un changement avant de l'accepter —
## c'est ainsi que la coupure de l'île est détectée.
static func applied(
	rows: PackedStringArray, cell: Vector2i, work_id: StringName
) -> PackedStringArray:
	var out := PackedStringArray(rows)
	if not _inside(out, cell) or not exists(work_id):
		return out
	var symbol := String(CombatRules.terrain_property(target(work_id), &"symbol", "."))
	var line := out[cell.y]
	out[cell.y] = line.substr(0, cell.x) + symbol + line.substr(cell.x + 1)
	return out


# --- Lecture du plateau ----------------------------------------------------

static func _inside(rows: PackedStringArray, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= rows.size():
		return false
	return cell.x >= 0 and cell.x < rows[cell.y].length()


static func _terrain_at(rows: PackedStringArray, cell: Vector2i) -> StringName:
	if not _inside(rows, cell):
		return &""
	return CombatRules.terrain_for_symbol(rows[cell.y][cell.x])


static func _walkable(rows: PackedStringArray, cell: Vector2i) -> bool:
	var terrain := _terrain_at(rows, cell)
	if terrain.is_empty():
		return false
	return bool(CombatRules.terrain_property(terrain, &"walkable", false))


static func _touches_land(rows: PackedStringArray, cell: Vector2i) -> bool:
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _walkable(rows, cell + step):
			return true
	return false


## Le nombre de morceaux de terre séparés. Un rocher reste de la terre
## pour l'œil mais pas pour les pieds : c'est la marche qui compte ici,
## comme dans `verify_maps`.
static func _islands(rows: PackedStringArray) -> int:
	var seen := {}
	var count := 0
	for y in rows.size():
		for x in rows[y].length():
			var cell := Vector2i(x, y)
			if seen.has(cell) or not _walkable(rows, cell):
				continue
			count += 1
			var stack: Array[Vector2i] = [cell]
			seen[cell] = true
			while not stack.is_empty():
				var here: Vector2i = stack.pop_back()
				for step: Vector2i in [
					Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN
				]:
					var next := here + step
					if seen.has(next) or not _walkable(rows, next):
						continue
					seen[next] = true
					stack.append(next)
	return count
