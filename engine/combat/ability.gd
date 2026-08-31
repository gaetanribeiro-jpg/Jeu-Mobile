class_name Ability
extends RefCounted

## Une compétence, lue dans `data/units/abilities.json`.
##
## Une compétence est décrite entièrement par ses données (vision § 47) :
## son coût en PA, sa portée, la forme de sa zone, la statistique qui met
## ses dégâts à l'échelle. Le moteur ne connaît aucune compétence par son
## nom — il lit ces champs et les applique. C'est ce qui permet d'ajouter
## une compétence sans toucher à un seul `.gd`.

const ABILITIES_PATH := "res://data/units/abilities.json"

## Ce que la compétence fait, une fois sa cible désignée.
const KIND_ATTACK := &"attack"
const KIND_TAUNT := &"taunt"
const KIND_REPOSITION := &"reposition"
const KIND_PUSH := &"push"
const KIND_HEAL := &"heal"

## Formes de zone (§ 18). `single` et `cross` sont implémentées ; `line`
## sert au Troll ; `cone` attend une classe qui en ait besoin.
const SHAPE_SINGLE := &"single"
const SHAPE_CROSS := &"cross"
const SHAPE_LINE := &"line"

static var _raw: Dictionary = {}
static var _cache: Dictionary = {}

var id: StringName = &""
var class_id: StringName = &""
var kind: StringName = KIND_ATTACK

var action_points: int = 0
var movement_points: int = 0

var range_min: int = 1
var range_max: int = 1
var needs_line_of_sight: bool = true

var shape: StringName = SHAPE_SINGLE
var radius: int = 0
var length: int = 1

var damage: int = 0
var scaling: StringName = &""

var cooldown: int = 0
var requires_not_moved: bool = false
var counts_as_movement: bool = false
var friendly_fire: bool = false

## Durée d'un effet posé sur soi — la Provocation dure un tour.
var duration: int = 0

## Statut posé sur la cible, s'il y en a un.
var status_id: StringName = &""
var status_duration: int = 0

## Terrain laissé sur la case touchée, s'il y en a un.
var leaves_terrain: StringName = &""

## Noms d'animation et d'effet, résolus par la vue. Le moteur ne s'en sert
## pas : il les transporte.
var animation: StringName = &""
var effect: StringName = &""


static func reload() -> void:
	_raw = {}
	_cache = {}


