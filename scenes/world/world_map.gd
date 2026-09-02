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

## Hauteur d'une rangée de région, et côté de son carré de terre.
const ROW_HEIGHT_PX := 84
const SWATCH_PX := 56
const SQUAD_CARD_PX := 250
const SQUAD_CARD_HEIGHT_PX := 112

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
	_lay_backdrop()
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


## Une région : son carré de terre, son nom, son état.
##
## SIX RANGÉES IDENTIQUES NE FONT PAS UNE CARTE, elles font une liste —
## et c'est exactement ce que la carte du monde était : six boîtes brunes
## portant six noms. Chaque région a maintenant SA couleur, qui teinte à
## la fois son carré d'herbe et le liseré de sa rangée. On reconnaît les
## Dunes Ardentes sans lire leur nom, ce qui est la seule chose qu'une
## carte doit savoir faire.
##
## UN BOUTON, PAS UN PANNEAU, malgré les apparences : la rangée se
## clique, donc elle doit être un `Button`. Le décor est posé DEDANS, en
## `MOUSE_FILTER_IGNORE`, sinon le carré d'herbe avale le clic.
func _region_row(region_id: StringName) -> Button:
	var open := Region.is_unlocked(region_id)
	var accent := Region.accent_of(region_id)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, ROW_HEIGHT_PX)
	button.toggle_mode = true
	button.button_pressed = region_id == _selected
	# Une région verrouillée reste LISIBLE et cliquable : le joueur a le
	# droit de lire ce qui l'attend. Elle ne peut simplement pas être
	# choisie pour partir, et le bouton du bas le dit.
	button.disabled = false
	UiSkin.dress_button(button, accent if open else &"muted")
	button.pressed.connect(func() -> void:
		_selected = region_id
		refresh())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.metric(&"card_margin"))
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UiTheme.metric(&"card_margin")
	row.offset_right = -UiTheme.metric(&"card_margin")
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var swatch := TextureRect.new()
	swatch.texture = UiSkin.terrain_swatch(UiTheme.color(accent), SWATCH_PX)
	swatch.custom_minimum_size = Vector2(SWATCH_PX, SWATCH_PX)
	swatch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	swatch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# UNE RÉGION VERROUILLÉE EST ÉTEINTE, pas cachée : on voit qu'il y a
	# une terre là-bas, on ne sait pas encore de quelle couleur elle est.
	swatch.modulate = Color(1, 1, 1, 1.0 if open else 0.35)
	row.add_child(swatch)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)

	var name_ := Label.new()
	name_.text = tr(Region.name_key(region_id))
	name_.add_theme_font_size_override("font_size", UiTheme.font_size(&"subheading"))
	name_.add_theme_color_override(
		"font_color", UiTheme.color(accent) if open else UiTheme.color(&"ink_muted")
	)
	name_.add_theme_constant_override("outline_size", 0)
	name_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_)

	var state := Label.new()
	state.text = (
		tr("WORLD_ACT") % Region.act_of(region_id) if open else tr("WORLD_LOCKED")
	)
	state.add_theme_font_size_override("font_size", UiTheme.font_size(&"small"))
	state.add_theme_color_override("font_color", UiTheme.color(&"ink_soft"))
	state.add_theme_constant_override("outline_size", 0)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(state)
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
		# LE MÊME VISAGE QU'AILLEURS, mais SANS JAUGE : au départ tout le
		# monde est au complet, et une barre pleine sur quatre héros ne
		# dit rien. Ici ce qui compte est qui part, pas dans quel état.
		# Cet écran affichait ses héros en
		# texte nu quand le combat, l'expédition et la compagnie leur
		# donnaient déjà un portrait : trois dessins pour une même
		# information est ce qui donne à un jeu son air de brouillon
		# (T9.7), et n'en donner aucun est pire.
		var button := Button.new()
		# HAUTEUR IMPOSÉE : un `HBoxContainer` prend la hauteur minimale de
		# ses enfants, et une carte de héros posée en ancrage plein n'en
		# déclare aucune. Sans ça, la rangée se rabote et les portraits
		# sortent par le bas.
		button.custom_minimum_size = Vector2(SQUAD_CARD_PX, SQUAD_CARD_HEIGHT_PX)
		button.pressed.connect(_cycle.bind(slot))
		UiSkin.dress_button(button, &"default")
		var card := UiSkin.hero_card(
			UiSkin.portrait(hero.class_id, hero.color),
			"%s · %s" % [
				hero.display_name(),
				tr("CLASS_%s" % String(hero.class_id).to_upper()),
			],
			0, 0, false, tr("COMPANY_LEVEL") % hero.level,
			Unit.class_accent(hero.class_id)
		)
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(card)
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


## Le motif de fond, posé DERRIÈRE tout le reste. Un aplat noir est fade :
## rien n'y accroche la lumière et les panneaux flottent sur du vide.
func _lay_backdrop() -> void:
	UiSkin.lay_backdrop(self)
