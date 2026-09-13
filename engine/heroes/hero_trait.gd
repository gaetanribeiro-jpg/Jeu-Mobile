class_name HeroTrait
extends RefCounted

## Les traits de caractère, lus dans `data/heroes/traits.json`.
##
## ILS FONT DU RECRUTEMENT UN CHOIX. Le reproche était : « un bâtiment =
## une classe = un héros générique ». Trois candidats, trois traits, et
## deux Guerriers cessent d'être interchangeables.
##
## CHAQUE TRAIT EST UN ÉCHANGE, JAMAIS UN BONUS : il donne autant qu'il
## retire, au barème de l'équipement. Sans ça l'un des trois serait « le
## bon », et en proposer trois reviendrait à en proposer un avec deux
## distractions — la faute que `verify_skills` refuse déjà entre deux
## branches d'arbre.
##
## PAS `Trait` : les noms courts sont exactement ceux que Godot risque de
## prendre, et le projet s'est déjà fait avoir par `Skin` (la peau d'un
## squelette) et par `reload()`. Un nom de classe se vérifie avant de
## l'écrire.

const PATH := "res://data/heroes/traits.json"

static var _data: Dictionary = {}


## Vide le cache de données, pour les tests et le rechargement à chaud.
static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("HeroTrait : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("HeroTrait : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("HeroTrait : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func _table() -> Dictionary:
	return data().get("traits", {})


## Les traits, dans l'ordre du FICHIER.
##
## PAS DE `sort()` ICI, ET C'EST UN PIÈGE ÉVITÉ : Godot compare deux
## StringName par ADRESSE, pas par lettre. Un tableau trié se serait donc
## rangé autrement d'un lancement à l'autre — et comme les candidats se
## tirent dans cette liste, les trois proposés auraient changé tout seuls
## en rouvrant la partie. L'ordre du JSON, lui, ne bouge pas.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in _table().keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


static func exists(trait_id: StringName) -> bool:
	return _table().has(String(trait_id))


static func entry(trait_id: StringName) -> Dictionary:
	return _table().get(String(trait_id), {})


static func name_key(trait_id: StringName) -> String:
	return String(entry(trait_id).get("name_key", ""))


static func grants(trait_id: StringName) -> Dictionary:
	return (entry(trait_id).get("grants", {}) as Dictionary).duplicate()


static func costs(trait_id: StringName) -> Dictionary:
	return (entry(trait_id).get("costs", {}) as Dictionary).duplicate()


## Ce que le trait ajoute réellement aux statistiques : les gains moins les
## retraits, en un seul bloc.
##
## RENDU EN UN SEUL BLOC parce que `Hero._apply` prend un dictionnaire de
## modificateurs : deux appels feraient deux passages de la mise à
## l'échelle par statistique primaire, et un trait n'a pas à être meilleur
## pour la classe qui le porte — c'est un caractère, pas un équipement.
static func modifiers(trait_id: StringName) -> Dictionary:
	var out := grants(trait_id)
	for key: Variant in costs(trait_id).keys():
		out[key] = int(out.get(key, 0)) - int(costs(trait_id)[key])
	return out


## Un trait tiré au hasard, à graine. Rend une chaîne vide s'il n'y en a
## aucun — un héros sans trait reste un héros valable.
static func draw(rng: CombatRng, avoid: Array = []) -> StringName:
	var pool: Array[StringName] = []
	for trait_id: StringName in ids():
		if not avoid.has(trait_id):
			pool.append(trait_id)
	if pool.is_empty():
		pool = ids()
	if pool.is_empty():
		return &""
	return StringName(rng.pick(pool, &"hero_trait"))
