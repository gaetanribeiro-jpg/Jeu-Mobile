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
## C'EST UNE CARTE DEPUIS T12.11, et le nom mentait avant. L'écran empilait
## six BOÎTES rectangulaires portant chacune un carré de terre : rien n'y
## disait où sont les Dunes par rapport aux Terres Vertes, ni que l'Empire
## est au bout du monde — donc le § 27, « le joueur découvre », n'avait
## rien à découvrir. `world_map_view` dessine la mer, les terres et la
## route des six actes ; cet écran garde ce qu'il faisait déjà, la fiche et
## la composition de l'équipe.
##
## L'ÉQUIPE SE COMPOSE ICI ET PAS DANS L'EXPÉDITION. Une fois partie, elle
## ne change plus : c'est ce qui fait de sa composition une décision, et
## d'une déroute une conséquence de cette décision-là.

## Le joueur part. L'appelant fabrique l'expédition et bascule d'écran.
signal departed(region_id: StringName, squad_ids: Array)

signal closed

const SQUAD_CARD_PX := 250
const SQUAD_CARD_HEIGHT_PX := 112

var _company: Company
var _campaign := Campaign.new()
var _selected: StringName = &""
var _squad_ids: Array[int] = []

## Le royaume qui accompagne l'équipe (§ 43). Peut être nul.
var _kingdom: Kingdom = null

@onready var _title: Label = %Title
@onready var _gold: Label = %Gold
@onready var _back: Button = %Back
@onready var _atlas: Control = %Atlas
@onready var _atlas_frame: PanelContainer = %AtlasFrame
@onready var _brief: VBoxContainer = %Brief
@onready var _brief_frame: PanelContainer = %BriefFrame
@onready var _squad: HBoxContainer = %Squad
@onready var _depart: Button = %Depart


func _ready() -> void:
	theme = UiSkin.theme
	_lay_backdrop()
	UiSkin.dress_scrolls(self)
	_title.text = tr("WORLD_TITLE")
	_back.text = tr("COMBAT_BACK")
	_back.pressed.connect(func() -> void: closed.emit())
	_depart.pressed.connect(_on_depart)
	_atlas.picked.connect(_on_region_picked)
	_atlas_frame.add_theme_stylebox_override("panel", UiSkin.framed_style(&"panel"))
	refresh()


func _on_region_picked(region_id: StringName) -> void:
	_selected = region_id
	refresh()


## À appeler avant d'ajouter la scène à l'arbre.
## `campaign` dit ce qui est OUVERT aujourd'hui. Sans lui, l'écran lisait
## `regions.json`, qui ne dit que l'état d'une partie neuve : battre le
## boss de l'acte 1 n'ouvrait rien.
## `kingdom` est OPTIONNEL : l'écran reste lisible sans royaume — en test,
## et le jour où on l'ouvre d'ailleurs. Sans lui, il ne montre simplement
## pas ce que le royaume envoie.
func configure(
	company: Company, campaign: Campaign = null, kingdom: Kingdom = null
) -> void:
	_company = company
	_kingdom = kingdom
	if campaign != null:
		_campaign = campaign
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
		var open := _campaign.open_ids()
		_selected = open[0] if not open.is_empty() else Region.ids()[0]
	# LE FOND PREND L'AIR DE LA RÉGION DÉSIGNÉE (T11.9). C'est le seul écran
	# où l'on compare six régions : le fond qui vire en même temps que la
	# fiche dit « voilà à quoi ça ressemblera » avant d'y aller.
	UiSkin.lay_backdrop(self, Region.accent_of(_selected))
	# APRÈS `lay_backdrop`, ET PAS DANS `_ready` : c'est elle qui pose l'air
	# de l'écran, et le cadre le lit au moment où on le fabrique. Habillé
	# dans `_ready`, il gardait l'or neutre quelle que soit la région — la
	# mécanique était branchée et ne se voyait pas.
	#
	# La fiche de région flottait sur le fond, seule de son espèce : les
	# régions à gauche portent leur cadre, l'équipe en bas aussi.
	_brief_frame.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_panel", &"panel_fill", &"panel_edge_soft"
	))
	_gold.text = tr("COMPANY_GOLD") % _company.gold
	_build_regions()
	_build_brief()
	_build_squad()

	_depart.text = tr("WORLD_DEPART") % tr(Region.name_key(_selected))
	_depart.disabled = not _campaign.is_open(_selected) or _squad_ids.is_empty()


