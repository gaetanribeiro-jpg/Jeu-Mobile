class_name Unit
extends RefCounted

## Une unité engagée dans un combat : ses statistiques du moment, sa case,
## ses PA et ses PM.
##
## Une Unit est jetable — elle vit le temps d'un combat. Ce qui persiste
## d'un combat à l'autre est le Hero (Phase 2), qui porte le nom, le
## niveau et l'équipement, et qui fabrique une Unit au moment d'entrer sur
## la grille. Les bonus de niveau, d'objet et d'arbre de compétences sont
## donc déjà appliqués aux valeurs qu'on reçoit ici : Unit ne les
## recalcule jamais.
##
## LE MODÈLE DE TOUR (vision § 13) : un personnage a des Points d'Action
## et des Points de Mouvement. Il les retrouve intacts au début de son
## activation, et c'est lui qui décide comment les dépenser — deux
## attaques, ou une compétence puissante et un repositionnement. C'est de
## là que vient le choix à chaque tour (§ 50).

const HERO_CLASSES_PATH := "res://data/units/hero_classes.json"
const ENEMIES_PATH := "res://data/enemies/act1.json"

## Les deux camps et les deux états d'une unité. Stockés en `int` plutôt
## qu'en type énuméré : GDScript refuse d'annoter un champ avec une
## énumération déclarée dans la même classe nommée.
enum Side { HEROES, ENEMIES }
enum State { ACTIVE, DOWNED }

## Les statistiques du § 12. Une compétence nomme celle qui met ses dégâts
## à l'échelle ; `stat()` fait la traduction.
const STAT_STRENGTH := &"strength"
const STAT_AGILITY := &"agility"
const STAT_INTELLIGENCE := &"intelligence"
const STAT_DEFENCE := &"defence"
const STAT_CRITICAL := &"critical"

static var _hero_classes: Dictionary = {}
static var _enemies: Dictionary = {}

var id: int = -1
var class_id: StringName = &""
var side: int = Side.HEROES
var cell: Vector2i = Vector2i.ZERO

var max_hit_points: int = 0
var hit_points: int = 0

## Points d'Action et Points de Mouvement (§ 13). Les maxima viennent de
## la classe ; les courants sont ce qu'il reste dans l'activation en cours.
var max_action_points: int = 0
var action_points: int = 0
var max_movement_points: int = 0
var movement_points: int = 0

## Place dans la timeline (§ 16) : la plus haute joue en premier.
var initiative: int = 0

var strength: int = 0
var agility: int = 0
var intelligence: int = 0
var defence: int = 0
var critical: int = 0

## Identifiants des compétences dont l'unité dispose, dans l'ordre de la
## barre d'action. La première est son attaque de base.
var abilities: Array[StringName] = []

## Recharges en cours : identifiant de compétence → activations restantes.
## Une entrée absente signifie que la compétence est prête.
var cooldowns: Dictionary = {}

## Effets de statut en cours : identifiant → activations restantes.
var statuses: Dictionary = {}

## Circule dans l'eau, et n'y meurt pas. Vrai pour les créatures
## aquatiques du bestiaire, faux pour tous les héros.
var aquatic: bool = false

## Ignore le terrain : la chauve-souris et le bourdon passent au-dessus
## des rochers, de l'eau et de la forêt.
var flying: bool = false

## Comportement d'IA. Vide pour un héros, que le joueur pilote.
var role: StringName = &""

## Numéro d'emplacement dans l'équipe, à partir de 1. Les doublons de
## classe étant autorisés, c'est la seule chose qui distingue deux
## Guerriers tant que les héros n'ont pas de nom.
var slot: int = 0

var state: int = State.ACTIVE

## Vrai dès que l'unité a dépensé un PM dans l'activation en cours. Le Tir
## puissant de l'Archer ne part que si ce drapeau est faux : c'est ce qui
## rend l'immobilité tentante, et donc le Voleur dangereux.
var has_moved: bool = false


static func reload() -> void:
	_hero_classes = {}
	_enemies = {}


static func hero_classes() -> Dictionary:
	if _hero_classes.is_empty():
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
	return Unit.from_stats(unit_id, class_to_use, Side.HEROES, at, stats)


