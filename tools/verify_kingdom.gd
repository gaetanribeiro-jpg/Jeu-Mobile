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
	_check_traits()
	_check_invasions()
	_check_neighbours()
	_check_councils()

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
	# DEUX CHIFFRES DEPUIS QUE LES HABITANTS ONT UN MÉTIER (§ 9) : ce que
	# produisent des DÉBUTANTS, et ce que produisent des maîtres. Le
	# premier est la contrainte du début de partie, le second dit à quel
	# point elle se desserre — et n'imprimer que l'un des deux cacherait
	# soit la difficulté initiale, soit le fait qu'elle disparaît.
	var raw := 0
	var mastered := 0
	var expert := Pawn.create(0)
	for worksite_id: StringName in Worksite.ids():
		if Worksite.resource_of(worksite_id) != &"food":
			continue
		expert.experience[worksite_id] = Worksite.xp_per_level() * Worksite.max_trade_level()
		raw += Worksite.per_cycle(worksite_id) * Worksite.slots_of(worksite_id)
		mastered += expert.yield_at(worksite_id) * Worksite.slots_of(worksite_id)
	print("nourriture : %d produite par des débutants, %d par des maîtres, %d mangée par %d habitants"
		% [raw, mastered, need, largest])
	if mastered <= need:
		# Sinon le royaume ne peut pas se nourrir, quoi que le joueur
		# fasse, et le plafond de population est un mensonge.
		_problems.append(
			"un royaume plein ne peut pas se nourrir : %d produite pour %d mangée"
			% [mastered, need])
	# CE QUE LA NOURRITURE DOIT COÛTER, C'EST DES BRAS. Elle ne contraint
	# pas par la famine — le royaume plein doit pouvoir se nourrir — mais
	# par le NOMBRE DE PLACES qu'elle immobilise : trois pâtures sur douze
	# places, c'est un quart de la main-d'œuvre qui ne fait ni bois, ni
	# pierre, ni or.
	#
	# LE PREMIER JET DE CE TEST DEMANDAIT L'INVERSE — que des débutants NE
	# suffisent PAS — et c'était une erreur de raisonnement : si des
	# débutants ne nourrissaient pas un royaume plein, le plafond de
	# population serait un mensonge, ce que le test d'au-dessus refuse
	# déjà. Les deux conditions se seraient contredites.
	var slots := 0
	var per_farmer := 0
	for worksite_id: StringName in Worksite.ids():
		if Worksite.resource_of(worksite_id) == &"food":
			slots += Worksite.slots_of(worksite_id)
			per_farmer = maxi(per_farmer, Worksite.per_cycle(worksite_id))
	var farmers_needed := 0 if per_farmer <= 0 else int(ceil(float(need) / float(per_farmer)))
	print("  il faut %d éleveurs débutants sur %d places pour tenir" % [farmers_needed, slots])
	if farmers_needed * 2 < slots:
		_problems.append(
			"nourrir un royaume plein n'occupe que %d places sur %d : "
			% [farmers_needed, slots]
			+ "la nourriture ne coûte pas assez de bras pour peser")

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
		for class_id: StringName in Buildings.recruits(building_id):
			served[class_id] = building_id
	print("recrutement : %s" % ", ".join(PackedStringArray(served.keys())))
	for class_id: StringName in Unit.hero_class_ids():
		if not served.has(class_id):
			_problems.append("aucun bâtiment ne recrute un %s" % class_id)
	_check_trades()
	_check_spots()
	_check_brewing()
	if Buildings.candidate_count() < 2:
		# Un seul candidat n'est pas un choix, c'est un bouton — le
		# reproche exact auquel les traits répondent.
		_problems.append("le recrutement ne propose que %d candidat"
			% Buildings.candidate_count())


