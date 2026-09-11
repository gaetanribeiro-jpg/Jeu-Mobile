extends Control

## L'écran du royaume (T4.3).
##
## LE TERRAIN À GAUCHE, LA DÉCISION À DROITE. Le § 5 fait de l'évolution
## visuelle une exigence : il fallait donc que le royaume se VOIE, et pas
## seulement se lise dans un tableau. Mais un royaume qu'on voit sans
## pouvoir agir dessus est un fond d'écran ; le panneau de droite est la
## moitié qui décide.
##
## DEUX DÉCISIONS, ET DEUX SEULEMENT :
##   bâtir      dépenser maintenant, ou garder pour la prochaine sortie
##   affecter   quelle ressource manque le plus, ce cycle-ci
##
## Elles se disputent la même bourse et les mêmes bras, et c'est ce qui
## les rend intéressantes. Tout le reste de l'écran est là pour les
## éclairer : les réserves en haut, les bras libres sous elles, et le
## coût du prochain niveau écrit en toutes lettres.
##
## L'ÉCRAN NE SAUVEGARDE PAS. Il émet `changed`, l'appelant décide — même
## frontière que la compagnie et l'expédition.

signal closed
signal changed

var _kingdom: Kingdom
var _company: Company

## Le générateur de la partie, pour le nom du prochain recruté. Sans lui,
## deux parties de même graine ne nommeraient pas les mêmes héros.
var _rng: CombatRng

@onready var _title: Label = %Title
@onready var _stores: HBoxContainer = %Stores
@onready var _back: Button = %Back
@onready var _view: Control = %View
@onready var _header_frame: PanelContainer = %HeaderFrame
@onready var _view_frame: PanelContainer = %ViewFrame
@onready var _panel_frame: PanelContainer = %PanelFrame
@onready var _panel: VBoxContainer = %Panel
@onready var _journal: Label = %Journal


func _ready() -> void:
	theme = UiSkin.theme
	_lay_backdrop()
	_dress_frames()
	UiSkin.dress_scrolls(self)
	_back.text = tr("COMBAT_BACK")
	_back.pressed.connect(func() -> void: closed.emit())
	_view.picked.connect(_on_picked)
	refresh()


## À appeler avant d'ajouter la scène à l'arbre.
func configure(kingdom: Kingdom, company: Company, rng: CombatRng) -> void:
	_kingdom = kingdom
	_company = company
	_rng = rng


func refresh() -> void:
	if _kingdom == null or not is_node_ready():
		return
	_view.kingdom = _kingdom
	_view.refresh()
	_title.text = tr("KINGDOM_TITLE")
	_build_stores()
	_build_panel()


# --- Les réserves ----------------------------------------------------------

func _build_stores() -> void:
	for child in _stores.get_children():
		child.queue_free()
	for resource_id: StringName in ResourceTable.ids():
		_stores.add_child(_store_entry(
			ResourceTable.asset_of(resource_id),
			tr(ResourceTable.name_key(resource_id)),
			str(_kingdom.amount(resource_id, _company))
		))
	# Les bras libres sont une ressource comme les autres, et la plus
	# facile à oublier — sauf qu'ils ne sont plus OISIFS : ceux qu'on ne
	# met pas sur un chantier montent la garde, et valent quatre fois un
	# ouvrier contre un assaut.
	_stores.add_child(_store_entry(
		"",
		tr("KINGDOM_PEOPLE"),
		"%d / %d  (%d %s)" % [
			_kingdom.population, _kingdom.population_cap(),
			_kingdom.garrison(), tr("KINGDOM_ON_WATCH")
		]
	))
	# LA DÉFENSE SE LIT AVANT DE PARTIR, sinon retirer un bras d'un
	# chantier est un pari. Le § 39 veut l'information parfaite au combat ;
	# le royaume la doit aussi, puisqu'on lui demande un arbitrage chiffré
	# entre produire et tenir.
	# ELLE ROUGIT QUAND ELLE NE SUFFIT PAS. Deux chiffres côte à côte se
	# comparent, mais pas d'un coup d'œil — et c'est un coup d'œil qu'on
	# donne à une barre d'en-tête. Le rouge est le rôle `danger` de la
	# palette, celui des boutons qui refusent.
	_stores.add_child(_store_entry(
		"", tr("KINGDOM_DEFENCE"), _defence_text(),
		&"" if _kingdom.holds_alone() else &"rust"
	))


