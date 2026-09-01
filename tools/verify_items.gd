extends SceneTree

## Vérifie que chaque objet vaut exactement le budget de sa rareté.
##
##     godot --headless --path . -s tools/verify_items.gd
##
## POURQUOI. L'équilibrage d'un objet n'a pas d'instrument : on ne peut pas
## simuler mille combats pour chaque anneau. Le budget est donc la seule
## chose qui empêche un légendaire inventé un soir de fatigue de casser le
## jeu en silence. Le barème est dans `costs` de equipment.json — 5 PV
## valent un point, un point de statistique deux, un PM cinq et un PA sept.

var _problems: Array[String] = []


func _init() -> void:
	var ids := Equipment.ids()
	print("Vérification de %d objets…\n" % ids.size())
	print("%-18s %-10s %6s %7s  %s" % ["objet", "rareté", "coût", "budget", "gains"])
	print("-".repeat(74))

	for item_id: StringName in ids:
		_check(item_id)

	_check_coverage()

	print("-".repeat(74))
	_check_consumables()

	if _problems.is_empty():
		print("\nTous les objets sont dans leur budget.")
		quit(0)
		return
	print("\nProblèmes : %d" % _problems.size())
	for line: String in _problems:
		print("  %s" % line)
	quit(1)


func _check(item_id: StringName) -> void:
	var rarity := Equipment.rarity_of(item_id)
	var cost := Equipment.cost_of(item_id)
	var budget := Equipment.rarity_budget(rarity)
	var slot := Equipment.slot_of(item_id)

	if not Equipment.is_slot(slot):
		_problems.append("%s : emplacement inconnu « %s »" % [item_id, slot])
	if not Equipment.rarities().has(rarity):
		_problems.append("%s : rareté inconnue « %s »" % [item_id, rarity])
	if Equipment.grants(item_id).is_empty():
		_problems.append("%s : n'accorde rien" % item_id)
	if not is_equal_approx(cost, budget):
		_problems.append("%s : vaut %.1f pour un budget de %.0f" % [item_id, cost, budget])

	var pieces := PackedStringArray()
	for key: Variant in Equipment.grants(item_id).keys():
		pieces.append("%s %+d" % [key, int(Equipment.grants(item_id)[key])])
	print("%-18s %-10s %6.1f %7.0f  %s"
		% [item_id, rarity, cost, budget, ", ".join(pieces)])


## Chaque classe doit pouvoir remplir chacun de ses emplacements, sinon
## une fiche de héros montre un trou que rien ne peut combler.
func _check_coverage() -> void:
	print("")
	for class_id: StringName in Unit.hero_class_ids():
		for slot: StringName in Equipment.slots():
			var available := Equipment.of_slot(slot, class_id)
			if available.is_empty():
				_problems.append(
					"un %s n'a aucun objet pour l'emplacement « %s »" % [class_id, slot]
				)
			else:
				print("  %-8s %-10s %d objets" % [class_id, slot, available.size()])


## Les potions du § 44. Même règle que l'équipement, et pour la même
## raison : on ne simule pas mille combats pour un flacon.
##
## L'UNITÉ EST LE POINT DE VIE ÉPARGNÉ. Une rencontre coûte environ 20 %
## des PV d'une équipe ; une potion qui en rend 45 épargne un peu plus
## d'un demi-combat, et doit coûter dans cet ordre. Sinon on en achète
## dix, et l'usure sur laquelle repose tout le roguelite disparaît.
func _check_consumables() -> void:
	var ids := Consumable.ids()
	if ids.is_empty():
		_problems.append("aucune potion déclarée")
		return

	print("\n%-24s %6s %6s %8s  %s"
		% ["potion", "valeur", "prix", "barème", "compétence"])
	print("-".repeat(74))

	var verbs := {}
	for item_id: StringName in ids:
		var ability_id := Consumable.ability_of(item_id)
		var ability := Ability.of(ability_id)
		if ability == null:
			_problems.append("%s : compétence « %s » introuvable" % [item_id, ability_id])
			continue
		if not ability.is_carried():
			_problems.append("%s : « %s » n'est pas de classe consumable"
				% [item_id, ability_id])
		# UNE POTION NE DÉPEND DE PERSONNE : une bombe lancée par le Mage
		# et par le Guerrier fait les mêmes dégâts. Sinon il faudrait la
		# réserver au personnage qui la valorise le mieux, et le sac
		# COMMUN du § 44 n'aurait plus de sens.
		if not ability.scaling.is_empty():
			_problems.append("%s : monte à « %s », or une potion ne doit "
				% [item_id, ability.scaling] + "dépendre de personne")

		var fair := Consumable.fair_price(item_id)
		var written := float(Consumable.price_of(item_id))
		var gap := absf(written - fair) / maxf(fair, 1.0)
		if gap > Consumable.price_tolerance():
			_problems.append("%s : %d d'or pour un barème à %.0f"
				% [item_id, int(written), fair])

		var key := "%s/%d" % [ability.kind, ability.range_max]
		if verbs.has(key):
			_problems.append("« %s » et « %s » font la même chose"
				% [verbs[key], item_id])
		verbs[key] = item_id

		var name_key := Consumable.name_key(item_id)
		if name_key.is_empty() or TranslationServer.translate(name_key) == name_key:
			_problems.append("%s : pas de nom traduit" % item_id)

		print("%-24s %6d %6d %8.0f  %s"
			% [item_id, Consumable.value_of(item_id), int(written), fair, ability_id])

	# Une potion qu'on ne peut pas obtenir n'est pas une mécanique.
	var stock := Consumable.starting_stock()
	if Consumable.total(stock) <= 0:
		_problems.append("le sac de départ est vide : les potions sont inatteignables")
	print("\nsac de départ : %d potions" % Consumable.total(stock))
