class_name UiTheme
extends RefCounted

## Le thème de l'interface, lu dans `data/ui/theme.json`.
##
## CLASSE PURE, comme `ViewSettings` : elle lit une table et rend des
## valeurs. Elle ne construit aucun `Theme` Godot et ne connaît aucun
## nœud — c'est `Skin` qui fait ça, côté scènes, parce que ça demande des
## textures.
##
## POURQUOI ELLE EXISTE. Sept fichiers d'écran portaient des
## `Color(0.13, 0.15, 0.13)` et des tailles de police en dur : la règle 1
## du projet — « aucune valeur chiffrée dans le code » — était violée
## exactement là où le § 46 veut le plus de souplesse, puisqu'une couleur
## est une valeur de ressenti et rien d'autre.
##
## UN ÉCRAN DEMANDE UN RÔLE, PAS UNE COULEUR. `color(&"ink_gold")`,
## `font_size(&"heading")`, `button_tint(&"danger")`. Le jour où la
## palette change, aucun écran ne bouge.

const PATH := "res://data/ui/theme.json"

## Repli quand une clé manque : le magenta se voit tout de suite, alors
## qu'un gris passerait pour une intention.
const MISSING := Color.MAGENTA

static var _data: Dictionary = {}


static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("UiTheme : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("UiTheme : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("UiTheme : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func section(name_: StringName) -> Dictionary:
	return data().get(String(name_), {})


## Couleur nommée de la palette, lue comme [r, v, b] ou [r, v, b, a].
static func color(key: StringName) -> Color:
	var raw: Variant = section(&"palette").get(String(key), null)
	if raw == null:
		push_error("UiTheme : couleur « %s » absente du thème" % key)
		return MISSING
	var values: Array = raw
	return Color(
		float(values[0]), float(values[1]), float(values[2]),
		float(values[3]) if values.size() > 3 else 1.0
	)


static func has_color(key: StringName) -> bool:
	return section(&"palette").has(String(key))


static func font_size(key: StringName) -> int:
	var block := section(&"typography")
	if not block.has(String(key)):
		push_error("UiTheme : taille de police « %s » absente du thème" % key)
		return 0
	return int(block[String(key)])


static func metric(key: StringName) -> int:
	var block := section(&"metrics")
	if not block.has(String(key)):
		push_error("UiTheme : mesure « %s » absente du thème" % key)
		return 0
	return int(block[String(key)])


## Description d'une surface : { asset, pressed_asset, scale, desaturate,
## tint }. Vide si le rôle n'existe pas.
static func surface(role: StringName) -> Dictionary:
	var block: Dictionary = section(&"surfaces").get(String(role), {})
	if block.is_empty():
		push_error("UiTheme : surface « %s » absente du thème" % role)
	return block


static func surface_roles() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in section(&"surfaces").keys():
		if not String(key).begins_with("_"):
			out.append(StringName(key))
	return out


## La couleur d'un rôle de bouton. Le rôle porte le SENS — « danger »,
## « primary » — et la palette décide de la teinte.
static func button_tint(role: StringName) -> Color:
	var tints := section(&"button_tints")
	if not tints.has(String(role)):
		push_error("UiTheme : rôle de bouton « %s » absent du thème" % role)
		return MISSING
	return color(StringName(tints[String(role)]))


static func button_roles() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in section(&"button_tints").keys():
		if not String(key).begins_with("_"):
			out.append(StringName(key))
	return out


static func bars() -> Dictionary:
	return section(&"bars")


## La couleur d'une jauge de vie selon ce qu'il reste, en fraction.
## Vit ici et pas dans un écran : trois écrans dessinent des PV, et trois
## seuils écrits trois fois divergent au premier réglage.
static func health_color(fraction: float) -> Color:
	if fraction > 0.6:
		return color(&"health_high")
	if fraction > 0.3:
		return color(&"health_mid")
	return color(&"health_low")
