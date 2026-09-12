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

## Les potions du § 44, identifiant → compte. COMMUNES À L'ÉQUIPE : un sac
## par personnage demanderait une gestion d'inventaire que le § 44 ne
## réclame pas, et transformerait une décision tactique en rangement.
##
## Elles ne sont PAS dans `stash` malgré la ressemblance : la réserve
## contient des objets uniques qu'on équipe, celle-ci des exemplaires
## qu'on compte et qui disparaissent. Les mélanger obligerait chaque
## appelant à demander de quel genre est l'objet qu'il tient.
var supplies: Dictionary = {}

## Les héros que le joueur emmène, par identifiant et DANS SON ORDRE.
##
## ELLE VIT ICI, ET C'EST TOUT LE PROPOS. Le choix était dans l'écran de
## titre, remis à zéro chaque fois qu'on fermait un écran : le joueur
## repartait toujours avec ses quatre PREMIERS héros, dans l'ordre du
## recrutement. Un cinquième héros ne jouait donc jamais — ce qui vidait de
## son sens le recrutement à trois candidats de T12.3, et la demande de
## Gaetan « changer de personnage ou de composition » avec.
##
## L'ORDRE EST CELUI DU JOUEUR : c'est lui qui donne le numéro
## d'emplacement, et c'est ce qui distingue deux Guerriers sur le plateau.
##
## ELLE SE SÉRIALISE. Une composition qu'il faudrait refaire à chaque
## lancement serait une corvée, pas une décision.
var squad_ids: Array[int] = []

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


## LA COMPOSITION RESTE VALIDE PAR CONSTRUCTION. Entrer ou sortir un héros
## la remet d'aplomb ici, plutôt que de compter sur les appelants pour y
## penser — et c'est la sauvegarde qui l'a imposé : une compagnie bâtie à
## la main n'avait pas d'équipe, la même relue en avait une, et l'aller-
## retour n'était donc pas stable. On retire le piège, on ne protège pas
## les appelants.
func add(hero: Hero) -> bool:
	if hero == null or hero_by_id(hero.id) != null:
		return false
	heroes.append(hero)
	_next_id = maxi(_next_id, hero.id + 1)
	settle_squad()
	return true


## Recrute un héros nommé au hasard, sans homonyme dans la compagnie.
func recruit(class_id: StringName, rng: CombatRng, color: String = "Blue") -> Hero:
	var hero := Hero.recruit(_next_id, class_id, rng, heroes, color)
	if hero == null:
		return null
	add(hero)
	return hero


## Prochain identifiant libre. Le royaume en a besoin pour fabriquer un
## CANDIDAT : un héros qu'on regarde sans l'engager doit porter un
## identifiant plausible sans en consommer un.
func next_id() -> int:
	return _next_id


## Fait entrer un candidat déjà fabriqué, qui reçoit ICI son identifiant.
##
## POURQUOI PAS `add()` : un candidat vit avant d'être engagé, et pendant
## ce temps la compagnie a pu changer. Lui laisser l'identifiant qu'il
## portait à sa fabrication en ferait un doublon le jour où deux écrans
## recrutent — et un doublon écrase un héros à la sauvegarde.
func take(hero: Hero) -> bool:
	if hero == null:
		return false
	hero.id = _next_id
	return add(hero)


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
	settle_squad()
	return hero


# --- L'équipe qui part -----------------------------------------------------

## Ce héros part-il ?
func is_in_squad(hero_id: int) -> bool:
	return squad_ids.has(hero_id)


## Fait entrer ou sortir un héros de l'équipe. Renvoie son nouvel état.
##
## ON NE DESCEND PAS SOUS UN HÉROS et on ne dépasse pas le plafond : la
## carte ne prévoit pas plus de cases de départ, et une équipe vide n'est
## pas une composition, c'est une impasse.
func toggle_squad(hero_id: int) -> bool:
	if hero_by_id(hero_id) == null:
		return false
	if squad_ids.has(hero_id):
		if squad_ids.size() <= 1:
			return true
		squad_ids.erase(hero_id)
		return false
	if squad_ids.size() >= CombatRules.team_size():
		return false
	squad_ids.append(hero_id)
	return true


