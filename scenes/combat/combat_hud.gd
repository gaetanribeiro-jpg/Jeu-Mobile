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
const TOP_BAR_PX := 62
const BOTTOM_BAR_PX := 168

var _objective: Label
var _round: Label
var _timeline: HBoxContainer
var _squad: VBoxContainer
var _active_name: Label
var _active_face: TextureRect
var _detail: VBoxContainer
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
## La place qui reste VRAIMENT au plateau.
##
## ELLE NE COMPTAIT QUE LE HAUT ET LE BAS. Depuis que la colonne des héros
## et le panneau de détail existent, le plateau était cadré sur toute la
## largeur puis DESSINÉ SOUS EUX : un tiers de la carte se jouait derrière
## des panneaux opaques. Le joueur ne voyait pas qu'il manquait quelque
## chose, il voyait juste un plateau étroit.
func safe_area(viewport: Vector2) -> Rect2:
	var left := float(UiTheme.metric(&"card_width") + 30)
	var right := float(UiTheme.metric(&"detail_width") + 30)
	return Rect2(
		Vector2(left, TOP_BAR_PX),
		Vector2(
			maxf(viewport.x - left - right, 1.0),
			maxf(viewport.y - TOP_BAR_PX - BOTTOM_BAR_PX, 1.0)
		)
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
	_build_detail()


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
	goal.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_panel", &"panel_fill", &"panel_edge_soft",
		UiTheme.metric(&"card_margin")
	))
	goal.custom_minimum_size = Vector2(UiTheme.metric(&"objective_width"), 0)
	goal.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	goal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal.add_child(stack)

	# UN EN-TÊTE EN PETITES CAPITALES DORÉES au-dessus de chaque panneau :
	# c'est ce qui, dans le modèle, dit à quoi sert la zone avant qu'on
	# lise son contenu. Sans lui un panneau n'est qu'une boîte.
	stack.add_child(_caption("HUD_OBJECTIVE_TITLE"))
	_objective = _label(UiTheme.font_size(&"small"))
	_objective.add_theme_color_override("font_color", UiTheme.color(&"ink"))
	_objective.add_theme_constant_override("outline_size", 0)
	_objective.clip_text = true
	stack.add_child(_objective)
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
## Le panneau de détail de la compétence visée, ancré à droite.
##
## C'EST CE QUE LE MODÈLE AJOUTE ET QUE LE JEU N'AVAIT PAS : le § 48 veut
## que le joueur sache ce qu'une action coûte ET ce qu'elle fait AVANT de
## la choisir. Le coût était sur le bouton ; les dégâts, la portée et
## l'effet ne se lisaient nulle part, sinon en la lançant.
func _build_detail() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -float(UiTheme.metric(&"detail_width")) - 18.0
	panel.offset_right = -18.0
	panel.offset_top = 14.0 + float(TOP_BAR_PX)
	panel.offset_bottom = panel.offset_top + float(UiTheme.metric(&"detail_height"))
	panel.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_panel", &"panel_fill", &"panel_edge_soft",
		UiTheme.metric(&"card_margin")
	))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_detail)


## Remplit le panneau de détail à partir de la compétence choisie.
func _refresh_detail(engine: CombatEngine) -> void:
	for child in _detail.get_children():
		child.queue_free()
	var unit := engine.current_unit()
	if unit == null or not unit.is_hero() or _selected_ability.is_empty():
		return
	var ability := Ability.of(_selected_ability)
	if ability == null:
		return

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(head)
	var mark := UiSkin.glyph(_selected_ability)
	if mark != null:
		var icon := TextureRect.new()
		icon.texture = mark
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(icon)
	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", 0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	var name_ := _label_text(UiTheme.font_size(&"subheading"), _ability_name(_selected_ability))
	name_.add_theme_color_override("font_color", UiTheme.color(&"ink_gold"))
	name_.add_theme_constant_override("outline_size", 0)
	title.add_child(name_)
	title.add_child(_detail_value(tr("HUD_ABILITY_COST") % ability.action_points))

	_detail.add_child(_caption("HUD_DETAIL_DAMAGE"))
	_detail.add_child(_detail_value(
		tr("HUD_DETAIL_NONE") if ability.damage <= 0 else str(ability.damage)
	))
	_detail.add_child(_caption("HUD_DETAIL_RANGE"))
	_detail.add_child(_detail_value(
		tr("HUD_DETAIL_CELLS") % [ability.range_min, ability.range_max]
	))
	_detail.add_child(_caption("HUD_DETAIL_EFFECT"))
	_detail.add_child(_detail_value(
		tr("HUD_DETAIL_NONE") if ability.status_id.is_empty()
		else tr("STATUS_%s" % String(ability.status_id).to_upper())
	))


