class_name AssetTable
extends RefCounted

## Accès unique aux fichiers du pack Tiny Swords.
##
## RÈGLE DURE : aucun chemin de fichier n'est écrit ailleurs que dans
## `data/assets.json`. Tout le code passe par ici. Le jour où Pixel Frog
## réorganise le pack, une seule ligne de JSON change.
##
## Le pack n'étant pas versionné (sa licence interdit la redistribution),
## une entrée manquante doit produire une erreur lisible, jamais un crash :
## toutes les fonctions renvoient un dictionnaire vide et poussent une
## erreur nommée.
##
## Chaque entrée renvoyée porte un `kind` qui dit comment la lire :
##   KIND_IMAGE : une seule image      → w, h
##   KIND_STRIP : bande d'animation    → frames, frame_w, frame_h
##   KIND_ATLAS : grille de cellules   → columns, rows, cell_w, cell_h
## Les cadres d'une bande ne sont pas tous carrés : Pirate Tower_Water fait
## 8 cadres de 128 × 192. Toute la table a été mesurée sur les fichiers
## réels, jamais supposée.

const TABLE_PATH := "res://data/assets.json"

## Catégories dont les entrées sont de simples fichiers, sans couleur.
const PLAIN_CATEGORIES: Array[StringName] = [
	&"terrain", &"decorations", &"resources", &"fx", &"ui", &"extra",
	&"widgets", &"glyphs"
]

const KIND_IMAGE := &"image"
const KIND_STRIP := &"strip"
const KIND_ATLAS := &"atlas"

static var _table: Dictionary = {}


