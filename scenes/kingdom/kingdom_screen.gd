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

## Ce que le dernier conseil a produit, tant que le joueur ne l'a pas lu
## (T12.10). Tant qu'il est là, le panneau montre l'issue plutôt que la
## suite : une conséquence qu'on chasse d'un clic involontaire n'a pas été
## lue, et une décision dont on ne voit pas l'effet n'en est plus une.
var _council_outcome: Dictionary = {}

## La ville à qui l'on est en train de confier quelqu'un (T12.12), ou vide.
## Tant qu'elle est posée, le panneau montre la liste des héros : « à qui »
## et « lequel » sont deux questions, et les poser sur un seul bouton en
## aurait fait trois fois plus.
var _lending_town: StringName = &""

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
	# LE CONSEIL PREND LE PANNEAU, et c'est voulu. Une décision posée à
	# côté du reste se remet à plus tard, et « plus tard » n'arrive pas :
	# le joueur repart en expédition. Tant qu'il n'a pas tranché, le
	# royaume ne propose rien d'autre.
	if not _council_outcome.is_empty():
		_build_outcome_panel()
		return
	if not _kingdom.council().is_empty():
		_build_council_panel(_kingdom.council())
		return
	if not _lending_town.is_empty():
		_build_lending_panel(_lending_town)
		return

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
	_build_neighbours(building_id)


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
	var posted := _kingdom.workers_at(worksite_id)
	var slots := Worksite.slots_of(worksite_id)
	var resource := tr(ResourceTable.name_key(Worksite.resource_of(worksite_id)))
	_line(tr(Worksite.name_key(worksite_id)), 26)
	_line(tr("KINGDOM_HANDS") % [posted.size(), slots], 20)

	# CE QUE LE CHANTIER REND VRAIMENT, pas « la base × le nombre » : depuis
	# le § 9 chacun rend ce que son métier vaut, et deux chantiers à trois
	# bras ne se valent plus.
	var total := 0
	for pawn: Pawn in posted:
		total += pawn.yield_at(worksite_id)
	_line(tr("KINGDOM_YIELD") % [
		total, resource, Worksite.per_cycle(worksite_id)
	], 19)

	# CE QU'UN BRAS VAUT DES DEUX CÔTÉS, écrit là où on le déplace. Retirer
	# un ouvrier coûte une production et rend une sentinelle ; sans les
	# deux chiffres, l'arbitrage se fait au doigt mouillé.
	_line(tr("KINGDOM_HAND_WORTH") % [
		Worksite.per_cycle(worksite_id), resource,
		Invasion.number(&"defence", &"per_garrison", 0.0)
			- Invasion.number(&"defence", &"per_worker", 0.0),
	], 19)

	_build_crew(worksite_id, posted, resource)


## QUI TRAVAILLE ICI, ET QUI POURRAIT (§ 9).
##
## C'EST LA MOITIÉ QUI MANQUAIT À LA VILLE. « Envoyer un habitant » et
## « Rappeler un habitant » déplaçaient un BRAS : deux boutons, aucune
## lecture, trente secondes entre deux sorties. On déplace maintenant
## QUELQU'UN, dont on lit le nom et le rang au métier — et un bûcheron de
## rang 4 qu'on envoie à la carrière y repart de zéro.
##
## LES DEUX LISTES SONT L'UNE SOUS L'AUTRE, et c'est ce qui rend l'échange
## lisible : en haut ceux qui y sont, en bas ceux qu'on pourrait y mettre,
## avec le rang que CHACUN a À CE CHANTIER. Sans le rang des candidats, le
## joueur ne saurait pas lequel de ses gardes est déjà carrier.
func _build_crew(
	worksite_id: StringName, posted: Array[Pawn], resource: String
) -> void:
	if posted.is_empty():
		_line(tr("KINGDOM_NOBODY_HERE"), 19)
	for pawn: Pawn in posted:
		_action(
			_pawn_label(pawn, worksite_id, resource, tr("KINGDOM_RECALL")),
			_unassign.bind(worksite_id, pawn.id), true
		)

	var available := _kingdom.watch()
	if available.is_empty() or posted.size() >= Worksite.slots_of(worksite_id):
		return
	_line(tr("KINGDOM_FROM_WATCH"), 19)
	# LES PLUS EXPÉRIMENTÉS EN TÊTE : sur quatorze habitants, une liste
	# dans l'ordre d'arrivée obligerait à la lire en entier pour trouver le
	# carrier. Trier, c'est répondre à la question qu'on se pose.
	var sorted := available.duplicate()
	sorted.sort_custom(func(a: Pawn, b: Pawn) -> bool:
		return a.level_at(worksite_id) > b.level_at(worksite_id))
	for pawn: Pawn in sorted:
		_action(
			_pawn_label(pawn, worksite_id, resource, tr("KINGDOM_POST")),
			_assign.bind(worksite_id, pawn.id), true
		)