## La défense du royaume, et l'assaut qu'elle affronterait s'il est
## déclaré. Deux chiffres côte à côte : un seul ne dirait pas s'il suffit.
func _defence_text() -> String:
	var defence := _kingdom.defence_strength()
	# L'assaut DÉCLARÉ s'il y en a un, celui que le royaume ATTIRE sinon.
	# La menace retombe au retour : il n'y a donc presque jamais
	# d'invasion en cours au moment où l'on compose la garde, et n'afficher
	# que celle-là laisserait le joueur décider à l'aveugle.
	var assault := (
		_kingdom.invasion.strength if _kingdom.invasion != null
		else _kingdom.expected_assault()
	)
	return tr("KINGDOM_DEFENCE_VS") % [defence, assault]


## Une réserve : son icône, puis son compte.
##
## LE TAS DE BOIS DIT « BOIS » MIEUX QUE LE MOT, et sur un téléphone la
## barre se lit d'un coup d'œil au lieu de se lire mot à mot. Le nom reste
## quand même : quatre icônes de 64 réduites à la hauteur d'une ligne se
## ressemblent trop pour porter seules l'information (règle de T11.6 — la
## couleur, ou ici l'image, AJOUTE une lecture, elle n'en remplace pas
## une).
##
## Sans référence — les habitants n'en ont pas —, on rend le texte seul.
func _store_entry(
	reference: String, name_: String, value: String, tint: StringName = &""
) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var side := UiTheme.metric(&"resource_icon")
	var icon := UiSkin.resource_icon(reference, side)
	if icon != null:
		var image := TextureRect.new()
		image.texture = icon
		image.custom_minimum_size = Vector2(side, side)
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	label.text = "%s %s" % [name_, value]
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not tint.is_empty() and UiTheme.has_color(tint):
		label.add_theme_color_override("font_color", UiTheme.color(tint))
	row.add_child(label)
	return row


# --- Le panneau ------------------------------------------------------------

func _build_panel() -> void:
	for child in _panel.get_children():
		child.queue_free()
	# Les noms de genre se lisent SUR LA VUE, jamais recopiés ici. Une
	# constante recopiée qui cesse d'être vraie ne casse rien : elle rend
	# simplement le panneau vide, sans un mot.
	match _view.selected_kind:
		_view.KIND_BUILDING:
			_build_building_panel(_view.selected_id)
		_view.KIND_WORKSITE:
			_build_worksite_panel(_view.selected_id)
		_:
			_line(tr("KINGDOM_PICK"), 22)


func _build_building_panel(building_id: StringName) -> void:
	if not Buildings.exists(building_id):
		return
	var level := _kingdom.level_of(building_id)
	_line(tr(Buildings.name_key(building_id)), 26)
	_line(tr("KINGDOM_LEVEL") % [level, Buildings.max_level(building_id)], 20)
	_line(tr(Buildings.description_key(building_id)), 19)

	if level > 0:
		_line(tr("KINGDOM_GRANTS_NOW") % _grants(Buildings.grants_up_to(building_id, level)), 19)

	var wanted := _kingdom.next_level(building_id)
	if wanted <= 0:
		_line(tr("KINGDOM_MAXED"), 20)
		return

	# Ce que le niveau suivant COÛTE et ce qu'il DONNE, côte à côte. Un
	# prix sans son gain ne demande pas de décider, il demande de payer.
	_line(tr("KINGDOM_NEXT") % [
		wanted, _costs(_kingdom.next_cost(building_id))
	], 20)
	_line(tr("KINGDOM_NEXT_GRANTS") % _grants(Buildings.grants_at(building_id, wanted)), 19)

	var reason := _kingdom.blocked_because(building_id, _company)
	var label := tr("KINGDOM_BUILD") if level > 0 else tr("KINGDOM_FOUND")
	# Un bouton grisé qui ne dit pas pourquoi est une impasse. Celui-ci
	# dit ce qui manque : de l'argent, ou un château plus haut.
	if reason == &"castle":
		label = tr("KINGDOM_NEEDS_CASTLE")
	elif reason == &"cost":
		label = tr("KINGDOM_NEEDS_RESOURCES")
	_action(label, _upgrade.bind(building_id), reason.is_empty())
	_recruit_buttons(building_id)
	_ascend_buttons(building_id)


