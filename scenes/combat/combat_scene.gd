extends Node2D

## La scène de combat (C1.15, C1.17, C1.18, C1.22).
##
## Elle ne décide rien du jeu : toute règle vit dans `CombatEngine`. Son
## travail est de montrer l'état, de traduire des doigts en actions, et de
## rejouer le journal du tour ennemi.
##
## GRAMMAIRE D'INTERACTION (§ 11.2), et la règle absolue qui la gouverne :
## rien n'est irréversible avant la validation du tour.
##   tap sur un héros        → le sélectionner, montrer ses cases
##   tap sur une case valide → prévisualiser (fantôme)
##   tap sur la même case    → valider
##   glissement              → caméra
##   pincement               → zoom
## Le double tap n'est pas une coquetterie : il évite 90 % des erreurs de
## gros doigts, et il coûte un état de plus dans la machine.

signal combat_finished(victory: bool)

enum Selection { NONE, UNIT, PREVIEW }

const HERO_COLOR := "Blue"
const ENEMY_COLOR := "Red"

var engine: CombatEngine
var map_id: StringName = &"vallee_01"

var _terrain: Node2D
var _units_root: Node2D
var _overlay: Node2D
var _camera: Camera2D
var _hud: CanvasLayer

var _views: Dictionary = {}
var _ghost: Sprite2D
var _selection: int = Selection.NONE
var _selected: Unit = null
var _preview_cell: Vector2i = Vector2i(-1, -1)
var _preview_target: Unit = null
var _resolving := false

var _touch_start: Vector2 = Vector2.ZERO
var _touch_moved := false
var _dragging := false
var _tile_size: int = 0


func _ready() -> void:
	_tile_size = AssetTable.tile_size()
	if engine == null:
		_build_from_map()
	_build_scene()
	_refresh_all()


## Prépare la scène sur une carte donnée. À appeler avant de l'ajouter à
## l'arbre ; sinon la carte par défaut est chargée.
func configure(combat_map_id: StringName, squad: Array[Unit], rng: CombatRng = null) -> void:
	map_id = combat_map_id
	var map := CombatMap.load_map(map_id)
	if map == null:
		return
	engine = map.to_engine(squad, rng)
	engine.start()


## Escouade de démonstration, quand la scène est lancée sans configuration.
## Elle compte `squad_size` héros — trois pour quatre classes, donc un
## choix à faire — et la composition par défaut porte volontairement un
## doublon, pour que le cas des deux mêmes classes soit celui qu'on voit
## tous les jours plutôt qu'un cas limite qu'on découvre tard.
func default_squad() -> Array[Unit]:
	var wanted: Array = [&"warrior", &"archer", &"warrior", &"monk"]
	return Unit.squad_from_classes(wanted.slice(0, CombatRules.squad_size()))


func _build_from_map() -> void:
	var squad := default_squad()
	var map := CombatMap.load_map(map_id)
	if map == null:
		return
	engine = map.to_engine(squad, CombatRng.new(1))
	engine.start()


func _build_scene() -> void:
	if engine == null:
		return

	_terrain = Node2D.new()
	_terrain.set_script(load("res://scenes/combat/terrain_view.gd"))
	add_child(_terrain)
	_terrain.setup(engine.board)

	_units_root = Node2D.new()
	_units_root.y_sort_enabled = true
	add_child(_units_root)

	# Fantôme de prévisualisation (§ 11.2) : le sprite de l'unité, à demi
	# transparent, sur la case visée. Un contour seul ne dit pas QUI va
	# bouger, ce qui est précisément la question quand quatre héros sont
	# empilés dans un coin.
	_ghost = Sprite2D.new()
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost.visible = false
	_units_root.add_child(_ghost)

	_overlay = Node2D.new()
	_overlay.set_script(load("res://scenes/combat/overlay_layer.gd"))
	add_child(_overlay)
	_overlay.setup(engine.board.grid)

	_camera = Camera2D.new()
	_camera.set_script(load("res://scenes/combat/combat_camera.gd"))
	add_child(_camera)
	_camera.make_current()
	_camera.frame_board(engine.board.grid, _tile_size, get_viewport_rect().size)

	_hud = CanvasLayer.new()
	_hud.set_script(load("res://scenes/combat/combat_hud.gd"))
	add_child(_hud)
	_hud.end_turn_pressed.connect(_on_end_turn)
	_hud.undo_pressed.connect(_on_undo)

	for unit: Unit in engine.board.units():
		_spawn_view(unit)


func _spawn_view(unit: Unit) -> void:
	var view := Node2D.new()
	view.set_script(load("res://scenes/combat/unit_view.gd"))
	_units_root.add_child(view)
	view.setup(unit, HERO_COLOR if unit.is_hero() else ENEMY_COLOR)
	view.position = _centre_of(unit.cell)
	_views[unit.id] = view


