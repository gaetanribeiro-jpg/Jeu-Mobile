extends SceneTree

## Simulateur de combats en masse.
##
##     godot --headless --path . -s tools/simulate_combats.gd
##     godot --headless --path . -s tools/simulate_combats.gd -- 200
##
## Joue chaque carte sur N graines avec une politique de joueur triviale,
## et rend quatre chiffres. Les trois derniers comptent plus que le
## premier :
##
##   victoire   le taux de victoire. 100 % partout ne veut pas dire
##              « équilibré », seulement « gagnable en pilote automatique ».
##   rondes     la durée. La cible est 3 à 8 (rules.json, turns).
##   PV         les points de vie qu'il RESTE à l'équipe à la fin, en
##              pourcentage. C'est le vrai instrument : une victoire à
##              98 % de PV est un combat qui ne s'est jamais joué.
##   tombés     le nombre moyen de personnages mis hors de combat.
##
## Ce que l'on cherche pour T1.11 : des victoires, mais payées. Une
## escarmouche de tutoriel peut finir à 85 % de PV ; un gardien ne devrait
## pas se passer sans descendre sous 60 %, et devrait pouvoir coûter
## quelqu'un.
##
## La politique ne joue pas bien — elle avance et vide ses PA sur le plus
## proche. Les chiffres sont donc un PLANCHER : un vrai joueur fera mieux.
## Une carte que ce pilote perd n'est pas forcément trop dure ; une carte
## qu'il gagne sans une égratignure est forcément trop facile.
##
## CHAQUE CARTE EST JOUÉE DEUX FOIS, de jour puis de nuit (§ 36). La nuit
## ajoute un ennemi : sans cette colonne, on réglerait le cycle à l'estime,
## et la moitié des rencontres d'une expédition profonde échapperait à la
## seule mesure dont on dispose.

## Plafond de sécurité, en RONDES et pas en activations.
##
## IL ÉTAIT EN ACTIVATIONS, ET C'ÉTAIT UN PIÈGE. Trente activations, c'est
## trois rondes à onze combattants et sept rondes à quatre : le plafond
## dépendait donc du NOMBRE D'ENNEMIS. En ajoutant la bête de la nuit
## (§ 36), des combats parfaitement gagnés se sont mis à sortir « perdus »
## — `vallee_06` rendait 56 % de victoires avec 91 % de PV et personne à
## terre, ce qui ne veut rien dire. On mesurait le plafond de l'outil, pas
## la carte.
##
## Une ronde est l'unité du jeu ; c'est donc la bonne unité pour ce
## plafond. Trois fois la durée visée laisse toute la place à une carte
## lente sans jamais laisser tourner une boucle folle.
const ROUND_CAP_FACTOR := 3

## Garde-fou dur, au cas où une ronde ne se terminerait jamais.
const ACTIVATION_CAP := 500


func _init() -> void:
	var runs := 50
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0 and arguments[0].is_valid_int():
		runs = maxi(1, arguments[0].to_int())

	print("Simulation : %d graines par carte, politique de joueur triviale.\n" % runs)
	print("%-14s %-7s %9s %8s %7s %8s"
		% ["carte", "heure", "victoire", "rondes", "PV", "tombés"])
	print("-".repeat(58))

	var total_turns := 0
	var total_health := 0.0
	var total_downed := 0.0
	var total_runs := 0
	for id: StringName in CombatMap.map_ids():
		for moment: StringName in [&"day", &"night"]:
			var wins := 0
			var turns_sum := 0
			var health_sum := 0.0
			var downed_sum := 0.0
			for i in runs:
				var result := _run(id, 1000 + i * 7919, moment)
				if result.is_empty():
					continue
				if result["victory"]:
					wins += 1
				turns_sum += int(result["turns"])
				health_sum += float(result["health"])
				downed_sum += float(result["downed"])
			# LA MOYENNE GÉNÉRALE RESTE CELLE DU JOUR. Elle sert de repère
			# depuis T1.11 et la comparer à elle-même d'une session à
			# l'autre n'aurait plus de sens si la nuit venait s'y mêler.
			if moment == &"day":
				total_turns += turns_sum
				total_health += health_sum
				total_downed += downed_sum
				total_runs += runs
			print("%-14s %-7s %8d%% %8.1f %6d%% %8.2f" % [
				id if moment == &"day" else "", moment,
				int(round(100.0 * wins / runs)),
				float(turns_sum) / float(runs),
				int(round(100.0 * health_sum / float(runs))),
				downed_sum / float(runs),
			])

	print("-".repeat(58))
	print("Durée moyenne : %.1f rondes (cible : %d à %d)" % [
		float(total_turns) / float(maxi(total_runs, 1)),
		int(CombatRules.rule(&"turns", &"min_rounds", 3)),
		int(CombatRules.rule(&"turns", &"max_rounds", 8)),
	])
	print("PV restants   : %d%% en moyenne, %.2f personnage tombé par combat" % [
		int(round(100.0 * total_health / float(maxi(total_runs, 1)))),
		total_downed / float(maxi(total_runs, 1)),
	])
	quit(0)