## ÉLEVER UN HÉROS EST CE QUE LA TOUR PERMET, et c'est le premier bâtiment
## du jeu qui OUVRE quelque chose au lieu d'ajouter un chiffre. La règle du
## royaume demande à chaque bâtiment « qu'est-ce que ça permet à mes
## héros ? » ; les cinq premiers répondaient « +1 de force ».
##
## UN BOUTON PAR HÉROS, et les refusés restent AFFICHÉS avec leur raison.
## Cacher ce qui manque obligerait à deviner pourquoi un héros n'est pas
## élevable — c'est la même promesse que le télégraphe fait au combat :
## information parfaite, toujours.
func _ascend_buttons(building_id: StringName) -> void:
	if building_id != Ascension.BUILDING or _kingdom.level_of(building_id) <= 0:
		return
	if _company == null or _company.heroes.is_empty():
		return
	for hero: Hero in _company.heroes:
		var blocked := _kingdom.cannot_ascend_because(hero, _company)
		var target := Ascension.next_rank(hero.rank)
		var label := ""
		match blocked:
			Ascension.BLOCKED_MAXED:
				label = "%s — %s" % [hero.display_name(), tr("ASCENSION_MAXED")]
			Ascension.BLOCKED_LEVEL:
				label = "%s — %s" % [
					hero.display_name(),
					tr("ASCENSION_LEVEL") % Ascension.requires_level(target),
				]
			Ascension.BLOCKED_TOWER:
				label = "%s — %s" % [
					hero.display_name(),
					tr("ASCENSION_TOWER") % Ascension.requires_tower(target),
				]
			Ascension.BLOCKED_COST:
				label = "%s — %s" % [hero.display_name(), tr("ASCENSION_COST")]
			_:
				label = tr("ASCENSION_DO") % hero.display_name() + "\n" + _costs(
					Ascension.cost_of(target)
				)
		_action(label, _ascend.bind(hero), blocked.is_empty())


## Recruter est la seconde chose qu'un bâtiment militaire permet, et le
## § 45 la met dans cette phase. Les boutons n'apparaissent que là où
## quelqu'un se forme.
##
## TROIS CANDIDATS, PAS UN BOUTON. Le reproche était « un bâtiment = une
## classe = un héros générique » : avec un seul recruté possible, l'écran
## n'offrait pas une décision. Chacun porte son NOM et son CARACTÈRE, et
## aucun n'est meilleur — un trait rend exactement ce qu'il retire, donc
## la question posée est « de quoi mon équipe manque-t-elle ? ».
##
## LE PRIX EST DIT UNE FOIS, au-dessus des trois : il est le même pour
## tous, et le répéter trois fois donnerait à lire trois chiffres
## identiques au lieu des trois caractères qui, eux, diffèrent.
func _recruit_buttons(building_id: StringName) -> void:
	var taught := Buildings.recruits(building_id)
	if taught.is_empty() or _kingdom.level_of(building_id) <= 0:
		return
	var blocked := _kingdom.cannot_recruit_because(building_id, _company)
	# UN BÂTIMENT PEUT EN FORMER DEUX. L'en-tête les nomme toutes, séparées
	# par une barre : la caserne forme les gens d'armes, et le joueur doit
	# le savoir avant de lire les trois noms.
	var names := PackedStringArray()
	for class_id: StringName in taught:
		names.append(tr("CLASS_%s" % String(class_id).to_upper()))
	_line(tr("KINGDOM_RECRUIT") % [
		" · ".join(names), _costs(Buildings.recruit_cost(building_id)),
	], 20)
	if blocked == &"cost":
		_line(tr("KINGDOM_NEEDS_RESOURCES"), 19)
	var offered := _kingdom.candidates(building_id, _company, _rng)
	for i in offered.size():
		# Sur trois lignes quand le bâtiment forme plusieurs classes : qui
		# c'est, ce qu'il est, puis ce que son caractère change. La classe
		# ne se déduit plus du bâtiment, donc elle doit être écrite.
		var label := "%s\n%s" % [
			offered[i].display_name(), UiSkin.trait_line(offered[i].trait_id)
		]
		if taught.size() > 1:
			label = "%s — %s\n%s" % [
				offered[i].display_name(),
				tr("CLASS_%s" % String(offered[i].class_id).to_upper()),
				UiSkin.trait_line(offered[i].trait_id),
			]
		_action(label, _hire.bind(building_id, i), blocked.is_empty())


