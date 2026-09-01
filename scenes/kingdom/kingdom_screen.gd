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
@onready var _panel: VBoxContainer = %Panel
@onready var _journal: Label = %Journal


func _ready() -> void:
	theme = UiSkin.theme
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
		_stores.add_child(_store_label(
			tr(ResourceTable.name_key(resource_id)),
			str(_kingdom.amount(resource_id, _company))
		))
	# Les bras libres sont une ressource comme les autres, et la plus
	# facile à oublier : un habitant au repos mange sans rien rendre.
	_stores.add_child(_store_label(
		tr("KINGDOM_PEOPLE"),
		"%d / %d  (%d %s)" % [
			_kingdom.population, _kingdom.population_cap(),
			_kingdom.idle_pawns(), tr("KINGDOM_IDLE")
		]
	))


func _store_label(name_: String, value: String) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	label.text = "%s %s" % [name_, value]
	return label


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
	_recruit_button(building_id)


## Recruter est la seconde chose qu'un bâtiment militaire permet, et le
## § 45 la met dans cette phase. Le bouton n'apparaît que là où quelqu'un
## se forme.
func _recruit_button(building_id: StringName) -> void:
	var class_id := Buildings.hero_class(building_id)
	if class_id.is_empty() or _kingdom.level_of(building_id) <= 0:
		return
	var blocked := _kingdom.cannot_recruit_because(building_id, _company)
	# Sur deux lignes : le nom, puis le prix. Une seule ligne dépassait la
	# largeur du panneau, et c'est ce qui a fait boucler la mise en page.
	var label := tr("KINGDOM_RECRUIT") % [
		tr("CLASS_%s" % String(class_id).to_upper()),
		_costs(Buildings.recruit_cost(building_id)),
	]
	if blocked == &"cost":
		label = tr("KINGDOM_NEEDS_RESOURCES")
	_action(label, _recruit.bind(building_id), blocked.is_empty())


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
	_note(tr("KINGDOM_BUILT") % [tr(Buildings.name_key(building_id)), reached])
	changed.emit()
	refresh()


func _recruit(building_id: StringName) -> void:
	var hero := _kingdom.recruit(building_id, _company, _rng)
	if hero == null:
		return
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
