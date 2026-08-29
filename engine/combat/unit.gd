class_name Unit
extends RefCounted

## Une unité engagée dans un combat : ses statistiques du moment, sa case,
## son état de tour.
##
## Une Unit est jetable — elle vit le temps d'un combat. Ce qui persiste
## d'un combat à l'autre est le Hero (tâche H2.1), qui porte le nom, le
## niveau, les blessures et l'équipement, et qui fabrique une Unit au
## moment d'entrer sur la grille. Les bonus de niveau, de trait, d'objet
## et de rang de l'Ordre sont donc déjà appliqués aux valeurs qu'on reçoit
## ici : Unit ne les recalcule jamais.
##
## RÈGLE : tomber à 0 PV n'est pas mourir. L'unité est hors de combat pour
## le reste de l'expédition, et c'est le niveau au-dessus qui décidera d'en
## faire une blessure (§ 3.4).

const HERO_CLASSES_PATH := "res://data/units/hero_classes.json"
const ENEMIES_PATH := "res://data/enemies/act1.json"

## Les deux camps et les deux états d'une unité. Stockés en `int` plutôt
## qu'en type énuméré : GDScript refuse d'annoter un champ avec une
## énumération déclarée dans la même classe nommée.
enum Side { HEROES, ENEMIES }
enum State { ACTIVE, DOWNED }

static var _hero_classes: Dictionary = {}
static var _enemies: Dictionary = {}

var id: int = -1
var class_id: StringName = &""
var side: int = Side.HEROES
var cell: Vector2i = Vector2i.ZERO

var max_hit_points: int = 0
var hit_points: int = 0
var movement: int = 0
var range_min: int = 0
var range_max: int = 0
var damage: int = 0

## Circule dans l'eau, et n'y meurt pas. Vrai pour les trois créatures
## aquatiques du bestiaire, faux pour tous les héros.
var aquatic: bool = false

## Ignore le terrain : la chauve-souris et le bourdon passent au-dessus
## des rochers, de l'eau et de la forêt (§ 4.4).
var flying: bool = false

## Comportement d'IA. Vide pour un héros, que le joueur pilote.
var role: StringName = &""

var state: int = State.ACTIVE

## Remis à faux au début de chaque tour. Le Tir tendu de l'Archer donne
## +2 dégâts s'il n'a pas bougé : c'est ce drapeau qui le sait.
var has_moved: bool = false
var has_acted: bool = false


static func reload() -> void:
	_hero_classes = {}
	_enemies = {}


static func hero_classes() -> Dictionary:
	if not _hero_classes.is_empty():
		return _hero_classes
	_hero_classes = _read_json(HERO_CLASSES_PATH)
	return _hero_classes


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Unit : %s introuvable" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unit : %s illisible" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Unit : %s n'est pas un objet JSON" % path)
		return {}
	return parsed


## Identifiants des classes de héros déclarées.
static func hero_class_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in hero_classes().keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


## Statistiques de base d'une classe de héros, telles qu'écrites en données.
static func hero_class(class_to_find: StringName) -> Dictionary:
	var found: Dictionary = hero_classes().get(String(class_to_find), {})
	if found.is_empty():
		push_error("Unit : classe de héros inconnue « %s »" % class_to_find)
	return found


## Fabrique une unité au niveau 1, sans aucun bonus. C'est l'unité de
## départ et celle des tests ; en jeu, c'est le Hero qui fournira les
## valeurs déjà modifiées, via `from_stats`.
static func from_hero_class(
	unit_id: int, class_to_use: StringName, at: Vector2i
) -> Unit:
	var stats := hero_class(class_to_use)
	if stats.is_empty():
		return null
	var unit := Unit.from_stats(unit_id, class_to_use, Side.HEROES, at, stats)
	return unit


## Fabrique une unité à partir d'un bloc de statistiques déjà calculé.
## `unit_side` est une valeur de `Unit.Side`.
static func from_stats(
	unit_id: int, class_to_use: StringName, unit_side: int,
	at: Vector2i, stats: Dictionary
) -> Unit:
	var unit := Unit.new()
	unit.id = unit_id
	unit.class_id = class_to_use
	unit.side = unit_side
	unit.cell = at
	unit.max_hit_points = int(stats.get("hit_points", 0))
	unit.hit_points = unit.max_hit_points
	unit.movement = int(stats.get("movement", 0))
	unit.range_min = int(stats.get("range_min", 1))
	unit.range_max = int(stats.get("range_max", 1))
	unit.damage = int(stats.get("damage", 0))
	unit.aquatic = bool(stats.get("aquatic", false))
	unit.flying = bool(stats.get("flying", false))
	unit.role = StringName(stats.get("role", ""))
	return unit


