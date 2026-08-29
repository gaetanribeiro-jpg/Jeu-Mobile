extends Control

## Écran d'amorçage — et, pour l'instant, lanceur de combats.
##
## Le Jalon 0 demandait un écran noir affichant « Reconquête ». Il est là,
## mais seul il ne se teste qu'une fois. Comme le Jalon 1 demande de jouer
## le combat vingt fois avant de continuer, cet écran liste les huit
## cartes : on relance sans reconstruire l'APK.
##
## PROVISOIRE. Le vrai menu principal est la tâche A9.1, et il n'aura rien
## à voir avec celui-ci.

const COMBAT_SCENE := "res://scenes/combat/combat_scene.tscn"

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _maps: VBoxContainer = %Maps


func _ready() -> void:
	_title.text = tr("GAME_TITLE")
	_subtitle.text = tr("BOOT_TEMPORARY")
	_build_map_list()


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
	var scene: Node2D = packed.instantiate()
	scene.map_id = map_id
	scene.combat_finished.connect(_on_combat_finished.bind(scene))
	get_tree().root.add_child(scene)
	visible = false


func _on_combat_finished(_victory: bool, scene: Node) -> void:
	# On laisse la bannière de résultat à l'écran, puis on rend la main.
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(scene):
		scene.queue_free()
	visible = true
