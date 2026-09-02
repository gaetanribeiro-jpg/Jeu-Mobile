extends Control

## L'écran d'expédition (T3.5) : la route, la besace, et la question du
## § 29.
##
## Sans cet écran, toute la Phase 3 est invisible. Une chaîne de rencontres
## qu'on ne voit pas n'est pas une expédition, c'est une file d'attente ;
## et « rentrer maintenant, ou continuer ? » n'est une question que si les
## trois termes de la décision sont à l'écran EN MÊME TEMPS :
##
##   la ROUTE      ce qui reste — combien de combats, où est le boss
##   la BESACE     ce qu'on perdrait
##   l'ÉQUIPE      ce avec quoi on continuerait
##
## Les séparer sur trois écrans reviendrait à demander au joueur de retenir
## deux d'entre eux pendant qu'il regarde le troisième, et il choisirait
## alors au sentiment. Ils tiennent donc sur une seule page, quitte à ce
## qu'aucun ne soit détaillé.
##
## L'ÉCRAN NE SAUVEGARDE PAS. Il émet `changed`, et l'appelant décide —
## même frontière que l'écran de compagnie, et pour la même raison : sans
## elle, l'écran serait intestable hors d'une partie chargée.

## L'étape en cours demande un plateau. L'appelant lance le combat et
## revient donner son compte rendu à `resolve_combat`.
signal combat_requested(map_id: StringName)

## L'expédition est finie — rentrée, achevée ou perdue.
signal finished(state: int)

## Le joueur rentre défendre son royaume (§ 37). L'appelant clôt la sortie
## et résout l'assaut avec les héros présents.
signal defence_requested

## Quelque chose a changé et mérite le disque.
signal changed

const BADGE_PX := 118

var _run: Expedition
var _company: Company

## Le royaume qui reçoit les ressources au retour. Facultatif : une
## expédition doit pouvoir se jouer sans, en test comme au simulateur.
var _kingdom: Kingdom
## Le générateur de l'étape en cours. Il est renouvelé quand l'étape
## change, et jamais autrement : le rappeler à chaque tirage repartirait du
## début de la séquence, et l'autel rendrait le même verdict trois fois.
var _rng: CombatRng
var _rng_step: int = -1
var _journal := ""

@onready var _title: Label = %Title
@onready var _satchel: Label = %Satchel
@onready var _retreat: Button = %Retreat
@onready var _route: HBoxContainer = %Route
@onready var _step: VBoxContainer = %Step
@onready var _squad: VBoxContainer = %Squad
@onready var _journal_label: Label = %Journal
@onready var _alarm: HBoxContainer = %Alarm
@onready var _alarm_label: Label = %AlarmLabel
@onready var _alarm_defend: Button = %AlarmDefend


func _ready() -> void:
	_retreat.pressed.connect(_on_retreat)
	_alarm_defend.pressed.connect(_on_defend)
	refresh()


## À appeler avant d'ajouter la scène à l'arbre.
func configure(run: Expedition, company: Company, kingdom: Kingdom = null) -> void:
	_run = run
	_company = company
	_kingdom = kingdom
	_sync_rng()


func _sync_rng() -> void:
	if _run != null and _rng_step != _run.index:
		_rng_step = _run.index
		_rng = _run.step_rng()


func expedition() -> Expedition:
	return _run