## LE MÉTIER EST LA SECONDE PISTE DE PROGRESSION DU ROYAUME (§ 9), celle
## qui ne s'achète pas. Il doit donc PESER — un rang qui ne change rien
## ferait de la spécialisation une décoration — sans pour autant rendre un
## débutant inutile.
func _check_trades() -> void:
	print("\nmétiers : %d rangs, %d cycles par rang, +%.0f %% par rang"
		% [
			Worksite.max_trade_level(), Worksite.xp_per_level(),
			Worksite.yield_per_level() * 100.0,
		])
	print("%-12s %8s %8s" % ["chantier", "débutant", "maître"])
	var expert := Pawn.create(0)
	for worksite_id: StringName in Worksite.ids():
		expert.experience[worksite_id] = Worksite.xp_per_level() * Worksite.max_trade_level()
		var raw := Worksite.per_cycle(worksite_id)
		var best := expert.yield_at(worksite_id)
		print("%-12s %8d %8d" % [worksite_id, raw, best])
		if best <= raw:
			_problems.append(
				"%s : un maître y produit autant qu'un débutant — le métier ne sert à rien"
				% worksite_id)
	if Worksite.max_trade_level() <= 0:
		_problems.append("aucun rang de métier : la spécialisation n'existe pas")


## UN BÂTIMENT POSÉ HORS DE LA TOILE NE SE DESSINE PAS, et ne se plaint
## pas. La tour de guet était en 930 sur une toile de 900 depuis sa
## création : un joueur qui la bâtissait — et il le faut pour l'ascension —
## ne voyait rien apparaître. Aucun test ne pouvait le dire, puisque la
## toile était une constante de la VUE que rien d'autre ne lisait.
func _check_spots() -> void:
	var canvas := Buildings.canvas()
	print("\ntoile du royaume : %d × %d" % [canvas.x, canvas.y])
	for building_id: StringName in Buildings.ids():
		_check_spot(building_id, Buildings.spot_of(building_id), canvas)
	for worksite_id: StringName in Worksite.ids():
		_check_spot(worksite_id, Worksite.spot_of(worksite_id), canvas)


func _check_spot(owner_id: StringName, spot: Vector2, canvas: Vector2) -> void:
	if spot.x < 0.0 or spot.y < 0.0 or spot.x > canvas.x or spot.y > canvas.y:
		_problems.append(
			"%s : emplacement %s hors de la toile %s — il ne se dessinera pas"
			% [owner_id, spot, canvas]
		)


## DEUX MOITIÉS QUI NE SE PARLENT PAS NE FONT PAS UNE MÉCANIQUE — c'est
## la leçon de `verify_world` en Phase 10, appliquée au royaume. Un
## bâtiment qui accorde `brew` sans dire QUOI ne préparerait rien, en
## silence ; un bâtiment qui déclare une potion sans jamais accorder
## `brew` ne la préparerait jamais. Les deux se lisent juste séparément.
func _check_brewing() -> void:
	for building_id: StringName in Buildings.ids():
		var potion := Buildings.brews(building_id)
		var top := Buildings.grants_up_to(building_id, Buildings.max_level(building_id))
		var batch := int(top.get(&"brew", 0))
		if batch > 0 and potion.is_empty():
			_problems.append("%s : prépare %d fiole(s) sans dire laquelle"
				% [building_id, batch])
		if not potion.is_empty() and batch <= 0:
			_problems.append("%s : déclare « %s » et n'en prépare jamais"
				% [building_id, potion])
		if not potion.is_empty() and not Consumable.exists(potion):
			_problems.append("%s : prépare « %s », qui n'existe pas"
				% [building_id, potion])
		if batch > 0:
			print("%s : %d × %s par cycle au maximum"
				% [building_id, batch, potion])
	# Un gain de royaume non déclaré file jusqu'à `Unit.from_stats`, qui
	# l'ignore sans rien dire. On vérifie donc que les clés qui ne sont
	# pas des statistiques sont bien triées comme telles.
	for key: StringName in [&"population_cap", &"heal_between_steps", &"brew"]:
		if not Buildings.is_kingdom_grant(key):
			_problems.append("« %s » n'est pas déclaré comme gain de royaume" % key)