## Remet la composition d'aplomb : retire ceux qui ont quitté la compagnie,
## complète jusqu'au plafond avec ceux qui restent.
##
## À APPELER APRÈS CHAQUE CHANGEMENT DE COMPAGNIE, et jamais à la place du
## choix du joueur : elle COMPLÈTE une composition, elle ne la refait pas.
## C'est la différence exacte avec l'ancien `_reset_squad`, qui reprenait
## les quatre premiers à chaque fermeture d'écran.
## UN HÉROS PRÊTÉ SORT DE L'ÉQUIPE (T12.12). Il n'est pas là : le laisser
## dans la composition ferait partir un fantôme, et `squad_units` rendrait
## une équipe de trois sans que rien ne s'en plaigne.
func settle_squad() -> void:
	var kept: Array[int] = []
	for hero_id: int in squad_ids:
		var hero := hero_by_id(hero_id)
		if hero != null and hero.is_available() and not kept.has(hero_id):
			kept.append(hero_id)
	squad_ids = kept
	var limit := CombatRules.team_size()
	for hero: Hero in heroes:
		if squad_ids.size() >= limit:
			break
		if not hero.is_available():
			continue
		if not squad_ids.has(hero.id):
			squad_ids.append(hero.id)
	if squad_ids.size() > limit:
		squad_ids = squad_ids.slice(0, limit)


## Les héros qui sont là — ceux qu'aucune ville n'a empruntés.
func available() -> Array[Hero]:
	var out: Array[Hero] = []
	for hero: Hero in heroes:
		if hero.is_available():
			out.append(hero)
	return out


## Les héros en mission chez une voisine, et pour combien de temps.
func lent() -> Array[Hero]:
	var out: Array[Hero] = []
	for hero: Hero in heroes:
		if not hero.is_available():
			out.append(hero)
	return out


## Les héros qui partent, dans l'ordre choisi.
func selected_squad() -> Array[Hero]:
	settle_squad()
	return squad(squad_ids)



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
##
## `bonuses_by_class` est ce que le royaume ajoute, par classe. La
## compagnie ne sait pas d'où ça vient — c'est l'appelant qui relie les
## deux, et c'est ce qui permet de fabriquer une escouade sans royaume, en
## test comme dans le simulateur.
func to_units(
	company_squad: Array[Hero], bonuses_by_class: Dictionary = {}
) -> Array[Unit]:
	var out: Array[Unit] = []
	for i in company_squad.size():
		var bonuses: Dictionary = bonuses_by_class.get(company_squad[i].class_id, {})
		var unit := company_squad[i].to_unit(i + 1, i + 1, bonuses)
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


## Fond un objet de la réserve et verse ses matériaux au royaume. Renvoie
## ce qui a été rendu, vide si l'objet n'y était pas.
##
## LE ROYAUME EST UN PARAMÈTRE, PAS UNE DÉPENDANCE. La compagnie ne sait
## pas ce qu'est un royaume — elle reçoit celui qui encaisse, comme
## `bonuses_by_class` reçoit ce qu'il accorde. C'est ce qui permet de
## fondre un objet en test sans bâtir un royaume autour.
func melt(item_id: StringName, kingdom) -> Dictionary:
	if kingdom == null or not stash.has(item_id):
		return {}
	var gained := Equipment.salvage_of(item_id)
	if gained.is_empty():
		return {}
	stash.erase(item_id)
	kingdom.grant(gained, self)
	return gained


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
	var potions := {}
	for item_id: Variant in supplies.keys():
		potions[String(item_id)] = int(supplies[item_id])
	return {
		"gold": gold,
		"next_id": _next_id,
		"heroes": saved,
		"stash": items,
		"supplies": potions,
		"squad": squad_ids.duplicate(),
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
	# Une potion retirée des données depuis la sauvegarde disparaît du sac,
	# sans emporter la partie avec elle — même règle que la réserve.
	for item_id: Variant in (data.get("supplies", {}) as Dictionary).keys():
		if Consumable.exists(StringName(item_id)):
			company.supplies[StringName(item_id)] = int(data["supplies"][item_id])
	company._next_id = maxi(int(data.get("next_id", 1)), company._next_id)
	# Un héros retiré des données depuis la sauvegarde disparaît de la
	# composition, sans emporter la partie avec lui — même règle que la
	# réserve et le sac. `settle_squad` s'en charge et complète le reste.
	# ON VIDE AVANT DE LIRE, et c'est `add()` qui l'impose : il remet la
	# composition d'aplomb à chaque héros ajouté, donc elle est DÉJÀ pleine
	# des quatre premiers quand on arrive ici. Empiler la composition
	# sauvegardée par-dessus, puis tronquer au plafond, rendait exactement
	# les quatre premiers — le choix du joueur disparaissait au chargement
	# sans que rien ne s'en plaigne.
	company.squad_ids.clear()
	for raw: Variant in data.get("squad", []):
		company.squad_ids.append(int(raw))
	company.settle_squad()
	return company
