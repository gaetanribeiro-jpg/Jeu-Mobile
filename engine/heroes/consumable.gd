class_name Consumable
extends RefCounted

## Les potions du § 44, et la réserve finie qu'elles constituent.
##
## UNE POTION EST UNE COMPÉTENCE, PLUS UN STOCK. Le moteur sait déjà
## porter un coût en PA, une portée, une zone et un effet ; cette classe
## n'ajoute que ce qui manque — combien il en reste, et ce que ça vaut.
## Lui donner un second système de résolution aurait doublé la surface du
## moteur pour rien, ce que le § 46 interdit en toutes lettres.
##
## CE QU'ELLES APPORTENT AU § 29 : une réserve finie qui traverse toute
## l'expédition. Chaque potion bue est une potion que le boss n'aura pas.
## « Je rentre ou je continue ? » gagne un troisième terme après les PV et
## la besace — et c'est le seul des trois sur lequel le joueur décide au
## coup par coup, au lieu de subir.
##
## LE STOCK EST COMMUN À L'ÉQUIPE. Un sac par personnage demanderait une
## gestion d'inventaire que le § 44 ne réclame pas, et transformerait une
## décision tactique en corvée de rangement.

const PATH := "res://data/items/consumables.json"

static var _data: Dictionary = {}


static func clear_cache() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("Consumable : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Consumable : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Consumable : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in data().get("items", {}).keys():
		if not String(key).begins_with("_"):
			out.append(StringName(key))
	return out


static func exists(item_id: StringName) -> bool:
	return data().get("items", {}).has(String(item_id))


static func entry(item_id: StringName) -> Dictionary:
	var items: Dictionary = data().get("items", {})
	if not items.has(String(item_id)):
		push_error("Consumable : « %s » n'existe pas" % item_id)
		return {}
	return items[String(item_id)]


static func name_key(item_id: StringName) -> String:
	return String(entry(item_id).get("name_key", ""))


## La compétence que la potion déclenche. C'est elle qui porte le coût en
## PA, la portée et l'effet : le moteur n'a rien de neuf à apprendre.
static func ability_of(item_id: StringName) -> StringName:
	return StringName(entry(item_id).get("ability", ""))


## La potion qui déclenche cette compétence, ou vide. Le HUD ne manipule
## que des identifiants de compétence — c'est ce qui lui permet de traiter
## une potion exactement comme un sort — et se sert d'ici pour retrouver
## l'objet au moment de le consommer.
static func item_for_ability(ability_id: StringName) -> StringName:
	for item_id: StringName in ids():
		if ability_of(item_id) == ability_id:
			return item_id
	return &""


static func rarity_of(item_id: StringName) -> StringName:
	return StringName(entry(item_id).get("rarity", "common"))


static func icon_of(item_id: StringName) -> String:
	return String(entry(item_id).get("icon", ""))


static func price_of(item_id: StringName) -> int:
	return int(entry(item_id).get("price", 0))


## Ce que la potion épargne, en points de vie. C'est l'unité du barème :
## on ne simule pas mille combats pour une potion, on la paie à ce qu'elle
## évite.
static func value_of(item_id: StringName) -> int:
	return int(entry(item_id).get("value", 0))


## Le prix que le barème réclame pour cette valeur. `verify_items` compare
## celui-ci au prix écrit et refuse l'écart.
static func fair_price(item_id: StringName) -> float:
	var budget: Dictionary = data().get("budget", {})
	return float(value_of(item_id)) * float(budget.get("gold_per_point", 0.0))


static func price_tolerance() -> float:
	return float(data().get("budget", {}).get("tolerance", 0.0))


## Ce que la compagnie possède au premier lancement. Une potion qu'on ne
## peut pas obtenir n'est pas une mécanique, c'est une déclaration.
static func starting_stock() -> Dictionary:
	var out := {}
	var block: Dictionary = data().get("starting_stock", {})
	for key: Variant in block.keys():
		if String(key).begins_with("_"):
			continue
		if not exists(StringName(key)):
			push_error("Consumable : stock de départ inconnu « %s »" % key)
			continue
		out[StringName(key)] = int(block[key])
	return out


## Retire une potion d'un stock. Rend faux s'il n'y en a plus — c'est le
## seul verrou, et il vit ici pour que le moteur de combat et l'écran de
## compagnie ne puissent pas en avoir deux versions différentes.
static func take(stock: Dictionary, item_id: StringName) -> bool:
	var left := int(stock.get(item_id, 0))
	if left <= 0:
		return false
	if left == 1:
		stock.erase(item_id)
	else:
		stock[item_id] = left - 1
	return true


static func add(stock: Dictionary, item_id: StringName, count: int = 1) -> void:
	if count <= 0 or not exists(item_id):
		return
	stock[item_id] = int(stock.get(item_id, 0)) + count


static func total(stock: Dictionary) -> int:
	var sum := 0
	for key: Variant in stock.keys():
		sum += int(stock[key])
	return sum
