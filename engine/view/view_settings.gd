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


## Vide le cache de données, pour les tests et le rechargement à chaud.
##
## PAS `reload()` : ce nom entre en collision avec `Script.reload()` de
## Godot, et c'est CELUI-LÀ qui était appelé — « Cannot reload script while
## instances exist », 472 fois par exécution des tests. Le cache n'était
## donc jamais vidé, et la table de données que le test croyait relire
## était celle du test précédent.
static func clear_cache() -> void:
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


## Chiffres du tremblement d'écran. Ils attendaient dans `view.json` depuis
## T1.9 sans que rien ne les lise : le § 12 met le tremblement en tête du
## rapport impact/coût, et c'était le coût qui n'avait pas été payé.
static func shake(key: StringName) -> float:
	return number(&"shake", key, 0.0)


## Nom du bloc de tuiles d'un terrain. Deux terrains du même bloc se
## touchent sans bord ; deux terrains de blocs différents ont une rive
## entre eux. C'est ce qui rend une colline visible au milieu de l'herbe.
static func terrain_block_name(terrain_id: StringName) -> String:
	return String(section(&"terrain_block_of").get(String(terrain_id), "land"))


## Coin haut-gauche du bloc 4 x 4 dans lequel se prend un terrain.
static func terrain_block_origin(terrain_id: StringName) -> Vector2i:
	var raw: Variant = section(&"terrain_blocks").get(terrain_block_name(terrain_id), [0, 0])
	var cell: Array = raw
	return Vector2i(int(cell[0]), int(cell[1]))


## Tuile à prendre dans un bloc 4 x 4 selon les voisins du MÊME BLOC.
##
## « Du même bloc » et non « de la terre » : une colline entourée d'herbe
## doit recevoir des bords sur ses quatre côtés, sinon elle est peinte avec
## la tuile de remplissage du plateau — identique à celle de l'herbe — et
## le joueur ne voit pas où est le bonus de portée.
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
	same_left: bool = true, same_right: bool = true,
	same_up: bool = true, same_down: bool = true
) -> Rect2:
	var origin := terrain_block_origin(terrain_id)
	return Rect2(
		(origin.x + _edge_index(same_left, same_right)) * tile_size,
		(origin.y + _edge_index(same_up, same_down)) * tile_size,
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


## Rangée de falaise du bloc « hill », dessinée sous le bord bas d'une
## colline. L'intérieur du plateau est identique à celui de l'herbe : sans
## cette lèvre de pierre, le joueur ne voit pas où est le bonus de portée.
static func hill_cliff_region(tile_size: int) -> Rect2:
	var raw: Variant = section(&"terrain_blocks").get("hill_cliff", [6, 4])
	var cell: Array = raw
	return Rect2(
		int(cell[0]) * tile_size, int(cell[1]) * tile_size, tile_size, tile_size
	)


## Décoration posée sur un terrain : { category, key }, ou {} s'il n'y en a pas.
##
## LE MÊME TERRAIN NE SE DESSINE PAS PAREIL PARTOUT (T11.9). Un bosquet
## des Terres Vertes est un arbre vert ; le même bosquet dans les Dunes
## est un arbre MORT — mêmes règles (il coupe la vue, il abrite), autre
## dessin. C'est la leçon de T11.7 poussée jusqu'au décor : on n'invente
## pas de mécanique pour un acte, on change ce qu'elle montre.
##
## `ground` est la couleur de sol de la région (`Region.ground_of`). Vide,
## ou sans variante déclarée, on retombe sur le dessin par défaut : une
## région n'a pas à redéclarer les six terrains pour en changer deux.
static func terrain_decoration(
	terrain_id: StringName, ground: StringName = &""
) -> Dictionary:
	var raw: Variant = null
	if not ground.is_empty():
		var variants: Dictionary = section(&"terrain_decorations_by_ground")
		raw = (variants.get(String(ground), {}) as Dictionary).get(String(terrain_id), null)
	if raw == null:
		raw = section(&"terrain_decorations").get(String(terrain_id), null)
	if raw == null:
		return {}
	var pair: Array = raw
	var out := {"category": StringName(pair[0]), "key": StringName(pair[1])}
	# Trois valeurs : l'image voulue dans une bande d'animation. La première
	# image d'un feu n'est qu'une étincelle de quelques pixels — invisible
	# sur une case de 64, donc mensongère pour un terrain qui blesse.
	if pair.size() == 3:
		out["frame"] = int(pair[2])
	# Quatre : la cellule voulue d'un atlas, [cat, clé, colonne, rangée].
	elif pair.size() >= 4:
		out["cell"] = Vector2i(int(pair[2]), int(pair[3]))
	return out


## La teinte posée SOUS un terrain, par le nom d'une couleur de
## `view.json`. Vide s'il n'y en a pas.
##
## LA BOUE N'A AUCUN SPRITE DANS LE PACK, et la note de `view.json` le
## disait depuis toujours : « elle se dessine comme de l'herbe, ce qui est
## un piège — il faudra une teinte avant qu'une carte l'utilise ». Le
## sable mouvant des Dunes est cette carte. Une case qui coûte deux PM et
## qui ressemble à une case qui en coûte un est un mensonge, pas une
## surprise.
## LA TEINTE SUIT LE BIOME, COMME LE DESSIN (T12.1). Le sable mouvant est
## brun ; la même teinte posée sur de la glace donnait une bande de BOUE au
## milieu d'un col enneigé — la neige profonde des Montagnes Gelées est
## exactement le même terrain, et elle doit être blanc-bleu.
##
## Une seule couleur pour un terrain valait tant qu'un seul acte
## l'employait. Même mécanisme que `terrain_decorations_by_ground`, et
## même retombée : ce qui n'est pas décliné garde la teinte par défaut.
static func terrain_tint(
	terrain_id: StringName, ground: StringName = &""
) -> StringName:
	if not ground.is_empty():
		var variants: Dictionary = section(&"terrain_tints_by_ground")
		var declared: Variant = (
			variants.get(String(ground), {}) as Dictionary
		).get(String(terrain_id), null)
		if declared != null:
			return StringName(declared)
	return StringName(section(&"terrain_tints").get(String(terrain_id), ""))