## Équipe de combat, à partir d'une liste de classes.
##
## LES DOUBLONS SONT AUTORISÉS : deux Guerriers et un Mage est une
## composition légale. Rien ici ne vérifie l'unicité des classes.
##
## Les identifiants vont de 1 à n, dans l'ordre donné. Cet ordre est le
## numéro d'emplacement affiché en jeu : sans lui, deux Guerriers de la
## même couleur sont impossibles à distinguer sur le plateau.
static func squad_from_classes(class_ids: Array) -> Array[Unit]:
	var out: Array[Unit] = []
	var limit := CombatRules.max_heroes()
	if class_ids.size() > limit:
		push_error("Unit : équipe de %d héros, %d au plus" % [class_ids.size(), limit])
	for i in mini(class_ids.size(), limit):
		var unit := Unit.from_hero_class(i + 1, StringName(class_ids[i]), Vector2i.ZERO)
		if unit == null:
			continue
		unit.slot = i + 1
		out.append(unit)
	return out


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
	unit.max_action_points = int(stats.get("action_points", 0))
	unit.action_points = unit.max_action_points
	unit.max_movement_points = int(stats.get("movement_points", 0))
	unit.movement_points = unit.max_movement_points
	unit.initiative = int(stats.get("initiative", 0))
	unit.strength = int(stats.get("strength", 0))
	unit.agility = int(stats.get("agility", 0))
	unit.intelligence = int(stats.get("intelligence", 0))
	unit.defence = int(stats.get("defence", 0))
	unit.critical = int(stats.get("critical", 0))
	unit.aquatic = bool(stats.get("aquatic", false))
	unit.flying = bool(stats.get("flying", false))
	unit.role = StringName(stats.get("role", ""))
	for ability_id: Variant in stats.get("abilities", []):
		unit.abilities.append(StringName(ability_id))
	return unit


static func enemies() -> Dictionary:
	if _enemies.is_empty():
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


## Valeur d'une statistique nommée (§ 12). C'est par là que passe la
## formule de dégâts : une compétence dit « je monte à la Force », elle
## n'a pas besoin de savoir ce qu'est un Guerrier.
func stat(stat_name: StringName) -> int:
	match stat_name:
		STAT_STRENGTH: return strength
		STAT_AGILITY: return agility
		STAT_INTELLIGENCE: return intelligence
		STAT_DEFENCE: return defence
		STAT_CRITICAL: return critical
	return 0


## Identifiant de l'attaque de base : la première de la liste.
func basic_ability() -> StringName:
	return abilities[0] if not abilities.is_empty() else &""


func has_ability(ability_id: StringName) -> bool:
	return abilities.has(ability_id)


## Une compétence est prête si elle n'est pas en recharge.
func is_ready(ability_id: StringName) -> bool:
	return int(cooldowns.get(ability_id, 0)) <= 0


func cooldown_left(ability_id: StringName) -> int:
	return maxi(int(cooldowns.get(ability_id, 0)), 0)


## Met une compétence en recharge pour `turns` activations.
func start_cooldown(ability_id: StringName, turns: int) -> void:
	if turns > 0:
		cooldowns[ability_id] = turns


func has_status(status_id: StringName) -> bool:
	return int(statuses.get(status_id, 0)) > 0


## Pose un statut, ou prolonge celui qui est déjà là.
func apply_status(status_id: StringName, duration: int) -> void:
	if duration <= 0:
		return
	statuses[status_id] = maxi(int(statuses.get(status_id, 0)), duration)


func clear_status(status_id: StringName) -> void:
	statuses.erase(status_id)


## Reste-t-il de quoi lancer cette compétence ?
func can_spend_action_points(cost: int) -> bool:
	return action_points >= cost


func spend_action_points(cost: int) -> bool:
	if cost < 0 or action_points < cost:
		return false
	action_points -= cost
	return true


func spend_movement_points(cost: int) -> bool:
	if cost < 0 or movement_points < cost:
		return false
	movement_points -= cost
	has_moved = has_moved or cost > 0
	return true


