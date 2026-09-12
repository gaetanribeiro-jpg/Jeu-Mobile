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

## La ville à qui l'on achète un milicien pour cette sortie (T12.12), ou
## vide. Un seul : le jeton ne sert qu'une fois et ne s'accumule pas.
var _ally_town: StringName = &""

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
	# L'ACTION PASSE DEVANT L'INFORMATION. Les cadeaux du royaume se
	# LISENT ; le renfort se DÉCIDE, et il se décidait sous la ligne de
	# flottaison du panneau — seule la capture le disait.
	_build_muster()
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
## LE RENFORT S'ACHÈTE AVANT DE PARTIR, ET IL SE DÉPENSE EN ROUTE (T12.12).
##
## Ici, c'est l'ACHAT : une ville assez cordiale accepte d'envoyer un bras
## contre de l'or. Le choix de la rencontre où il se battra se pose plus
## tard, sur la route — c'est là qu'est la décision, et elle ne vaut que si
## l'on sait déjà ce qu'on a en poche au moment de partir.
##
## UNE VILLE QUI REFUSE RESTE AFFICHÉE, grisée, avec ce qui manque : savoir
## ce qu'on ne peut pas s'offrir fait partie de la décision. Même règle que
## l'étal du marchand et que les options du conseil.
func _build_muster() -> void:
	if _kingdom == null or _company == null:
		return
	var offers: Array[StringName] = []
	for town_id: StringName in Neighbour.ids():
		if Neighbour.musters(town_id):
			offers.append(town_id)
	if offers.is_empty():
		return

	_line(tr("WORLD_MUSTER"), 20)
	for town_id: StringName in offers:
		var cost := Neighbour.muster_cost(town_id)
		var friendly := _kingdom.standing_of(town_id) >= Neighbour.muster_standing(town_id)
		var affordable := _kingdom.can_afford(cost, _company)
		var label := tr("WORLD_MUSTER_CALL") % [
			tr(Neighbour.name_key(town_id)), _price(cost)
		]
		if _ally_town == town_id:
			label = tr("WORLD_MUSTER_READY") % tr(Neighbour.name_key(town_id))
		elif not friendly:
			label = tr("WORLD_MUSTER_COLD") % [
				tr(Neighbour.name_key(town_id)),
				tr(Neighbour.standing_key(Neighbour.muster_standing(town_id))),
			]
		elif not affordable:
			label = tr("WORLD_MUSTER_COST") % [tr(Neighbour.name_key(town_id)), _price(cost)]
		var button := _action(label, _hire_militia.bind(town_id),
			friendly and (affordable or _ally_town == town_id))
		button.set_pressed_no_signal(_ally_town == town_id)


## ON NE PAIE QU'AU DÉPART, et c'est ce qui rend le geste réversible. Une
## dépense encaissée sur un écran de préparation — avant même de savoir où
## l'on va, et qu'on peut quitter par « Retour » — serait de l'or perdu
## sans contrepartie. Le bouton retient une INTENTION ; `_on_depart` paie.
func _hire_militia(town_id: StringName) -> void:
	_ally_town = &"" if _ally_town == town_id else town_id
	refresh()


## Un bouton d'action du panneau de droite.
func _action(text: String, handler: Callable, enabled: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 54)
	button.add_theme_font_size_override("font_size", 19)
	button.clip_text = true
	button.toggle_mode = true
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(handler)
	_brief.add_child(button)
	return button


func _price(cost: Dictionary) -> String:
	var pieces := PackedStringArray()
	for key: Variant in cost.keys():
		pieces.append("%s %d" % [tr(ResourceTable.name_key(StringName(key))), int(cost[key])])
	return ", ".join(pieces)


## La ville dont le milicien part avec l'expédition, ou vide.
func ally_town() -> StringName:
	return _ally_town


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
	# LE MILICIEN SE PAIE ICI, pas au clic : le joueur peut changer d'avis
	# et quitter l'écran sans avoir rien dépensé. Si la bourse ne suit
	# plus, on part SANS lui plutôt que de refuser le départ — le renfort
	# est un bonus, pas une condition.
	if not _ally_town.is_empty():
		if _kingdom == null or not _kingdom.pay(
				Neighbour.muster_cost(_ally_town), _company):
			_ally_town = &""
	departed.emit(_selected, _squad_ids.duplicate())


## Le motif de fond, posé DERRIÈRE tout le reste. Un aplat noir est fade :
## rien n'y accroche la lumière et les panneaux flottent sur du vide.
func _lay_backdrop() -> void:
	UiSkin.lay_backdrop(self)