## CHAQUE TRAIT EST UN ÉCHANGE, JAMAIS UN BONUS. C'est ce qui fait des
## trois candidats une décision : si l'un d'eux était meilleur, en
## proposer trois reviendrait à en proposer un avec deux distractions.
##
## Le barème est celui de l'équipement — la même mesure que `verify_items`
## applique aux objets, parce que c'est la même monnaie. Un trait qui
## donne 4 points doit en retirer 4, à la virgule près.
func _check_traits() -> void:
	print("")
	print("%-10s %7s %7s  %s" % ["trait", "donne", "retire", "clé"])
	for trait_id: StringName in HeroTrait.ids():
		var given := Equipment.price_of_grants(HeroTrait.grants(trait_id))
		var taken := Equipment.price_of_grants(HeroTrait.costs(trait_id))
		print("%-10s %7.1f %7.1f  %s"
			% [trait_id, given, taken, HeroTrait.name_key(trait_id)])
		_check_translation(trait_id, HeroTrait.name_key(trait_id))
		if given <= 0.0:
			_problems.append("%s : ne donne rien" % trait_id)
		if taken <= 0.0:
			# Un trait gratuit serait « le bon » candidat, toujours.
			_problems.append("%s : ne retire rien" % trait_id)
		if not is_equal_approx(given, taken):
			_problems.append("%s : donne %.1f pour %.1f retiré"
				% [trait_id, given, taken])
		# Un trait qui donne et retire la MÊME statistique s'annule en
		# partie, et le joueur lit deux chiffres pour un demi-effet.
		for key: Variant in HeroTrait.grants(trait_id).keys():
			if HeroTrait.costs(trait_id).has(key):
				_problems.append("%s : donne et retire « %s »" % [trait_id, key])
	if HeroTrait.ids().size() < Buildings.candidate_count():
		# En dessous, deux candidats porteraient le même caractère et
		# l'étal proposerait deux fois la même personne.
		_problems.append("%d traits pour %d candidats"
			% [HeroTrait.ids().size(), Buildings.candidate_count()])



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


# --- Les invasions (§ 37) --------------------------------------------------
#
# Trois choses doivent être vraies en même temps, et aucune ne se voit à la
# lecture du fichier :
#  1. l'invasion doit ARRIVER — une mécanique qu'on peut ne jamais
#     rencontrer n'en est pas une ;
#  2. elle ne doit pas arriver à chaque étape, sinon l'expédition n'est
#     plus qu'une alarme ;
#  3. un royaume bâti doit pouvoir la repousser SEUL, sinon partir devient
#     interdit et le § 37 dit le contraire.

