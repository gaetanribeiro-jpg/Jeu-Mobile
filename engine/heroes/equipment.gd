class_name Equipment
extends RefCounted

## L'équipement, lu dans `data/items/equipment.json`.
##
## Cinq emplacements et cinq raretés (§ 30, § 31). Un objet est décrit
## entièrement par ses données : son emplacement, sa rareté, ce qu'il
## accorde, et les classes qui ont le droit de le porter.
##
## LE BUDGET EST LA RÈGLE. Chaque rareté vaut un nombre de points, et les
## gains d'un objet doivent le valoir exactement. Sans ce garde-fou, un
## légendaire inventé un soir de fatigue casse le jeu sans que rien ne le
## signale ; avec lui, `tools/verify_items.gd` le dit.

const PATH := "res://data/items/equipment.json"

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
		push_error("Equipment : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Equipment : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Equipment : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


## Les cinq emplacements, dans l'ordre où la fiche de héros les montre.
static func slots() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Variant in data().get("slots", []):
		out.append(StringName(entry))
	return out


static func is_slot(slot: StringName) -> bool:
	return slots().has(slot)


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in (data().get("items", {}) as Dictionary).keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


static func item(item_id: StringName) -> Dictionary:
	var found: Dictionary = (data().get("items", {}) as Dictionary).get(
		String(item_id), {}
	)
	if found.is_empty():
		push_error("Equipment : objet inconnu « %s »" % item_id)
	return found


static func exists(item_id: StringName) -> bool:
	return (data().get("items", {}) as Dictionary).has(String(item_id))


static func slot_of(item_id: StringName) -> StringName:
	return StringName(item(item_id).get("slot", ""))


static func rarity_of(item_id: StringName) -> StringName:
	return StringName(item(item_id).get("rarity", ""))


static func icon_of(item_id: StringName) -> StringName:
	return StringName(item(item_id).get("icon", ""))


static func name_key(item_id: StringName) -> String:
	return "ITEM_%s" % String(item_id).to_upper()


## Ce que l'objet accorde, prêt à être additionné aux statistiques.
static func grants(item_id: StringName) -> Dictionary:
	var out := {}
	var raw: Dictionary = item(item_id).get("grants", {})
	for key: String in raw.keys():
		if not key.begins_with("_"):
			out[StringName(key)] = int(raw[key])
	return out


## Cette classe a-t-elle le droit de porter cet objet ?
##
## Un objet sans restriction est ouvert à tous : sur-restreindre laisserait
## des emplacements morts sur deux classes.
static func allows(item_id: StringName, class_id: StringName) -> bool:
	var restricted: Array = item(item_id).get("classes", [])
	if restricted.is_empty():
		return true
	return restricted.has(String(class_id))


# --- Raretés ---------------------------------------------------------------

static func rarities() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in (data().get("rarities", {}) as Dictionary).keys():
		if not key.begins_with("_"):
			out.append(StringName(key))
	return out


static func rarity(rarity_id: StringName) -> Dictionary:
	var found: Dictionary = (data().get("rarities", {}) as Dictionary).get(
		String(rarity_id), {}
	)
	if found.is_empty():
		push_error("Equipment : rareté inconnue « %s »" % rarity_id)
	return found


static func rarity_budget(rarity_id: StringName) -> float:
	return float(rarity(rarity_id).get("budget", 0))


## Poids de tirage d'une rareté. Un commun sort bien plus souvent qu'un
## légendaire, et c'est ce qui donne son prix au légendaire.
static func rarity_weight(rarity_id: StringName) -> int:
	return int(rarity(rarity_id).get("weight", 0))


static func rarity_color(rarity_id: StringName) -> Color:
	var raw: Array = rarity(rarity_id).get("color", [1, 1, 1, 1])
	if raw.size() < 4:
		return Color.WHITE
	return Color(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))


static func rarity_name_key(rarity_id: StringName) -> String:
	return String(rarity(rarity_id).get("name_key", ""))


# --- Budget ----------------------------------------------------------------

## Ce que vaut un bloc de gains, au barème de `costs`.
##
## SORTI DE `cost_of` POUR SERVIR AILLEURS : les nœuds d'arbre accordent
## les mêmes statistiques que les objets, et il n'y a aucune raison de les
## peser autrement. Deux barèmes divergeraient dès la première retouche.
static func price_of_grants(gained: Dictionary) -> float:
	var costs: Dictionary = data().get("costs", {})
	var total := 0.0
	for key: Variant in gained.keys():
		if String(key).begins_with("_"):
			continue
		if not costs.has(String(key)):
			push_error("Equipment : « %s » n'a pas de coût au barème" % key)
			continue
		total += float(costs[String(key)]) * float(gained[key])
	return total


## Ce que valent les gains d'un objet, au barème de `costs`.
static func cost_of(item_id: StringName) -> float:
	var costs: Dictionary = data().get("costs", {})
	var total := 0.0
	for key: Variant in grants(item_id).keys():
		if not costs.has(String(key)):
			push_error("Equipment : « %s » n'a pas de prix au barème" % key)
			continue
		total += float(costs[String(key)]) * float(grants(item_id)[key])
	return total


## L'objet vaut-il exactement le budget de sa rareté ?
static func is_within_budget(item_id: StringName) -> bool:
	return is_equal_approx(cost_of(item_id), rarity_budget(rarity_of(item_id)))


## Objets d'un emplacement donné, éventuellement filtrés par classe.
static func of_slot(slot: StringName, class_id: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for item_id: StringName in ids():
		if slot_of(item_id) != slot:
			continue
		if not class_id.is_empty() and not allows(item_id, class_id):
			continue
		out.append(item_id)
	return out
