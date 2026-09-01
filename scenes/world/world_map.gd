extends Control

## La carte du monde (T3.6) : où l'on va, et avec qui.
##
## Le § 28 met trois décisions AVANT le départ — « destination, équipe,
## équipement, objectif » — et c'est l'écran qui les pose. Il n'y en a
## qu'une de vraie au MVP, l'équipe, puisqu'une seule région est ouverte ;
## les cinq autres sont là pour qu'on voie où l'on ira, ce qui est le § 27
## en une ligne : « le joueur découvre ».
##
## POURQUOI MONTRER CE QU'ON NE PEUT PAS FAIRE. Une carte qui n'afficherait
## que les Terres Vertes ne serait pas une carte du monde, ce serait un
## bouton. Le verrou dit qu'il y a une suite, et c'est gratuit : les cinq
## régions verrouillées n'ont qu'un nom et une ligne.
##
## L'ÉQUIPE SE COMPOSE ICI ET PAS DANS L'EXPÉDITION. Une fois partie, elle
## ne change plus : c'est ce qui fait de sa composition une décision, et
## d'une déroute une conséquence de cette décision-là.

## Le joueur part. L'appelant fabrique l'expédition et bascule d'écran.
signal departed(region_id: StringName, squad_ids: Array)

signal closed

var _company: Company
var _selected: StringName = &""
var _squad_ids: Array[int] = []

@onready var _title: Label = %Title
@onready var _gold: Label = %Gold
@onready var _back: Button = %Back
@onready var _regions: VBoxContainer = %Regions
@onready var _brief: VBoxContainer = %Brief
@onready var _squad: HBoxContainer = %Squad
@onready var _depart: Button = %Depart


func _ready() -> void:
	theme = UiSkin.theme
	_title.text = tr("WORLD_TITLE")
	_back.text = tr("COMBAT_BACK")
	_back.pressed.connect(func() -> void: closed.emit())
	_depart.pressed.connect(_on_depart)
	refresh()


## À appeler avant d'ajouter la scène à l'arbre.
func configure(company: Company) -> void:
	_company = company
	_reset_squad()


func selected_region() -> StringName:
	return _selected


func squad_ids() -> Array[int]:
	return _squad_ids.duplicate()


func _reset_squad() -> void:
	_squad_ids.clear()
	for hero: Hero in _company.heroes:
		if _squad_ids.size() < CombatRules.team_size():
			_squad_ids.append(hero.id)


func refresh() -> void:
	if _company == null or not is_node_ready():
		return
	if _selected.is_empty():
		var open := Region.unlocked_ids()
		_selected = open[0] if not open.is_empty() else Region.ids()[0]
	_gold.text = tr("COMPANY_GOLD") % _company.gold
	_build_regions()
	_build_brief()
	_build_squad()

	_depart.text = tr("WORLD_DEPART") % tr(Region.name_key(_selected))
	_depart.disabled = not Region.is_unlocked(_selected) or _squad_ids.is_empty()


# --- Les régions -----------------------------------------------------------

func _build_regions() -> void:
	for child in _regions.get_children():
		child.queue_free()
	for region_id: StringName in Region.ids():
		_regions.add_child(_region_row(region_id))


func _region_row(region_id: StringName) -> Button:
	var open := Region.is_unlocked(region_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 72)
	button.toggle_mode = true
	button.button_pressed = region_id == _selected
	# Une région verrouillée reste LISIBLE et cliquable : le joueur a le
	# droit de lire ce qui l'attend. Elle ne peut simplement pas être
	# choisie pour partir, et le bouton du bas le dit.
	button.disabled = false
	button.add_theme_font_size_override("font_size", 24)
	button.text = "%s   ·   %s" % [
		tr(Region.name_key(region_id)),
		tr("WORLD_ACT") % Region.act_of(region_id) if open else tr("WORLD_LOCKED"),
	]
	if not open:
		button.add_theme_color_override("font_color", UiTheme.color(&"ink_muted"))
	button.pressed.connect(func() -> void:
		_selected = region_id
		refresh())
	return button


func _build_brief() -> void:
	for child in _brief.get_children():
		child.queue_free()

	_line(tr(Region.name_key(_selected)), 28)
	_line(tr(Region.description_key(_selected)), 20)

	if not Region.is_unlocked(_selected):
		_line(tr("WORLD_LOCKED_TEXT"), 20)
		return

	# Ce que le joueur a besoin de savoir avant de dire oui : la longueur
	# de la sortie, et qu'elle finit sur un boss. Le reste se découvre.
	var chain: Dictionary = Region.chain(_selected)
	var body: Dictionary = chain.get("body", {})
	var tail := Region.chain_tail(_selected).size()
	_line(tr("WORLD_LENGTH") % [
		int(body.get("min", 0)) + tail, int(body.get("max", 0)) + tail
	], 20)
	_line(tr("WORLD_ENDS_ON_BOSS"), 20)
	_line(tr("WORLD_NO_HEALING"), 20)


func _line(text: String, size: int) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.text = text
	_brief.add_child(label)


# --- L'équipe --------------------------------------------------------------

func _build_squad() -> void:
	for child in _squad.get_children():
		child.queue_free()

	var header := Label.new()
	header.add_theme_font_size_override("font_size", 22)
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.text = tr("WORLD_SQUAD")
	_squad.add_child(header)

	for slot in _squad_ids.size():
		var hero := _company.hero_by_id(_squad_ids[slot])
		if hero == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(240, 68)
		button.add_theme_font_size_override("font_size", 20)
		button.text = "%s\n%s · %s" % [
			hero.display_name(),
			tr("CLASS_%s" % String(hero.class_id).to_upper()),
			tr("COMPANY_LEVEL") % hero.level,
		]
		button.pressed.connect(_cycle.bind(slot))
		_squad.add_child(button)


## Fait défiler les héros de la compagnie sur cet emplacement, en sautant
## ceux qui sont déjà pris ailleurs.
func _cycle(slot: int) -> void:
	var all_heroes := _company.heroes
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
	refresh()


func _on_depart() -> void:
	if not Region.is_unlocked(_selected) or _squad_ids.is_empty():
		return
	departed.emit(_selected, _squad_ids.duplicate())