func _check_invasions() -> void:
	print("")
	var young := Kingdom.create()
	var steps := _steps_to_invasion(young)
	print("royaume de départ : invasion à l'étape %d" % steps)
	if steps <= 1:
		_problems.append("une invasion se déclare dès la première étape")
	if steps > 20:
		_problems.append("une invasion demande %d étapes — on ne la verra jamais" % steps)

	# Un royaume au maximum, tel qu'il finira par l'être.
	var grown := Kingdom.create()
	for building_id: StringName in Buildings.ids():
		grown.levels[building_id] = Buildings.max_level(building_id)
	grown.population = grown.population_cap()
	var rich_steps := _steps_to_invasion(grown)
	print("royaume au maximum : invasion à l'étape %d" % rich_steps)
	if rich_steps > steps:
		# Un royaume riche doit attirer PLUS, pas moins.
		_problems.append("un royaume bâti attire moins qu'un hameau")

	var assault := Invasion.declare(null, grown.building_levels(), 0)

	# LA GARDE DOIT DÉCIDER DE L'ISSUE, et c'est le seul moyen de le
	# vérifier : on mesure le MÊME royaume les bras au travail, puis les
	# bras à la garde. Si les deux chiffres repoussent l'assaut, monter la
	# garde ne sert à rien ; si aucun ne le repousse, elle ne suffit jamais.
	# Dans les deux cas se protéger cesse d'être une décision — c'était
	# exactement l'état d'avant, où la défense comptait des niveaux de
	# bâtiment et une population.
	grown.settle_assignments()
	var working := grown
	while working.idle_pawns() > 0 and _fill_one(working):
		pass
	var busy := working.defence_strength(0)
	var watching := Invasion.defence_of(
		working.ward_strength(), 0, working.population, 0
	)
	print("royaume au maximum : assaut %d" % assault.strength)
	print("  tous aux chantiers : défense %d (%d de rempart, %d ouvriers)"
		% [busy, working.ward_strength(), working.assigned_total()])
	print("  tous à la garde    : défense %d (%d sentinelles)"
		% [watching, working.population])
	if busy >= assault.strength:
		_problems.append(
			"un royaume au maximum repousse l'assaut SANS retirer un seul bras "
			+ "des chantiers (%d contre %d) : monter la garde ne sert à rien."
			% [busy, assault.strength])
	if watching < assault.strength:
		_problems.append(
			"un royaume au maximum ne repousse pas l'assaut MÊME tous à la garde "
			+ "(%d contre %d) : la garde ne suffit jamais."
			% [watching, assault.strength])

	var bare := Kingdom.create()
	var bare_assault := Invasion.declare(null, bare.building_levels(), 0)
	print("royaume de départ : défense %d contre un assaut de %d"
		% [bare.defence_strength(0), bare_assault.strength])


## Pose un bras sur le premier chantier qui a de la place. Renvoie faux
## quand il n'y en a plus.
func _fill_one(kingdom: Kingdom) -> bool:
	for worksite_id: StringName in Worksite.ids():
		if kingdom.assign(worksite_id):
			return true
	return false


## Étapes d'expédition avant qu'une invasion ne se déclare.
func _steps_to_invasion(kingdom: Kingdom) -> int:
	for step in range(1, 200):
		if kingdom.raise_threat(CombatRng.new(step), 0) != null:
			return step
	return 999


# --- Les villes voisines et le conseil (T12.10) -----------------------------
#
# LA SEULE RÈGLE DU § 40 VAUT ICI AUSSI : « les événements doivent créer
# des décisions ». Un conseil à une option, ou dont une option est
# meilleure qu'une autre sur TOUTE la ligne, se joue parfaitement — il ne
# demande simplement plus rien au joueur, et rien ne plante. C'est le même
# barème que `verify_world` applique à l'expédition, transposé aux
# monnaies de la ville.

func _check_neighbours() -> void:
	var towns := Neighbour.ids()
	print("\nVilles voisines (crédit de %d à %d)\n" % [Neighbour.minimum(), Neighbour.maximum()])
	for town_id: StringName in towns:
		_check_translation(town_id, Neighbour.name_key(town_id))
		_check_translation(town_id, Neighbour.description_key(town_id))
		var trade := Neighbour.trade_of(town_id)
		print("%-14s commerce : %-6s  (%s)" % [
			town_id, trade, TranslationServer.translate(Neighbour.name_key(town_id))])
		if not ResourceTable.exists(trade):
			_problems.append("%s : commerce une ressource inconnue « %s »" % [town_id, trade])
	# UNE SEULE VILLE NE PEUT PAS SE QUERELLER AVEC ELLE-MÊME, et c'est la
	# querelle qui empêche le crédit d'être une barre de progression : sans
	# un second voisin à fâcher, il ne fait que monter.
	if towns.size() < 2:
		_problems.append("il faut au moins deux voisines pour qu'un choix en fâche une")

	if Neighbour.minimum() >= 0 or Neighbour.maximum() <= 0:
		_problems.append("le crédit doit pouvoir descendre ET monter autour de zéro")
	var previous := Neighbour.minimum() - 1
	for level: Variant in Neighbour.levels():
		var step: Dictionary = level
		var from := int(step.get("from", 0))
		if from <= previous:
			_problems.append("les paliers de crédit ne montent pas : %d après %d" % [from, previous])
		previous = from
		_check_translation(&"standing", String(step.get("name_key", "")))
	for value in range(Neighbour.minimum(), Neighbour.maximum() + 1):
		if Neighbour.standing_key(value).is_empty():
			_problems.append("le crédit %+d ne tombe dans aucun palier" % value)


