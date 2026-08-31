class_name HeroProgression
extends RefCounted

## Accès aux chiffres de la montée en niveau, tous dans
## `data/heroes/progression.json`.
##
## RÈGLE DURE : aucun nombre de gameplay dans un `.gd`. Cette classe est le
## seul chemin entre le fichier et le moteur, comme `CombatRules` l'est
## pour le combat.

const PATH := "res://data/heroes/progression.json"

## Dans un bloc de gains, ce mot désigne la statistique qui définit la
## classe. Écrire « strength » à la place rendrait la table fausse pour
## deux classes sur trois.
const PRIMARY := &"primary"

static var _data: Dictionary = {}


static func reload() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("HeroProgression : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("HeroProgression : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("HeroProgression : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func max_level() -> int:
	return int(data().get("max_level", 1))


## Expérience totale exigée pour atteindre ce niveau. Zéro au niveau 1.
static func experience_to_reach(level: int) -> int:
	if level <= 1:
		return 0
	var table: Dictionary = data().get("experience_to_reach", {})
	if not table.has(str(level)):
		push_error("HeroProgression : pas de seuil pour le niveau %d" % level)
		return 0
	return int(table[str(level)])


## Expérience accordée par un évènement de combat.
static func award(event: StringName) -> int:
	var table: Dictionary = data().get("experience_awards", {})
	if not table.has(String(event)):
		push_error("HeroProgression : récompense inconnue « %s »" % event)
		return 0
	return int(table[String(event)])


## Gains accordés à chaque montée, sans condition.
static func per_level() -> Dictionary:
	return _grants(data().get("per_level", {}))


## Gains accordés en plus aux niveaux pairs.
static func every_other_level() -> Dictionary:
	return _grants(data().get("every_other_level", {}))


## Options offertes à ce niveau. Vide si le niveau ne demande pas de choix.
static func choices_at(level: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var table: Dictionary = data().get("choices", {})
	for entry: Variant in table.get(str(level), []):
		out.append(StringName(entry))
	return out


## Tous les niveaux qui demandent un choix, en ordre croissant.
static func choice_levels() -> Array[int]:
	var out: Array[int] = []
	for key: String in (data().get("choices", {}) as Dictionary).keys():
		if key.is_valid_int():
			out.append(int(key))
	out.sort()
	return out


static func option(option_id: StringName) -> Dictionary:
	var found: Dictionary = (data().get("options", {}) as Dictionary).get(
		String(option_id), {}
	)
	if found.is_empty():
		push_error("HeroProgression : option inconnue « %s »" % option_id)
	return found


static func option_grants(option_id: StringName) -> Dictionary:
	return _grants(option(option_id).get("grants", {}))


static func option_name_key(option_id: StringName) -> String:
	return String(option(option_id).get("name_key", ""))


## Retire les clés de commentaire d'un bloc de gains. Un `_note` compté
## comme une statistique donnerait un héros avec une caractéristique
## fantôme, et le bogue serait très difficile à voir.
static func _grants(raw: Dictionary) -> Dictionary:
	var out := {}
	for key: String in raw.keys():
		if not key.begins_with("_"):
			out[StringName(key)] = int(raw[key])
	return out
