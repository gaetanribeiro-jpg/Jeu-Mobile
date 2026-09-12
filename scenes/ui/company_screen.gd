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

## Le royaume qui encaisse les objets fondus (§ 32). Peut être nul.
var _kingdom: Kingdom = null

@onready var _gold: Label = %Gold
@onready var _roster: VBoxContainer = %Roster
@onready var _sheet: VBoxContainer = %Sheet
@onready var _stash: HBoxContainer = %Stash
@onready var _stash_label: Label = %StashLabel
@onready var _back: Button = %Back
@onready var _sheet_frame: PanelContainer = %SheetFrame
@onready var _roster_frame: PanelContainer = %RosterFrame
@onready var _stash_frame: PanelContainer = %StashFrame


func _ready() -> void:
	theme = UiSkin.theme
	_lay_backdrop()
	UiSkin.dress_scrolls(self)
	%Title.text = tr("COMPANY_TITLE")
	_back.text = tr("COMBAT_BACK")
	_back.pressed.connect(func() -> void: closed.emit())
	refresh()
	# TROIS PANNEAUX, TROIS CADRES (T12.13). La fiche du héros, la liste et
	# la réserve étaient du TEXTE POSÉ SUR LE FOND : rien ne disait où
	# commençait l'un et où finissait l'autre, et l'écran avait l'air d'un
	# brouillon à côté du combat, qui est habillé depuis T9.6.
	_sheet_frame.add_theme_stylebox_override("panel", UiSkin.framed_style(&"frame_panel"))
	_roster_frame.add_theme_stylebox_override("panel", UiSkin.framed_style(&"frame_panel"))
	_stash_frame.add_theme_stylebox_override("panel", UiSkin.framed_style(&"frame_panel"))


## Affiche une compagnie. À appeler avant d'ajouter la scène à l'arbre.
## LE ROYAUME EST OPTIONNEL, et c'est ce qui garde l'écran autonome : sans
## lui, la réserve se lit et s'équipe comme avant, elle ne se fond pas.
## Les tests d'écran n'ont donc pas à bâtir un royaume pour vérifier
## l'équipement, et le jour où l'écran s'ouvre depuis un endroit qui n'en a
## pas, il ne tombe pas.
func configure(company: Company, kingdom: Kingdom = null) -> void:
	_company = company
	_kingdom = kingdom


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
	# LE HÉROS NON SÉLECTIONNÉ PORTE LA COULEUR DE SA CLASSE. Quatre
	# lignes identiques ne se distinguent que par leur nom, qu'il faut
	# lire ; teintées, elles se comptent d'un coup d'œil.
	var edge: StringName = (
		&"panel_edge" if hero.id == _selected_id
		else Unit.class_accent(hero.class_id)
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
	# QUI PART SE LIT DANS LE VIVIER, pas seulement sur la fiche : c'est
	# une information de COMPARAISON — « ai-je bien composé ? » — et une
	# comparaison qui demande de cliquer sur chacun n'en est pas une.
	text.text = "%s%s\n%s · %s" % [
		tr("COMPANY_GOING_MARK") if _company.is_in_squad(hero.id) else "",
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

	_sheet.add_child(_sheet_header(hero))
	_sheet.add_child(_trait_line(hero))
	_build_squad_choice(hero)
	_build_level_choice(hero)
	_sheet.add_child(_stats_grid(hero))
	_sheet.add_child(_abilities_line(hero))
	_build_equipment(hero)


## L'EN-TÊTE D'UNE FICHE : le visage, le nom, et la jauge d'expérience.
##
## UN PORTRAIT DE 92 PX DANS LA LISTE ET RIEN DANS LA FICHE, c'était
## l'inverse de ce qu'il fallait : la liste sert à RECONNAÎTRE, la fiche
## sert à REGARDER. Et une progression écrite « 0 / 30 » se compte ; une
## jauge se voit — le jeu en dessine partout ailleurs depuis T9.2.
func _sheet_header(hero: Hero) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.metric(&"card_margin"))

	var face := _portrait_of(hero)
	face.custom_minimum_size = Vector2(
		UiTheme.metric(&"portrait_hero"), UiTheme.metric(&"portrait_hero")
	)
	row.add_child(face)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)

	var title := _label("%s — %s" % [
		hero.display_name(), tr("CLASS_%s" % String(hero.class_id).to_upper())
	], 30)
	# LE NOM PORTE LA COULEUR DE SA CLASSE, comme sa rangée dans la liste :
	# on retrouve du premier coup d'œil quelle fiche est ouverte.
	title.add_theme_color_override(
		"font_color", UiTheme.color(Unit.class_accent(hero.class_id))
	)
	column.add_child(title)
	column.add_child(_experience_line(hero))
	if hero.level < HeroProgression.max_level():
		var floor_ := HeroProgression.experience_to_reach(hero.level)
		var ceiling := HeroProgression.experience_to_reach(hero.level + 1)
		var gauge := UiSkin.build_bar(
			float(hero.experience - floor_), maxf(float(ceiling - floor_), 1.0),
			UiTheme.color(Unit.class_accent(hero.class_id)),
			UiTheme.metric(&"bar_height_card")
		)
		# ELLE NE PREND PAS TOUTE LA LARGEUR. Une auge de mille pixels pour
		# trente points d'expérience se lit comme une barre pleine : l'œil
		# juge un remplissage à sa PROPORTION, et une auge trop longue rend
		# toute proportion illisible.
		gauge.custom_minimum_size = Vector2(UiTheme.metric(&"card_width"), 0)
		gauge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(gauge)
	return row