func refresh() -> void:
	if _run == null or not is_node_ready():
		return
	_sync_rng()
	# Le stock et l'évènement se tirent à l'arrivée. Les tirer ici, au
	# moment d'afficher l'étape, est le seul endroit qui garantisse que le
	# joueur les découvre en même temps que l'écran les montre.
	_run.reveal_event(_rng)
	_run.reveal_stock(_rng)

	# L'HEURE EST DANS LE TITRE, pas dans un coin. Le § 36 veut que le
	# moment pèse sur la décision du § 29 ; une information qu'il faut
	# chercher ne pèse sur rien.
	theme = UiSkin.theme
	_title.text = "%s · %s · %s" % [
		tr(Region.name_key(_run.region_id)),
		tr("EXPEDITION_STEP_OF") % [_run.depth() + 1, _run.length()],
		tr(DayNight.name_key(_run.moment())),
	]
	_satchel.text = tr("EXPEDITION_SATCHEL") % [_run.satchel_gold, _run.satchel_items.size()]
	if not _run.satchel_resources.is_empty():
		# Les ressources sont dans la besace comme le reste : les montrer à
		# côté de l'or est ce qui fait comprendre qu'elles sont en jeu.
		_satchel.text += "  ·  %s" % _resources_text(_run.satchel_resources)
	_retreat.text = tr("EXPEDITION_RETREAT")
	_retreat.disabled = not _run.can_retreat()
	_journal_label.text = _journal

	_build_route()
	_build_squad()
	_build_step()
	_build_alarm()


# --- L'alarme du § 37 ------------------------------------------------------

## « 🚨 Votre royaume est attaqué ! » Le § 37 en fait une interruption de
## l'expédition, pas une ligne de journal : elle occupe le haut de l'écran
## tant qu'elle dure, et elle dit combien d'étapes il reste.
##
## RENTRER EST UN BOUTON À PART DE « Rentrer ». Les deux referment la
## sortie, mais l'un ramène des héros à la bataille et l'autre pas, et
## confondre les deux ferait perdre un royaume par méprise.
func _build_alarm() -> void:
	if _kingdom == null or _kingdom.invasion == null:
		_alarm.visible = false
		return
	_alarm.visible = true
	var steps := _kingdom.invasion.steps_left
	_alarm_label.text = tr("INVASION_ALARM") if steps <= 0 else tr("INVASION_ALARM_IN") % steps
	_alarm_defend.text = tr("INVASION_DEFEND")
	_alarm_defend.disabled = not _run.can_retreat()


# --- La route --------------------------------------------------------------
#
# Un badge par étape. C'est la moitié « ce qui m'attend » de la décision :
# rentrer avant le boss et rentrer avant trois combats ne sont pas le même
# renoncement, et rien d'autre à l'écran ne le dit.

func _build_route() -> void:
	for child in _route.get_children():
		child.queue_free()
	for i in _run.length():
		_route.add_child(_badge(i))


func _badge(step_index: int) -> Control:
	var kind := _run.step_kind(step_index)
	var done := step_index < _run.depth()
	var here := step_index == _run.depth()

	# LE MÊME CADRE ORNÉ QUE PARTOUT AILLEURS, et l'heure dans la couleur
	# du trait : la route se lit comme une journée (§ 36), et un moment
	# qu'on ne voit qu'en arrivant ne se décide pas.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(BADGE_PX, 92)
	panel.add_theme_stylebox_override("panel", UiSkin.framed_style(
		&"frame_card", _moment_fill(_run.moment_at(step_index)),
		&"panel_edge" if here else &"panel_edge_soft", UiTheme.metric(&"card_margin")
	))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)

	var number := Label.new()
	number.text = str(step_index + 1)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", UiTheme.font_size(&"subheading"))
	number.add_theme_color_override(
		"font_color",
		UiTheme.color(&"ink_gold") if here else UiTheme.color(&"ink")
	)
	column.add_child(number)

	var name_ := Label.new()
	name_.text = tr(_kind_key(kind))
	name_.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_.add_theme_font_size_override("font_size", UiTheme.font_size(&"caption"))
	name_.add_theme_color_override("font_color", UiTheme.color(&"ink_soft"))
	column.add_child(name_)

	if done:
		panel.modulate = Color(0.55, 0.55, 0.55)
	return panel


## Le fond d'une pastille de route dit l'heure : gris-vert le jour, brun au
## crépuscule, bleu la nuit.
func _moment_fill(moment: StringName) -> StringName:
	return StringName("moment_%s_fill" % moment)


