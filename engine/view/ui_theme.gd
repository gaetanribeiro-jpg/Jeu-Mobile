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


## Un réglage fractionnaire d'une section quelconque. `metric` rend des
## entiers — des pixels ; celui-ci rend des proportions.
static func number(section_name: StringName, key: StringName) -> float:
	var block := section(section_name)
	if not block.has(String(key)):
		push_error("UiTheme : réglage « %s.%s » absent du thème" % [section_name, key])
		return 0.0
	return float(block[String(key)])


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


## Les widgets que Tiny Swords ne dessine pas — barre de défilement, case
## à cocher — pris chez Kenney. Vide si le thème n'en déclare pas : on
## retombe alors sur les widgets de Godot, moins jolis mais fonctionnels.
static func widgets() -> Dictionary:
	return section(&"widgets")


static func widget(name_: StringName) -> Dictionary:
	return widgets().get(String(name_), {})


## Les glyphes de compétences (§ 48) : taille, seuil d'alpha, teinte.
## Vide si le thème n'en déclare pas — la barre d'action reste alors en
## texte, ce qu'elle a fait pendant neuf phases.
static func glyphs() -> Dictionary:
	return section(&"glyphs")


## L'APLAT DE FOND, TEINTÉ PAR L'ACTE (T11.9).
##
## « L'interface pourrait légèrement changer d'un acte à l'autre. » Elle le
## fait par le FOND, et par lui seul : le liseré doré, les panneaux et les
## rôles de bouton ne bougent pas. Autrement ce ne serait plus le même jeu
## d'un acte à l'autre, mais deux jeux — et T9.7 a verrouillé cette
## identité.
##
## À LUMINANCE CONSTANTE, et c'est le point délicat. On change la TEINTE
## du presque-noir, jamais sa clarté : le contraste des panneaux posés
## dessus reste celui qui a été mesuré une fois, au lieu d'être à
## revérifier pour chacune des six régions.
##
## ICI ET PAS DANS `UiSkin` PARCE QUE `verify_ui` DOIT SAVOIR CALCULER ÇA.
## Un script lancé par `-s` ne reçoit AUCUN autoload, et l'identifiant est
## résolu à la COMPILATION : le vérificateur ne compilait même pas. Même
## piège que `GameState` dans `tools/dev/screenshot.gd`.
static func air_ground(air: StringName) -> Color:
	var base := color(&"backdrop")
	if air.is_empty() or not has_color(air):
		return base
	return base.lerp(
		_at_luminance(color(air), base.get_luminance()),
		number(&"act_air", &"ground_mix")
	)


## Le motif de fond, teinté du même air — plus doucement. Il est déjà à
## peine visible ; le teinter fort ne ferait que l'éteindre.
static func air_weave(air: StringName) -> Color:
	var base := color(&"weave")
	if air.is_empty() or not has_color(air):
		return base
	var tinted := base.lerp(color(air), number(&"act_air", &"weave_mix"))
	tinted.a = base.a
	return tinted


## LE TRAIT DOUX, TEINTÉ PAR L'ACTE — et c'est LUI qu'on voit (T11.9).
##
## Le fond ne peut porter qu'un soupçon, et c'est mesuré : à la luminance
## d'un presque-noir, deux teintes opposées ne se séparent que de deux
## niveaux sur 255, et l'éclaircir ferait passer la crête du motif devant
## le panneau le plus sombre — ce que T9.8 refuse.
##
## `panel_edge_soft` est un or ÉTEINT, et il ne porte aucune information :
## le trait VIF dit « c'est à lui » (T9.7), le doux dit seulement « ceci
## est un panneau ». Une couleur libre est celle qu'on peut donner. Mélangé
## vers l'accent de la région, il vire visiblement sans jamais s'approcher
## de l'or vif — `verify_ui` mesure cette distance pour les six régions.
static func air_edge(air: StringName) -> Color:
	var base := color(&"panel_edge_soft")
	if air.is_empty() or not has_color(air):
		return base
	return base.lerp(color(air), number(&"act_air", &"edge_mix"))


## La même couleur, ramenée à une luminance voulue. Une couleur noire n'a
## pas de teinte à conserver : on la rend telle quelle plutôt que de
## diviser par zéro.
static func _at_luminance(source: Color, target: float) -> Color:
	var here := source.get_luminance()
	if here <= 0.0:
		return source
	var factor := target / here
	return Color(source.r * factor, source.g * factor, source.b * factor, source.a)


## La couleur d'une jauge de vie selon ce qu'il reste, en fraction.
## Vit ici et pas dans un écran : trois écrans dessinent des PV, et trois
## seuils écrits trois fois divergent au premier réglage.
static func health_color(fraction: float) -> Color:
	if fraction > 0.6:
		return color(&"health_high")
	if fraction > 0.3:
		return color(&"health_mid")
	return color(&"health_low")