## LE CARACTÈRE SE RELIT APRÈS L'EMBAUCHE. Il est définitif, donc c'est
## une information permanente de la fiche et pas un détail du recrutement :
## six mois plus tard le joueur doit pouvoir se demander pourquoi ce
## Guerrier-ci encaisse mieux que l'autre. Les DEUX moitiés sont dites —
## n'annoncer que le gain ferait passer un échange pour un bonus.
func _trait_line(hero: Hero) -> Label:
	return _label(UiSkin.trait_line(hero.trait_id), 22)


func _experience_line(hero: Hero) -> Label:
	if hero.level >= HeroProgression.max_level():
		return _label(tr("COMPANY_MAX_LEVEL") % hero.level, 22)
	return _label(tr("COMPANY_EXPERIENCE") % [
		hero.level, hero.experience, HeroProgression.experience_to_reach(hero.level + 1)
	], 20)


## EMMENER OU LAISSER, ET C'EST LA DÉCISION QUI MANQUAIT. La composition
## était figée sur les quatre PREMIERS héros de la compagnie, remise à
## zéro chaque fois qu'on fermait un écran : un cinquième recruté ne
## jouait jamais. Le recrutement à trois candidats de T12.3 ne servait donc
## à rien, et la demande de Gaetan — « changer de personnage ou de
## composition » — était sans objet.
##
## LE BOUTON DIT CE QUI VA ARRIVER, pas l'état courant : « Emmener » sur un
## héros resté, « Laisser au royaume » sur un héros qui part. Un bouton qui
## affiche un état se lit comme une case à cocher et se clique à l'envers.
##
## LE REFUS S'EXPLIQUE. L'équipe est plafonnée à `team_size` — la carte ne
## prévoit pas plus de cases de départ — et on ne descend pas sous un
## héros. Un bouton grisé sans raison est une impasse ; celui-ci dit
## laquelle des deux bornes il touche.
func _build_squad_choice(hero: Hero) -> void:
	var going := _company.is_in_squad(hero.id)
	var full := _company.squad_ids.size() >= CombatRules.team_size()
	var lone := _company.squad_ids.size() <= 1
	var label := tr("COMPANY_LEAVE_BEHIND") if going else tr("COMPANY_TAKE_ALONG")
	var allowed := true
	if going and lone:
		label = tr("COMPANY_SQUAD_LAST")
		allowed = false
	elif not going and full:
		label = tr("COMPANY_SQUAD_FULL") % CombatRules.team_size()
		allowed = false
	var button := _button(label, &"primary" if not going else &"muted")
	# UN BOUTON PLEINE LARGEUR SE LIT COMME UNE BANNIÈRE, pas comme une
	# action : il prend la place d'un titre et son libellé se perd au
	# milieu. Les actions d'une fiche se rangent à gauche, à leur taille.
	button.custom_minimum_size = Vector2(
		UiTheme.metric(&"detail_width"), UiTheme.metric(&"button_height")
	)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.disabled = not allowed
	button.pressed.connect(func() -> void:
		_company.toggle_squad(hero.id)
		changed.emit()
		refresh())
	_sheet.add_child(button)


## La montée de niveau, puis l'arbre. Monter ne demande plus rien — le
## niveau donne un point, et le point se dépense ici quand le joueur veut.
## C'est ce qui permet d'encaisser une expédition entière sans ouvrir un
## menu au milieu d'un combat.
func _build_level_choice(hero: Hero) -> void:
	if hero.can_level_up():
		var button := _button(tr("COMPANY_LEVEL_UP") % (hero.level + 1))
		button.custom_minimum_size = Vector2(
			UiTheme.metric(&"detail_width"), UiTheme.metric(&"button_height")
		)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
