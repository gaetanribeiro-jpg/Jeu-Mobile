extends SceneTree

## Vérifie l'économie du royaume : ressources, chantiers, bâtiments.
##
##     godot --headless --path . -s tools/verify_kingdom.gd
##
## POURQUOI. Une économie n'a pas d'instrument non plus. On ne simule pas
## cent parties pour savoir si une caserne est trop chère — mais on peut
## exiger qu'elle soit ATTEIGNABLE, et dire en combien de cycles.
##
## Ce que l'outil refuse tient en trois idées :
##  1. un bâtiment qui n'accorde RIEN est décoratif, et c'est interdit ;
##  2. un bâtiment qu'on ne peut pas payer avant la fin des temps n'est
##     pas un objectif, c'est une décoration chère ;
##  3. un chantier qui ne nourrit pas ses ouvriers rend la nourriture
##     impossible à tenir, quoi que le joueur fasse.
##
## Il IMPRIME aussi l'échelle complète — prix par niveau, cycles pour
## l'atteindre, gains cumulés. C'est la seule vue d'ensemble de la
## progression du royaume, et elle vaut plus que les refus.

var _problems: Array[String] = []


func _init() -> void:
	print("Ressources et chantiers\n")
	_check_resources()
	_check_worksites()
	print("\nBâtiments\n")
	for building_id: StringName in Buildings.ids():
		_check_building(building_id)
	_check_food_balance()
	_check_recruiting()

	if _problems.is_empty():
		print("\nL'économie du royaume tient debout.")
		quit(0)
		return
	print("\nProblèmes : %d" % _problems.size())
	for line: String in _problems:
		print("  %s" % line)
	quit(1)


func _check_resources() -> void:
	print("%-8s %-9s %7s  %s" % ["ressource", "vit chez", "départ", "clé"])
	for resource_id: StringName in ResourceTable.ids():
		print("%-8s %-9s %7d  %s" % [
			resource_id,
			ResourceTable.holder_of(resource_id),
			ResourceTable.starting_amount(resource_id),
			ResourceTable.name_key(resource_id),
		])
		_check_translation(resource_id, ResourceTable.name_key(resource_id))
		if not _asset_exists(ResourceTable.asset_of(resource_id)):
			_problems.append("%s : image « %s » absente de la table"
				% [resource_id, ResourceTable.asset_of(resource_id)])
	if ResourceTable.ids().size() != 4:
		# Le § 6 en veut quatre et le dit deux fois. En ajouter une au MVP
		# se paierait sur tous les coûts déjà réglés.
		_problems.append("le § 6 veut quatre ressources, il y en a %d"
			% ResourceTable.ids().size())


func _check_worksites() -> void:
	print("")
	print("%-12s %-6s %6s %6s  %s" % ["chantier", "rend", "/cycle", "places", "outil"])
	var slots := 0
	for worksite_id: StringName in Worksite.ids():
		slots += Worksite.slots_of(worksite_id)
		print("%-12s %-6s %6d %6d  %s" % [
			worksite_id,
			Worksite.resource_of(worksite_id),
			Worksite.per_cycle(worksite_id),
			Worksite.slots_of(worksite_id),
			Worksite.tool_of(worksite_id),
		])
		_check_translation(worksite_id, Worksite.name_key(worksite_id))
		if not ResourceTable.exists(Worksite.resource_of(worksite_id)):
			_problems.append("%s : ressource inconnue « %s »"
				% [worksite_id, Worksite.resource_of(worksite_id)])
		if Worksite.per_cycle(worksite_id) <= 0:
			_problems.append("%s : ne produit rien" % worksite_id)
		if Worksite.slots_of(worksite_id) <= 0:
			_problems.append("%s : n'accepte personne" % worksite_id)
		if not _asset_exists(Worksite.asset_of(worksite_id)):
			_problems.append("%s : image « %s » absente de la table"
				% [worksite_id, Worksite.asset_of(worksite_id)])

	# Il doit toujours rester des places libres, sinon affecter cesse
	# d'être un arbitrage et devient un remplissage.
	var largest_kingdom := Worksite.base_population_cap()
	for building_id: StringName in Buildings.ids():
		largest_kingdom += int(
			Buildings.grants_up_to(building_id, Buildings.max_level(building_id))
				.get("population_cap", 0)
		)
	print("\n%d places pour %d habitants au maximum" % [slots, largest_kingdom])
	if slots <= Worksite.base_population_cap():
		_problems.append("il y a moins de places que de bras au premier jour")


func _check_building(building_id: StringName) -> void:
	_check_translation(building_id, Buildings.name_key(building_id))
	_check_translation(building_id, Buildings.description_key(building_id))

	var served := Buildings.hero_class(building_id)
	print("%s%s" % [
		tr(Buildings.name_key(building_id)),
		"   (%s)" % served if not served.is_empty() else "",
	])
	print("  %-6s %-34s %-9s %s" % ["niveau", "coût", "cycles", "gains cumulés"])

	for level in range(1, Buildings.max_level(building_id) + 1):
		var cost := Buildings.cost_of(building_id, level)
		print("  %-6d %-34s %-9s %s" % [
			level,
			_costs(cost) if not cost.is_empty() else "—",
			"%.0f" % _cycles_for(cost) if not cost.is_empty() else "—",
			_grants(Buildings.grants_up_to(building_id, level)),
		])
		if Buildings.grants_at(building_id, level).is_empty():
			# Un niveau qui n'accorde rien fait payer pour un chiffre qui
			# monte, et le § 8 promet « de nouvelles mécaniques ».
			_problems.append("%s niveau %d : n'accorde rien" % [building_id, level])
		if not _asset_exists(Buildings.asset_of(building_id, level)):
			_problems.append("%s niveau %d : image « %s » absente de la table"
				% [building_id, level, Buildings.asset_of(building_id, level)])

	if Buildings.max_level(building_id) <= 0:
		_problems.append("%s : aucun niveau" % building_id)
	if Buildings.grants_up_to(building_id, Buildings.max_level(building_id)).is_empty():
		_problems.append("%s : décoratif — il n'accorde rien" % building_id)
	if not served.is_empty() and not Unit.hero_class_ids().has(served):
		_problems.append("%s : sert une classe inconnue « %s »" % [building_id, served])
	print("")