## Le nom de quelqu'un, son rang au métier, et ce qu'il rendrait ici.
##
## LE RANG ET LE RENDEMENT ENSEMBLE : le rang seul est un chiffre abstrait,
## le rendement seul cache pourquoi celui-ci vaut mieux que celui-là.
func _pawn_label(
	pawn: Pawn, worksite_id: StringName, resource: String, action: String
) -> String:
	var rank := tr("KINGDOM_TRADE_RANK") % [
		pawn.level_at(worksite_id), Worksite.max_trade_level()
	]
	if pawn.is_master_at(worksite_id):
		rank = tr("KINGDOM_TRADE_MASTER")
	return "%s — %s\n%s · %d %s" % [
		action, pawn.given_name(), rank, pawn.yield_at(worksite_id), resource
	]


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


# --- Le conseil et les voisines (T12.10) -----------------------------------
#
# LE ROYAUME AVAIT DEUX DÉCISIONS, ET AUCUNE NE SE REPOSAIT AU RETOUR.
# Bâtir quoi, et qui travaille où : deux arbitrages qu'on pose une fois et
# qu'on revoit rarement. Le conseil en ajoute un qui attend à chaque
# retour d'expédition, dans la monnaie de la ville — bois, pierre, vivres
# et GENS — et pas dans celle de la sortie.

func _build_council_panel(event_id: StringName) -> void:
	_line(tr("COUNCIL_TITLE"), 20)
	_line(tr(KingdomEvent.name_key(event_id)), 26)
	_line(tr(KingdomEvent.text_key(event_id)), 19)

	# LES VILLES EN JEU SE LISENT AVANT DE TRANCHER. Le crédit décide de ce
	# qu'on vous proposera plus tard : décider sans le voir reviendrait à
	# choisir à l'aveugle, ce que le § 39 refuse partout ailleurs.
	for town_id: StringName in KingdomEvent.towns_of(event_id):
		if Neighbour.exists(town_id):
			_line(tr("COUNCIL_CREDIT") % [
				tr(Neighbour.name_key(town_id)), tr(_kingdom.standing_key(town_id))
			], 18)

	for index in KingdomEvent.options(event_id).size():
		var label := tr(KingdomEvent.option_label(event_id, index))
		# Le télégraphe, appliqué au conseil : un ennemi annonce ses dégâts
		# avant de frapper, une option annonce sa chance avant qu'on la
		# coure. Même formule que l'écran d'expédition.
		if KingdomEvent.option_gambles(event_id, index):
			label += "   %d %%" % int(round(KingdomEvent.option_chance(event_id, index) * 100.0))
		var affordable := _kingdom.can_choose(index, _company)
		if not affordable:
			label += "   (%s)" % tr("COUNCIL_UNAFFORDABLE")
		_action(label, _choose_council.bind(index), affordable)
		# LES TERMES SONT UN LABEL, PAS LA SECONDE LIGNE DU BOUTON, et
		# c'est la capture qui a tranché : un `Button` a `clip_text` — il le
		# FAUT, sinon un libellé trop large renégocie sa largeur et la mise
		# en page oscille — donc « sinon Valmont −2 » se faisait couper net.
		# Un pari dont on ne voit pas la perte est exactement ce que le
		# § 39 refuse. Un `Label` se replie, lui, et ne peut pas mentir par
		# troncature.
		_terms_line(_council_terms(event_id, index))


