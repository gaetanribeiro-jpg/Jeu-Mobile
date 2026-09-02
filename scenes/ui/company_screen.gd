extends Control

## L'écran de compagnie (T2.7) : la fiche de héros, et tout ce qui la
## remplit.
##
## Sans lui, la Phase 2 entière est invisible. Un niveau gagné, un objet
## trouvé, un choix à faire : rien de tout cela n'existe pour le joueur
## tant qu'il ne peut pas le voir et y toucher. Le § 50 le dit autrement —
## « le joueur doit sentir sa progression » — et on ne sent rien qu'on ne
## voit pas.
##
## TROIS COLONNES, et une seule question chacune :
##   à gauche   qui compose ma compagnie ?
##   au centre  que vaut celui-ci, et que puis-je décider pour lui ?
##   en bas     qu'ai-je en réserve, et à qui le donner ?
##
## Les choix de niveau sont ici, et ils ne sont nulle part ailleurs : trois
## niveaux sur dix en demandent un, définitif. Un joueur qui ne peut pas
## les faire ne monte pas de niveau, il regarde un compteur augmenter.

signal closed

## Émis après toute modification — un niveau pris, un objet porté ou rendu.
##
## L'écran NE SAUVEGARDE PAS lui-même. Il ne connaît ni `GameState` ni le
## disque : il montre une compagnie et la modifie, et c'est l'appelant qui
## décide quoi en faire. Sans cette séparation, l'écran serait intestable
## hors d'une partie chargée, et il faudrait un singleton pour afficher
## trois portraits.
signal changed

const PORTRAIT_PX := 92

var _company: Company
var _selected_id: int = -1

@onready var _gold: Label = %Gold
@onready var _roster: VBoxContainer = %Roster
@onready var _sheet: VBoxContainer = %Sheet
@onready var _stash: HBoxContainer = %Stash
@onready var _stash_label: Label = %StashLabel
@onready var _back: Button = %Back


func _ready() -> void:
	theme = UiSkin.theme
	%Title.text = tr("COMPANY_TITLE")
	_back.text = tr("COMBAT_BACK")
	_back.pressed.connect(func() -> void: closed.emit())
	refresh()


## Affiche une compagnie. À appeler avant d'ajouter la scène à l'arbre.
func configure(company: Company) -> void:
	_company = company


func selected_hero() -> Hero:
	return _company.hero_by_id(_selected_id) if _company != null else null


func refresh() -> void:
	if _company == null:
		return
	if _company.hero_by_id(_selected_id) == null and _company.size() > 0:
		_selected_id = _company.heroes[0].id
	_gold.text = tr("COMPANY_GOLD") % _company.gold
	_build_roster()
	_build_sheet()
	_build_stash()


# --- La compagnie, à gauche ------------------------------------------------

func _build_roster() -> void:
	for child in _roster.get_children():
		child.queue_free()
	for hero: Hero in _company.heroes:
		_roster.add_child(_roster_row(hero))


func _roster_row(hero: Hero) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, PORTRAIT_PX + 20)
	button.toggle_mode = true
	button.button_pressed = hero.id == _selected_id
	button.add_theme_font_size_override("font_size", UiTheme.font_size(&"small"))
	# LE HÉROS SÉLECTIONNÉ PORTE LE LISERÉ DORÉ VIF, comme la carte de
	# celui qui joue en combat. C'est la même question posée au même
	# endroit : lequel je regarde ?
	var edge: StringName = (
		&"panel_edge" if hero.id == _selected_id else &"panel_edge_soft"
	)
	for state: String in ["normal", "hover", "focus", "pressed"]:
		button.add_theme_stylebox_override(state, UiSkin.framed_style(
			&"frame_card", &"panel_fill", edge, UiTheme.metric(&"card_margin")
		))
	button.add_theme_color_override("font_color", UiTheme.color(&"ink"))
	button.add_theme_constant_override("outline_size", 0)
	button.pressed.connect(func() -> void:
		_selected_id = hero.id
		refresh())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(row)

	var portrait := _portrait_of(hero)
	if portrait != null:
		row.add_child(portrait)

	var text := Label.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", UiTheme.font_size(&"small"))
	text.add_theme_color_override(
		"font_color",
		UiTheme.color(&"ink_gold") if hero.id == _selected_id else UiTheme.color(&"ink")
	)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = "%s\n%s · %s" % [
		hero.display_name(),
		tr("CLASS_%s" % String(hero.class_id).to_upper()),
		tr("COMPANY_LEVEL") % hero.level,
	]
	row.add_child(text)

	# Une pastille sur un héros qui attend une décision : c'est la seule
	# chose de cet écran qui ne peut pas attendre.
	if hero.can_level_up():
		var mark := Label.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 30)
		mark.add_theme_color_override("font_color", UiTheme.color(&"ink_gold"))
		mark.text = "!"
		row.add_child(mark)
	return button


