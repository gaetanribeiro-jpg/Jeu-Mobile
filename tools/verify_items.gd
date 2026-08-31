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