func _build_worksite_panel(worksite_id: StringName) -> void:
	if not Worksite.exists(worksite_id):
		return
	var hands := _kingdom.assigned_to(worksite_id)
	var slots := Worksite.slots_of(worksite_id)
	_line(tr(Worksite.name_key(worksite_id)), 26)
	_line(tr("KINGDOM_HANDS") % [hands, slots], 20)
	_line(tr("KINGDOM_YIELD") % [
		Worksite.per_cycle(worksite_id) * hands,
		tr(ResourceTable.name_key(Worksite.resource_of(worksite_id))),
		Worksite.per_cycle(worksite_id),
	], 19)

	# CE QU'UN BRAS VAUT DES DEUX CÔTÉS, écrit là où on le déplace. Retirer
	# un ouvrier coûte une production et rend une sentinelle ; sans les
	# deux chiffres, l'arbitrage se fait au doigt mouillé.
	_line(tr("KINGDOM_HAND_WORTH") % [
		Worksite.per_cycle(worksite_id),
		tr(ResourceTable.name_key(Worksite.resource_of(worksite_id))),
		Invasion.number(&"defence", &"per_garrison", 0.0)
			- Invasion.number(&"defence", &"per_worker", 0.0),
	], 19)

	_action(tr("KINGDOM_ASSIGN"), _assign.bind(worksite_id), _kingdom.can_assign(worksite_id))
	_action(tr("KINGDOM_UNASSIGN"), _unassign.bind(worksite_id), hands > 0)


func _line(text: String, size: int) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.text = text
	_panel.add_child(label)


## DEUX PIÈGES DE MISE EN PAGE, ET LE PREMIER FAIT TOMBER LE MOTEUR.
##
## 1. La barre de défilement VERTICALE d'un `ScrollContainer` qui
##    apparaît et disparaît selon la hauteur du contenu rétrécit ce
##    contenu quand elle apparaît. Un texte replié qui rétrécit devient
##    plus haut, donc rappelle la barre : la mise en page OSCILLE, empile
##    un redessin par tour, et en headless — où rien ne vide cette file —
##    Godot tombe sur un signal 11 en désignant `_redraw_callback` ou
##    `_update_minimum_size`, c'est-à-dire rien. La barre est donc
##    TOUJOURS visible dans la scène : sa présence ne dépend plus de rien.
##    Le panneau ne passait de six à sept enfants qu'avec le bouton de
##    recrutement, ce qui a fait accuser le bouton pendant un moment.
##
## 2. `clip_text` reste par précaution : un bouton dont le texte est plus
##    large que son conteneur renégocie sa largeur, et c'est la même
##    famille de boucle. Les libellés tiennent donc sur deux lignes
##    courtes plutôt que sur une longue.
func _action(text: String, handler: Callable, enabled: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 21)
	button.clip_text = true
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(handler)
	_panel.add_child(button)
	return button


# --- Agir ------------------------------------------------------------------

func _on_picked(kind: StringName, id: StringName) -> void:
	_view.selected_kind = kind
	_view.selected_id = id
	refresh()


func _upgrade(building_id: StringName) -> void:
	var reached := _kingdom.build(building_id, _company)
	if reached <= 0:
		return
	AudioManager.play_cue(&"build")
	_note(tr("KINGDOM_BUILT") % [tr(Buildings.name_key(building_id)), reached])
	changed.emit()
	refresh()


func _ascend(hero: Hero) -> void:
	var reached := _kingdom.ascend(hero, _company)
	if reached < 0:
		return
	AudioManager.play_cue(&"recruit")
	_note(tr("KINGDOM_ASCENDED") % [
		hero.display_name(), tr(Ascension.name_key_of(reached))
	])
	changed.emit()
	refresh()


func _hire(building_id: StringName, index: int) -> void:
	var hero := _kingdom.hire(building_id, index, _company, _rng)
	if hero == null:
		return
	AudioManager.play_cue(&"recruit")
	_note(tr("KINGDOM_RECRUITED") % [
		hero.display_name(), tr("CLASS_%s" % String(hero.class_id).to_upper())
	])
	changed.emit()
	refresh()


func _assign(worksite_id: StringName) -> void:
	if not _kingdom.assign(worksite_id):
		return
	changed.emit()
	refresh()


func _unassign(worksite_id: StringName) -> void:
	if not _kingdom.unassign(worksite_id):
		return
	changed.emit()
	refresh()