func _portrait_of(hero: Hero) -> TextureRect:
	var entry := AssetTable.portrait(hero.class_id, hero.color)
	if entry.is_empty() or not FileAccess.file_exists(entry["path"]):
		return null
	var texture: Texture2D = load(entry["path"])
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# --- La fiche, au centre ---------------------------------------------------

func _build_sheet() -> void:
	for child in _sheet.get_children():
		child.queue_free()
	var hero := selected_hero()
	if hero == null:
		_sheet.add_child(_label(tr("COMPANY_EMPTY"), 24))
		return

	_sheet.add_child(_label("%s — %s" % [
		hero.display_name(), tr("CLASS_%s" % String(hero.class_id).to_upper())
	], 32))
	_sheet.add_child(_experience_line(hero))
	_build_level_choice(hero)
	_sheet.add_child(_stats_grid(hero))
	_sheet.add_child(_abilities_line(hero))
	_build_equipment(hero)


func _experience_line(hero: Hero) -> Label:
	if hero.level >= HeroProgression.max_level():
		return _label(tr("COMPANY_MAX_LEVEL") % hero.level, 22)
	return _label(tr("COMPANY_EXPERIENCE") % [
		hero.level, hero.experience, HeroProgression.experience_to_reach(hero.level + 1)
	], 22)


## La montée de niveau, puis l'arbre. Monter ne demande plus rien — le
## niveau donne un point, et le point se dépense ici quand le joueur veut.
## C'est ce qui permet d'encaisser une expédition entière sans ouvrir un
## menu au milieu d'un combat.
func _build_level_choice(hero: Hero) -> void:
	if hero.can_level_up():
		var button := _button(tr("COMPANY_LEVEL_UP") % (hero.level + 1))
		button.pressed.connect(func() -> void:
			hero.level_up()
			_touched())
		_sheet.add_child(button)
	_build_skill_tree(hero)


## L'arbre de compétences du § 34.
##
## UN NŒUD DIT TROIS CHOSES : son nom, ce qu'il donne, et pourquoi on ne
## peut pas le prendre. « Fureur » ne dit rien ; « Fureur — Force +1 » dit
## tout, et « il faut d'abord Entaille » évite de chercher.
##
## L'INDENTATION EST LA STRUCTURE. Les nœuds sont décalés de leur
## profondeur : c'est ce qui fait qu'un tronc et deux branches se lisent
## comme un tronc et deux branches, sans avoir à dessiner de traits.
func _build_skill_tree(hero: Hero) -> void:
	if not SkillTree.has_tree(hero.class_id):
		return
	var left := hero.skill_points_left()
	_sheet.add_child(_label(tr("SKILLS_TITLE"), 24))
	_sheet.add_child(_label(
		tr("SKILLS_POINTS") % left if left > 0 else tr("SKILLS_NONE"), 20
	))

	for node_id: StringName in SkillTree.node_ids(hero.class_id):
		_sheet.add_child(_skill_row(hero, node_id))