## Combien de cycles de production il faut pour payer un coût, en supposant
## un royaume qui tient ses chantiers avec la moitié de ses places. C'est
## une estimation grossière, et c'est exprès : ce qu'on veut savoir, c'est
## si le prix se compte en unités, en dizaines ou en centaines de sorties.
func _cycles_for(cost: Dictionary) -> float:
	var worst := 0.0
	for key: Variant in cost.keys():
		var resource_id := StringName(key)
		var per_cycle := 0.0
		for worksite_id: StringName in Worksite.ids():
			if Worksite.resource_of(worksite_id) == resource_id:
				# La moitié des places tenues : un royaume ne consacre
				# jamais tous ses bras à une seule ressource.
				per_cycle += float(Worksite.per_cycle(worksite_id)) \
					* float(Worksite.slots_of(worksite_id)) * 0.5
		if resource_id == &"gold":
			# L'or ne vient pas que du gisement : une expédition en rapporte
			# bien davantage, et c'est elle qui finance le royaume.
			per_cycle += Loot.number(&"gold", &"per_enemy", 0.0) * 4.0 * 4.0
		if per_cycle <= 0.0:
			continue
		worst = maxf(worst, float(cost[key]) / per_cycle)
	return worst


## Le premier niveau de chaque bâtiment doit rester à portée : un objectif
## qui demande cinquante sorties n'est pas un objectif, c'est un mur.
func _check_food_balance() -> void:
	var largest := Worksite.base_population_cap()
	for building_id: StringName in Buildings.ids():
		largest += int(
			Buildings.grants_up_to(building_id, Buildings.max_level(building_id))
				.get("population_cap", 0)
		)
	var need := Worksite.food_per_pawn() * largest
	var can_make := 0
	for worksite_id: StringName in Worksite.ids():
		if Worksite.resource_of(worksite_id) == &"food":
			can_make += Worksite.per_cycle(worksite_id) * Worksite.slots_of(worksite_id)
	print("nourriture : %d produite au mieux, %d mangée par %d habitants"
		% [can_make, need, largest])
	if can_make <= need:
		# Sinon le royaume ne peut pas se nourrir, quoi que le joueur
		# fasse, et le plafond de population est un mensonge.
		_problems.append(
			"un royaume plein ne peut pas se nourrir : %d produite pour %d mangée"
			% [can_make, need])

	for building_id: StringName in Buildings.ids():
		if Buildings.starts_at(building_id) > 0:
			continue
		var first := _cycles_for(Buildings.cost_of(building_id, 1))
		if first > 12.0:
			_problems.append("%s : %.0f cycles pour le bâtir — c'est un mur"
				% [building_id, first])


## Chaque classe du MVP doit avoir son bâtiment, sinon on ne peut pas la
## recruter et le § 11 promet trois classes.
func _check_recruiting() -> void:
	var served := {}
	for building_id: StringName in Buildings.ids():
		var class_id := Buildings.hero_class(building_id)
		if not class_id.is_empty():
			served[class_id] = building_id
	print("recrutement : %s" % ", ".join(PackedStringArray(served.keys())))
	for class_id: StringName in Unit.hero_class_ids():
		if not served.has(class_id):
			_problems.append("aucun bâtiment ne recrute un %s" % class_id)


func _costs(cost: Dictionary) -> String:
	var pieces := PackedStringArray()
	for key: Variant in cost.keys():
		pieces.append("%s %d" % [tr(ResourceTable.name_key(StringName(key))), int(cost[key])])
	return ", ".join(pieces)


func _grants(gained: Dictionary) -> String:
	var pieces := PackedStringArray()
	for key: Variant in gained.keys():
		if Buildings.is_fraction(StringName(key)):
			pieces.append("%s %+.0f %%" % [key, float(gained[key]) * 100.0])
		else:
			pieces.append("%s %+d" % [key, int(gained[key])])
	return ", ".join(pieces)


## Une image nommée « catégorie/clé » existe-t-elle dans `assets.json` ?
##
## On lit la table plutôt que d'appeler `AssetTable.sprite`, qui pousse une
## erreur : ici, l'absence est ce qu'on VÉRIFIE, pas une panne.
func _asset_exists(reference: String) -> bool:
	var parts := reference.split("/", false)
	if parts.size() != 2:
		return false
	var category: Dictionary = AssetTable.table().get(parts[0], {})
	return category.has(parts[1])


func _check_translation(owner_id: StringName, key: String) -> void:
	if key.is_empty():
		_problems.append("%s : pas de clé de texte" % owner_id)
	elif TranslationServer.translate(key) == key:
		_problems.append("%s : la clé « %s » n'est pas traduite" % [owner_id, key])