func _check_councils() -> void:
	var councils := KingdomEvent.ids()
	print("\nLe conseil du royaume : %d évènements\n" % councils.size())
	var open_pool := 0
	for event_id: StringName in councils:
		_check_council(event_id)
		if KingdomEvent.weight_of(event_id) > 0 and KingdomEvent.required_standing(event_id).is_empty():
			open_pool += 1

	# UN VIVIER TROP MINCE SE RABÂCHE, et `draw` ne s'en plaint pas : il
	# rouvre la table quand elle est vide. Le même raisonnement que pour
	# les évènements d'expédition, où quatre entrées faisaient se répéter
	# une route de sept étapes.
	print("\n%d conseils tirables sans crédit" % open_pool)
	if open_pool < KingdomEvent.minimum_pool():
		_problems.append(
			"seulement %d conseils tirables d'emblée : ils se répéteront"
			% open_pool)
	if KingdomEvent.recent_kept() >= open_pool:
		_problems.append(
			"on écarte %d conseils récents sur %d tirables : la table se rouvrira à chaque fois"
			% [KingdomEvent.recent_kept(), open_pool])
	_check_credit_sources()


func _check_council(event_id: StringName) -> void:
	_check_translation(event_id, KingdomEvent.name_key(event_id))
	_check_translation(event_id, KingdomEvent.text_key(event_id))

	var options := KingdomEvent.options(event_id)
	print("%-14s %-34s %d options" % [
		event_id, TranslationServer.translate(KingdomEvent.name_key(event_id)), options.size()])
	if KingdomEvent.weight_of(event_id) <= 0:
		_problems.append("%s : poids nul, il ne sortira jamais" % event_id)
	if options.size() < 2:
		_problems.append("%s : une seule option, donc aucune décision" % event_id)
		return

	var required := KingdomEvent.required_standing(event_id)
	if not required.is_empty():
		var town_id := StringName(required.get("town", ""))
		if not Neighbour.exists(town_id):
			_problems.append("%s : exige le crédit d'une ville inconnue « %s »" % [event_id, town_id])
		elif int(required.get("minimum", 0)) > Neighbour.maximum():
			_problems.append("%s : exige un crédit hors d'atteinte (%d)"
				% [event_id, int(required.get("minimum", 0))])

	var scored: Array[Dictionary] = []
	for index in options.size():
		_check_translation(event_id, KingdomEvent.option_label(event_id, index))
		_check_branches(event_id, index)
		var value := _council_value(event_id, index)
		scored.append(value)
		print("    %-40s %s" % [
			TranslationServer.translate(KingdomEvent.option_label(event_id, index)),
			_describe_council(value)])

	for a in options.size():
		for b in options.size():
			if a != b and _dominates(scored[a], scored[b]):
				_problems.append(
					"%s : l'option %d est meilleure que la %d sur toute la ligne"
					% [event_id, a, b])


## Ce qu'une option peut écrire dans le royaume. Tout le reste est une
## COQUILLE : un effet mal orthographié ne plante pas, il ne fait rien —
## et une option qui ne fait rien passerait pour un choix.
func _known_effects() -> Array[String]:
	var known: Array[String] = ["threat", "population", "trade_xp", "standing",
		"potions", "hero", "text_key"]
	for resource_id: StringName in ResourceTable.ids():
		known.append(String(resource_id))
	return known