static func all() -> Dictionary:
	if not _raw.is_empty():
		return _raw
	if not FileAccess.file_exists(ABILITIES_PATH):
		push_error("Ability : %s introuvable" % ABILITIES_PATH)
		return {}
	var file := FileAccess.open(ABILITIES_PATH, FileAccess.READ)
	if file == null:
		push_error("Ability : %s illisible" % ABILITIES_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Ability : %s n'est pas un objet JSON" % ABILITIES_PATH)
		return {}
	_raw = parsed
	return _raw


## Identifiants de toutes les compétences déclarées.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in all().keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


## Le bloc de données brut d'une compétence.
static func data_of(ability_id: StringName) -> Dictionary:
	var found: Dictionary = all().get(String(ability_id), {})
	if found.is_empty():
		push_error("Ability : compétence inconnue « %s »" % ability_id)
	return found


## La compétence, sous forme d'objet. Les instances sont mises en cache :
## une compétence est une fiche technique, elle ne change jamais.
static func of(ability_id: StringName) -> Ability:
	if _cache.has(ability_id):
		return _cache[ability_id]
	var data := data_of(ability_id)
	if data.is_empty():
		return null
	var ability := Ability.from_dictionary(ability_id, data)
	_cache[ability_id] = ability
	return ability


static func from_dictionary(ability_id: StringName, data: Dictionary) -> Ability:
	var ability := Ability.new()
	ability.id = ability_id
	ability.class_id = StringName(data.get("class", ""))
	ability.kind = StringName(data.get("kind", KIND_ATTACK))
	ability.action_points = int(data.get("action_points", 0))
	ability.movement_points = int(data.get("movement_points", 0))
	ability.range_min = int(data.get("range_min", 1))
	ability.range_max = int(data.get("range_max", 1))
	ability.needs_line_of_sight = bool(data.get("needs_line_of_sight", true))
	ability.damage = int(data.get("damage", 0))
	ability.scaling = StringName(data.get("scaling", ""))
	ability.cooldown = int(data.get("cooldown", 0))
	ability.requires_not_moved = bool(data.get("requires_not_moved", false))
	ability.counts_as_movement = bool(data.get("counts_as_movement", false))
	ability.friendly_fire = bool(data.get("friendly_fire", false))
	ability.duration = int(data.get("duration", 0))
	ability.leaves_terrain = StringName(data.get("leaves_terrain", ""))
	ability.animation = StringName(data.get("animation", ""))
	ability.effect = StringName(data.get("effect", ""))

	var area: Dictionary = data.get("area", {})
	ability.shape = StringName(area.get("shape", SHAPE_SINGLE))
	ability.radius = int(area.get("radius", 0))
	ability.length = int(area.get("length", 1))

	var status: Dictionary = data.get("status", {})
	if not status.is_empty():
		ability.status_id = StringName(status.get("id", ""))
		ability.status_duration = int(status.get("duration", 0))
	return ability


## Compétences d'une classe, dans l'ordre où elles sont déclarées sur elle.
static func of_class(class_to_find: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for ability_id: StringName in ids():
		if StringName(data_of(ability_id).get("class", "")) == class_to_find:
			out.append(ability_id)
	return out


func is_attack() -> bool:
	return kind == KIND_ATTACK


## Se lance sur sa propre case : la Provocation ne vise personne.
func targets_self() -> bool:
	return range_max <= 0


## Terrain que la compétence laisse derrière elle, s'il y en a un.
func leaves_terrain_id() -> StringName:
	return leaves_terrain


## Cette compétence exige-t-elle une victime sur la case visée ?
##
## Une attaque à cible unique, oui : tirer sur du terrain vide coûterait
## 3 PA pour rien, et le joueur n'aurait aucun moyen de comprendre ce qui
## vient de se passer. Une compétence de zone, non — viser entre deux
## ennemis pour les attraper tous les deux est précisément son usage.
## Un déplacement ou une Provocation non plus : leur cible n'est pas une
## victime, c'est une case.
func needs_occupant() -> bool:
	return is_attack() and shape == SHAPE_SINGLE


## La distance est-elle dans la fourchette de portée ?
func is_distance_in_range(distance: int) -> bool:
	return distance >= range_min and distance <= range_max


## L'unité peut-elle lancer cette compétence maintenant ? Ne regarde que
## l'unité — les PA, la recharge, l'immobilité —, pas le plateau.
func is_available_to(unit: Unit) -> bool:
	if not unit.is_active():
		return false
	if not unit.has_ability(id):
		return false
	if not unit.is_ready(id):
		return false
	if not unit.can_spend_action_points(action_points):
		return false
	if movement_points > 0 and unit.movement_points < movement_points:
		return false
	if requires_not_moved and unit.has_moved:
		return false
	return true


## Pourquoi la compétence est indisponible, en une clé de traduction.
## Chaîne vide si elle est disponible.
func unavailable_reason(unit: Unit) -> StringName:
	if not unit.has_ability(id):
		return &"ability.unknown"
	if not unit.is_ready(id):
		return &"ability.cooling_down"
	if not unit.can_spend_action_points(action_points):
		return &"ability.not_enough_ap"
	if movement_points > 0 and unit.movement_points < movement_points:
		return &"ability.not_enough_mp"
	if requires_not_moved and unit.has_moved:
		return &"ability.already_moved"
	return &""


## Les cases effectivement touchées quand on vise `target` depuis `from`.
##
## `single` ne touche que la case visée. `cross` y ajoute tout ce qui est
## à portée de Manhattan `radius` — c'est la Boule de feu. `line` part de
## la case visée et continue dans la direction du coup, c'est la Frappe du
## Troll. Le résultat est toujours borné à la grille.
func area_cells(grid: Grid, from: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match shape:
		SHAPE_CROSS:
			for cell: Vector2i in grid.cells_in_range(target, 0, radius):
				out.append(cell)
		SHAPE_LINE:
			var step := grid.direction(from, target)
			if step == Vector2i.ZERO:
				step = Vector2i.RIGHT
			var cell := target
			for i in maxi(length, 1):
				if not grid.contains(cell):
					break
				out.append(cell)
				cell += step
		_:
			if grid.contains(target):
				out.append(target)
	return out