func _squad() -> Array[Unit]:
	var wanted: Array = [&"warrior", &"archer", &"mage", &"warrior"]
	return Unit.squad_from_classes(wanted.slice(0, CombatRules.team_size()))


func _run(
	map_id: StringName, seed_value: int, moment: StringName = DayNight.DEFAULT_MOMENT
) -> Dictionary:
	var map := CombatMap.load_map(map_id)
	if map == null:
		return {}
	var rng := CombatRng.new(seed_value)
	# On prend le renfort de la région où la carte se joue. Les Terres
	# Vertes sont la seule région de l'Acte I ; le jour où il y en aura
	# deux, ce sera à passer en argument.
	DayNight.reinforce(
		map.board, moment, Region.night_roster(&"greenlands"),
		map.deployment_cells, rng, map.objective
	)
	var engine := map.to_engine(_squad(), rng)
	engine.start()
	# Les simulations ne choisissent pas leur placement : ce serait une
	# stratégie de plus à écrire, et c'est justement la décision qu'on veut
	# laisser au joueur. On pose sur les premières cases libres.
	engine.auto_deploy()
	engine.begin_combat()
	var round_cap := ROUND_CAP_FACTOR * int(CombatRules.rule(&"turns", &"max_rounds", 8))
	var activations := 0
	while (not engine.is_finished()
			and engine.round_index() <= round_cap
			and activations < ACTIVATION_CAP):
		var hero := engine.current_unit()
		if hero != null and hero.is_hero():
			_play_activation(engine, hero)
		engine.end_activation()
		activations += 1
	# Les PV restants, tombés compris : c'est ce que le combat a coûté.
	var current := 0
	var maximum := 0
	var downed := 0
	for unit: Unit in engine.board.units():
		if not unit.is_hero():
			continue
		current += unit.hit_points
		maximum += unit.max_hit_points
		if unit.is_downed():
			downed += 1
	return {
		"victory": engine.is_victory(),
		"turns": engine.round_index(),
		"health": float(current) / float(maxi(maximum, 1)),
		"downed": downed,
	}


## Le pilote automatique d'un personnage : il va vers son objectif s'il en
## a un, sinon il s'approche de l'ennemi le plus proche et vide ses PA
## dessus. Ce n'est pas une bonne stratégie, c'est une stratégie
## REPRODUCTIBLE — ce qu'il faut pour comparer deux réglages.
func _play_activation(engine: CombatEngine, hero: Unit) -> void:
	var goal := _goal_for(engine, hero)
	if goal != Vector2i(-1, -1):
		_walk_toward(engine, hero, goal, 0)
		# Les PA ne se gardent pas d'une activation à l'autre : marcher vers
		# un objectif n'empêche pas de frapper ce qui barre la route. Sans
		# cette ligne, une carte à couloir se solde par une file de héros
		# bloqués derrière un gobelin qu'ils ne songent jamais à écarter —
		# et l'outil mesure alors sa propre bêtise, pas la carte.
		_spend_action_points(engine, hero)
		return

	var target := _nearest_enemy(engine, hero)
	if target == null:
		return
	if not _can_hit(engine, hero, target):
		_walk_toward(engine, hero, target.cell, _closest_range(hero))
	_spend_action_points(engine, hero)


## Vide les PA du personnage sur l'ennemi le plus proche qu'il peut
## atteindre, la compétence la plus chère d'abord.
func _spend_action_points(engine: CombatEngine, hero: Unit) -> void:
	while true:
		var target := _nearest_reachable_enemy(engine, hero)
		if target == null:
			return
		var ability := _best_ability(engine, hero, target)
		if ability == null:
			return
		if engine.use_ability(hero, ability.id, target.cell).is_empty():
			return


