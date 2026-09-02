extends CanvasLayer

## HUD de combat (T1.9).
##
## Le § 48 en fait une exigence chiffrée : le joueur doit TOUJOURS savoir
## combien de PA et de PM il lui reste, quelles actions sont possibles,
## leur portée et leur coût. Le § 16 y ajoute la timeline — qui joue
## maintenant, et qui joue ensuite.
##
## Trois blocs, et rien d'autre :
##   en haut    l'objectif, la timeline, la ronde
##   à gauche   l'équipe, une ligne par personnage
##   en bas     le personnage actif, ses jauges, ses compétences, les
##              deux boutons
##
## Le plateau ne doit JAMAIS passer sous le HUD : `safe_area()` rend au
## contrôleur de caméra le rectangle qui reste libre, et c'est dans
## celui-là que la grille est cadrée. Un HUD qui recouvre le terrain fait
## perdre des cases au joueur sans qu'il sache lesquelles.
##
## Les boutons sont EN BAS, à portée de pouce, et Annuler est présent en
## permanence tant que l'activation n'est pas validée. Il se grise quand
## il n'y a rien à annuler, mais il ne disparaît jamais — un bouton qui
## apparaît et disparaît se cherche, un bouton grisé se comprend.
##
## Zéro texte en dur : tout passe par les clés de traduction.

signal end_turn_pressed
signal undo_pressed
signal ability_selected(ability_id: StringName)

## Le joueur demande la pause. Le combat est au tour par tour, donc rien
## ne « tourne » — mais sur mobile on est interrompu, et un écran sans
## sortie visible est un écran dont on sort par le bouton système, ce qui
## tue l'application.
signal pause_pressed

## La couleur de faction des héros, la même que celle des sprites du
## plateau : un portrait bleu au-dessus d'un guerrier rouge se remarque.
const HERO_COLOR := "Blue"

const TOUCH_TARGET_PX := 96
const TOP_BAR_PX := 64
const BOTTOM_BAR_PX := 196

var _objective: Label
var _round: Label
var _timeline: HBoxContainer
var _squad: VBoxContainer
var _active_name: Label
var _action_pips: Control
var _movement_pips: Control
var _abilities: HBoxContainer
var _end_turn: Button
var _undo: Button
var _banner: Label

var _rows: Dictionary = {}
var _ability_buttons: Dictionary = {}
var _selected_ability: StringName = &""


## Une rangée de pastilles : les PA et les PM sont des points, pas une
## quantité continue. Huit pastilles se comptent d'un coup d'œil et disent
## « deux attaques à trois, et il m'en reste deux » ; une barre pleine à
## 62 % ne dit rien de tel.
class PipRow:
	extends Control

	var filled: int = 0
	var total: int = 0
	var color: Color = Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(10, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_points(now: int, maximum: int, pip_color: Color) -> void:
		filled = maxi(now, 0)
		total = maxi(maximum, 0)
		color = pip_color
		var spacing := ViewSettings.size_of(&"pip_spacing_px")
		custom_minimum_size = Vector2(spacing * float(maxi(total, 1)), 20)
		queue_redraw()

	func _draw() -> void:
		var radius := ViewSettings.size_of(&"pip_radius_px")
		var spacing := ViewSettings.size_of(&"pip_spacing_px")
		var empty := ViewSettings.color(&"pip_empty")
		for i in total:
			var centre := Vector2(radius + float(i) * spacing, size.y * 0.5)
			draw_circle(centre, radius, color if i < filled else empty)
			draw_arc(centre, radius, 0.0, TAU, 16, ViewSettings.color(&"dot_outline"), 1.5)


func _ready() -> void:
	_build()


## Le rectangle que le plateau peut occuper sans passer sous le HUD.
func safe_area(viewport: Vector2) -> Rect2:
	return Rect2(
		Vector2(0, TOP_BAR_PX),
		Vector2(viewport.x, maxf(viewport.y - TOP_BAR_PX - BOTTOM_BAR_PX, 1.0))
	)


func selected_ability() -> StringName:
	return _selected_ability


func set_selected_ability(ability_id: StringName) -> void:
	_selected_ability = ability_id


func _build() -> void:
	# Disposition en conteneurs plutôt qu'en ancres : un preset d'ancrage
	# calcule ses décalages à partir de la taille minimale du moment, donc
	# AVANT que les enfants existent il vaut zéro, et le contenu disparaît
	# sans la moindre erreur. Les conteneurs, eux, se remesurent tout seuls.
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_top", 10)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_bottom", 14)
	add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	column.add_child(_build_top())
	column.add_child(_build_middle())
	column.add_child(_build_bottom())
	_build_timeline()
	_build_corner()