func _check_branches(event_id: StringName, index: int) -> void:
	var option := KingdomEvent.option(event_id, index)
	var branches: Array[String] = ["success"]
	if KingdomEvent.option_gambles(event_id, index):
		branches.append("failure")
		if not option.has("failure"):
			_problems.append("%s option %d : parie sans dire ce qu'on perd" % [event_id, index])
	elif option.has("failure"):
		_problems.append("%s option %d : a un échec sans chance de rater" % [event_id, index])

	var known := _known_effects()
	for branch: String in branches:
		var effects: Dictionary = option.get(branch, {})
		_check_translation(event_id, String(effects.get("text_key", "")))
		for key: Variant in effects.keys():
			if not known.has(String(key)):
				_problems.append("%s option %d : effet inconnu « %s »"
					% [event_id, index, key])
		for key: Variant in (effects.get("standing", {}) as Dictionary).keys():
			if not Neighbour.exists(StringName(key)):
				_problems.append("%s option %d : crédite une ville inconnue « %s »"
					% [event_id, index, key])
		for key: Variant in (effects.get("trade_xp", {}) as Dictionary).keys():
			if not Worksite.exists(StringName(key)):
				_problems.append("%s option %d : forme à un chantier inconnu « %s »"
					% [event_id, index, key])
		for key: Variant in (effects.get("potions", {}) as Dictionary).keys():
			if not Consumable.exists(StringName(key)):
				_problems.append("%s option %d : donne une fiole inconnue « %s »"
					% [event_id, index, key])
		var gift: Dictionary = effects.get("hero", {})
		if not gift.is_empty() and not Unit.hero_class_ids().has(StringName(gift.get("class", ""))):
			_problems.append("%s option %d : offre une classe inconnue « %s »"
				% [event_id, index, gift.get("class", "")])


## L'espérance d'une option sur chaque monnaie de l'échange. Une option qui
## parie compte ses deux issues au prorata de sa chance : c'est ce que le
## joueur compare, et c'est donc ce qu'il faut comparer.
##
## CHAQUE VILLE EST SON PROPRE AXE, jamais une somme. Soutenir Valmont
## contre Roche-Claire fait zéro en somme, exactement comme ne rien faire —
## et les deux ne sont pas du tout la même décision.
func _council_value(event_id: StringName, index: int) -> Dictionary:
	var option := KingdomEvent.option(event_id, index)
	var chance := clampf(KingdomEvent.option_chance(event_id, index), 0.0, 1.0)
	var value := {"threat": 0.0, "population": 0.0, "xp": 0.0, "potions": 0.0, "hero": 0.0}
	for resource_id: StringName in ResourceTable.ids():
		value[String(resource_id)] = 0.0
	for town_id: StringName in Neighbour.ids():
		value["credit:%s" % town_id] = 0.0

	var branches := {"success": chance, "failure": 1.0 - chance}
	for branch: String in branches:
		var weight: float = branches[branch]
		if is_zero_approx(weight):
			continue
		var effects: Dictionary = option.get(branch, {})
		for resource_id: StringName in ResourceTable.ids():
			value[String(resource_id)] += weight * float(effects.get(String(resource_id), 0))
		# LA MENACE EST UNE MAUVAISE CHOSE : on la compte à l'envers, sinon
		# l'option qui attire les pillards passerait pour la meilleure.
		value["threat"] -= weight * float(effects.get("threat", 0))
		value["population"] += weight * float(effects.get("population", 0))
		for key: Variant in (effects.get("trade_xp", {}) as Dictionary).keys():
			value["xp"] += weight * float((effects["trade_xp"] as Dictionary)[key])
		for key: Variant in (effects.get("potions", {}) as Dictionary).keys():
			value["potions"] += weight * float((effects["potions"] as Dictionary)[key])
		for key: Variant in (effects.get("standing", {}) as Dictionary).keys():
			var axis := "credit:%s" % key
			if value.has(axis):
				value[axis] += weight * float((effects["standing"] as Dictionary)[key])
		var gift: Dictionary = effects.get("hero", {})
		if not gift.is_empty():
			value["hero"] += weight * float(gift.get("level", 1))
	return value


