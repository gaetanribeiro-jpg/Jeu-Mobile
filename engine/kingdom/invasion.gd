class_name Invasion
extends RefCounted

## Une invasion du royaume (§ 37), lue dans
## `data/kingdom/invasions.json`.
##
## CE QU'ELLE APPORTE À LA BOUCLE, et c'est la seule raison de l'écrire.
## Jusqu'ici, partir en expédition ne coûtait rien au royaume : il
## produisait pendant l'absence, sans risque. L'invasion le met EN JEU, et
## donne au § 29 une seconde question — « je rentre pour le butin » devient
## « je rentre pour le butin OU pour défendre ».
##
## LA MENACE EST UN COMPTEUR, PAS UNE PROBABILITÉ. Un tirage pourrait
## épargner un joueur toute une partie, et une mécanique qu'on peut ne
## jamais rencontrer n'en est pas une. Elle monte avec l'absence et avec ce
## qu'il y a à prendre : un hameau n'intéresse personne, un royaume bâti
## attire. Bâtir a donc un revers, et le § 50 veut qu'une récompense soit
## tentante, pas gratuite.
##
## L'ARMÉE PEUT DÉFENDRE SEULE, et le § 37 l'exige. Le joueur qui rentre
## apporte un bonus : rentrer doit être MEILLEUR, jamais obligatoire.
##
## CLASSE PURE. Elle ne connaît ni nœud ni sauvegarde ; c'est l'appelant
## qui la fait vivre.

const PATH := "res://data/kingdom/invasions.json"

static var _data: Dictionary = {}

## Force de l'assaut, tirée à la déclaration.
var strength: int = 0

## Étapes d'expédition avant que l'assaut ne tombe. Le joueur a ce
## délai-là pour rentrer, et c'est ce qui en fait un choix plutôt qu'une
## nouvelle.
var steps_left: int = 0


static func reload() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("Invasion : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Invasion : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invasion : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func number(section: StringName, key: StringName, fallback: float) -> float:
	var block: Dictionary = data().get(String(section), {})
	if not block.has(String(key)):
		push_error("Invasion : « %s.%s » absent de invasions.json" % [section, key])
		return fallback
	return float(block[String(key)])


# --- La menace -------------------------------------------------------------

## Ce qu'une étape d'expédition ajoute à la menace d'un royaume.
static func threat_per_step(building_levels: int) -> int:
	return int(round(
		number(&"threat", &"per_step", 0.0)
		+ number(&"threat", &"per_building_level", 0.0) * float(maxi(building_levels, 0))
	))


static func threat_trigger() -> int:
	return int(number(&"threat", &"trigger", 0.0))


static func warning_steps() -> int:
	return int(number(&"threat", &"warning_steps", 0))


## Déclare un assaut. `depth` est la profondeur de la sortie en cours :
## un royaume laissé longtemps sans défenseur est repéré.
static func declare(rng: CombatRng, building_levels: int, depth: int) -> Invasion:
	var raid := Invasion.new()
	var base := (
		number(&"strength", &"base", 0.0)
		+ number(&"strength", &"per_building_level", 0.0) * float(maxi(building_levels, 0))
		+ number(&"strength", &"per_depth", 0.0) * float(maxi(depth, 0))
	)
	var spread := number(&"strength", &"variance", 0.0)
	var swing := 1.0
	if rng != null:
		swing = 1.0 + (rng.unit_float(&"invasion_strength") * 2.0 - 1.0) * spread
	raid.strength = maxi(int(round(base * swing)), 1)
	raid.steps_left = warning_steps()
	return raid


## Fait avancer le compte à rebours. Renvoie true quand l'assaut tombe.
func advance() -> bool:
	steps_left = maxi(steps_left - 1, 0)
	return steps_left <= 0


func is_imminent() -> bool:
	return steps_left <= 0


# --- La défense ------------------------------------------------------------

## Ce que le royaume oppose. `hero_levels` est la somme des niveaux des
## héros rentrés défendre — zéro si l'armée est seule.
static func defence_of(building_levels: int, population: int, hero_levels: int = 0) -> int:
	return int(round(
		number(&"defence", &"per_building_level", 0.0) * float(maxi(building_levels, 0))
		+ number(&"defence", &"per_pawn", 0.0) * float(maxi(population, 0))
		+ number(&"defence", &"hero_bonus_per_level", 0.0) * float(maxi(hero_levels, 0))
	))


func is_repelled_by(defence: int) -> bool:
	return defence >= strength


## Ce qu'une défense ratée coûte : des RESSOURCES, jamais un bâtiment
## détruit ni un habitant tué. Le § 41 refuse la punition absolue, et voir
## son château redescendre d'un niveau après trois heures de jeu ferait
## fermer l'application. Le pillage fait mal et se rattrape.
static func plunder(kingdom: Kingdom, company: Company) -> Dictionary:
	var taken := {}
	if kingdom == null:
		return taken
	var share := clampf(number(&"losses", &"resources_fraction", 0.0), 0.0, 1.0)
	for resource_id: StringName in kingdom.stores.keys():
		var lost := int(floor(float(kingdom.stores[resource_id]) * share))
		if lost > 0:
			kingdom.stores[resource_id] = int(kingdom.stores[resource_id]) - lost
			taken[resource_id] = lost
	if company != null:
		var gold := int(floor(
			float(company.gold) * clampf(number(&"losses", &"gold_fraction", 0.0), 0.0, 1.0)
		))
		if gold > 0:
			company.gold -= gold
			taken[&"gold"] = gold
	return taken


## Ce qu'une défense réussie rapporte : les assaillants laissent leur
## barda. Modeste — repousser une invasion est déjà la récompense.
func spoils() -> int:
	return maxi(int(round(
		float(strength) * number(&"spoils", &"gold_per_strength", 0.0)
	)), 0)


# --- Sérialisation ---------------------------------------------------------

func to_dictionary() -> Dictionary:
	return {"strength": strength, "steps_left": steps_left}


static func from_dictionary(saved: Dictionary) -> Invasion:
	if saved.is_empty():
		return null
	var raid := Invasion.new()
	raid.strength = int(saved.get("strength", 0))
	raid.steps_left = int(saved.get("steps_left", 0))
	return raid