## Le compte rendu du dernier cycle, à afficher au retour d'une expédition.
func report_cycle(report: Dictionary) -> void:
	if report.is_empty():
		return
	var pieces := PackedStringArray()
	for key: Variant in (report.get("produced", {}) as Dictionary).keys():
		pieces.append("%s +%d" % [
			tr(ResourceTable.name_key(StringName(key))),
			int((report["produced"] as Dictionary)[key]),
		])
	# LA BRASSERIE SE DIT DANS LE COMPTE RENDU, sinon le troisième fil
	# d'obtention des potions serait invisible : le sac grossirait tout
	# seul et le joueur n'aurait aucune raison de monter le monastère.
	for key: Variant in (report.get("brewed", {}) as Dictionary).keys():
		pieces.append("%s +%d" % [
			tr(Consumable.name_key(StringName(key))),
			int((report["brewed"] as Dictionary)[key]),
		])
	pieces.append(tr("KINGDOM_EATEN") % int(report.get("eaten", 0)))
	if bool(report.get("arrived", false)):
		pieces.append(tr("KINGDOM_ARRIVED"))
	if bool(report.get("hungry", false)):
		pieces.append(tr("KINGDOM_HUNGRY"))
	_note(" · ".join(pieces))


## Le compte rendu du dernier assaut (§ 37), à afficher au retour.
func report_defence(report: Dictionary) -> void:
	if report.is_empty():
		return
	var line := ""
	if bool(report.get("repelled", false)):
		line = tr("INVASION_REPELLED") % [
			int(report.get("defence", 0)), int(report.get("strength", 0)),
			int(report.get("spoils", 0)),
		]
	else:
		line = tr("INVASION_LOST") % [
			int(report.get("defence", 0)), int(report.get("strength", 0))
		]
		var taken: Dictionary = report.get("plundered", {})
		var pieces := PackedStringArray()
		for key: Variant in taken.keys():
			pieces.append("%s %d" % [
				tr(ResourceTable.name_key(StringName(key))), int(taken[key])
			])
		if not pieces.is_empty():
			line += "  " + ", ".join(pieces)
	if bool(report.get("alone", false)):
		line += "  " + tr("INVASION_ALONE")
	_note(line)


func _note(text: String) -> void:
	if is_node_ready():
		_journal.text = text


# --- Mise en forme ---------------------------------------------------------

func _costs(cost: Dictionary) -> String:
	var pieces := PackedStringArray()
	for key: Variant in cost.keys():
		var resource_id := StringName(key)
		var price := int(cost[key])
		var have := _kingdom.amount(resource_id, _company)
		# Ce qu'on n'a pas encore est écrit à côté du prix : « Bois 130
		# (80) » se lit d'un coup, « Bois 130 » oblige à remonter en haut
		# de l'écran pour comparer.
		var text := "%s %d" % [tr(ResourceTable.name_key(resource_id)), price]
		if have < price:
			text += " (%d)" % have
		pieces.append(text)
	return ", ".join(pieces)


func _grants(gained: Dictionary) -> String:
	var pieces := PackedStringArray()
	for key: Variant in gained.keys():
		var field := StringName(key)
		if Buildings.is_fraction(field):
			pieces.append("%s %+d %%" % [
				tr("GRANT_%s" % String(field).to_upper()),
				int(round(float(gained[key]) * 100.0)),
			])
		else:
			pieces.append("%s %+d" % [
				tr("GRANT_%s" % String(field).to_upper()), int(gained[key])
			])
	return ", ".join(pieces) if not pieces.is_empty() else tr("EFFECT_NOTHING")


## Le motif de fond, posé DERRIÈRE tout le reste. Un aplat noir est fade :
## rien n'y accroche la lumière et les panneaux flottent sur du vide.
func _lay_backdrop() -> void:
	UiSkin.lay_backdrop(self)


## LE ROYAUME ÉTAIT LE DERNIER ÉCRAN NU (T11.8). Un rectangle vert à bord
## franc d'un côté, du texte posé sur le fond de l'autre : les deux
## moitiés flottaient, quand tous les autres écrans portent le cadre orné
## de T9.7 depuis longtemps. C'est le pire endroit où l'oublier — c'est
## l'écran que la boucle du § 3 traverse à chaque retour d'expédition.
##
## Le terrain garde son fond à lui : le cadre ne pose qu'un TRAIT
## par-dessus, et le vert reste le vert. Le panneau reçoit le fond sombre
## habituel, comme la fiche d'un héros.
func _dress_frames() -> void:
	# La barre des réserves est une INFORMATION PERMANENTE, pas un titre :
	# elle mérite son cadre, comme l'objectif porte le sien en combat.
	_header_frame.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_card", &"panel_fill", &"panel_edge_soft"
	))
	_view_frame.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_panel", &"panel_deep", &"panel_edge"
	))
	_panel_frame.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_panel", &"panel_fill", &"panel_edge_soft"
	))