## Début d'activation (§ 13) : les PA et les PM reviennent au maximum, les
## recharges descendent d'un cran, les statuts vieillissent.
##
## `movement_penalty` est ce que les statuts retirent de PM — le Gel du
## Mage en enlève 2. C'est le moteur qui le calcule, parce que c'est lui
## qui lit `rules.json` : Unit ne connaît aucun chiffre.
func begin_activation(movement_penalty: int = 0) -> void:
	action_points = max_action_points
	movement_points = maxi(max_movement_points - maxi(movement_penalty, 0), 0)
	has_moved = false
	_tick_down(cooldowns)
	_tick_down(statuses)


## Fait descendre d'un cran tous les compteurs d'un dictionnaire, et
## retire ceux qui arrivent à zéro.
func _tick_down(counters: Dictionary) -> void:
	for key: Variant in counters.keys():
		var left := int(counters[key]) - 1
		if left <= 0:
			counters.erase(key)
		else:
			counters[key] = left


## L'unité a-t-elle encore quelque chose à faire ? Le moteur s'en sert
## pour proposer de passer, jamais pour terminer l'activation d'office :
## rien n'est irréversible tant que le joueur n'a pas validé.
func is_spent() -> bool:
	return action_points <= 0 and movement_points <= 0


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


## Soigne sans dépasser le maximum. Ne relève pas une unité tombée.
func heal(amount: int) -> int:
	if is_downed() or amount <= 0:
		return 0
	var before := hit_points
	hit_points = mini(hit_points + amount, max_hit_points)
	return hit_points - before


## Remet debout une unité tombée, avec le nombre de PV donné.
func revive(with_hit_points: int) -> bool:
	if not is_downed():
		return false
	state = State.ACTIVE
	hit_points = clampi(with_hit_points, 1, max_hit_points)
	return true


func to_dictionary() -> Dictionary:
	var ability_names: Array[String] = []
	for ability_id: StringName in abilities:
		ability_names.append(String(ability_id))
	return {
		"id": id,
		"class": String(class_id),
		"side": int(side),
		"x": cell.x,
		"y": cell.y,
		"max_hit_points": max_hit_points,
		"hit_points": hit_points,
		"max_action_points": max_action_points,
		"action_points": action_points,
		"max_movement_points": max_movement_points,
		"movement_points": movement_points,
		"initiative": initiative,
		"strength": strength,
		"agility": agility,
		"intelligence": intelligence,
		"defence": defence,
		"critical": critical,
		"abilities": ability_names,
		"cooldowns": cooldowns.duplicate(),
		"statuses": statuses.duplicate(),
		"aquatic": aquatic,
		"flying": flying,
		"role": String(role),
		"slot": slot,
		"state": int(state),
		"has_moved": has_moved,
	}


static func from_dictionary(data: Dictionary) -> Unit:
	var unit := Unit.new()
	unit.id = int(data.get("id", -1))
	unit.class_id = StringName(data.get("class", ""))
	unit.side = int(data.get("side", Side.HEROES))
	unit.cell = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	unit.max_hit_points = int(data.get("max_hit_points", 0))
	unit.hit_points = int(data.get("hit_points", 0))
	unit.max_action_points = int(data.get("max_action_points", 0))
	unit.action_points = int(data.get("action_points", 0))
	unit.max_movement_points = int(data.get("max_movement_points", 0))
	unit.movement_points = int(data.get("movement_points", 0))
	unit.initiative = int(data.get("initiative", 0))
	unit.strength = int(data.get("strength", 0))
	unit.agility = int(data.get("agility", 0))
	unit.intelligence = int(data.get("intelligence", 0))
	unit.defence = int(data.get("defence", 0))
	unit.critical = int(data.get("critical", 0))
	for ability_id: Variant in data.get("abilities", []):
		unit.abilities.append(StringName(ability_id))
	unit.cooldowns = (data.get("cooldowns", {}) as Dictionary).duplicate()
	unit.statuses = (data.get("statuses", {}) as Dictionary).duplicate()
	unit.aquatic = bool(data.get("aquatic", false))
	unit.flying = bool(data.get("flying", false))
	unit.role = StringName(data.get("role", ""))
	unit.slot = int(data.get("slot", 0))
	unit.state = int(data.get("state", State.ACTIVE))
	unit.has_moved = bool(data.get("has_moved", false))
	return unit
