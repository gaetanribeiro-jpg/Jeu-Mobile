class_name Kingdom
extends RefCounted

## Le royaume : ses réserves, ses habitants, ses chantiers (§ 6, § 9).
##
## LE CYCLE EST UNE EXPÉDITION, PAS UNE MINUTE. Aucun timer, aucune
## énergie — c'est une décision verrouillée, et le § 2 refuse le
## free-to-play. Le royaume produit une fois par sortie conclue, quelle
## qu'en soit la longueur.
##
## Cette règle-là n'est pas un détail d'implémentation, c'est ce qui relie
## les deux moitiés de la boucle du § 3 : une sortie COURTE rapporte plus
## de cycles, une sortie LONGUE rapporte plus de butin. Les deux se
## disputent le même temps, et « je rentre ou je continue ? » gagne un
## troisième terme sans qu'on ait rien ajouté à l'expédition.
##
## IL Y A TOUJOURS MOINS DE BRAS QUE DE PLACES. C'est ce qui fait de
## l'affectation une décision plutôt qu'un remplissage, et le § 50 réclame
## qu'un tour contienne un choix.
##
## L'OR N'EST PAS ICI. Il vit avec la compagnie — voir `ResourceTable`.
## Toutes les méthodes qui touchent à une ressource prennent donc la
## compagnie : c'est le prix, assumé, de n'avoir qu'une seule bourse.
##
## CLASSE PURE. Aucun nœud, aucune sauvegarde, aucun signal.

## Réserves du royaume : { ressource → quantité }. L'or n'y figure jamais.
var stores: Dictionary = {}

var population: int = 0

## Bras posés sur chaque chantier : { chantier → nombre }.
var assignments: Dictionary = {}

## Cycles de production écoulés. Sert au journal et aux tests, jamais à un
## calcul de production — un royaume ne produit pas plus parce qu'il est
## vieux.
var cycles: int = 0

## Niveau de chaque bâtiment : { bâtiment → niveau }. Zéro signifie « pas
## encore bâti ».
var levels: Dictionary = {}


static func create() -> Kingdom:
	var kingdom := Kingdom.new()
	for resource_id: StringName in ResourceTable.ids():
		if ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = ResourceTable.starting_amount(resource_id)
	kingdom.population = Worksite.starting_population()
	for building_id: StringName in Buildings.ids():
		kingdom.levels[building_id] = Buildings.starts_at(building_id)
	return kingdom


# --- Les réserves ----------------------------------------------------------

## Ce que le joueur possède d'une ressource, où qu'elle vive.
func amount(resource_id: StringName, company: Company = null) -> int:
	if not ResourceTable.lives_in_kingdom(resource_id):
		return company.gold if company != null else 0
	return int(stores.get(resource_id, 0))


func can_afford(cost: Dictionary, company: Company = null) -> bool:
	for key: Variant in cost.keys():
		var resource_id := StringName(key)
		if amount(resource_id, company) < int(cost[key]):
			return false
	return true


## Paie un coût. Ne prend rien si le compte n'y est pas : une dépense
## partielle laisserait le joueur sans son bâtiment ET sans ses réserves.
func pay(cost: Dictionary, company: Company = null) -> bool:
	if not can_afford(cost, company):
		return false
	for key: Variant in cost.keys():
		_add(StringName(key), -int(cost[key]), company)
	return true


func grant(gains: Dictionary, company: Company = null) -> void:
	for key: Variant in gains.keys():
		_add(StringName(key), int(gains[key]), company)


func _add(resource_id: StringName, delta: int, company: Company) -> void:
	if not ResourceTable.exists(resource_id):
		return
	if not ResourceTable.lives_in_kingdom(resource_id):
		if company != null:
			company.gold = maxi(company.gold + delta, 0)
		return
	stores[resource_id] = maxi(int(stores.get(resource_id, 0)) + delta, 0)


# --- Les bras --------------------------------------------------------------

func population_cap() -> int:
	return Worksite.base_population_cap() + int(_grants().get(&"population_cap", 0))


# --- Bâtir -----------------------------------------------------------------

func level_of(building_id: StringName) -> int:
	return int(levels.get(building_id, 0))


func is_built(building_id: StringName) -> bool:
	return level_of(building_id) > 0


## Le niveau le plus haut qu'un bâtiment puisse atteindre aujourd'hui.
##
## LE CHÂTEAU PLAFONNE TOUT LE RESTE. Sans cette règle on monterait une
## caserne au niveau 5 dans un hameau, et la progression du royaume
## n'aurait plus de colonne vertébrale. Le château, lui, ne se plafonne
## que lui-même — sinon rien ne pourrait jamais monter.
func reachable_level(building_id: StringName) -> int:
	var ceiling := Buildings.max_level(building_id)
	if building_id != Buildings.KEYSTONE:
		ceiling = mini(ceiling, level_of(Buildings.KEYSTONE))
	return ceiling