func _kind_key(kind: StringName) -> String:
	return "STEP_%s" % String(kind).to_upper()



# --- L'équipe --------------------------------------------------------------
#
# L'autre moitié de la décision. Les PV ne se rendent pas entre deux
# rencontres : c'est ce chiffre-là, et lui seul, qui dit si continuer est
# encore raisonnable.

func _build_squad() -> void:
	for child in _squad.get_children():
		child.queue_free()

	var header := Label.new()
	header.add_theme_font_size_override("font_size", 22)
	header.text = tr("EXPEDITION_SQUAD")
	_squad.add_child(header)

	for unit: Unit in _run.squad_units(_company):
		var hero := _company.hero_by_id(_run.hero_id_of_unit(unit))
		if hero == null:
			continue
		# LA MÊME CARTE QU'EN COMBAT. C'est la même information — un
		# visage, un nom, une jauge — et trois dessins pour une même chose
		# est ce qui donnait à l'ensemble son air de brouillon.
		_squad.add_child(UiSkin.hero_card(
			UiSkin.portrait(hero.class_id, hero.color),
			"%s · %s" % [
				hero.display_name(),
				tr("CLASS_%s" % String(hero.class_id).to_upper())
			],
			unit.hit_points, unit.max_hit_points
		))


# --- L'étape en cours ------------------------------------------------------

func _build_step() -> void:
	for child in _step.get_children():
		child.queue_free()
	if _run.is_over():
		_show_ending()
		return

	match _run.current_kind():
		Expedition.KIND_MERCHANT:
			_build_merchant()
		Expedition.KIND_REWARD:
			_build_reward()
		_:
			if _run.current_is_combat():
				_build_combat()
			else:
				_build_event()


func _heading(text: String, size: int = 28) -> void:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_step.add_child(label)