func _centre_of(cell: Vector2i) -> Vector2:
	return engine.board.grid.to_world_center(cell, _tile_size)


# --- Entrées (C1.17) ------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if engine == null or _resolving:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		if pressed:
			_touch_start = event.position
			_touch_moved = false
			_dragging = false
		elif not _touch_moved:
			_on_tap(get_global_mouse_position())
		return

	if event is InputEventScreenDrag or (
		event is InputEventMouseMotion and event.button_mask != 0
	):
		var travelled: float = _touch_start.distance_to(event.position)
		if not _dragging and travelled > ViewSettings.number(
			&"camera", &"drag_threshold_px", 12.0
		):
			_dragging = true
			_touch_moved = true
		if _dragging:
			_camera.pan(event.relative)
		return

	# Molette : pratique pour tester au clavier, sans remplacer le pincement.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.set_zoom_level(_camera.zoom_level() * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.set_zoom_level(_camera.zoom_level() / 1.1)


## Un tap sur le monde. C'est ici que vit la grammaire du § 11.2.
func handle_tap(cell: Vector2i) -> void:
	if engine == null or engine.is_finished() or _resolving:
		return
	if not engine.board.grid.contains(cell):
		_clear_selection()
		return

	match _selection:
		Selection.NONE:
			_try_select(cell)
		Selection.UNIT:
			_try_preview(cell)
		Selection.PREVIEW:
			if cell == _preview_cell:
				_confirm()
			else:
				_try_preview(cell)
	_refresh_all()


func _on_tap(world_position: Vector2) -> void:
	handle_tap(engine.board.grid.to_cell(world_position, _tile_size))


func _try_select(cell: Vector2i) -> void:
	var unit := engine.board.unit_at(cell)
	if unit == null or not unit.is_hero() or not unit.is_active():
		_clear_selection()
		return
	_selected = unit
	_selection = Selection.UNIT


## Deuxième tap : on montre ce qui va se passer, sans rien appliquer.
func _try_preview(cell: Vector2i) -> void:
	if _selected == null:
		_clear_selection()
		return

	var occupant := engine.board.unit_at(cell)
	if occupant != null and occupant.is_hero() and occupant.is_active() and occupant != _selected:
		_selected = occupant
		_selection = Selection.UNIT
		_preview_cell = Vector2i(-1, -1)
		_preview_target = null
		return

	if occupant != null and not occupant.is_hero() and engine.board.can_attack(_selected, occupant):
		_preview_target = occupant
		_preview_cell = cell
		_selection = Selection.PREVIEW
		return

	if occupant == null and not _selected.has_moved and engine.board.can_move_to(_selected, cell):
		_preview_target = null
		_preview_cell = cell
		_selection = Selection.PREVIEW
		return

	_clear_selection()


## Troisième tap sur la même case : on valide.
func _confirm() -> void:
	if _selected == null:
		return
	if _preview_target != null:
		var report := engine.attack(_selected, _preview_target)
		if not report.is_empty():
			_play_attack(_selected, _preview_target, report)
	else:
		var from := _selected.cell
		if engine.move_hero(_selected, _preview_cell):
			_animate_move(_selected, from, _selected.cell)
	_clear_selection()


func _clear_selection() -> void:
	_selection = Selection.NONE
	_selected = null
	_preview_cell = Vector2i(-1, -1)
	_preview_target = null
	_refresh_ghost()


## Montre le fantôme sur la case visée, et seulement pour un déplacement :
## sur une attaque, c'est le chiffre des dégâts qui informe, pas un sprite
## posé sur l'ennemi.
func _refresh_ghost() -> void:
	if _ghost == null:
		return
	var showing := (
		_selection == Selection.PREVIEW
		and _selected != null
		and _preview_target == null
		and engine.board.grid.contains(_preview_cell)
	)
	_ghost.visible = showing
	if not showing:
		return
	var frames: SpriteFrames = null
	if _selected.is_hero():
		frames = SpriteFrameFactory.for_unit(_selected.class_id, &"idle", HERO_COLOR)
	if frames == null or frames.get_frame_count(&"default") == 0:
		_ghost.visible = false
		return
	_ghost.texture = frames.get_frame_texture(&"default", 0)
	_ghost.position = _centre_of(_preview_cell)
	_ghost.modulate = ViewSettings.color(&"ghost")


# --- Boutons --------------------------------------------------------------

func _on_undo() -> void:
	if engine.undo():
		_clear_selection()
		_sync_views()
		_refresh_all()


func _on_end_turn() -> void:
	if _resolving or engine.is_finished():
		return
	_clear_selection()
	_resolve_enemy_turn()


# --- Tour ennemi (C1.22) --------------------------------------------------