func _skill_row(hero: Hero, node_id: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Un décalage par niveau de profondeur : l'arbre se lit sans traits.
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(float(SkillTree.depth_of(node_id)) * 18.0, 0)
	row.add_child(indent)

	var blocked := hero.cannot_learn_because(node_id)
	var label := "%s — %s" % [
		tr(SkillTree.name_key(node_id)), tr(SkillTree.description_key(node_id))
	]
	if blocked == &"learned":
		label = "%s — %s" % [tr(SkillTree.name_key(node_id)), tr("SKILLS_TAKEN")]
	elif blocked == &"locked":
		label = "%s — %s" % [
			tr(SkillTree.name_key(node_id)),
			tr("SKILLS_LOCKED") % tr(SkillTree.name_key(SkillTree.requires(node_id))),
		]

	var button := _button(label)
	button.custom_minimum_size = Vector2(520, 46)
	button.add_theme_font_size_override("font_size", 18)
	button.disabled = not blocked.is_empty()
	if blocked == &"learned":
		button.add_theme_color_override("font_disabled_color", UiTheme.color(&"moss"))
	button.pressed.connect(func() -> void:
		if hero.learn(node_id):
			_touched())
	row.add_child(button)
	return row


func _stats_grid(hero: Hero) -> GridContainer:
	var stats := hero.effective_stats()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 4)
	for field: String in [
		"hit_points", "action_points", "movement_points", "initiative",
		"strength", "agility", "intelligence", "defence",
	]:
		grid.add_child(_label("%s %d" % [
			tr("STAT_%s" % field.to_upper()), int(stats.get(field, 0))
		], 22))
	return grid


func _abilities_line(hero: Hero) -> Label:
	var pieces := PackedStringArray()
	for ability_id: StringName in Unit.hero_class(hero.class_id).get("abilities", []):
		var ability := Ability.of(ability_id)
		if ability == null:
			continue
		pieces.append("%s (%d PA)" % [
			tr("ABILITY_%s" % String(ability_id).to_upper()), ability.action_points
		])
	return _label(" · ".join(pieces), 20)


## Les cinq emplacements. Toucher un emplacement rempli rend l'objet à la
## réserve — c'est la seule façon de le reprendre, et elle doit être
## évidente.
func _build_equipment(hero: Hero) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	_sheet.add_child(grid)

	for slot: StringName in Equipment.slots():
		grid.add_child(_label(tr("SLOT_%s" % String(slot).to_upper()), 22))
		var worn := hero.equipped(slot)
		if worn.is_empty():
			grid.add_child(_label(tr("COMPANY_SLOT_EMPTY"), 22))
			continue
		# Plus bas qu'un bouton ordinaire : les cinq emplacements doivent
		# tenir sous les statistiques sans repousser le dernier hors de vue.
		var button := _button(tr(Equipment.name_key(worn)))
		button.custom_minimum_size = Vector2(240, 44)
		button.add_theme_color_override(
			"font_color", Equipment.rarity_color(Equipment.rarity_of(worn))
		)
		button.pressed.connect(func() -> void:
			_company.unequip_to_stash(hero.id, slot)
			_touched())
		grid.add_child(button)


# --- La réserve, en bas ----------------------------------------------------

func _build_stash() -> void:
	for child in _stash.get_children():
		child.queue_free()
	var hero := selected_hero()
	_stash_label.text = tr("COMPANY_STASH") % _company.stash.size()
	if _company.stash.is_empty():
		_stash.add_child(_label(tr("COMPANY_STASH_EMPTY"), 20))
		return

	# Trié : une réserve qui change d'ordre à chaque objet ramassé est
	# illisible dès la dixième pièce.
	var sorted := _company.stash.duplicate()
	sorted.sort()
	for item_id: StringName in sorted:
		var button := _button(tr(Equipment.name_key(item_id)))
		button.add_theme_color_override(
			"font_color", Equipment.rarity_color(Equipment.rarity_of(item_id))
		)
		# Grisé plutôt qu'absent : le joueur doit voir qu'il possède l'épée,
		# et comprendre que c'est SON Mage qui ne peut pas la porter.
		button.disabled = hero == null or not hero.can_equip(item_id)
		if not button.disabled:
			button.pressed.connect(func() -> void:
				_company.equip_from_stash(hero.id, item_id)
				_touched())
		_stash.add_child(button)


## Quelque chose a changé : on redessine, et on prévient l'appelant pour
## qu'il sauvegarde. Règle dure n° 5 — l'application peut être tuée à tout
## moment, et un objet équipé qu'on ne retrouve pas au rechargement est
## exactement le genre de perte qui fait fermer un jeu.
func _touched() -> void:
	refresh()
	changed.emit()


# --- Fabriques -------------------------------------------------------------

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(210, 64)
	button.add_theme_font_size_override("font_size", 20)
	return button