## Bandeau haut : objectif à gauche, timeline au centre, ronde à droite.
func _build_top() -> Control:
	# TROIS ZONES À LARGEUR EXPLICITE, et pas des ressorts entre des
	# éléments libres. Un `HBoxContainer` dont la somme des minimums
	# dépasse sa largeur rabote ses DERNIERS enfants — la ronde et la
	# pause avaient purement disparu du bandeau, sans erreur ni trace,
	# quand l'objectif et la timeline ont grossi. On borne donc chaque
	# zone au lieu de laisser le conteneur arbitrer.
	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, TOP_BAR_PX)
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var goal := PanelContainer.new()
	goal.add_theme_stylebox_override(
		"panel", UiSkin.panel_style(&"panel_strong", UiTheme.metric(&"card_margin"))
	)
	goal.custom_minimum_size = Vector2(UiTheme.metric(&"objective_width"), 0)
	goal.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	goal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective = _label(UiTheme.font_size(&"small"))
	_objective.add_theme_color_override("font_color", UiTheme.color(&"ink"))
	_objective.add_theme_constant_override("outline_size", 0)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.clip_text = true
	goal.add_child(_objective)
	top.add_child(goal)

	return top


## La timeline, ANCRÉE AU CENTRE et hors du flux, pour la même raison que
## le coin : laissée dans le `HBoxContainer`, elle s'étalait jusque sous
## la ronde et la pause. Trois zones ancrées valent mieux que trois zones
## qui se disputent une largeur.
func _build_timeline() -> void:
	_timeline = HBoxContainer.new()
	_timeline.add_theme_constant_override("separation", 6)
	_timeline.alignment = BoxContainer.ALIGNMENT_CENTER
	_timeline.anchor_left = 0.5
	_timeline.anchor_right = 0.5
	_timeline.offset_left = -float(UiTheme.metric(&"timeline_width")) * 0.5
	_timeline.offset_right = float(UiTheme.metric(&"timeline_width")) * 0.5
	_timeline.offset_top = 14.0
	_timeline.offset_bottom = 14.0 + float(TOP_BAR_PX)
	_timeline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timeline)


## La ronde et la pause, ANCRÉES EN HAUT À DROITE et hors du flux.
##
## ELLES AVAIENT DISPARU DEUX FOIS. Dans un `HBoxContainer`, quand la somme
## des tailles minimales dépasse la largeur, ce sont les DERNIERS enfants
## qui sont rabotés — sans erreur, sans trace, sans rien à l'écran. Ça
## s'est produit dès que l'objectif a pris un panneau et que les badges de
## timeline ont grossi, et deux tentatives de bornage n'y ont rien fait.
##
## Un ancrage ne dépend de personne : c'est le seul moyen de garantir que
## le bouton de pause soit là, et sur mobile un combat dont on ne peut pas
## sortir est le pire des défauts (§ T6.1).
## POSÉ SUR LE `CanvasLayer`, PAS DANS LE CONTENEUR. Un `Container` écrase
## les ancrages de ses enfants — c'est sa raison d'être — donc un ancrage
## posé à l'intérieur du `MarginContainer` était réécrit à chaque mise en
## page. Le calque, lui, n'est pas un conteneur : ce qu'on y ancre reste
## où on l'a mis.
func _build_corner() -> void:
	var corner := HBoxContainer.new()
	corner.add_theme_constant_override("separation", 8)
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	corner.anchor_top = 0.0
	corner.anchor_bottom = 0.0
	corner.offset_left = -float(UiTheme.metric(&"corner_width"))
	corner.offset_right = -18.0
	corner.offset_top = 14.0
	corner.offset_bottom = 14.0 + float(TOP_BAR_PX)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(corner)

	_round = _label(UiTheme.font_size(&"small"))
	_round.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	corner.add_child(_round)

	# En haut à droite, loin des compétences : une pause qu'on presse par
	# accident au milieu d'une activation est pire que pas de pause.
	var pause := _button("HUD_PAUSE")
	pause.custom_minimum_size = Vector2(64, 48)
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	corner.add_child(pause)


