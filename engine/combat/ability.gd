class_name Ability
extends RefCounted

## Les capacités de classe, lues dans `data/units/abilities.json`.
##
## Les quatre premières couvrent les quatre verbes tactiques du § 3.1 —
## attirer, frapper à distance, déplacer, annuler — et toute la profondeur
## du combat vient de leurs combinaisons. Aucune n'a de valeur chiffrée
## dans le code.

const ABILITIES_PATH := "res://data/units/abilities.json"

const KIND_TAUNT := &"taunt"
const KIND_ATTACK := &"attack"
const KIND_PUSH := &"push"
const KIND_WARD := &"ward"

static var _abilities: Dictionary = {}


static func reload() -> void:
	_abilities = {}


static func all() -> Dictionary:
	if not _abilities.is_empty():
		return _abilities
	if not FileAccess.file_exists(ABILITIES_PATH):
		push_error("Ability : %s introuvable" % ABILITIES_PATH)
		return {}
	var file := FileAccess.open(ABILITIES_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Ability : %s n'est pas un objet JSON" % ABILITIES_PATH)
		return {}
	_abilities = parsed
	return _abilities


static func get_ability(ability_id: StringName) -> Dictionary:
	var found: Dictionary = all().get(String(ability_id), {})
	if found.is_empty():
		push_error("Ability : capacité inconnue « %s »" % ability_id)
	return found


static func kind_of(ability_id: StringName) -> StringName:
	return StringName(get_ability(ability_id).get("kind", ""))


## Capacité de départ d'une classe de héros (§ 3.1).
static func first_of_class(class_id: StringName) -> StringName:
	return StringName(Unit.hero_class(class_id).get("ability", ""))


## Seconde capacité, débloquée au rang 3 de l'Ordre (§ 3.5.3).
static func second_of_class(class_id: StringName) -> StringName:
	return StringName(Unit.hero_class(class_id).get("second_ability", ""))


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in all().keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out