## Charge la table si besoin et la renvoie. Vide si le fichier est absent
## ou illisible.
static func table() -> Dictionary:
	if not _table.is_empty():
		return _table
	if not FileAccess.file_exists(TABLE_PATH):
		push_error("AssetTable : %s introuvable" % TABLE_PATH)
		return {}
	var file := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if file == null:
		push_error("AssetTable : %s illisible" % TABLE_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("AssetTable : %s n'est pas un objet JSON" % TABLE_PATH)
		return {}
	_table = parsed
	return _table


## Vide le cache. Utile aux tests, inutile en jeu.
## Vide le cache de données, pour les tests et le rechargement à chaud.
##
## PAS `reload()` : ce nom entre en collision avec `Script.reload()` de
## Godot, et c'est CELUI-LÀ qui était appelé — « Cannot reload script while
## instances exist », 472 fois par exécution des tests. Le cache n'était
## donc jamais vidé, et la table de données que le test croyait relire
## était celle du test précédent.
static func clear_cache() -> void:
	_table = {}


static func meta() -> Dictionary:
	return table().get("meta", {})


## Côté d'une tuile, en pixels.
static func tile_size() -> int:
	return int(meta().get("tile_size", 0))


## Cadence des animations du pack.
static func fps() -> int:
	return int(meta().get("fps", 0))


## Les cinq couleurs de faction.
static func colors() -> Array:
	return meta().get("colors", [])


static func has_color(color: String) -> bool:
	return colors().has(color)


## Racine `res://` d'une catégorie (pack gratuit ou pack ennemi).
static func root_of(category: StringName) -> String:
	var roots: Dictionary = meta().get("roots", {})
	var which: String = roots.get(String(category), "")
	if which.is_empty():
		push_error("AssetTable : catégorie inconnue « %s »" % category)
		return ""
	var root: String = meta().get("root_%s" % which, "")
	if root.is_empty():
		push_error("AssetTable : racine « root_%s » absente de meta" % which)
		return ""
	return "res://" + root


## Animation d'une unité humaine, dans une couleur de faction.
## Renvoie { path, frames, frame } ou {} si l'entrée n'existe pas.
static func unit_animation(unit_id: StringName, animation: StringName, color: String) -> Dictionary:
	if not has_color(color):
		push_error("AssetTable : couleur inconnue « %s »" % color)
		return {}
	var units: Dictionary = table().get("units", {})
	var unit: Dictionary = units.get(String(unit_id), {})
	if unit.is_empty():
		push_error("AssetTable : unité inconnue « %s »" % unit_id)
		return {}
	var animations: Dictionary = unit.get("animations", {})
	var entry: Dictionary = animations.get(String(animation), {})
	if entry.is_empty():
		push_error("AssetTable : l'unité « %s » n'a pas d'animation « %s »" % [unit_id, animation])
		return {}
	var relative: String = String(unit.get("path_template", "")) \
		.replace("{color}", color) \
		.replace("{file}", String(entry.get("file", "")))
	return _resolved(root_of(&"units") + relative, entry)


## Cette unité a-t-elle cette animation ? À demander AVANT d'aller la
## chercher : toutes les unités du pack n'ont pas les mêmes animations, et
## une absence attendue ne doit pas remplir la console d'erreurs.
static func has_unit_animation(unit_id: StringName, animation: StringName) -> bool:
	var unit: Dictionary = table().get("units", {}).get(String(unit_id), {})
	return unit.get("animations", {}).has(String(animation))


static func has_enemy_animation(enemy_id: StringName, animation: StringName) -> bool:
	var enemy: Dictionary = table().get("enemies", {}).get(String(enemy_id), {})
	return enemy.get("animations", {}).has(String(animation))


## Animation d'un ennemi. Les ennemis n'ont pas de couleur de faction.
##
## UNE BÊTE PEUT VENIR D'UNE AUTRE ORIGINE QUE LE PACK, et c'est le champ
## `root` de son entrée qui le dit. Tiny Swords interdit la redistribution,
## donc ses dossiers sont dans le `.gitignore` ; un dessin qui n'en vient
## pas n'a aucune raison de partager ce sort et se versionne. Sans ce
## champ, la seule façon d'ajouter une bête aurait été de la poser dans un
## dossier ignoré — donc de la perdre au prochain clone.
static func enemy_animation(enemy_id: StringName, animation: StringName) -> Dictionary:
	var enemies: Dictionary = table().get("enemies", {})
	var enemy: Dictionary = enemies.get(String(enemy_id), {})
	if enemy.is_empty():
		push_error("AssetTable : ennemi inconnu « %s »" % enemy_id)
		return {}
	var animations: Dictionary = enemy.get("animations", {})
	var entry: Dictionary = animations.get(String(animation), {})
	if entry.is_empty():
		push_error("AssetTable : l'ennemi « %s » n'a pas d'animation « %s »" % [enemy_id, animation])
		return {}
	var root: String = root_of(StringName(enemy.get("root", "enemies")))
	return _resolved(root + String(entry.get("file", "")), entry)


## Bâtiment, dans une couleur de faction. Renvoie { path, w, h }.
## Les bâtiments sont des images fixes, pas des feuilles d'animation.
static func building(building_id: StringName, color: String) -> Dictionary:
	if not has_color(color):
		push_error("AssetTable : couleur inconnue « %s »" % color)
		return {}
	var buildings: Dictionary = table().get("buildings", {})
	var entry: Dictionary = buildings.get(String(building_id), {})
	if entry.is_empty():
		push_error("AssetTable : bâtiment inconnu « %s »" % building_id)
		return {}
	var relative: String = String(entry.get("path_template", "")).replace("{color}", color)
	return _resolved(root_of(&"buildings") + relative, entry)


## Portrait d'un héros, d'après sa classe et sa couleur de faction.
##
## Le pack fournit 25 portraits humains : 5 classes × 5 couleurs. Le
## portrait découle donc de la classe et de la couleur, pas de l'individu
## — c'est assez pour la fiche de héros, le roster et la Convocation.
##
## PIÈGE : l'ordre des couleurs des portraits n'est pas celui de
## `meta.colors`. Les portraits mettent Yellow avant Purple, l'inverse du
## reste du pack. C'est pour ça que cette fonction existe au lieu d'un
## calcul d'indice recopié à chaque appel.
##
## `class_order` liste les cinq ARCHÉTYPES DESSINÉS, pas les classes
## jouables. Une classe qui emprunte le sprite d'une autre emprunte aussi
## son portrait, et `aliases` fait la traduction : le Mage passe par le
## Moine, faute de mage dans le pack.
static func portrait(class_id: StringName, color: String) -> Dictionary:
	var block: Dictionary = table().get("portraits", {})
	var classes: Array = block.get("class_order", [])
	var colors_order: Array = block.get("color_order", [])
	var aliases: Dictionary = block.get("aliases", {})

	var wanted := String(aliases.get(String(class_id), String(class_id)))
	var class_index := classes.find(wanted)
	if class_index < 0:
		push_error("AssetTable : aucun portrait pour la classe « %s »" % class_id)
		return {}
	var color_index := colors_order.find(color)
	if color_index < 0:
		push_error("AssetTable : aucun portrait pour la couleur « %s »" % color)
		return {}

	var index := color_index * classes.size() + class_index + 1
	return sprite(&"ui", StringName("avatars_%02d" % index))


## Entrée d'une catégorie simple : terrain, decorations, resources, fx, ui, extra.
## Préfixe d'une clé de COMMENTAIRE. Tous les fichiers de données du
## projet en portent ; la table des assets n'y échappait que parce qu'elle
## n'en avait pas encore. En ajouter une a suffi à faire tomber
## `all_entries()`, qui la lisait comme une entrée et recevait une chaîne
## là où il attendait un objet.
const NOTE_PREFIX := "_"


static func is_note(key: String) -> bool:
	return key.begins_with(NOTE_PREFIX)


## Cette entrée existe-t-elle ? Distinct de `sprite()`, qui pousse une
## erreur quand elle manque : ici, l'absence est une réponse valable —
## une compétence sans glyphe reste en texte.
static func has(category: StringName, key: StringName) -> bool:
	if not PLAIN_CATEGORIES.has(category) or is_note(String(key)):
		return false
	return (table().get(String(category), {}) as Dictionary).has(String(key))


static func sprite(category: StringName, key: StringName) -> Dictionary:
	if not PLAIN_CATEGORIES.has(category):
		push_error("AssetTable : « %s » n'est pas une catégorie simple" % category)
		return {}
	if is_note(String(key)):
		return {}
	var entries: Dictionary = table().get(String(category), {})
	var entry: Dictionary = entries.get(String(key), {})
	if entry.is_empty():
		push_error("AssetTable : « %s » absent de la catégorie « %s »" % [key, category])
		return {}
	return _resolved(root_of(category) + String(entry.get("file", "")), entry)


## Toutes les entrées de la table, à plat, pour l'outil de vérification.
## Chaque élément : { id, category, path, frames, frame }.
static func all_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data := table()

	for unit_id: String in data.get("units", {}).keys():
		if is_note(unit_id):
			continue
		for animation: String in data["units"][unit_id].get("animations", {}).keys():
			for color: String in colors():
				var found := unit_animation(unit_id, animation, color)
				if not found.is_empty():
					found["id"] = "%s.%s.%s" % [unit_id, animation, color]
					found["category"] = "units"
					out.append(found)

	for enemy_id: String in data.get("enemies", {}).keys():
		if is_note(enemy_id):
			continue
		for animation: String in data["enemies"][enemy_id].get("animations", {}).keys():
			var found := enemy_animation(enemy_id, animation)
			if not found.is_empty():
				found["id"] = "%s.%s" % [enemy_id, animation]
				found["category"] = "enemies"
				out.append(found)

	for building_id: String in data.get("buildings", {}).keys():
		if is_note(building_id):
			continue
		for color: String in colors():
			var found := building(building_id, color)
			if not found.is_empty():
				found["id"] = "%s.%s" % [building_id, color]
				found["category"] = "buildings"
				out.append(found)

	for category: StringName in PLAIN_CATEGORIES:
		for key: String in data.get(String(category), {}).keys():
			if is_note(key):
				continue
			var found := sprite(category, key)
			if not found.is_empty():
				found["id"] = "%s.%s" % [category, key]
				found["category"] = String(category)
				out.append(found)

	return out


## Champs qui comptent des pixels ou des images. `JSON.parse_string`
## rend tous les nombres en flottant ; on les repasse en entier ici, une
## fois pour toutes, plutôt que de laisser chaque appelant s'en souvenir.
const INTEGER_KEYS: Array[String] = [
	"frames", "frame_w", "frame_h", "w", "h", "columns", "rows", "cell_w", "cell_h"
]


## Recopie l'entrée telle qu'elle est écrite, en remplaçant le chemin
## relatif par le chemin `res://` complet. Aucune dimension n'est
## recalculée : ce que dit `assets.json` est ce que reçoit l'appelant.
static func _resolved(path: String, entry: Dictionary) -> Dictionary:
	var out := entry.duplicate(true)
	out.erase("file")
	out.erase("path_template")
	out["path"] = path
	out["kind"] = StringName(entry.get("kind", KIND_IMAGE))
	for key: String in INTEGER_KEYS:
		if out.has(key):
			out[key] = int(out[key])
	return out


## Dimensions totales de l'image d'une entrée, quel que soit son kind.
## Sert à la vérification et au calcul de mise en page.
static func pixel_size(entry: Dictionary) -> Vector2i:
	match StringName(entry.get("kind", KIND_IMAGE)):
		KIND_STRIP:
			return Vector2i(
				int(entry.get("frames", 1)) * int(entry.get("frame_w", 0)),
				int(entry.get("frame_h", 0))
			)
		KIND_ATLAS:
			return Vector2i(
				int(entry.get("columns", 1)) * int(entry.get("cell_w", 0)),
				int(entry.get("rows", 1)) * int(entry.get("cell_h", 0))
			)
		_:
			return Vector2i(int(entry.get("w", 0)), int(entry.get("h", 0)))
