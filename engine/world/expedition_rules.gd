class_name ExpeditionRules
extends RefCounted

## Accès aux chiffres d'une expédition, tous dans
## `data/world/expedition.json`.
##
## RÈGLE DURE : aucun nombre de gameplay dans un `.gd`. Cette classe est le
## seul chemin entre le fichier et le moteur, comme `CombatRules` l'est
## pour le combat et `HeroProgression` pour les niveaux.

const PATH := "res://data/world/expedition.json"

static var _data: Dictionary = {}


static func reload() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("ExpeditionRules : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("ExpeditionRules : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ExpeditionRules : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func number(section: StringName, key: StringName, fallback: float) -> float:
	var block: Dictionary = data().get(String(section), {})
	if not block.has(String(key)):
		push_error("ExpeditionRules : « %s.%s » absent de expedition.json" % [section, key])
		return fallback
	return float(block[String(key)])


## Fraction des PV maximums rendue après chaque étape franchie.
static func healing_between_steps() -> float:
	return number(&"healing", &"between_steps", 0.0)


## Fraction rendue en plus par l'étape de récompense du § 28.
static func healing_on_reward_step() -> float:
	return number(&"healing", &"on_reward_step", 0.0)


## Fraction des PV maximums avec laquelle un héros mis à terre se relève
## entre deux étapes. Jamais zéro : ce serait une mort définitive.
static func downed_recovery() -> float:
	return number(&"healing", &"downed_recovery", 0.0)


## Part de la besace qui revient quand même après une déroute (§ 41).
static func satchel_kept_on_wipe() -> float:
	return number(&"wipe", &"satchel_kept", 0.0)


## Nombre d'étapes à franchir avant de pouvoir rentrer.
static func retreat_min_steps() -> int:
	return int(number(&"retreat", &"min_steps", 0))
