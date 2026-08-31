extends Control

## Écran d'amorçage — et, pour l'instant, menu principal.
##
## LA BOUCLE PASSE PAR ICI, et elle est maintenant complète du côté du
## joueur : carte du monde → expédition → combat → butin → compagnie →
## sauvegarde. Il manque le royaume, qui est la Phase 4 et qui viendra se
## brancher au même endroit.
##
## LE BANC D'ESSAI RESTE. La liste des huit cartes lance un combat seul,
## hors expédition. Ce n'est pas un reliquat : je ne peux pas jouer au jeu,
## et pouvoir ouvrir une carte précise en deux clics est la seule façon de
## vérifier un combat sans traverser une sortie entière. Il est nommé pour
## ce qu'il est.
##
## PROVISOIRE quand même : le vrai menu principal viendra avec le royaume.

const COMBAT_SCENE := "res://scenes/combat/combat_scene.tscn"
const COMPANY_SCENE := "res://scenes/ui/company_screen.tscn"
const WORLD_SCENE := "res://scenes/world/world_map.tscn"
const EXPEDITION_SCENE := "res://scenes/world/expedition_screen.tscn"

## Identifiants des héros emmenés au banc d'essai, dans l'ordre des
## emplacements. L'expédition tient sa propre équipe.
var _squad_ids: Array[int] = []

## Combats du banc d'essai déjà enchaînés. Nourrit la profondeur du butin
## hors expédition ; une vraie sortie utilise la sienne.
var _depth: int = 0

var _company_screen: Control = null
var _world_screen: Control = null
var _expedition_screen: Control = null

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _maps: VBoxContainer = %Maps
@onready var _squad: VBoxContainer = %Squad


func _ready() -> void:
	_title.text = tr("GAME_TITLE")
	_subtitle.text = tr("BOOT_TEMPORARY")
	GameState.load_saved()
	_ensure_company()
	_reset_squad()
	_build_squad_picker()
	_build_map_list()


## Une compagnie vide n'a rien à montrer et rien à envoyer au combat : on
## en recrute une au premier lancement, à la graine de la partie, pour
## qu'elle soit la même à chaque rechargement.
func _ensure_company() -> void:
	var company := GameState.company
	if company.size() > 0:
		return
	var rng := GameState.combat_rng(0)
	var classes := Unit.hero_class_ids()
	for i in CombatRules.team_size():
		company.recruit(classes[i % classes.size()], rng)
	GameState.save()


func _reset_squad() -> void:
	_squad_ids.clear()
	for hero: Hero in GameState.company.heroes:
		if _squad_ids.size() < CombatRules.team_size():
			_squad_ids.append(hero.id)


# --- Le haut de l'écran : l'expédition et la compagnie ---------------------

func _build_squad_picker() -> void:
	for child in _squad.get_children():
		child.queue_free()

	var centre := CenterContainer.new()
	_squad.add_child(centre)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	centre.add_child(row)

	# Une expédition en cours passe avant tout le reste : elle a la
	# priorité sur le disque comme à l'écran, sinon on la perdrait en
	# repartant de zéro sans s'en apercevoir.
	var running := GameState.expedition != null and GameState.expedition.is_ongoing()
	var go := Button.new()
	go.custom_minimum_size = Vector2(400, 84)
	go.add_theme_font_size_override("font_size", 26)
	go.text = tr("BOOT_RESUME") if running else tr("BOOT_EXPEDITION")
	go.pressed.connect(_resume_expedition if running else _open_world)
	row.add_child(go)

	var company := Button.new()
	company.custom_minimum_size = Vector2(260, 84)
	company.add_theme_font_size_override("font_size", 26)
	company.text = tr("BOOT_COMPANY")
	company.pressed.connect(_open_company)
	row.add_child(company)


func _open_company() -> void:
	_company_screen = _open(COMPANY_SCENE, func(screen: Node) -> void:
		screen.configure(GameState.company)
		screen.closed.connect(_close_company)
		screen.changed.connect(GameState.save))


func _close_company() -> void:
	_dismiss(_company_screen)
	_company_screen = null
	_reset_squad()
	_build_squad_picker()
	visible = true


# --- La carte du monde -----------------------------------------------------

func _open_world() -> void:
	_world_screen = _open(WORLD_SCENE, func(screen: Node) -> void:
		screen.configure(GameState.company)
		screen.closed.connect(_close_world)
		screen.departed.connect(_depart))


func _close_world() -> void:
	_dismiss(_world_screen)
	_world_screen = null
	_build_squad_picker()
	visible = true


func _depart(region_id: StringName, hero_ids: Array) -> void:
	var ids: Array[int] = []
	for hero_id: Variant in hero_ids:
		ids.append(int(hero_id))
	# La graine de la sortie sort de la graine de la partie : deux
	# expéditions successives ne se ressemblent pas, et la même partie
	# rejouée les retrouve toutes les deux.
	var run := Expedition.depart(
		region_id, ids, GameState.combat_rng(GameState.company.gold + ids.size())
	)
	if run == null:
		return
	GameState.expedition = run
	GameState.save()
	_dismiss(_world_screen)
	_world_screen = null
	_open_expedition()