## Les termes d'une option, CENTRÉS sous son bouton : alignés à gauche
## comme le reste du panneau, ils se lisaient comme une ligne du texte
## d'ambiance et pas comme la suite du bouton.
func _terms_line(text: String) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	label.text = text
	_panel.add_child(label)


## Ce que l'option donne et ce qu'elle prend, écrit sous son intitulé.
##
## C'EST LE TÉLÉGRAPHE, APPLIQUÉ AU ROYAUME. Une option qui ne dirait pas
## ses termes demanderait au joueur de parier sur une phrase d'ambiance.
func _council_terms(event_id: StringName, index: int) -> String:
	var option := KingdomEvent.option(event_id, index)
	var line := _council_effects(option.get("success", {}))
	if KingdomEvent.option_gambles(event_id, index):
		line = tr("EVENT_OR_ELSE") % [line, _council_effects(option.get("failure", {}))]
	return line


func _council_effects(effects: Dictionary) -> String:
	var pieces := PackedStringArray()
	for resource_id: StringName in ResourceTable.ids():
		var delta := int(effects.get(String(resource_id), 0))
		if delta != 0:
			pieces.append("%s %+d" % [tr(ResourceTable.name_key(resource_id)), delta])
	var menace := int(effects.get("threat", 0))
	if menace != 0:
		pieces.append(tr("EFFECT_THREAT") % menace)
	var hands := int(effects.get("population", 0))
	if hands != 0:
		pieces.append(tr("EFFECT_HANDS") % hands)
	for key: Variant in (effects.get("trade_xp", {}) as Dictionary).keys():
		pieces.append(tr("EFFECT_TRADE") % tr(Worksite.name_key(StringName(key))))
	for key: Variant in (effects.get("standing", {}) as Dictionary).keys():
		pieces.append("%s %+d" % [
			tr(Neighbour.name_key(StringName(key))),
			int((effects["standing"] as Dictionary)[key]),
		])
	for key: Variant in (effects.get("potions", {}) as Dictionary).keys():
		pieces.append("%s %+d" % [
			tr(Consumable.name_key(StringName(key))),
			int((effects["potions"] as Dictionary)[key]),
		])
	if not (effects.get("hero", {}) as Dictionary).is_empty():
		pieces.append(tr("EFFECT_CHAMPION"))
	return " · ".join(pieces) if not pieces.is_empty() else tr("EFFECT_NOTHING")


## Les voisines et ce qu'elles pensent de vous, sur le panneau au repos.
##
## PAS D'ÉCRAN DE DIPLOMATIE. Le marchand du § 40 n'en a jamais eu non
## plus : il arrive, il propose, il repart. Trois lignes sur le panneau
## qui ne sert à rien d'autre suffisent à rendre le crédit visible, et un
## écran écrit avant d'avoir des offres à y mettre serait une coquille.
func _build_neighbours(building_id: StringName) -> void:
	# SOUS LE CHÂTEAU, et pas sur le panneau « rien de sélectionné » : ce
	# panneau-là ne s'affiche JAMAIS, la vue ouvrant sur le château
	# sélectionné. Une liste posée là aurait été une mécanique branchée et
	# invisible — le défaut que ce projet attrape en capture depuis dix
	# phases. Le château est d'ailleurs le bon endroit : c'est de lui qu'on
	# traite avec les voisines, et c'est ce que la vue montre d'entrée.
	if building_id != Buildings.KEYSTONE:
		return
	var towns := Neighbour.ids()
	if towns.is_empty():
		return
	_line(tr("COUNCIL_NEIGHBOURS"), 22)
	for town_id: StringName in towns:
		_line(tr("COUNCIL_CREDIT") % [
			tr(Neighbour.name_key(town_id)), tr(_kingdom.standing_key(town_id))
		], 20)
		_line(tr(Neighbour.description_key(town_id)), 17)
		_lend_button(town_id)
	_build_away()


