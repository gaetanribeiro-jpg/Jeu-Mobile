extends Control

## Écran d'amorçage — et, pour l'instant, lanceur de combats.
##
## LA BOUCLE PASSE PAR ICI. Ce n'est plus un banc d'essai : l'écran part de
## la VRAIE compagnie sauvegardée, envoie ses héros au combat avec leurs
## niveaux et leur équipement, et lui rend l'expérience et le butin au
## retour. C'est le plus court chemin complet de la boucle du § 3 —
## héros → combat → récompense → héros — et il tourne.
##
## PROVISOIRE quand même : le vrai menu principal, le royaume et la carte
## du monde viendront le remplacer. Ce qui n'est pas provisoire est le
## chaînage : combat → CombatRewards → Loot → Company → sauvegarde.

const COMBAT_SCENE := "res://scenes/combat/combat_scene.tscn"
const COMPANY_SCENE := "res://scenes/ui/company_screen.tscn"

## Identifiants des héros emmenés, dans l'ordre des emplacements.
var _squad_ids: Array[int] = []

## Combats déjà enchaînés. Nourrit la profondeur du butin (§ 29) — c'est
## l'amorce de l'expédition, que la Phase 3 reprendra.
var _depth: int = 0

var _company_screen: Control = null

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


## Un bouton par emplacement, qui fait défiler les héros de la compagnie.
## Provisoire, mais sans lui on jouerait toujours la même équipe.
func _build_squad_picker() -> void:
	for child in _squad.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = tr("BOOT_SQUAD")
	header.add_theme_font_size_override("font_size", 22)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_squad.add_child(header)

	var centre := CenterContainer.new()
	_squad.add_child(centre)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	centre.add_child(row)

	for slot in _squad_ids.size():
		var hero := GameState.company.hero_by_id(_squad_ids[slot])
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 76)
		button.add_theme_font_size_override("font_size", 20)
		button.text = "%d  %s\n%s · %s" % [
			slot + 1, hero.display_name(),
			tr("CLASS_%s" % String(hero.class_id).to_upper()),
			tr("COMPANY_LEVEL") % hero.level,
		]
		button.pressed.connect(_cycle_hero.bind(slot))
		row.add_child(button)

	var company := Button.new()
	company.custom_minimum_size = Vector2(200, 76)
	company.add_theme_font_size_override("font_size", 22)
	company.text = tr("BOOT_COMPANY")
	company.pressed.connect(_open_company)
	row.add_child(company)


## Fait défiler les héros de la compagnie sur cet emplacement, en sautant
## ceux qui sont déjà pris ailleurs.
func _cycle_hero(slot: int) -> void:
	var all_heroes := GameState.company.heroes
	if all_heroes.size() <= 1:
		return
	var index := 0
	for i in all_heroes.size():
		if all_heroes[i].id == _squad_ids[slot]:
			index = i
			break
	for step in range(1, all_heroes.size() + 1):
		var candidate: int = all_heroes[(index + step) % all_heroes.size()].id
		if not _squad_ids.has(candidate) or candidate == _squad_ids[slot]:
			_squad_ids[slot] = candidate
			break
	_build_squad_picker()


func _open_company() -> void:
	var packed: PackedScene = load(COMPANY_SCENE)
	if packed == null:
		return
	_company_screen = packed.instantiate()
	_company_screen.configure(GameState.company)
	_company_screen.closed.connect(_close_company)
	_company_screen.changed.connect(GameState.save)
	get_tree().root.add_child(_company_screen)
	visible = false


func _close_company() -> void:
	if is_instance_valid(_company_screen):
		_company_screen.queue_free()
	_company_screen = null
	_reset_squad()
	_build_squad_picker()
	visible = true


func _build_map_list() -> void:
	for child in _maps.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = tr("BOOT_PICK_MAP")
	header.add_theme_font_size_override("font_size", 26)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_maps.add_child(header)

	# Un GridContainer prend sa taille minimale et se cale à gauche : sans
	# CenterContainer autour, la première colonne sort de l'écran.
	var centre := CenterContainer.new()
	_maps.add_child(centre)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	centre.add_child(grid)

	for map_id: StringName in CombatMap.map_ids():
		var map := CombatMap.load_map(map_id)
		var button := Button.new()
		button.text = tr(map.name_key) if map != null else String(map_id)
		button.custom_minimum_size = Vector2(260, 88)
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(_start.bind(map_id))
		grid.add_child(button)


func _start(map_id: StringName) -> void:
	var packed: PackedScene = load(COMBAT_SCENE)
	if packed == null:
		return
	var squad := GameState.company.squad(_squad_ids)
	if squad.is_empty():
		return
	var scene: Node2D = packed.instantiate()
	scene.map_id = map_id
	scene.configure(
		map_id, GameState.company.to_units(squad), GameState.combat_rng(_depth)
	)
	scene.combat_finished.connect(_on_combat_finished.bind(scene))
	get_tree().root.add_child(scene)
	visible = false


## La boucle se referme ici : le combat rend son compte, la compagnie
## encaisse, et tout part sur le disque avant que le joueur ne puisse
## toucher à quoi que ce soit.
func _on_combat_finished(_victory: bool, scene: Node) -> void:
	if is_instance_valid(scene):
		_collect(scene.engine)
	# On laisse la bannière de résultat à l'écran, puis on rend la main.
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(scene):
		scene.queue_free()
	_build_squad_picker()
	visible = true


func _collect(engine: CombatEngine) -> void:
	var summary := CombatRewards.summarise(engine)
	if summary.is_empty():
		return
	CombatRewards.award_to(GameState.company.squad(_squad_ids), int(summary["experience"]))
	GameState.company.collect(Loot.roll(GameState.combat_rng(_depth + 1), summary, _depth))
	_depth += 1
	GameState.save()