func next_level(building_id: StringName) -> int:
	if not Buildings.exists(building_id):
		return 0
	var wanted := level_of(building_id) + 1
	return wanted if wanted <= Buildings.max_level(building_id) else 0


## Ce que coûte le niveau suivant. Vide s'il n'y en a pas.
func next_cost(building_id: StringName) -> Dictionary:
	var wanted := next_level(building_id)
	if wanted <= 0:
		return {}
	return Buildings.cost_of(building_id, wanted)


## Pourquoi on ne peut pas bâtir : vide si on peut.
func blocked_because(building_id: StringName, company: Company = null) -> StringName:
	if not Buildings.exists(building_id):
		return &"unknown"
	var wanted := next_level(building_id)
	if wanted <= 0:
		return &"maxed"
	if wanted > reachable_level(building_id):
		return &"castle"
	if not can_afford(next_cost(building_id), company):
		return &"cost"
	return &""


func can_build(building_id: StringName, company: Company = null) -> bool:
	return blocked_because(building_id, company).is_empty()


## Monte un bâtiment d'un niveau. Renvoie le niveau atteint, ou zéro.
func build(building_id: StringName, company: Company = null) -> int:
	if not can_build(building_id, company):
		return 0
	var wanted := next_level(building_id)
	if not pay(next_cost(building_id), company):
		return 0
	levels[building_id] = wanted
	# Un plafond qui monte ne déplace personne ; un plafond qui descendrait
	# le ferait, et rien n'interdit à une donnée retouchée de le faire.
	settle_assignments()
	return wanted


# --- Ce que le royaume donne aux héros -------------------------------------
#
# C'est la réponse au § 45, dont la Phase 4 a pour objectif de « connecter
# le royaume au RPG ». Le sens de la dépendance ne bouge pas d'un pouce :
# le royaume rend un bloc de modificateurs, `Hero.effective_stats` l'ajoute
# comme il ajoute l'équipement, et ni `Hero` ni `Unit` ne savent qu'un
# royaume existe.

## Somme des gains de tous les bâtiments bâtis, toutes classes mêlées.
func _grants() -> Dictionary:
	var out := {}
	for building_id: StringName in levels.keys():
		if not Buildings.exists(building_id):
			continue
		var gained := Buildings.grants_up_to(building_id, level_of(building_id))
		for key: Variant in gained.keys():
			out[key] = Buildings.sum_grant(out.get(key, 0), gained[key])
	return out


## Les modificateurs qu'un héros de cette classe reçoit du royaume.
##
## Un bâtiment qui sert une classe ne donne qu'à elle : la caserne ne rend
## pas l'Archer plus fort, sinon bâtir ne serait plus un choix entre trois
## voies mais un cumul.
func hero_bonuses(class_id: StringName) -> Dictionary:
	var out := {}
	for building_id: StringName in levels.keys():
		if not Buildings.exists(building_id) or level_of(building_id) <= 0:
			continue
		var served := Buildings.hero_class(building_id)
		if not served.is_empty() and served != class_id:
			continue
		var gained := Buildings.grants_up_to(building_id, level_of(building_id))
		for key: Variant in gained.keys():
			# Le plafond de population et le soin ne sont pas des
			# statistiques de combat : les laisser passer les ferait
			# atterrir dans `Unit.from_stats`, qui les ignorerait en
			# silence — et un gain qu'on croit acquis sans qu'il le soit
			# est pire qu'un gain absent.
			if key in ["population_cap", "heal_between_steps"]:
				continue
			out[key] = Buildings.sum_grant(out.get(key, 0), gained[key])
	return out


## Fraction des PV que le royaume rend à l'équipe entre deux rencontres.
##
## C'est le seul effet du royaume qui touche à l'expédition elle-même, et
## donc le seul qui déplace la courbe d'usure mesurée en T1.11.
func healing_between_steps() -> float:
	return float(_grants().get(&"heal_between_steps", 0.0))


## Les classes que le royaume sait recruter. Le premier héros de chaque
## classe vient d'un bâtiment : sans caserne, pas de Guerrier.
func recruitable_classes() -> Array[StringName]:
	var out: Array[StringName] = []
	for building_id: StringName in Buildings.ids():
		var served := Buildings.hero_class(building_id)
		if not served.is_empty() and level_of(building_id) > 0:
			out.append(served)
	return out


func assigned_to(worksite_id: StringName) -> int:
	return int(assignments.get(worksite_id, 0))


func assigned_total() -> int:
	var total := 0
	for key: Variant in assignments.keys():
		total += int(assignments[key])
	return total


## Habitants qui ne font rien. Ils mangent quand même — c'est ce qui rend
## une affectation oubliée coûteuse plutôt que neutre.
func idle_pawns() -> int:
	return maxi(population - assigned_total(), 0)


func can_assign(worksite_id: StringName) -> bool:
	if not Worksite.exists(worksite_id):
		return false
	return idle_pawns() > 0 and assigned_to(worksite_id) < Worksite.slots_of(worksite_id)