## Milieu : l'équipe à gauche, le reste vide pour que le plateau respire.
func _build_middle() -> Control:
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(left)
	_squad = VBoxContainer.new()
	_squad.add_theme_constant_override("separation", 4)
	_squad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_squad)

	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(centre)
	_banner = _label(64)
	_banner.visible = false
	centre.add_child(_banner)
	return middle


## Bandeau bas : le personnage actif et ses jauges, ses compétences, et
## les deux boutons — le tout à portée de pouce.
func _build_bottom() -> Control:
	# LA TABLE DE BOIS DU PACK SOUS TOUTE LA BARRE. C'est le défaut que
	# Gaetan a pointé : les boutons flottaient sur du noir. Dans les trois
	# jeux montrés en référence, aucune zone d'interface ne touche
	# directement le fond — tout repose sur un panneau. Et
	# thématiquement, la table est l'endroit où l'on pose ses outils.
	var plank := PanelContainer.new()
	plank.custom_minimum_size = Vector2(0, BOTTOM_BAR_PX)
	plank.add_theme_stylebox_override(
		"panel", UiSkin.panel_style(&"frame", UiTheme.metric(&"plank_margin"))
	)
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.add_child(bottom)

	# Ligne d'état : qui joue, ses PV, ses PA, ses PM.
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 22)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(status)

	_active_name = _label(26)
	status.add_child(_active_name)

	status.add_child(_label_text(24, tr("HUD_AP")))
	_action_pips = PipRow.new()
	status.add_child(_action_pips)

	status.add_child(_label_text(24, tr("HUD_MP")))
	_movement_pips = PipRow.new()
	status.add_child(_movement_pips)

	status.add_child(_stretch())

	# Ligne d'action : les compétences à gauche, les boutons à droite.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(actions)

	_abilities = HBoxContainer.new()
	_abilities.add_theme_constant_override("separation", 10)
	_abilities.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(_abilities)

	actions.add_child(_stretch())

	_undo = _button("HUD_UNDO")
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	actions.add_child(_undo)

	_end_turn = _button("HUD_END_TURN")
	_end_turn.pressed.connect(func() -> void: end_turn_pressed.emit())
	actions.add_child(_end_turn)
	return plank


# --- Mise à jour ----------------------------------------------------------

## Met le HUD en accord avec l'état du moteur.
func refresh(engine: CombatEngine) -> void:
	if engine == null:
		return
	_objective.text = _objective_text(engine.objective)

	if engine.is_deploying():
		# Pendant le placement, le bouton principal démarre le combat et le
		# compteur de rondes n'a pas encore de sens : on met à la place ce
		# qu'il reste à poser.
		var left := engine.pending_heroes().size()
		_round.text = tr("HUD_DEPLOY_READY") if left == 0 else tr("HUD_DEPLOY") % left
		_end_turn.text = tr("HUD_BEGIN_COMBAT")
		_end_turn.disabled = not engine.can_begin_combat()
		_undo.disabled = _placed_count(engine) == 0
	else:
		_round.text = tr("HUD_ROUND") % engine.round_index()
		_end_turn.text = tr("HUD_END_TURN")
		_end_turn.disabled = not engine.is_player_turn()
		_undo.disabled = not engine.can_undo()

	_refresh_timeline(engine)
	_refresh_active(engine)
	_refresh_abilities(engine)
	_refresh_squad(engine)


## La timeline : qui joue maintenant, et qui joue ensuite (§ 16).
##
## Le premier badge est le personnage actif, mis en avant. Les suivants
## sont l'ordre à venir, en débordant sur la ronde d'après — sinon la
## timeline se viderait en fin de ronde, au moment précis où le joueur a
## le plus besoin de savoir ce qui arrive.
func _refresh_timeline(engine: CombatEngine) -> void:
	for child in _timeline.get_children():
		child.queue_free()
	if engine.is_deploying() or engine.is_finished():
		return
	var order := engine.timeline()
	for i in order.size():
		var unit := engine.board.unit_by_id(order[i])
		if unit == null:
			continue
		_timeline.add_child(_timeline_badge(unit, i == 0))