# --- Les régions -----------------------------------------------------------

## LA CARTE EST DESSINÉE, PAS EMPILÉE (T12.11). Six rangées identiques ne
## font pas une carte, elles font une liste — et c'est exactement ce que
## cet écran était. La vue reçoit la campagne (qui est ouvert), le royaume
## (le crédit des voisines, qui décide de leur couleur) et la région
## choisie ; elle rend un clic.
func _build_regions() -> void:
	_atlas.campaign = _campaign
	_atlas.kingdom = _kingdom
	_atlas.selected = _selected
	_atlas.refresh()


func _build_brief() -> void:
	for child in _brief.get_children():
		child.queue_free()

	_line(tr(Region.name_key(_selected)), 28)
	_line(tr(Region.description_key(_selected)), 20)

	if not _campaign.is_open(_selected):
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
	_build_kingdom_gifts()


## CE QUE LE ROYAUME ENVOIE AVEC L'ÉQUIPE, écrit au moment où l'on part.
##
## LE § 43 EST LA RAISON : « le joueur n'est jamais uniquement un
## gestionnaire, uniquement un héros RPG, uniquement un commandant — il
## est les trois, et CHAQUE ACTIVITÉ INFLUENCE LES AUTRES ». Le royaume
## influençait déjà l'expédition — soin entre les étapes, modificateurs
## par classe, fioles brassées — mais INVISIBLEMENT : ces chiffres
## s'appliquaient dans le moteur sans jamais s'afficher, donc bâtir un
## monastère ne se voyait nulle part au moment où l'on en profite.
##
## Une influence qu'on ne voit pas ne relie rien. C'est la même règle que
## partout ailleurs : la défense du royaume se lit avant de partir, le
## caractère d'un candidat se lit avant de l'engager, le télégraphe se lit
## avant de valider.
func _build_kingdom_gifts() -> void:
	if _kingdom == null:
		return
	var gifts := PackedStringArray()

	var healing := _kingdom.healing_between_steps()
	if healing > 0.0:
		gifts.append(tr("WORLD_GIFT_HEALING") % (healing * 100.0))

	# Les modificateurs sont PAR CLASSE, et on ne montre que ceux des
	# classes qui PARTENT : lire le bonus d'un Mage resté au royaume
	# donnerait un chiffre qu'on ne touchera pas.
	var classes := {}
	for hero_id: Variant in _squad_ids:
		var hero := _company.hero_by_id(int(hero_id))
		if hero != null:
			classes[hero.class_id] = true
	for class_id: StringName in classes.keys():
		var bonuses := _kingdom.hero_bonuses(class_id)
		if bonuses.is_empty():
			continue
		var pieces := PackedStringArray()
		for key: Variant in bonuses.keys():
			pieces.append("%s %+d" % [
				tr("STAT_%s" % String(key).to_upper()), int(bonuses[key])
			])
		gifts.append("%s : %s" % [
			tr("CLASS_%s" % String(class_id).to_upper()), ", ".join(pieces)
		])

	if gifts.is_empty():
		_line(tr("WORLD_GIFT_NONE"), 19)
		return
	_line(tr("WORLD_GIFTS"), 20)
	for gift: String in gifts:
		_line("  " + gift, 19)


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
	if not _campaign.is_open(_selected) or _squad_ids.is_empty():
		return
	departed.emit(_selected, _squad_ids.duplicate())


## Le motif de fond, posé DERRIÈRE tout le reste. Un aplat noir est fade :
## rien n'y accroche la lumière et les panneaux flottent sur du vide.
func _lay_backdrop() -> void:
	UiSkin.lay_backdrop(self)
