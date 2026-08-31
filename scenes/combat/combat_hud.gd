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

const TOUCH_TARGET_PX := 96
const TOP_BAR_PX := 64
const BOTTOM_BAR_PX := 172

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
			draw_arc(centre, radius, 0.0, TAU, 16, Color(0, 0, 0, 0.6), 1.5)


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


## Bandeau haut : objectif à gauche, timeline au centre, ronde à droite.
func _build_top() -> Control:
	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, TOP_BAR_PX)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_objective = _label(24)
	top.add_child(_objective)
	top.add_child(_stretch())

	_timeline = HBoxContainer.new()
	_timeline.add_theme_constant_override("separation", 6)
	_timeline.alignment = BoxContainer.ALIGNMENT_CENTER
	_timeline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_timeline)

	top.add_child(_stretch())
	_round = _label(24)
	top.add_child(_round)
	return top


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
	var bottom := VBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, BOTTOM_BAR_PX)
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	return bottom


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

	var style := StyleBoxFlat.new()
	style.bg_color = ViewSettings.color(
		&"timeline_hero" if unit.is_hero() else &"timeline_enemy"
	)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	if is_current:
		# Le personnage actif porte un liseré clair : la question du § 16
		# — qui joue MAINTENANT ? — doit se lire sans compter.
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_color = ViewSettings.color(&"timeline_now")
	badge.add_theme_stylebox_override("panel", style)

	var label := _label(20)
	label.text = _timeline_text(unit)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.08, 0.07, 0.06))
	label.add_theme_constant_override("outline_size", 0)
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
		wanted = unit.abilities

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
		if left > 0:
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
	button.add_theme_font_size_override("font_size", 22)
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

	var active := engine.current_unit()
	for unit: Unit in listed:
		var row: Label = _rows.get(unit.id, null)
		if row == null:
			row = _label(22)
			_rows[unit.id] = row
			_squad.add_child(row)
		# Le numéro d'emplacement d'abord : avec les doublons de classe,
		# « Guerrier 120/120 » deux fois de suite ne désigne personne.
		row.text = "%d  %s  %d/%d" % [
			unit.slot, tr("CLASS_%s" % String(unit.class_id).to_upper()),
			unit.hit_points, unit.max_hit_points,
		]
		if pending.has(unit):
			row.modulate = Color(0.62, 0.7, 0.62)
		elif not unit.is_active():
			row.modulate = Color(0.5, 0.4, 0.4)
		elif active != null and active.id == unit.id:
			row.modulate = ViewSettings.color(&"timeline_now")
		else:
			row.modulate = Color(1, 1, 1)


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
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
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
