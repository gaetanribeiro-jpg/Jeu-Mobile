class_name Region
extends RefCounted

## Les régions du monde, lues dans `data/world/regions.json` (§ 26).
##
## Une seule est jouable au MVP — les Terres Vertes. Les cinq autres sont
## déclarées et verrouillées : la carte du monde a ainsi quelque chose à
## montrer sans qu'on ait inventé leur contenu, et le joueur voit où il
## ira. Une région verrouillée n'a donc PAS de cartes, et rien ici ne doit
## en exiger.
##
## L'ESCALADE DU § 29 VIT ICI, et elle ne touche à aucun chiffre de
## combat. `encounter_maps` est rangée du plus facile au plus dur, et le
## tirage d'une rencontre ne pioche pas dans toute la liste : il pioche
## dans une fenêtre qui glisse avec la profondeur. Plus le joueur
## s'enfonce, plus les cartes faciles cessent de sortir. C'est la
## SÉLECTION qui monte, pas les ennemis — ce qui laisse l'équilibrage de
## T1.11 intact.

const PATH := "res://data/world/regions.json"

static var _data: Dictionary = {}


## Vide le cache de données, pour les tests et le rechargement à chaud.
##
## PAS `reload()` : ce nom entre en collision avec `Script.reload()` de
## Godot, et c'est CELUI-LÀ qui était appelé — « Cannot reload script while
## instances exist », 472 fois par exécution des tests. Le cache n'était
## donc jamais vidé, et la table de données que le test croyait relire
## était celle du test précédent.
static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("Region : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Region : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Region : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func _table() -> Dictionary:
	return data().get("regions", {})


## Toutes les régions, dans l'ordre de leur acte : c'est l'ordre dans
## lequel la carte du monde les propose, et il ne doit pas dépendre de
## l'ordre d'écriture du fichier.
static func ids() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: String in _table().keys():
		if not key.begins_with("_"):
			keys.append(StringName(key))
	keys.sort_custom(func(a: StringName, b: StringName) -> bool:
		if act_of(a) != act_of(b):
			return act_of(a) < act_of(b)
		return a < b)
	return keys


## Les régions où le joueur peut partir aujourd'hui.
static func unlocked_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for region_id: StringName in ids():
		if is_unlocked(region_id):
			out.append(region_id)
	return out


static func exists(region_id: StringName) -> bool:
	return _table().has(String(region_id))


static func entry(region_id: StringName) -> Dictionary:
	var table := _table()
	if not table.has(String(region_id)):
		push_error("Region : région inconnue « %s »" % region_id)
		return {}
	return table[String(region_id)]


static func name_key(region_id: StringName) -> String:
	return String(entry(region_id).get("name_key", ""))


static func description_key(region_id: StringName) -> String:
	return String(entry(region_id).get("description_key", ""))


static func act_of(region_id: StringName) -> int:
	return int(entry(region_id).get("act", 1))


static func is_unlocked(region_id: StringName) -> bool:
	return bool(entry(region_id).get("unlocked", false))


static func encounter_maps(region_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for map_id: Variant in entry(region_id).get("encounter_maps", []):
		out.append(StringName(map_id))
	return out


## Ce que la région envoie en renfort quand la nuit tombe (§ 36). Vide,
## la région n'a pas de nuit — ce qui est une réponse valable, pas un
## défaut : une région souterraine n'a pas de jour à perdre.
static func night_roster(region_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for enemy_id: Variant in entry(region_id).get("night_roster", []):
		out.append(StringName(enemy_id))
	return out


static func miniboss_map(region_id: StringName) -> StringName:
	return StringName(entry(region_id).get("miniboss_map", ""))


static func boss_map(region_id: StringName) -> StringName:
	return StringName(entry(region_id).get("boss_map", ""))


## Ce qu'une rencontre de cette région rapporte au royaume, avant
## variance et profondeur. C'est le maillon « exploration → ressources » du
## § 45 : sans lui, l'expédition et le royaume vivent chacun de leur côté.
static func resources_per_encounter(region_id: StringName) -> Dictionary:
	var out := {}
	var declared: Dictionary = entry(region_id).get("resources_per_encounter", {})
	for key: String in declared.keys():
		if not key.begins_with("_"):
			out[StringName(key)] = int(declared[key])
	return out


## Ce qu'une rencontre rapporte vraiment : la déclaration de la région,
## augmentée par la profondeur et bousculée par la variance, exactement
## comme l'or. Deux courbes différentes pour deux ressources qui financent
## la même chose auraient été impossibles à équilibrer.
static func draw_resources(region_id: StringName, rng: CombatRng, depth: int = 0) -> Dictionary:
	var out := {}
	if rng == null:
		return out
	var deeper := 1.0 + Loot.number(&"depth", &"gold_per_step", 0.0) * float(maxi(depth, 0))
	var spread := Loot.number(&"gold", &"variance", 0.0)
	for resource_id: StringName in resources_per_encounter(region_id).keys():
		var base := float(resources_per_encounter(region_id)[resource_id]) * deeper
		var swing := 1.0 + (rng.unit_float(&"region_resources") * 2.0 - 1.0) * spread
		var gained := maxi(int(round(base * swing)), 0)
		if gained > 0:
			out[resource_id] = gained
	return out


static func chain(region_id: StringName) -> Dictionary:
	return entry(region_id).get("chain", {})


## Les étapes qui se répètent, et celles qui closent toujours la chaîne.
static func chain_pattern(region_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for kind: Variant in chain(region_id).get("pattern", []):
		out.append(StringName(kind))
	return out


static func chain_tail(region_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for kind: Variant in chain(region_id).get("tail", []):
		out.append(StringName(kind))
	return out


## Longueur du corps de la chaîne, tirée à la graine. La fin s'y ajoute.
static func body_length(region_id: StringName, rng: CombatRng) -> int:
	var body: Dictionary = chain(region_id).get("body", {})
	var low := int(body.get("min", 0))
	var high := int(body.get("max", low))
	if rng == null or high <= low:
		return maxi(low, 0)
	return rng.int_between(low, high, &"expedition_length")


## La fenêtre de cartes tirables à cette profondeur : un sous-ensemble
## contigu de `encounter_maps`, qui glisse vers les cartes dures à mesure
## que le joueur s'enfonce.
static func map_window(region_id: StringName, depth: int) -> Array[StringName]:
	var maps := encounter_maps(region_id)
	if maps.is_empty():
		return maps
	var window: Dictionary = entry(region_id).get("map_window", {})
	var size := int(window.get("size", maps.size()))
	if size <= 0 or size >= maps.size():
		return maps
	var slide := float(window.get("slide", 0.0))
	var start := int(floor(float(maxi(depth, 0)) * slide))
	start = clampi(start, 0, maps.size() - size)
	return maps.slice(start, start + size)


## Une carte de rencontre pour cette profondeur. `avoid` sert à ne pas
## rejouer la carte qu'on vient de faire : deux fois la même de suite est
## la seule répétition que le joueur remarque vraiment.
static func draw_map(region_id: StringName, depth: int, rng: CombatRng, avoid: StringName = &"") -> StringName:
	var window := map_window(region_id, depth)
	if window.is_empty():
		push_error("Region : « %s » n'a aucune carte de rencontre" % region_id)
		return &""
	var pool := window.duplicate()
	if pool.size() > 1 and pool.has(avoid):
		pool.erase(avoid)
	if rng == null:
		return pool[0]
	return StringName(rng.pick(pool, &"expedition_map"))
