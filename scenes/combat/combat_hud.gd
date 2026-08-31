extends CanvasLayer

## HUD de combat (C1.21) : objectif, tour, escouade, Fin de tour, Annuler.
##
## Deux règles du document se lisent directement dans sa disposition :
## les boutons sont EN BAS, à portée de pouce et jamais dans les coins
## hauts (§ 11.3) ; et le bouton Annuler est présent en permanence tant
## que le tour n'est pas validé (§ 11.2). Il se grise quand il n'y a rien
## à annuler, mais il ne disparaît jamais — un bouton qui apparaît et
## disparaît se cherche, un bouton grisé se comprend.
##
## Zéro texte en dur : tout passe par les clés de traduction.

signal end_turn_pressed
signal undo_pressed

const TOUCH_TARGET_PX := 96

var _objective: Label
var _turn: Label
var _squad: VBoxContainer
var _end_turn: Button
var _undo: Button
var _banner: Label
var _rows: Dictionary = {}


func _ready() -> void:
	_build()


func _build() -> void:
	# Disposition en conteneurs plutôt qu'en ancres : un preset d'ancrage
	# calcule ses décalages à partir de la taille minimale du moment, donc
	# AVANT que les enfants existent il vaut zéro, et le contenu disparaît
	# sans la moindre erreur. Les conteneurs, eux, se remesurent tout seuls.
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left", 20)
	root.add_theme_constant_override("margin_top", 12)
	root.add_theme_constant_override("margin_right", 20)
	root.add_theme_constant_override("margin_bottom", 18)
	add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	# Bandeau haut : objectif à gauche, tour à droite.
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	_objective = _label(26)
	top.add_child(_objective)
	top.add_child(_stretch())
	_turn = _label(26)
	top.add_child(_turn)

	# Milieu : l'escouade à gauche, et tout l'espace libre au centre pour
	# que le plateau reste visible.
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(middle)

	var squad_column := VBoxContainer.new()
	squad_column.alignment = BoxContainer.ALIGNMENT_CENTER
	squad_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(squad_column)
	_squad = VBoxContainer.new()
	_squad.add_theme_constant_override("separation", 6)
	_squad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	squad_column.add_child(_squad)

	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(centre)
	_banner = _label(64)
	_banner.visible = false
	centre.add_child(_banner)

	# Bandeau bas : les deux boutons à droite, à portée de pouce (§ 11.3),
	# et jamais dans les coins hauts.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottom)
	bottom.add_child(_stretch())

	_undo = _button("HUD_UNDO")
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	bottom.add_child(_undo)

	_end_turn = _button("HUD_END_TURN")
	_end_turn.pressed.connect(func() -> void: end_turn_pressed.emit())
	bottom.add_child(_end_turn)


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


func _button(key: String) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.custom_minimum_size = Vector2(TOUCH_TARGET_PX * 2, TOUCH_TARGET_PX)
	button.add_theme_font_size_override("font_size", 28)
	return button


## Met le HUD en accord avec l'état du moteur.
func refresh(engine: CombatEngine) -> void:
	if engine == null:
		return
	_objective.text = _objective_text(engine.objective)
	if engine.is_deploying():
		# Pendant le placement, le bouton principal démarre le combat et le
		# compteur de tours n'a pas encore de sens : on met à la place ce
		# qu'il reste à poser.
		var left := engine.pending_heroes().size()
		_turn.text = tr("HUD_DEPLOY_READY") if left == 0 else tr("HUD_DEPLOY") % left
		_end_turn.text = tr("HUD_BEGIN_COMBAT")
		_end_turn.disabled = not engine.can_begin_combat()
		# Annuler reprend le dernier héros posé : rien n'est irréversible
		# avant que le combat commence, comme rien ne l'est avant la
		# validation d'un tour (§ 11.2).
		_undo.disabled = _placed_count(engine) == 0
	else:
		_turn.text = tr("HUD_ROUND") % engine.round_index()
		_end_turn.text = tr("HUD_END_TURN")
		_end_turn.disabled = not engine.is_player_turn()
		_undo.disabled = not engine.can_undo()
	_refresh_squad(engine)


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

	for unit: Unit in listed:
		var row: Label = _rows.get(unit.id, null)
		if row == null:
			row = _label(22)
			_rows[unit.id] = row
			_squad.add_child(row)
		var name_ := tr("CLASS_%s" % String(unit.class_id).to_upper())
		# Le numéro d'emplacement d'abord : avec les doublons de classe,
		# « Guerrier 120/120 » deux fois de suite ne désigne personne.
		# Les PA et les PM ensuite : le § 48 en fait une exigence — le
		# joueur doit toujours savoir combien il lui en reste.
		row.text = "%d  %s  %d/%d   PA %d/%d  PM %d/%d" % [
			unit.slot, name_, unit.hit_points, unit.max_hit_points,
			unit.action_points, unit.max_action_points,
			unit.movement_points, unit.max_movement_points,
		]
		var active := engine.current_unit()
		if pending.has(unit):
			row.modulate = Color(0.62, 0.7, 0.62)
		elif not unit.is_active():
			row.modulate = Color(0.5, 0.4, 0.4)
		elif active != null and active.id == unit.id:
			# Celui que la timeline désigne, mis en avant : c'est LA
			# question du § 16, qui joue maintenant ?
			row.modulate = Color(1, 0.92, 0.55)
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