## PRÊTER UN HÉROS, C'EST LA DÉCISION DU § 9 TRANSPOSÉE (T12.12) : « qui
## peux-tu te passer ? ». Le bouton ne prête personne — il pose la
## QUESTION, et le panneau bascule sur la liste des héros.
##
## LE REFUS DIT POURQUOI. Un bouton grisé muet est une impasse ; celui-ci
## dit s'il manque du crédit ou des bras.
func _lend_button(town_id: StringName) -> void:
	if _company == null or Neighbour.loan_cycles() <= 0:
		return
	var blocked := &""
	for hero: Hero in _company.available():
		blocked = _kingdom.cannot_lend_because(hero, town_id, _company)
		if blocked.is_empty():
			break
	if _company.available().is_empty():
		blocked = &"nobody"
	var label := tr("KINGDOM_LEND") % [
		tr(Neighbour.name_key(town_id)), Neighbour.loan_cycles()
	]
	if blocked == &"standing":
		label = tr("KINGDOM_LEND_STANDING")
	elif blocked == &"too_few" or blocked == &"nobody":
		label = tr("KINGDOM_LEND_TOO_FEW") % Neighbour.loan_minimum_left()
	_action(label, func() -> void:
		_lending_town = town_id
		refresh(), blocked.is_empty())


## Ceux qui sont en mission, et pour combien de temps encore. Sans ça, un
## héros disparu de l'écran de compagnie serait un bug, pas une décision.
func _build_away() -> void:
	if _company == null:
		return
	var away := _company.lent()
	if away.is_empty():
		return
	_line(tr("KINGDOM_AWAY"), 20)
	for hero: Hero in away:
		_line(tr("KINGDOM_AWAY_LINE") % [
			hero.display_name(), tr(Neighbour.name_key(hero.away_town)), hero.away_cycles
		], 18)


## À QUI est posé ; reste LEQUEL. Un bouton par héros disponible, avec ce
## que le prêt rapporte écrit une fois en haut : un chiffre répété sur
## quatre boutons se lit comme quatre chiffres différents.
func _build_lending_panel(town_id: StringName) -> void:
	_line(tr(Neighbour.name_key(town_id)), 26)
	_line(tr("KINGDOM_LEND_TERMS") % [
		Neighbour.loan_cycles(),
		Neighbour.loan_gold() * Neighbour.loan_cycles(),
		Neighbour.loan_experience() * Neighbour.loan_cycles(),
	], 19)
	for hero: Hero in _company.available():
		var blocked := _kingdom.cannot_lend_because(hero, town_id, _company)
		_action(
			tr("KINGDOM_LEND_HERO") % [
				hero.display_name(), tr("CLASS_%s" % String(hero.class_id).to_upper())
			],
			_lend.bind(hero, town_id), blocked.is_empty()
		)
	_action(tr("COUNCIL_CLOSE"), func() -> void:
		_lending_town = &""
		refresh(), true)


func _lend(hero: Hero, town_id: StringName) -> void:
	if not _kingdom.lend(hero, town_id, _company):
		return
	_lending_town = &""
	_note(tr("KINGDOM_LENT") % [
		hero.display_name(), tr(Neighbour.name_key(town_id)), Neighbour.loan_cycles()
	])
	changed.emit()
	refresh()


## L'issue du conseil, lue avant de passer à la suite.
func _build_outcome_panel() -> void:
	var event_id := StringName(_council_outcome.get("event", ""))
	if KingdomEvent.exists(event_id):
		_line(tr(KingdomEvent.name_key(event_id)), 26)
	_line(tr(String(_council_outcome.get("text_key", ""))), 20)

	for line: String in _council_lines():
		_line(line, 18)
	_action(tr("COUNCIL_CLOSE"), func() -> void:
		_council_outcome = {}
		refresh(), true)