## Rejoue le journal du moteur, un évènement à la fois.
##
## Le moteur a déjà tout résolu ; ce qui se joue ici est une relecture.
## Ordonnée, jamais simultanée : si trois gobelins frappent, on les voit
## frapper l'un après l'autre. C'est la seule façon pour le joueur de
## comprendre POURQUOI il a perdu quatre points de vie.
func _resolve_enemy_turn() -> void:
	_resolving = true
	var log := engine.end_player_turn()
	var gap := ViewSettings.duration(&"enemy_step_gap")

	for entry: Dictionary in log:
		match String(entry["event"]):
			"attack_landed", "attack_missed", "attack_warded":
				var attacker: Unit = engine.board.unit_by_id(int(entry["attacker_id"]))
				var view: Node2D = _views.get(attacker.id, null)
				if view != null:
					var cell: Vector2i = entry["cell"]
					view.play_attack(cell - attacker.cell)
					await get_tree().create_timer(
						ViewSettings.duration(&"attack_strike")
					).timeout
				if String(entry["event"]) == "attack_landed":
					await _play_impact(int(entry["target_id"]), bool(entry["downed"]))
			"enemy_moved":
				var unit: Unit = engine.board.unit_by_id(int(entry["unit_id"]))
				await _animate_move(unit, entry["from"], entry["to"])
			"combat_ended":
				_hud.show_result(bool(entry["victory"]))
				combat_finished.emit(bool(entry["victory"]))
		await get_tree().create_timer(gap).timeout
		_refresh_all()

	_sync_views()
	_resolving = false
	_refresh_all()


func _animate_move(unit: Unit, from: Vector2i, to: Vector2i) -> void:
	var view: Node2D = _views.get(unit.id, null)
	if view == null:
		return
	var path: Array[Vector2] = []
	for cell: Vector2i in engine.board.grid.line(from, to):
		path.append(_centre_of(cell))
	await view.move_along(path)
	_refresh_all()


func _play_attack(attacker: Unit, target: Unit, report: Dictionary) -> void:
	_resolving = true
	var view: Node2D = _views.get(attacker.id, null)
	if view != null:
		view.play_attack(target.cell - attacker.cell)
		await get_tree().create_timer(ViewSettings.duration(&"attack_strike")).timeout
	await _play_impact(target.id, bool(report.get("downed", false)))
	_resolving = false
	_sync_views()
	_refresh_all()


func _play_impact(target_id: int, downed: bool) -> void:
	var view: Node2D = _views.get(target_id, null)
	if view == null:
		return
	# Hit stop : 80 ms de gel à l'impact. Le § 12 le met en tête du rapport
	# impact/coût, et il ne coûte effectivement qu'une attente.
	await get_tree().create_timer(ViewSettings.duration(&"hit_stop")).timeout
	if downed:
		await view.play_downed()
	else:
		await view.play_hit()


# --- Rafraîchissement -----------------------------------------------------

func _sync_views() -> void:
	for unit: Unit in engine.board.units():
		var view: Node2D = _views.get(unit.id, null)
		if view == null:
			continue
		view.position = _centre_of(unit.cell)
		view.visible = not unit.is_downed()
		view.modulate.a = 1.0
		if view.has_method("refresh"):
			view.refresh()


func _refresh_all() -> void:
	if engine == null:
		return
	_refresh_overlay()
	if _hud != null:
		_hud.refresh(engine)


func _refresh_overlay() -> void:
	if _overlay == null:
		return
	_overlay.move_cells.clear()
	_overlay.attack_cells.clear()
	_overlay.objective_cells = engine.objective.cells.duplicate()
	_overlay.warded_cells.clear()
	_overlay.selected_cell = _selected.cell if _selected != null else Vector2i(-1, -1)
	_overlay.ghost_cell = _preview_cell

	for cell: Vector2i in engine.board.grid.cells():
		if engine.is_warded(cell):
			_overlay.warded_cells.append(cell)

	if _selected != null:
		if not _selected.has_moved:
			for cell: Vector2i in engine.board.reachable_cells(_selected).keys():
				if cell != _selected.cell:
					_overlay.move_cells.append(cell)
		if not _selected.has_acted:
			for target: Unit in engine.board.attackable_units(_selected):
				_overlay.attack_cells.append(target.cell)

	var threat := {}
	for entry: Dictionary in engine.telegraph():
		var cells: Array = entry["cells"]
		for i in cells.size():
			var cell: Vector2i = cells[i]
			threat[cell] = int(threat.get(cell, 0)) + int(entry["damage"][i])
	# Dégâts que porterait l'attaque en cours de prévisualisation. Le joueur
	# doit lire le chiffre AVANT de valider, comme il lit ceux du télégraphe.
	_overlay.preview_damage.clear()
	if _preview_target != null and _selected != null:
		_overlay.preview_damage[_preview_target.cell] = engine.board.predicted_damage(
			_selected, _preview_target.cell
		)

	_overlay.threat = threat
	_refresh_ghost()
	_overlay.queue_redraw()