func _detail_value(text: String) -> Label:
	var value := _label_text(UiTheme.font_size(&"small"), text)
	value.add_theme_color_override("font_color", UiTheme.color(&"ink"))
	value.add_theme_constant_override("outline_size", 0)
	return value


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

	# LA RONDE DANS SON PROPRE CADRE, comme le reste. Une ligne de texte
	# nue au milieu de panneaux ornés se voit autant qu'un panneau
	# manquant.
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_card", &"panel_fill", &"panel_edge_soft", 10
	))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_child(badge)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(inner)
	inner.add_child(_caption("HUD_ROUND_TITLE"))
	_round = _label(UiTheme.font_size(&"subheading"))
	_round.add_theme_color_override("font_color", UiTheme.color(&"ink"))
	_round.add_theme_constant_override("outline_size", 0)
	_round.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(_round)

	# En haut à droite, loin des compétences : une pause qu'on presse par
	# accident au milieu d'une activation est pire que pas de pause.
	var pause := _button("HUD_PAUSE")
	pause.custom_minimum_size = Vector2(56, 56)
	pause.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state: String in ["normal", "hover", "focus", "pressed"]:
		pause.add_theme_stylebox_override(state, UiSkin.framed_style(
			&"frame_card", &"panel_fill", &"panel_edge", 6
		))
	pause.add_theme_color_override("font_color", UiTheme.color(&"ink_gold"))
	pause.add_theme_constant_override("outline_size", 0)
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
	_banner = _outlined(64)
	_banner.visible = false
	centre.add_child(_banner)
	return middle


## Bandeau bas : le personnage actif et ses jauges, ses compétences, et
## les deux boutons — le tout à portée de pouce.
func _build_bottom() -> Control:
	# UN PANNEAU SOMBRE À LISERÉ ORNÉ, comme tout le reste. La table de
	# bois du pack faisait le travail — plus rien ne flottait — mais elle
	# jurait avec le sombre et l'or du modèle : deux matières pour une
	# seule interface.
	var plank := PanelContainer.new()
	plank.custom_minimum_size = Vector2(0, BOTTOM_BAR_PX)
	plank.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_panel", &"panel_deep", &"panel_edge_soft",
		UiTheme.metric(&"plank_margin")
	))
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 14)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.add_child(strip)

	# LE GRAND PORTRAIT DE CELUI QUI JOUE, à gauche. C'est ce que le modèle
	# met en premier, et c'est justifié : la barre du bas parle d'UN
	# personnage, et rien ne le disait à part une ligne de texte.
	_active_face = TextureRect.new()
	var side := UiTheme.metric(&"portrait_hero")
	_active_face.custom_minimum_size = Vector2(side, side)
	_active_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_active_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_active_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_active_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_card", &"panel_fill", &"panel_edge_soft", 4
	))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_active_face)
	strip.add_child(frame)

	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(bottom)

	# Ligne d'état : qui joue, ses PV, ses PA, ses PM.
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 22)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(status)

	_active_name = _label(UiTheme.font_size(&"subheading"))
	_active_name.add_theme_color_override("font_color", UiTheme.color(&"ink_gold"))
	status.add_child(_active_name)

	status.add_child(_caption_text(tr("HUD_AP")))
	_action_pips = PipRow.new()
	status.add_child(_action_pips)

	status.add_child(_caption_text(tr("HUD_MP")))
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