func _action(text: String, handler: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(420, 72)
	button.add_theme_font_size_override("font_size", 22)
	# Voir `kingdom_screen._action` : un texte plus large que son conteneur
	# renégocie sa largeur, et la mise en page peut se mettre à osciller.
	button.clip_text = true
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(handler)
	_step.add_child(button)
	return button


func _build_combat() -> void:
	var map := CombatMap.load_map(_run.current_map())
	_heading(tr(_kind_key(_run.current_kind())))
	_heading(tr(map.name_key) if map != null else String(_run.current_map()), 22)
	_action(tr("EXPEDITION_FIGHT"), func() -> void:
		combat_requested.emit(_run.current_map()))


func _build_reward() -> void:
	_heading(tr("STEP_REWARD"))
	_heading(tr("EXPEDITION_REWARD_TEXT"), 20)
	_action(tr("EXPEDITION_TAKE"), func() -> void:
		_report(_run.resolve_event({}, _rng, _company))
		_after_step())


## Un évènement du § 40. Une option par bouton, et le pari annoncé quand il
## y en a un : le télégraphe du combat dit les dégâts avant de frapper,
## un évènement doit dire sa chance avant qu'on la coure.
func _build_event() -> void:
	var event_id := _run.reveal_event(_rng)
	if event_id.is_empty():
		# Aucune donnée pour cette étape : on ne bloque pas la chaîne.
		_action(tr("EXPEDITION_CONTINUE"), func() -> void:
			_run.resolve_event({}, _rng, _company)
			_after_step())
		return

	_heading(tr(ExpeditionEvent.name_key(event_id)))
	_heading(tr(ExpeditionEvent.text_key(event_id)), 20)

	for index in ExpeditionEvent.options(event_id).size():
		var label := tr(ExpeditionEvent.option_label(event_id, index))
		if ExpeditionEvent.option_gambles(event_id, index):
			label += "   %d %%" % int(round(ExpeditionEvent.option_chance(event_id, index) * 100.0))
		label += "\n%s" % _terms(event_id, index)
		# Une option qu'on ne peut pas payer reste PROPOSÉE, grisée :
		# savoir ce qu'on ne peut pas s'offrir fait partie de la décision.
		var affordable := ExpeditionEvent.can_afford(event_id, index, _company.gold)
		_action(label, _choose.bind(event_id, index), affordable)


## Ce que l'option donne et ce qu'elle prend, écrit sous son intitulé.
##
## C'EST LE TÉLÉGRAPHE, APPLIQUÉ AUX ÉVÈNEMENTS. Un ennemi annonce ses
## dégâts chiffrés avant de frapper ; une option qui ne dirait pas ses
## termes demanderait au joueur de parier sur une phrase d'ambiance. Le
## § 40 réclame une décision, et on ne décide pas de ce qu'on ignore.
func _terms(event_id: StringName, index: int) -> String:
	var option := ExpeditionEvent.option(event_id, index)
	var line := _effects_text(option.get("success", {}))
	if ExpeditionEvent.option_gambles(event_id, index):
		line = tr("EVENT_OR_ELSE") % [line, _effects_text(option.get("failure", {}))]
	return line


func _effects_text(effects: Dictionary) -> String:
	var pieces := PackedStringArray()
	var gold := int(effects.get("gold", 0))
	if gold != 0:
		pieces.append(tr("EFFECT_GOLD") % gold)
	var health := float(effects.get("health", 0.0))
	if not is_zero_approx(health):
		pieces.append(tr("EFFECT_HEALTH") % int(round(health * 100.0)))
	var items := int(effects.get("items", 0))
	if items > 0:
		var key := "EFFECT_ITEM_FINE" if int(effects.get("rarity_bonus", 0)) > 0 else "EFFECT_ITEM"
		pieces.append(tr(key) % items if items > 1 else tr(key + "_ONE"))
	var kept := float(effects.get("satchel_kept", 1.0))
	if kept < 1.0:
		pieces.append(tr("EFFECT_SATCHEL") % int(round((1.0 - kept) * 100.0)))
	if bool(effects.get("combat", false)):
		pieces.append(tr("EFFECT_COMBAT"))
	if pieces.is_empty():
		return tr("EFFECT_NOTHING")
	return " · ".join(pieces)


func _choose(event_id: StringName, index: int) -> void:
	_report(_run.resolve_event(
		ExpeditionEvent.resolve(event_id, index, _rng), _rng, _company
	))
	_after_step()


func _build_merchant() -> void:
	_heading(tr("STEP_MERCHANT"))
	_heading(tr("EXPEDITION_MERCHANT_GOLD") % _company.gold, 20)

	var stock := _run.reveal_stock(_rng)
	for slot in stock.size():
		var item_id := stock[slot]
		var price := Merchant.price_of(item_id)
		var sold := _run.sold_slots().has(slot)
		var label := "%s   %s   %d\n%s" % [
			tr(Equipment.name_key(item_id)),
			tr(Equipment.rarity_name_key(Equipment.rarity_of(item_id))),
			price,
			# Un nom et un prix ne suffisent pas à décider : « Pavois, rare,
			# 132 » ne dit pas si c'est mieux que ce qu'on porte. Ce que
			# l'objet accorde est la seule information qui rende l'achat
			# comparable à ne pas acheter.
			_grants_text(item_id),
		]
		if sold:
			label = tr("EXPEDITION_SOLD") % tr(Equipment.name_key(item_id))
		_action(label, _purchase.bind(slot), not sold and _company.gold >= price)

	_action(tr("EXPEDITION_LEAVE_SHOP"), func() -> void:
		_run.resolve_event({}, _rng, _company)
		_after_step())


func _grants_text(item_id: StringName) -> String:
	var pieces := PackedStringArray()
	var grants := Equipment.grants(item_id)
	for key: Variant in grants.keys():
		pieces.append("%s %+d" % [
			tr("STAT_%s" % String(key).to_upper()), int(grants[key])
		])
	return ", ".join(pieces)


func _purchase(slot: int) -> void:
	var bought := _run.buy(slot, _company)
	if bought.is_empty():
		return
	_note(tr("EXPEDITION_BOUGHT") % tr(Equipment.name_key(bought)))
	changed.emit()
	refresh()


# --- Encaisser une rencontre ----------------------------------------------

## L'appelant rend le compte rendu du combat qu'il a lancé.
func resolve_combat(summary: Dictionary, hero_units: Array[Unit]) -> void:
	if _run == null:
		return
	_report(_run.resolve_combat(summary, hero_units, _rng))
	_after_step()


func _after_step() -> void:
	changed.emit()
	if _run.is_over():
		# La besace ne rejoint la compagnie qu'ici : c'est ce qui met le
		# butin en jeu pendant toute la sortie.
		_run.bank(_company, _kingdom)
		changed.emit()
	refresh()
	if _run.is_over():
		finished.emit(_run.state)


## Rentrer défendre : la sortie se referme comme un retour ordinaire — la
## besace est sauve — et l'appelant résout l'assaut.
## L'ORDRE COMPTE. On annonce le retour AVANT de refermer la sortie :
## refermer déclenche le cycle de production, qui résout un assaut imminent
## par l'armée seule. Annoncé après, le joueur rentrait défendre une
## bataille déjà perdue sans lui.
func _on_defend() -> void:
	if not _run.retreat():
		return
	defence_requested.emit()
	_note(tr("INVASION_RETURNING"))
	_after_step()


func _on_retreat() -> void:
	if not _run.retreat():
		return
	_note(tr("EXPEDITION_RETREATED"))
	_after_step()


func _show_ending() -> void:
	var key := "EXPEDITION_LOST"
	if _run.state == Expedition.State.RETURNED:
		key = "EXPEDITION_COMPLETE" if _run.is_complete() else "EXPEDITION_HOME"
	_heading(tr(key))
	_action(tr("COMBAT_BACK"), func() -> void: finished.emit(_run.state))


# --- Le journal ------------------------------------------------------------
#
# Une ligne, la dernière. Le joueur a besoin de savoir ce que son choix
# vient de lui coûter ou de lui rapporter ; il n'a pas besoin de l'histoire
# complète de sa sortie, qui prendrait la place de la décision suivante.

func _report(outcome: Dictionary) -> void:
	if outcome.is_empty():
		return
	var pieces := PackedStringArray()
	var gold := int(outcome.get("gold", 0))
	if gold != 0:
		pieces.append(tr("EXPEDITION_LOG_GOLD") % gold)
	var items: Array = outcome.get("items", [])
	for item_id: Variant in items:
		pieces.append(tr(Equipment.name_key(StringName(item_id))))
	var harvested: Dictionary = outcome.get("resources", {})
	if not harvested.is_empty():
		pieces.append(_resources_text(harvested))
	var lost_gold := int(outcome.get("lost_gold", 0))
	if lost_gold > 0:
		pieces.append(tr("EXPEDITION_LOG_LOST") % lost_gold)
	var downed: Array = outcome.get("downed", [])
	for hero_id: Variant in downed:
		var hero := _company.hero_by_id(int(hero_id))
		if hero != null:
			pieces.append(tr("EXPEDITION_LOG_DOWNED") % hero.display_name())
	if bool(outcome.get("combat", false)):
		pieces.append(tr("EXPEDITION_LOG_AMBUSHED"))
	_note(" · ".join(pieces))


func _resources_text(harvested: Dictionary) -> String:
	var pieces := PackedStringArray()
	for key: Variant in harvested.keys():
		pieces.append("%s %d" % [
			tr(ResourceTable.name_key(StringName(key))), int(harvested[key])
		])
	return ", ".join(pieces)


func _note(text: String) -> void:
	_journal = text
	if is_node_ready():
		_journal_label.text = _journal
