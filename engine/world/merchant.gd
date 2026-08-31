class_name Merchant
extends RefCounted

## Le marchand du § 28, lu dans `data/world/merchant.json`.
##
## CE QU'IL APPORTE QUI N'EST PAS UN AUTRE TAS DE BUTIN. Ce qu'on trouve va
## dans la besace et reste en jeu jusqu'au retour ; ce qu'on ACHÈTE est à
## l'abri tout de suite — une déroute ne reprend pas ce qui a été payé.
## L'or n'achète donc pas seulement un objet, il achète de la sécurité, et
## c'est ce qui fait du marchand une décision plutôt qu'une distribution.
##
## EN FACE, L'OR A DÉJÀ UN AUTRE USAGE : le § 32 le destine au royaume.
## Dépenser ici, c'est ne pas bâtir là-bas.
##
## LE PRIX SORT DU BARÈME DE L'ÉQUIPEMENT, jamais d'une liste à part. Un
## objet vaut son budget de rareté multiplié par `gold_per_point` — les
## mêmes points qui servent à `verify_items` pour vérifier qu'il est
## équilibré. Un objet ajouté un jour a donc son prix le jour même, et il
## est juste par construction. Une table de prix séparée aurait dérivé du
## barème dès le deuxième objet ajouté.

const PATH := "res://data/world/merchant.json"

static var _data: Dictionary = {}


static func reload() -> void:
	_data = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		push_error("Merchant : %s introuvable" % PATH)
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Merchant : %s illisible" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Merchant : %s n'est pas un objet JSON" % PATH)
		return {}
	_data = parsed
	return _data


static func number(section: StringName, key: StringName, fallback: float) -> float:
	var block: Dictionary = data().get(String(section), {})
	if not block.has(String(key)):
		push_error("Merchant : « %s.%s » absent de merchant.json" % [section, key])
		return fallback
	return float(block[String(key)])


static func stock_size() -> int:
	return int(number(&"stock", &"size", 0))


static func stock_rarity_bonus() -> int:
	return int(number(&"stock", &"rarity_bonus", 0))


## Ce que le marchand propose à cette profondeur. Tiré à la graine, donc
## rejouable ; l'expédition le retient pour ne pas le retirer au premier
## rechargement.
static func draw_stock(rng: CombatRng, depth: int) -> Array[StringName]:
	return Loot.draw_items(rng, stock_size(), depth, stock_rarity_bonus())


static func price_of(item_id: StringName) -> int:
	if not Equipment.exists(item_id):
		return 0
	var budget := Equipment.rarity_budget(Equipment.rarity_of(item_id))
	return maxi(int(round(budget * number(&"prices", &"gold_per_point", 0.0))), 0)


## Ce que le marchand redonne d'un objet qu'on lui vend. Bas exprès : la
## réserve n'est pas un compte en banque, et revendre doit rester l'aveu
## qu'on n'en avait pas l'usage.
static func resale_of(item_id: StringName) -> int:
	return int(floor(float(price_of(item_id)) * number(&"prices", &"buy_back", 0.0)))


static func can_afford(item_id: StringName, purse: int) -> bool:
	return purse >= price_of(item_id)


## Achète un objet pour la compagnie. Il rejoint la RÉSERVE, pas la
## besace : c'est ce qui distingue l'achat de la trouvaille.
static func buy(item_id: StringName, company: Company) -> bool:
	if company == null or not Equipment.exists(item_id):
		return false
	var price := price_of(item_id)
	if company.gold < price:
		return false
	company.gold -= price
	company.stash.append(item_id)
	return true


## Vend un objet de la réserve. Un objet porté n'est pas dans la réserve,
## et ne peut donc pas partir par mégarde.
static func sell(item_id: StringName, company: Company) -> int:
	if company == null or not company.stash.has(item_id):
		return 0
	var paid := resale_of(item_id)
	company.stash.erase(item_id)
	company.gold += paid
	return paid
