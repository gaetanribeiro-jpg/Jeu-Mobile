class_name Company
extends RefCounted

## La compagnie : les héros du joueur, son or, et sa réserve d'objets.
##
## C'est l'état qui traverse toute la campagne, et le seul qu'il faille
## sauvegarder entre deux rencontres. Le combat n'en sait rien : il reçoit
## des `Unit`, il rend un journal, et c'est ici qu'on encaisse le résultat.
##
## LA RÉSERVE N'EST PAS UN INVENTAIRE DE JEU DE RÔLE. Elle ne fait que
## contenir ce qui n'est pas porté. Le § 32 lui donnera d'autres usages —
## vendre, améliorer une arme, améliorer un bâtiment — et ils viendront
## s'y brancher sans qu'elle ait à changer de forme.

## Héros de la compagnie, tous, y compris ceux qui restent au royaume.
var heroes: Array[Hero] = []

var gold: int = 0

## Objets possédés et non portés.
var stash: Array[StringName] = []

## Prochain identifiant de héros. Il ne redescend jamais, même après un
## départ : deux héros ne doivent jamais partager un identifiant, sinon une
## sauvegarde en écrase un.
var _next_id: int = 1


func size() -> int:
	return heroes.size()


func hero_by_id(hero_id: int) -> Hero:
	for hero: Hero in heroes:
		if hero.id == hero_id:
			return hero
	return null


func add(hero: Hero) -> bool:
	if hero == null or hero_by_id(hero.id) != null:
		return false
	heroes.append(hero)
	_next_id = maxi(_next_id, hero.id + 1)
	return true


## Recrute un héros nommé au hasard, sans homonyme dans la compagnie.
func recruit(class_id: StringName, rng: CombatRng, color: String = "Blue") -> Hero:
	var hero := Hero.recruit(_next_id, class_id, rng, heroes, color)
	if hero == null:
		return null
	add(hero)
	return hero


## Retire un héros de la compagnie et rend son équipement à la réserve.
func remove(hero_id: int) -> Hero:
	var hero := hero_by_id(hero_id)
	if hero == null:
		return null
	for slot: StringName in Equipment.slots():
		var item_id := hero.unequip(slot)
		if not item_id.is_empty():
			stash.append(item_id)
	heroes.erase(hero)
	return hero


# --- L'équipe qui part -----------------------------------------------------

## Les héros que le joueur emmène, dans l'ordre donné. Refuse au-delà du
## plafond de `rules.json` : la carte ne prévoit pas plus de cases.
func squad(hero_ids: Array) -> Array[Hero]:
	var out: Array[Hero] = []
	var limit := CombatRules.max_heroes()
	if hero_ids.size() > limit:
		push_error("Company : équipe de %d, %d au plus" % [hero_ids.size(), limit])
	for i in mini(hero_ids.size(), limit):
		var hero := hero_by_id(int(hero_ids[i]))
		if hero != null:
			out.append(hero)
	return out


## Fabrique les unités de combat d'une équipe, numérotées de 1 à n. L'ordre
## donne le numéro d'emplacement, qui est ce qui distingue deux Guerriers.
func to_units(company_squad: Array[Hero]) -> Array[Unit]:
	var out: Array[Unit] = []
	for i in company_squad.size():
		var unit := company_squad[i].to_unit(i + 1, i + 1)
		if unit != null:
			out.append(unit)
	return out


# --- Encaisser une rencontre -----------------------------------------------

## Verse l'or et range les objets d'un butin. Renvoie ce qui a été rangé.
func collect(loot: Dictionary) -> Array[StringName]:
	var taken: Array[StringName] = []
	gold += maxi(int(loot.get("gold", 0)), 0)
	for item_id: Variant in loot.get("items", []):
		var wanted := StringName(item_id)
		if not Equipment.exists(wanted):
			continue
		stash.append(wanted)
		taken.append(wanted)
	return taken


## Fait porter un objet de la réserve à un héros. Ce qu'il portait déjà
## retourne à la réserve — rien ne se perd.
func equip_from_stash(hero_id: int, item_id: StringName) -> bool:
	var hero := hero_by_id(hero_id)
	if hero == null or not stash.has(item_id) or not hero.can_equip(item_id):
		return false
	stash.erase(item_id)
	var replaced := hero.equip(item_id)
	if not replaced.is_empty():
		stash.append(replaced)
	return true


## Retire un objet d'un héros et le rend à la réserve.
func unequip_to_stash(hero_id: int, slot: StringName) -> bool:
	var hero := hero_by_id(hero_id)
	if hero == null:
		return false
	var removed := hero.unequip(slot)
	if removed.is_empty():
		return false
	stash.append(removed)
	return true


# --- Sérialisation ---------------------------------------------------------

func to_dictionary() -> Dictionary:
	var saved: Array = []
	for hero: Hero in heroes:
		saved.append(hero.to_dictionary())
	var items: Array = []
	for item_id: StringName in stash:
		items.append(String(item_id))
	return {
		"gold": gold,
		"next_id": _next_id,
		"heroes": saved,
		"stash": items,
	}


static func from_dictionary(data: Dictionary) -> Company:
	var company := Company.new()
	company.gold = int(data.get("gold", 0))
	for raw: Variant in data.get("heroes", []):
		company.add(Hero.from_dictionary(raw))
	for item_id: Variant in data.get("stash", []):
		# Un objet retiré des données depuis la sauvegarde disparaît de la
		# réserve, sans emporter la partie avec lui.
		if Equipment.exists(StringName(item_id)):
			company.stash.append(StringName(item_id))
	company._next_id = maxi(int(data.get("next_id", 1)), company._next_id)
	return company