func _timeline_badge(unit: Unit, is_current: bool) -> Control:
	var side := ViewSettings.size_of(&"timeline_badge_px")
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(side, side)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# UN `Panel` ET PAS UN `PanelContainer`, et la différence n'est pas
	# cosmétique : un `PanelContainer` écarte son enfant des marges de
	# tranches du style — 32 px de chaque côté sur un badge de 44, il ne
	# reste rien. Ici le portrait est posé par-dessus, en plein cadre.
	var role: StringName = &"default" if unit.is_hero() else &"danger"
	if is_current:
		role = &"primary"
	badge.add_theme_stylebox_override("panel", UiSkin.button_style(role, false))

	var face := UiSkin.portrait(unit.class_id, HERO_COLOR) if unit.is_hero() else null
	if face != null:
		var rect := TextureRect.new()
		rect.texture = face
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(rect)
		return badge

	# LE PACK N'A PAS DE PORTRAIT D'ENNEMI — 25 avatars humains et rien
	# d'autre. L'initiale de l'espèce tient donc le rôle, sur le cadre
	# rouge : mieux vaut un cadre cohérent avec une lettre qu'un visage
	# emprunté à quelqu'un d'autre.
	var label := _label(20)
	label.text = _timeline_text(unit)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiTheme.color(&"ink_inverse"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge


## Un héros porte son numéro d'emplacement — c'est ce qui distingue deux
## Guerriers. Un ennemi porte l'initiale de son espèce.
func _timeline_text(unit: Unit) -> String:
	if unit.is_hero() and unit.slot > 0:
		return str(unit.slot)
	var key := "ENEMY_%s" % String(unit.class_id).to_upper()
	var name_ := tr(key)
	# Une clé absente se renvoie elle-même : « ENEMY_GNOME » donnerait « E »
	# pour tout le bestiaire, et la timeline ne distinguerait plus rien.
	if name_ == key:
		push_error("HUD : pas de nom pour l'ennemi « %s »" % unit.class_id)
		return "?"
	return name_.substr(0, 1).to_upper()


func _refresh_active(engine: CombatEngine) -> void:
	var unit := engine.current_unit()
	if unit == null or not unit.is_hero():
		_active_name.text = ""
		_action_pips.set_points(0, 0, ViewSettings.color(&"ap_pip"))
		_movement_pips.set_points(0, 0, ViewSettings.color(&"mp_pip"))
		return
	_active_name.text = tr("HUD_ACTIVE") % [
		unit.slot, tr("CLASS_%s" % String(unit.class_id).to_upper()),
		unit.hit_points, unit.max_hit_points,
	]
	_action_pips.set_points(
		unit.action_points, unit.max_action_points, ViewSettings.color(&"ap_pip")
	)
	_movement_pips.set_points(
		unit.movement_points, unit.max_movement_points, ViewSettings.color(&"mp_pip")
	)


## La barre de compétences. Une par capacité du personnage actif, avec son
## coût en PA écrit dessus — le § 48 demande que le joueur sache ce que
## chaque action coûte AVANT de la choisir, pas après.
##
## Un bouton indisponible est grisé et dit pourquoi : pas assez de PA, en
## recharge, a déjà bougé. Le refus doit être lisible, sinon le joueur
## croit à un bug.
func _refresh_abilities(engine: CombatEngine) -> void:
	var unit := engine.current_unit()
	var wanted: Array[StringName] = []
	if unit != null and unit.is_hero() and not engine.is_deploying():
		wanted = unit.abilities.duplicate()
		# LE BOUTON « ITEM » DU § 48. Les potions se rangent après les
		# compétences et se manipulent comme elles : le HUD ne connaît que
		# des identifiants de compétence, et c'est le moteur qui sait
		# laquelle vient du sac.
		for item_id: StringName in engine.usable_consumables(unit):
			wanted.append(Consumable.ability_of(item_id))

	if wanted.is_empty():
		_clear_abilities()
		return

	# On ne reconstruit les boutons que si la liste change : recréer des
	# nœuds à chaque image perdrait le focus et ferait clignoter la barre.
	if _ability_buttons.keys() != Array(wanted):
		_clear_abilities()
		for ability_id: StringName in wanted:
			var button := _ability_button(ability_id)
			_ability_buttons[ability_id] = button
			_abilities.add_child(button)

	if not wanted.has(_selected_ability):
		_selected_ability = unit.basic_ability()

	for ability_id: StringName in wanted:
		var ability := Ability.of(ability_id)
		var button: Button = _ability_buttons[ability_id]
		if ability == null:
			continue
		var left := unit.cooldown_left(ability_id)
		var carried := Consumable.item_for_ability(ability_id)
		if not carried.is_empty():
			# Une potion affiche ce qu'il en RESTE, pas sa recharge : c'est
			# le seul chiffre qui décide de la boire maintenant ou plus
			# tard, et c'est tout le poids qu'elle a dans le § 29.
			button.text = tr("HUD_CONSUMABLE") % [
				tr(Consumable.name_key(carried)), ability.action_points,
				int(engine.supplies.get(carried, 0))
			]
		elif left > 0:
			button.text = tr("HUD_ABILITY_COOLDOWN") % [_ability_name(ability_id), left]
		else:
			button.text = tr("HUD_ABILITY") % [
				_ability_name(ability_id), ability.action_points
			]
		button.disabled = not ability.is_available_to(unit)
		button.tooltip_text = tr(String(ability.unavailable_reason(unit)).to_upper()
			.replace(".", "_")) if button.disabled else ""
		button.button_pressed = ability_id == _selected_ability


func _clear_abilities() -> void:
	for child in _abilities.get_children():
		child.queue_free()
	_ability_buttons.clear()


func _ability_button(ability_id: StringName) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(TOUCH_TARGET_PX * 2, TOUCH_TARGET_PX * 0.75)
	button.add_theme_font_size_override("font_size", UiTheme.font_size(&"button"))
	# UNE POTION N'EST PAS UN SORT, ET ÇA DOIT SE VOIR AVANT DE LIRE. Elle
	# se consomme : la confondre avec une compétence gratuite au moment de
	# choisir, c'est brûler la dernière du sac par distraction.
	var role: StringName = &"default"
	if not Consumable.item_for_ability(ability_id).is_empty():
		role = &"arcane"
	UiSkin.dress_button(button, role)
	# LE GLYPHE DU § 48. Une compétence sans icône garde son texte seul :
	# l'absence est une réponse valable, pas un défaut — c'est ce qui
	# permet d'en ajouter une à la fois.
	var mark := UiSkin.glyph(ability_id)
	if mark != null:
		button.icon = mark
		button.expand_icon = false
	button.pressed.connect(func() -> void:
		_selected_ability = ability_id
		ability_selected.emit(ability_id))
	return button


func _ability_name(ability_id: StringName) -> String:
	return tr("ABILITY_%s" % String(ability_id).to_upper())


func _placed_count(engine: CombatEngine) -> int:
	var placed := 0
	for unit: Unit in engine.board.active_units(Unit.Side.HEROES):
		if not engine.pending_heroes().has(unit):
			placed += 1
	return placed


func _refresh_squad(engine: CombatEngine) -> void:
	var pending := engine.pending_heroes()
	var listed: Array[Unit] = []
	for unit: Unit in engine.board.units():
		if unit.is_hero():
			listed.append(unit)
	for unit: Unit in pending:
		if not listed.has(unit):
			listed.append(unit)
	listed.sort_custom(func(a: Unit, b: Unit) -> bool: return a.slot < b.slot)

	# LES CARTES SE RECONSTRUISENT À CHAQUE RAFRAÎCHISSEMENT, parce
	# qu'elles portent une jauge dont la valeur change. Quatre cartes,
	# c'est assez peu pour que ça ne coûte rien, et ça évite d'entretenir
	# une correspondance unité → nœuds qui se désynchronise dès qu'un
	# héros tombe.
	for child in _squad.get_children():
		child.queue_free()
	_rows.clear()

	var active := engine.current_unit()
	for unit: Unit in listed:
		var state: StringName = &"ready"
		if pending.has(unit):
			state = &"pending"
		elif not unit.is_active():
			state = &"downed"
		elif active != null and active.id == unit.id:
			state = &"active"
		_squad.add_child(_hero_card(unit, state))


## La carte d'un héros : son visage, son nom, sa vie.
##
## C'ÉTAIT DU TEXTE SUR DU NOIR, et c'est le défaut que Gaetan a pointé en
## comparant à d'autres jeux. Les trois montrés en référence ont tous la
## même chose : chaque zone d'interface est posée sur un panneau, avec un
## portrait et une jauge. Ce n'est pas de la décoration — un visage se
## reconnaît plus vite qu'une ligne « 1 Guerrier 120/120 », et c'est ce
## qu'on lit vingt fois par combat.
func _hero_card(unit: Unit, state: StringName) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# LARGEUR FIXE. Sans elle les quatre cartes s'étiraient sur toute la
	# hauteur et POUSSAIENT LA BARRE D'ACTION HORS DE L'ÉCRAN : 4 × 130 px
	# plus les bandeaux dépassent les 720 px de haut, et Godot ne dit rien
	# — il rogne en silence.
	card.custom_minimum_size = Vector2(UiTheme.metric(&"card_width"), 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override(
		"panel", UiSkin.panel_style(&"panel", UiTheme.metric(&"card_margin"))
	)

	# Pas de `MarginContainer` : le style porte déjà l'encart, et en
	# ajouter un second par-dessus est l'erreur qui avait fait disparaître
	# la jauge de PV en T9.2.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.metric(&"card_margin"))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var side_px := UiTheme.metric(&"portrait_card")
	var face := UiSkin.portrait(unit.class_id, HERO_COLOR)
	if face != null:
		var rect := TextureRect.new()
		rect.texture = face
		rect.custom_minimum_size = Vector2(side_px, side_px)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rect)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)

	# Le numéro d'emplacement d'abord : avec les doublons de classe,
	# « Guerrier » deux fois de suite ne désigne personne.
	# NOM ET POINTS DE VIE SUR LA MÊME LIGNE : deux lignes de texte plus
	# une jauge font une carte de 130 px, et quatre de celles-là ne
	# tiennent pas dans un écran qui doit aussi loger la barre d'action.
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)

	var name_ := _label_text(
		UiTheme.font_size(&"small"),
		"%d  %s" % [unit.slot, tr("CLASS_%s" % String(unit.class_id).to_upper())]
	)
	name_.add_theme_color_override("font_color", UiTheme.color(&"ink"))
	name_.add_theme_constant_override("outline_size", 0)
	name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_)

	var points := _label_text(
		UiTheme.font_size(&"small"),
		"%d/%d" % [unit.hit_points, unit.max_hit_points]
	)
	points.add_theme_color_override("font_color", UiTheme.color(&"ink_soft"))
	points.add_theme_constant_override("outline_size", 0)
	header.add_child(points)

	column.add_child(UiSkin.build_bar(
		float(unit.hit_points), float(unit.max_hit_points),
		UiTheme.health_color(
			float(unit.hit_points) / maxf(float(unit.max_hit_points), 1.0)
		),
		UiTheme.metric(&"bar_height_card")
	))

	match state:
		&"pending":
			card.modulate = ViewSettings.color(&"timeline_done")
		&"downed":
			card.modulate = ViewSettings.color(&"timeline_downed")
		&"active":
			# La carte de celui qui joue s'éclaircit : la même question que
			# la timeline, posée là où le joueur regarde ses PV.
			card.modulate = ViewSettings.color(&"timeline_now")
	return card