## Une étiquette en petites capitales dorées, pour un texte déjà traduit.
func _caption_text(text: String) -> Label:
	var caption := _label(UiTheme.font_size(&"caption"))
	caption.text = text.to_upper()
	caption.add_theme_color_override("font_color", UiTheme.color(&"ink_gold"))
	caption.add_theme_constant_override("outline_size", 0)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return caption


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
		_round.text = str(engine.round_index())
		_end_turn.text = tr("HUD_END_TURN")
		_end_turn.disabled = not engine.is_player_turn()
		_undo.disabled = not engine.can_undo()

	_refresh_timeline(engine)
	_refresh_active(engine)
	_refresh_abilities(engine)
	_refresh_squad(engine)
	_refresh_detail(engine)


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
	# Le liseré porte le camp et le tour : or vif pour celui qui joue,
	# doré éteint pour les héros, rouge pour les ennemis.
	var edge: StringName = &"panel_edge_soft"
	if is_current:
		edge = &"panel_edge"
	elif not unit.is_hero():
		edge = &"rust"
	badge.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_slot", &"panel_fill", edge, 2
	))

	# LE PACK A VINGT ET UN VISAGES D'ENNEMIS, et le commentaire qui suivait
	# ici disait le contraire. La timeline montrait une lettre pour tout le
	# bestiaire : « G » ne distingue pas un gnoll d'un gnome, et c'est
	# précisément ce que la timeline doit permettre de lire d'un coup d'œil.
	var face := UiSkin.portrait(unit.class_id, HERO_COLOR) if unit.is_hero() \
		else UiSkin.enemy_portrait(unit.sprite_id)
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

	# La retombée quand un visage manque : l'initiale de l'espèce, sur le
	# cadre rouge. Mieux vaut un cadre cohérent avec une lettre qu'un
	# visage emprunté à quelqu'un d'autre.
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
		_active_face.texture = null
		_action_pips.set_points(0, 0, ViewSettings.color(&"ap_pip"))
		_movement_pips.set_points(0, 0, ViewSettings.color(&"mp_pip"))
		return
	_active_face.texture = UiSkin.portrait(unit.class_id, HERO_COLOR)
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
	button.custom_minimum_size = Vector2(
		UiTheme.metric(&"ability_card_width"), TOUCH_TARGET_PX * 0.72
	)
	button.add_theme_font_size_override("font_size", UiTheme.font_size(&"small"))
	# UNE POTION N'EST PAS UN SORT, ET ÇA DOIT SE VOIR AVANT DE LIRE. Elle
	# se consomme : la confondre avec une compétence gratuite au moment de
	# choisir, c'est brûler la dernière du sac par distraction.
	var carried := not Consumable.item_for_ability(ability_id).is_empty()
	var edge: StringName = &"plum" if carried else &"panel_edge_soft"
	var fill: StringName = &"panel_potion" if carried else &"panel_fill"
	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(
			state, UiSkin.framed_style(&"frame_card", fill, edge, 10)
		)
	button.add_theme_stylebox_override("pressed", UiSkin.framed_style(
		&"frame_card", fill, &"panel_edge", 10
	))
	button.add_theme_stylebox_override("disabled", UiSkin.framed_style(
		&"frame_card", &"panel_deep", &"panel_edge_soft", 10
	))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, UiTheme.color(&"ink"))
	button.add_theme_color_override("font_disabled_color", UiTheme.color(&"ink_muted"))
	button.add_theme_constant_override("outline_size", 0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# LE GLYPHE DU § 48. Une compétence sans icône garde son texte seul :
	# l'absence est une réponse valable, pas un défaut.
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
	var card := UiSkin.hero_card(
		UiSkin.portrait(unit.class_id, HERO_COLOR),
		"%d  %s" % [unit.slot, tr("CLASS_%s" % String(unit.class_id).to_upper())],
		unit.hit_points, unit.max_hit_points, state == &"active", "",
		Unit.class_accent(unit.class_id)
	)
	card.custom_minimum_size = Vector2(UiTheme.metric(&"card_width"), 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	match state:
		&"pending":
			card.modulate = ViewSettings.color(&"timeline_done")
		&"downed":
			card.modulate = ViewSettings.color(&"timeline_downed")
	return card


func show_result(victory: bool) -> void:
	AudioManager.play_cue(&"victory" if victory else &"defeat")
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


## Un en-tête de zone : petites capitales dorées. Le modèle en met un sur
## chaque panneau, et c'est ce qui distingue une interface d'une pile de
## boîtes.
func _caption(key: String) -> Label:
	var caption := _label(UiTheme.font_size(&"caption"))
	caption.text = tr(key).to_upper()
	caption.add_theme_color_override("font_color", UiTheme.color(&"ink_gold"))
	caption.add_theme_constant_override("outline_size", 0)
	return caption


## PAS DE CONTOUR PAR DÉFAUT, et c'est un correctif, pas un réglage.
##
## `_label` en posait un de 6 px sur CHAQUE texte, hérité du temps où le
## HUD flottait au-dessus du plateau et devait rester lisible sur de
## l'herbe. Depuis que tout repose sur un panneau sombre, le contour ne
## sert plus à rien — et depuis que `ink` est passé au crème, il est
## CLAIR SUR CLAIR : les glyphes d'une police pixel se rejoignent et le
## texte devient une bouillie grasse. C'est ce que Gaetan a montré en
## zoomant sur l'arbre de compétences.
##
## Le contour reste disponible pour ce qui se dessine SUR le plateau —
## la bannière de résultat — par `_outlined`.
func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Un texte posé SUR le plateau : là, le contour sombre est la seule
## chose qui le sépare de l'herbe.
func _outlined(size: int) -> Label:
	var label := _label(size)
	label.add_theme_color_override("font_outline_color", UiTheme.color(&"backdrop"))
	label.add_theme_constant_override("outline_size", UiTheme.metric(&"text_outline"))
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
