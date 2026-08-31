class_name CombatRules
extends RefCounted

## Accès aux valeurs chiffrées du combat, toutes dans `data/combat/`.
##
## RÈGLE DURE : aucun nombre de gameplay dans un `.gd`. Cette classe est
## le seul chemin entre les fichiers de données et le moteur.

const RULES_PATH := "res://data/combat/rules.json"
const TERRAIN_PATH := "res://data/combat/terrain.json"

## Les deux façons de compter les voisins et les distances.
const ADJACENCY_ORTHOGONAL := "orthogonal"
const ADJACENCY_DIAGONAL := "diagonal"

static var _rules: Dictionary = {}
static var _terrain: Dictionary = {}


static func reload() -> void:
	_rules = {}
	_terrain = {}


static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = _read(RULES_PATH)
	return _rules


static func terrain() -> Dictionary:
	if _terrain.is_empty():
		_terrain = _read(TERRAIN_PATH)
	return _terrain


## Valeur d'une section de `rules.json`, avec un défaut explicite.
static func rule(section: StringName, key: StringName, fallback: Variant = null) -> Variant:
	var block: Dictionary = rules().get(String(section), {})
	if not block.has(String(key)):
		push_error("CombatRules : règle « %s.%s » absente de rules.json" % [section, key])
		return fallback
	return block[String(key)]


## Toutes les propriétés d'un type de terrain.
static func terrain_type(type_id: StringName) -> Dictionary:
	var found: Dictionary = terrain().get(String(type_id), {})
	if found.is_empty():
		push_error("CombatRules : terrain inconnu « %s »" % type_id)
	return found


## Une propriété d'un type de terrain, avec un défaut explicite.
static func terrain_property(type_id: StringName, key: StringName, fallback: Variant) -> Variant:
	return terrain_type(type_id).get(String(key), fallback)


## Identifiants de tous les types de terrain déclarés.
static func terrain_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in terrain().keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


## Terrain associé à un symbole de carte écrite à la main.
## Renvoie une chaîne vide si le symbole n'est déclaré nulle part.
static func terrain_for_symbol(symbol: String) -> StringName:
	for id: StringName in terrain_ids():
		if String(terrain_property(id, &"symbol", "")) == symbol:
			return id
	push_error("CombatRules : aucun terrain pour le symbole « %s »" % symbol)
	return &""


## Nombre de personnages que le joueur emmène (§ 23 : 4 au plus dans le MVP).
static func team_size() -> int:
	return int(rule(&"sides", &"team_size", 4))


## Plafond dur. C'est le nombre de cases de départ qu'une carte doit
## prévoir, pas la taille de l'équipe du début de partie.
static func max_heroes() -> int:
	return int(rule(&"sides", &"max_heroes", 4))


## --- PA, PM et initiative (§ 13 et § 16) ---

## Coût en PM d'un pas, avant le surcoût du terrain.
static func move_cost_per_cell() -> int:
	return int(rule(&"movement_points", &"cost_per_cell", 1))


static func pass_through_allies() -> bool:
	return bool(rule(&"movement_points", &"pass_through_allies", true))


static func pass_through_enemies() -> bool:
	return bool(rule(&"movement_points", &"pass_through_enemies", false))


## Comment départager deux combattants de même initiative.
static func initiative_tie_break() -> String:
	return String(rule(&"initiative", &"tie_break", "heroes_first"))


## Nombre d'activations que le HUD montre dans la timeline.
static func initiative_preview_length() -> int:
	return int(rule(&"initiative", &"preview_length", 6))


## Plancher de la formule de dégâts : une attaque qui passe fait toujours
## au moins ça, quelle que soit la défense d'en face.
static func damage_minimum() -> int:
	return int(rule(&"damage", &"minimum", 1))


## Bloc d'un effet de statut, tel qu'écrit dans `rules.json`.
static func status(status_id: StringName) -> Dictionary:
	var block: Dictionary = rules().get("statuses", {})
	var found: Dictionary = block.get(String(status_id), {})
	if found.is_empty():
		push_error("CombatRules : statut inconnu « %s »" % status_id)
	return found


## PM retirés par un statut, en valeur positive. Le Gel en retire 2.
static func status_movement_penalty(status_id: StringName) -> int:
	return absi(int(status(status_id).get("movement_points", 0)))


static func adjacency() -> String:
	return String(rule(&"grid", &"adjacency", ADJACENCY_ORTHOGONAL))


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("CombatRules : %s introuvable" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CombatRules : %s illisible" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CombatRules : %s n'est pas un objet JSON" % path)
		return {}
	return parsed