func show_result(victory: bool) -> void:
	_banner.text = tr("RESULT_VICTORY" if victory else "RESULT_DEFEAT")
	_banner.visible = true


func _objective_text(objective: CombatObjective) -> String:
	match objective.kind:
		CombatObjective.Kind.SURVIVE:
			return tr("OBJECTIVE_SURVIVE") % objective.turns
		CombatObjective.Kind.ESCORT:
			return tr("OBJECTIVE_ESCORT")
		CombatObjective.Kind.PROTECT:
			return tr("OBJECTIVE_PROTECT") % objective.turns
		CombatObjective.Kind.SEIZE:
			return tr("OBJECTIVE_SEIZE") % objective.deadline
		CombatObjective.Kind.EXTRACT:
			return tr("OBJECTIVE_EXTRACT")
	return tr("OBJECTIVE_ELIMINATE")


# --- Fabriques ------------------------------------------------------------

func _stretch() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", UiTheme.color(&"ink"))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _label_text(size: int, text: String) -> Label:
	var label := _label(size)
	label.text = text
	return label


func _button(key: String) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.custom_minimum_size = Vector2(TOUCH_TARGET_PX * 1.7, TOUCH_TARGET_PX * 0.75)
	button.add_theme_font_size_override("font_size", 26)
	return button