static func enemies() -> Dictionary:
	if not _enemies.is_empty():
		return _enemies
	_enemies = _read_json(ENEMIES_PATH)
	return _enemies


## Identifiants des ennemis déclarés.
static func enemy_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in enemies().keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


## Statistiques de base d'un ennemi, telles qu'écrites en données.
static func enemy_stats(enemy_id: StringName) -> Dictionary:
	var found: Dictionary = enemies().get(String(enemy_id), {})
	if found.is_empty():
		push_error("Unit : ennemi inconnu « %s »" % enemy_id)
	return found


## Fabrique un ennemi à partir de son identifiant.
static func from_enemy(unit_id: int, enemy_id: StringName, at: Vector2i) -> Unit:
	var stats := enemy_stats(enemy_id)
	if stats.is_empty():
		return null
	return Unit.from_stats(unit_id, enemy_id, Side.ENEMIES, at, stats)


func is_active() -> bool:
	return state == State.ACTIVE


func is_downed() -> bool:
	return state == State.DOWNED


func is_hero() -> bool:
	return side == Side.HEROES


func is_enemy() -> bool:
	return side == Side.ENEMIES


## Frappe à distance : l'unité peut atteindre plus loin que sa case voisine.
func is_ranged() -> bool:
	return range_max > 1


## Une unité qui doit s'écarter pour frapper : l'Archer ne peut pas tirer
## sur son voisin immédiat.
func has_minimum_range() -> bool:
	return range_min > 1


## Applique des dégâts. Renvoie true si l'unité tombe hors de combat.
## Les dégâts sont bornés à zéro : un modificateur de terrain ne soigne pas.
func take_damage(amount: int) -> bool:
	if is_downed():
		return false
	hit_points -= maxi(amount, 0)
	if hit_points <= 0:
		hit_points = 0
		state = State.DOWNED
		return true
	return false


## Met l'unité hors de combat quelle que soit sa vie restante.
## C'est ce qui arrive à un héros poussé dans l'eau.
func down() -> bool:
	if is_downed():
		return false
	hit_points = 0
	state = State.DOWNED
	return true


## Soigne sans dépasser le maximum. Ne relève pas une unité tombée :
## seule la Relève du Moine le fait, et elle passe par `revive`.
func heal(amount: int) -> int:
	if is_downed() or amount <= 0:
		return 0
	var before := hit_points
	hit_points = mini(hit_points + amount, max_hit_points)
	return hit_points - before


## Remet debout une unité tombée, avec le nombre de PV donné.
## Réservé à la Relève du Moine (rang 3 de l'Ordre).
func revive(with_hit_points: int) -> bool:
	if not is_downed():
		return false
	state = State.ACTIVE
	hit_points = clampi(with_hit_points, 1, max_hit_points)
	return true


## Début de tour : l'unité peut à nouveau bouger et agir.
func begin_turn() -> void:
	has_moved = false
	has_acted = false


## L'unité a-t-elle encore quelque chose à faire ce tour ?
func is_spent() -> bool:
	return has_moved and has_acted


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"class": String(class_id),
		"side": int(side),
		"x": cell.x,
		"y": cell.y,
		"max_hit_points": max_hit_points,
		"hit_points": hit_points,
		"movement": movement,
		"range_min": range_min,
		"range_max": range_max,
		"damage": damage,
		"aquatic": aquatic,
		"flying": flying,
		"role": String(role),
		"state": int(state),
		"has_moved": has_moved,
		"has_acted": has_acted,
	}


static func from_dictionary(data: Dictionary) -> Unit:
	var unit := Unit.new()
	unit.id = int(data.get("id", -1))
	unit.class_id = StringName(data.get("class", ""))
	unit.side = int(data.get("side", Side.HEROES))
	unit.cell = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	unit.max_hit_points = int(data.get("max_hit_points", 0))
	unit.hit_points = int(data.get("hit_points", 0))
	unit.movement = int(data.get("movement", 0))
	unit.range_min = int(data.get("range_min", 1))
	unit.range_max = int(data.get("range_max", 1))
	unit.damage = int(data.get("damage", 0))
	unit.aquatic = bool(data.get("aquatic", false))
	unit.flying = bool(data.get("flying", false))
	unit.role = StringName(data.get("role", ""))
	unit.state = int(data.get("state", State.ACTIVE))
	unit.has_moved = bool(data.get("has_moved", false))
	unit.has_acted = bool(data.get("has_acted", false))
	return unit