## Ce que le conseil a RÉELLEMENT changé, et pas ce qu'il annonçait.
##
## L'ÉCART EXISTE ET IL COMPTE : un royaume au plafond de population
## n'accueille pas les deux familles qu'il vient d'accepter, et une réserve
## à zéro ne descend pas plus bas. Réafficher les termes annoncés ferait
## mentir l'écran exactement là où le joueur vérifie.
func _council_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var moved: Dictionary = _council_outcome.get("moved", {})
	var pieces := PackedStringArray()
	for key: Variant in moved.keys():
		pieces.append("%s %+d" % [
			tr(ResourceTable.name_key(StringName(key))), int(moved[key])
		])
	if not pieces.is_empty():
		out.append(" · ".join(pieces))
	if int(_council_outcome.get("arrived", 0)) > 0:
		out.append(tr("COUNCIL_SETTLED") % int(_council_outcome["arrived"]))
	for name_: Variant in _council_outcome.get("left", []):
		out.append(tr("COUNCIL_LEFT") % String(name_))
	var learned: Dictionary = _council_outcome.get("learned", {})
	for key: Variant in learned.keys():
		out.append(tr("COUNCIL_LEARNED") % [
			int(learned[key]), tr(Worksite.name_key(StringName(key)))
		])
	var credits: Dictionary = _council_outcome.get("credits", {})
	for key: Variant in credits.keys():
		var town_id := StringName(key)
		out.append(tr("COUNCIL_CREDIT") % [
			tr(Neighbour.name_key(town_id)), tr(Neighbour.standing_key(int(credits[key])))
		])
	var flasks: Dictionary = _council_outcome.get("flasks", {})
	for key: Variant in flasks.keys():
		out.append(tr("COUNCIL_FLASKS") % [
			int(flasks[key]), tr(Consumable.name_key(StringName(key)))
		])
	var champion: Variant = _council_outcome.get("champion", null)
	if champion is Hero:
		out.append(tr("COUNCIL_JOINS") % (champion as Hero).display_name())
	return out


func _choose_council(index: int) -> void:
	var outcome := _kingdom.resolve_council(index, _company, _rng)
	if outcome.is_empty():
		return
	_council_outcome = outcome
	changed.emit()
	refresh()


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


func _assign(worksite_id: StringName, pawn_id: int = -1) -> void:
	if not _kingdom.assign(worksite_id, pawn_id):
		return
	changed.emit()
	refresh()


func _unassign(worksite_id: StringName, pawn_id: int = -1) -> void:
	if not _kingdom.unassign(worksite_id, pawn_id):
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
	# QUI A MONTÉ D'UN RANG, NOMMÉMENT. La progression d'un métier est
	# invisible tant qu'on ne rouvre pas le panneau du chantier — et une
	# récompense qu'on ne voit pas ne récompense rien. C'est le retour qui
	# manquait à la décision « qui je laisse où » : on la prend au départ,
	# on en lit le fruit au retour.
	for entry: Variant in report.get("promoted", []):
		var line: Dictionary = entry
		var key := "KINGDOM_MASTERED" if bool(line.get("master", false)) else "KINGDOM_PROMOTED"
		pieces.append(tr(key) % [
			String(line.get("name", "")),
			tr(Worksite.name_key(StringName(line.get("worksite", &"")))),
			int(line.get("level", 0)),
		])
	if bool(report.get("arrived", false)):
		pieces.append(tr("KINGDOM_ARRIVED"))
	if bool(report.get("hungry", false)):
		pieces.append(tr("KINGDOM_HUNGRY"))
	# LE CONSEIL SE SIGNALE DANS LE JOURNAL AUSSI. Le panneau le montre
	# déjà, mais le joueur qui revient regarde d'abord ce qui a changé
	# pendant son absence : c'est là qu'il faut lui dire qu'on l'attend.
	# CEUX QUI RENTRENT SONT NOMMÉS. Un héros prêté trois cycles plus tôt
	# reparaîtrait sans un mot dans l'écran de compagnie : une décision dont
	# on ne voit pas la fin n'a pas de fin (règle de T12.9).
	for entry: Variant in report.get("returned", []):
		var line: Dictionary = entry
		pieces.append(tr("KINGDOM_RETURNED") % [
			String(line.get("name", "")),
			tr(Neighbour.name_key(StringName(line.get("town", &"")))),
			int(line.get("gold", 0)),
		])
	if not String(report.get("council", "")).is_empty():
		pieces.append(tr("COUNCIL_WAITING"))
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
