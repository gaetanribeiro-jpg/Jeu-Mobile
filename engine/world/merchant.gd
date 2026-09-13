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


static func stock_supplies() -> int:
	return int(number(&"stock", &"supplies", 0))


## Le nombre de RANGS de l'étal : équipement et potions confondus.
##
## `stock_size` ne compte que l'équipement, et c'est ce qui compte quand
## on parle de tirage ; mais le rang dans la liste est ce qui identifie un
## emplacement vendu, donc ce qui parle d'affichage ou d'achat a besoin du
## total. Deux noms parce que ce sont deux questions.
static func stall_size() -> int:
	return stock_size() + stock_supplies()


## Ce que le marchand propose à cette profondeur. Tiré à la graine, donc
## rejouable ; l'expédition le retient pour ne pas le retirer au premier
## rechargement.
##
## DES PLACES RÉSERVÉES AUX POTIONS, pas un tirage mêlé (T10.2). Le
## marchand est le seul endroit où le joueur CHOISIT ce qu'il emporte ; un
## étal qui ne proposerait des potions qu'une fois sur trois ne serait pas
## un ravitaillement. Le butin, lui, décide à sa place — c'est toute la
## différence entre trouver et acheter.
##
## L'équipement d'abord, les potions ensuite : le rang dans la liste EST
## l'identifiant d'un emplacement d'étal (`sold_slots`), donc l'ordre ne
## doit dépendre que du tirage, jamais de l'affichage.
static func draw_stock(rng: CombatRng, depth: int) -> Array[StringName]:
	var listed := Loot.draw_items(rng, stock_size(), depth, stock_rarity_bonus())
	# LE COUP DE POUCE DE RARETÉ NE S'APPLIQUE PAS AUX POTIONS, et c'est
	# une leçon prise en le faisant : il n'y a de potions que dans deux
	# raretés, donc relever le plancher d'un cran ne laissait qu'une seule
	# fiole possible et l'étal proposait deux fois la même. L'avantage du
	# marchand sur les potions n'est pas d'en vendre de meilleures — c'est
	# d'en vendre TOUT COURT, et de laisser choisir.
	listed.append_array(Loot.draw_supplies(rng, stock_supplies(), depth, 0, true))
	return listed


## Le prix d'un objet, équipement ou potion.
##
## L'ÉTAL VEND DEUX FAMILLES, ET C'EST ICI QUE ÇA SE DÉMÊLE, une seule
## fois. Chacune a déjà son barème vérifié — l'équipement au point de
## rareté, la potion au point de vie épargné — et les fondre en un seul
## reviendrait à dire qu'une armure et une fiole se comparent, ce qui est
## faux. L'appelant, lui, tient un identifiant et veut un prix.
static func price_of(item_id: StringName) -> int:
	if Consumable.exists(item_id):
		return Consumable.price_of(item_id)
	if not Equipment.exists(item_id):
		return 0
	var budget := Equipment.rarity_budget(Equipment.rarity_of(item_id))
	return maxi(int(round(budget * number(&"prices", &"gold_per_point", 0.0))), 0)


## Le nom affichable d'un objet de l'étal, quelle que soit sa famille.
static func name_key_of(item_id: StringName) -> String:
	if Consumable.exists(item_id):
		return Consumable.name_key(item_id)
	return Equipment.name_key(item_id)


## Sa rareté, sur l'échelle commune aux deux familles.
static func rarity_of(item_id: StringName) -> StringName:
	if Consumable.exists(item_id):
		return Consumable.rarity_of(item_id)
	return Equipment.rarity_of(item_id)


## Ce que le marchand redonne d'un objet qu'on lui vend. Bas exprès : la
## réserve n'est pas un compte en banque, et revendre doit rester l'aveu
## qu'on n'en avait pas l'usage.
static func resale_of(item_id: StringName) -> int:
	return int(floor(float(price_of(item_id)) * number(&"prices", &"buy_back", 0.0)))


static func can_afford(item_id: StringName, purse: int) -> bool:
	return purse >= price_of(item_id)


## Achète un objet pour la compagnie. Il rejoint la RÉSERVE, pas la
## besace : c'est ce qui distingue l'achat de la trouvaille.
##
## UNE POTION VA DANS LE SAC, PAS DANS LA RÉSERVE. Les deux ne se
## rangent pas pareil — la réserve contient des objets uniques qu'on
## équipe, le sac des exemplaires qu'on compte — et surtout une potion
## achetée doit être buvable à l'étape suivante. Une fiole qui attendrait
## le retour au royaume ne serait un ravitaillement pour personne.
static func buy(item_id: StringName, company: Company) -> bool:
	if company == null:
		return false
	var is_supply := Consumable.exists(item_id)
	if not is_supply and not Equipment.exists(item_id):
		return false
	var price := price_of(item_id)
	if company.gold < price:
		return false
	company.gold -= price
	if is_supply:
		Consumable.add(company.supplies, item_id)
	else:
		company.stash.append(item_id)
	return true


## Vend un objet de la réserve. Un objet porté n'est pas dans la réserve,
## et ne peut donc pas partir par mégarde.
##
## ON NE REVEND PAS UNE POTION, et rien n'a eu à l'interdire : les
## potions ne sont pas dans `stash`, donc la condition ci-dessous les
## écarte d'elle-même. C'est la bonne réponse — revendre une consommable
## à 35 % en ferait un placement, alors qu'elle est faite pour être bue.
static func sell(item_id: StringName, company: Company) -> int:
	if company == null or not company.stash.has(item_id):
		return 0
	var paid := resale_of(item_id)
	company.stash.erase(item_id)
	company.gold += paid
	return paid
