class_name HeroNames
extends RefCounted

## Les noms des héros, tirés de `data/heroes/names.json`.
##
## 120 prénoms médiévaux français, et 20 épithètes pour départager deux
## homonymes. Le tirage passe TOUJOURS par `CombatRng` : une compagnie
## doit se régénérer à l'identique à partir de sa graine, sinon rejouer une
## partie ne donne pas la même partie.

const PATH := "res://data/heroes/names.json"

static var _data: Dictionary = {}


static func reload() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("HeroNames : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("HeroNames : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("HeroNames : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


## Tous les prénoms déclarés, les deux listes réunies.
static func all_given() -> Array[String]:
	var out: Array[String] = []
	var given: Dictionary = data().get("given", {})
	for key: String in given.keys():
		if key.begins_with("_"):
			continue
		for name_: Variant in given[key]:
			out.append(String(name_))
	return out


static func epithets() -> Array[String]:
	var out: Array[String] = []
	for entry: Variant in data().get("epithets", []):
		out.append(String(entry))
	return out


## Un prénom au hasard, en évitant ceux déjà portés dans la compagnie.
##
## Quand tous sont pris — 120 noms, cela suppose une compagnie
## considérable — on rend quand même un nom : mieux vaut un homonyme qu'un
## héros sans nom. C'est précisément ce que l'épithète sert à réparer.
static func given(rng: CombatRng, taken: Array[String] = []) -> String:
	var pool := all_given()
	if pool.is_empty():
		push_error("HeroNames : aucun prénom déclaré")
		return ""
	var free: Array[String] = []
	for name_: String in pool:
		if not taken.has(name_):
			free.append(name_)
	var from := free if not free.is_empty() else pool
	return String(rng.pick(from, &"hero_name"))


## Une épithète au hasard, à donner quand le nom est déjà pris.
static func epithet(rng: CombatRng) -> String:
	var pool := epithets()
	if pool.is_empty():
		push_error("HeroNames : aucune épithète déclarée")
		return ""
	return String(rng.pick(pool, &"hero_epithet"))