func _nearest_enemy(engine: CombatEngine, hero: Unit) -> Unit:
	var best: Unit = null
	for candidate: Unit in engine.board.active_units(Unit.Side.ENEMIES):
		if best == null or engine.board.grid.distance(hero.cell, candidate.cell) \
				< engine.board.grid.distance(hero.cell, best.cell):
			best = candidate
	return best


## Le plus proche ennemi que ce personnage peut frapper là où il se tient.
func _nearest_reachable_enemy(engine: CombatEngine, hero: Unit) -> Unit:
	var best: Unit = null
	for candidate: Unit in engine.board.active_units(Unit.Side.ENEMIES):
		if _best_ability(engine, hero, candidate) == null:
			continue
		if best == null or engine.board.grid.distance(hero.cell, candidate.cell) \
				< engine.board.grid.distance(hero.cell, best.cell):
			best = candidate
	return best


## La compétence la plus chère que ce personnage peut porter maintenant.
func _best_ability(engine: CombatEngine, hero: Unit, target: Unit) -> Ability:
	var best: Ability = null
	for ability_id: StringName in hero.abilities:
		var ability := Ability.of(ability_id)
		if ability == null or not ability.is_attack():
			continue
		if not engine.can_use(hero, ability_id):
			continue
		if not engine.targetable_cells(hero, ability_id).has(target.cell):
			continue
		if best == null or ability.action_points > best.action_points:
			best = ability
	return best


func _can_hit(engine: CombatEngine, hero: Unit, target: Unit) -> bool:
	return _best_ability(engine, hero, target) != null


## La portée minimale la plus basse dont dispose ce personnage : c'est la
## distance à laquelle il doit s'arrêter d'avancer.
func _closest_range(hero: Unit) -> int:
	var closest := 99
	for ability_id: StringName in hero.abilities:
		var ability := Ability.of(ability_id)
		if ability != null and ability.is_attack():
			closest = mini(closest, ability.range_min)
	return closest if closest < 99 else 1


func _goal_for(engine: CombatEngine, hero: Unit) -> Vector2i:
	var objective := engine.objective
	match objective.kind:
		CombatObjective.Kind.ESCORT:
			if objective.subject_ids.has(hero.id):
				return _open_goal(engine, hero, objective.cells)
		CombatObjective.Kind.SEIZE:
			return _open_goal(engine, hero, objective.cells)
		CombatObjective.Kind.EXTRACT:
			if not objective.carried:
				return _open_goal(engine, hero, objective.pickup_cells)
			return _open_goal(engine, hero, objective.cells)
	return Vector2i(-1, -1)


## La case d'objectif LIBRE la plus proche, et pas la première déclarée.
##
## PRENDRE `cells[0]` A COÛTÉ UNE FAUSSE MESURE. Sur `vallee_06`, le
## pilote garait son propre Guerrier sur (11,3) et l'escorté, arrivé en
## (10,3), passait quinze rondes à viser une case occupée par son escorte
## alors que (11,4) était libre à côté. La carte sortait « perdue » 44 %
## du temps — et rien dans la carte ne clochait, c'est l'outil qui se
## bloquait tout seul. Un vrai joueur prendrait la case d'à côté.
##
## Les cases d'objectif sont données en alternative, jamais en liste
## ordonnée : les traiter comme une file était une lecture fausse de la
## donnée, pas seulement une politique paresseuse.
func _open_goal(
	engine: CombatEngine, hero: Unit, cells: Array[Vector2i]
) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := -1
	for cell: Vector2i in cells:
		var occupant := engine.board.unit_at(cell)
		if occupant != null and occupant.id != hero.id:
			continue
		var distance := engine.board.grid.distance(hero.cell, cell)
		if best_distance < 0 or distance < best_distance:
			best_distance = distance
			best = cell
	return best


func _walk_toward(engine: CombatEngine, hero: Unit, goal: Vector2i, keep: int) -> void:
	var best := hero.cell
	var best_distance := engine.board.grid.distance(hero.cell, goal)
	for cell: Vector2i in engine.board.reachable_cells(hero).keys():
		var distance := engine.board.grid.distance(cell, goal)
		if distance < best_distance and distance >= keep:
			best_distance = distance
			best = cell
	if best != hero.cell:
		engine.move(hero, best)