func assign(worksite_id: StringName) -> bool:
	if not can_assign(worksite_id):
		return false
	assignments[worksite_id] = assigned_to(worksite_id) + 1
	return true


func unassign(worksite_id: StringName) -> bool:
	if assigned_to(worksite_id) <= 0:
		return false
	assignments[worksite_id] = assigned_to(worksite_id) - 1
	return true


## Renvoie les bras en trop au repos. À appeler quand la population baisse
## ou qu'un chantier rétrécit : un chantier tenu par des gens qui n'existent
## plus produirait du bois avec des fantômes.
func settle_assignments() -> void:
	for worksite_id: StringName in assignments.keys():
		var limit := Worksite.slots_of(worksite_id)
		assignments[worksite_id] = clampi(assigned_to(worksite_id), 0, limit)
	while assigned_total() > population:
		var busiest := &""
		for worksite_id: StringName in assignments.keys():
			if assigned_to(worksite_id) > assigned_to(busiest):
				busiest = worksite_id
		if busiest.is_empty():
			break
		unassign(busiest)


# --- Le cycle de production ------------------------------------------------

## Une sortie conclue = un cycle. Renvoie de quoi le raconter au joueur :
## { produced, eaten, arrived, hungry }.
##
## L'ORDRE COMPTE. On produit d'abord, on mange ensuite, on accueille en
## dernier : sinon un habitant arriverait pour manger une nourriture que
## personne n'a encore récoltée, et le premier cycle affamerait le royaume
## qu'on vient de fonder.
func run_cycle(company: Company = null) -> Dictionary:
	cycles += 1
	settle_assignments()

	var produced := {}
	for worksite_id: StringName in assignments.keys():
		var hands := assigned_to(worksite_id)
		if hands <= 0:
			continue
		var resource_id := Worksite.resource_of(worksite_id)
		var gained := Worksite.per_cycle(worksite_id) * hands
		produced[resource_id] = int(produced.get(resource_id, 0)) + gained
	grant(produced, company)

	var eaten := Worksite.food_per_pawn() * population
	var larder := amount(&"food")
	# Personne ne meurt de faim : la réserve tombe à zéro et le royaume
	# n'accueille plus. Le § 41 refuse la punition absolue, et affamer un
	# village pendant que le joueur est en expédition en serait une — il
	# n'était même pas là pour l'empêcher.
	var hungry := larder < eaten
	_add(&"food", -eaten, company)

	var arrived := false
	if not hungry and population < population_cap() and amount(&"food") >= Worksite.arrival_food():
		_add(&"food", -Worksite.arrival_food(), company)
		population += 1
		arrived = true

	return {
		"produced": produced,
		"eaten": eaten,
		"arrived": arrived,
		"hungry": hungry,
		"cycle": cycles,
	}


# --- Sérialisation ---------------------------------------------------------

func to_dictionary() -> Dictionary:
	var saved_stores := {}
	for resource_id: StringName in stores.keys():
		saved_stores[String(resource_id)] = int(stores[resource_id])
	var saved_work := {}
	for worksite_id: StringName in assignments.keys():
		saved_work[String(worksite_id)] = int(assignments[worksite_id])
	var saved_levels := {}
	for building_id: StringName in levels.keys():
		saved_levels[String(building_id)] = int(levels[building_id])
	return {
		"stores": saved_stores,
		"population": population,
		"assignments": saved_work,
		"levels": saved_levels,
		"cycles": cycles,
	}


static func from_dictionary(data: Dictionary) -> Kingdom:
	var kingdom := Kingdom.create()
	if data.is_empty():
		return kingdom
	kingdom.stores.clear()
	for key: Variant in (data.get("stores", {}) as Dictionary).keys():
		var resource_id := StringName(key)
		# Une ressource retirée des données depuis la sauvegarde disparaît
		# des réserves, sans emporter la partie avec elle.
		if ResourceTable.exists(resource_id) and ResourceTable.lives_in_kingdom(resource_id):
			kingdom.stores[resource_id] = int((data["stores"] as Dictionary)[key])
	kingdom.population = int(data.get("population", kingdom.population))
	kingdom.cycles = int(data.get("cycles", 0))
	for key: Variant in (data.get("assignments", {}) as Dictionary).keys():
		var worksite_id := StringName(key)
		if Worksite.exists(worksite_id):
			kingdom.assignments[worksite_id] = int((data["assignments"] as Dictionary)[key])
	for key: Variant in (data.get("levels", {}) as Dictionary).keys():
		var building_id := StringName(key)
		# Un bâtiment retiré des données depuis la sauvegarde disparaît du
		# royaume, sans emporter la partie avec lui.
		if Buildings.exists(building_id):
			kingdom.levels[building_id] = clampi(
				int((data["levels"] as Dictionary)[key]),
				Buildings.starts_at(building_id),
				Buildings.max_level(building_id)
			)
	kingdom.settle_assignments()
	return kingdom