# --- L'expédition ----------------------------------------------------------

func _resume_expedition() -> void:
	if GameState.expedition == null:
		return
	_open_expedition()


func _open_expedition() -> void:
	_expedition_screen = _open(EXPEDITION_SCENE, func(screen: Node) -> void:
		screen.configure(GameState.expedition, GameState.company)
		screen.changed.connect(GameState.save)
		screen.combat_requested.connect(_start_expedition_combat)
		screen.finished.connect(_close_expedition))


func _close_expedition(_state: int) -> void:
	_dismiss(_expedition_screen)
	_expedition_screen = null
	# Une expédition finie ne doit pas rester dans la sauvegarde : au
	# prochain lancement, « Reprendre » proposerait une sortie déjà close.
	if GameState.expedition != null and GameState.expedition.is_over():
		GameState.expedition = null
	GameState.save()
	_build_squad_picker()
	visible = true


func _start_expedition_combat(map_id: StringName) -> void:
	var run: Expedition = GameState.expedition
	if run == null:
		return
	var units := run.squad_units(GameState.company)
	if units.is_empty():
		return
	_launch(map_id, units, CombatRng.new(hash([run.seed_value, run.index])),
		_on_expedition_combat_finished)


func _on_expedition_combat_finished(scene: Node) -> void:
	var run: Expedition = GameState.expedition
	if run == null or not is_instance_valid(scene):
		return
	var engine: CombatEngine = scene.engine
	var summary := CombatRewards.summarise(engine)
	# L'expérience va à la compagnie, le butin à la besace : la première
	# est acquise, le second reste en jeu jusqu'au retour.
	CombatRewards.award_to(
		GameState.company.squad(run.squad_ids), int(summary.get("experience", 0))
	)
	var heroes: Array[Unit] = []
	for unit: Unit in engine.board.units():
		if unit.is_hero():
			heroes.append(unit)
	if is_instance_valid(_expedition_screen):
		_expedition_screen.resolve_combat(summary, heroes)
		_expedition_screen.visible = true
	GameState.save()


# --- Le banc d'essai : un combat seul, hors expédition ---------------------

func _build_map_list() -> void:
	for child in _maps.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = tr("BOOT_TESTBENCH")
	header.add_theme_font_size_override("font_size", 22)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.64))
	_maps.add_child(header)

	# Un GridContainer prend sa taille minimale et se cale à gauche : sans
	# CenterContainer autour, la première colonne sort de l'écran.
	var centre := CenterContainer.new()
	_maps.add_child(centre)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	centre.add_child(grid)

	for map_id: StringName in CombatMap.map_ids():
		var map := CombatMap.load_map(map_id)
		var button := Button.new()
		button.text = tr(map.name_key) if map != null else String(map_id)
		button.custom_minimum_size = Vector2(250, 62)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_start_test_combat.bind(map_id))
		grid.add_child(button)


func _start_test_combat(map_id: StringName) -> void:
	var squad := GameState.company.squad(_squad_ids)
	if squad.is_empty():
		return
	_launch(map_id, GameState.company.to_units(squad),
		GameState.combat_rng(_depth), _on_test_combat_finished)


func _on_test_combat_finished(scene: Node) -> void:
	if not is_instance_valid(scene):
		return
	var summary := CombatRewards.summarise(scene.engine)
	if summary.is_empty():
		return
	CombatRewards.award_to(GameState.company.squad(_squad_ids), int(summary["experience"]))
	GameState.company.collect(Loot.roll(GameState.combat_rng(_depth + 1), summary, _depth))
	_depth += 1
	GameState.save()
	_build_squad_picker()
	visible = true


# --- Plomberie commune -----------------------------------------------------

func _launch(map_id: StringName, units: Array[Unit], rng: CombatRng, on_done: Callable) -> void:
	var packed: PackedScene = load(COMBAT_SCENE)
	if packed == null:
		return
	var scene: Node2D = packed.instantiate()
	scene.map_id = map_id
	scene.configure(map_id, units, rng)
	scene.combat_finished.connect(func(_victory: bool) -> void:
		# On laisse la bannière de résultat à l'écran, puis on rend la main.
		await get_tree().create_timer(2.5).timeout
		on_done.call(scene)
		if is_instance_valid(scene):
			scene.queue_free())
	get_tree().root.add_child(scene)
	visible = false
	if is_instance_valid(_expedition_screen):
		_expedition_screen.visible = false


func _open(path: String, setup: Callable) -> Control:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var screen: Control = packed.instantiate()
	setup.call(screen)
	get_tree().root.add_child(screen)
	visible = false
	return screen


func _dismiss(screen: Node) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