func _dominates(a: Dictionary, b: Dictionary) -> bool:
	var strictly_better := false
	for key: String in a:
		if float(a[key]) < float(b[key]) - 0.0001:
			return false
		if float(a[key]) > float(b[key]) + 0.0001:
			strictly_better = true
	return strictly_better


func _describe_council(value: Dictionary) -> String:
	var pieces := PackedStringArray()
	for resource_id: StringName in ResourceTable.ids():
		if not is_zero_approx(float(value[String(resource_id)])):
			pieces.append("%s %+.0f" % [resource_id, float(value[String(resource_id)])])
	if not is_zero_approx(float(value["threat"])):
		pieces.append("menace %+.0f" % -float(value["threat"]))
	if not is_zero_approx(float(value["population"])):
		pieces.append("bras %+.1f" % float(value["population"]))
	if not is_zero_approx(float(value["xp"])):
		pieces.append("métier %+.0f" % float(value["xp"]))
	if not is_zero_approx(float(value["potions"])):
		pieces.append("fioles %+.1f" % float(value["potions"]))
	if not is_zero_approx(float(value["hero"])):
		pieces.append("un champion")
	for town_id: StringName in Neighbour.ids():
		var credit := float(value["credit:%s" % town_id])
		if not is_zero_approx(credit):
			pieces.append("%s %+.1f" % [town_id, credit])
	return ", ".join(pieces)


## LE CRÉDIT DOIT POUVOIR MONTER ET DESCENDRE, pour chaque ville. Un crédit
## qui ne ferait que monter serait une barre de progression déguisée en
## diplomatie ; un qui ne ferait que descendre serait une punition.
##
## ET UN CONSEIL QUE LE CRÉDIT OUVRE EXIGE DEUX SOURCES. Avec une seule, un
## joueur qui la refuse une fois attend indéfiniment son champion : l'offre
## gagnée redevient une loterie, ce qui est exactement ce qu'elle n'est pas
## censée être.
func _check_credit_sources() -> void:
	print("")
	for town_id: StringName in Neighbour.ids():
		var rises: Array[String] = []
		var falls := 0
		for event_id: StringName in KingdomEvent.ids():
			var gated: Dictionary = KingdomEvent.required_standing(event_id)
			var closed := StringName(gated.get("town", "")) == town_id
			var up := false
			for index in KingdomEvent.options(event_id).size():
				for branch: String in ["success", "failure"]:
					var shifts: Dictionary = KingdomEvent.option(event_id, index).get(branch, {}).get("standing", {})
					var delta := int(shifts.get(String(town_id), 0))
					if delta > 0 and not closed:
						up = true
					elif delta < 0:
						falls += 1
			if up:
				rises.append(String(event_id))
		print("%-14s %d conseils le font monter, %d options le font descendre"
			% [town_id, rises.size(), falls])
		if rises.is_empty():
			_problems.append("%s : aucun conseil ne fait monter son crédit" % town_id)
		if falls <= 0:
			_problems.append("%s : rien ne fait descendre son crédit" % town_id)

	for event_id: StringName in KingdomEvent.ids():
		var gated := KingdomEvent.required_standing(event_id)
		if gated.is_empty():
			continue
		var town_id := StringName(gated.get("town", ""))
		var sources := 0
		for other: StringName in KingdomEvent.ids():
			if StringName(KingdomEvent.required_standing(other).get("town", "")) == town_id:
				continue
			for index in KingdomEvent.options(other).size():
				var shifts: Dictionary = KingdomEvent.option(other, index).get("success", {}).get("standing", {})
				if int(shifts.get(String(town_id), 0)) > 0:
					sources += 1
					break
		if sources < 2:
			_problems.append(
				"%s : le crédit de %s ne se gagne que dans %d conseil — une seule porte"
				% [event_id, town_id, sources])