## L'INDENTATION EST LA STRUCTURE — MAIS PAS CELLE DE LA PROFONDEUR.
##
## Chaque rangée était décalée de sa profondeur, et onze nœuds donnaient
## un ESCALIER de sept marches qui filait vers la droite. Un arbre à deux
## branches n'a que DEUX niveaux de lecture : le tronc, puis le choix. La
## profondeur, elle, est déjà écrite dans chaque ligne — « il faut
## d'abord Poigne » dit l'ordre mieux qu'un décalage.
##
## Les deux voies sont donc annoncées et groupées, et c'est la seule
## question qu'on se pose en ouvrant l'écran : laquelle des deux.
func _build_skill_tree(hero: Hero) -> void:
	if not SkillTree.has_tree(hero.class_id):
		return
	var left := hero.skill_points_left()
	_sheet.add_child(_label(tr("SKILLS_TITLE"), 24))
	_sheet.add_child(_label(
		tr("SKILLS_POINTS") % left if left > 0 else tr("SKILLS_NONE"), 20
	))

	var announced := {}
	for node_id: StringName in SkillTree.node_ids(hero.class_id):
		var branch := SkillTree.branch_of(node_id)
		if not branch.is_empty() and not announced.has(branch):
			announced[branch] = true
			_sheet.add_child(_label(tr(SkillTree.branch_name_key(branch)), 20))
		_sheet.add_child(_skill_row(hero, node_id))


func _skill_row(hero: Hero, node_id: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Un seul cran, et seulement pour ce qui est sous une branche : le
	# tronc à gauche, les deux voies en retrait.
	var indent := Control.new()
	var step := UiTheme.metric(&"tree_indent")
	indent.custom_minimum_size = Vector2(
		0.0 if SkillTree.branch_of(node_id).is_empty() else float(step), 0
	)
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

	# TROIS ÉTATS, TROIS COULEURS DE LISERÉ. Un arbre de onze nœuds tous
	# gris demande de lire chaque ligne pour savoir laquelle est prise,
	# laquelle est ouverte et laquelle attend un prérequis — alors que
	# c'est justement la seule question qu'on se pose en l'ouvrant.
	var role: StringName = &"muted"
	if blocked == &"learned":
		role = &"positive"
	elif blocked.is_empty():
		role = Unit.class_accent(hero.class_id)
	var button := _button(label, role)
	# À SA TAILLE, PAS À CELLE DU PANNEAU. Étirés, les onze nœuds faisaient
	# onze dalles vides dont le libellé se perdait au milieu — et un arbre
	# de compétences doit se PARCOURIR du regard, pas se lire ligne à ligne.
	button.custom_minimum_size = Vector2(
		UiTheme.metric(&"ability_card_width") * 2, UiTheme.metric(&"button_height_small")
	)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
		_stash.add_child(_melt_button(item_id))


## FONDRE UN OBJET (§ 32) : « un même objet peut être vendu, améliorer une
## arme, améliorer un bâtiment ou débloquer une technologie — cela crée des
## choix stratégiques ». La réserve n'avait aucun débouché : trente objets
## pour vingt-cinq cases portées, et rien à faire du reste.
##
## LE BOUTON DIT CE QU'IL REND, chiffres compris. « Fondre » seul
## demanderait d'essayer pour savoir, sur une action IRRÉVERSIBLE — et une
## action irréversible qu'on ne peut pas évaluer avant n'est pas une
## décision, c'est un pari.
##
## IL RESTE SOUS L'OBJET, en `muted` : équiper est l'action principale de
## la réserve, fondre est l'aveu qu'on n'en a pas l'usage. Le rôle de
## couleur le dit sans une ligne de texte.
func _melt_button(item_id: StringName) -> Button:
	var gained := Equipment.salvage_of(item_id)
	var pieces := PackedStringArray()
	for key: Variant in gained.keys():
		pieces.append("%d %s" % [
			int(gained[key]), tr(ResourceTable.name_key(StringName(key)))
		])
	var button := _button(tr("COMPANY_MELT") % ", ".join(pieces), &"muted")
	button.disabled = _kingdom == null or gained.is_empty()
	if not button.disabled:
		button.pressed.connect(func() -> void:
			_company.melt(item_id, _kingdom)
			_touched())
	return button


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


func _button(text: String, role: StringName = &"default") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(210, 64)
	button.add_theme_font_size_override("font_size", 20)
	UiSkin.dress_button(button, role)
	return button


## Le motif de fond, posé DERRIÈRE tout le reste. Un aplat noir est fade :
## rien n'y accroche la lumière et les panneaux flottent sur du vide.
func _lay_backdrop() -> void:
	UiSkin.lay_backdrop(self)
