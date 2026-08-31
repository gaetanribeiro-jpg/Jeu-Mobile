extends SceneTree

## Pilote un combat et capture chaque étape (développement seul).
##
##     xvfb-run -a godot --path . -s tools/dev/combat_storyboard.gd -- <dossier> [carte]
##
## Sert à VOIR ce que le joueur verra : sélection, cases valides,
## prévisualisation, validation, tour ennemi. C'est le seul moyen que j'ai
## de vérifier le rendu et l'enchaînement sans jouer.

var _scene: Node2D
var _out: String = "/tmp"
var _step: int = 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var map_id := StringName(args[1]) if args.size() > 1 else &"vallee_01"

	var packed: PackedScene = load("res://scenes/combat/combat_scene.tscn")
	_scene = packed.instantiate()
	_scene.map_id = map_id
	root.add_child(_scene)
	await _settle()

	var engine: CombatEngine = _scene.engine

	await _shot("01_placement")

	# Placement : on pose deux héros à la main, pour montrer le geste.
	var cells := engine.deployment_cells()
	_scene.handle_tap(cells[0])
	_scene.handle_tap(cells[3] if cells.size() > 3 else cells[1])
	await _settle()
	await _shot("02_deux_poses")

	# On complète et on lance le combat. Sans passer par les taps : sur une
	# case déjà occupée, un tap REPREND le héros, et la boucle oscillerait.
	engine.auto_deploy()
	for unit: Unit in engine.board.active_units(Unit.Side.HEROES):
		if not _scene._views.has(unit.id):
			_scene._spawn_view(unit)
	_scene._on_end_turn()
	await _settle()
	await _shot("03_combat_lance")

	var heroes := engine.board.active_units(Unit.Side.HEROES)
	if heroes.is_empty():
		quit(1)
		return
	var warrior: Unit = heroes[0]

	# Tap sur le guerrier : ses cases de déplacement et d'attaque s'allument.
	_scene.handle_tap(warrior.cell)
	await _settle()
	await _shot("04_selection")

	# Tap sur une case valide : fantôme de prévisualisation.
	var destination := _far_reachable(engine, warrior)
	_scene.handle_tap(destination)
	await _settle()
	await _shot("05_previsualisation")

	# Tap de confirmation sur la même case.
	_scene.handle_tap(destination)
	await _wait(1.2)
	await _shot("06_deplacement_valide")

	# Fin de tour : les ennemis avancent et annoncent.
	_scene._on_end_turn()
	await _wait(3.0)
	await _shot("07_apres_tour_ennemi")

	# Deuxième tour : on s'approche encore, puis on regarde le télégraphe.
	for i in 3:
		for hero: Unit in engine.board.active_units(Unit.Side.HEROES):
			var target := _nearest_enemy(engine, hero)
			if target != null and engine.board.can_attack(hero, target):
				engine.attack(hero, target)
			elif hero.movement_points > 0:
				var step := _step_toward(engine, hero, target)
				if step != hero.cell:
					engine.move(hero, step)
		_scene._on_end_turn()
		await _wait(3.0)
	await _shot("08_melee")

	print("storyboard terminé : %d captures dans %s" % [_step, _out])
	quit(0)


func _far_reachable(engine: CombatEngine, unit: Unit) -> Vector2i:
	var best := unit.cell
	var best_cost := -1
	for cell: Vector2i in engine.board.reachable_cells(unit).keys():
		var cost: int = engine.board.reachable_cells(unit)[cell]
		if cost > best_cost:
			best_cost = cost
			best = cell
	return best


func _nearest_enemy(engine: CombatEngine, unit: Unit) -> Unit:
	var enemies := engine.board.active_units(Unit.Side.ENEMIES)
	if enemies.is_empty():
		return null
	var best: Unit = enemies[0]
	for candidate: Unit in enemies:
		if engine.board.grid.distance(unit.cell, candidate.cell) \
				< engine.board.grid.distance(unit.cell, best.cell):
			best = candidate
	return best


func _step_toward(engine: CombatEngine, unit: Unit, target: Unit) -> Vector2i:
	if target == null:
		return unit.cell
	var best := unit.cell
	var best_distance := engine.board.grid.distance(unit.cell, target.cell)
	for cell: Vector2i in engine.board.reachable_cells(unit).keys():
		var distance := engine.board.grid.distance(cell, target.cell)
		if distance < best_distance and distance >= 1:
			best_distance = distance
			best = cell
	return best


func _settle() -> void:
	for i in 6:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
	await _settle()


func _shot(name_: String) -> void:
	await _settle()
	_step += 1
	var path := "%s/%s.png" % [_out, name_]
	root.get_texture().get_image().save_png(path)
	print("  %s" % path)
